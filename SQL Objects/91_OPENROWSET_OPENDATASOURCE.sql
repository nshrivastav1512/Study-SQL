-- =============================================
-- SQL Server OPENROWSET and OPENDATASOURCE for HR Data Access
-- =============================================

/*
This script demonstrates using OPENROWSET and OPENDATASOURCE for external HR data access:
- Understanding ad-hoc connection methods
- Querying various data sources
- Security considerations
- Performance optimization
- Best practices for external data access
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: OPENROWSET BASICS
-- =============================================

/*
OPENROWSET Benefits:
1. Ad-hoc Queries:
   - No linked server required
   - Flexible data source access
   - One-time query needs

2. Multiple Provider Support:
   - SQL Server
   - OLE DB
   - ODBC
   - Flat files

3. Use Cases:
   - Import external HR data
   - Cross-database reporting
   - Data validation
*/

-- Example: Query Excel File using OPENROWSET
-- Note: Replace provider and file path as needed
/*
SELECT *
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\HR_Data\Employee_Records.xlsx',
    'SELECT * FROM [EmployeeSheet$]'
) AS ExcelData;
*/

-- Example: Query CSV File using OPENROWSET with BULK
/*
SELECT *
FROM OPENROWSET(
    BULK 'C:\HR_Data\employee_data.csv',
    SINGLE_CLOB
) AS CSVData;
*/

-- =============================================
-- PART 2: OPENDATASOURCE FUNCTIONALITY
-- =============================================

/*
OPENDATASOURCE Features:
1. Connection Reuse:
   - Multiple queries in same batch
   - Consistent connection settings
   - Resource efficiency

2. Provider Configuration:
   - Connection string parameters
   - Authentication options
   - Network settings

3. Data Source Types:
   - Remote SQL Servers
   - Oracle databases
   - Other OLEDB sources
*/

-- Example: Query Remote SQL Server using OPENDATASOURCE
/*
SELECT *
FROM OPENDATASOURCE(
    'SQLNCLI', -- SQL Server Native Client
    'Data Source=RemoteServer;Initial Catalog=HRDatabase;
     User ID=HRReader;Password=****'
).HRDatabase.dbo.Employees;
*/

-- =============================================
-- PART 3: SECURITY CONSIDERATIONS
-- =============================================

/*
Security Best Practices:
1. Authentication:
   - Use Windows Authentication when possible
   - Secure credential management
   - Avoid hardcoded passwords

2. Network Security:
   - Encryption settings
   - Firewall configuration
   - Protocol security

3. Permission Management:
   - Minimal required permissions
   - Role-based access
   - Audit logging
*/

-- Example: Configure Security Context
SP_CONFIGURE 'show advanced options', 1;
GO
RECONFIGURE;
GO

-- Enable Ad Hoc Distributed Queries
SP_CONFIGURE 'Ad Hoc Distributed Queries', 1;
GO
RECONFIGURE;
GO

-- Create Credentials for External Access
/*
CREATE CREDENTIAL HR_DataSource_Cred
WITH IDENTITY = 'HRReader',
     SECRET = '****';
*/

-- =============================================
-- PART 4: PERFORMANCE OPTIMIZATION
-- =============================================

/*
Performance Considerations:
1. Query Optimization:
   - Filter data at source
   - Minimize data transfer
   - Use appropriate indexes

2. Connection Management:
   - Connection pooling
   - Timeout settings
   - Resource governance

3. Data Transfer:
   - Batch processing
   - Compression options
   - Network optimization
*/

-- Example: Optimized External Query
/*
SELECT e.EmployeeID, e.Name, d.DepartmentName
FROM OPENDATASOURCE(
    'SQLNCLI',
    'Data Source=RemoteServer;Initial Catalog=HRDatabase;
     Integrated Security=SSPI;Connection Timeout=30'
).HRDatabase.dbo.Employees e
INNER JOIN HRSystem.dbo.Departments d
    ON e.DepartmentID = d.DepartmentID
WHERE e.HireDate >= DATEADD(year, -1, GETDATE());
*/

-- =============================================
-- PART 5: ERROR HANDLING
-- =============================================

/*
Error Handling Strategies:
1. Connection Errors:
   - Retry logic
   - Timeout handling
   - Alternative sources

2. Data Validation:
   - Type conversion
   - NULL handling
   - Constraint checking

3. Error Logging:
   - Detailed error messages
   - Audit trail
   - Notification system
*/

-- Create Error Log Table
CREATE TABLE External_Query_ErrorLog (
    ErrorID INT IDENTITY(1,1) PRIMARY KEY,
    QuerySource NVARCHAR(100),
    ErrorNumber INT,
    ErrorMessage NVARCHAR(MAX),
    ErrorTime DATETIME DEFAULT GETDATE()
);

-- Example: Error Handling for External Query
BEGIN TRY
    /*
    SELECT *
    FROM OPENROWSET(
        'Microsoft.ACE.OLEDB.12.0',
        'Excel 12.0;Database=C:\HR_Data\Employee_Records.xlsx',
        'SELECT * FROM [InvalidSheet$]'
    ) AS ExcelData;
    */
END TRY
BEGIN CATCH
    INSERT INTO External_Query_ErrorLog
        (QuerySource, ErrorNumber, ErrorMessage)
    VALUES
        ('Employee_Records.xlsx',
         ERROR_NUMBER(),
         ERROR_MESSAGE());
    
    -- Optionally, raise custom error
    THROW 50000, 'External data access failed', 1;
END CATCH;

-- =============================================
-- PART 6: MONITORING AND MAINTENANCE
-- =============================================

/*
Monitoring Strategy:
1. Performance Metrics:
   - Query execution time
   - Resource usage
   - Connection statistics

2. Health Checks:
   - Connection availability
   - Permission validation
   - Data consistency

3. Maintenance Tasks:
   - Cache clearing
   - Statistics updates
   - Connection testing
*/

-- Create Monitoring Table
CREATE TABLE External_Query_Stats (
    StatID INT IDENTITY(1,1) PRIMARY KEY,
    QuerySource NVARCHAR(100),
    ExecutionTime DATETIME,
    Duration DECIMAL(10,2),
    RowsProcessed INT,
    Status NVARCHAR(20)
);

-- Example: Monitor External Query Performance
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @RowCount INT;

/*
SELECT @RowCount = COUNT(*)
FROM OPENDATASOURCE(
    'SQLNCLI',
    'Data Source=RemoteServer;Initial Catalog=HRDatabase;
     Integrated Security=SSPI'
).HRDatabase.dbo.Employees;

INSERT INTO External_Query_Stats
    (QuerySource, ExecutionTime, Duration, RowsProcessed, Status)
VALUES
    ('Remote HR Database',
     @StartTime,
     DATEDIFF(millisecond, @StartTime, GETDATE()),
     @RowCount,
     'Completed');
*/