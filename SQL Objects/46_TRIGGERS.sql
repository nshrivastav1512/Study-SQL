-- =============================================
-- SQL Server TRIGGERS Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating a Basic DML Trigger (AFTER INSERT)
CREATE TRIGGER trg_ProjectInsert
ON Projects
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Log the project creation
    INSERT INTO ProjectStatus (ProjectID, StatusDate, StatusUpdate, UpdatedBy)
    SELECT 
        i.ProjectID, 
        GETDATE(), 
        'Project created with status: ' + i.Status,
        SYSTEM_USER
    FROM inserted i;
    
    -- Create default milestone
    INSERT INTO ProjectMilestones (ProjectID, MilestoneName, TargetDate, CompletionPercentage)
    SELECT 
        i.ProjectID, 
        'Project Kickoff', 
        DATEADD(DAY, 7, i.StartDate),
        0
    FROM inserted i;
END;
GO

-- 2. Creating an AFTER UPDATE Trigger
CREATE TRIGGER trg_ProjectUpdate
ON Projects
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Only log when status changes
    IF UPDATE(Status)
    BEGIN
        INSERT INTO ProjectStatus (ProjectID, StatusDate, StatusUpdate, UpdatedBy)
        SELECT 
            i.ProjectID, 
            GETDATE(), 
            'Status changed from "' + d.Status + '" to "' + i.Status + '"',
            SYSTEM_USER
        FROM inserted i
        JOIN deleted d ON i.ProjectID = d.ProjectID
        WHERE i.Status <> d.Status;
    END;
    
    -- Update project end date if budget changes significantly
    IF UPDATE(Budget)
    BEGIN
        UPDATE Projects
        SET EndDate = DATEADD(MONTH, 1, p.EndDate)
        FROM Projects p
        JOIN inserted i ON p.ProjectID = i.ProjectID
        JOIN deleted d ON i.ProjectID = d.ProjectID
        WHERE i.Budget > d.Budget * 1.25; -- 25% increase
    END;
END;
GO

-- 3. Creating an AFTER DELETE Trigger
CREATE TRIGGER trg_ProjectDelete
ON Projects
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Archive deleted projects
    INSERT INTO ProjectArchive (ProjectID, ProjectName, StartDate, EndDate, Budget, Status, DeletedDate, DeletedBy)
    SELECT 
        d.ProjectID, 
        d.ProjectName, 
        d.StartDate, 
        d.EndDate, 
        d.Budget, 
        d.Status,
        GETDATE(),
        SYSTEM_USER
    FROM deleted d;
END;
GO

-- 4. Creating an INSTEAD OF Trigger
CREATE TRIGGER trg_PreventProjectDeletion
ON Projects
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CanDelete BIT = 1;
    
    -- Check if any project being deleted has active assignments
    IF EXISTS (
        SELECT 1 
        FROM deleted d
        JOIN ProjectAssignments pa ON d.ProjectID = pa.ProjectID
    )
    BEGIN
        SET @CanDelete = 0;
        RAISERROR('Cannot delete projects with active assignments. Remove assignments first.', 16, 1);
        RETURN;
    END;
    
    -- Check if any project being deleted has budget items
    IF EXISTS (
        SELECT 1 
        FROM deleted d
        JOIN ProjectBudgetItems pbi ON d.ProjectID = pbi.ProjectID
    )
    BEGIN
        SET @CanDelete = 0;
        RAISERROR('Cannot delete projects with budget items. Remove budget items first.', 16, 1);
        RETURN;
    END;
    
    -- If all checks pass, perform the deletion
    IF @CanDelete = 1
    BEGIN
        -- Delete related milestones
        DELETE FROM ProjectMilestones
        WHERE ProjectID IN (SELECT ProjectID FROM deleted);
        
        -- Delete related status records
        DELETE FROM ProjectStatus
        WHERE ProjectID IN (SELECT ProjectID FROM deleted);
        
        -- Delete the project
        DELETE FROM Projects
        WHERE ProjectID IN (SELECT ProjectID FROM deleted);
    END;
END;
GO

