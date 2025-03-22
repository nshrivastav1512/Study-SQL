-- =============================================
-- QUERY STORE Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Query Store, including:
- What Query Store is and its benefits
- How to enable and configure Query Store
- Monitoring query performance over time
- Identifying and resolving performance regressions
- Forcing execution plans
- Query Store reports and views
- Best practices and maintenance
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: QUERY STORE FUNDAMENTALS
-- =============================================

-- What is Query Store?
-- Query Store is a database feature that captures query execution statistics and plans over time
-- It provides insights into query performance history and allows for plan forcing

-- Benefits of Query Store:
-- 1. Performance troubleshooting across time periods
-- 2. Identifying query regressions
-- 3. Ensuring plan stability by forcing optimal plans
-- 4. Monitoring resource usage patterns

-- =============================================
-- PART 2: ENABLING AND CONFIGURING QUERY STORE
-- =============================================

-- Enable Query Store for a database
ALTER DATABASE HRSystem SET QUERY_STORE = ON;

-- Configure Query Store with custom settings
ALTER DATABASE HRSystem SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    INTERVAL_LENGTH_MINUTES = 60,
    MAX_STORAGE_SIZE_MB = 1000,
    QUERY_CAPTURE_MODE = ALL,
    SIZE_BASED_CLEANUP_MODE = AUTO,
    MAX_PLANS_PER_QUERY = 200
);

-- Explanation of settings:
-- OPERATION_MODE: Controls whether Query Store is collecting data (READ_WRITE) or read-only
-- CLEANUP_POLICY: How long to keep data before automatic cleanup
-- DATA_FLUSH_INTERVAL_SECONDS: How often to write data from memory to disk
-- INTERVAL_LENGTH_MINUTES: Size of the time intervals for aggregating statistics
-- MAX_STORAGE_SIZE_MB: Maximum disk space Query Store can use
-- QUERY_CAPTURE_MODE: Which queries to capture (ALL, AUTO, NONE)
-- SIZE_BASED_CLEANUP_MODE: Whether to automatically clean up when approaching size limit
-- MAX_PLANS_PER_QUERY: Maximum number of plans to store per query

-- Check Query Store status and configuration
SELECT * FROM sys.database_query_store_options;

-- =============================================
-- PART 3: MONITORING QUERY PERFORMANCE
-- =============================================

-- 1. View overall Query Store statistics
SELECT * FROM sys.dm_db_query_store_runtime_stats;

-- 2. Identify top resource-consuming queries
SELECT 
    q.query_id,
    qt.query_sql_text,
    rs.count_executions,
    rs.avg_duration,
    rs.avg_cpu_time,
    rs.avg_logical_io_reads,
    rs.avg_logical_io_writes,
    rs.avg_physical_io_reads,
    rs.last_execution_time
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
ORDER BY rs.avg_cpu_time DESC;

-- 3. Track query performance over time
SELECT 
    q.query_id,
    qt.query_sql_text,
    p.plan_id,
    rs.runtime_stats_id,
    rsi.start_time,
    rsi.end_time,
    rs.avg_duration,
    rs.avg_cpu_time,
    rs.avg_logical_io_reads
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
JOIN sys.query_store_runtime_stats_interval rsi ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE q.query_id = 42 -- Replace with actual query_id
ORDER BY rsi.start_time;

-- 4. Compare performance across different plans for the same query
SELECT 
    p.plan_id,
    p.query_id,
    AVG(rs.avg_duration) AS avg_duration,
    AVG(rs.avg_cpu_time) AS avg_cpu_time,
    AVG(rs.avg_logical_io_reads) AS avg_logical_io_reads,
    COUNT(rs.runtime_stats_id) AS num_executions
FROM sys.query_store_plan p
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE p.query_id = 42 -- Replace with actual query_id
GROUP BY p.plan_id, p.query_id
ORDER BY avg_duration;

-- =============================================
-- PART 4: IDENTIFYING PERFORMANCE REGRESSIONS
-- =============================================

-- 1. Find queries with multiple plans and performance variations
SELECT 
    q.query_id,
    qt.query_sql_text,
    COUNT(DISTINCT p.plan_id) AS number_of_plans,
    MIN(rs.avg_duration) AS min_duration,
    MAX(rs.avg_duration) AS max_duration,
    MAX(rs.avg_duration) - MIN(rs.avg_duration) AS duration_variance
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
GROUP BY q.query_id, qt.query_sql_text
HAVING COUNT(DISTINCT p.plan_id) > 1
ORDER BY duration_variance DESC;

