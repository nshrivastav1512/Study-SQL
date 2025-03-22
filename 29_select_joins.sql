-- =============================================
-- DQL Joins - Combining Data from Multiple Tables
-- =============================================

USE HRSystem;
GO

-- 1. INNER JOIN
-- Returns only matching rows from both tables
-- Most common join type - returns only when there's a match in both tables
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName
FROM HR.EMP_Details e
INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID;
-- Only employees with valid departments and departments with employees are returned
-- If an employee has no department or a department has no employees, those rows are excluded

-- 2. LEFT JOIN (LEFT OUTER JOIN)
-- Returns all rows from left table and matching rows from right table
-- Non-matching rows from right table contain NULL values
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName
FROM HR.EMP_Details e
LEFT JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID;
-- All employees are returned, even those without a department
-- If an employee has no department, DepartmentName will be NULL

-- 3. RIGHT JOIN (RIGHT OUTER JOIN)
-- Returns all rows from right table and matching rows from left table
-- Non-matching rows from left table contain NULL values
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName
FROM HR.EMP_Details e
RIGHT JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID;
-- All departments are returned, even those without employees
-- If a department has no employees, employee fields will be NULL

-- 4. FULL JOIN (FULL OUTER JOIN)
-- Returns all rows from both tables
-- Non-matching rows from either table contain NULL values
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName
FROM HR.EMP_Details e
FULL JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID;
-- All employees and all departments are returned
-- Shows NULL for employee fields when department has no employees
-- Shows NULL for department fields when employee has no department

-- 5. CROSS JOIN
-- Cartesian product - every row from first table joined with every row from second
-- No join condition needed - creates all possible combinations
SELECT 
    e.FirstName,
    e.LastName,
    s.SkillName
FROM HR.EMP_Details e
CROSS JOIN HR.Skills s;
-- If there are 100 employees and 20 skills, this returns 2,000 rows
-- Useful for generating combinations or when you need all possible pairings

-- 6. Self Join
-- Joining a table to itself (using different aliases)
-- Useful for hierarchical data or comparing rows within same table
SELECT 
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS Employee,
    m.FirstName + ' ' + m.LastName AS Manager
FROM HR.EMP_Details e
LEFT JOIN HR.EMP_Details m ON e.ManagerID = m.EmployeeID;
-- Shows each employee with their manager's name
-- Uses LEFT JOIN to include employees without managers (NULL in Manager column)

-- 7. Multi-Table Joins
-- Joining more than two tables together
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName,
    l.LocationName,
    p.ProjectName
FROM HR.EMP_Details e
INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
INNER JOIN HR.Locations l ON d.LocationID = l.LocationID
LEFT JOIN HR.EmployeeProjects ep ON e.EmployeeID = ep.EmployeeID
LEFT JOIN HR.Projects p ON ep.ProjectID = p.ProjectID;
-- Joins employees to departments to locations to projects
-- INNER JOINs for required relationships, LEFT JOINs for optional ones

-- 8. Non-Equi Joins
-- Joins using conditions other than equality
SELECT 
    e1.EmployeeID,
    e1.FirstName,
    e1.LastName,
    e1.Salary,
    e2.EmployeeID AS HigherPaidID,
    e2.FirstName AS HigherPaidFirstName,
    e2.LastName AS HigherPaidLastName,
    e2.Salary AS HigherSalary
FROM HR.EMP_Details e1
INNER JOIN HR.EMP_Details e2 ON e1.Salary < e2.Salary AND e1.DepartmentID = e2.DepartmentID;
-- Finds all employees who earn less than other employees in the same department
-- Join condition uses < instead of = and adds a second condition with AND

-- 9. Joining with Subqueries
-- Using a subquery as a table in a join
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    e.Salary,
    d.AvgSalary,
    e.Salary - d.AvgSalary AS Difference
FROM HR.EMP_Details e
INNER JOIN (
    SELECT 
        DepartmentID, 
        AVG(Salary) AS AvgSalary
    FROM HR.EMP_Details
    GROUP BY DepartmentID
) d ON e.DepartmentID = d.DepartmentID;
-- Joins employees to a derived table of department averages
-- Shows how each employee's salary compares to their department average

-- 10. Filtered Joins
-- Adding WHERE conditions after joins
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName
FROM HR.EMP_Details e
INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.Salary > 50000 AND d.DepartmentName LIKE 'F%';
-- First joins the tables, then filters the joined results
-- Returns only high-paid employees in departments starting with 'F'

-- 11. Finding Unmatched Records
-- Using LEFT JOIN and IS NULL to find records without matches
SELECT 
    d.DepartmentID,
    d.DepartmentName
FROM HR.Departments d
LEFT JOIN HR.EMP_Details e ON d.DepartmentID = e.DepartmentID
WHERE e.EmployeeID IS NULL;
-- Returns departments that have no employees
-- The IS NULL check finds departments where no matching employee was found

-- 12. APPLY Operator (CROSS APPLY and OUTER APPLY)
-- Applying a table-valued function to each row of a table

-- CROSS APPLY (like INNER JOIN with a function)
SELECT 
    d.DepartmentID,
    d.DepartmentName,
    e.EmployeeID,
    e.FirstName,
    e.LastName
FROM HR.Departments d
CROSS APPLY (
    SELECT TOP 3 *
    FROM HR.EMP_Details
    WHERE DepartmentID = d.DepartmentID
    ORDER BY Salary DESC
) e;
-- For each department, finds the 3 highest-paid employees
-- Departments with fewer than 3 employees will still appear with fewer rows
-- Departments with no employees won't appear at all (like INNER JOIN)

-- OUTER APPLY (like LEFT JOIN with a function)
SELECT 
    d.DepartmentID,
    d.DepartmentName,
    e.EmployeeID,
    e.FirstName,
    e.LastName
FROM HR.Departments d
OUTER APPLY (
    SELECT TOP 3 *
    FROM HR.EMP_Details
    WHERE DepartmentID = d.DepartmentID
    ORDER BY Salary DESC
) e;
-- Similar to CROSS APPLY but includes departments with no employees
-- For departments with no employees, employee fields will be NULL