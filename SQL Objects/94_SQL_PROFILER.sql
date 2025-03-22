-- =============================================
-- SQL Server Profiler Implementation
-- =============================================

/*
This script demonstrates SQL Server Profiler setup for HR system:
- Custom trace templates
- Performance monitoring
- Query analysis
- Resource usage tracking
*/

USE master;
GO

-- =============================================
-- PART 1: TRACE TEMPLATE CREATION
-- =============================================

-- Create Custom HR Trace Template
DECLARE @TraceID INT;
DECLARE @MaxFileSize BIGINT = 5;

-- Create the trace
EXEC sp_trace_create 
    @TraceID OUTPUT,
    0,
    N'C:\SQLTraces\HR_System_Trace',
    @MaxFileSize,
    NULL;

-- Set the events
DECLARE @on BIT = 1;
DECLARE @RC INT;

-- Add events for query execution
EXEC sp_trace_setevent @TraceID, 10, 1, @on;  -- RPC:Completed
EXEC sp_trace_setevent @TraceID, 10, 6, @on;  -- NTUserName
EXEC sp_trace_setevent @TraceID, 10, 8, @on;  -- HostName
EXEC sp_trace_setevent @TraceID, 10, 10, @on; -- ApplicationName
EXEC sp_trace_setevent @TraceID, 10, 12, @on; -- SPID
EXEC sp_trace_setevent @TraceID, 10, 14, @on; -- StartTime
EXEC sp_trace_setevent @TraceID, 10, 15, @on; -- EndTime
EXEC sp_trace_setevent @TraceID, 10, 16, @on; -- Reads
EXEC sp_trace_setevent @TraceID, 10, 17, @on; -- Writes
EXEC sp_trace_setevent @TraceID, 10, 18, @on; -- CPU
EXEC sp_trace_setevent @TraceID, 10, 26, @on; -- ServerName
EXEC sp_trace_setevent @TraceID, 10, 35, @on; -- DatabaseName

-- Add SQL:BatchCompleted events
EXEC sp_trace_setevent @TraceID, 12, 1, @on;
EXEC sp_trace_setevent @TraceID, 12, 6, @on;
EXEC sp_trace_setevent @TraceID, 12, 8, @on;
EXEC sp_trace_setevent @TraceID, 12, 10, @on;
EXEC sp_trace_setevent @TraceID, 12, 12, @on;
EXEC sp_trace_setevent @TraceID, 12, 14, @on;
EXEC sp_trace_setevent @TraceID, 12, 15, @on;
EXEC sp_trace_setevent @TraceID, 12, 16, @on;
EXEC sp_trace_setevent @TraceID, 12, 17, @on;
EXEC sp_trace_setevent @TraceID, 12, 18, @on;

-- Set the filters
EXEC sp_trace_setfilter @TraceID, 35, 0, 6, N'HRSystem'; -- DatabaseName
EXEC sp_trace_setfilter @TraceID, 16, 0, 4, 1000;        -- Minimum Reads
EXEC sp_trace_setfilter @TraceID, 18, 0, 4, 1000;        -- Minimum CPU

-- Start the trace
EXEC sp_trace_setstatus @TraceID, 1;

-- =============================================
-- PART 2: TRACE ANALYSIS
-- =============================================

-- Create Trace Analysis Tables
USE HRSystem;
GO

CREATE TABLE dbo.TraceAnalysis
(
    AnalysisID INT IDENTITY(1,1) PRIMARY KEY,
    TraceTime DATETIME,
    EventClass INT,
    ApplicationName NVARCHAR(128),
    DatabaseName NVARCHAR(128),
    HostName NVARCHAR(128),
    LoginName NVARCHAR(128),
    CPU INT,
    Reads BIGINT,
    Writes BIGINT,
    Duration BIGINT,
    TextData NVARCHAR(MAX)
);
GO

