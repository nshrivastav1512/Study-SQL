-- =============================================
-- SQL Server VIEWS Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating a Basic View
CREATE VIEW vw_ProjectSummary AS
SELECT 
    ProjectID,
    ProjectName,
    StartDate,
    EndDate,
    Budget,
    Status
FROM Projects;
GO

-- 2. Creating a View with Joins
CREATE VIEW vw_ProjectAssignmentDetails AS
SELECT 
    p.ProjectID,
    p.ProjectName,
    p.Status AS ProjectStatus,
    pa.AssignmentID,
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS EmployeeName,
    pa.RoleOnProject,
    pa.AssignmentDate,
    pa.HoursAllocated
FROM Projects p
JOIN ProjectAssignments pa ON p.ProjectID = pa.ProjectID
JOIN HR.Employees e ON pa.EmployeeID = e.EmployeeID;
GO

-- 3. Creating a View with Aggregation
CREATE VIEW vw_ProjectBudgetSummary AS
SELECT 
    p.ProjectID,
    p.ProjectName,
    p.Budget AS TotalBudget,
    SUM(ISNULL(pbi.EstimatedCost, 0)) AS TotalEstimatedCost,
    SUM(ISNULL(pbi.ActualCost, 0)) AS TotalActualCost,
    p.Budget - SUM(ISNULL(pbi.ActualCost, 0)) AS RemainingBudget
FROM Projects p
LEFT JOIN ProjectBudgetItems pbi ON p.ProjectID = pbi.ProjectID
GROUP BY p.ProjectID, p.ProjectName, p.Budget;
GO

-- 4. Creating a View with Filtering
CREATE VIEW vw_ActiveProjects AS
SELECT 
    ProjectID,
    ProjectName,
    StartDate,
    EndDate,
    Budget,
    Status,
    Description
FROM Projects
WHERE Status IN ('Planning', 'In Progress') AND EndDate > GETDATE();
GO

-- 5. Creating a View with Computed Columns
CREATE VIEW vw_ProjectDuration AS
SELECT 
    ProjectID,
    ProjectName,
    StartDate,
    EndDate,
    DATEDIFF(DAY, StartDate, EndDate) AS DurationDays,
    DATEDIFF(MONTH, StartDate, EndDate) AS DurationMonths,
    Budget,
    Status
FROM Projects;
GO

-- 6. Creating an Indexed View (Materialized View)
-- Note: Requires schema binding and certain SET options
SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;
SET ARITHABORT ON;
GO

CREATE VIEW vw_ProjectMilestoneStats WITH SCHEMABINDING AS
SELECT 
    p.ProjectID,
    p.ProjectName,
    COUNT_BIG(*) AS TotalMilestones,
    SUM(CASE WHEN pm.CompletionDate IS NOT NULL THEN 1 ELSE 0 END) AS CompletedMilestones,
    AVG(pm.CompletionPercentage) AS AvgCompletionPercentage
FROM dbo.Projects p
JOIN dbo.ProjectMilestones pm ON p.ProjectID = pm.ProjectID
GROUP BY p.ProjectID, p.ProjectName;
GO

-- Create a unique clustered index on the view
CREATE UNIQUE CLUSTERED INDEX IX_vw_ProjectMilestoneStats 
ON vw_ProjectMilestoneStats (ProjectID);
GO

-- 7. Creating a View with UNION
CREATE VIEW vw_AllProjectItems AS
SELECT 
    'Milestone' AS ItemType,
    ProjectID,
    CAST(MilestoneID AS VARCHAR(10)) AS ItemID,
    MilestoneName AS ItemName,
    TargetDate AS ItemDate,
    CAST(CompletionPercentage AS VARCHAR(10)) + '%' AS ItemStatus
FROM ProjectMilestones
UNION ALL
SELECT 
    'Document' AS ItemType,
    ProjectID,
    CAST(DocumentID AS VARCHAR(10)) AS ItemID,
    DocumentName AS ItemName,
    UploadDate AS ItemDate,
    FileType AS ItemStatus
FROM ProjectDocuments
UNION ALL
SELECT 
    'Risk' AS ItemType,
    ProjectID,
    CAST(RiskID AS VARCHAR(10)) AS ItemID,
    RiskDescription AS ItemName,
    IdentifiedDate AS ItemDate,
    Status AS ItemStatus
FROM ProjectRisks;
GO

-- 8. Creating a View with TOP
CREATE VIEW vw_Top5ExpensiveProjects AS
SELECT TOP 5
    ProjectID,
    ProjectName,
    Budget,
    StartDate,
    EndDate,
    Status
FROM Projects
ORDER BY Budget DESC;
GO

