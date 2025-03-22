-- =============================================
-- BULK Operations Complete Guide
-- =============================================

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