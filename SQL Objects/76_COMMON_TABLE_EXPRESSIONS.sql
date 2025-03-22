-- =============================================
-- COMMON TABLE EXPRESSIONS (CTEs) Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Common Table Expressions (CTEs), including:
- What CTEs are and their benefits
- Basic CTE syntax and usage
- Multiple CTEs in a single query
- Recursive CTEs for hierarchical data
- CTEs vs Subqueries and Temporary Tables
- Performance considerations
- Real-world HR scenarios and best practices
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: CTE FUNDAMENTALS
-- =============================================

-- What is a CTE?
-- A Common Table Expression (CTE) is a temporary named result set that you can reference
-- within a SELECT, INSERT, UPDATE, DELETE, or MERGE statement.

-- Benefits of CTEs:
-- 1. Improved readability and maintainability of complex queries
-- 2. Ability to reference the same subquery multiple times in a single statement
-- 3. Ability to create recursive queries for hierarchical data
-- 4. Modular approach to building complex queries
-- 5. Self-documenting code through meaningful CTE names

-- Basic CTE Syntax:
-- WITH CTE_Name [(Column1, Column2, ...)] AS (
--     CTE_Query_Definition
-- )
-- Main_Query

-- =============================================
-- PART 2: BASIC CTE EXAMPLES
-- =============================================

-- 1. Simple CTE Example
-- This CTE calculates the average salary by department

WITH DepartmentAvgSalary AS (
    SELECT 
        DepartmentID,
        AVG(Salary) AS AvgSalary
    FROM HR.Employees
    WHERE Status = 'Active'
    GROUP BY DepartmentID
)
SELECT 
    d.DepartmentID,
    d.DepartmentName,
    das.AvgSalary
FROM DepartmentAvgSalary das
JOIN HR.Departments d ON das.DepartmentID = d.DepartmentID
ORDER BY das.AvgSalary DESC;

-- 2. CTE with Multiple Columns
-- This CTE identifies employees with salaries above their department average

WITH EmployeeSalaryComparison AS (
    SELECT 
        e.EmployeeID,
        e.FirstName,
        e.LastName,
        e.DepartmentID,
        e.Salary,
        AVG(e2.Salary) OVER (PARTITION BY e.DepartmentID) AS DeptAvgSalary
    FROM HR.Employees e
    JOIN HR.Employees e2 ON e.DepartmentID = e2.DepartmentID
    WHERE e.Status = 'Active' AND e2.Status = 'Active'
)
SELECT 
    esc.EmployeeID,
    esc.FirstName,
    esc.LastName,
    d.DepartmentName,
    esc.Salary,
    esc.DeptAvgSalary,
    (esc.Salary - esc.DeptAvgSalary) AS SalaryDifference,
    FORMAT((esc.Salary / esc.DeptAvgSalary - 1) * 100, 'N2') + '%' AS PercentAboveAvg
FROM EmployeeSalaryComparison esc
JOIN HR.Departments d ON esc.DepartmentID = d.DepartmentID
WHERE esc.Salary > esc.DeptAvgSalary
ORDER BY PercentAboveAvg DESC;

-- 3. CTE with Joins
-- This CTE combines employee data with their project assignments

WITH EmployeeProjects AS (
    SELECT 
        e.EmployeeID,
        e.FirstName,
        e.LastName,
        e.DepartmentID,
        p.ProjectID,
        p.ProjectName,
        pa.RoleOnProject,
        pa.HoursAllocated
    FROM HR.Employees e
    JOIN ProjectAssignments pa ON e.EmployeeID = pa.EmployeeID
    JOIN Projects p ON pa.ProjectID = p.ProjectID
    WHERE e.Status = 'Active' AND p.Status IN ('Not Started', 'In Progress')
)
SELECT 
    ep.EmployeeID,
    ep.FirstName + ' ' + ep.LastName AS EmployeeName,
    d.DepartmentName,
    COUNT(DISTINCT ep.ProjectID) AS ProjectCount,
    STRING_AGG(ep.ProjectName, ', ') AS ProjectList,
    SUM(ep.HoursAllocated) AS TotalHoursAllocated
