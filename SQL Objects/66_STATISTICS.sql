-- =============================================
-- STATISTICS Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Statistics, including:
- What statistics are and why they're important for query optimization
- How SQL Server creates and uses statistics
- Auto-creation and auto-update of statistics
- Manually creating and updating statistics
- Viewing statistics information
- Troubleshooting performance issues related to statistics
- Best practices for statistics management
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: STATISTICS FUNDAMENTALS
-- =============================================

-- What are Statistics?
-- Statistics are objects that contain information about the distribution of values in one or more columns of a table
-- SQL Server uses statistics to estimate the cardinality (number of rows) for query plan optimization

-- Benefits of Statistics:
-- 1. Help the query optimizer create efficient execution plans
-- 2. Improve query performance by making better join, filter, and aggregation decisions
-- 3. Enable cost-based decisions for index usage

-- =============================================
-- PART 2: AUTOMATIC STATISTICS MANAGEMENT
-- =============================================

-- 1. Auto-creation of statistics
-- By default, SQL Server automatically creates statistics for columns used in:
-- - WHERE clauses
-- - JOIN conditions
-- - GROUP BY clauses
-- - ORDER BY clauses

-- Check auto-create statistics setting for the database
SELECT name, is_auto_create_stats_on
FROM sys.databases
WHERE name = 'HRSystem';

-- Enable auto-create statistics (if not already enabled)
ALTER DATABASE HRSystem SET AUTO_CREATE_STATISTICS ON;

-- 2. Auto-update of statistics
-- SQL Server automatically updates statistics when data changes significantly

-- Check auto-update statistics setting for the database
SELECT name, is_auto_update_stats_on
FROM sys.databases
WHERE name = 'HRSystem';

-- Enable auto-update statistics (if not already enabled)
ALTER DATABASE HRSystem SET AUTO_UPDATE_STATISTICS ON;

-- 3. Auto-update statistics asynchronously
-- Updates statistics in the background without blocking queries

-- Check async stats update setting
SELECT name, is_auto_update_stats_async_on
FROM sys.databases
WHERE name = 'HRSystem';

-- Enable async stats updates
ALTER DATABASE HRSystem SET AUTO_UPDATE_STATISTICS_ASYNC ON;

-- =============================================
-- PART 3: MANUALLY MANAGING STATISTICS
-- =============================================

-- 1. Create statistics manually
-- Useful for columns not automatically covered or for multi-column statistics

-- Create single-column statistics
CREATE STATISTICS Stats_EMP_HireDate ON HR.EMP_Details(HireDate);

-- Create multi-column statistics (column order matters!)
CREATE STATISTICS Stats_EMP_Dept_Salary ON HR.EMP_Details(DepartmentID, Salary);

-- Create filtered statistics (SQL Server 2008+)
CREATE STATISTICS Stats_EMP_HighSalary ON HR.EMP_Details(Salary)
WHERE Salary > 50000;

-- 2. Update statistics manually
-- Useful before running important queries or after bulk operations

-- Update all statistics for a table
UPDATE STATISTICS HR.EMP_Details;

-- Update specific statistics
UPDATE STATISTICS HR.EMP_Details Stats_EMP_HireDate;

-- Update with full scan (most accurate but more resource-intensive)
UPDATE STATISTICS HR.EMP_Details WITH FULLSCAN;

-- Update with a sampling (balance between accuracy and performance)
UPDATE STATISTICS HR.EMP_Details WITH SAMPLE 50 PERCENT;

-- Update with specific number of rows to sample
UPDATE STATISTICS HR.EMP_Details WITH SAMPLE 1000 ROWS;

-- 3. Drop statistics when no longer needed
DROP STATISTICS HR.EMP_Details.Stats_EMP_HireDate;

-- =============================================
-- PART 4: VIEWING STATISTICS INFORMATION
-- =============================================

-- 1. List all statistics for a table
SELECT 
    s.name AS statistics_name,
    OBJECT_NAME(s.object_id) AS table_name,
    COL_NAME(sc.object_id, sc.column_id) AS column_name,
    s.auto_created,
    s.user_created,
    s.no_recompute,
    s.has_filter,
    s.filter_definition,
    STATS_DATE(s.object_id, s.stats_id) AS last_updated
