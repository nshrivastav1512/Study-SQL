/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\125_TRIGGER_FUNCTIONS.sql
    
    This script demonstrates SQL Server Trigger Functions using the HRSystem database.
    These functions are specifically designed for use within triggers to handle data
    modifications and manage trigger execution flow.

    Trigger Functions covered:
    1. COLUMNS_UPDATED() - Identifies modified columns
    2. EVENTDATA() - Gets XML event information
    3. TRIGGER_NESTLEVEL() - Checks trigger nesting depth
    4. UPDATE() - Tests if a column was updated
    5. INSERTED/DELETED - Special tables for tracking changes
*/

USE HRSystem;
GO

-- Create a table for employee audit logging
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[EmployeeAudit]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.EmployeeAudit (
        AuditID INT PRIMARY KEY IDENTITY(1,1),
        EmployeeID INT,
        ColumnModified NVARCHAR(128),
        OldValue NVARCHAR(MAX),
        NewValue NVARCHAR(MAX),
        ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
        ModifiedBy NVARCHAR(128) DEFAULT SYSTEM_USER,
        TriggerLevel INT,
        EventData XML
    );
END

-- Create or alter the trigger to demonstrate trigger functions
CREATE OR ALTER TRIGGER HR.trg_Employee_Update
ON HR.Employees
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. COLUMNS_UPDATED()
    -- Get bitmap of updated columns
    DECLARE @UpdatedColumns BINARY(128) = COLUMNS_UPDATED();

    -- 2. TRIGGER_NESTLEVEL()
    -- Check current trigger nesting level
    DECLARE @TriggerLevel INT = TRIGGER_NESTLEVEL();

    -- 3. EVENTDATA()
    -- Get XML information about the triggering event
    DECLARE @EventInfo XML = EVENTDATA();

    -- Process each modified column
    IF UPDATE(Salary) -- 4. UPDATE() function
    BEGIN
        INSERT INTO HR.EmployeeAudit (
            EmployeeID,
            ColumnModified,
            OldValue,
            NewValue,
            TriggerLevel,
            EventData
        )
        SELECT 
            i.EmployeeID,
            'Salary',
            CAST(d.Salary AS NVARCHAR(50)), -- From DELETED table
            CAST(i.Salary AS NVARCHAR(50)), -- From INSERTED table
            @TriggerLevel,
            @EventInfo
        FROM INSERTED i
        JOIN DELETED d ON i.EmployeeID = d.EmployeeID
        WHERE i.Salary <> d.Salary;
    END

    IF UPDATE(Department)
    BEGIN
        INSERT INTO HR.EmployeeAudit (
            EmployeeID,
            ColumnModified,
            OldValue,
            NewValue,
            TriggerLevel,
            EventData
        )
        SELECT 
            i.EmployeeID,
            'Department',
            d.Department,
            i.Department,
            @TriggerLevel,
            @EventInfo
        FROM INSERTED i
        JOIN DELETED d ON i.EmployeeID = d.EmployeeID
        WHERE i.Department <> d.Department;
    END
END;

-- Create a nested trigger example
CREATE OR ALTER TRIGGER HR.trg_EmployeeAudit_Insert
ON HR.EmployeeAudit
AFTER INSERT
AS
BEGIN
    -- Demonstrate nested trigger level
    DECLARE @CurrentLevel INT = TRIGGER_NESTLEVEL();
    
    -- Prevent infinite recursion
    IF @CurrentLevel > 2
    BEGIN
        RAISERROR ('Maximum trigger nesting level exceeded', 16, 1);
        RETURN;
    END

    -- Log trigger execution
    PRINT 'Audit trigger executed at nesting level: ' + CAST(@CurrentLevel AS VARCHAR(10));
END;

-- Example usage and demonstration
BEGIN TRANSACTION;

TRY
    -- Update employee information to trigger the audit
    UPDATE HR.Employees
    SET 
        Salary = Salary * 1.1,
        Department = 'IT'
    WHERE EmployeeID = 1;

    -- View the audit results
    SELECT 
        AuditID,
        EmployeeID,
        ColumnModified,
        OldValue,
        NewValue,
        ModifiedDate,
        ModifiedBy,
        TriggerLevel,
        EventData.value('(/EVENT_INSTANCE/EventType)[1]', 'nvarchar(100)') AS EventType,
        EventData.value('(/EVENT_INSTANCE/PostTime)[1]', 'datetime') AS EventTime
    FROM HR.EmployeeAudit
    ORDER BY AuditID DESC;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;

-- Cleanup (commented out for safety)
/*
DROP TRIGGER IF EXISTS HR.trg_Employee_Update;
DROP TRIGGER IF EXISTS HR.trg_EmployeeAudit_Insert;
DROP TABLE IF EXISTS HR.EmployeeAudit;
*/