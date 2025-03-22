-- =============================================
-- DQL Grouping and Aggregation
-- =============================================

USE HRSystem;
GO

-- 1. Basic GROUP BY
-- Groups rows with the same values into summary rows
SELECT 
    DepartmentID,
    COUNT(*) AS EmployeeCount
FROM HR.EMP_Details
GROUP BY DepartmentID;
-- Counts employees in each department
-- Each unique DepartmentID appears once in the result
-- Without GROUP BY, COUNT(*) would return a single total

-- 2. Multiple Grouping Columns
-- Groups by combinations of values
SELECT 
    DepartmentID,
    JobTitle,
    COUNT(*) AS EmployeeCount,
    AVG(Salary) AS AvgSalary
FROM HR.EMP_Details
GROUP BY DepartmentID, JobTitle;
-- Groups by unique combinations of department and job title
-- Shows count and average salary for each combination

-- 3. Aggregate Functions
-- Functions that operate on groups of rows
SELECT 
    DepartmentID,
    COUNT(*) AS EmployeeCount,           -- Number of employees
    MIN(Salary) AS MinSalary,            -- Lowest salary
    MAX(Salary) AS MaxSalary,            -- Highest salary
    AVG(Salary) AS AvgSalary,            -- Average salary
    SUM(Salary) AS TotalSalaryBudget,    -- Sum of all salaries
    STRING_AGG(LastName, ', ') AS EmployeeList  -- Concatenated list of names
FROM HR.EMP_Details
GROUP BY DepartmentID;
-- Each aggregate function produces a single value per group

-- 4. HAVING Clause
-- Filters groups after aggregation (WHERE filters before grouping)
SELECT 
    DepartmentID,
    COUNT(*) AS EmployeeCount,
    AVG(Salary) AS AvgSalary
FROM HR.EMP_Details
GROUP BY DepartmentID
HAVING COUNT(*) > 5 AND AVG(Salary) > 60000;
-- Only shows departments with more than 5 employees AND average salary over $60,000
-- HAVING filters groups, WHERE would filter individual rows

-- 5. GROUP BY with ORDER BY
-- Sorts the grouped results
SELECT 
    DepartmentID,
    COUNT(*) AS EmployeeCount
FROM HR.EMP_Details
GROUP BY DepartmentID
ORDER BY COUNT(*) DESC;
-- Groups by department, then sorts by employee count (highest first)
-- Shows departments from largest to smallest

-- 6. GROUP BY with Expressions
-- Groups by calculated values
SELECT 
    YEAR(HireDate) AS HireYear,
    MONTH(HireDate) AS HireMonth,
    COUNT(*) AS HireCount
FROM HR.EMP_Details
GROUP BY YEAR(HireDate), MONTH(HireDate)
ORDER BY HireYear, HireMonth;
-- Groups employees by year and month of hire date
-- Shows hiring patterns over time

-- 7. ROLLUP - Hierarchical Grouping
-- Adds subtotals and grand totals
SELECT 
    ISNULL(CAST(DepartmentID AS VARCHAR), 'All Departments') AS Department,
    ISNULL(JobTitle, 'All Jobs') AS Job,
    COUNT(*) AS EmployeeCount,
    AVG(Salary) AS AvgSalary
FROM HR.EMP_Details
GROUP BY ROLLUP(DepartmentID, JobTitle);
-- Creates a hierarchy of totals:
-- 1. Each Department+Job combination
-- 2. Subtotals for each Department (all jobs)
-- 3. Grand total (all departments, all jobs)
-- NULL values replaced with descriptive text

-- 8. CUBE - Multi-dimensional Grouping
-- Adds all possible subtotal combinations
SELECT 
    ISNULL(CAST(DepartmentID AS VARCHAR), 'All Departments') AS Department,
    ISNULL(JobTitle, 'All Jobs') AS Job,
    COUNT(*) AS EmployeeCount
FROM HR.EMP_Details
GROUP BY CUBE(DepartmentID, JobTitle);
-- Creates all possible subtotal combinations:
-- 1. Each Department+Job combination
-- 2. Subtotals for each Department (all jobs)
-- 3. Subtotals for each Job (all departments)
-- 4. Grand total (all departments, all jobs)

-- 9. GROUPING SETS - Custom Grouping
-- Specifies exactly which groupings to include
SELECT 
    ISNULL(CAST(DepartmentID AS VARCHAR), 'All Departments') AS Department,
    ISNULL(JobTitle, 'All Jobs') AS Job,
    COUNT(*) AS EmployeeCount
FROM HR.EMP_Details
GROUP BY GROUPING SETS(
    (DepartmentID, JobTitle),  -- Group by both
    (DepartmentID),            -- Group by department only
    ()                         -- Grand total
);
-- Only creates the specified groupings:
-- 1. Each Department+Job combination
-- 2. Subtotals for each Department
-- 3. Grand total
-- No subtotals by Job alone (unlike CUBE)

-- 10. GROUPING Function
-- Identifies which columns are responsible for NULL values
SELECT 
    DepartmentID,
    JobTitle,
    COUNT(*) AS EmployeeCount,
    GROUPING(DepartmentID) AS IsDepTotal,
    GROUPING(JobTitle) AS IsJobTotal
FROM HR.EMP_Details
GROUP BY ROLLUP(DepartmentID, JobTitle);
-- GROUPING returns 1 if the NULL is from a subtotal/total, 0 otherwise
-- Helps distinguish between actual NULL values and rollup-generated NULLs

-- 11. Filtering Before Grouping
-- Use WHERE before GROUP BY to filter input rows
SELECT 
    DepartmentID,
    COUNT(*) AS EmployeeCount
FROM HR.EMP_Details
WHERE Salary > 50000  -- Only consider employees with salary > $50,000
GROUP BY DepartmentID;
-- Counts only high-paid employees in each department
-- WHERE filters rows before they're grouped

-- 12. Complex Grouping Example
-- Combining multiple techniques
SELECT 
    YEAR(HireDate) AS HireYear,
    DATENAME(MONTH, HireDate) AS HireMonth,
    DepartmentID,
    COUNT(*) AS HireCount,
    SUM(COUNT(*)) OVER(PARTITION BY YEAR(HireDate)) AS YearlyTotal,
    FORMAT(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY YEAR(HireDate)), 'N2') + '%' AS PercentOfYear
FROM HR.EMP_Details
WHERE HireDate >= '2018-01-01'
GROUP BY YEAR(HireDate), MONTH(HireDate), DATENAME(MONTH, HireDate), DepartmentID
ORDER BY HireYear, MONTH(HireDate);
-- Groups by year, month, and department
-- Shows hire count and percentage of yearly total for each group
-- Uses window function to calculate yearly totals for percentage calculation