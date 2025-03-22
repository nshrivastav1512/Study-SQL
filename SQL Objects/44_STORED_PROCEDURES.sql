-- =============================================
-- SQL Server STORED PROCEDURES Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating a Basic Stored Procedure
CREATE PROCEDURE sp_GetAllProjects
AS
BEGIN
    SELECT ProjectID, ProjectName, StartDate, EndDate, Budget, Status
    FROM Projects
    ORDER BY StartDate DESC;
END;
GO

-- 2. Creating a Stored Procedure with Parameters
CREATE PROCEDURE sp_GetProjectsByStatus
    @Status VARCHAR(20)
AS
BEGIN
    SELECT ProjectID, ProjectName, StartDate, EndDate, Budget, Status
    FROM Projects
    WHERE Status = @Status
    ORDER BY StartDate DESC;
END;
GO

-- 3. Creating a Stored Procedure with Optional Parameters
CREATE PROCEDURE sp_SearchProjects
    @ProjectName VARCHAR(100) = NULL,
    @Status VARCHAR(20) = NULL,
    @MinBudget DECIMAL(15,2) = NULL,
    @MaxBudget DECIMAL(15,2) = NULL
AS
BEGIN
    SELECT ProjectID, ProjectName, StartDate, EndDate, Budget, Status
    FROM Projects
    WHERE 
        (@ProjectName IS NULL OR ProjectName LIKE '%' + @ProjectName + '%')
        AND (@Status IS NULL OR Status = @Status)
        AND (@MinBudget IS NULL OR Budget >= @MinBudget)
        AND (@MaxBudget IS NULL OR Budget <= @MaxBudget)
    ORDER BY ProjectName;
END;
GO

-- 4. Creating a Stored Procedure with Output Parameters
CREATE PROCEDURE sp_GetProjectStats
    @Status VARCHAR(20),
    @ProjectCount INT OUTPUT,
    @TotalBudget DECIMAL(18,2) OUTPUT,
    @AvgBudget DECIMAL(18,2) OUTPUT
AS
BEGIN
    SELECT 
        @ProjectCount = COUNT(*),
        @TotalBudget = SUM(Budget),
        @AvgBudget = AVG(Budget)
    FROM Projects
    WHERE Status = @Status;
END;
GO

-- 5. Creating a Stored Procedure with Return Value
CREATE PROCEDURE sp_AddProject
    @ProjectName VARCHAR(100),
    @StartDate DATE,
    @EndDate DATE,
    @Budget DECIMAL(15,2),
    @Status VARCHAR(20),
    @Description VARCHAR(500) = NULL
AS
BEGIN
    -- Check if project name already exists
    IF EXISTS (SELECT 1 FROM Projects WHERE ProjectName = @ProjectName)
    BEGIN
        RETURN -1; -- Return error code
    END
    
    -- Insert the new project
    INSERT INTO Projects (ProjectName, StartDate, EndDate, Budget, Status, Description)
    VALUES (@ProjectName, @StartDate, @EndDate, @Budget, @Status, @Description);
    
    RETURN SCOPE_IDENTITY(); -- Return the new ProjectID
END;
GO

-- 6. Creating a Stored Procedure with Error Handling
CREATE PROCEDURE sp_AssignEmployeeToProject
    @ProjectID INT,
    @EmployeeID INT,
    @RoleOnProject VARCHAR(50),
    @HoursAllocated DECIMAL(6,2)
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Check if project exists
        IF NOT EXISTS (SELECT 1 FROM Projects WHERE ProjectID = @ProjectID)
        BEGIN
            THROW 50001, 'Project does not exist.', 1;
        END
        
        -- Check if employee exists
        IF NOT EXISTS (SELECT 1 FROM HR.Employees WHERE EmployeeID = @EmployeeID)
        BEGIN
            THROW 50002, 'Employee does not exist.', 1;
        END
        
        -- Check if assignment already exists
        IF EXISTS (SELECT 1 FROM ProjectAssignments 
                  WHERE ProjectID = @ProjectID AND EmployeeID = @EmployeeID)
        BEGIN
            THROW 50003, 'Employee is already assigned to this project.', 1;
        END
        
        -- Insert the assignment
        INSERT INTO ProjectAssignments (ProjectID, EmployeeID, RoleOnProject, HoursAllocated)
        VALUES (@ProjectID, @EmployeeID, @RoleOnProject, @HoursAllocated);
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO

