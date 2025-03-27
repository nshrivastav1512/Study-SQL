/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\115_METADATA_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Metadata Functions with real-life examples
    using the HRSystem database schemas and tables.

    Metadata Functions covered:
    1. OBJECT_ID() - Returns object identifier
    2. OBJECT_NAME() - Returns object name
    3. COLUMNPROPERTY() - Returns column information
    4. INDEXPROPERTY() - Returns index information
    5. TYPEPROPERTY() - Returns type information
    6. DATABASEPROPERTYEX() - Returns database properties
    7. SERVERPROPERTY() - Returns server properties
    8. SCHEMA_ID() - Returns schema identifier
    9. SCHEMA_NAME() - Returns schema name
    10. TABLE_NAME() - Returns table name
    11. OBJECT_SCHEMA_NAME() - Returns schema name of object
    12. OBJECT_DEFINITION() - Returns object definition
    13. FILEGROUP_ID() - Returns filegroup identifier
    14. FILEGROUP_NAME() - Returns filegroup name
    15. INDEXKEY_PROPERTY() - Returns index key properties
*/

USE HRSystem;
GO

-- Create sample tables if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[MetadataDemo]') AND type in (N'U'))
BEGIN
    -- Create a filegroup for demonstration
    IF NOT EXISTS (SELECT * FROM sys.filegroups WHERE name = 'HR_DATA')
    BEGIN
        ALTER DATABASE HRSystem
        ADD FILEGROUP HR_DATA;

        ALTER DATABASE HRSystem
        ADD FILE 
        (
            NAME = 'HR_Data_1',
            FILENAME = 'C:\SQLData\HR_Data_1.ndf',
            SIZE = 5MB,
            MAXSIZE = 100MB,
            FILEGROWTH = 5MB
        )
        TO FILEGROUP HR_DATA;
    END

    -- Create table with specific properties
    CREATE TABLE HR.MetadataDemo
    (
        ID INT IDENTITY(1,1) PRIMARY KEY,
        Name NVARCHAR(100) NOT NULL,
        Description NVARCHAR(MAX),
        CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
        Status BIT DEFAULT 1,
        Amount DECIMAL(10,2)
    ) ON HR_DATA;

    -- Create indexes
    CREATE NONCLUSTERED INDEX IX_MetadataDemo_Name
    ON HR.MetadataDemo(Name);

    CREATE NONCLUSTERED INDEX IX_MetadataDemo_CreatedDate
    ON HR.MetadataDemo(CreatedDate)
    INCLUDE (Status);

    -- Insert sample data
    INSERT INTO HR.MetadataDemo (Name, Description, Amount) VALUES
    ('Sample 1', 'First sample record', 1000.50),
    ('Sample 2', 'Second sample record', 2500.75),
    ('Sample 3', 'Third sample record', 750.25);
END

-- 1. OBJECT_ID() - Get object identifiers
SELECT 
    'HR.MetadataDemo' AS ObjectName,
    OBJECT_ID('HR.MetadataDemo') AS ObjectID,
    'Returns internal object ID' AS Description;
/* Output example:
ObjectName        ObjectID    Description
HR.MetadataDemo  581577110   Returns internal object ID
*/

-- 2. OBJECT_NAME() - Get object names
SELECT 
    OBJECT_ID('HR.MetadataDemo') AS ObjectID,
    OBJECT_NAME(OBJECT_ID('HR.MetadataDemo')) AS ObjectName,
    'Returns object name from ID' AS Description;
/* Output example:
ObjectID    ObjectName    Description
581577110   MetadataDemo Returns object name from ID
*/

-- 3. COLUMNPROPERTY() - Check column properties
SELECT 
    'ID' AS ColumnName,
    COLUMNPROPERTY(OBJECT_ID('HR.MetadataDemo'), 'ID', 'IsIdentity') AS IsIdentity,
    COLUMNPROPERTY(OBJECT_ID('HR.MetadataDemo'), 'ID', 'Precision') AS Precision,
    COLUMNPROPERTY(OBJECT_ID('HR.MetadataDemo'), 'ID', 'Scale') AS Scale;
/* Output example:
ColumnName  IsIdentity  Precision  Scale
ID          1           10         0
*/

-- 4. INDEXPROPERTY() - Check index properties
SELECT 
    name AS IndexName,
    INDEXPROPERTY(OBJECT_ID('HR.MetadataDemo'), name, 'IsUnique') AS IsUnique,
    INDEXPROPERTY(OBJECT_ID('HR.MetadataDemo'), name, 'IsPrimary') AS IsPrimary,
    INDEXPROPERTY(OBJECT_ID('HR.MetadataDemo'), name, 'IsDisabled') AS IsDisabled
FROM sys.indexes
WHERE object_id = OBJECT_ID('HR.MetadataDemo');
/* Output example:
IndexName                    IsUnique  IsPrimary  IsDisabled
PK_MetadataDemo_ID           1         1          0
IX_MetadataDemo_Name         0         0          0
IX_MetadataDemo_CreatedDate  0         0          0
*/

-- 5. TYPEPROPERTY() - Check data type properties
SELECT 
    'varchar' AS DataType,
    TYPEPROPERTY('varchar', 'Precision') AS Precision,
    TYPEPROPERTY('varchar', 'Scale') AS Scale,
    TYPEPROPERTY('varchar', 'MaxLength') AS MaxLength;
/* Output example:
DataType  Precision  Scale  MaxLength
varchar   0          0      8000
*/

