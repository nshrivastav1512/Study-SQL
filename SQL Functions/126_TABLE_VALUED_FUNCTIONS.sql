/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\126_TABLE_VALUED_FUNCTIONS.sql
    
    This script demonstrates SQL Server Table-Valued Functions using the HRSystem database.
    These functions return table results and are particularly useful for retrieving
    system object information and analyzing database schema.

    Table-Valued Functions covered:
    1. TABLE_NAME() - Get table name from object ID
    2. SYSOBJECTS() - Query system objects
    3. SYSCOLUMNS() - Query column information
    4. SYSINDEXES() - Query index information
    5. SYSFOREIGNKEYS() - Query foreign key constraints
*/

USE HRSystem;
GO

-- Create a schema analysis table to store results
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[SchemaAnalysis]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.SchemaAnalysis (
        AnalysisID INT PRIMARY KEY IDENTITY(1,1),
        ObjectName NVARCHAR(128),
        ObjectType NVARCHAR(50),
        ColumnCount INT,
        IndexCount INT,
        ForeignKeyCount INT,
        AnalysisDate DATETIME2 DEFAULT SYSDATETIME(),
        AnalyzedBy NVARCHAR(128) DEFAULT SYSTEM_USER
    );
END

-- Function to get detailed table information
CREATE OR ALTER FUNCTION HR.fn_GetTableInfo
(
    @TableName NVARCHAR(128)
)
RETURNS TABLE
AS
RETURN
(
    -- Get basic table information using system objects
    SELECT 
        o.name AS TableName,
        o.type_desc AS ObjectType,
        o.create_date AS CreatedDate,
        o.modify_date AS LastModifiedDate,
        (
            SELECT COUNT(*) 
            FROM sys.columns c 
            WHERE c.object_id = o.object_id
        ) AS ColumnCount,
        (
            SELECT COUNT(*) 
            FROM sys.indexes i 
            WHERE i.object_id = o.object_id
        ) AS IndexCount,
        (
            SELECT COUNT(*) 
            FROM sys.foreign_keys fk 
            WHERE fk.parent_object_id = o.object_id
        ) AS ForeignKeyCount
    FROM sys.objects o
    WHERE o.name = @TableName
        AND o.type = 'U' -- User table
);

-- Function to analyze column information
CREATE OR ALTER FUNCTION HR.fn_GetColumnDetails
(
    @TableName NVARCHAR(128)
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        c.name AS ColumnName,
        t.name AS DataType,
        c.max_length AS MaxLength,
        c.precision AS NumericPrecision,
        c.scale AS NumericScale,
        c.is_nullable AS IsNullable,
        CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS IsPrimaryKey,
        CASE WHEN fk.parent_column_id IS NOT NULL THEN 1 ELSE 0 END AS IsForeignKey
    FROM sys.columns c
    INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
    INNER JOIN sys.objects o ON c.object_id = o.object_id
    LEFT JOIN sys.index_columns pk 
        ON c.object_id = pk.object_id 
        AND c.column_id = pk.column_id
        AND pk.index_id = 1 -- Clustered index (usually primary key)
    LEFT JOIN sys.foreign_key_columns fk
        ON c.object_id = fk.parent_object_id
        AND c.column_id = fk.parent_column_id
    WHERE o.name = @TableName
);

-- Function to get index information
CREATE OR ALTER FUNCTION HR.fn_GetIndexDetails
(
    @TableName NVARCHAR(128)
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        i.name AS IndexName,
        i.type_desc AS IndexType,
        i.is_unique AS IsUnique,
        i.is_primary_key AS IsPrimaryKey,
        (
            SELECT STRING_AGG(c.name, ', ')
            FROM sys.index_columns ic
            JOIN sys.columns c ON 
                ic.object_id = c.object_id AND 
                ic.column_id = c.column_id
            WHERE ic.object_id = i.object_id
                AND ic.index_id = i.index_id
        ) AS IndexColumns
    FROM sys.indexes i
    JOIN sys.objects o ON i.object_id = o.object_id
    WHERE o.name = @TableName
);

-- Example usage of the functions
BEGIN TRANSACTION;

TRY
    -- Analyze the Employees table structure
    INSERT INTO HR.SchemaAnalysis (
        ObjectName,
        ObjectType,
        ColumnCount,
        IndexCount,
        ForeignKeyCount
    )
    SELECT 
        TableName,
        ObjectType,
        ColumnCount,
        IndexCount,
        ForeignKeyCount
    FROM HR.fn_GetTableInfo('Employees');

    -- View detailed column information
    SELECT * FROM HR.fn_GetColumnDetails('Employees');

    -- View index information
    SELECT * FROM HR.fn_GetIndexDetails('Employees');

    -- View schema analysis results
    SELECT 
        ObjectName,
        ObjectType,
        ColumnCount,
        IndexCount,
        ForeignKeyCount,
        AnalysisDate,
        AnalyzedBy
    FROM HR.SchemaAnalysis
    ORDER BY AnalysisDate DESC;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;

-- Cleanup (commented out for safety)
/*
DROP FUNCTION IF EXISTS HR.fn_GetTableInfo;
DROP FUNCTION IF EXISTS HR.fn_GetColumnDetails;
DROP FUNCTION IF EXISTS HR.fn_GetIndexDetails;
DROP TABLE IF EXISTS HR.SchemaAnalysis;
*/