FROM EmployeeProjects ep
JOIN HR.Departments d ON ep.DepartmentID = d.DepartmentID
GROUP BY ep.EmployeeID, ep.FirstName, ep.LastName, d.DepartmentName
HAVING COUNT(DISTINCT ep.ProjectID) > 1
ORDER BY TotalHoursAllocated DESC;

-- =============================================
-- PART 3: MULTIPLE CTEs IN A SINGLE QUERY
-- =============================================

-- You can define multiple CTEs in a single query by separating them with commas

WITH 
-- CTE 1: Calculate department statistics
DepartmentStats AS (
    SELECT 
        DepartmentID,
        COUNT(*) AS EmployeeCount,
        AVG(Salary) AS AvgSalary,
        MIN(Salary) AS MinSalary,
        MAX(Salary) AS MaxSalary,
        SUM(Salary) AS TotalSalary
    FROM HR.Employees
    WHERE Status = 'Active'
    GROUP BY DepartmentID
),
-- CTE 2: Calculate company-wide statistics
CompanyStats AS (
    SELECT 
        COUNT(*) AS TotalEmployees,
        AVG(Salary) AS CompanyAvgSalary
    FROM HR.Employees
    WHERE Status = 'Active'
)
-- Main query using both CTEs
SELECT 
    d.DepartmentName,
    ds.EmployeeCount,
    FORMAT(ds.EmployeeCount * 100.0 / cs.TotalEmployees, 'N2') + '%' AS DeptEmployeePercentage,
    FORMAT(ds.AvgSalary, 'C') AS DeptAvgSalary,
    FORMAT(cs.CompanyAvgSalary, 'C') AS CompanyAvgSalary,
    FORMAT(ds.AvgSalary - cs.CompanyAvgSalary, 'C') AS SalaryDifference,
    FORMAT(ds.TotalSalary, 'C') AS DeptSalaryBudget
FROM DepartmentStats ds
JOIN HR.Departments d ON ds.DepartmentID = d.DepartmentID
CROSS JOIN CompanyStats cs
ORDER BY ds.EmployeeCount DESC;

-- =============================================
-- PART 4: RECURSIVE CTEs FOR HIERARCHICAL DATA
-- =============================================

-- Recursive CTEs are used to query hierarchical data like organizational charts,
-- bill of materials, or any parent-child relationship.

-- 1. Basic Recursive CTE Syntax:
-- WITH RecursiveCTE AS (
--     -- Anchor member (starting point)
--     SELECT columns FROM table WHERE condition
--     UNION ALL
--     -- Recursive member (references the CTE itself)
--     SELECT columns FROM table JOIN RecursiveCTE WHERE condition
-- )

-- 2. Employee Hierarchy Example
-- This recursive CTE builds an organizational chart showing the management hierarchy

WITH EmployeeHierarchy AS (
    -- Anchor member: Start with top-level managers (employees with no manager)
    SELECT 
        EmployeeID,
        FirstName,
        LastName,
        ManagerID,
        0 AS HierarchyLevel,
        CAST(FirstName + ' ' + LastName AS VARCHAR(500)) AS HierarchyPath
    FROM HR.Employees
    WHERE ManagerID IS NULL AND Status = 'Active'
    
    UNION ALL
    
    -- Recursive member: Join employees with their managers
    SELECT 
        e.EmployeeID,
        e.FirstName,
        e.LastName,
        e.ManagerID,
        eh.HierarchyLevel + 1,
        CAST(eh.HierarchyPath + ' > ' + e.FirstName + ' ' + e.LastName AS VARCHAR(500))
    FROM HR.Employees e
    INNER JOIN EmployeeHierarchy eh ON e.ManagerID = eh.EmployeeID
    WHERE e.Status = 'Active'
)
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    ManagerID,
    HierarchyLevel,
    REPLICATE('    ', HierarchyLevel) + FirstName + ' ' + LastName AS OrgChart,
    HierarchyPath
FROM EmployeeHierarchy
ORDER BY HierarchyPath;

-- 3. Department Budget Rollup Example
-- This recursive CTE calculates the total budget for each department including subdepartments