-- 6. DATABASEPROPERTYEX() - Get database properties
SELECT 
    DB_NAME() AS DatabaseName,
    DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS Collation,
    DATABASEPROPERTYEX(DB_NAME(), 'Recovery') AS RecoveryModel,
    DATABASEPROPERTYEX(DB_NAME(), 'IsAutoClose') AS IsAutoClose;
/* Output example:
DatabaseName  Collation           RecoveryModel  IsAutoClose
HRSystem      SQL_Latin1_General  FULL           0
*/

-- 7. SERVERPROPERTY() - Get server properties
SELECT 
    SERVERPROPERTY('ProductVersion') AS SQLServerVersion,
    SERVERPROPERTY('Edition') AS Edition,
    SERVERPROPERTY('InstanceName') AS InstanceName,
    SERVERPROPERTY('IsClustered') AS IsClustered;
/* Output example:
SQLServerVersion  Edition                InstanceName  IsClustered
15.0.2000.5      Developer Edition      NULL          0
*/

-- 8. SCHEMA_ID() and 9. SCHEMA_NAME() - Schema information
SELECT 
    'HR' AS SchemaName,
    SCHEMA_ID('HR') AS SchemaID,
    SCHEMA_NAME(SCHEMA_ID('HR')) AS ResolvedSchemaName;
/* Output example:
SchemaName  SchemaID  ResolvedSchemaName
HR          5         HR
*/

-- 10. TABLE_NAME() - Get table names
SELECT 
    OBJECT_ID('HR.MetadataDemo') AS TableID,
    OBJECT_SCHEMA_NAME(OBJECT_ID('HR.MetadataDemo')) AS SchemaName,
    TABLE_NAME(OBJECT_ID('HR.MetadataDemo')) AS TableName;
/* Output example:
TableID     SchemaName  TableName
581577110   HR          MetadataDemo
*/

-- 11. OBJECT_SCHEMA_NAME() - Get schema name of object
SELECT 
    name AS ObjectName,
    OBJECT_SCHEMA_NAME(object_id) AS SchemaName,
    type_desc AS ObjectType
FROM sys.objects
WHERE schema_id = SCHEMA_ID('HR');
/* Output example:
ObjectName    SchemaName  ObjectType
MetadataDemo  HR          USER_TABLE
*/

-- 12. OBJECT_DEFINITION() - Get object definition
SELECT 
    OBJECT_DEFINITION(OBJECT_ID('HR.MetadataDemo')) AS TableDefinition;
/* Output example:
TableDefinition
CREATE TABLE [HR].[MetadataDemo](...)
*/

-- 13. FILEGROUP_ID() and 14. FILEGROUP_NAME() - Filegroup information
SELECT 
    name AS FileGroupName,
    FILEGROUP_ID(name) AS FileGroupID,
    FILEGROUP_NAME(FILEGROUP_ID(name)) AS ResolvedFileGroupName
FROM sys.filegroups;
/* Output example:
FileGroupName  FileGroupID  ResolvedFileGroupName
PRIMARY        1            PRIMARY
HR_DATA        2            HR_DATA
*/

-- 15. INDEXKEY_PROPERTY() - Get index key properties
SELECT 
    i.name AS IndexName,
    c.name AS ColumnName,
    INDEXKEY_PROPERTY(OBJECT_ID('HR.MetadataDemo'), i.index_id, ic.index_column_id, 'IsDescending') AS IsDescending
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('HR.MetadataDemo');
/* Output example:
IndexName                    ColumnName    IsDescending
PK_MetadataDemo_ID           ID            0
IX_MetadataDemo_Name         Name          0
IX_MetadataDemo_CreatedDate  CreatedDate   0
*/

-- Complex example combining multiple metadata functions
SELECT 
    -- Object information
    OBJECT_NAME(o.object_id) AS TableName,
    OBJECT_SCHEMA_NAME(o.object_id) AS SchemaName,
    o.type_desc AS ObjectType,
    
    -- Column properties
    c.name AS ColumnName,
    t.name AS DataType,
    COLUMNPROPERTY(o.object_id, c.name, 'Precision') AS Precision,
    COLUMNPROPERTY(o.object_id, c.name, 'Scale') AS Scale,
    
    -- Index information
    i.name AS IndexName,
    INDEXPROPERTY(o.object_id, i.name, 'IsUnique') AS IsUnique,
    
    -- Storage information
    fg.name AS FileGroupName,
    DATABASEPROPERTYEX(DB_NAME(), 'Recovery') AS DatabaseRecoveryModel,
    
    -- Server context
    SERVERPROPERTY('ProductVersion') AS SQLServerVersion,
    
    -- Object definition (truncated)
    LEFT(OBJECT_DEFINITION(o.object_id), 100) AS ObjectDefinitionPreview
FROM sys.objects o
JOIN sys.columns c ON o.object_id = c.object_id
JOIN sys.types t ON c.user_type_id = t.user_type_id
LEFT JOIN sys.indexes i ON o.object_id = i.object_id AND i.index_id = 1
JOIN sys.filegroups fg ON o.lob_data_space_id = fg.data_space_id
WHERE o.object_id = OBJECT_ID('HR.MetadataDemo');
/* Output example:
TableName    SchemaName  ObjectType   ColumnName  DataType  Precision  Scale  IndexName          IsUnique  FileGroupName  DatabaseRecoveryModel  SQLServerVersion  ObjectDefinitionPreview
MetadataDemo HR          USER_TABLE   ID          int       10         0      PK_MetadataDemo_ID 1         HR_DATA        FULL                   15.0.2000.5       CREATE TABLE [HR].[MetadataDemo](...
*/