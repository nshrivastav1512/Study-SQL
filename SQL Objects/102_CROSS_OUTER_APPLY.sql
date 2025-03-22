-- =============================================
-- SQL Server CROSS/OUTER APPLY Guide
-- Demonstrates practical usage of APPLY operators
-- in HR scenarios with performance considerations
-- =============================================

USE HRSystem;
GO

-- =============================================
-- PART 1: Basic CROSS APPLY Usage
-- =============================================

-- 1. Employee Skills Matrix
SELECT 
    e.FirstName,
    e.LastName,
    s.SkillName,
    s.ProficiencyLevel
FROM HR.Employees e
CROSS APPLY (
    SELECT TOP 3 SkillName, ProficiencyLevel
    FROM HR.EmployeeSkills
    WHERE EmployeeID = e.EmployeeID
    ORDER BY ProficiencyLevel DESC
) s;

-- 2. Latest Performance Reviews
SELECT 
    e.FirstName,
    e.LastName,
    r.ReviewDate,
    r.Rating,
    r.Comments
FROM HR.Employees e
CROSS APPLY (
    SELECT TOP 1 ReviewDate, Rating, Comments
    FROM HR.PerformanceReviews
    WHERE EmployeeID = e.EmployeeID
    ORDER BY ReviewDate DESC
) r;

-- =============================================
-- PART 2: OUTER APPLY Usage
-- =============================================

-- 1. Employee Sales Performance (including non-performers)
SELECT 
    e.FirstName,
    e.LastName,
    ISNULL(s.TotalSales, 0) as TotalSales,
    ISNULL(s.SalesCount, 0) as SalesCount
FROM HR.Employees e
OUTER APPLY (
    SELECT 
        COUNT(*) as SalesCount,
        SUM(Amount) as TotalSales
    FROM HR.Sales
    WHERE EmployeeID = e.EmployeeID
    AND YEAR(SaleDate) = YEAR(GETDATE())
) s;

-- 2. Department Budget Analysis
SELECT 
    d.DepartmentName,
    ISNULL(b.TotalBudget, 0) as AllocatedBudget,
    ISNULL(b.UsedBudget, 0) as UsedBudget
FROM HR.Departments d
OUTER APPLY (
    SELECT 
        SUM(Amount) as TotalBudget,
        SUM(CASE WHEN IsSpent = 1 THEN Amount ELSE 0 END) as UsedBudget
    FROM HR.DepartmentBudgets
    WHERE DepartmentID = d.DepartmentID
    AND FiscalYear = YEAR(GETDATE())
) b;

-- =============================================
-- PART 3: Complex Scenarios
-- =============================================

-- 1. Employee Career Progression
SELECT 
    e.FirstName,
    e.LastName,
    p.CurrentPosition,
    p.YearsInPosition,
    p.PreviousPosition
FROM HR.Employees e
CROSS APPLY (
    SELECT 
        Position as CurrentPosition,
        DATEDIFF(YEAR, StartDate, GETDATE()) as YearsInPosition,
        LAG(Position) OVER (ORDER BY StartDate) as PreviousPosition
    FROM HR.EmployeePositions
    WHERE EmployeeID = e.EmployeeID
    AND EndDate IS NULL
) p;

-- 2. Training Completion Status
SELECT 
    e.FirstName,
    e.LastName,
    t.RequiredTrainings,
    t.CompletedTrainings,
    t.CompletionRate
FROM HR.Employees e
OUTER APPLY (
    SELECT 
        COUNT(*) as RequiredTrainings,
        SUM(CASE WHEN CompletionDate IS NOT NULL THEN 1 ELSE 0 END) as CompletedTrainings,
        CAST(SUM(CASE WHEN CompletionDate IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as DECIMAL(5,2)) as CompletionRate
    FROM HR.EmployeeTraining
    WHERE EmployeeID = e.EmployeeID
    AND YEAR(DueDate) = YEAR(GETDATE())
) t;

-- =============================================
-- PART 4: Performance Best Practices
-- =============================================

/*
1. CROSS APPLY vs OUTER APPLY:
   - Use CROSS APPLY when you need inner join semantics
   - Use OUTER APPLY when you need left outer join semantics
   - CROSS APPLY performs better for non-NULL matches

2. Optimization Tips:
   - Include appropriate indexes on joined columns
   - Limit rows with TOP or WHERE clauses
   - Consider materialization for complex subqueries
   - Use appropriate indexes on sorting columns

3. Common Use Cases:
   - Row-by-row calculations
   - Complex filtering
   - Dynamic pivoting
   - Calling table-valued functions
*/

-- Example of optimized query
SELECT 
    e.FirstName,
    e.LastName,
    p.MetricsData
FROM HR.Employees e
CROSS APPLY (
    SELECT TOP 1
        CONCAT(
            'Sales: ', FORMAT(SUM(Amount), 'C'),
            ' | Clients: ', COUNT(DISTINCT ClientID),
            ' | Avg Deal: ', FORMAT(AVG(Amount), 'C')
        ) as MetricsData
    FROM HR.Sales
    WHERE EmployeeID = e.EmployeeID
    AND SaleDate >= DATEADD(MONTH, -3, GETDATE())
) p;
GO