-- First, let's create a table to represent department hierarchy
IF OBJECT_ID('HR.DepartmentHierarchy', 'U') IS NOT NULL
    DROP TABLE HR.DepartmentHierarchy;

CREATE TABLE HR.DepartmentHierarchy (
    DepartmentID INT PRIMARY KEY,
    DepartmentName VARCHAR(100) NOT NULL,
    ParentDepartmentID INT NULL,
    DepartmentBudget DECIMAL(15,2) NOT NULL,
    CONSTRAINT FK_DepartmentHierarchy_Parent FOREIGN KEY (ParentDepartmentID) 
        REFERENCES HR.DepartmentHierarchy(DepartmentID)
);

-- Insert sample department hierarchy data
INSERT INTO HR.DepartmentHierarchy (DepartmentID, DepartmentName, ParentDepartmentID, DepartmentBudget)
VALUES
    (1, 'Executive Office', NULL, 500000.00),
    (2, 'Human Resources', 1, 350000.00),
    (3, 'Finance', 1, 400000.00),
    (4, 'Information Technology', 1, 750000.00),
    (5, 'Marketing', 1, 650000.00),
    (6, 'Recruitment', 2, 150000.00),
    (7, 'Training & Development', 2, 200000.00),
    (8, 'Accounting', 3, 250000.00),
    (9, 'Financial Planning', 3, 150000.00),
    (10, 'Infrastructure', 4, 350000.00),
    (11, 'Application Development', 4, 400000.00),
    (12, 'Digital Marketing', 5, 300000.00),
    (13, 'Brand Management', 5, 350000.00),
    (14, 'Technical Recruitment', 6, 75000.00),
    (15, 'Executive Recruitment', 6, 75000.00);

-- Recursive CTE to calculate total budget including subdepartments
WITH DepartmentBudgetRollup AS (
    -- Anchor member: Departments with no subdepartments (leaf nodes)
    SELECT 
        DepartmentID,
        DepartmentName,
        ParentDepartmentID,
        DepartmentBudget AS DirectBudget,
        DepartmentBudget AS TotalBudget,
        0 AS SubdepartmentCount,
        CAST(DepartmentName AS VARCHAR(500)) AS DepartmentPath
    FROM HR.DepartmentHierarchy
    WHERE DepartmentID NOT IN (SELECT DISTINCT ParentDepartmentID FROM HR.DepartmentHierarchy WHERE ParentDepartmentID IS NOT NULL)
    
    UNION ALL
    
    -- Recursive member: Roll up budgets from bottom to top
    SELECT 
        p.DepartmentID,
        p.DepartmentName,
        p.ParentDepartmentID,
        p.DepartmentBudget,
        p.DepartmentBudget + SUM(c.TotalBudget),
        COUNT(c.DepartmentID),
        CAST(p.DepartmentName AS VARCHAR(500))
    FROM HR.DepartmentHierarchy p
    JOIN DepartmentBudgetRollup c ON p.DepartmentID = c.ParentDepartmentID
    GROUP BY p.DepartmentID, p.DepartmentName, p.ParentDepartmentID, p.DepartmentBudget
)
SELECT 
    d.DepartmentID,
    d.DepartmentName,
    d.ParentDepartmentID,
    p.DepartmentName AS ParentDepartment,
    FORMAT(d.DirectBudget, 'C') AS DirectBudget,
    FORMAT(dbr.TotalBudget, 'C') AS TotalBudget,
    dbr.SubdepartmentCount,
    CASE 
        WHEN dbr.SubdepartmentCount > 0 THEN FORMAT((dbr.TotalBudget - d.DirectBudget) / dbr.TotalBudget * 100, 'N2') + '%'
        ELSE '0.00%'
    END AS SubdepartmentBudgetPercentage
FROM HR.DepartmentHierarchy d
LEFT JOIN HR.DepartmentHierarchy p ON d.ParentDepartmentID = p.DepartmentID
JOIN DepartmentBudgetRollup dbr ON d.DepartmentID = dbr.DepartmentID
ORDER BY 
    CASE WHEN d.ParentDepartmentID IS NULL THEN 0 ELSE 1 END,
    d.ParentDepartmentID,
    dbr.TotalBudget DESC;