FROM sys.stats s
JOIN sys.stats_columns sc ON s.stats_id = sc.stats_id AND s.object_id = sc.object_id
WHERE s.object_id = OBJECT_ID('HR.EMP_Details')
ORDER BY s.name, sc.stats_column_id;

-- 2. View detailed statistics information
-- DBCC SHOW_STATISTICS shows the histogram and density information
DBCC SHOW_STATISTICS ('HR.EMP_Details', 'Stats_EMP_HireDate');

-- 3. View statistics properties using DMVs
SELECT 
    OBJECT_NAME(s.object_id) AS TableName,
    s.name AS StatisticsName,
    s.stats_id,
    sp.last_updated,
    sp.rows,
    sp.rows_sampled,
    sp.steps AS HistogramSteps,
    sp.unfiltered_rows,
    sp.modification_counter AS RowsModified
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE s.object_id = OBJECT_ID('HR.EMP_Details');

-- =============================================
-- PART 5: STATISTICS AND QUERY PERFORMANCE
-- =============================================

-- 1. Outdated statistics can lead to poor query plans
-- Example query with potentially outdated statistics
SELECT * FROM HR.EMP_Details WHERE Salary > 50000;

-- Update statistics before running important queries
UPDATE STATISTICS HR.EMP_Details WITH FULLSCAN;
-- Run the query again and compare execution plans

-- 2. Missing statistics can cause suboptimal plans
-- Query using a column without statistics
SELECT * FROM HR.EMP_Details WHERE PhoneNumber LIKE '555%';

-- Create statistics for the column
CREATE STATISTICS Stats_EMP_Phone ON HR.EMP_Details(PhoneNumber);
-- Run the query again and compare execution plans

-- 3. Using trace flags to see statistics usage
-- Enable trace flag 9204 to see statistics used during optimization
-- DBCC TRACEON(9204, -1); -- Commented out as it affects server-wide behavior

-- =============================================
-- PART 6: TROUBLESHOOTING STATISTICS ISSUES
-- =============================================

-- 1. Identifying outdated statistics
SELECT 
    OBJECT_NAME(s.object_id) AS TableName,
    s.name AS StatisticsName,
    sp.last_updated,
    sp.rows,
    sp.modification_counter,
    CAST(100.0 * sp.modification_counter / NULLIF(sp.rows, 0) AS DECIMAL(18,2)) AS PercentModified
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE 
    OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
    AND (sp.modification_counter > 0)
ORDER BY PercentModified DESC;

-- 2. Fixing parameter sniffing issues related to statistics
-- Problem query with parameter sniffing
DECLARE @Salary DECIMAL(10,2) = 30000;
SELECT * FROM HR.EMP_Details WHERE Salary > @Salary;

-- Solution 1: Update statistics
UPDATE STATISTICS HR.EMP_Details WITH FULLSCAN;

-- Solution 2: Use OPTIMIZE FOR hint
DECLARE @Salary DECIMAL(10,2) = 30000;
SELECT * FROM HR.EMP_Details 
WHERE Salary > @Salary
OPTION (OPTIMIZE FOR (@Salary = 50000));

-- Solution 3: Use OPTIMIZE FOR UNKNOWN
DECLARE @Salary DECIMAL(10,2) = 30000;
SELECT * FROM HR.EMP_Details 
WHERE Salary > @Salary
OPTION (OPTIMIZE FOR UNKNOWN);

-- Solution 4: Use RECOMPILE hint
DECLARE @Salary DECIMAL(10,2) = 30000;
SELECT * FROM HR.EMP_Details 
WHERE Salary > @Salary
OPTION (RECOMPILE);

-- 3. Handling ascending key problem (e.g., date columns)
-- When new values are always higher than existing ones

-- Create statistics with FULLSCAN to get accurate histogram
CREATE STATISTICS Stats_EMP_HireDate_Full ON HR.EMP_Details(HireDate) WITH FULLSCAN;

-- Or use trace flag 2389 to enable dynamic statistics sampling
-- DBCC TRACEON(2389, -1); -- Commented out as it affects server-wide behavior

-- =============================================
-- PART 7: STATISTICS MAINTENANCE STRATEGIES
-- =============================================

-- 1. Regular maintenance for critical tables