-- 9. Creating a View with CASE Statements
CREATE VIEW vw_ProjectStatusCategory AS
SELECT 
    ProjectID,
    ProjectName,
    Status,
    CASE 
        WHEN Status = 'Not Started' THEN 'Future'
        WHEN Status = 'Planning' THEN 'Preparation'
        WHEN Status = 'In Progress' THEN 'Active'
        WHEN Status IN ('Completed', 'Cancelled') THEN 'Finished'
        ELSE 'Unknown'
    END AS StatusCategory,
    Budget,
    StartDate,
    EndDate
FROM Projects;
GO

-- 10. Altering a View
ALTER VIEW vw_ProjectSummary AS
SELECT 
    ProjectID,
    ProjectName,
    StartDate,
    EndDate,
    Budget,
    Status,
    ProjectManager,  -- Added column
    Description      -- Added column
FROM Projects;
GO

-- 11. Dropping a View
DROP VIEW vw_Top5ExpensiveProjects;
GO

-- 12. Creating a View with Encryption (to hide the definition)
CREATE VIEW vw_ConfidentialProjects
WITH ENCRYPTION
AS
SELECT 
    ProjectID,
    ProjectName,
    Budget,
    Status,
    Description
FROM Projects
WHERE Budget > 100000;
GO

-- 13. Creating a View with CHECK OPTION (prevents updates that violate the view's WHERE clause)
CREATE VIEW vw_HighBudgetProjects
AS
SELECT 
    ProjectID,
    ProjectName,
    Budget,
    Status,
    StartDate,
    EndDate
FROM Projects
WHERE Budget > 50000
WITH CHECK OPTION;
GO

-- 14. Querying Views
SELECT * FROM vw_ProjectSummary;
GO

SELECT * FROM vw_ProjectAssignmentDetails
WHERE ProjectStatus = 'In Progress';
GO

-- 15. Updating Data Through a View
UPDATE vw_ProjectSummary
SET Status = 'Completed'
WHERE ProjectID = 1;
GO

-- 16. Inserting Data Through a View
-- Note: Only works for simple views that reference a single table
INSERT INTO vw_ActiveProjects (ProjectName, StartDate, EndDate, Budget, Status, Description)
VALUES ('New Marketing Campaign', '2023-05-01', '2023-12-31', 85000.00, 'Planning', 'Q3-Q4 Marketing Initiative');
GO

-- 17. Deleting Data Through a View
DELETE FROM vw_ActiveProjects
WHERE ProjectName = 'New Marketing Campaign';
GO

-- 18. Creating a View with APPLY Operator
CREATE VIEW vw_ProjectWithLatestMilestone AS
SELECT 
    p.ProjectID,
    p.ProjectName,
    p.Status,
    lm.MilestoneID,
    lm.MilestoneName,
    lm.TargetDate,
    lm.CompletionDate,
    lm.CompletionPercentage
FROM Projects p
OUTER APPLY (
    SELECT TOP 1 *
    FROM ProjectMilestones pm
    WHERE pm.ProjectID = p.ProjectID
    ORDER BY pm.TargetDate DESC
) AS lm;
GO

-- 19. Creating a View with Dynamic Pivot
-- This example creates a view that shows project budget items by category
CREATE VIEW vw_ProjectBudgetByCategory AS
SELECT *
FROM (
    SELECT 
        p.ProjectName,
        pbi.ItemCategory,
        pbi.EstimatedCost
    FROM Projects p
    JOIN ProjectBudgetItems pbi ON p.ProjectID = pbi.ProjectID
) AS SourceTable
PIVOT (
    SUM(EstimatedCost)
    FOR ItemCategory IN ([Hardware], [Software], [Services], [Personnel], [Facilities], [Other])
) AS PivotTable;
GO

-- 20. Creating a View with Common Table Expression (CTE)
CREATE VIEW vw_ProjectHierarchy AS
WITH ProjectCTE AS (
    SELECT 
        p.ProjectID,
        p.ProjectName,
        NULL AS ParentProjectID,
        0 AS Level,
        CAST(p.ProjectName AS VARCHAR(500)) AS ProjectPath
    FROM Projects p
    WHERE p.ProjectID NOT IN (SELECT DISTINCT pm.ProjectID FROM ProjectMilestones pm)
    
    UNION ALL
    
    SELECT 
        pm.MilestoneID + 10000 AS ProjectID,  -- Adding offset to avoid ID conflicts
        pm.MilestoneName AS ProjectName,
        pm.ProjectID AS ParentProjectID,
        pcte.Level + 1 AS Level,
        CAST(pcte.ProjectPath + ' > ' + pm.MilestoneName AS VARCHAR(500)) AS ProjectPath
    FROM ProjectMilestones pm
    JOIN ProjectCTE pcte ON pm.ProjectID = pcte.ProjectID
)
SELECT 
    ProjectID,
    ProjectName,
    ParentProjectID,
    Level,
    ProjectPath
FROM ProjectCTE;
GO