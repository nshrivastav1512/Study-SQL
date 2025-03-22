-- =============================================
-- SQL Server Bulk Insert Operations for HR Data
-- =============================================

/*
This script demonstrates various bulk data loading techniques for HR data:
- Understanding bulk insert operations and their benefits
- Different methods of bulk loading
- Performance optimization strategies
- Error handling and data validation
- Best practices for large-scale data loading
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: BULK INSERT BASICS
-- =============================================

/*
Bulk Insert Benefits:
1. Minimal Transaction Logging:
   - Uses bulk-logged recovery model
   - Reduces log space requirements
   - Improves performance

2. Memory Efficiency:
   - Optimized buffer usage
   - Reduced memory footprint
   - Better resource utilization

3. Performance Optimization:
   - Minimized row-by-row processing
   - Batch processing capabilities
   - Parallel loading options
*/

-- Example: Create Target Table for Employee Data
CREATE TABLE HR_Bulk_Employees (
    EmployeeID INT,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Department NVARCHAR(50),
    HireDate DATE,
    Salary DECIMAL(10,2)
);

-- Basic Bulk Insert from CSV
-- Note: Adjust the file path according to your environment
BULK INSERT HR_Bulk_Employees
FROM 'C:\HR_Data\employees.csv'
WITH (
    FIRSTROW = 2,              -- Skip header row
    FIELDTERMINATOR = ',',      -- CSV delimiter
    ROWTERMINATOR = '\n',       -- New line character
    MAXERRORS = 0,             -- Stop on first error
    CHECK_CONSTRAINTS          -- Validate constraints
);

-- =============================================
-- PART 2: ADVANCED BULK INSERT OPTIONS
-- =============================================

/*
Advanced Options:
1. Data Formatting:
   - Custom field terminators
   - Date formats
   - Character sets

2. Error Handling:
   - Error file generation
   - Row rejection thresholds
   - Constraint validation

3. Performance Settings:
   - Batch sizes
   - Transaction control
   - Index handling
*/

-- Example: Bulk Insert with Advanced Options
BULK INSERT HR_Bulk_Employees
FROM 'C:\HR_Data\employees.dat'
WITH (
    DATAFILETYPE = 'widenative',   -- Unicode data
    FORMATFILE = 'C:\HR_Data\employees.fmt',  -- Format file
    BATCHSIZE = 1000,              -- Records per batch
    FIRE_TRIGGERS,                 -- Enable triggers
    KEEPNULLS,                     -- Preserve NULL values
    ORDER (EmployeeID ASC)         -- Sort order
);

-- =============================================
-- PART 3: FORMAT FILES
-- =============================================

/*
Format File Components:
1. File Structure:
   - Column definitions
   - Data types
   - Field positions

2. Data Mapping:
   - Source to target mapping
   - Type conversions
   - Default values

Example Format File (employees.fmt):
<?xml version="1.0"?>
<BCPFORMAT xmlns="http://schemas.microsoft.com/sqlserver/2004/bulkload/format">
    <RECORD>
        <FIELD ID="1" xsi:type="CharTerm" TERMINATOR="," MAX_LENGTH="10"/>
        <FIELD ID="2" xsi:type="CharTerm" TERMINATOR="," MAX_LENGTH="50"/>
        <FIELD ID="3" xsi:type="CharTerm" TERMINATOR="," MAX_LENGTH="50"/>
        <FIELD ID="4" xsi:type="CharTerm" TERMINATOR="," MAX_LENGTH="50"/>
        <FIELD ID="5" xsi:type="CharTerm" TERMINATOR="," MAX_LENGTH="10"/>
        <FIELD ID="6" xsi:type="CharTerm" TERMINATOR="\r\n" MAX_LENGTH="20"/>
    </RECORD>
</BCPFORMAT>
*/

-- =============================================
-- PART 4: ERROR HANDLING AND VALIDATION
-- =============================================

/*
Validation Strategies:
1. Pre-load Validation:
   - Data type checking
   - Business rule validation
   - Referential integrity

2. Error Handling:
   - Error file logging
   - Invalid row redirection
   - Transaction management
*/

-- Create Error Log Table
CREATE TABLE HR_Bulk_ErrorLog (
    ErrorID INT IDENTITY(1,1) PRIMARY KEY,
    FileName NVARCHAR(255),
    ErrorNumber INT,
    ErrorMessage NVARCHAR(MAX),
    ErrorLine INT,
    ErrorTime DATETIME DEFAULT GETDATE()
);

-- Example: Bulk Insert with Error Handling
BEGIN TRY
    BULK INSERT HR_Bulk_Employees
    FROM 'C:\HR_Data\employees_with_errors.csv'
    WITH (
        ERRORFILE = 'C:\HR_Data\errors.log',
        MAXERRORS = 10,
        CHECK_CONSTRAINTS
    );
END TRY
BEGIN CATCH
    INSERT INTO HR_Bulk_ErrorLog (FileName, ErrorNumber, ErrorMessage, ErrorLine)
    VALUES (
        'employees_with_errors.csv',
        ERROR_NUMBER(),
        ERROR_MESSAGE(),
        ERROR_LINE()
    );
END CATCH;

-- =============================================
-- PART 5: PERFORMANCE OPTIMIZATION
-- =============================================

/*
Optimization Techniques:
1. Index Management:
   - Disable indexes before load
   - Rebuild after completion
   - Statistics update

2. Resource Configuration:
   - Memory allocation
   - Degree of parallelism
   - TempDB settings

3. File Organization:
   - File partitioning
   - Sort order
   - Batch sizing
*/

-- Example: Optimized Bulk Insert
BEGIN TRANSACTION;

-- Disable indexes
ALTER INDEX ALL ON HR_Bulk_Employees DISABLE;

-- Perform bulk insert
BULK INSERT HR_Bulk_Employees
FROM 'C:\HR_Data\employees.csv'
WITH (
    BATCHSIZE = 5000,
    TABLOCK,              -- Table-level locking
    ORDER (EmployeeID),   -- Ordered data
    ROWS_PER_BATCH = 0    -- Optimize for performance
);

-- Rebuild indexes
ALTER INDEX ALL ON HR_Bulk_Employees REBUILD;

-- Update statistics
UPDATE STATISTICS HR_Bulk_Employees WITH FULLSCAN;

COMMIT TRANSACTION;

-- =============================================
-- PART 6: BEST PRACTICES AND MONITORING
-- =============================================

/*
Best Practices:
1. Data Preparation:
   - Clean and validate source data
   - Consistent formatting
   - Remove duplicates

2. System Configuration:
   - Recovery model selection
   - File growth settings
   - Lock escalation

3. Monitoring:
   - Progress tracking
   - Resource usage
   - Performance metrics
*/

-- Create Monitoring Table
CREATE TABLE HR_Bulk_LoadStats (
    LoadID INT IDENTITY(1,1) PRIMARY KEY,
    SourceFile NVARCHAR(255),
    StartTime DATETIME,
    EndTime DATETIME,
    RowsLoaded INT,
    ErrorCount INT,
    Status NVARCHAR(20)
);

-- Example: Monitor Bulk Insert Progress
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @RowCount INT;

BULK INSERT HR_Bulk_Employees
FROM 'C:\HR_Data\employees.csv'
WITH (TABLOCK);

SET @RowCount = @@ROWCOUNT;

INSERT INTO HR_Bulk_LoadStats
    (SourceFile, StartTime, EndTime, RowsLoaded, ErrorCount, Status)
VALUES
    ('employees.csv', 
     @StartTime,
     GETDATE(),
     @RowCount,
     0,
     'Completed');