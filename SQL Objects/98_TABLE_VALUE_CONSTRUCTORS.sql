-- =============================================
-- SQL Server Table Value Constructors Guide
-- =============================================

USE HRSystem;
GO

-- =============================================
-- PART 1: Basic Table Value Constructor
-- =============================================

-- 1. Simple single-row constructor
SELECT *
FROM (VALUES (1, 'John', 'Developer')) AS Employee(ID, Name, Role);

-- 2. Multi-row constructor
SELECT *
FROM (VALUES 
    (1, 'John', 'Developer'),
    (2, 'Mary', 'Manager'),
    (3, 'Bob', 'Analyst')
) AS Employees(ID, Name, Role);

-- =============================================
-- PART 2: Practical HR Scenarios
-- =============================================

-- 1. Department Budget Planning
DECLARE @DeptBudgets TABLE (
    DepartmentID INT,
    DepartmentName VARCHAR(50),
    AnnualBudget DECIMAL(12,2)
);

INSERT INTO @DeptBudgets
SELECT *
FROM (VALUES
    (1, 'IT', 1000000.00),
    (2, 'HR', 500000.00),
    (3, 'Finance', 750000.00),
    (4, 'Marketing', 600000.00)
) AS Budgets(DeptID, DeptName, Budget);

-- Compare with actual spending
SELECT 
    d.DepartmentName,
    b.AnnualBudget,
    SUM(e.Salary) AS ActualSpending
FROM @DeptBudgets b
JOIN HR.Departments d ON b.DepartmentID = d.DepartmentID
JOIN HR.Employees e ON d.DepartmentID = e.DepartmentID
GROUP BY d.DepartmentName, b.AnnualBudget;

-- 2. Skill Matrix Definition
SELECT s.EmployeeID, e.FirstName, s.SkillName, s.ProficiencyLevel
FROM (VALUES
    (1, 'SQL', 'Expert'),
    (1, 'Python', 'Intermediate'),
    (2, 'Java', 'Expert'),
    (2, 'SQL', 'Beginner')
) AS s(EmployeeID, SkillName, ProficiencyLevel)
JOIN HR.Employees e ON s.EmployeeID = e.EmployeeID;

-- =============================================
-- PART 3: Advanced Usage
-- =============================================

-- 1. Combining with JOIN operations
SELECT 
    e.FirstName,
    e.LastName,
    p.ProjectName,
    p.Role
FROM HR.Employees e
JOIN (VALUES
    (1, 'CRM Upgrade', 'Lead'),
    (2, 'Mobile App', 'Developer'),
    (3, 'Cloud Migration', 'Architect')
) AS p(EmployeeID, ProjectName, Role)
ON e.EmployeeID = p.EmployeeID;

-- 2. Using in UPDATE statements
UPDATE HR.Employees
SET Salary = v.NewSalary
FROM (VALUES
    (1, 75000),
    (2, 85000),
    (3, 95000)
) AS v(EmployeeID, NewSalary)
WHERE HR.Employees.EmployeeID = v.EmployeeID;

-- =============================================
-- PART 4: Performance Considerations
-- =============================================

/*
1. Table Value Constructors are ideal for:
   - Small lookup tables
   - Test data generation
   - Parameter tables for stored procedures

2. Benefits:
   - Clean, readable syntax
   - No temporary table overhead
   - Efficient for small datasets

3. Limitations:
   - Not suitable for large datasets
   - Limited to 1000 rows per constructor
   - Cannot use subqueries within VALUES clause
*/

-- =============================================
-- PART 5: Best Practices
-- =============================================

/*
1. Always specify column names for clarity
2. Use appropriate data types
3. Keep row count under 1000
4. Consider using temporary tables for larger datasets
5. Maintain consistent column order
*/

-- Example of best practices
DECLARE @PerformanceRatings TABLE (
    EmployeeID INT,
    ReviewDate DATE,
    Rating DECIMAL(3,2),
    Comments VARCHAR(100)
);

-- Well-structured, clearly named columns
INSERT INTO @PerformanceRatings
SELECT *
FROM (VALUES
    (1, '2023-01-01', 4.5, 'Excellent team player'),
    (2, '2023-01-01', 4.0, 'Strong technical skills'),
    (3, '2023-01-01', 3.5, 'Good communication')
) AS Ratings(EmpID, ReviewDate, Score, Feedback);