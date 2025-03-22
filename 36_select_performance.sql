-- =============================================
-- DQL Performance Optimization Techniques
-- =============================================

USE HRSystem;
GO

-- 1. Using Appropriate Indexes
-- Query designed to use existing indexes
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Salary
FROM HR.EMP_Details
WHERE DepartmentID = 3
ORDER BY LastName, FirstName;
-- Assumes index on DepartmentID and/or (LastName, FirstName)
-- Covering index would include all columns in SELECT list
-- Check execution plan to verify index usage

-- 2. NOLOCK Hint (READ UNCOMMITTED)
-- Reduces blocking but may read uncommitted data
SELECT 
    EmployeeID,
    FirstName,
    LastName
FROM HR.EMP_Details WITH (NOLOCK)
WHERE DepartmentID = 3;
-- WITH (NOLOCK) allows dirty reads (uncommitted data)
-- Improves concurrency but sacrifices consistency
-- Use only when appropriate for business requirements

-- 3. Index Hints
-- Forces use of specific index
SELECT 
    EmployeeID,
    FirstName,
    LastName
FROM HR.EMP_Details WITH (INDEX(IX_EMP_Department))
WHERE DepartmentID = 3;
-- Forces query to use the IX_EMP_Department index
-- Overrides query optimizer's choice
-- Use only when optimizer consistently chooses wrong index

-- 4. Optimizing JOINs
-- Joining on indexed columns with appropriate join type
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName
FROM HR.EMP_Details e
INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.Salary > 50000;
-- Join on primary key/foreign key relationship
-- INNER JOIN when both tables must have matching rows
-- Filter on indexed column (Salary) if possible

-- 5. Avoiding Functions on Indexed Columns
-- Keep indexed columns free of functions
-- Bad example (function on indexed column):
SELECT 
    EmployeeID,
    FirstName,
    LastName
FROM HR.EMP_Details
WHERE YEAR(HireDate) = 2022;

-- Good example (no function on indexed column):
SELECT 
    EmployeeID,
    FirstName,
    LastName
FROM HR.EMP_Details
WHERE HireDate >= '2022-01-01' AND HireDate < '2023-01-01';
-- Second query can use index on HireDate
-- First query cannot use index effectively due to YEAR() function

-- 6. TOP with ORDER BY for Limited Results
-- Limits processing when only top N rows needed
SELECT TOP 10
    EmployeeID,
    FirstName,
    LastName,
    Salary
FROM HR.EMP_Details
ORDER BY Salary DESC;
-- Database can stop processing after finding top 10
-- More efficient than sorting entire result set
-- Especially important for large tables

-- 7. EXISTS vs. IN for Subqueries
-- EXISTS often performs better than IN for large datasets
-- Using IN:
SELECT 
    DepartmentID,
    DepartmentName
FROM HR.Departments
WHERE DepartmentID IN (
    SELECT DepartmentID FROM HR.EMP_Details WHERE Salary > 70000
);

-- Using EXISTS (often more efficient):
SELECT 
    DepartmentID,
    DepartmentName
FROM HR.Departments d
WHERE EXISTS (
    SELECT 1 FROM HR.EMP_Details e 
    WHERE e.DepartmentID = d.DepartmentID AND e.Salary > 70000
);
-- EXISTS stops evaluating after finding first match
-- IN must evaluate all values returned by subquery

-- 8. Avoiding SELECT *
-- Retrieve only needed columns
-- Bad practice:
SELECT * FROM HR.EMP_Details WHERE DepartmentID = 3;

-- Good practice:
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Email
FROM HR.EMP_Details
WHERE DepartmentID = 3;
-- Retrieves only necessary columns
-- Reduces I/O, memory usage, and network traffic
-- May allow use of covering indexes

-- 9. Using UNION ALL Instead of UNION When Possible
-- UNION ALL avoids duplicate elimination overhead
-- Use UNION ALL when you know there are no duplicates or duplicates are acceptable
SELECT EmployeeID, FirstName, LastName FROM HR.CurrentEmployees
UNION ALL
SELECT EmployeeID, FirstName, LastName FROM HR.NewHires;
-- UNION ALL doesn't check for duplicates (faster)
-- UNION removes duplicates (slower)

-- 10. Optimizing GROUP BY
-- Group by indexed columns when possible
SELECT 
    DepartmentID,
    COUNT(*) AS EmployeeCount,
    AVG(Salary) AS AvgSalary
