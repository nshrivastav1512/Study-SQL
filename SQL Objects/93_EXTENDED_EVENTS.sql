-- =============================================
-- SQL Server Extended Events Implementation
-- =============================================

/*
This script demonstrates Extended Events setup for HR system monitoring:
- Session configuration for performance tracking
- Query execution monitoring
- Deadlock detection
- Resource utilization tracking
*/

USE master;
GO

-- =============================================
-- PART 1: BASIC EXTENDED EVENTS SESSION
-- =============================================

-- Create Basic Performance Monitoring Session
IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'HR_Performance_Monitoring')
    DROP EVENT SESSION HR_Performance_Monitoring ON SERVER;
GO

CREATE EVENT SESSION HR_Performance_Monitoring
ON SERVER
ADD EVENT sqlserver.sql_statement_completed
(
    ACTION
    (
        sqlserver.database_name,
        sqlserver.sql_text,
        sqlserver.plan_handle,
        sqlserver.session_id
    )
    WHERE database_name = N'HRSystem'
),
ADD EVENT sqlserver.sql_batch_completed
(
    ACTION
    (
        sqlserver.database_name,
        sqlserver.sql_text
    )
    WHERE database_name = N'HRSystem'
)
ADD TARGET package0.event_file
(
    SET filename = 'C:\SQLEvents\HR_Performance.xel',
        max_file_size = 100,
        max_rollover_files = 5
);
GO

-- Start the Session
ALTER EVENT SESSION HR_Performance_Monitoring
ON SERVER STATE = START;
GO

-- =============================================
-- PART 2: DEADLOCK MONITORING
-- =============================================

-- Create Deadlock Tracking Session
IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'HR_Deadlock_Tracking')
    DROP EVENT SESSION HR_Deadlock_Tracking ON SERVER;
GO

CREATE EVENT SESSION HR_Deadlock_Tracking
ON SERVER
ADD EVENT sqlserver.xml_deadlock_report
(
    ACTION
    (
        sqlserver.database_name,
        sqlserver.session_id,
        sqlserver.sql_text
    )
    WHERE database_name = N'HRSystem'
)
ADD TARGET package0.event_file
(
    SET filename = 'C:\SQLEvents\HR_Deadlocks.xel',
        max_file_size = 50,
        max_rollover_files = 5
);
GO

-- Start the Session
ALTER EVENT SESSION HR_Deadlock_Tracking
ON SERVER STATE = START;
GO

-- =============================================
-- PART 3: QUERY ANALYSIS
-- =============================================

-- Create Query Performance Analysis Session
IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'HR_Query_Analysis')
    DROP EVENT SESSION HR_Query_Analysis ON SERVER;
GO

CREATE EVENT SESSION HR_Query_Analysis
ON SERVER
ADD EVENT sqlserver.sp_statement_completed,
ADD EVENT sqlserver.sql_statement_completed,
ADD EVENT sqlserver.rpc_completed
(
    ACTION
    (
        sqlserver.database_name,
        sqlserver.sql_text,
        sqlserver.plan_handle,
        sqlserver.session_id,
        sqlserver.username,
        sqlserver.client_hostname
    )
    WHERE database_name = N'HRSystem'
    AND duration > 1000000 -- 1 second in microseconds
)
ADD TARGET package0.event_file
(
    SET filename = 'C:\SQLEvents\HR_Query_Analysis.xel',
        max_file_size = 200,
        max_rollover_files = 5
);
GO

-- Start the Session
ALTER EVENT SESSION HR_Query_Analysis
ON SERVER STATE = START;
GO

-- =============================================
-- PART 4: EVENT DATA ANALYSIS
-- =============================================

-- Create Helper Function for Reading XEL Files
CREATE FUNCTION dbo.fn_ReadExtendedEventFile
(
    @file_path NVARCHAR(260)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        CAST(event_data AS XML) AS event_data_XML,
        file_name,
        file_offset
    FROM sys.fn_xe_file_target_read_file
    (@file_path, NULL, NULL, NULL)
);
GO

