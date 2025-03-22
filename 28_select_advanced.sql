-- =============================================
-- DQL Advanced Techniques
-- =============================================

USE HRSystem;
GO

-- 1. Complex Sorting
-- Sort employees with $50,000 salary first, then others by ascending salary
SELECT 
    EmployeeID, 
    FirstName, 
    LastName, 
    Salary,
    CASE WHEN Salary = 50000 THEN 0 ELSE 1 END AS SortOrder
FROM HR.EMP_Details
ORDER BY SortOrder, Salary ASC;
-- This uses a CASE expression to create a temporary sorting column
-- Employees with $50,000 get SortOrder=0, others get SortOrder=1
-- We sort by SortOrder first (bringing $50,000 employees to top)
-- Then by Salary ascending for the remaining employees

-- 2. Dynamic TOP with Variables
-- Return a variable number of top-paid employees
DECLARE @TopCount INT = 5;
SELECT TOP (@TopCount) *
FROM HR.EMP_Details
ORDER BY Salary DESC;
-- The number of rows returned can be controlled by changing @TopCount
-- Useful for reports where the number of results needs to be configurable

-- 3. Conditional Aggregation
-- Count employees by department and salary range in one query
SELECT 
    DepartmentID,
    COUNT(*) AS TotalEmployees,
    SUM(CASE WHEN Salary < 50000 THEN 1 ELSE 0 END) AS LowSalary,
    SUM(CASE WHEN Salary BETWEEN 50000 AND 80000 THEN 1 ELSE 0 END) AS MidSalary,
    SUM(CASE WHEN Salary > 80000 THEN 1 ELSE 0 END) AS HighSalary
FROM HR.EMP_Details
GROUP BY DepartmentID;
-- This creates a pivot-like report showing salary distribution by department
-- Each CASE expression counts employees in a specific salary range

-- 4. Window Functions with Partitioning
-- Calculate department-specific salary statistics for each employee
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    AVG(Salary) OVER(PARTITION BY DepartmentID) AS AvgDeptSalary,
    MAX(Salary) OVER(PARTITION BY DepartmentID) AS MaxDeptSalary,
    MIN(Salary) OVER(PARTITION BY DepartmentID) AS MinDeptSalary,
    Salary - AVG(Salary) OVER(PARTITION BY DepartmentID) AS DiffFromAvg
FROM HR.EMP_Details;
-- PARTITION BY divides data into groups (departments)
-- Window functions calculate values across these groups
-- Each employee row shows both individual salary and department statistics
-- No GROUP BY needed - maintains individual rows while showing aggregates

-- 5. Row Numbering and Ranking
-- Assign ranks to employees based on salary within each department
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    ROW_NUMBER() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS RowNum,
    RANK() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS SalaryRank,
    DENSE_RANK() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS DenseRank,
    NTILE(4) OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS Quartile
FROM HR.EMP_Details;
-- ROW_NUMBER: Unique sequential number (1,2,3,4...)
-- RANK: Same rank for ties, leaves gaps (1,1,3,4...)
-- DENSE_RANK: Same rank for ties, no gaps (1,1,2,3...)
-- NTILE: Divides results into N equal groups (quartiles in this case)

-- 6. Running Totals and Moving Averages
-- Calculate cumulative salary totals and 3-employee moving averages
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    HireDate,
    Salary,
    SUM(Salary) OVER(ORDER BY HireDate) AS RunningTotal,
    AVG(Salary) OVER(ORDER BY HireDate ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS MovingAvg
FROM HR.EMP_Details;
-- Running total adds up all salaries from first hire date to current row
-- Moving average calculates average of current employee, previous, and next
-- ROWS BETWEEN defines the window frame (1 before, current, 1 after)

-- 7. Finding Nth Highest Salary
-- Find the 3rd highest salary in each department
WITH RankedSalaries AS (
    SELECT 
        DepartmentID,
        Salary,
        DENSE_RANK() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS SalaryRank
    FROM HR.EMP_Details
)
SELECT 
    DepartmentID,
    Salary AS ThirdHighestSalary
FROM RankedSalaries
WHERE SalaryRank = 3;
-- First creates a CTE (Common Table Expression) with ranked salaries
-- Then filters to only show rank 3 (third highest) for each department

-- 8. Pivot Tables
-- Transform rows into columns (departments as columns, job titles as rows)
SELECT 
    JobTitle,
    [1] AS HR_Dept,
    [2] AS IT_Dept,
    [3] AS Finance_Dept,
    [4] AS Marketing_Dept
FROM (
    SELECT JobTitle, DepartmentID, Salary
    FROM HR.EMP_Details
) AS SourceData
PIVOT (
    SUM(Salary) 
    FOR DepartmentID IN ([1], [2], [3], [4])
) AS PivotTable;
-- Creates a cross-tabulation report showing total salary by job and department
-- Rows are job titles, columns are departments
-- Values are sum of salaries for each job/department combination

-- 9. Unpivot Tables
-- Transform columns back into rows (reverse of PIVOT)
SELECT 
    JobTitle,
    Department,
    Salary
FROM (
    SELECT 
        JobTitle, 
        HR_Dept, 
        IT_Dept, 
        Finance_Dept, 
        Marketing_Dept
    FROM PivotedSalaries
) AS SourceTable
UNPIVOT (
    Salary FOR Department IN (
        HR_Dept, IT_Dept, Finance_Dept, Marketing_Dept
    )
) AS UnpivotTable;
-- Takes a pivoted table and converts it back to normalized form
-- Column names become values in the Department column
-- Column values become values in the Salary column

-- 10. Recursive CTEs
-- Find employee hierarchy (managers and their subordinates)
WITH EmployeeHierarchy AS (
    -- Anchor member (top level managers)
    SELECT 
        EmployeeID, 
        FirstName, 
        LastName, 
        ManagerID, 
        0 AS Level
    FROM HR.EMP_Details
    WHERE ManagerID IS NULL
    
    UNION ALL
    
    -- Recursive member (subordinates)
    SELECT 
        e.EmployeeID, 
        e.FirstName, 
        e.LastName, 
        e.ManagerID, 
        h.Level + 1
    FROM HR.EMP_Details e
    INNER JOIN EmployeeHierarchy h ON e.ManagerID = h.EmployeeID
)
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    ManagerID,
    Level,
    REPLICATE('    ', Level) + FirstName + ' ' + LastName AS HierarchyDisplay
FROM EmployeeHierarchy
ORDER BY Level, FirstName;
-- Starts with employees who have no manager (top level)
-- Recursively finds all employees who report to each manager
-- Tracks the level in the hierarchy (0 for top, 1 for direct reports, etc.)
-- Creates an indented display to visualize the hierarchy