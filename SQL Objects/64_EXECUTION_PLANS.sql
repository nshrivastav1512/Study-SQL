-- =============================================
-- EXECUTION PLANS Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Execution Plans, including:
- What execution plans are and why they're important
- Types of execution plans (Estimated vs. Actual)
- How to view and interpret execution plans
- Common operators in execution plans
- How to identify and resolve performance issues using execution plans
- Plan caching and reuse
- Plan forcing and hints
- Real-world scenarios and best practices
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: EXECUTION PLAN FUNDAMENTALS
-- =============================================

-- What is an Execution Plan?
-- An execution plan is SQL Server's strategy for executing a query
-- It shows the sequence of operations SQL Server will perform

-- Simple query to demonstrate execution plans
-- To view the estimated execution plan: CTRL+L in SSMS
-- To view the actual execution plan: Include Actual Execution Plan (CTRL+M) and then execute

-- Basic SELECT query
SELECT 
    EmployeeID, 
    FirstName, 
    LastName, 
    Salary
FROM HR.EMP_Details
WHERE DepartmentID = 3;
-- Examine the execution plan to see how SQL Server retrieves this data
-- Look for operators like Index Seek, Table Scan, etc.

-- =============================================
-- PART 2: TYPES OF EXECUTION PLANS
-- =============================================

-- 1. Estimated Execution Plan
-- Shows SQL Server's best guess before executing the query
-- Useful for testing query changes without running them

-- View estimated plan (CTRL+L in SSMS)
SELECT 
    e.EmployeeID, 
    e.FirstName, 
    e.LastName, 
    d.DepartmentName
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.Salary > 50000;

-- 2. Actual Execution Plan
-- Shows what actually happened during query execution
-- Includes runtime statistics like actual row counts

-- Enable actual execution plan (CTRL+M) and run the query
-- Compare estimated vs. actual row counts

-- =============================================
-- PART 3: READING EXECUTION PLANS
-- =============================================

-- Execution plans are read from right to left, bottom to top
-- Each operator represents a specific operation

-- Query with multiple operations to analyze
SELECT 
    d.DepartmentName,
    COUNT(e.EmployeeID) AS EmployeeCount,
    AVG(e.Salary) AS AvgSalary
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.HireDate > '2020-01-01'
GROUP BY d.DepartmentName
HAVING COUNT(e.EmployeeID) > 5
ORDER BY AvgSalary DESC;

-- Key metrics to examine in the plan:
-- 1. Cost percentage of each operation
-- 2. Estimated vs. actual row counts
-- 3. Operator types (seeks vs. scans)
-- 4. Data flow between operators

-- =============================================
-- PART 4: COMMON PLAN OPERATORS
-- =============================================

-- 1. Table Scan / Clustered Index Scan
-- Reads all rows in a table or clustered index
-- Often indicates missing indexes

-- Query likely to cause a table scan
SELECT * FROM HR.EMP_Details WHERE LastName LIKE 'S%';

-- 2. Index Seek
-- Uses an index to find specific rows efficiently
-- Preferred over scans for selective queries

-- Query likely to use an index seek (assuming index on EmployeeID)
SELECT * FROM HR.EMP_Details WHERE EmployeeID = 1001;

-- 3. Key Lookup / RID Lookup
-- Retrieves additional columns not in the index
-- Can indicate need for a covering index

-- Query that might cause a Key Lookup
SELECT 
    EmployeeID, 
    FirstName, 
    LastName, 
    PhoneNumber  -- Assuming this isn't in the index
FROM HR.EMP_Details
WHERE EmployeeID = 1001;

-- 4. Hash Match / Merge Join / Nested Loops
-- Different join algorithms SQL Server might use

-- Hash Match (typically for larger datasets)
SELECT e.EmployeeID, d.DepartmentName
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID;

-- Nested Loops (typically for smaller datasets)
SELECT e.EmployeeID, p.ProjectName
FROM HR.EMP_Details e
JOIN HR.Projects p ON e.EmployeeID = p.ProjectLead
WHERE e.DepartmentID = 3;

