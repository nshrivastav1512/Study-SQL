-- =============================================
-- SQL Server PIVOT/UNPIVOT Operations Guide
-- =============================================

USE HRSystem;
GO

-- =============================================
-- PART 1: BASIC PIVOT OPERATIONS
-- =============================================

-- 1. Simple PIVOT Example: Employee Count by Department and Year
-- This shows how many employees were hired in each department per year
SELECT *
FROM (
    SELECT 
        DepartmentName,
        YEAR(HireDate) AS HireYear,
        EmployeeID
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
) AS SourceData
PIVOT (
    COUNT(EmployeeID)
    FOR HireYear IN ([2020], [2021], [2022], [2023])
) AS PivotTable;

-- 2. Salary Analysis: Average Salary by Department and Quarter
SELECT *
FROM (
    SELECT 
        DepartmentName,
        'Q' + CAST(DATEPART(QUARTER, HireDate) AS VARCHAR) AS Quarter,
        Salary
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
) AS SourceData
PIVOT (
    AVG(Salary)
    FOR Quarter IN ([Q1], [Q2], [Q3], [Q4])
) AS PivotTable;

-- =============================================
-- PART 2: ADVANCED PIVOT SCENARIOS
-- =============================================

-- 1. Dynamic PIVOT with Variable Columns
DECLARE @Columns NVARCHAR(MAX);
DECLARE @SQL NVARCHAR(MAX);

-- Get unique years dynamically
SELECT @Columns = STRING_AGG(QUOTENAME(CAST(Year AS VARCHAR)), ',')
FROM (
    SELECT DISTINCT YEAR(HireDate) AS Year
    FROM HR.Employees
) AS Years;

-- Build and execute dynamic pivot query
SET @SQL = N'
SELECT *
FROM (
    SELECT 
        DepartmentName,
        YEAR(HireDate) AS HireYear,
        Salary
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
) AS SourceData
PIVOT (
    AVG(Salary)
    FOR HireYear IN (' + @Columns + ')
) AS PivotTable;';

EXEC sp_executesql @SQL;

-- 2. Multiple Aggregations in PIVOT
-- Shows both count and average salary
WITH EmployeeStats AS (
    SELECT 
        DepartmentName,
        YEAR(HireDate) AS HireYear,
        COUNT(*) AS EmpCount,
        AVG(Salary) AS AvgSalary
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    GROUP BY DepartmentName, YEAR(HireDate)
)
SELECT *
FROM EmployeeStats
PIVOT (
    SUM(EmpCount)
    FOR HireYear IN ([2020], [2021], [2022], [2023])
) AS CountPivot;

-- =============================================
-- PART 3: UNPIVOT OPERATIONS
-- =============================================

-- 1. Basic UNPIVOT Example
-- Converting quarterly performance ratings from columns to rows
CREATE TABLE #EmployeeQuarterlyRatings (
    EmployeeID INT,
    Q1_Rating DECIMAL(3,2),
    Q2_Rating DECIMAL(3,2),
    Q3_Rating DECIMAL(3,2),
    Q4_Rating DECIMAL(3,2)
);

-- Sample data
INSERT INTO #EmployeeQuarterlyRatings VALUES
(1, 4.5, 4.2, 4.7, 4.8),
(2, 3.8, 4.0, 4.1, 4.3);

-- UNPIVOT the ratings
SELECT EmployeeID, Quarter, Rating
FROM #EmployeeQuarterlyRatings
UNPIVOT (
    Rating FOR Quarter IN (Q1_Rating, Q2_Rating, Q3_Rating, Q4_Rating)
) AS UnpivotedRatings;

-- 2. Dynamic UNPIVOT
DECLARE @UnpivotColumns NVARCHAR(MAX);
DECLARE @UnpivotSQL NVARCHAR(MAX);

-- Get column names dynamically
SELECT @UnpivotColumns = STRING_AGG(QUOTENAME(name), ',')
FROM sys.columns
WHERE object_id = OBJECT_ID('tempdb..#EmployeeQuarterlyRatings')
    AND name LIKE '%Rating';

-- Build and execute dynamic unpivot query
SET @UnpivotSQL = N'
SELECT EmployeeID, Quarter, Rating
FROM #EmployeeQuarterlyRatings
UNPIVOT (
    Rating FOR Quarter IN (' + @UnpivotColumns + ')
) AS UnpivotedRatings;';

