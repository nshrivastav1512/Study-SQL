-- =============================================
-- SQL Server Database Audit Implementation
-- =============================================

/*
This script demonstrates SQL Server Audit implementation for HR data:
- Server and database audit setup
- Tracking data access and modifications
- Audit log analysis
- Security compliance monitoring
*/

USE master;
GO

-- =============================================
-- PART 1: SERVER AUDIT SETUP
-- =============================================

-- Create Server Audit
CREATE SERVER AUDIT HR_System_Audit
TO FILE 
(
    FILEPATH = 'C:\SQLAudit\',
    MAXSIZE = 100MB,
    MAX_ROLLOVER_FILES = 5
)
WITH
(
    QUEUE_DELAY = 1000,
    ON_FAILURE = CONTINUE
);
GO

-- Enable the Server Audit
ALTER SERVER AUDIT HR_System_Audit
WITH (STATE = ON);
GO

USE HRSystem;
GO

-- =============================================
-- PART 2: DATABASE AUDIT SPECIFICATION
-- =============================================

-- Create Database Audit Specification
CREATE DATABASE AUDIT SPECIFICATION HR_Data_Access_Audit
FOR SERVER AUDIT HR_System_Audit
ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Employees BY public),
ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Salaries BY public),
ADD (SCHEMA_OBJECT_ACCESS_GROUP),
ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP)
WITH (STATE = ON);
GO

-- =============================================
-- PART 3: AUDIT LOG ANALYSIS
-- =============================================

-- Query Audit Logs
SELECT 
    event_time,
    action_id,
    server_principal_name,
    database_principal_name,
    object_name,
    statement
FROM sys.fn_get_audit_file
('C:\SQLAudit\*',DEFAULT,DEFAULT);

-- Filter Specific Actions
SELECT 
    event_time,
    server_principal_name,
    database_name,
    object_name,
    statement
FROM sys.fn_get_audit_file
('C:\SQLAudit\*',DEFAULT,DEFAULT)
WHERE action_id IN ('INS', 'UPD', 'DEL')
AND object_name LIKE '%Employees%';

-- =============================================
-- PART 4: AUDIT MAINTENANCE
-- =============================================

-- Create Audit Maintenance Procedure
CREATE PROCEDURE dbo.Maintain_HR_Audit
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @audit_file_path NVARCHAR(260);
    DECLARE @archive_path NVARCHAR(260);
    DECLARE @current_date NVARCHAR(8);

    SET @current_date = CONVERT(NVARCHAR(8), GETDATE(), 112);
    SET @audit_file_path = 'C:\SQLAudit\';
    SET @archive_path = 'C:\SQLAudit\Archive\' + @current_date + '\';

    -- Archive old audit files
    DECLARE @cmd NVARCHAR(1000);
    SET @cmd = 'MOVE ' + @audit_file_path + '*.sqlaudit '
             + @archive_path;

    -- Execute archive command
    EXEC master.dbo.xp_cmdshell @cmd;

    -- Clean up old archives (keep last 30 days)
    DECLARE @cleanup_date DATETIME = DATEADD(DAY, -30, GETDATE());
    SET @cmd = 'FORFILES /P "C:\SQLAudit\Archive" /D -30 /C "CMD /C RD /S /Q @PATH"';
    EXEC master.dbo.xp_cmdshell @cmd;
END;
GO

-- Schedule Audit Maintenance (Example)
/*
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = 'HR_Audit_Maintenance',
    @enabled = 1;

EXEC dbo.sp_add_jobstep
    @job_name = 'HR_Audit_Maintenance',
    @step_name = 'Execute Maintenance',
    @subsystem = 'TSQL',
    @command = 'EXEC HRSystem.dbo.Maintain_HR_Audit;';

EXEC dbo.sp_add_schedule
    @job_name = 'HR_Audit_Maintenance',
    @name = 'Daily_Midnight',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 000000;
*/

-- =============================================
-- PART 5: AUDIT REPORTING
-- =============================================

-- Create Audit Summary View
CREATE VIEW dbo.HR_Audit_Summary
AS
SELECT 
    CONVERT(DATE, event_time) AS audit_date,
    database_principal_name,
    action_id,
    object_name,
    COUNT(*) as action_count
FROM sys.fn_get_audit_file
('C:\SQLAudit\*',DEFAULT,DEFAULT)
GROUP BY 
    CONVERT(DATE, event_time),
    database_principal_name,
    action_id,
    object_name;
GO

-- Create Suspicious Activity Report
CREATE PROCEDURE dbo.Report_Suspicious_Activity
    @start_date DATE,
    @end_date DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Detect multiple failed access attempts
    SELECT 
        event_time,
        server_principal_name,
        database_principal_name,
        object_name,
        statement
    FROM sys.fn_get_audit_file
    ('C:\SQLAudit\*',DEFAULT,DEFAULT)
    WHERE 
        succeeded = 0
        AND event_time BETWEEN @start_date AND @end_date
    ORDER BY event_time DESC;

    -- Detect after-hours access
    SELECT 
        event_time,
        server_principal_name,
        database_principal_name,
        object_name,
        statement
    FROM sys.fn_get_audit_file
    ('C:\SQLAudit\*',DEFAULT,DEFAULT)
    WHERE 
        DATEPART(HOUR, event_time) NOT BETWEEN 9 AND 17
        AND event_time BETWEEN @start_date AND @end_date
    ORDER BY event_time DESC;

    -- Detect mass data modifications
    SELECT 
        event_time,
        server_principal_name,
        database_principal_name,
        object_name,
        statement
    FROM sys.fn_get_audit_file
    ('C:\SQLAudit\*',DEFAULT,DEFAULT)
    WHERE 
        action_id IN ('INS', 'UPD', 'DEL')
        AND event_time BETWEEN @start_date AND @end_date
    GROUP BY 
        event_time,
        server_principal_name,
        database_principal_name,
        object_name,
        statement
    HAVING COUNT(*) > 1000;
END;
GO