-- 5. Sort
-- Arranges data in specified order
-- Can be expensive for large datasets

SELECT * FROM HR.EMP_Details ORDER BY LastName, FirstName;

-- =============================================
-- PART 5: IDENTIFYING PERFORMANCE ISSUES
-- =============================================

-- 1. High-Cost Operators
-- Look for operators with high relative cost

-- Complex query with potential performance issues
SELECT 
    d.DepartmentName,
    e.JobTitle,
    COUNT(*) AS EmployeeCount,
    AVG(e.Salary) AS AvgSalary,
    SUM(e.Salary) AS TotalSalary
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
JOIN HR.Locations l ON d.LocationID = l.LocationID
WHERE e.HireDate BETWEEN '2018-01-01' AND '2022-12-31'
GROUP BY d.DepartmentName, e.JobTitle
ORDER BY TotalSalary DESC;

-- 2. Warning Operators
-- Look for yellow exclamation marks in the plan

-- Query that might cause warnings (e.g., implicit conversions)
SELECT * FROM HR.EMP_Details WHERE EmployeeID = '1001';

-- 3. Scans on Large Tables
-- Table or index scans on large tables can be problematic

-- Query scanning a large table without appropriate filtering
SELECT * FROM HR.EMP_Details WHERE Salary > 30000;

-- 4. Missing Indexes
-- SQL Server may suggest missing indexes in the plan

-- Query that might benefit from an index
SELECT * FROM HR.EMP_Details WHERE HireDate > '2021-01-01' AND DepartmentID = 5;

-- =============================================
-- PART 6: PLAN CACHING AND REUSE
-- =============================================

-- SQL Server caches execution plans for reuse
-- This improves performance by avoiding recompilation

-- View cached plans in the plan cache
SELECT 
    st.text AS QueryText,
    cp.objtype AS PlanType,
    cp.usecounts AS UseCount,
    cp.size_in_bytes / 1024 AS SizeKB
FROM sys.dm_exec_cached_plans cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
WHERE st.text LIKE '%HR.EMP_Details%'
AND st.text NOT LIKE '%dm_exec_cached_plans%'
ORDER BY cp.usecounts DESC;

-- Factors affecting plan reuse:
-- 1. Parameter sniffing
-- 2. Schema changes
-- 3. Statistics updates
-- 4. SET options

-- Parameterized query for better plan reuse
DECLARE @DeptID INT = 3;
SELECT * FROM HR.EMP_Details WHERE DepartmentID = @DeptID;

-- Clear the procedure cache (USE WITH CAUTION in production!)
-- DBCC FREEPROCCACHE; -- Commented out for safety

-- =============================================
-- PART 7: PLAN FORCING AND QUERY HINTS
-- =============================================

-- 1. Query Hints
-- Direct SQL Server to use specific strategies

-- Force a specific join type
SELECT e.EmployeeID, d.DepartmentName
FROM HR.EMP_Details e
INNER MERGE JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.Salary > 50000;

-- Force a specific index
SELECT * FROM HR.EMP_Details WITH (INDEX(IX_EMP_DepartmentID))
WHERE DepartmentID = 3;

-- Optimize for a specific parameter value
SELECT * FROM HR.EMP_Details 
WHERE DepartmentID = @DeptID
OPTION (OPTIMIZE FOR (@DeptID = 3));

-- 2. Plan Guides
-- Force plans for queries you can't modify

-- Create a plan guide for a specific query
EXEC sp_create_plan_guide 
    @name = N'PG_EmpDetails_ByDept',
    @stmt = N'SELECT * FROM HR.EMP_Details WHERE DepartmentID = @dept',
    @type = N'SQL',
    @module_or_batch = NULL,
    @params = N'@dept int',
    @hints = N'OPTION (OPTIMIZE FOR (@dept = 3), MAXDOP 1)';

-- 3. Query Store Plan Forcing
-- Force a specific plan using Query Store