-- 4. Project Task Dependencies Example
-- This recursive CTE identifies the critical path in a project schedule

-- First, let's create a table to represent project tasks and dependencies
IF OBJECT_ID('HR.ProjectTasks', 'U') IS NOT NULL
    DROP TABLE HR.ProjectTasks;

CREATE TABLE HR.ProjectTasks (
    TaskID INT PRIMARY KEY,
    ProjectID INT NOT NULL,
    TaskName VARCHAR(100) NOT NULL,
    DurationDays INT NOT NULL,
    PredecessorTaskID INT NULL,
    CONSTRAINT FK_ProjectTasks_Predecessor FOREIGN KEY (PredecessorTaskID) 
        REFERENCES HR.ProjectTasks(TaskID)
);

-- Insert sample project task data
INSERT INTO HR.ProjectTasks (TaskID, ProjectID, TaskName, DurationDays, PredecessorTaskID)
VALUES
    (1, 1, 'Project Initiation', 5, NULL),
    (2, 1, 'Requirements Gathering', 10, 1),
    (3, 1, 'System Design', 15, 2),
    (4, 1, 'Development - Core Modules', 20, 3),
    (5, 1, 'Development - Additional Features', 15, 3),
    (6, 1, 'Testing - Unit Tests', 10, 4),
    (7, 1, 'Testing - Integration Tests', 10, 5),
    (8, 1, 'User Acceptance Testing', 15, 6),
    (9, 1, 'Documentation', 10, 7),
    (10, 1, 'Deployment', 5, 8),
    (11, 1, 'Post-Implementation Review', 5, 10);

-- Recursive CTE to calculate earliest start and finish times for each task
WITH TaskSchedule AS (
    -- Anchor member: Tasks with no predecessors
    SELECT 
        TaskID,
        ProjectID,
        TaskName,
        DurationDays,
        PredecessorTaskID,
        0 AS EarliestStartDay,
        DurationDays AS EarliestFinishDay,
        CAST(TaskName AS VARCHAR(1000)) AS TaskPath
    FROM HR.ProjectTasks
    WHERE PredecessorTaskID IS NULL
    
    UNION ALL
    
    -- Recursive member: Calculate start and finish times based on predecessors
    SELECT 
        t.TaskID,
        t.ProjectID,
        t.TaskName,
        t.DurationDays,
        t.PredecessorTaskID,
        ts.EarliestFinishDay AS EarliestStartDay,
        ts.EarliestFinishDay + t.DurationDays AS EarliestFinishDay,
        CAST(ts.TaskPath + ' > ' + t.TaskName AS VARCHAR(1000))
    FROM HR.ProjectTasks t
    JOIN TaskSchedule ts ON t.PredecessorTaskID = ts.TaskID
)
SELECT 
    TaskID,
    TaskName,
    PredecessorTaskID,
    DurationDays,
    EarliestStartDay,
    EarliestFinishDay,
    TaskPath,
    CASE 
        WHEN TaskID IN (
            -- Find tasks on the critical path (those with the latest finish time)
            SELECT TaskID FROM TaskSchedule 
            WHERE EarliestFinishDay = (SELECT MAX(EarliestFinishDay) FROM TaskSchedule)
            UNION ALL
            -- Include all predecessors of critical path tasks
            SELECT t.TaskID
            FROM HR.ProjectTasks t
            JOIN TaskSchedule ts ON t.TaskID = ts.PredecessorTaskID
            WHERE ts.TaskID IN (
                SELECT TaskID FROM TaskSchedule 
                WHERE EarliestFinishDay = (SELECT MAX(EarliestFinishDay) FROM TaskSchedule)
            )
        ) THEN 'Yes' 
        ELSE 'No' 
    END AS OnCriticalPath
FROM TaskSchedule
ORDER BY EarliestStartDay, EarliestFinishDay;

-- =============================================
-- PART 5: USING CTEs IN DML OPERATIONS
-- =============================================

-- CTEs can be used not only for SELECT statements but also for INSERT, UPDATE, DELETE, and MERGE