EXEC sp_executesql @UnpivotSQL;

-- =============================================
-- PART 4: PRACTICAL HR SCENARIOS
-- =============================================

-- 1. Skills Matrix Analysis
-- Creating a skills matrix table
CREATE TABLE #EmployeeSkills (
    EmployeeID INT,
    Technical_Skills INT,
    Communication_Skills INT,
    Leadership_Skills INT,
    Problem_Solving INT
);

-- Sample data
INSERT INTO #EmployeeSkills VALUES
(1, 5, 4, 3, 5),
(2, 4, 5, 5, 4),
(3, 3, 5, 4, 4);

-- UNPIVOT to analyze skills distribution
SELECT 
    e.FirstName + ' ' + e.LastName AS EmployeeName,
    Skill,
    Rating
FROM #EmployeeSkills es
CROSS APPLY (
    SELECT *
    FROM (SELECT EmployeeID, Technical_Skills, Communication_Skills, 
                 Leadership_Skills, Problem_Solving
          FROM #EmployeeSkills
         ) p
    UNPIVOT (
        Rating FOR Skill IN (
            Technical_Skills, Communication_Skills, 
            Leadership_Skills, Problem_Solving
        )
    ) AS unpvt
) AS SkillsUnpivoted
JOIN HR.Employees e ON e.EmployeeID = es.EmployeeID
ORDER BY EmployeeName, Skill;

-- 2. Salary Distribution Analysis
-- Pivoting salary ranges by department and experience level
WITH SalaryRanges AS (
    SELECT 
        DepartmentName,
        CASE 
            WHEN DATEDIFF(YEAR, HireDate, GETDATE()) < 2 THEN 'Junior'
            WHEN DATEDIFF(YEAR, HireDate, GETDATE()) < 5 THEN 'Mid'
            ELSE 'Senior'
        END AS ExperienceLevel,
        Salary
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
)
SELECT *
FROM SalaryRanges
PIVOT (
    AVG(Salary)
    FOR ExperienceLevel IN ([Junior], [Mid], [Senior])
) AS SalaryPivot;

-- =============================================
-- PART 5: ADVANCED TECHNIQUES
-- =============================================

-- 1. Combining PIVOT with Window Functions
WITH DepartmentStats AS (
    SELECT 
        DepartmentName,
        YEAR(HireDate) AS HireYear,
        AVG(Salary) OVER (PARTITION BY DepartmentID) AS AvgDeptSalary,
        Salary
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
)
SELECT *
FROM DepartmentStats
PIVOT (
    AVG(Salary)
    FOR HireYear IN ([2020], [2021], [2022], [2023])
) AS PivotWithWindow;

-- 2. Conditional Pivoting
-- Pivot based on salary ranges
WITH SalaryCategories AS (
    SELECT 
        DepartmentName,
        CASE 
            WHEN Salary < 50000 THEN 'Entry'
            WHEN Salary < 80000 THEN 'Mid'
            ELSE 'Senior'
        END AS SalaryBand,
        EmployeeID
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
)
SELECT *
FROM SalaryCategories
PIVOT (
    COUNT(EmployeeID)
    FOR SalaryBand IN ([Entry], [Mid], [Senior])
) AS SalaryDistribution;

-- Clean up
DROP TABLE #EmployeeQuarterlyRatings;
DROP TABLE #EmployeeSkills;
GO

-- =============================================
-- PART 6: BEST PRACTICES AND TIPS
-- =============================================

/*
1. Performance Considerations:
   - PIVOT operations can be resource-intensive for large datasets
   - Consider pre-aggregating data before pivoting
   - Use appropriate indexes on columns used in the PIVOT operation

2. Dynamic PIVOT/UNPIVOT:
   - Always sanitize dynamic column names
   - Use QUOTENAME to handle special characters in column names
   - Consider caching dynamic SQL results for frequently used queries

3. Maintenance:
   - Document the expected column structure
   - Include error handling for dynamic queries
   - Consider creating views for commonly used PIVOT/UNPIVOT operations

4. Alternatives to Consider:
   - CASE statements for simple pivots
   - Cross tab queries for basic transformations
   - Temporary tables for complex transformations
*/