FROM HR.EMP_Details
WHERE HireDate >= '2020-01-01'
GROUP BY DepartmentID;
-- GROUP BY on indexed column (DepartmentID)
-- Filter before grouping to reduce rows processed

-- 11. Using Computed Columns
-- Pre-calculate frequently used expressions
-- Create computed column:
ALTER TABLE HR.EMP_Details
ADD FullName AS (FirstName + ' ' + LastName) PERSISTED;

-- Query using computed column:
SELECT 
    EmployeeID,
    FullName,
    Email
FROM HR.EMP_Details
WHERE FullName LIKE 'J%';
-- PERSISTED computed columns can be indexed
-- Avoids recalculating expressions for each query

-- 12. Optimizing Subqueries
-- Use JOIN instead of correlated subqueries when possible
-- Correlated subquery (runs once per outer row):
SELECT 
    d.DepartmentID,
    d.DepartmentName,
    (SELECT COUNT(*) FROM HR.EMP_Details e WHERE e.DepartmentID = d.DepartmentID) AS EmployeeCount
FROM HR.Departments d;

-- JOIN alternative (often more efficient):
SELECT 
    d.DepartmentID,
    d.DepartmentName,
    COUNT(e.EmployeeID) AS EmployeeCount
FROM HR.Departments d
LEFT JOIN HR.EMP_Details e ON d.DepartmentID = e.DepartmentID
GROUP BY d.DepartmentID, d.DepartmentName;
-- JOIN processes all rows at once rather than row-by-row

-- 13. Using Table Variables vs. Temporary Tables
-- Choose appropriate temporary storage
-- Table variable (stored in memory for small datasets):
DECLARE @HighPaidEmployees TABLE (
    EmployeeID INT,
    FullName NVARCHAR(100),
    Salary DECIMAL(10,2)
);

INSERT INTO @HighPaidEmployees
SELECT EmployeeID, FirstName + ' ' + LastName, Salary
FROM HR.EMP_Details
WHERE Salary > 70000;

SELECT * FROM @HighPaidEmployees ORDER BY Salary DESC;

-- Temp table (better for larger datasets):
CREATE TABLE #HighPaidEmployees (
    EmployeeID INT,
    FullName NVARCHAR(100),
    Salary DECIMAL(10,2)
);

CREATE INDEX IX_Temp_Salary ON #HighPaidEmployees(Salary);

INSERT INTO #HighPaidEmployees
SELECT EmployeeID, FirstName + ' ' + LastName, Salary
FROM HR.EMP_Details
WHERE Salary > 70000;

SELECT * FROM #HighPaidEmployees ORDER BY Salary DESC;

DROP TABLE #HighPaidEmployees;
-- Table variables: Less overhead, no statistics, memory-optimized
-- Temp tables: Can be indexed, have statistics, better for large datasets

-- 14. Using OPTION Hints
-- Provide query optimizer with execution hints
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID
FROM HR.EMP_Details
WHERE Salary > 50000
OPTION (OPTIMIZE FOR (@Salary = 60000), MAXDOP 2);
-- OPTIMIZE FOR: Optimizes for specific parameter value
-- MAXDOP: Limits degree of parallelism
-- Use only when default optimizer behavior is suboptimal