-- 1. Using CTE with INSERT
-- This example inserts new department budget records based on a CTE calculation

IF OBJECT_ID('HR.DepartmentBudgetPlan', 'U') IS NOT NULL
    DROP TABLE HR.DepartmentBudgetPlan;

CREATE TABLE HR.DepartmentBudgetPlan (
    PlanID INT IDENTITY(1,1) PRIMARY KEY,
    DepartmentID INT NOT NULL,
    FiscalYear INT NOT NULL,
    PlannedBudget DECIMAL(15,2) NOT NULL,
    CreatedDate DATETIME DEFAULT GETDATE(),
    CONSTRAINT UQ_DeptBudgetPlan UNIQUE (DepartmentID, FiscalYear)
);

-- Insert budget plan for next year with 5% increase using a CTE
WITH NextYearBudget AS (
    SELECT 
        DepartmentID,
        DepartmentName,
        DepartmentBudget,
        DepartmentBudget * 1.05 AS NextYearBudget
    FROM HR.DepartmentHierarchy
)
INSERT INTO HR.DepartmentBudgetPlan (DepartmentID, FiscalYear, PlannedBudget)
SELECT 
    DepartmentID,
    YEAR(GETDATE()) + 1,
    NextYearBudget
FROM NextYearBudget;

-- 2. Using CTE with UPDATE
-- This example updates employee salaries based on a CTE calculation

-- First, let's create a table for salary adjustments
IF OBJECT_ID('HR.SalaryAdjustments', 'U') IS NOT NULL
    DROP TABLE HR.SalaryAdjustments;

CREATE TABLE HR.SalaryAdjustments (
    AdjustmentID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    OldSalary DECIMAL(12,2) NOT NULL,
    NewSalary DECIMAL(12,2) NOT NULL,
    AdjustmentDate DATETIME DEFAULT GETDATE(),
    AdjustmentReason VARCHAR(200) NOT NULL
);

-- Update salaries for employees below department average using a CTE
WITH SalaryAdjustmentCTE AS (
    SELECT 
        e.EmployeeID,
        e.FirstName,
        e.LastName,
        e.DepartmentID,
        e.Salary AS OldSalary,
        d.DepartmentName,
        AVG(e2.Salary) OVER (PARTITION BY e.DepartmentID) AS DeptAvgSalary,
        CASE
            WHEN e.Salary < AVG(e2.Salary) OVER (PARTITION BY e.DepartmentID) * 0.9
            THEN e.Salary * 1.1 -- 10% increase for those significantly below average
            WHEN e.Salary < AVG(e2.Salary) OVER (PARTITION BY e.DepartmentID)
            THEN e.Salary * 1.05 -- 5% increase for those below average
            ELSE e.Salary -- No change for others
        END AS NewSalary
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    JOIN HR.Employees e2 ON e.DepartmentID = e2.DepartmentID
    WHERE e.Status = 'Active' AND e2.Status = 'Active'
)
UPDATE SalaryAdjustmentCTE
SET OldSalary = NewSalary
OUTPUT 
    deleted.EmployeeID,
    deleted.OldSalary,
    inserted.OldSalary,
    GETDATE(),
    'Annual salary adjustment to align with department average'
INTO HR.SalaryAdjustments;

-- 3. Using CTE with DELETE
-- This example deletes completed project tasks using a CTE

-- First, let's create a table for completed tasks
IF OBJECT_ID('HR.CompletedTasks', 'U') IS NOT NULL
    DROP TABLE HR.CompletedTasks;

CREATE TABLE HR.CompletedTasks (
    TaskID INT PRIMARY KEY,
    ProjectID INT NOT NULL,
    TaskName VARCHAR(100) NOT NULL,
    CompletionDate DATETIME DEFAULT GETDATE(),
    CompletedBy INT -- Employee ID
);

-- Insert some completed tasks
INSERT INTO HR.CompletedTasks (TaskID, ProjectID, TaskName, CompletedBy)
VALUES
    (1, 1, 'Project Initiation', 101),
    (2, 1, 'Requirements Gathering', 102),
    (3, 1, 'System Design', 103);

