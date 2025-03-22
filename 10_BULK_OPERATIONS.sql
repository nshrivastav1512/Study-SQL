-- =============================================
-- BULK Operations Complete Guide
-- =============================================
/*
-- BULK Operations Complete Guide
-- BULK operations in SQL Server are specialized data import and export mechanisms designed for high-performance transfer of large data sets between files and SQL Server tables. These operations include BULK INSERT, OPENROWSET(BULK...), and BCP (Bulk Copy Program) commands, providing efficient ways to load or extract large volumes of data.

Facts and Notes:
- Significantly faster than regular INSERT operations for large datasets
- Minimally logged when appropriate conditions are met
- Supports various file formats including CSV, fixed-width, native, and XML
- Can use format files to define complex data mappings
- BCP utility provides command-line interface for bulk operations
- Supports both character and native (binary) data formats
- Can handle Unicode and non-Unicode data
- Allows specification of code pages for international character sets

Important Considerations:
- Requires appropriate file system permissions
- Table locks may impact concurrent operations
- Minimal logging requires specific recovery model and table conditions
- Format files must match exact data file structure
- Error handling requires careful configuration
- Network file paths may require specific security configurations
- Performance varies based on chosen options and constraints
- Batch size affects transaction log usage and recovery capabilities

1. Basic BULK INSERT: This section demonstrates fundamental BULK INSERT syntax with CSV files, including basic options for field terminators, row terminators, and encoding specifications.
2. BULK INSERT with Format File: This section covers using format files to define complex data mappings and handle various data file formats with precise control over data import.
3. OPENROWSET with BULK: This section shows alternative approach using OPENROWSET for bulk data loading, offering more flexibility in data selection and transformation.
4. BULK INSERT with XML Data: This section illustrates handling XML data files in bulk operations, including proper configuration for XML data types and encoding.
5. BULK INSERT with Table Lock: This section demonstrates performance optimization techniques using table locks and batch sizing for large data imports.
6. BULK INSERT with Error Handling: This section covers implementing error handling and logging for bulk operations, including error file configuration and maximum error thresholds.
7. OPENROWSET with Multiple Files: This section shows techniques for combining data from multiple source files in a single bulk operation using OPENROWSET.
8. BULK INSERT with Data Transformation: This section illustrates staging and transforming data during bulk import operations using intermediate tables and data parsing.
9. BCP Command Examples: This section provides examples of using the BCP utility for both import and export operations, including format file generation.
10. BULK INSERT with Partitioned Table: This section demonstrates bulk loading data into partitioned tables with appropriate ordering and batch size considerations.

Author: Nikhil Shrivastav
Date: February 2025
*/
USE HRSystem;
GO

-- 1. Basic BULK INSERT
-- First, create a target table
CREATE TABLE HR.ImportedEmployees (
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Email VARCHAR(100),
    Department VARCHAR(50),
    Salary DECIMAL(12,2)
);
GO

-- Basic BULK INSERT from CSV (Not working)
BULK INSERT HR.ImportedEmployees
FROM 'C:\AI Use and Deveopment\Study SQL\Data\employees.csv'
WITH (
    FORMAT = 'CSV',  -- Specify CSV format
    FIRSTROW = 2,    -- Skip header row
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',  -- Windows line ending
    CODEPAGE = '65001',      -- UTF-8 encoding
    KEEPNULLS,              -- Preserve NULL values
    TABLOCK                 -- Table lock for better performance
);

-- 2. BULK INSERT with Format File (not working)
BULK INSERT HR.ImportedEmployees
FROM 'C:\AI Use and Deveopment\Study SQL\Data\employees.dat'
WITH (
    FORMATFILE = 'C:\AI Use and Deveopment\Study SQL\Data\employees.fmt',
    DATAFILETYPE = 'widechar',
    ERRORFILE = 'C:\AI Use and Deveopment\Study SQL\Data\errors.log'
);

-- 3. OPENROWSET with BULK
INSERT INTO HR.ImportedEmployees
SELECT *    
FROM OPENROWSET(
    BULK 'C:\AI Use and Deveopment\Study SQL\Data\employees.csv',
    FORMATFILE = 'C:\AI Use and Deveopment\Study SQL\Data\employees.fmt',
    FIRSTROW = 2
) AS DataSource;

