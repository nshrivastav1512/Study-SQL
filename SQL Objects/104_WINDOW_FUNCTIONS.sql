-- =============================================
-- SQL Server Window Functions Guide
-- A Progressive Learning Approach
-- =============================================

USE HRSystem;
GO

-- =============================================
-- PART 1: Introduction to Window Functions
-- =============================================

-- 1. Basic Aggregate Functions (Without Window Functions)
-- Traditional way using GROUP BY
SELECT 
    DepartmentID,
    AVG(Salary) as AvgSalary
FROM HR.Employees
GROUP BY DepartmentID;

-- 2. Same Query Using Window Function
-- Shows both individual rows AND aggregate data
SELECT 
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    AVG(Salary) OVER() as CompanyAvgSalary  -- Window function
FROM HR.Employees;

-- 3. Understanding PARTITION BY
-- Grouping data without losing row details
SELECT 
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    AVG(Salary) OVER(PARTITION BY DepartmentID) as DeptAvgSalary
FROM HR.Employees;

-- =============================================
-- PART 2: Basic Window Functions
-- =============================================

-- 1. Simple Aggregate Window Functions
SELECT 
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    MIN(Salary) OVER(PARTITION BY DepartmentID) as DeptMinSalary,
    MAX(Salary) OVER(PARTITION BY DepartmentID) as DeptMaxSalary,
    COUNT(*) OVER(PARTITION BY DepartmentID) as DeptEmployeeCount
FROM HR.Employees;

-- 2. Adding ORDER BY to Window Functions
-- Shows running totals within each department
SELECT 
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    SUM(Salary) OVER(
        PARTITION BY DepartmentID 
        ORDER BY Salary
    ) as RunningTotalSalary
FROM HR.Employees;

-- =============================================
-- PART 3: Ranking Functions
-- =============================================

-- 1. Basic Ranking: Understanding Different Ranking Functions
SELECT 
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    ROW_NUMBER() OVER(ORDER BY Salary DESC) as UniqueRank,      -- Always unique
    RANK() OVER(ORDER BY Salary DESC) as StandardRank,         -- Gaps in ranking
    DENSE_RANK() OVER(ORDER BY Salary DESC) as ConsecutiveRank -- No gaps
FROM HR.Employees;

-- 2. Ranking Within Departments
SELECT 
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    RANK() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) as DeptSalaryRank
FROM HR.Employees;

-- =============================================
-- PART 4: Offset Functions
-- =============================================

-- 1. Basic Offset Functions
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Salary,
    LAG(Salary) OVER(ORDER BY EmployeeID) as PreviousEmployeeSalary,
    LEAD(Salary) OVER(ORDER BY EmployeeID) as NextEmployeeSalary
FROM HR.Employees;

-- 2. Comparing Current Row with Previous/Next
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Salary,
    Salary - LAG(Salary) OVER(ORDER BY EmployeeID) as SalaryDifference
FROM HR.Employees;

-- =============================================
-- PART 5: Advanced Window Functions
-- =============================================

-- 1. FIRST_VALUE and LAST_VALUE
SELECT 
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    FIRST_VALUE(Salary) OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) as HighestInDept,
    LAST_VALUE(Salary) OVER(
        PARTITION BY DepartmentID 
        ORDER BY Salary DESC
        RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as LowestInDept
FROM HR.Employees;

-- 2. Moving Averages (Frame Clause)
SELECT 
    EmployeeID,
    HireDate,
    Salary,
    AVG(Salary) OVER(
        ORDER BY HireDate
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as MovingAvg3Months
FROM HR.Employees;

-- =============================================
-- PART 6: Practical Examples
-- =============================================

-- 1. Employee Salary Percentiles
SELECT 
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    NTILE(4) OVER(PARTITION BY DepartmentID ORDER BY Salary) as SalaryQuartile,
    PERCENT_RANK() OVER(PARTITION BY DepartmentID ORDER BY Salary) as RelativeRank
FROM HR.Employees;

-- 2. Year-over-Year Growth
SELECT 
    Year,
    TotalSales,
    LAG(TotalSales) OVER(ORDER BY Year) as PreviousYearSales,
    ((TotalSales - LAG(TotalSales) OVER(ORDER BY Year)) / 
     LAG(TotalSales) OVER(ORDER BY Year)) * 100 as YoYGrowth
FROM HR.YearlySales;

-- =============================================
-- Best Practices and Tips
-- =============================================

/*
1. Window Function Syntax Order:
   SELECT column_name,
   window_function() OVER (
       [PARTITION BY column_list]
       [ORDER BY column_list]
       [ROWS/RANGE frame_extent]
   )

2. Performance Tips:
   - Index columns used in PARTITION BY and ORDER BY
   - Avoid using window functions in WHERE clauses
   - Consider materialized views for complex calculations

3. Common Use Cases:
   - Running totals and averages
   - Rankings and comparisons
   - Moving averages
   - Year-over-year analysis
   - Percentile calculations
*/

GO