-- 2. Identify queries with recent performance degradation
SELECT 
    q.query_id,
    qt.query_sql_text,
    p.plan_id,
    rs_recent.avg_duration AS recent_avg_duration,
    rs_history.avg_duration AS historical_avg_duration,
    (rs_recent.avg_duration - rs_history.avg_duration) / rs_history.avg_duration * 100 AS pct_change
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN (
    -- Recent performance (last day)
    SELECT 
        plan_id, 
        AVG(avg_duration) AS avg_duration
    FROM sys.query_store_runtime_stats rs
    JOIN sys.query_store_runtime_stats_interval rsi 
        ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
    WHERE rsi.start_time >= DATEADD(day, -1, GETUTCDATE())
    GROUP BY plan_id
) AS rs_recent ON p.plan_id = rs_recent.plan_id
JOIN (
    -- Historical performance (last month excluding last day)
    SELECT 
        plan_id, 
        AVG(avg_duration) AS avg_duration
    FROM sys.query_store_runtime_stats rs
    JOIN sys.query_store_runtime_stats_interval rsi 
        ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
    WHERE 
        rsi.start_time >= DATEADD(month, -1, GETUTCDATE()) AND
        rsi.start_time < DATEADD(day, -1, GETUTCDATE())
    GROUP BY plan_id
) AS rs_history ON p.plan_id = rs_history.plan_id
WHERE 
    rs_history.avg_duration > 0 AND
    rs_recent.avg_duration > rs_history.avg_duration * 1.5 -- 50% or more degradation
ORDER BY pct_change DESC;

-- 3. Visualize performance over time for a specific query
-- (This would typically be done through SSMS UI, but here's the underlying query)
SELECT 
    rsi.start_time,
    rsi.end_time,
    rs.avg_duration,
    rs.avg_cpu_time,
    rs.avg_logical_io_reads,
    p.plan_id
FROM sys.query_store_runtime_stats rs
JOIN sys.query_store_runtime_stats_interval rsi 
    ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
JOIN sys.query_store_plan p ON rs.plan_id = p.plan_id
WHERE p.query_id = 42 -- Replace with actual query_id
ORDER BY rsi.start_time;

-- =============================================
-- PART 5: FORCING EXECUTION PLANS
-- =============================================

-- 1. Force a specific plan for a query
-- This ensures SQL Server uses this plan regardless of parameter values or statistics
EXEC sp_query_store_force_plan @query_id = 42, @plan_id = 142;

-- 2. Unforce a previously forced plan
EXEC sp_query_store_unforce_plan @query_id = 42, @plan_id = 142;

-- 3. View currently forced plans
SELECT 
    q.query_id,
    qt.query_sql_text,
    p.plan_id,
    p.is_forced_plan,
    p.force_failure_count,
    p.last_force_failure_reason_desc
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
WHERE p.is_forced_plan = 1;

-- 4. Real-world scenario: Force the best performing plan
-- First, identify the best performing plan for a problematic query
DECLARE @query_id INT = 42; -- Replace with actual query_id

DECLARE @best_plan_id INT;
SELECT TOP 1 @best_plan_id = p.plan_id
FROM sys.query_store_plan p
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE p.query_id = @query_id
GROUP BY p.plan_id
ORDER BY AVG(rs.avg_duration) ASC;

-- Then force that plan
IF @best_plan_id IS NOT NULL
BEGIN
    EXEC sp_query_store_force_plan @query_id = @query_id, @plan_id = @best_plan_id;
    PRINT 'Forced plan ' + CAST(@best_plan_id AS VARCHAR) + ' for query ' + CAST(@query_id AS VARCHAR);
END
ELSE
    PRINT 'No suitable plan found for query ' + CAST(@query_id AS VARCHAR);

-- =============================================
-- PART 6: QUERY STORE REPORTS AND VIEWS
-- =============================================

-- 1. Query Store catalog views

-- Query texts
SELECT * FROM sys.query_store_query_text;

-- Queries
SELECT * FROM sys.query_store_query;

-- Plans
SELECT * FROM sys.query_store_plan;

-- Runtime statistics
SELECT * FROM sys.query_store_runtime_stats;

-- Runtime statistics intervals
SELECT * FROM sys.query_store_runtime_stats_interval;

-- Wait statistics
SELECT * FROM sys.query_store_wait_stats;

-- 2. Built-in procedures for Query Store management

-- Clean up Query Store data
EXEC sp_query_store_reset_exec_stats @query_id = NULL; -- Reset execution statistics
EXEC sp_query_store_remove_query @query_id = NULL; -- Remove all queries
EXEC sp_query_store_remove_plan @plan_id = NULL; -- Remove all plans
EXEC sp_query_store_flush_db; -- Flush Query Store data to disk

-- 3. Custom reports

-- Top 10 queries by average CPU time
SELECT TOP 10
    q.query_id,
    SUBSTRING(qt.query_sql_text, 1, 100) AS query_text_snippet,
    p.plan_id,
    SUM(rs.count_executions) AS total_executions,
    SUM(rs.count_executions * rs.avg_cpu_time) / SUM(rs.count_executions) AS overall_avg_cpu_time,
    MIN(rs.min_cpu_time) AS min_cpu_time,
    MAX(rs.max_cpu_time) AS max_cpu_time,
    SUM(rs.count_executions * rs.avg_logical_io_reads) / SUM(rs.count_executions) AS overall_avg_logical_reads
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
GROUP BY q.query_id, SUBSTRING(qt.query_sql_text, 1, 100), p.plan_id
ORDER BY overall_avg_cpu_time DESC;

-- Queries with high variation in execution time
SELECT 
    q.query_id,
    SUBSTRING(qt.query_sql_text, 1, 100) AS query_text_snippet,
    COUNT(DISTINCT p.plan_id) AS number_of_plans,
    SUM(rs.count_executions) AS total_executions,
    MIN(rs.avg_duration) AS min_avg_duration,
    MAX(rs.avg_duration) AS