-- Delete completed tasks from the active tasks table using a CTE
WITH CompletedTasksCTE AS (
    SELECT pt.TaskID
    FROM HR.ProjectTasks pt
    JOIN HR.CompletedTasks ct ON pt.TaskID = ct.TaskID
)
DELETE FROM CompletedTasksCTE;

-- 4. Using CTE with MERGE
-- This example synchronizes employee project assignments using a CTE

-- First, let's create a table for new project assignments
IF OBJECT_ID('HR.NewProjectAssignments', 'U') IS NOT NULL
    DROP TABLE HR.NewProjectAssignments;

CREATE TABLE HR.NewProjectAssignments (
    EmployeeID INT NOT NULL,
    ProjectID INT NOT NULL,
    RoleOnProject VARCHAR(50),
    HoursAllocated DECIMAL(6,2),
    PRIMARY KEY (EmployeeID, ProjectID)
);

-- Insert some new assignments
INSERT INTO HR.NewProjectAssignments (EmployeeID, ProjectID, RoleOnProject, HoursAllocated)
VALUES
    (101, 1, 'Project Manager', 40.0),
    (102, 1, 'Business Analyst', 30.0),
    (103, 1, 'Developer', 40.0),
    (104, 1, 'Tester', 20.0);

-- Synchronize project assignments using a CTE and MERGE
WITH ProjectAssignmentsCTE AS (
    SELECT 
        npa.EmployeeID,
        npa.ProjectID,
        npa.RoleOnProject,
        npa.HoursAllocated
    FROM HR.NewProjectAssignments npa
)
MERGE ProjectAssignments AS target
USING ProjectAssignmentsCTE AS source
ON (target.EmployeeID = source.EmployeeID AND target.ProjectID = source.ProjectID)
WHEN MATCHED THEN
    UPDATE SET 
        target.RoleOnProject = source.RoleOnProject,
        target.HoursAllocated = source.HoursAllocated
WHEN NOT MATCHED BY TARGET THEN
    INSERT (EmployeeID, ProjectID, RoleOnProject, HoursAllocated)
    VALUES (source.EmployeeID, source.ProjectID, source.RoleOnProject, source.HoursAllocated)
WHEN NOT MATCHED BY SOURCE AND target.ProjectID = 1 THEN
    DELETE;

-- =============================================
-- PART 6: CTEs vs SUBQUERIES vs TEMPORARY TABLES
-- =============================================

-- 1. CTE vs Subquery
-- CTEs are often more readable than subqueries, especially for complex queries

-- Example using a subquery
SELECT 
    d.DepartmentName,
    (SELECT COUNT(*) FROM HR.Employees e WHERE e.DepartmentID = d.DepartmentID AND e.Status = 'Active') AS EmployeeCount,
    (SELECT AVG(Salary) FROM HR.Employees e WHERE e.DepartmentID = d.DepartmentID AND e.Status = 'Active') AS AvgSalary
FROM HR.Departments d
WHERE (SELECT COUNT(*) FROM HR.Employees e WHERE e.DepartmentID = d.DepartmentID AND e.Status = 'Active') > 0
ORDER BY EmployeeCount DESC;

-- Same example using a CTE
WITH DepartmentStats AS (
    SELECT 
        DepartmentID,
        COUNT(*) AS EmployeeCount,
        AVG(Salary) AS AvgSalary
    FROM HR.Employees
    WHERE Status = 'Active'
    GROUP BY DepartmentID
)
SELECT 
    d.DepartmentName,
    ds.EmployeeCount,
    ds.AvgSalary
FROM HR.Departments d
JOIN DepartmentStats ds ON d.DepartmentID = ds.DepartmentID
ORDER BY ds.EmployeeCount DESC;

-- 2. CTE vs Temporary Table
-- Temporary tables persist for the session and can be indexed, while CTEs exist only for the duration of the query

-- Example using a temporary table
CREATE TABLE #DepartmentStats (
    DepartmentID INT PRIMARY KEY,
    EmployeeCount INT,
    AvgSalary DECIMAL(12,2)
);

