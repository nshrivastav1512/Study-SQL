-- =============================================
-- DQL Basics - SELECT Fundamentals
-- =============================================

USE HRSystem;
GO

-- 1. Basic SELECT Statement
-- Retrieves all columns (*) and all rows from the HR.EMP_Details table
-- This returns everything in the table - all columns, all rows
SELECT * FROM HR.EMP_Details;
-- Note: Using * is convenient but not recommended for production code
-- as it retrieves unnecessary columns and can impact performance

-- 2. Selecting Specific Columns
-- Only retrieves the columns you actually need
-- This is more efficient than SELECT * as it transfers less data
SELECT EmployeeID, FirstName, LastName, Email 
FROM HR.EMP_Details;
-- The result will have exactly these 4 columns in this order

-- 3. Column Aliases
-- Renames columns in the result set for better readability
-- AS keyword creates an alias (temporary name) for the column
SELECT 
    EmployeeID AS ID,                -- Column will be called "ID" in results
    FirstName AS [First Name],       -- Square brackets allow spaces in alias names
    LastName AS [Last Name],         -- Without brackets: LastName AS Last_Name
    Email AS [Contact Email]
FROM HR.EMP_Details;
-- Note: Aliases only exist in the result set, not in the actual table

-- 4. Literal Values
-- Includes constant values in your results
-- Useful for adding status indicators or timestamps
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    'Active' AS Status,              -- Adds "Active" text to every row
    GETDATE() AS [Report Date]       -- Adds current date/time to every row
FROM HR.EMP_Details;
-- GETDATE() is a function that returns the current date and time

-- 5. Arithmetic Operations
-- Performs calculations directly in the SELECT statement
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Salary,
    Salary * 1.1 AS [Salary After 10% Raise],   -- Multiplies Salary by 1.1
    Salary * 12 AS [Annual Salary]              -- Multiplies Salary by 12
FROM HR.EMP_Details;
-- These calculations are performed for each row but don't change the database

-- 6. DISTINCT Keyword
-- Removes duplicate values from the result set
-- Only unique values will be returned
SELECT DISTINCT DepartmentID 
FROM HR.EMP_Details;
-- If there are 100 employees but only 5 departments, this returns just 5 rows

-- 7. TOP Clause
-- Limits the number of rows returned
-- Useful for retrieving only the highest/lowest values
SELECT TOP 10 * 
FROM HR.EMP_Details
ORDER BY Salary DESC;
-- Returns the 10 highest-paid employees (because of ORDER BY Salary DESC)

-- 8. TOP with PERCENT
-- Returns a percentage of rows instead of a fixed number
SELECT TOP 5 PERCENT * 
FROM HR.EMP_Details
ORDER BY HireDate DESC;
-- If there are 200 employees, this returns the 10 most recently hired (5% of 200)

-- 9. TOP with TIES
-- Includes additional rows that have the same values as the last row
SELECT TOP 5 WITH TIES * 
FROM HR.EMP_Details
ORDER BY Salary DESC;
-- If the 5th and 6th highest salaries are the same, both will be included

-- 10. Simple WHERE Clause
-- Filters rows based on a condition
-- Only rows that satisfy the condition are returned
SELECT * 
FROM HR.EMP_Details
WHERE DepartmentID = 3;
-- Returns only employees in department #3

-- 11. Multiple WHERE Conditions
-- Combines multiple filters with AND/OR
-- All conditions must be true when using AND
SELECT * 
FROM HR.EMP_Details
WHERE Salary > 50000 
AND DepartmentID = 2;
-- Returns employees in department #2 who earn more than $50,000

-- 12. ORDER BY Clause
-- Sorts the result set
-- Can sort by multiple columns (primary sort, secondary sort, etc.)
SELECT EmployeeID, FirstName, LastName, Salary 
FROM HR.EMP_Details
ORDER BY Salary DESC, LastName ASC;
-- Sorts by Salary (highest first), then by LastName (A to Z) when salaries are equal

-- 13. NULL Values
-- Finds rows with NULL values
-- NULL means "no value" or "unknown value" (not zero or empty string)
SELECT * 
FROM HR.EMP_Details
WHERE ManagerID IS NULL;
-- Returns employees who don't have a manager (likely top-level executives)

-- 14. OFFSET-FETCH
-- Implements pagination (skipping rows and limiting results)
-- Useful for displaying data page by page in applications
SELECT * 
FROM HR.EMP_Details
ORDER BY EmployeeID
OFFSET 10 ROWS          -- Skip the first 10 rows
FETCH NEXT 10 ROWS ONLY; -- Get the next 10 rows
-- Returns rows 11-20 (second page if page size is 10)

-- 15. Simple CASE Expression
-- Implements conditional logic in SELECT
-- Works like an IF-THEN-ELSE statement
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    CASE DepartmentID
        WHEN 1 THEN 'HR'           -- If DepartmentID = 1, show 'HR'
        WHEN 2 THEN 'IT'           -- If DepartmentID = 2, show 'IT'
        WHEN 3 THEN 'Finance'      -- If DepartmentID = 3, show 'Finance'
        ELSE 'Other'               -- For any other value, show 'Other'
    END AS Department
FROM HR.EMP_Details;
-- Translates numeric department IDs into readable department names