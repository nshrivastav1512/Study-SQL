-- =============================================
-- DQL Advanced Performance Optimization
-- =============================================

USE HRSystem;
GO

-- 1. Using Plan Guides
-- Force specific execution plans for queries you can't modify
EXEC sp_create_plan_guide 
    @name = N'PG_EmpDetails_ByDept',
    @stmt = N'SELECT EmployeeID, FirstName, LastName FROM HR.EMP_Details WHERE DepartmentID = @dept',
    @type = N'SQL',
    @module_or_batch = NULL,
    @params = N'@dept int',
    @hints = N'OPTION (OPTIMIZE FOR (@dept = 1), MAXDOP 1)';
-- Forces specific plan for parameterized queries
-- Useful for third-party applications where code can't be changed
-- Helps stabilize performance for critical queries

-- 2. Memory-Optimized Tables
-- Use in-memory OLTP for high-performance scenarios
CREATE TABLE HR.HighFrequencyLogs (
    LogID BIGINT IDENTITY PRIMARY KEY NONCLUSTERED,
    LogTime DATETIME2 NOT NULL,
    LogMessage NVARCHAR(1000),
    LogLevel TINYINT,
    INDEX IX_LogTime HASH (LogTime) WITH (BUCKET_COUNT = 1000000)
) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);
-- Stores data in memory instead of disk
-- Eliminates latches and locks for higher concurrency
-- Hash indexes provide O(1) lookup performance
-- Significantly faster for high-throughput scenarios

-- 3. Columnstore Indexes
-- Optimized for analytical queries and data warehousing
CREATE CLUSTERED COLUMNSTORE INDEX CCI_OrderHistory 
ON HR.OrderHistory;
-- Stores data by column instead of by row
-- Highly compressed format reduces I/O
-- Excellent for aggregation queries on large datasets
-- Can improve query performance by 10-100x for analytical workloads

-- 4. Spatial Index Optimization
-- Improve performance of geographic queries
CREATE SPATIAL INDEX SIndx_Locations_Geo
ON HR.Locations(LocationGeo)
USING GEOGRAPHY_GRID
WITH (
    GRIDS = (LEVEL_1 = MEDIUM, LEVEL_2 = MEDIUM, LEVEL_3 = MEDIUM, LEVEL_4 = MEDIUM),
    CELLS_PER_OBJECT = 16,
    PAD_INDEX = ON
);
-- Optimizes spatial data queries
-- Configures appropriate grid density for data distribution
-- Improves performance of proximity and containment queries

-- 5. Optimizing for Specific Hardware
-- Tailor database settings to server capabilities
ALTER DATABASE HRSystem SET TARGET_RECOVERY_TIME = 60 SECONDS;
ALTER DATABASE HRSystem MODIFY FILE (NAME = HRSystem_Data, SIZE = 10GB, FILEGROWTH = 1GB);
ALTER DATABASE HRSystem SET MIXED_PAGE_ALLOCATION OFF;
-- Recovery time target optimizes for modern storage
-- Appropriate file sizes reduce auto-growth events
-- Hardware-specific settings maximize performance

-- 6. Intelligent Query Processing
-- Enable SQL Server 2019+ features for adaptive processing
ALTER DATABASE HRSystem SET COMPATIBILITY_LEVEL = 150;
ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_ON_ROWSTORE = ON;
ALTER DATABASE SCOPED CONFIGURATION SET DEFERRED_COMPILATION_TV = ON;
-- Enables latest query processing features
-- Batch mode on rowstore for faster analytics
-- Adaptive joins and memory grant feedback
-- Automatic tuning capabilities

-- 7. Query Hints for Specific Scenarios
-- Fine-tune execution for edge cases
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName
FROM HR.EMP_Details e WITH (FORCESEEK, ROWLOCK)
JOIN HR.Departments d WITH (NOLOCK) ON e.DepartmentID = d.DepartmentID
WHERE e.Salary > 50000
OPTION (RECOMPILE, FAST 10, MAXRECURSION 0);
-- FORCESEEK: Forces index seek operations
-- ROWLOCK: Uses row-level locking
-- NOLOCK: Reduces blocking (with consistency tradeoffs)
-- RECOMPILE: Creates optimal plan each execution
-- FAST: Returns first N percent of rows quickly

-- 8. Optimizing for Concurrency
-- Balance performance with multi-user scenarios
ALTER TABLE HR.EMP_Details SET (LOCK_ESCALATION = DISABLE);
-- Prevents lock escalation from row to table
-- Improves concurrency in multi-user environments
-- Reduces blocking in high-contention scenarios

-- 9. Resource Governor
-- Manage resource usage for different workloads
CREATE RESOURCE POOL ReportingPool WITH (
    MAX_CPU_PERCENT = 40,
    MIN_CPU_PERCENT = 10,
    MAX_MEMORY_PERCENT = 50,
    MIN_MEMORY_PERCENT = 10
);