-- 5. Creating a Trigger on Multiple Actions
CREATE TRIGGER trg_ProjectAudit
ON Projects
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Action CHAR(1);
    
    -- Determine the action (I=Insert, U=Update, D=Delete)
    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
        SET @Action = 'U';
    ELSE IF EXISTS(SELECT * FROM inserted)
        SET @Action = 'I';
    ELSE IF EXISTS(SELECT * FROM deleted)
        SET @Action = 'D';
    
    -- Insert audit record
    INSERT INTO AuditLog (TableName, PrimaryKeyValue, Action, ActionDate, UserName)
    SELECT 
        'Projects',
        CASE 
            WHEN @Action IN ('U', 'D') THEN d.ProjectID
            ELSE i.ProjectID
        END,
        @Action,
        GETDATE(),
        SYSTEM_USER
    FROM 
        deleted d
        FULL OUTER JOIN inserted i ON d.ProjectID = i.ProjectID;
END;
GO

-- 6. Creating a DDL Trigger (Database Level)
CREATE TRIGGER trg_PreventTableDrop
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @EventData XML = EVENTDATA();
    DECLARE @ObjectName NVARCHAR(255);
    
    -- Get the name of the table being dropped
    SET @ObjectName = @EventData.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(255)');
    
    -- Prevent dropping of core project tables
    IF @ObjectName IN ('Projects', 'ProjectAssignments', 'ProjectMilestones', 'ProjectStatus')
    BEGIN
        PRINT 'You cannot drop core project tables. Operation cancelled.';
        ROLLBACK;
    END;
END;
GO

-- 7. Creating a Server-Level Trigger
CREATE TRIGGER trg_ServerAudit
ON ALL SERVER
FOR CREATE_LOGIN, ALTER_LOGIN, DROP_LOGIN
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @EventData XML = EVENTDATA();
    
    -- Log login changes to a server audit table
    INSERT INTO master.dbo.ServerAuditLog
    (
        EventType,
        LoginName,
        EventDate,
        SQLCommand,
        UserName
    )
    VALUES
    (
        @EventData.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)'),
        @EventData.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(255)'),
        GETDATE(),
        @EventData.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)'),
        @EventData.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(255)')
    );
END;
GO

-- 8. Creating a Trigger with COLUMNS_UPDATED Function
CREATE TRIGGER trg_TrackProjectChanges
ON Projects
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @UpdatedColumns VARCHAR(1000) = '';
    
    -- Check which columns were updated
    IF UPDATE(ProjectName)
        SET @UpdatedColumns = @UpdatedColumns + 'ProjectName, ';
    
    IF UPDATE(StartDate)
        SET @UpdatedColumns = @UpdatedColumns + 'StartDate, ';
    
    IF UPDATE(EndDate)
        SET @UpdatedColumns = @UpdatedColumns + 'EndDate, ';
    
    IF UPDATE(Budget)
        SET @UpdatedColumns = @UpdatedColumns + 'Budget, ';
    
    IF UPDATE(Status)
        SET @UpdatedColumns = @UpdatedColumns + 'Status, ';
    
    IF UPDATE(Description)
        SET @UpdatedColumns = @UpdatedColumns + 'Description, ';
    
    IF UPDATE(ProjectManager)
        SET @UpdatedColumns = @UpdatedColumns + 'ProjectManager, ';
    
    -- Remove trailing comma and space
    IF LEN(@UpdatedColumns) > 0
        SET @UpdatedColumns = LEFT(@UpdatedColumns, LEN(@UpdatedColumns) - 2);
    
    -- Log the changes
    INSERT INTO ProjectChangeLog (ProjectID, ChangedColumns, ChangeDate, ChangedBy)
    SELECT 
        i.ProjectID,
        @UpdatedColumns,
        GETDATE(),
        SYSTEM_USER
    FROM inserted i;
END;
GO