-- Enable Query Store (if not already enabled)
ALTER DATABASE HRSystem SET QUERY_STORE = ON;

-- Force a specific plan (would be done through SSMS UI or T-SQL)
-- This example shows the T-SQL approach
EXEC sp_query_store_force_plan @query_id = 42, @plan_id = 73;

-- =============================================
-- PART 8: REAL-WORLD SCENARIOS
-- =============================================

-- Scenario 1: Identifying a missing index
-- Run a query and look for missing index suggestions
SELECT 
    e.FirstName,
    e.LastName,
    e.Salary,
    d.DepartmentName
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.HireDate > '2020-01-01' AND e.Salary > 60000;

-- Scenario 2: Resolving a parameter sniffing issue
-- Original query with potential parameter sniffing
DECLARE @Salary DECIMAL(10,2) = 30000;
SELECT * FROM HR.EMP_Details WHERE Salary > @Salary;

-- Solution: Use OPTIMIZE FOR UNKNOWN or RECOMPILE
DECLARE @Salary DECIMAL(10,2) = 30000;
SELECT * FROM HR.EMP_Details 
WHERE Salary > @Salary
OPTION (OPTIMIZE FOR UNKNOWN);

-- Alternative solution with RECOMPILE
DECLARE @Salary DECIMAL(10,2) = 30000;
SELECT * FROM HR.EMP_Details 
WHERE Salary > @Salary
OPTION (RECOMPILE);

-- Scenario 3: Improving a complex query
-- Original complex query
SELECT 
    d.DepartmentName,
    l.City,
    COUNT(e.EmployeeID) AS EmployeeCount,
    AVG(e.Salary) AS AvgSalary,
    MAX(e.HireDate) AS MostRecentHire
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
JOIN HR.Locations l ON d.LocationID = l.LocationID
LEFT JOIN HR.Projects p ON e.EmployeeID = p.ProjectLead
WHERE e.HireDate > '2019-01-01'
GROUP BY d.DepartmentName, l.City
ORDER BY EmployeeCount DESC;

-- Improved version with query hints
SELECT 
    d.DepartmentName,
    l.City,
    COUNT(e.EmployeeID) AS EmployeeCount,
    AVG(e.Salary) AS AvgSalary,
    MAX(e.HireDate) AS MostRecentHire
FROM HR.EMP_Details e WITH (INDEX(IX_EMP_DepartmentID_HireDate))
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
JOIN HR.Locations l ON d.LocationID = l.LocationID
LEFT JOIN HR.Projects p ON e.EmployeeID = p.ProjectLead
WHERE e.HireDate > '2019-01-01'
GROUP BY d.DepartmentName, l.City
ORDER BY EmployeeCount DESC
OPTION (MAXDOP 4);

-- =============================================
-- PART 9: BEST PRACTICES
-- =============================================

-- 1. Regularly review execution plans for critical queries

-- 2. Look for these common issues:
--    - Table/Index scans on large tables
--    - Key lookups with high row counts
--    - Expensive sorts or hash operations
--    - Warnings (yellow exclamation marks)
--    - Large differences between estimated and actual rows

-- 3. Use Query Store to track plan changes over time

-- 4. Be cautious with query hints - they prevent optimizer improvements

-- 5. Consider the impact of statistics on plan generation
UPDATE STATISTICS HR.EMP_Details WITH FULLSCAN;

-- 6. Use Database Engine Tuning Advisor for complex workloads

-- 7. Monitor for plan recompilations using Extended Events

-- 8. Ensure proper indexing strategy based on workload

-- 9. Use OPTION (RECOMPILE) sparingly for queries with atypical parameter values

-- 10. Document baseline execution plans for critical queries

-- =============================================
-- PART 10: MONITORING AND TROUBLESHOOTING TOOLS
-- =============================================

-- 1. Dynamic Management Views (DMVs) for execution plans

-- Find top queries by average CPU time
SELECT TOP 10
    st.text AS QueryText,
    qs.total_