-- Create Analysis Procedures
CREATE PROCEDURE dbo.Analyze_HR_Performance
AS
BEGIN
    SET NOCOUNT ON;

    -- Analyze slow queries
    SELECT
        event_data_XML.value('(event/@timestamp)[1]', 'datetime2') AS event_time,
        event_data_XML.value('(event/action[@name="database_name"]/value)[1]', 'nvarchar(128)') AS database_name,
        event_data_XML.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS sql_text,
        event_data_XML.value('(event/data[@name="duration"]/value)[1]', 'bigint') / 1000000.0 AS duration_seconds
    FROM dbo.fn_ReadExtendedEventFile('C:\SQLEvents\HR_Performance*.xel')
    WHERE event_data_XML.value('(event/@name)[1]', 'nvarchar(128)') = 'sql_statement_completed'
    ORDER BY duration_seconds DESC;

    -- Analyze query patterns
    SELECT
        event_data_XML.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS sql_pattern,
        COUNT(*) as execution_count,
        AVG(CAST(event_data_XML.value('(event/data[@name="duration"]/value)[1]', 'bigint') AS FLOAT) / 1000000.0) AS avg_duration_seconds
    FROM dbo.fn_ReadExtendedEventFile('C:\SQLEvents\HR_Performance*.xel')
    WHERE event_data_XML.value('(event/@name)[1]', 'nvarchar(128)') = 'sql_statement_completed'
    GROUP BY event_data_XML.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)')
    ORDER BY execution_count DESC;
END;
GO

CREATE PROCEDURE dbo.Analyze_HR_Deadlocks
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        event_data_XML.value('(event/@timestamp)[1]', 'datetime2') AS deadlock_time,
        event_data_XML.value('(event/data[@name="xml_report"]/value)[1]', 'xml') AS deadlock_graph,
        event_data_XML.value('(event/action[@name="database_name"]/value)[1]', 'nvarchar(128)') AS database_name
    FROM dbo.fn_ReadExtendedEventFile('C:\SQLEvents\HR_Deadlocks*.xel')
    WHERE event_data_XML.value('(event/@name)[1]', 'nvarchar(128)') = 'xml_deadlock_report'
    ORDER BY deadlock_time DESC;
END;
GO

-- =============================================
-- PART 5: MAINTENANCE AND CLEANUP
-- =============================================

CREATE PROCEDURE dbo.Maintain_Extended_Events
AS
BEGIN
    SET NOCOUNT ON;

    -- Archive old XEL files
    DECLARE @archive_path NVARCHAR(260) = 'C:\SQLEvents\Archive\' + 
        CONVERT(NVARCHAR(8), GETDATE(), 112);
    DECLARE @cmd NVARCHAR(1000);

    -- Create archive directory
    SET @cmd = 'mkdir "' + @archive_path + '"';
    EXEC master.dbo.xp_cmdshell @cmd;

    -- Move files to archive
    SET @cmd = 'move "C:\SQLEvents\*.xel" "' + @archive_path + '"';
    EXEC master.dbo.xp_cmdshell @cmd;

    -- Clean up old archives (keep last 30 days)
    SET @cmd = 'forfiles /p "C:\SQLEvents\Archive" /d -30 /c "cmd /c rd /s /q @path"';
    EXEC master.dbo.xp_cmdshell @cmd;

    -- Restart sessions to create new files
    ALTER EVENT SESSION HR_Performance_Monitoring ON SERVER STATE = STOP;
    ALTER EVENT SESSION HR_Deadlock_Tracking ON SERVER STATE = STOP;
    ALTER EVENT SESSION HR_Query_Analysis ON SERVER STATE = STOP;

    ALTER EVENT SESSION HR_Performance_Monitoring ON SERVER STATE = START;
    ALTER EVENT SESSION HR_Deadlock_Tracking ON SERVER STATE = START;
    ALTER EVENT SESSION HR_Query_Analysis ON SERVER STATE = START;
END;
GO