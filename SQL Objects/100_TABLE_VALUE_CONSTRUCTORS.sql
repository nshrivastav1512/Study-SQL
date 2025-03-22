-- =============================================
-- SQL Server Table Value Constructors Guide
-- Demonstrates various ways to create and use
-- table-valued data in SQL Server
-- =============================================

USE HRSystem;
GO

-- =============================================
-- PART 1: Basic Table Value Constructor
-- =============================================

-- Simple VALUES clause constructor
SELECT *
FROM (VALUES
    (1, 'John', 'Developer'),
    (2, 'Mary', 'Manager'),
    (3, 'David', 'Analyst')
) AS Employees(ID, Name, Role);

-- Using constructor in INSERT
CREATE TABLE #TempEmployees (
    ID INT,
    Name NVARCHAR(50),
    Role NVARCHAR(50)
);

INSERT INTO #TempEmployees
VALUES
    (1, 'John', 'Developer'),
    (2, 'Mary', 'Manager'),
    (3, 'David', 'Analyst');

-- =============================================
-- PART 2: Table Constructor in JOIN Operations
-- =============================================

-- Join with constructed table
SELECT e.FirstName, e.LastName, r.NewRole
FROM HR.Employees e
JOIN (VALUES
    (1, 'Senior Developer'),
    (2, 'Project Manager'),
    (3, 'Business Analyst')
) AS r(EmployeeID, NewRole)
ON e.EmployeeID = r.EmployeeID;

-- Multiple column constructor
SELECT e.*, s.Bonus, s.ReviewDate
FROM HR.Employees e
JOIN (VALUES
    (1, 5000, '2023-12-01'),
    (2, 7500, '2023-12-15'),
    (3, 4000, '2023-12-30')
) AS s(EmployeeID, Bonus, ReviewDate)
ON e.EmployeeID = s.EmployeeID;

-- =============================================
-- PART 3: Derived Tables with Constructors
-- =============================================

-- Salary ranges with constructors
SELECT e.FirstName, e.LastName, e.Salary,
       r.Range AS SalaryRange
FROM HR.Employees e
CROSS APPLY (VALUES
    ('Entry', 30000, 50000),
    ('Mid', 50001, 80000),
    ('Senior', 80001, 120000)
) AS r(Range, MinSalary, MaxSalary)
WHERE e.Salary BETWEEN r.MinSalary AND r.MaxSalary;

-- Department budget allocation
SELECT d.DepartmentName,
       b.Budget,
       b.AllocationDate
FROM HR.Departments d
JOIN (VALUES
    (1, 500000, '2024-01-01'),
    (2, 750000, '2024-01-01'),
    (3, 600000, '2024-01-01')
) AS b(DeptID, Budget, AllocationDate)
ON d.DepartmentID = b.DeptID;

-- =============================================
-- PART 4: Advanced Constructor Scenarios
-- =============================================

-- Conditional value assignment
SELECT e.FirstName, e.LastName,
       CASE 
           WHEN e.Salary >= s.Threshold THEN s.Bonus
           ELSE 0
       END AS BonusAmount
FROM HR.Employees e
CROSS APPLY (VALUES
    (50000, 2000),
    (75000, 3500),
    (100000, 5000)
) AS s(Threshold, Bonus)
WHERE e.Salary >= s.Threshold;

-- Multiple value sets for comparison
SELECT e.FirstName, e.LastName,
       e.DepartmentID,
       t.Quarter,
       t.Target
FROM HR.Employees e
CROSS APPLY (VALUES
    (1, 'Q1', 25000),
    (1, 'Q2', 30000),
    (2, 'Q1', 35000),
    (2, 'Q2', 40000)
) AS t(DeptID, Quarter, Target)
WHERE e.DepartmentID = t.DeptID;

-- =============================================
-- PART 5: Best Practices and Tips
-- =============================================

/*
1. Performance Considerations:
   - Table value constructors are best for small sets of data
   - Use for static reference data or lookup values
   - Consider temp tables for larger datasets

2. Maintainability:
   - Keep constructor values organized and aligned
   - Add comments for complex value sets
   - Use meaningful alias names

3. Common Use Cases:
   - Test data generation
   - Static lookup tables
   - Parameter tables for stored procedures
   - Quick data comparisons
*/

-- Example of well-structured constructor
SELECT e.FirstName, e.LastName,
       p.Level,
       p.MinSalary,
       p.MaxSalary
FROM HR.Employees e
CROSS APPLY (VALUES
    -- Level    MinSalary  MaxSalary
    ('Junior',  40000,     60000),
    ('Mid',     60001,     90000),
    ('Senior',  90001,     120000),
    ('Lead',    120001,    150000)
) AS p(Level, MinSalary, MaxSalary)
WHERE e.Salary BETWEEN p.MinSalary AND p.MaxSalary
ORDER BY p.MinSalary;

-- Cleanup
DROP TABLE #TempEmployees;
GO