-- 7. Creating a Stored Procedure with Dynamic SQL
CREATE PROCEDURE sp_DynamicProjectQuery
    @SortColumn VARCHAR(50) = 'ProjectName',
    @SortDirection VARCHAR(4) = 'ASC',
    @WhereClause NVARCHAR(500) = NULL
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    
    -- Validate sort column to prevent SQL injection
    IF @SortColumn NOT IN ('ProjectID', 'ProjectName', 'StartDate', 'EndDate', 'Budget', 'Status')
    BEGIN
        SET @SortColumn = 'ProjectName';
    END
    
    -- Validate sort direction
    IF @SortDirection NOT IN ('ASC', 'DESC')
    BEGIN
        SET @SortDirection = 'ASC';
    END
    
    -- Build the SQL statement
    SET @SQL = 'SELECT ProjectID, ProjectName, StartDate, EndDate, Budget, Status FROM Projects';
    
    -- Add WHERE clause if provided
    IF @WhereClause IS NOT NULL
    BEGIN
        SET @SQL = @SQL + ' WHERE ' + @WhereClause;
    END
    
    -- Add ORDER BY clause
    SET @SQL = @SQL + ' ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection;
    
    -- Execute the dynamic SQL
    EXEC sp_executesql @SQL;
END;
GO

-- 8. Creating a Stored Procedure with Table-Valued Parameter
-- First create a user-defined table type
CREATE TYPE ProjectMilestoneTableType AS TABLE
(
    MilestoneName VARCHAR(100),
    TargetDate DATE,
    CompletionPercentage DECIMAL(5,2)
);
GO

CREATE PROCEDURE sp_AddProjectWithMilestones
    @ProjectName VARCHAR(100),
    @StartDate DATE,
    @EndDate DATE,
    @Budget DECIMAL(15,2),
    @Status VARCHAR(20),
    @Description VARCHAR(500) = NULL,
    @Milestones ProjectMilestoneTableType READONLY
AS
BEGIN
    DECLARE @ProjectID INT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Insert the project
        INSERT INTO Projects (ProjectName, StartDate, EndDate, Budget, Status, Description)
        VALUES (@ProjectName, @StartDate, @EndDate, @Budget, @Status, @Description);
        
        SET @ProjectID = SCOPE_IDENTITY();
        
        -- Insert the milestones
        INSERT INTO ProjectMilestones (ProjectID, MilestoneName, TargetDate, CompletionPercentage)
        SELECT @ProjectID, MilestoneName, TargetDate, CompletionPercentage
        FROM @Milestones;
        
        COMMIT TRANSACTION;
        
        -- Return the new project ID
        SELECT @ProjectID AS NewProjectID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        THROW;
    END CATCH;
END;
GO

-- 9. Creating a Stored Procedure with Temporary Tables
CREATE PROCEDURE sp_AnalyzeProjectPerformance
AS
BEGIN
    -- Create a temporary table to hold project performance data
    CREATE TABLE #ProjectPerformance
    (
        ProjectID INT,
        ProjectName VARCHAR(100),
        PlannedDuration INT,
        ActualDuration INT,
        DurationVariance INT,
        BudgetVariance DECIMAL(15,2),
        MilestoneCompletion DECIMAL(5,2),
        PerformanceScore DECIMAL(5,2)
    );
    
    -- Populate the temporary table
    INSERT INTO #ProjectPerformance (ProjectID, ProjectName, PlannedDuration, ActualDuration, BudgetVariance, MilestoneCompletion)
    SELECT 
        p.ProjectID,
        p.ProjectName,
        DATEDIFF(DAY, p.StartDate, p.EndDate) AS PlannedDuration,
        CASE 
            WHEN p.Status = 'Completed' THEN DATEDIFF(DAY, p.StartDate, GETDATE())
            ELSE NULL
        END AS ActualDuration,
        ISNULL(SUM(pbi.ActualCost), 0) - p.Budget AS BudgetVariance,
        AVG(pm.CompletionPercentage) AS MilestoneCompletion
    FROM Projects p
    LEFT JOIN ProjectBudgetItems pbi ON p.ProjectID = pbi.ProjectID
    LEFT JOIN ProjectMilestones pm ON p.ProjectID = pm.ProjectID
    GROUP BY p.ProjectID, p.ProjectName, p.StartDate, p.EndDate, p.Status, p.Budget;
    
    -- Calculate duration variance
    UPDATE #ProjectPerformance
    SET DurationVariance = ActualDuration - PlannedDuration
    WHERE ActualDuration IS NOT NULL;
    
    -- Calculate performance score (lower is better)
    UPDATE #ProjectPerformance
    SET PerformanceScore = 
        (CASE WHEN DurationVariance > 0 THEN DurationVariance / CAST(PlannedDuration AS DECIMAL(10,2)) ELSE 0 END) * 50 +
        (CASE WHEN BudgetVariance > 0 THEN BudgetVariance / CAST(ABS(BudgetVariance) + 1 AS DECIMAL(15,2)) ELSE 0 END) * 30 +
        (100 - MilestoneCompletion) * 0.2;
    
    -- Return the results
    SELECT * FROM #ProjectPerformance ORDER BY PerformanceScore;
    
    -- Clean up
    DROP TABLE #ProjectPerformance;
