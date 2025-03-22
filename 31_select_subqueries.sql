-- =============================================
-- DQL Subqueries - Queries within Queries
-- =============================================

USE HRSystem;
GO

-- 1. Scalar Subquery
-- Returns a single value (one row, one column)
-- Can be used anywhere a single value is expected
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Salary,
    (SELECT AVG(Salary) FROM HR.EMP_Details) AS AvgCompanySalary,
    Salary - (SELECT AVG(Salary) FROM HR.EMP_Details) AS DiffFromAvg
FROM HR.EMP_Details;
-- Subquery calculates the average salary across the company
-- Main query shows how each employee's salary compares to this average
-- Subquery runs once and returns a single value

-- 2. Column Subquery
-- Returns a single column with multiple rows
-- Used with IN, ANY, ALL operators
SELECT 
    EmployeeID,
    FirstName,
    LastName
FROM HR.EMP_Details
WHERE DepartmentID IN (
    SELECT DepartmentID 
    FROM HR.Departments 
    WHERE DepartmentName LIKE '%IT%' OR DepartmentName LIKE '%Tech%'
);
-- Subquery returns a list of department IDs matching the criteria
-- Main query finds employees in any of these departments
-- IN operator checks if a value matches any value in the list

-- 3. Row Subquery
-- Returns a single row with multiple columns
-- Used with comparison operators
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    HireDate
FROM HR.EMP_Details
WHERE (Salary, DepartmentID) = (
    SELECT MAX(Salary), 1
    FROM HR.EMP_Details
    WHERE DepartmentID = 1
);
-- Subquery returns highest salary in department 1 and the department ID
-- Main query finds the employee with this exact salary and department
-- Compares multiple columns at once

-- 4. Table Subquery
-- Returns multiple rows and columns
-- Used in FROM clause as a derived table
SELECT 
    d.DepartmentName,
    e.EmployeeCount,
    e.AvgSalary
FROM HR.Departments d
JOIN (
    SELECT 
        DepartmentID,
        COUNT(*) AS EmployeeCount,
        AVG(Salary) AS AvgSalary
    FROM HR.EMP_Details
    GROUP BY DepartmentID
) e ON d.DepartmentID = e.DepartmentID;
-- Subquery creates a derived table with department statistics
-- Main query joins this to the Departments table
-- Allows complex aggregations to be joined to other tables

-- 5. Correlated Subquery
-- References columns from the outer query
-- Runs once for each row processed by outer query
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    e.Salary,
    (SELECT AVG(Salary) FROM HR.EMP_Details WHERE DepartmentID = e.DepartmentID) AS AvgDeptSalary
FROM HR.EMP_Details e;
-- For each employee, subquery calculates average salary in their department
-- Subquery references e.DepartmentID from the outer query
-- Subquery runs once per row in the outer query

-- 6. EXISTS Subquery
-- Tests for existence of rows
-- Returns TRUE if subquery returns any rows, FALSE otherwise
SELECT 
    d.DepartmentID,
    d.DepartmentName
FROM HR.Departments d
WHERE EXISTS (
    SELECT 1 
    FROM HR.EMP_Details e 
    WHERE e.DepartmentID = d.DepartmentID AND e.Salary > 80000
);
-- Returns departments that have at least one employee earning over $80,000
-- Subquery checks if any matching employees exist
-- Efficient because it stops searching once any match is found

-- 7. NOT EXISTS Subquery
-- Tests for non-existence of rows
-- Returns TRUE if subquery returns no rows
SELECT 
    d.DepartmentID,
    d.DepartmentName
FROM HR.Departments d
WHERE NOT EXISTS (
    SELECT 1 
    FROM HR.EMP_Details e 
    WHERE e.DepartmentID = d.DepartmentID
);
-- Returns departments that have no employees
-- Subquery checks if any matching employees exist
-- NOT EXISTS returns TRUE when no matches are found

-- 8. Subquery with ANY/SOME
-- Returns TRUE if any comparison is TRUE
-- ANY and SOME are identical in functionality
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Salary
FROM HR.EMP_Details
WHERE Salary > ANY (
    SELECT AVG(Salary)
    FROM HR.EMP_Details
    GROUP BY DepartmentID
);
-- Returns employees whose salary is higher than at least one department's average
-- Subquery returns average salary for each department
-- ANY operator checks if salary exceeds any of these averages

-- 9. Subquery with ALL
-- Returns TRUE if all comparisons are TRUE
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Salary
FROM HR.EMP_Details
WHERE Salary > ALL (
    SELECT AVG(Salary)
    FROM HR.EMP_Details
    GROUP BY DepartmentID
);
-- Returns employees whose salary is higher than ALL department averages
-- Subquery returns average salary for each department
-- ALL operator checks if salary exceeds every one of these averages

-- 10. Nested Subqueries
-- Subqueries within subqueries
SELECT 
    EmployeeID,
    FirstName,
    LastName
FROM HR.EMP_Details
WHERE DepartmentID IN (
    SELECT DepartmentID
    FROM HR.Departments
    WHERE LocationID IN (
        SELECT LocationID
        FROM HR.Locations
        WHERE Country = 'USA'
    )
);
-- Inner subquery finds locations in USA
-- Middle subquery finds departments at these locations
-- Outer query finds employees in these departments
-- Each subquery feeds its results to the level above it

-- 11. Common Table Expressions (CTEs)
-- Named temporary result sets
WITH EmployeeStats AS (
    SELECT 
        DepartmentID,
        COUNT(*) AS EmployeeCount,
        AVG(Salary) AS AvgSalary
    FROM HR.EMP_Details
    GROUP BY DepartmentID
)
SELECT 
    d.DepartmentName,
    es.EmployeeCount,
    es.AvgSalary
FROM HR.Departments d
JOIN EmployeeStats es ON d.DepartmentID = es.DepartmentID;
-- CTE defines a named result set (EmployeeStats)
-- Main query uses this CTE like a regular table
-- Makes complex queries more readable than nested subqueries

-- 12. Multiple CTEs
-- Using multiple CTEs in the same query
WITH DepartmentStats AS (
    SELECT 
        DepartmentID,
        COUNT(*) AS EmployeeCount,
        AVG(Salary) AS AvgSalary
    FROM HR.EMP_Details
    GROUP BY DepartmentID
),
HighPaidDepts AS (
    SELECT DepartmentID
    FROM DepartmentStats
    WHERE AvgSalary > 70000
)
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    d.DepartmentName
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.DepartmentID IN (SELECT DepartmentID FROM HighPaidDepts);
-- First CTE calculates department statistics
-- Second CTE finds high-paying departments (using the first CTE)
-- Main query finds employees in these departments
-- Each CTE can reference CTEs defined before it