-- Create Analysis Procedure
CREATE PROCEDURE dbo.Analyze_Trace_Data
    @TraceFile NVARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;

    -- Load trace data
    INSERT INTO dbo.TraceAnalysis
    SELECT 
        StartTime,
        EventClass,
        ApplicationName,
        DatabaseName,
        HostName,
        LoginName,
        CPU,
        Reads,
        Writes,
        Duration,
        TextData
    FROM fn_trace_gettable(@TraceFile, DEFAULT);

    -- Analyze expensive queries
    SELECT TOP 10
        ApplicationName,
        HostName,
        LoginName,
        AVG(CPU) as AvgCPU,
        AVG(Reads) as AvgReads,
        AVG(Writes) as AvgWrites,
        COUNT(*) as ExecutionCount,
        TextData
    FROM dbo.TraceAnalysis
    GROUP BY 
        ApplicationName,
        HostName,
        LoginName,
        TextData
    ORDER BY AvgCPU DESC;

    -- Analyze usage patterns
    SELECT 
        DATEPART(HOUR, TraceTime) as HourOfDay,
        COUNT(*) as QueryCount,
        AVG(CPU) as AvgCPU,
        AVG(Reads) as AvgReads
    FROM dbo.TraceAnalysis
    GROUP BY DATEPART(HOUR, TraceTime)
    ORDER BY HourOfDay;
END;
GO

-- =============================================
-- PART 3: PERFORMANCE MONITORING
-- =============================================

-- Create Performance Monitoring Procedure
CREATE PROCEDURE dbo.Monitor_HR_Performance
AS
BEGIN
    SET NOCOUNT ON;

    -- Monitor active expensive queries
    SELECT 
        r.session_id,
        r.start_time,
        r.status,
        r.cpu_time,
        r.logical_reads,
        r.writes,
        t.text as QueryText,
        p.query_plan as QueryPlan
    FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    CROSS APPLY sys.dm_exec_query_plan(r.plan_handle) p
    WHERE r.database_id = DB_ID('HRSystem')
    AND r.cpu_time > 1000
    ORDER BY r.cpu_time DESC;

    -- Monitor resource usage by application
    SELECT 
        s.program_name,
        COUNT(*) as SessionCount,
        SUM(r.cpu_time) as TotalCPU,
        SUM(r.logical_reads) as TotalReads,
        SUM(r.writes) as TotalWrites
    FROM sys.dm_exec_sessions s
    LEFT JOIN sys.dm_exec_requests r
        ON s.session_id = r.session_id
    WHERE s.database_id = DB_ID('HRSystem')
    GROUP BY s.program_name
    ORDER BY TotalCPU DESC;
END;
GO

-- =============================================
-- PART 4: TRACE MAINTENANCE
-- =============================================

-- Create Trace Maintenance Procedure
CREATE PROCEDURE dbo.Maintain_Traces
AS
BEGIN
    SET NOCOUNT ON;

    -- Stop all active traces except system traces
    DECLARE @TraceID INT;
    DECLARE trace_cursor CURSOR FOR
        SELECT id FROM sys.traces
        WHERE is_system_trace = 0;

    OPEN trace_cursor;
    FETCH NEXT FROM trace_cursor INTO @TraceID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sp_trace_setstatus @TraceID, 0;
        EXEC sp_trace_setstatus @TraceID, 2;

        FETCH NEXT FROM trace_cursor INTO @TraceID;
    END;

    CLOSE trace_cursor;
    DEALLOCATE trace_cursor;

    -- Archive trace files
    DECLARE @cmd NVARCHAR(1000);
    DECLARE @archive_path NVARCHAR(260);
    
    SET @archive_path = 'C:\SQLTraces\Archive\' + 
        CONVERT(NVARCHAR(8), GETDATE(), 112);

    SET @cmd = 'mkdir "' + @archive_path + '"';
    EXEC master.dbo.xp_cmdshell @cmd;

    SET @cmd = 'move "C:\SQLTraces\*.trc" "' + @archive_path + '"';
    EXEC master.dbo.xp_cmdshell @cmd;

    -- Clean up old archives
    SET @cmd = 'forfiles /p "C:\SQLTraces\Archive" /d -30 /c "cmd /c rd /s /q @path"';
    EXEC master.dbo.xp_cmdshell @cmd;

    -- Cleanup analysis data older than 30 days
    DELETE FROM dbo.TraceAnalysis
    WHERE TraceTime < DATEADD(DAY, -30, GETDATE());
END;
GO