-- =============================================
-- DQL Common Table Expressions (CTEs)
-- =============================================

USE HRSystem;
GO

-- 1. Basic CTE
-- Defines a named temporary result set
WITH EmployeeSalaryStats AS (
    SELECT 
        DepartmentID,
        AVG(Salary) AS AvgSalary,
        MAX(Salary) AS MaxSalary,
        MIN(Salary) AS MinSalary
    FROM HR.EMP_Details
    GROUP BY DepartmentID
)
SELECT 
    d.DepartmentName,
    ess.AvgSalary,
    ess.MaxSalary,
    ess.MinSalary
FROM EmployeeSalaryStats ess
JOIN HR.Departments d ON ess.DepartmentID = d.DepartmentID;
-- CTE defined after WITH keyword
-- Makes complex queries more readable
-- CTE only exists for the duration of the query

-- 2. Multiple CTEs
-- Define multiple temporary result sets
WITH DepartmentCounts AS (
    SELECT 
        DepartmentID,
        COUNT(*) AS EmployeeCount
    FROM HR.EMP_Details
    GROUP BY DepartmentID
),
HighSalaryEmployees AS (
    SELECT 
        DepartmentID,
        COUNT(*) AS HighPaidCount
    FROM HR.EMP_Details
    WHERE Salary > 70000
    GROUP BY DepartmentID
)
SELECT 
    d.DepartmentName,
    dc.EmployeeCount,
    hse.HighPaidCount,
    CAST(hse.HighPaidCount * 100.0 / dc.EmployeeCount AS DECIMAL(5,2)) AS HighPaidPercentage
FROM DepartmentCounts dc
JOIN HighSalaryEmployees hse ON dc.DepartmentID = hse.DepartmentID
JOIN HR.Departments d ON dc.DepartmentID = d.DepartmentID;
-- Defines two separate CTEs
-- Each CTE performs a different calculation
-- Main query joins them together
-- Later CTEs can reference earlier CTEs

-- 3. CTE with Window Functions
-- Combines CTEs with window functions
WITH RankedEmployees AS (
    SELECT 
        EmployeeID,
        FirstName,
        LastName,
        DepartmentID,
        Salary,
        RANK() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS SalaryRank
    FROM HR.EMP_Details
)
SELECT 
    re.EmployeeID,
    re.FirstName,
    re.LastName,
    d.DepartmentName,
    re.Salary
FROM RankedEmployees re
JOIN HR.Departments d ON re.DepartmentID = d.DepartmentID
WHERE re.SalaryRank <= 3;
-- CTE calculates salary rank within each department
-- Main query filters to top 3 salaries in each department
-- Cleaner than using a subquery with window function

-- 4. Recursive CTE
-- Self-referencing CTE for hierarchical or iterative data
WITH EmployeeHierarchy AS (
    -- Anchor member (base case)
    SELECT 
        EmployeeID,
        FirstName,
        LastName,
        ManagerID,
        0 AS Level,
        CAST(FirstName + ' ' + LastName AS VARCHAR(1000)) AS HierarchyPath
    FROM HR.EMP_Details
    WHERE ManagerID IS NULL
    
    UNION ALL
    
    -- Recursive member
    SELECT 
        e.EmployeeID,
        e.FirstName,
        e.LastName,
        e.ManagerID,
        eh.Level + 1,
        CAST(eh.HierarchyPath + ' > ' + e.FirstName + ' ' + e.LastName AS VARCHAR(1000))
    FROM HR.EMP_Details e
    INNER JOIN EmployeeHierarchy eh ON e.ManagerID = eh.EmployeeID
)
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Level,
    HierarchyPath
FROM EmployeeHierarchy
ORDER BY Level, FirstName;
-- Consists of anchor member (starting point) and recursive member
-- Anchor: Finds top-level employees (no manager)
-- Recursive: Finds employees who report to previously found employees
-- Builds organization hierarchy showing reporting relationships
-- Level tracks depth in hierarchy
-- HierarchyPath builds a string showing the chain of command

-- 5. Recursive CTE with MAXRECURSION
-- Limits recursion depth to prevent infinite loops
WITH NumberSequence AS (
    -- Anchor member
    SELECT 1 AS Number
    
    UNION ALL
    
    -- Recursive member
    SELECT Number + 1
    FROM NumberSequence
    WHERE Number < 100
)
SELECT Number
FROM NumberSequence
OPTION (MAXRECURSION 100);
-- Generates numbers from 1 to 100
-- MAXRECURSION option limits recursion depth
-- Default limit is 100, can be set up to 32,767
-- Prevents infinite loops in poorly designed recursive CTEs

