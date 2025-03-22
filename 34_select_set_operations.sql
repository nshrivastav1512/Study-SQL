-- =============================================
-- DQL Set Operations - Combining Result Sets
-- =============================================

USE HRSystem;
GO

-- 1. UNION
-- Combines results and removes duplicates
SELECT EmployeeID, FirstName, LastName, 'Current' AS Status
FROM HR.EMP_Details
UNION
SELECT EmployeeID, FirstName, LastName, 'Former' AS Status
FROM HR.FormerEmployees;
-- Combines current and former employee lists
-- Removes any duplicate rows
-- Column count and data types must match between queries
-- Result is sorted by default (unless ORDER BY is specified)

-- 2. UNION ALL
-- Combines results and keeps duplicates
SELECT DepartmentID, 'Has Employees' AS Status
FROM HR.EMP_Details
UNION ALL
SELECT DepartmentID, 'Has Budget' AS Status
FROM HR.DepartmentBudgets;
-- Combines department lists without removing duplicates
-- Faster than UNION because it doesn't need to check for duplicates
-- A department can appear twice if it has both employees and budget

-- 3. INTERSECT
-- Returns only rows that exist in both result sets
SELECT DepartmentID
FROM HR.EMP_Details
INTERSECT
SELECT DepartmentID
FROM HR.DepartmentBudgets;
-- Returns departments that have both employees and budgets
-- Only matching values appear in the result
-- Duplicates are removed

-- 4. EXCEPT
-- Returns rows from first query that don't exist in second query
SELECT DepartmentID
FROM HR.Departments
EXCEPT
SELECT DepartmentID
FROM HR.EMP_Details;
-- Returns departments that exist but have no employees
-- Only shows departments from first query that don't match second query
-- Duplicates are removed

-- 5. Combining Multiple Set Operations
-- Using multiple set operations in one query
SELECT DepartmentID, 'Has Employees' AS Status
FROM HR.EMP_Details
UNION ALL
SELECT DepartmentID, 'Has Budget' AS Status
FROM HR.DepartmentBudgets
EXCEPT
SELECT DepartmentID, 'Has Budget' AS Status
FROM HR.InactiveDepartments;
-- Combines employee and budget departments
-- Then removes inactive departments with budgets
-- Operations are processed in order (unless parentheses change precedence)

-- 6. Set Operations with ORDER BY
-- Sorting combined results
(SELECT EmployeeID, FirstName, LastName, HireDate
FROM HR.EMP_Details
WHERE DepartmentID = 1)
UNION
(SELECT EmployeeID, FirstName, LastName, HireDate
FROM HR.EMP_Details
WHERE DepartmentID = 2)
ORDER BY HireDate DESC;
-- Combines employees from departments 1 and 2
-- Orders the combined result by hire date (newest first)
-- ORDER BY must be at the end, after all set operations

-- 7. Set Operations with Different Column Names
-- Column names from first query are used
SELECT EmployeeID, FirstName, LastName, Salary AS Compensation
FROM HR.EMP_Details
UNION
SELECT EmployeeID, FirstName, LastName, ContractAmount
FROM HR.Contractors;
-- Result uses column names from first query (Salary becomes Compensation)
-- Second query's ContractAmount is displayed under Compensation heading
-- Data types must still be compatible

-- 8. Set Operations with Expressions
-- Using calculated columns in set operations
SELECT 
    EmployeeID, 
    FirstName + ' ' + LastName AS FullName, 
    'Employee' AS Type
FROM HR.EMP_Details
UNION
SELECT 
    VendorID, 
    VendorName, 
    'Vendor' AS Type
FROM HR.Vendors;
-- Combines employee and vendor lists with calculated columns
-- Both queries must return same number of columns with compatible types
-- Useful for creating comprehensive directories

-- 9. INTERSECT with Multiple Conditions
-- Finding rows that match multiple criteria
SELECT EmployeeID
FROM HR.EMP_Details
WHERE Salary > 70000
INTERSECT
SELECT EmployeeID
FROM HR.EMP_Details
WHERE DepartmentID = 2
INTERSECT
SELECT EmployeeID
FROM HR.PerformanceReviews
WHERE Rating > 4;
-- Finds employees who:
-- 1. Earn more than $70,000, AND
-- 2. Work in department 2, AND
-- 3. Have performance rating above 4
-- Each condition is in a separate query connected by INTERSECT

-- 10. EXCEPT with Subqueries
-- Using subqueries with set operations
SELECT DepartmentID, DepartmentName
FROM HR.Departments
WHERE DepartmentID NOT IN (
    SELECT DepartmentID
    FROM HR.Departments
    EXCEPT
    SELECT DepartmentID
    FROM HR.EMP_Details
);
-- Finds departments that have at least one employee
-- Inner EXCEPT finds departments without employees
-- Outer NOT IN excludes these from all departments
-- Result shows only departments with employees

-- 11. Set Operations for Report Generation
-- Creating comprehensive reports
SELECT 
    'Department Total' AS Category,
    DepartmentID,
    NULL AS EmployeeID,
    SUM(Salary) AS Amount
FROM HR.EMP_Details
GROUP BY DepartmentID
UNION ALL
SELECT 
    'Employee Detail' AS Category,
    DepartmentID,
    EmployeeID,
    Salary AS Amount
FROM HR.EMP_Details
ORDER BY DepartmentID, Category DESC, EmployeeID;
-- Creates a report with both summary and detail rows
-- Summary rows show department totals
-- Detail rows show individual employee data
-- ORDER BY sorts by department, with totals before details

-- 12. Set Operations with CTEs
-- Combining CTEs using set operations
WITH CurrentQuarterHires AS (
    SELECT EmployeeID, FirstName, LastName, HireDate
    FROM HR.EMP_Details
    WHERE HireDate >= DATEADD(MONTH, -3, GETDATE())
),
HighSalaryEmployees AS (
    SELECT EmployeeID, FirstName, LastName, HireDate
    FROM HR.EMP_Details
    WHERE Salary > 80000
)
SELECT * FROM CurrentQuarterHires
INTERSECT
SELECT * FROM HighSalaryEmployees;
-- Finds employees who are both recent hires AND high-salary
-- Each CTE defines a different employee subset
-- INTERSECT finds employees in both subsets