-- 9. Creating a Trigger with Error Handling
CREATE TRIGGER trg_ValidateProjectDates
ON Projects
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Check if end date is before start date
        IF EXISTS (
            SELECT 1 FROM inserted 
            WHERE EndDate < StartDate AND EndDate IS NOT NULL
        )
        BEGIN
            THROW 50001, 'Project end date cannot be earlier than start date.', 1;
        END;
        
        -- Check if start date is in the past (more than 30 days)
        IF EXISTS (
            SELECT 1 FROM inserted 
            WHERE StartDate < DATEADD(DAY, -30, GETDATE())
        )
        BEGIN
            THROW 50002, 'Project start date cannot be more than 30 days in the past.', 1;
        END;
    END TRY
    BEGIN CATCH
        -- Roll back the transaction
        IF @@TRANCOUNT > 0
            ROLLBACK;
            
        -- Re-throw the error
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO

-- 10. Creating a Trigger with Nested Triggers
-- Enable nested triggers if not already enabled
SP_CONFIGURE 'nested triggers', 1;
RECONFIGURE;
GO

-- First-level trigger
CREATE TRIGGER trg_ProjectMilestoneInsert
ON ProjectMilestones
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Update project status based on milestone creation
    UPDATE Projects
    SET Status = 
        CASE 
            WHEN Status = 'Not Started' THEN 'Planning'
            ELSE Status
        END
    FROM Projects p
    JOIN inserted i ON p.ProjectID = i.ProjectID
    WHERE p.Status = 'Not Started';
    
    -- Log milestone creation
    INSERT INTO ProjectStatus (ProjectID, StatusDate, StatusUpdate, UpdatedBy)
    SELECT 
        i.ProjectID,
        GETDATE(),
        'Milestone added: ' + i.MilestoneName,
        SYSTEM_USER
    FROM inserted i;
END;
GO

-- Second-level trigger (will be triggered by the first one)
CREATE TRIGGER trg_ProjectStatusInsert
ON ProjectStatus
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Notify project manager about status update
    INSERT INTO Notifications (UserID, NotificationType, NotificationText, CreatedDate, IsRead)
    SELECT 
        (SELECT ManagerID FROM HR.Departments d 
         JOIN Projects p ON d.DepartmentID = p.DepartmentID
         WHERE p.ProjectID = i.ProjectID),
        'Status Update',
        'Project ' + p.ProjectName + ' has a new status update: ' + i.StatusUpdate,
        GETDATE(),
        0
    FROM inserted i
    JOIN Projects p ON i.ProjectID = p.ProjectID;
END;
GO

-- 11. Disabling a Trigger
DISABLE TRIGGER trg_ProjectInsert ON Projects;
GO

-- 12. Enabling a Trigger
ENABLE TRIGGER trg_ProjectInsert ON Projects;
GO

-- 13. Dropping a Trigger
DROP TRIGGER trg_ProjectDelete;
GO

-- 14. Creating a Trigger with CONTEXT_INFO
-- This allows passing additional information to triggers
CREATE TRIGGER trg_ProjectUpdateWithContext
ON Projects
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ContextInfo VARBINARY(128);
    DECLARE @Reason NVARCHAR(100);
    
    -- Get the context info (set by the application before the update)
    SET @ContextInfo = CONTEXT_INFO();
    
    -- Extract reason from context info if available
    IF @ContextInfo IS NOT NULL
        SET @Reason = CAST(@ContextInfo AS NVARCHAR(100));
    ELSE
        SET @Reason = 'No reason provided';
    
    -- Log the update with the reason
    INSERT INTO ProjectChangeLog (ProjectID, ChangedColumns, ChangeDate, ChangedBy, ChangeReason)
    SELECT 
        i.ProjectID,
        'Multiple columns',
        GETDATE(),
        SYSTEM_USER,
        @Reason
    FROM inserted i;
END;
GO

-- 15. Creating a Trigger with MERGE Statement
CREATE TRIGGER trg_SyncProjectBudget
ON ProjectBudgetItems
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Update the project's budget based on budget items
    WITH ProjectTotals AS (
        SELECT 
            ProjectID,
            SUM(EstimatedCost) AS TotalEstimatedCost
        FROM ProjectBudgetItems
        GROUP BY ProjectID
    )
    MERGE INTO Projects AS target
    USING ProjectTotals AS source
    ON target.ProjectID = source.ProjectID
    WHEN MATCHED THEN
        UPDATE SET 
            Budget = source.TotalEstimatedCost,
            ModifiedDate = GETDATE();
END;
G