CREATE WORKLOAD GROUP ReportingGroup WITH (
    IMPORTANCE = LOW,
    REQUEST_MAX_MEMORY_GRANT_PERCENT = 25,
    REQUEST_MAX_CPU_TIME_SEC = 180,
    MAX_DOP = 4,
    GROUP_MAX_REQUESTS = 10
) USING ReportingPool;
-- Limits resources used by reporting queries
-- Prevents reporting workloads from impacting transactional systems
-- Provides predictable performance for different user groups

-- 10. Optimizing Parameterized Queries
-- Avoid parameter sniffing issues
DECLARE @DeptID INT = 3;
DECLARE @MinSalary DECIMAL(10,2) = 50000;

-- Option 1: Use local variables (prevents parameter sniffing)
SELECT 
    EmployeeID,
    FirstName,
    LastName
FROM HR.EMP_Details
WHERE DepartmentID = @DeptID AND Salary > @MinSalary;

-- Option 2: Use OPTIMIZE FOR hint
SELECT 
    EmployeeID,
    FirstName,
    LastName
FROM HR.EMP_Details
WHERE DepartmentID = @DeptID AND Salary > @MinSalary
OPTION (OPTIMIZE FOR (@DeptID UNKNOWN, @MinSalary = 60000));

-- Option 3: Use RECOMPILE hint
SELECT 
    EmployeeID,
    FirstName,
    LastName
FROM HR.EMP_Details
WHERE DepartmentID = @DeptID AND Salary > @MinSalary
OPTION (RECOMPILE);
-- Addresses parameter sniffing problems
-- Different approaches for different scenarios
-- Balances plan reuse with optimal execution

-- 11. Optimizing for OLAP vs OLTP
-- Different strategies for different workloads
-- OLTP optimization (high concurrency, point queries)
CREATE NONCLUSTERED INDEX IX_EMP_Email
ON HR.EMP_Details (Email)
INCLUDE (FirstName, LastName, DepartmentID);

-- OLAP optimization (analytical queries)
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_EMP_Analytics
ON HR.EMP_Details (DepartmentID, JobTitle, Salary, HireDate);
-- OLTP: Targeted indexes for specific lookups
-- OLAP: Columnstore indexes for analytical queries
-- Different index strategies for different query patterns

-- 12. Optimizing Execution Plans
-- Stabilize and improve plan quality
ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON;
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = ON;
ALTER DATABASE SCOPED CONFIGURATION SET ELEVATE_ONLINE = WHEN_SUPPORTED;
-- Enables latest optimizer improvements
-- Parameter-sensitive plans for varying data distributions
-- Applies hotfixes to query optimizer
-- Improves plan quality and stability

-- 13. Optimizing Tempdb
-- Reduce tempdb contention
ALTER DATABASE tempdb MODIFY FILE (NAME = 'tempdev', SIZE = 1GB, FILEGROWTH = 256MB);
-- Add multiple data files for tempdb
ALTER DATABASE tempdb ADD FILE (NAME = 'tempdev2', FILENAME = 'D:\tempdb2.ndf', SIZE = 1GB);
ALTER DATABASE tempdb ADD FILE (NAME = 'tempdev3', FILENAME = 'D:\tempdb3.ndf', SIZE = 1GB);
ALTER DATABASE tempdb ADD FILE (NAME = 'tempdev4', FILENAME = 'D:\tempdb4.ndf', SIZE = 1GB);
-- Multiple files reduce allocation page contention
-- Proper sizing reduces auto-growth events
-- Critical for workloads that use temp tables heavily

-- 14. Optimizing for Cloud Environments
-- Special considerations for Azure SQL Database
SELECT 
    EmployeeID,
    FirstName,
    LastName
FROM HR.EMP_Details
WHERE DepartmentID = 3
OPTION (LABEL = 'HR_Department_Lookup');
-- LABEL helps identify queries in monitoring tools
-- Consider elastic pools for variable workloads
-- Different optimization strategies for PaaS vs IaaS

-- 15. Optimizing Stored Procedures
-- Improve procedure performance and plan stability
CREATE OR ALTER PROCEDURE HR.GetEmployeesByDepartment
    @DepartmentID INT,
    @MinSalary DECIMAL(10,2) = 0
WITH RECOMPILE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Use table variable for small result sets
    DECLARE @Results TABLE (
        EmployeeID INT,
        FullName NVARCHAR(100),
        Salary DECIMAL(10,2)
    );
    
    -- Populate with filtered data
    INSERT INTO @Results
    SELECT 
        EmployeeID,
        FirstName + ' ' + LastName,
        Salary
    FROM HR.EMP_Details
    WHERE DepartmentID = @DepartmentID
      AND Salary > @MinSalary;
    
    -- Return results
    SELECT * FROM @Results ORDER BY Salary DESC;
END;
-- WITH RECOMPILE creates optimal plan each execution
-- SET NOCOUNT ON reduces network traffic
-- Table variables for intermediate results
-- Modular design improves maintainability