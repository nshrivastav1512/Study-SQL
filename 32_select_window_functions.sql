-- =============================================
-- DQL Window Functions - Row-by-Row Calculations
-- =============================================

USE HRSystem;
GO

-- 1. Basic Window Functions
-- Perform calculations across a set of rows related to current row
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    AVG(Salary) OVER() AS CompanyAvgSalary,
    MAX(Salary) OVER() AS CompanyMaxSalary,
    MIN(Salary) OVER() AS CompanyMinSalary
FROM HR.EMP_Details;
-- OVER() with empty parentheses applies function to entire result set
-- Each row shows individual data plus company-wide aggregates
-- Unlike GROUP BY, all rows are preserved

-- 2. PARTITION BY
-- Divides rows into groups for calculations
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    AVG(Salary) OVER(PARTITION BY DepartmentID) AS DeptAvgSalary,
    MAX(Salary) OVER(PARTITION BY DepartmentID) AS DeptMaxSalary,
    MIN(Salary) OVER(PARTITION BY DepartmentID) AS DeptMinSalary
FROM HR.EMP_Details;
-- PARTITION BY creates separate windows for each department
-- Calculations are performed within each department separately
-- Each employee row shows their data plus their department's aggregates

-- 3. ORDER BY in Window Functions
-- Defines the logical order of rows in each partition
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    SUM(Salary) OVER(PARTITION BY DepartmentID ORDER BY Salary) AS RunningDeptTotal
FROM HR.EMP_Details;
-- ORDER BY creates a running total within each department
-- For each employee, shows sum of their salary plus all lower salaries in their dept
-- Without ORDER BY, would show total department salary on every row

-- 4. ROW_NUMBER
-- Assigns unique sequential integers to rows
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    ROW_NUMBER() OVER(ORDER BY Salary DESC) AS CompanyRank,
    ROW_NUMBER() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS DepartmentRank
FROM HR.EMP_Details;
-- CompanyRank: Numbers employees 1,2,3,... by salary across entire company
-- DepartmentRank: Numbers employees 1,2,3,... by salary within each department
-- ROW_NUMBER always assigns unique numbers (no ties)

-- 5. RANK and DENSE_RANK
-- Assigns ranks to rows with ties handled differently
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    RANK() OVER(ORDER BY Salary DESC) AS SalaryRank,
    DENSE_RANK() OVER(ORDER BY Salary DESC) AS DenseSalaryRank
FROM HR.EMP_Details;
-- RANK: Same values get same rank, leaves gaps (1,1,3,4,...)
-- DENSE_RANK: Same values get same rank, no gaps (1,1,2,3,...)
-- If two employees have the same salary, they get the same rank

-- 6. NTILE
-- Divides rows into specified number of groups
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Salary,
    NTILE(4) OVER(ORDER BY Salary) AS SalaryQuartile
FROM HR.EMP_Details;
-- Divides employees into 4 equal groups (quartiles) by salary
-- 1 = bottom 25%, 4 = top 25%
-- Useful for creating bands or segments

-- 7. LAG and LEAD
-- Access data from previous or following rows
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    HireDate,
    Salary,
    LAG(Salary) OVER(ORDER BY HireDate) AS PreviousEmpSalary,
    LEAD(Salary) OVER(ORDER BY HireDate) AS NextEmpSalary,
    Salary - LAG(Salary) OVER(ORDER BY HireDate) AS SalaryGap
FROM HR.EMP_Details;
-- LAG: Retrieves value from previous row (earlier hire date)
-- LEAD: Retrieves value from next row (later hire date)
-- SalaryGap: Calculates difference between current and previous employee's salary
-- First row's LAG and last row's LEAD will be NULL

-- 8. LAG and LEAD with Offset and Default
-- Specify how many rows to look back/ahead and default value
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    HireDate,
    Salary,
    LAG(Salary, 2, 0) OVER(ORDER BY HireDate) AS Salary2EmpsBefore,
    LEAD(Salary, 3, 0) OVER(ORDER BY HireDate) AS Salary3EmpsAfter
FROM HR.EMP_Details;
-- LAG(Salary, 2, 0): Gets salary from 2 rows back, uses 0 if not available
-- LEAD(Salary, 3, 0): Gets salary from 3 rows ahead, uses 0 if not available
-- Useful for comparing with non-adjacent rows

-- 9. FIRST_VALUE and LAST_VALUE
-- Retrieve first or last value in window frame
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    FIRST_VALUE(Salary) OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS HighestDeptSalary,
    LAST_VALUE(Salary) OVER(
        PARTITION BY DepartmentID 
        ORDER BY Salary DESC
        RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS LowestDeptSalary
FROM HR.EMP_Details;
-- FIRST_VALUE: Gets highest salary in each department
-- LAST_VALUE: Gets lowest salary in each department
-- Note: LAST_VALUE needs explicit frame to work as expected

-- 10. Window Frame Specification
-- Control which rows are included in window calculations
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    HireDate,
    Salary,
    AVG(Salary) OVER(
        ORDER BY HireDate
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS MovingAvg3Employees
FROM HR.EMP_Details;
-- ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING: Current row, 1 before, 1 after
-- Creates a 3-employee moving average based on hire date
-- First and last employees use fewer rows in their calculation

-- 11. Different Window Frame Types
-- ROWS vs RANGE vs GROUPS
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    HireDate,
    Salary,
    SUM(Salary) OVER(
        ORDER BY HireDate
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS CumulativeSalaryByRows,
    SUM(Salary) OVER(
        ORDER BY HireDate
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS CumulativeSalaryByRange
FROM HR.EMP_Details;
-- ROWS: Physical rows (even if values are the same)
-- RANGE: Logical range of values (treats same values as a group)
-- Difference appears when multiple employees have same hire date

-- 12. Multiple Window Functions
-- Combining different window functions in one query
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    ROW_NUMBER() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS RowNum,
    RANK() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS SalaryRank,
    PERCENT_RANK() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS PercentRank,
    CUME_DIST() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS CumulativeDistribution
FROM HR.EMP_Details;
-- Multiple window functions provide different perspectives on the same data
-- PERCENT_RANK: Relative rank (0 to 1)
-- CUME_DIST: Cumulative distribution (0 to 1)

-- 13. Named Windows
-- Define window once and reuse in multiple functions
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    AVG(Salary) OVER w AS AvgSalary,
    MAX(Salary) OVER w AS MaxSalary,
    MIN(Salary) OVER w AS MinSalary
FROM HR.EMP_Details
WINDOW w AS (PARTITION BY DepartmentID);
-- WINDOW clause defines a named window "w"
-- Multiple functions use the same window definition
-- Makes query more readable and maintainable

-- 14. Window Functions with Aggregates
-- Combining window functions with regular aggregates
SELECT 
    DepartmentID,
    AVG(Salary) AS AvgDeptSalary,
    (
        SELECT AVG(Salary) 
        FROM HR.EMP_Details
    ) AS AvgCompanySalary,
    AVG(Salary) - (
        SELECT AVG(Salary) 
        FROM HR.EMP_Details
    ) AS DiffFromCompanyAvg
FROM HR.EMP_Details
GROUP BY DepartmentID;
-- Regular aggregates with GROUP BY
-- Subquery used to get company average
-- Shows how each department compares to company average