INSERT INTO #DepartmentStats (DepartmentID, EmployeeCount, AvgSalary)
SELECT 
    DepartmentID,
    COUNT(*),
    AVG(Salary)
FROM HR.Employees
WHERE Status = 'Active'
GROUP BY DepartmentID;

SELECT 
    d.DepartmentName,
    ds.EmployeeCount,
    ds.AvgSalary
FROM HR.Departments d
JOIN #DepartmentStats ds ON d.DepartmentID = ds.DepartmentID
ORDER BY ds.EmployeeCount DESC;

DROP TABLE #DepartmentStats;

-- =============================================
-- PART 7: CTE PERFORMANCE CONSIDERATIONS
-- =============================================

-- 1. CTEs are not materialized
-- Unlike temporary tables, CTEs are not stored separately and are expanded inline

-- 2. Recursive CTEs can have performance implications
-- Use OPTION (MAXRECURSION n) to control recursion depth (default is 100)

WITH EmployeeHierarchy AS (
    SELECT 
        EmployeeID,
        FirstName,
        LastName,
        ManagerID,
        0 AS HierarchyLevel
    FROM HR.Employees
    WHERE ManagerID IS NULL AND Status = 'Active'
    
    UNION ALL
    
    SELECT 
        e.EmployeeID,
        e.FirstName,
        e.LastName,
        e.ManagerID,
        eh.HierarchyLevel + 1
    FROM HR.Employees e
    INNER JOIN EmployeeHierarchy eh ON e.ManagerID = eh.EmployeeID
    WHERE e.Status = 'Active'
)
SELECT * FROM EmployeeHierarchy
OPTION (MAXRECURSION 500);

-- 3. Indexing considerations
-- CTEs benefit from proper indexing on the underlying tables
-- Ensure indexes exist on frequently used join and filter columns

-- 4. Avoid unnecessary complexity
-- Break down complex CTEs into smaller, more manageable ones
-- Use meaningful names that describe the CTE's purpose

-- =============================================
-- PART 8: CTE BEST PRACTICES
-- =============================================

-- 1. Naming Conventions
-- Use clear, descriptive names that indicate the CTE's purpose
-- Example: EmployeeSalaryAnalysis, DepartmentHierarchy, ProjectTimeline

-- 2. Readability
-- Format CTEs with proper indentation
-- Add comments to explain complex logic
-- Break down complex CTEs into multiple simpler ones

-- 3. Maintainability
-- Keep CTEs focused on a single logical task
-- Document dependencies between multiple CTEs
-- Consider creating views for frequently used CTEs

-- 4. Performance
-- Avoid unnecessary joins and calculations
-- Use appropriate indexes on underlying tables
-- Monitor and tune recursive CTEs
-- Consider using temporary tables for complex operations that are reused

-- 5. Error Handling
-- Include appropriate error checking in recursive CTEs
-- Handle edge cases and potential NULL values
-- Use MAXRECURSION option when necessary

-- 6. Testing
-- Test CTEs with various data scenarios
-- Verify recursive CTEs terminate properly
-- Validate results against expected outcomes

-- =============================================
-- PART 9: REAL-WORLD HR SCENARIOS
-- =============================================

-- 1. Employee Performance Review Cycles
WITH PerformanceReviewCycles AS (
    SELECT 
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        pr.ReviewDate,
        pr.Rating,
        pr.ReviewerID,
        ROW_NUMBER() OVER (PARTITION BY e.EmployeeID ORDER BY pr.ReviewDate DESC) AS ReviewCycle
    FROM HR.Employees e
    JOIN HR.PerformanceReviews pr ON e.EmployeeID = pr.EmployeeID
    WHERE e.Status = 'Active'
)
SELECT 
    prc1.EmployeeID,
    prc1.EmployeeName,
    prc1.Rating AS CurrentRating,
    prc2.Rating AS PreviousRating,
    prc1.ReviewDate AS CurrentReviewDate,
    prc2.ReviewDate AS PreviousReviewDate,
    CASE 
        WHEN prc1.Rating > prc2.Rating THEN 'Improved'
        WHEN prc1.Rating < prc2.Rating THEN 'Declined'
        ELSE 'Maintained'
    END AS PerformanceTrend