-- Create a stored procedure for statistics maintenance
CREATE OR ALTER PROCEDURE HR.UpdateStatistics
AS
BEGIN
    -- Update statistics for frequently modified tables with FULLSCAN
    UPDATE STATISTICS HR.EMP_Details WITH FULLSCAN;
    UPDATE STATISTICS HR.Departments WITH FULLSCAN;
    
    -- Update statistics for less critical tables with sampling
    UPDATE STATISTICS HR.AuditLog WITH SAMPLE 30 PERCENT;
    
    -- Log the update time
    INSERT INTO HR.MaintenanceLog(Operation, OperationTime)
    VALUES ('Statistics Update', GETDATE());
END;
GO

-- 2. Scheduling statistics updates
-- This would typically be done through SQL Agent Jobs
-- Example job step:
-- EXEC HR.UpdateStatistics;

-- 3. Statistics maintenance after bulk operations

-- After bulk insert
BULK INSERT HR.EMP_Details FROM 'C:\Data\NewEmployees.csv'
WITH (FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', FIRSTROW = 2);

-- Update statistics immediately after
UPDATE STATISTICS HR.EMP_Details WITH FULLSCAN;

-- =============================================
-- PART 8: REAL-WORLD SCENARIOS
-- =============================================

-- Scenario 1: Investigating a slow query

-- 1. Identify the query and its execution plan
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.Salary BETWEEN 40000 AND 60000;

-- 2. Check statistics for relevant columns
DBCC SHOW_STATISTICS ('HR.EMP_Details', IX_EMP_Salary);

-- 3. Update statistics if outdated
UPDATE STATISTICS HR.EMP_Details IX_EMP_Salary WITH FULLSCAN;

-- 4. Run the query again and compare plans

-- Scenario 2: Handling skewed data distribution

-- 1. Identify columns with skewed distribution
SELECT 
    DepartmentID,
    COUNT(*) AS EmployeeCount
FROM HR.EMP_Details
GROUP BY DepartmentID
ORDER BY EmployeeCount DESC;

-- 2. Create filtered statistics for better cardinality estimates
CREATE STATISTICS Stats_EMP_LargeDept ON HR.EMP_Details(DepartmentID)
WHERE DepartmentID IN (1, 2); -- Assuming these are the largest departments

CREATE STATISTICS Stats_EMP_SmallDept ON HR.EMP_Details(DepartmentID)
WHERE DepartmentID NOT IN (1, 2);

-- 3. Test query performance
SELECT * FROM HR.EMP_Details WHERE DepartmentID = 1; -- Large department
SELECT * FROM HR.EMP_Details WHERE DepartmentID = 10; -- Small department

-- Scenario 3: Handling temporary tables

-- 1. Create a temp table
CREATE TABLE #TempEmployees (
    EmployeeID INT,
    DepartmentID INT,
    Salary DECIMAL(10,2)
);

-- 2. Insert data
INSERT INTO #TempEmployees
SELECT EmployeeID, DepartmentID, Salary
FROM HR.EMP_Details
WHERE HireDate > '2020-01-01';

-- 3. Create statistics on the temp table
CREATE STATISTICS Stats_Temp_Dept ON #TempEmployees(DepartmentID);
CREATE STATISTICS Stats_Temp_Salary ON #TempEmployees(Salary);

-- 4. Run queries against the temp table
SELECT * FROM #TempEmployees WHERE DepartmentID = 3;

-- 5. Clean up
DROP TABLE #TempEmployees;

-- =============================================
-- PART 9: BEST PRACTICES
-- =============================================

-- 1. Keep AUTO_CREATE_STATISTICS and AUTO_UPDATE_STATISTICS enabled

-- 2. Consider using AUTO_UPDATE_STATISTICS_ASYNC for busy OLTP systems

-- 3. Update statistics after major data changes
--    - After index rebuilds (not needed as it's done automatically)
--    - After bulk operations
--    - Before running important reports or batch jobs

-- 4. Create multi-column statistics for correlated columns

-- 5. Use filtered statistics for skewed data distributions

-- 6. Monitor statistics age and modification counters

-- 7. Use FULLSCAN for critical tables, sampling for large tables

-- 8. Be aware of the ascending key problem for date columns

-- 9. Consider trace flags for specific statistics issues
--    - TF 2371: Lowers the threshold for auto-update statistics
--    - TF 2389: Enables dynamic sampling for ascending keys
--    - TF 2390: Enables dynamic sampling for ascending keys (alternative)

-- 10. Include statistics maintenance in