END;
GO

-- 10. Creating a Stored Procedure with Cursor
CREATE PROCEDURE sp_UpdateProjectStatus
AS
BEGIN
    DECLARE @ProjectID INT;
    DECLARE @ProjectName VARCHAR(100);
    DECLARE @EndDate DATE;
    DECLARE @MilestoneCompletion DECIMAL(5,2);
    DECLARE @NewStatus VARCHAR(20);
    
    -- Cursor to iterate through all active projects
    DECLARE ProjectCursor CURSOR FOR
    SELECT 
        p.ProjectID, 
        p.ProjectName, 
        p.EndDate,
        AVG(ISNULL(pm.CompletionPercentage, 0)) AS MilestoneCompletion
    FROM Projects p
    LEFT JOIN ProjectMilestones pm ON p.ProjectID = pm.ProjectID
    WHERE p.Status IN ('Not Started', 'Planning', 'In Progress')
    GROUP BY p.ProjectID, p.ProjectName, p.EndDate;
    
    OPEN ProjectCursor;
    
    FETCH NEXT FROM ProjectCursor INTO @ProjectID, @ProjectName, @EndDate, @MilestoneCompletion;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Determine new status based on milestone completion and end date
        IF @MilestoneCompletion = 100
        BEGIN
            SET @NewStatus = 'Completed';
        END
        ELSE IF @EndDate < GETDATE() AND @MilestoneCompletion < 100
        BEGIN
            SET @NewStatus = 'Delayed';
        END
        ELSE IF @MilestoneCompletion = 0
        BEGIN
            SET @NewStatus = 'Not Started';
        END
        ELSE IF @MilestoneCompletion < 25
        BEGIN
            SET @NewStatus = 'Planning';
        END
        ELSE
        BEGIN
            SET @NewStatus = 'In Progress';
        END
        
        -- Update the project status if it's different
        UPDATE Projects
        SET Status = @NewStatus
        WHERE ProjectID = @ProjectID AND Status <> @NewStatus;
        
        -- Insert a status update record
        IF @@ROWCOUNT > 0
        BEGIN
            INSERT INTO ProjectStatus (ProjectID, StatusDate, StatusUpdate, UpdatedBy)
            VALUES (@ProjectID, GETDATE(), 'Status automatically updated to ' + @NewStatus, 'System');
        END
        
        FETCH NEXT FROM ProjectCursor INTO @ProjectID, @ProjectName, @EndDate, @MilestoneCompletion;
    END
    
    CLOSE ProjectCursor;
    DEALLOCATE ProjectCursor;
END;
GO

-- 11. Altering a Stored Procedure
ALTER PROCEDURE sp_GetAllProjects
AS
BEGIN
    SELECT 
        ProjectID, 
        ProjectName, 
        StartDate, 
        EndDate, 
        Budget, 
        Status,
        ProjectManager,  -- Added column
        Description      -- Added column
    FROM Projects
    ORDER BY StartDate DESC;
END;
GO

-- 12. Dropping a Stored Procedure
DROP PROCEDURE sp_GetProjectsByStatus;
GO

-- 13. Executing Stored Procedures
-- Basic execution
EXEC sp_GetAllProjects;
GO

-- Execution with parameters
EXEC sp_SearchProjects 
    @ProjectName = 'Website', 
    @MinBudget = 50000;
GO

-- Execution with output parameters
DECLARE @Count INT, @Total DECIMAL(18,2), @Avg DECIMAL(18,2);

EXEC sp_GetProjectStats 
    @Status = 'In Progress',
    @ProjectCount = @Count OUTPUT,
    @TotalBudget = @Total OUTPUT,
    @AvgBudget = @Avg OUTPUT;

SELECT 
    @Count AS 'Number of Projects',
    @Total AS 'Total Budget',
    @Avg AS 'Average Budget';
GO

-- Execution with return value
DECLARE @ReturnValue INT;