FROM PerformanceReviewCycles prc1
LEFT JOIN PerformanceReviewCycles prc2 
    ON prc1.EmployeeID = prc2.EmployeeID 
    AND prc1.ReviewCycle = 1 
    AND prc2.ReviewCycle = 2
WHERE prc1.ReviewCycle = 1
ORDER BY 
    CASE 
        WHEN prc1.Rating > prc2.Rating THEN 1
        WHEN prc1.Rating < prc2.Rating THEN 3
        ELSE 2
    END,
    prc1.EmployeeName;

-- 2. Training and Certification Tracking
WITH EmployeeTraining AS (
    SELECT 
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        d.DepartmentName,
        tc.CertificationName,
        tc.CompletionDate,
        tc.ExpiryDate,
        ROW_NUMBER() OVER (PARTITION BY e.EmployeeID, tc.CertificationName 
                          ORDER BY tc.CompletionDate DESC) AS CertificationInstance
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    JOIN HR.TrainingCertifications tc ON e.EmployeeID = tc.EmployeeID
    WHERE e.Status = 'Active'
)
SELECT 
    et.EmployeeID,
    et.EmployeeName,
    et.DepartmentName,
    et.CertificationName,
    et.CompletionDate,
    et.ExpiryDate,
    CASE 
        WHEN et.ExpiryDate IS NULL THEN 'Never Expires'
        WHEN et.ExpiryDate <= DATEADD(MONTH, 3, GETDATE()) THEN 'Expiring Soon'
        WHEN et.ExpiryDate <= GETDATE() THEN 'Expired'
        ELSE 'Valid'
    END AS CertificationStatus
FROM EmployeeTraining et
WHERE et.CertificationInstance = 1
ORDER BY 
    CASE 
        WHEN et.ExpiryDate <= GETDATE() THEN 1
        WHEN et.ExpiryDate <= DATEADD(MONTH, 3, GETDATE()) THEN 2
        ELSE 3
    END,
    et.DepartmentName,
    et.EmployeeName;

-- 3. Succession Planning Analysis
WITH SuccessionCandidates AS (
    SELECT 
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        e.DepartmentID,
        d.DepartmentName,
        e.Position,
        e.YearsOfExperience,
        pr.AverageRating,
        tc.CertificationCount,
        DENSE_RANK() OVER (PARTITION BY e.DepartmentID, e.Position 
                          ORDER BY pr.AverageRating DESC, 
                                   e.YearsOfExperience DESC, 
                                   tc.CertificationCount DESC) AS SuccessionRank
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    JOIN (
        SELECT 
            EmployeeID,
            AVG(CAST(Rating AS FLOAT)) AS AverageRating
        FROM HR.PerformanceReviews
        WHERE ReviewDate >= DATEADD(YEAR, -2, GETDATE())
        GROUP BY EmployeeID
    ) pr ON e.EmployeeID = pr.EmployeeID
    JOIN (
        SELECT 
            EmployeeID,
            COUNT(DISTINCT CertificationName) AS CertificationCount
        FROM HR.TrainingCertifications
        WHERE ExpiryDate > GETDATE() OR ExpiryDate IS NULL
        GROUP BY EmployeeID
    ) tc ON e.EmployeeID = tc.EmployeeID
    WHERE e.Status = 'Active'
)
SELECT 
    sc.DepartmentName,
    sc.Position,
    sc.EmployeeName,
    sc.YearsOfExperience,
    FORMAT(sc.AverageRating, 'N2') AS AveragePerformanceRating,
    sc.CertificationCount,
    sc.SuccessionRank,
    CASE 
        WHEN sc.SuccessionRank = 1 THEN 'Primary'
        WHEN sc.SuccessionRank = 2 THEN 'Secondary'
        WHEN sc.SuccessionRank = 3 THEN 'Tertiary'
        ELSE 'Development Required'
    END AS SuccessionReadiness
FROM SuccessionCandidates sc
WHERE sc.SuccessionRank <= 3
ORDER BY 
    sc.DepartmentName,
    sc.Position,
    sc.SuccessionRank;