-- 4. BULK INSERT with XML Data
CREATE TABLE HR.ImportedXMLData (
    XMLData XML
);

BULK INSERT HR.ImportedXMLData
FROM 'C:\AI Use and Deveopment\Study SQL\Data\employees.xml'
WITH (
    DATAFILETYPE = 'widechar',
    ROWTERMINATOR = '\n'
);

-- 5. BULK INSERT with Table Lock
BULK INSERT HR.ImportedEmployees
FROM 'C:\AI Use and Deveopment\Study SQL\Data\new_employees.csv'
WITH (
    TABLOCK,
    ROWS_PER_BATCH = 10000,
    BATCHSIZE = 5000
);

-- 6. BULK INSERT with Error Handling
CREATE TABLE HR.BulkImportErrors (
    ErrorID INT IDENTITY(1,1) PRIMARY KEY,
    ErrorDateTime DATETIME DEFAULT GETDATE(),
    ErrorMessage VARCHAR(1000),
    RowData VARCHAR(MAX)
);
GO

BEGIN TRY
    BULK INSERT HR.ImportedEmployees
    FROM 'C:\AI Use and Deveopment\Study SQL\Data\employees_with_errors.csv'
    WITH (
        MAXERRORS = 10,
        ERRORFILE = 'C:\AI Use and Deveopment\Study SQL\Data\bulk_errors.log',
        KEEPNULLS
    );
END TRY
BEGIN CATCH
    INSERT INTO HR.BulkImportErrors (ErrorMessage)
    VALUES (ERROR_MESSAGE());
END CATCH;

-- 7. OPENROWSET with Multiple Files
INSERT INTO HR.ImportedEmployees
SELECT *
FROM (
    SELECT * FROM OPENROWSET(
        BULK 'C:\AI Use and Deveopment\Study SQL\Data\employees1.csv',
        FORMATFILE = 'C:\AI Use and Deveopment\Study SQL\Data\employees.fmt'
    ) AS File1
    UNION ALL
    SELECT * FROM OPENROWSET(
        BULK 'C:\AI Use and Deveopment\Study SQL\Data\employees2.csv',
        FORMATFILE = 'C:\AI Use and Deveopment\Study SQL\Data\employees.fmt'
    ) AS File2
) AS CombinedData;

-- 8. BULK INSERT with Data Transformation
-- Create staging table
CREATE TABLE #StagingEmployees (
    RawData VARCHAR(MAX)
);

-- Bulk insert into staging
BULK INSERT #StagingEmployees
FROM 'C:\AI Use and Deveopment\Study SQL\Data\raw_employees.txt'
WITH (
    ROWTERMINATOR = '\n'
);

-- Transform and insert into final table
INSERT INTO HR.ImportedEmployees
SELECT 
    PARSENAME(RawData, 4) AS FirstName,
    PARSENAME(RawData, 3) AS LastName,
    PARSENAME(RawData, 2) AS Email,
    PARSENAME(RawData, 1) AS Department,
    0 AS Salary
FROM #StagingEmployees;

-- 9. BCP Command Examples (Run in Command Prompt)
/*
-- Export data
bcp HRSystem.HR.ImportedEmployees out "C:\AI Use and Deveopment\Study SQL\Data\exported_employees.dat" -c -T

-- Import data
bcp HRSystem.HR.ImportedEmployees in "C:\AI Use and Deveopment\Study SQL\Data\imported_employees.dat" -c -T

-- Export with format file
bcp HRSystem.HR.ImportedEmployees format nul -c -f "C:\AI Use and Deveopment\Study SQL\Data\employees.fmt" -T
*/

-- 10. BULK INSERT with Partitioned Table
BULK INSERT HR.PartitionedEmployees
FROM 'C:\AI Use and Deveopment\Study SQL\Data\employees_by_region.csv'
WITH (
    ORDER (EmployeeID ASC),
    ROWS_PER_BATCH = 10000
);