-- 15. Avoiding Implicit Conversions
-- Ensure data types match to avoid conversions
-- Implicit conversion (can't use index effectively):
SELECT * FROM HR.EMP_Details WHERE EmployeeID = '1001';

-- No conversion (can use index):
SELECT * FROM HR.EMP_Details WHERE EmployeeID = 1001;
-- Implicit conversions prevent index seeks
-- Match data types between columns and search values

-- 16. Batch Processing for Large Operations
-- Process large datasets in smaller chunks
DECLARE @BatchSize INT = 10000;
DECLARE @MaxID INT = (SELECT MAX(EmployeeID) FROM HR.EMP_Details);
DECLARE @CurrentID INT = 0;

WHILE @CurrentID < @MaxID
BEGIN
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.05
    WHERE EmployeeID > @CurrentID AND EmployeeID <= @CurrentID + @BatchSize
    AND DepartmentID = 3;
    
    SET @CurrentID = @CurrentID + @BatchSize;
    
    -- Optional: Add delay to reduce resource contention
    WAITFOR DELAY '00:00:00.1';
END
-- Processes large updates in smaller batches
-- Reduces lock contention and transaction log growth
-- Allows other processes to access the table between batches

-- 17. Using Filtered Indexes
-- Indexes that include a WHERE clause
CREATE NONCLUSTERED INDEX IX_EMP_HighSalary
ON HR.EMP_Details (LastName, FirstName)
WHERE Salary > 70000;
-- Only includes rows matching the filter condition
-- Smaller and more efficient than full-table index
-- Useful for queries that frequently filter on the same condition

-- 18. Optimizing for Specific Query Patterns
-- Tailoring indexes to query patterns
CREATE NONCLUSTERED INDEX IX_EMP_DeptSalary
ON HR.EMP_Details (DepartmentID, Salary)
INCLUDE (FirstName, LastName, Email);
-- Index ordered by frequently filtered columns
-- INCLUDE adds columns needed by SELECT without adding to key
-- Creates covering index for common queries

-- 19. Using Query Store
-- Monitor and optimize query performance over time
ALTER DATABASE HRSystem SET QUERY_STORE = ON;
-- Captures query execution statistics
-- Identifies regression in query performance
-- Allows forcing specific execution plans

-- 20. Minimizing Network Traffic
-- Reduce data sent over network
SELECT TOP 100 
    EmployeeID,
    LEFT(FirstName, 1) + '. ' + LastName AS ShortName,
    CAST(Salary AS INT) AS ApproxSalary
FROM HR.EMP_Details
ORDER BY LastName;
-- Returns abbreviated data when full precision not needed
-- Reduces network bandwidth and client-side memory usage
-- Especially important for mobile applications

-- 21. Using Appropriate Data Types
-- Choose smallest data type that fits requirements
CREATE TABLE HR.EmployeeAttendance (
    AttendanceID INT IDENTITY(1,1),
    EmployeeID SMALLINT,  -- Instead of INT
    AttendanceDate DATE,   -- Instead of DATETIME
    IsPresent BIT,         -- Instead of INT or CHAR
    HoursWorked TINYINT    -- Instead of INT
);
-- Smaller data types use less storage and memory
-- Improves I/O performance and reduces cache misses
-- Allows more rows per page

-- 22. Partitioning Large Tables
-- Divide large tables into smaller, more manageable pieces
CREATE PARTITION FUNCTION PF_OrderDate (DATE)
AS RANGE RIGHT FOR VALUES ('2021-01-01', '2022-01-01', '2023-01-01');

CREATE PARTITION SCHEME PS_OrderDate
AS PARTITION PF_OrderDate TO (FG1, FG2, FG3, FG4);

CREATE TABLE HR.OrdersPartitioned (
    OrderID INT NOT NULL,
    OrderDate DATE NOT NULL,
    UserID INT,
    OrderAmount DECIMAL(10,2),
    PRIMARY KEY (OrderID, OrderDate)
) ON PS_OrderDate(OrderDate);
-- Divides table by date ranges across filegroups
-- Allows operations on specific partitions only
-- Improves maintenance and query performance for large tables

-- 23. Using Compression
-- Reduce storage and improve I/O performance
ALTER TABLE HR.EMP_Details REBUILD WITH (DATA_COMPRESSION = PAGE);
-- Compresses data to reduce storage requirements
-- Can improve I/O performance by reading fewer pages
-- May increase CPU usage for compression/decompression

-- 24. Optimizing Temp Tables
-- Improve performance of temporary objects
-- Create temp table with appropriate structure
CREATE TABLE #EmployeeStats (
    DepartmentID INT,
    EmployeeCount INT,
    AvgSalary DECIMAL(10,2),
    PRIMARY KEY (DepartmentID)
);

-- Populate with aggregated data
INSERT INTO #EmployeeStats
SELECT 
    DepartmentID,
    COUNT(*),
    AVG(Salary)
FROM HR.EMP_Details
GROUP BY DepartmentID;

-- Use in subsequent queries
SELECT 
    d.DepartmentName,
    es.EmployeeCount,
    es.AvgSalary
FROM #EmployeeStats es
JOIN HR.Departments d ON es.DepartmentID = d.DepartmentID;

-- Clean up
DROP TABLE #EmployeeStats;
-- Pre-aggregates data once instead of multiple times
-- Primary key improves join performance
-- Reduces repeated complex calculations

-- 25. Using SET NOCOUNT ON
-- Reduces network traffic by suppressing row count messages
SET NOCOUNT ON;

UPDATE HR.EMP_Details
SET Salary = Salary * 1.03
WHERE DepartmentID = 2;

SET NOCOUNT OFF;
-- Eliminates "X rows affected" messages
-- Reduces network packets, especially for batches of statements
-- Improves performance of applications that don't need row counts