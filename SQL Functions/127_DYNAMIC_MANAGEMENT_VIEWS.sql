/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\127_DYNAMIC_MANAGEMENT_VIEWS.sql
    
    This script demonstrates SQL Server Dynamic Management Views (DMVs) and Functions
    using the HRSystem database. These views provide insights into server performance,
    resource usage, and query execution statistics.

    DMVs and Functions covered:
    1. sys.dm_exec_requests - Active request information
    2. sys.dm_exec_sessions - Session information
    3. sys.dm_exec_query_stats - Query performance statistics
    4. sys.dm_db_index_usage_stats - Index usage statistics
    5. sys.dm_os_wait_stats - Wait statistics
    6. sys.dm_tran_active_transactions - Active transaction information
*/

USE HRSystem;
GO

-- Create a table for storing performance analysis results
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[PerformanceAnalysis]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.PerformanceAnalysis (
        AnalysisID INT PRIMARY KEY IDENTITY(1,1),
        AnalysisType NVARCHAR(50),
        MetricName NVARCHAR(100),
        MetricValue DECIMAL(18,2),
        AnalysisDate DATETIME2 DEFAULT SYSDATETIME(),
        AnalyzedBy NVARCHAR(128) DEFAULT SYSTEM_USER,
        AdditionalInfo XML
    );
END

-- 1. Query Active Requests
INSERT INTO HR.PerformanceAnalysis (
    AnalysisType,
    MetricName,
    MetricValue,
    AdditionalInfo
)
SELECT 
    'Active Requests',
    'CPU Time (ms)',
    AVG(CAST(r.cpu_time AS DECIMAL(18,2))),
    (
        SELECT TOP 5
            session_id,
            start_time,
            status,
            command,
            cpu_time,
            total_elapsed_time,
            reads,
            writes,
            logical_reads
        FROM sys.dm_exec_requests
        WHERE session_id > 50 -- Exclude system sessions
        FOR XML AUTO, ELEMENTS
    )
FROM sys.dm_exec_requests r
WHERE r.session_id > 50;

-- 2. Analyze Session Information
INSERT INTO HR.PerformanceAnalysis (
    AnalysisType,
    MetricName,
    MetricValue,
    AdditionalInfo
)
SELECT 
    'Active Sessions',
    'Memory Usage (KB)',
    AVG(CAST(s.memory_usage AS DECIMAL(18,2))),
    (
        SELECT TOP 5
            session_id,
            login_time,
            host_name,
            program_name,
            login_name,
            memory_usage
        FROM sys.dm_exec_sessions
        WHERE session_id > 50
        FOR XML AUTO, ELEMENTS
    )
FROM sys.dm_exec_sessions s
WHERE s.session_id > 50;

-- 3. Query Performance Statistics
INSERT INTO HR.PerformanceAnalysis (
    AnalysisType,
    MetricName,
    MetricValue,
    AdditionalInfo
)
SELECT TOP 1
    'Query Statistics',
    'Average CPU Time (ms)',
    AVG(CAST(qs.total_worker_time AS DECIMAL(18,2))) / qs.execution_count,
    (
        SELECT TOP 5
            SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
                ((CASE qs.statement_end_offset
                    WHEN -1 THEN DATALENGTH(qt.text)
                    ELSE qs.statement_end_offset
                END - qs.statement_start_offset)/2) + 1) AS query_text,
            qs.execution_count,
            qs.total_worker_time / qs.execution_count AS avg_cpu_time,
            qs.total_elapsed_time / qs.execution_count AS avg_elapsed_time,
            qs.total_logical_reads / qs.execution_count AS avg_logical_reads
        FROM sys.dm_exec_query_stats qs
        CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
        ORDER BY qs.total_worker_time DESC
        FOR XML AUTO, ELEMENTS
    )
FROM sys.dm_exec_query_stats qs;

-- 4. Index Usage Statistics
INSERT INTO HR.PerformanceAnalysis (
    AnalysisType,
    MetricName,
    MetricValue,
    AdditionalInfo
)
SELECT TOP 1
    'Index Usage',
    'Average Seeks Count',
    AVG(CAST(ius.user_seeks AS DECIMAL(18,2))),
    (
        SELECT TOP 5
            OBJECT_NAME(i.object_id) AS table_name,
            i.name AS index_name,
            ius.user_seeks,
            ius.user_scans,
            ius.user_lookups,
            ius.user_updates
        FROM sys.dm_db_index_usage_stats ius
        JOIN sys.indexes i ON 
            ius.object_id = i.object_id AND
            ius.index_id = i.index_id
        WHERE ius.database_id = DB_ID()
        ORDER BY (ius.user_seeks + ius.user_scans + ius.user_lookups) DESC
        FOR XML AUTO, ELEMENTS
    )
FROM sys.dm_db_index_usage_stats ius
WHERE ius.database_id = DB_ID();

-- 5. Wait Statistics Analysis
INSERT INTO HR.PerformanceAnalysis (
    AnalysisType,
    MetricName,
    MetricValue,
    AdditionalInfo
)
SELECT TOP 1
    'Wait Statistics',
    'Average Wait Time (ms)',
    AVG(CAST(wait_time_ms AS DECIMAL(18,2))) / waiting_tasks_count,
    (
        SELECT TOP 5
            wait_type,
            waiting_tasks_count,
            wait_time_ms,
            max_wait_time_ms,
            signal_wait_time_ms
        FROM sys.dm_os_wait_stats
        WHERE waiting_tasks_count > 0
        ORDER BY wait_time_ms DESC
        FOR XML AUTO, ELEMENTS
    )
FROM sys.dm_os_wait_stats
WHERE waiting_tasks_count > 0;

-- 6. Active Transactions Analysis
INSERT INTO HR.PerformanceAnalysis (
    AnalysisType,
    MetricName,
    MetricValue,
    AdditionalInfo
)
SELECT 
    'Active Transactions',
    'Transaction Count',
    COUNT(*),
    (
        SELECT TOP 5
            transaction_id,
            transaction_begin_time,
            transaction_type,
            transaction_state,
            transaction_status
        FROM sys.dm_tran_active_transactions
        FOR XML AUTO, ELEMENTS
    )
FROM sys.dm_tran_active_transactions;

-- View Performance Analysis Results
SELECT 
    AnalysisType,
    MetricName,
    MetricValue,
    AnalysisDate,
    AnalyzedBy,
    AdditionalInfo.value('(/row[1]/query_text)[1]', 'nvarchar(max)') AS SampleQueryText,
    AdditionalInfo.value('(/row[1]/wait_type)[1]', 'nvarchar(100)') AS TopWaitType,
    AdditionalInfo.value('(/row[1]/index_name)[1]', 'nvarchar(100)') AS TopUsedIndex
FROM HR.PerformanceAnalysis
ORDER BY AnalysisDate DESC;

-- Cleanup (commented out for safety)
/*
DROP TABLE IF EXISTS HR.PerformanceAnalysis;
*/