-- 6. CTE for Data Generation
-- Creates test data or date sequences
WITH DateSequence AS (
    -- Anchor member
    SELECT CAST('2023-01-01' AS DATE) AS SequenceDate
    
    UNION ALL
    
    -- Recursive member
    SELECT DATEADD(DAY, 1, SequenceDate)
    FROM DateSequence
    WHERE SequenceDate < '2023-12-31'
)
SELECT 
    SequenceDate,
    DATENAME(WEEKDAY, SequenceDate) AS DayOfWeek,
    MONTH(SequenceDate) AS MonthNumber,
    DATENAME(MONTH, SequenceDate) AS MonthName
FROM DateSequence
OPTION (MAXRECURSION 366);
-- Generates all dates in 2023
-- Useful for reporting that needs all dates (even those without data)
-- Creates calendar table on-the-fly

-- 7. CTE for Running Totals
-- Calculates cumulative sums
WITH MonthlySales AS (
    SELECT 
        YEAR(OrderDate) AS OrderYear,
        MONTH(OrderDate) AS OrderMonth,
        SUM(OrderAmount) AS MonthlySalesAmount
    FROM HR.Orders
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
),
RunningTotals AS (
    SELECT 
        OrderYear,
        OrderMonth,
        MonthlySalesAmount,
        SUM(MonthlySalesAmount) OVER(
            PARTITION BY OrderYear 
            ORDER BY OrderMonth
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS YearToDateSales
    FROM MonthlySales
)
SELECT 
    OrderYear,
    OrderMonth,
    MonthlySalesAmount,
    YearToDateSales,
    FORMAT(MonthlySalesAmount * 100.0 / YearToDateSales, 'N2') + '%' AS PercentOfYTD
FROM RunningTotals
ORDER BY OrderYear, OrderMonth;
-- First CTE aggregates sales by month
-- Second CTE calculates running totals within each year
-- Main query shows monthly and cumulative figures

-- 8. CTE for Pivoting Data
-- Transforms rows to columns
WITH DepartmentSalaries AS (
    SELECT 
        JobTitle,
        DepartmentID,
        SUM(Salary) AS TotalSalary
    FROM HR.EMP_Details
    GROUP BY JobTitle, DepartmentID
)
SELECT 
    JobTitle,
    [1] AS HR_Dept,
    [2] AS IT_Dept,
    [3] AS Finance_Dept,
    [4] AS Marketing_Dept
FROM DepartmentSalaries
PIVOT (
    SUM(TotalSalary)
    FOR DepartmentID IN ([1], [2], [3], [4])
) AS PivotTable;
-- CTE prepares data for pivoting
-- PIVOT transforms department IDs into columns
-- Result shows salary totals by job title and department

-- 9. CTE for Data Cleaning
-- Prepares and cleanses data before main query
WITH CleanedEmployeeData AS (
    SELECT 
        EmployeeID,
        TRIM(FirstName) AS FirstName,
        TRIM(LastName) AS LastName,
        CASE 
            WHEN Email LIKE '%@%.%' THEN Email
            ELSE NULL
        END AS CleanEmail,
        CASE
            WHEN ISNUMERIC(Salary) = 1 AND Salary > 0 THEN Salary
            ELSE NULL
        END AS CleanSalary,
        DepartmentID
    FROM HR.EMP_Details
)
SELECT 
    ced.EmployeeID,
    ced.FirstName + ' ' + ced.LastName AS FullName,
    ced.CleanEmail,
    ced.CleanSalary,
    d.DepartmentName
FROM CleanedEmployeeData ced
JOIN HR.Departments d ON ced.DepartmentID = d.DepartmentID
WHERE ced.CleanEmail IS NOT NULL AND ced.CleanSalary IS NOT NULL;
-- CTE handles data cleaning operations
-- Trims whitespace, validates email format, checks salary values
-- Main query uses only the clean data

-- 10. CTE for Pagination
-- Implements paging functionality
DECLARE @PageNumber INT = 2;
DECLARE @RowsPerPage INT = 10;

WITH PagedEmployees AS (
    SELECT 
        EmployeeID,
        FirstName,
        LastName,
        Email,
        Salary,
        ROW_NUMBER() OVER(ORDER BY LastName, FirstName) AS RowNum
    FROM HR.EMP_Details
)
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Email,
    Salary
FROM PagedEmployees
WHERE RowNum BETWEEN (@PageNumber - 1) * @RowsPerPage + 1 
                  AND @PageNumber * @RowsPerPage
ORDER BY RowNum;
-- CTE assigns row numbers to all employees
-- Main query filters to just the requested page
-- Shows 10 employees per page (page 2 = employees 11-20)