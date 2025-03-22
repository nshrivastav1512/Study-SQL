-- =============================================
-- SQL Server Dynamic Management Views (DMVs)
-- =============================================

/*
This script demonstrates using DMVs for monitoring SQL Server:
- Performance monitoring
- Resource utilization tracking
- Query execution statistics
- Memory usage analysis
*/

USE master;
GO

-- =============================================
-- PART 1: PERFORMANCE MONITORING
-- =============================================

-- Create Performance Monitoring Procedure
CREATE PROCEDURE dbo.Monitor_System_Performance
AS
BEGIN
    SET NOCOUNT ON;

    -- CPU Usage Statistics
    SELECT
        cpu.record_id,
        cpu.EventTime,
        cpu.SQLProcessUtilization,
        cpu.SystemIdle,
        100 - cpu.SystemIdle - cpu.SQLProcessUtilization AS OtherProcessUtilization
    FROM
    (
        SELECT
            record.value('(./Record/@id)[1]', 'int') AS record_id,
            record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS SystemIdle,
            record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS SQLProcessUtilization,
            DATEADD(ms, -1 * record.value('(./Record/@ms)[1]', 'int'), GETDATE()) AS EventTime
        FROM
        (
            SELECT TOP 10 CONVERT(XML, record) AS record
            FROM sys.dm_os_ring_buffers
            WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
            ORDER BY timestamp DESC
        ) AS RingBufferData
    ) AS cpu
    ORDER BY cpu.record_id DESC;

    -- Memory Usage
    SELECT
        (physical_memory_kb / 1024) AS Physical_Memory_MB,
        (available_physical_memory_kb / 1024) AS Available_Memory_MB,
        (total_virtual_memory_kb / 1024) AS Total_Virtual_Memory_MB,
        (available_virtual_memory_kb / 1024) AS Available_Virtual_Memory_MB,
        (memory_utilization_percentage) AS Memory_Utilization_Percentage
    FROM sys.dm_os_sys_memory;

    -- Buffer Pool Usage
    SELECT
        DB_NAME(database_id) AS DatabaseName,
        COUNT(*) * 8 / 1024 AS Cached_Size_MB,
        COUNT(*) AS Buffer_Cache_Pages
    FROM sys.dm_os_buffer_descriptors
    GROUP BY database_id
    ORDER BY Cached_Size_MB DESC;
END;
GO

-- =============================================
-- PART 2: I/O PERFORMANCE
-- =============================================

-- Create I/O Monitoring Procedure
CREATE PROCEDURE dbo.Monitor_IO_Performance
AS
BEGIN
    SET NOCOUNT ON;

    -- Database File I/O Statistics
    SELECT
        DB_NAME(mf.database_id) AS DatabaseName,
        mf.physical_name,
        mf.type_desc,
        fs.num_of_reads,
        fs.num_of_writes,
        fs.io_stall_read_ms,
        fs.io_stall_write_ms,
        CAST(100.0 * fs.io_stall_read_ms/(fs.io_stall_read_ms + fs.io_stall_write_ms)
            AS DECIMAL(10,1)) AS IO_Stall_Read_Percentage
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS fs
    INNER JOIN sys.master_files AS mf
        ON fs.database_id = mf.database_id
        AND fs.file_id = mf.file_id
    ORDER BY fs.io_stall_read_ms + fs.io_stall_write_ms DESC;

    -- Pending I/O Requests
    SELECT
        DB_NAME(mf.database_id) AS DatabaseName,
        mf.physical_name,
        r.io_pending,
        r.io_pending_ms_ticks,
        r.io_type,
        fs.num_of_reads,
        fs.num_of_writes
    FROM sys.dm_io_pending_io_requests AS r
    INNER JOIN sys.dm_io_virtual_file_stats(NULL, NULL) AS fs
        ON r.file_handle = fs.file_handle
    INNER JOIN sys.master_files AS mf
        ON fs.database_id = mf.database_id
        AND fs.file_id = mf.file_id;
END;
GO

-- =============================================
-- PART 3: QUERY PERFORMANCE
-- =============================================

-- Create Query Performance Monitoring Procedure
CREATE PROCEDURE dbo.Monitor_Query_Performance
AS
BEGIN
    SET NOCOUNT ON;

    -- Most Expensive Queries by CPU
    SELECT TOP 10
        qs.total_worker_time/qs.execution_count AS Avg_CPU_Time,
        qs.total_worker_time AS Total_CPU_Time,
        qs.execution_count,
        SUBSTRING(qt.text,qs.statement_start_offset/2, 
            (CASE WHEN qs.statement_end_offset = -1 
                THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
                ELSE qs.statement_end_offset END - qs.statement_start_offset)/2
            ) AS Query_Text,
        DB_NAME(qt.dbid) AS DatabaseName,
        qp.query_plan
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
    CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) as qp
    ORDER BY qs.total_worker_time/qs.execution_count DESC;

    -- Queries with High I/O
    SELECT TOP 10
        (total_logical_reads + total_logical_writes) / execution_count AS Avg_IO,
        total_logical_reads + total_logical_writes AS Total_IO,
        execution_count,
        SUBSTRING(qt.text,qs.statement_start_offset/2, 
            (CASE WHEN qs.statement_end_offset = -1 
                THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
                ELSE qs.statement_end_offset END - qs.statement_start_offset)/2
            ) AS Query_Text,
        DB_NAME(qt.dbid) AS DatabaseName
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
    ORDER BY (total_logical_reads + total_logical_writes) / execution_count DESC;
END;
GO

-- =============================================
-- PART 4: CONNECTION AND SESSION MONITORING
-- =============================================

-- Create Connection Monitoring Procedure
CREATE PROCEDURE dbo.Monitor_Connections
AS
BEGIN
    SET NOCOUNT ON;

    -- Active Sessions
    SELECT
        s.session_id,
        s.login_name,
        s.host_name,
        s.program_name,
        DB_NAME(s.database_id) AS DatabaseName,
        s.cpu_time,
        s.memory_usage,
        s.total_scheduled_time,
        s.total_elapsed_time,
        s.reads,
        s.writes,
        s.logical_reads,
        r.wait_type,
        r.wait_time,
        r.blocking_session_id,
        t.text AS Last_Query
    FROM sys.dm_exec_sessions s
    LEFT JOIN sys.dm_exec_requests r
        ON s.session_id = r.session_id
    OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE s.is_user_process = 1;

    -- Blocking Information
    SELECT
        tl.resource_type,
        DB_NAME(tl.resource_database_id) AS DatabaseName,
        OBJECT_NAME(tl.resource_associated_entity_id) AS BlockedObject,
        tl.request_mode,
        tl.request_session_id,
        es.login_name AS BlockedUser,
        es_2.login_name AS BlockingUser,
        tl.resource_description
    FROM sys.dm_tran_locks as tl
    INNER JOIN sys.dm_exec_sessions as es
        ON tl.request_session_id = es.session_id
    INNER JOIN sys.dm_exec_sessions as es_2
        ON tl.request_session_id = es_2.session_id
    WHERE tl.request_status = 'WAIT';
END;
GO