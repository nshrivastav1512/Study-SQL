-- =============================================
-- DQL System & Metadata Queries
-- =============================================

USE HRSystem;
GO

-- 1. Database Information
-- Query database properties and settings
SELECT 
    DB_NAME() AS DatabaseName,
    SUSER_SNAME() AS CurrentUser,
    USER_NAME() AS DatabaseUser,
    SERVERPROPERTY('ProductVersion') AS SQLServerVersion,
    SERVERPROPERTY('Edition') AS SQLServerEdition,
    DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS DatabaseCollation,
    DATABASEPROPERTYEX(DB_NAME(), 'Recovery') AS RecoveryModel,
    DATABASEPROPERTYEX(DB_NAME(), 'IsAutoShrink') AS IsAutoShrink,
    DATABASEPROPERTYEX(DB_NAME(), 'IsAutoCreateStatistics') AS IsAutoCreateStatistics;
-- Returns information about the current database
-- Shows version, edition, and configuration settings
-- Useful for documentation and troubleshooting

-- 2. Table Information
-- List all tables with row counts
SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    p.rows AS RowCount,
    CAST(ROUND((SUM(a.total_pages) * 8) / 1024.0, 2) AS DECIMAL(10,2)) AS TotalSpaceMB,
    CAST(ROUND((SUM(a.used_pages) * 8) / 1024.0, 2) AS DECIMAL(10,2)) AS UsedSpaceMB
FROM sys.tables t
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.is_ms_shipped = 0
GROUP BY s.name, t.name, p.rows
ORDER BY s.name, t.name;
-- Lists all user tables in the database
-- Shows row counts and space usage
-- Helps identify large tables

-- 3. Column Information
-- List all columns with data types
SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    c.name AS ColumnName,
    ty.name AS DataType,
    c.max_length AS MaxLength,
    c.precision AS Precision,
    c.scale AS Scale,
    c.is_nullable AS IsNullable,
    c.is_identity AS IsIdentity,
    CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS IsPrimaryKey
FROM sys.tables t
INNER JOIN sys.columns c ON t.object_id = c.object_id
INNER JOIN sys.types ty ON c.user_type_id = ty.user_type_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN (
    SELECT ic.object_id, ic.column_id
    FROM sys.indexes i
    JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    WHERE i.is_primary_key = 1
) pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id
WHERE t.is_ms_shipped = 0
ORDER BY s.name, t.name, c.column_id;
-- Lists all columns in all user tables
-- Shows data types, nullability, and primary key status
-- Helps understand database schema

-- 4. Index Information
-- List all indexes with details
SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.is_primary_key AS IsPrimaryKey,
    i.is_unique AS IsUnique,
    i.fill_factor AS FillFactor,
    STUFF((
        SELECT ', ' + c.name
        FROM sys.index_columns ic
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
        ORDER BY ic.key_ordinal
        FOR XML PATH('')
    ), 1, 2, '') AS KeyColumns,
    STUFF((
        SELECT ', ' + c.name
        FROM sys.index_columns ic
        JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
        ORDER BY ic.key_ordinal
        FOR XML PATH('')
    ), 1, 2, '') AS IncludedColumns
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.is_ms_shipped = 0 AND i.type > 0
ORDER BY s.name, t.name, i.name;
-- Lists all indexes in the database
-- Shows key columns and included columns
-- Helps identify missing or redundant indexes

-- 5. Foreign Key Relationships
-- List all foreign key constraints
SELECT 
    fk.name AS ForeignKeyName,
    ps.name AS ParentSchemaName,
    pt.name AS ParentTableName,
    pc.name AS ParentColumnName,
    rs.name AS ReferencedSchemaName,
    rt.name AS ReferencedTableName,
    rc.name AS ReferencedColumnName,
    fk.delete_referential_action_desc AS DeleteAction,
    fk.update_referential_action_desc AS UpdateAction
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
INNER JOIN sys.tables pt ON fk.parent_object_id = pt.object_id
INNER JOIN sys.schemas ps ON pt.schema_id = ps.schema_id
INNER JOIN sys.columns pc ON fkc.parent_object_id = pc.object_id AND fkc.parent_column_id = pc.column_id
INNER JOIN sys.tables rt ON fk.referenced_object_id = rt.object_id
INNER JOIN sys.schemas rs ON rt.schema_id = rs.schema_id
INNER JOIN sys.columns rc ON fkc.referenced_object_id = rc.object_id AND fkc.referenced_column_id = rc.column_id
ORDER BY ps.name, pt.name, fk.name;
-- Lists all foreign key relationships
-- Shows parent and referenced tables and columns
-- Includes referential actions (CASCADE, SET NULL, etc.)

-- 6. Stored Procedure Information
-- List all stored procedures with details
SELECT 
    s.name AS SchemaName,
    p.name AS ProcedureName,
    p.create_date AS CreatedDate,
    p.modify_date AS LastModifiedDate,
    p.is_ms_shipped AS IsSystemObject,
    OBJECT_DEFINITION(p.object_id) AS ProcedureDefinition
FROM sys.procedures p
INNER JOIN sys.schemas s ON p.schema_id = s.schema_id
WHERE p.is_ms_shipped = 0
ORDER BY s.name, p.name;
-- Lists all user-defined stored procedures
-- Shows creation and modification dates
-- Includes the full procedure definition

-- 7. View Information
-- List all views with details
SELECT 
    s.name AS SchemaName,
    v.name AS ViewName,
    v.create_date AS CreatedDate,
    v.modify_date AS LastModifiedDate,
    v.is_ms_shipped AS IsSystemObject,
    OBJECT_DEFINITION(v.object_id) AS ViewDefinition
FROM sys.views v
INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
WHERE v.is_ms_shipped = 0
ORDER BY s.name, v.name;
-- Lists all user-defined views
-- Shows creation and modification dates
-- Includes the full view definition

-- 8. User and Permission Information
-- List all database users and their roles
SELECT 
    dp.name AS PrincipalName,
    dp.type_desc AS PrincipalType,
    STUFF((
        SELECT ', ' + r.name
        FROM sys.database_principals r
        INNER JOIN sys.database_role_members rm ON r.principal_id = rm.role_principal_id
        WHERE rm.member_principal_id = dp.principal_id
        ORDER BY r.name
        FOR XML PATH('')
    ), 1, 2, '') AS DatabaseRoles
FROM sys.database_principals dp
WHERE dp.type IN ('S', 'U', 'G') -- SQL users, Windows users, Windows groups
  AND dp.name NOT IN ('sys', 'INFORMATION_SCHEMA')
ORDER BY dp.name;
-- Lists all database users
-- Shows user type (SQL user, Windows user, etc.)
-- Lists all roles assigned to each user

-- 9. Object Permission Information
-- List permissions granted on database objects
SELECT 
    dp.name AS PrincipalName,
    dp.type_desc AS PrincipalType,
    o.name AS ObjectName,
    o.type_desc AS ObjectType,
    p.permission_name AS Permission,
    p.state_desc AS PermissionState
FROM sys.database_permissions p
INNER JOIN sys.objects o ON p.major_id = o.object_id
INNER JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
WHERE o.is_ms_shipped = 0
ORDER BY dp.name, o.name, p.permission_name;
-- Lists all permissions granted on database objects
-- Shows which users have which permissions
-- Includes permission state (GRANT, DENY, etc.)

-- 10. Database File Information
-- List database files and their properties
SELECT 
    f.name AS FileName,
    f.physical_name AS PhysicalName,
    f.type_desc AS FileType,
    CAST(f.size * 8.0 / 1024 AS DECIMAL(10,2)) AS FileSizeMB,
    CASE WHEN f.max_size = -1 THEN 'Unlimited' ELSE CAST(f.max_size * 8.0 / 1024 AS VARCHAR) END AS MaxSizeMB,
    CAST(f.growth * 8.0 / 1024 AS DECIMAL(10,2)) AS GrowthMB,
    f.is_percent_growth AS IsPercentGrowth
FROM sys.database_files f;
-- Lists all database files
-- Shows file size, location, and growth settings
-- Helps monitor database storage

-- 11. Query Execution Statistics
-- View most expensive queries
SELECT TOP 20
    qs.total_elapsed_time / qs.execution_count / 1000.0 AS avg_elapsed_time_ms,
    qs.total_elapsed_time / 1000.0 AS total_elapsed_time_ms,
    qs.execution_count,
    qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
    qs.total_logical_writes / qs.execution_count AS avg_logical_writes,
    qs.total_worker_time / qs.execution_count / 1000.0 AS avg_cpu_time_ms,
    qs.total_worker_time / 1000.0 AS total_cpu_time_ms,
    qs.last_execution_time,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1, 
        (CASE WHEN qs.statement_end_offset = -1 
            THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
            ELSE qs.statement_end_offset 
        END - qs.statement_start_offset)/2) AS query_text,
    DB_NAME(qt.dbid) AS DatabaseName,
    qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.total_elapsed_time / qs.execution_count DESC;
-- Lists the most expensive queries by average execution time
-- Shows execution statistics and query text
-- Includes execution plan for performance analysis

-- 12. Index Usage Statistics
-- View index usage information
SELECT 
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    ius.user_seeks AS Seeks,
    ius.user_scans AS Scans,
    ius.user_lookups AS Lookups,
    ius.user_updates AS Updates,
    ius.last_user_seek AS LastSeek,
    ius.last_user_scan AS LastScan,
    ius.last_user_lookup AS LastLookup,
    ius.last_user_update AS LastUpdate
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats ius ON i.object_id = ius.object_id AND i.index_id = ius.index_id AND ius.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
ORDER BY OBJECT_NAME(i.object_id), i.name;
-- Shows how frequently each index is used
-- Helps identify unused or inefficient indexes
-- Includes last usage timestamps

-- 13. Missing Index Recommendations
-- View missing index suggestions
SELECT 
    DB_NAME(mid.database_id) AS DatabaseName,
    OBJECT_NAME(mid.object_id, mid.database_id) AS TableName,
    migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) AS ImprovementMeasure,
    migs.user_seeks + migs.user_scans AS UserQueryCount,
    migs.avg_total_user_cost AS AvgQueryCostReduction,
    migs.avg_user_impact AS AvgUserImpact,
    mid.equality_columns AS EqualityColumns,
    mid.inequality_columns AS InequalityColumns,
    mid.included_columns AS IncludedColumns,
    'CREATE NONCLUSTERED INDEX IX_' + OBJECT_NAME(mid.object_id, mid.database_id) + '_Missing_' + 
        CAST(mig.index_group_handle AS VARCHAR(10)) + 
        ' ON ' + mid.statement + 
        ' (' + ISNULL(mid.equality_columns, '') + 
        CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ', ' ELSE '' END + 
        ISNULL(mid.inequality_columns, '') + ')' + 
        ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS CreateIndexStatement
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
ORDER BY ImprovementMeasure DESC;
-- Identifies missing indexes that could improve performance
-- Calculates potential improvement measure
-- Generates CREATE INDEX statements

-- 14. Table Dependencies
-- View object dependencies
WITH Dependencies AS (
    SELECT 
        OBJECT_NAME(referencing_id) AS ReferencingObject,
        o1.type_desc AS ReferencingType,
        OBJECT_NAME(referenced_id) AS ReferencedObject,
        o2.type_desc AS ReferencedType
    FROM sys.sql_expression_dependencies d
    JOIN sys.objects o1 ON d.referencing_id = o1.object_id
    JOIN sys.objects o2 ON d.referenced_id = o2.object_id
    WHERE d.referenced_id IS NOT NULL
)
SELECT 
    ReferencingObject,
    ReferencingType,
    ReferencedObject,
    ReferencedType
FROM Dependencies
ORDER BY ReferencedObject, ReferencingObject;
-- Shows dependencies between database objects
-- Helps understand impact of schema changes
-- Identifies objects that reference a specific table or view

-- 15. Database Backup History
-- View backup history
SELECT 
    bs.database_name AS DatabaseName,
    bs.backup_start_date AS BackupStartTime,
    bs.backup_finish_date AS BackupFinishTime,
    DATEDIFF(MINUTE, bs.backup_start_date, bs.backup_finish_date) AS DurationMinutes,
    bs.backup_size / 1024 / 1024 AS BackupSizeMB,
    bmf.physical_device_name AS BackupFile,
    CASE bs.type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Log'
        ELSE bs.type
    END AS BackupType
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = DB_NAME()
ORDER BY bs.backup_start_date DESC;
-- Shows backup history for the current database
-- Includes backup type, size, and duration
-- Helps verify backup strategy compliance

-- 16. Server Configuration
-- View SQL Server configuration settings
SELECT 
    name AS ConfigurationName,
    value AS ConfiguredValue,
    value_in_use AS RunningValue,
    minimum AS MinimumValue,
    maximum AS MaximumValue,
    is_dynamic AS IsDynamic,
    is_advanced AS IsAdvanced,
    description AS Description
FROM sys.configurations
ORDER BY name;
-- Lists all SQL Server configuration settings
-- Shows configured vs. running values

-- 17. Wait Statistics
-- View current wait types affecting performance
SELECT TOP 20
    wait_type AS WaitType,
    waiting_tasks_count AS WaitingTasksCount,
    wait_time_ms AS TotalWaitTimeMs,
    wait_time_ms / waiting_tasks_count AS AvgWaitTimeMs,
    max_wait_time_ms AS MaxWaitTimeMs,
    signal_wait_time_ms AS SignalWaitTimeMs,
    signal_wait_time_ms * 100.0 / wait_time_ms AS PercentSignalWaits
FROM sys.dm_os_wait_stats
WHERE waiting_tasks_count > 0
AND wait_type NOT LIKE 'SLEEP_%'
AND wait_type NOT LIKE 'LAZYWRITER_%'
AND wait_type NOT LIKE 'HADR_%'
AND wait_type NOT IN ('SQLTRACE_BUFFER_FLUSH', 'WAITFOR', 'CHECKPOINT_QUEUE', 'REQUEST_FOR_DEADLOCK_SEARCH')
ORDER BY wait_time_ms DESC;
-- Shows top wait types affecting server performance
-- Helps identify resource bottlenecks
-- Excludes benign system waits

-- 18. Memory Usage
-- View memory usage by database
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    COUNT(*) AS BufferCount,
    COUNT(*) * 8 / 1024 AS BufferSizeMB,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM sys.dm_os_buffer_descriptors) AS PercentOfTotal
FROM sys.dm_os_buffer_descriptors
WHERE database_id <> 32767 -- ResourceDB
GROUP BY database_id
ORDER BY BufferCount DESC;
-- Shows buffer pool usage by database
-- Helps identify memory-intensive databases
-- Useful for memory optimization

-- 19. Cached Query Plans
-- View cached execution plans
SELECT TOP 20
    cp.objtype AS ObjectType,
    OBJECT_NAME(st.objectid, st.dbid) AS ObjectName,
    cp.usecounts AS ExecutionCount,
    cp.size_in_bytes / 1024 AS SizeKB,
    st.text AS QueryText,
    qp.query_plan AS QueryPlan
FROM sys.dm_exec_cached_plans cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
WHERE cp.cacheobjtype = 'Compiled Plan'
AND cp.objtype IN ('Proc', 'Prepared', 'Adhoc')
ORDER BY cp.usecounts DESC;
-- Shows most frequently executed query plans
-- Includes plan size and execution count
-- Helps identify frequently used procedures and queries

-- 20. Database Triggers
-- List all triggers in the database
SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    tr.name AS TriggerName,
    tr.create_date AS CreatedDate,
    tr.modify_date AS LastModifiedDate,
    CASE tr.is_disabled WHEN 1 THEN 'Yes' ELSE 'No' END AS IsDisabled,
    CASE 
        WHEN tr.is_instead_of_trigger = 1 THEN 'INSTEAD OF'
        ELSE 'AFTER'
    END AS TriggerType,
    CASE WHEN OBJECTPROPERTY(tr.object_id, 'ExecIsInsertTrigger') = 1 THEN 'Yes' ELSE 'No' END AS IsInsertTrigger,
    CASE WHEN OBJECTPROPERTY(tr.object_id, 'ExecIsUpdateTrigger') = 1 THEN 'Yes' ELSE 'No' END AS IsUpdateTrigger,
    CASE WHEN OBJECTPROPERTY(tr.object_id, 'ExecIsDeleteTrigger') = 1 THEN 'Yes' ELSE 'No' END AS IsDeleteTrigger,
    OBJECT_DEFINITION(tr.object_id) AS TriggerDefinition
FROM sys.triggers tr
JOIN sys.tables t ON tr.parent_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
ORDER BY s.name, t.name, tr.name;
-- Lists all triggers in the database
-- Shows trigger type and events (INSERT, UPDATE, DELETE)
-- Includes trigger definition and status

-- 21. Database Constraints
-- List all constraints in the database
SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    c.name AS ConstraintName,
    CASE c.type 
        WHEN 'PK' THEN 'Primary Key'
        WHEN 'UQ' THEN 'Unique Constraint'
        WHEN 'FK' THEN 'Foreign Key'
        WHEN 'C' THEN 'Check Constraint'
        WHEN 'D' THEN 'Default Constraint'
    END AS ConstraintType,
    CASE 
        WHEN c.type = 'C' THEN OBJECT_DEFINITION(c.object_id)
        WHEN c.type = 'D' THEN OBJECT_DEFINITION(c.object_id)
        ELSE NULL
    END AS ConstraintDefinition
FROM sys.constraints c
JOIN sys.tables t ON c.parent_object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
ORDER BY s.name, t.name, c.type, c.name;
-- Lists all constraints in the database
-- Shows constraint type and definition
-- Helps understand data integrity rules

-- 22. Database Fragmentation
-- View index fragmentation statistics
SELECT 
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    ips.index_type_desc AS IndexTypeDescription,
    ips.avg_fragmentation_in_percent AS FragmentationPercent,
    ips.page_count AS PageCount,
    ips.avg_page_space_used_in_percent AS PageDensity,
    CASE 
        WHEN ips.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
        WHEN ips.avg_fragmentation_in_percent > 5 THEN 'REORGANIZE'
        ELSE 'NONE'
    END AS RecommendedAction
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.page_count > 100
ORDER BY ips.avg_fragmentation_in_percent DESC;
-- Shows index fragmentation statistics
-- Recommends appropriate maintenance action
-- Helps optimize index performance

-- 23. Database Growth History
-- View database size growth over time
SELECT 
    DATEADD(HOUR, -DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), bs.backup_start_date) AS BackupDate,
    bs.database_name AS DatabaseName,
    bs.backup_size / 1024 / 1024 AS BackupSizeMB,
    bs.compressed_backup_size / 1024 / 1024 AS CompressedSizeMB,
    CASE bs.type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Log'
        ELSE bs.type
    END AS BackupType
FROM msdb.dbo.backupset bs
WHERE bs.database_name = DB_NAME()
AND bs.type = 'D' -- Full backups only
ORDER BY bs.backup_start_date;
-- Shows database size over time based on backup history
-- Helps track growth trends
-- Useful for capacity planning

-- 24. Unused Indexes
-- Find indexes that are not being used
SELECT 
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.is_primary_key AS IsPrimaryKey,
    i.is_unique AS IsUnique,
    ISNULL(ius.user_seeks, 0) AS UserSeeks,
    ISNULL(ius.user_scans, 0) AS UserScans,
    ISNULL(ius.user_lookups, 0) AS UserLookups,
    ISNULL(ius.user_updates, 0) AS UserUpdates,
    ISNULL(ius.last_user_seek, '1900-01-01') AS LastUserSeek,
    ISNULL(ius.last_user_scan, '1900-01-01') AS LastUserScan,
    ISNULL(ius.last_user_lookup, '1900-01-01') AS LastUserLookup,
    ISNULL(ius.last_user_update, '1900-01-01') AS LastUserUpdate,
    'DROP INDEX ' + i.name + ' ON ' + OBJECT_NAME(i.object_id) AS DropIndexStatement
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats ius ON i.object_id = ius.object_id AND i.index_id = ius.index_id AND ius.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
AND i.is_primary_key = 0
AND i.is_unique = 0
AND ISNULL(ius.user_seeks, 0) = 0
AND ISNULL(ius.user_scans, 0) = 0
AND ISNULL(ius.user_lookups, 0) = 0
AND i.name IS NOT NULL
ORDER BY ISNULL(ius.user_updates, 0) DESC;
-- Identifies indexes that are not being used for queries
-- Shows update cost for maintaining these indexes
-- Generates DROP INDEX statements for consideration
-- Helps reduce index maintenance overhead

-- 25. Schema Comparison
-- Compare schema between two databases
SELECT 
    'Current Database' AS Source,
    t.name AS TableName,
    c.name AS ColumnName,
    ty.name AS DataType,
    c.max_length AS MaxLength,
    c.precision AS Precision,
    c.scale AS Scale,
    c.is_nullable AS IsNullable
FROM sys.tables t
JOIN sys.columns c ON t.object_id = c.object_id
JOIN sys.types ty ON c.user_type_id = ty.user_type_id
WHERE t.is_ms_shipped = 0

UNION ALL

SELECT 
    'Reference Database' AS Source,
    t.name AS TableName,
    c.name AS ColumnName,
    ty.name AS DataType,
    c.max_length AS MaxLength,
    c.precision AS Precision,
    c.scale AS Scale,
    c.is_nullable AS IsNullable
FROM [ReferenceDB].sys.tables t
JOIN [ReferenceDB].sys.columns c ON t.object_id = c.object_id
JOIN [ReferenceDB].sys.types ty ON c.user_type_id = ty.user_type_id
WHERE t.is_ms_shipped = 0
ORDER BY TableName, ColumnName, Source;
-- Compares schema between current and reference database
-- Shows differences in table and column definitions
-- Helps identify schema drift between environments

-- 26. Execution Plan Cache Analysis
-- Analyze execution plan cache for optimization opportunities
WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'),
PlanMissingIndexes AS (
    SELECT 
        cp.usecounts AS ExecutionCount,
        cp.objtype AS ObjectType,
        qp.query_plan,
        qp.query_plan.value('(/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/MissingIndexes/MissingIndexGroup/@Impact)[1]', 'float') AS Impact,
        qp.query_plan.value('(/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/MissingIndexes/MissingIndexGroup/MissingIndex/@Database)[1]', 'nvarchar(128)') AS DatabaseName,
        qp.query_plan.value('(/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/MissingIndexes/MissingIndexGroup/MissingIndex/@Table)[1]', 'nvarchar(128)') AS TableName,
        qp.query_plan.value('(/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/MissingIndexes/MissingIndexGroup/MissingIndex/@Schema)[1]', 'nvarchar(128)') AS SchemaName,
        st.text AS SQLText
    FROM sys.dm_exec_cached_plans cp
    CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
    CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
    WHERE qp.query_plan.exist('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/MissingIndexes/MissingIndexGroup') = 1
)
SELECT TOP 20
    ExecutionCount,
    ObjectType,
    Impact,
    DatabaseName,
    SchemaName,
    TableName,
    SQLText,
    query_plan
FROM PlanMissingIndexes
ORDER BY Impact * ExecutionCount DESC;
-- Analyzes execution plan cache for missing index opportunities
-- Prioritizes by impact and execution count
-- Shows SQL text and full execution plan
-- Helps identify high-impact index improvements

-- 27. Database Permissions Hierarchy
-- View permissions hierarchy for database principals
WITH RoleMembers AS (
    -- Anchor: Database roles that don't belong to other roles
    SELECT 
        dp.principal_id,
        dp.name AS RoleName,
        dp.type_desc AS PrincipalType,
        0 AS NestLevel,
        CAST(dp.name AS NVARCHAR(MAX)) AS RoleHierarchy
    FROM sys.database_principals dp
    WHERE dp.type = 'R' -- Database role
    AND NOT EXISTS (
        SELECT 1 FROM sys.database_role_members rm
        WHERE rm.member_principal_id = dp.principal_id
    )
    
    UNION ALL
    
    -- Recursive: Roles that belong to other roles
    SELECT 
        dp.principal_id,
        dp.name AS RoleName,
        dp.type_desc AS PrincipalType,
        rm.NestLevel + 1,
        CAST(rm.RoleHierarchy + ' -> ' + dp.name AS NVARCHAR(MAX)) AS RoleHierarchy
    FROM sys.database_principals dp
    JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
    JOIN RoleMembers rm ON drm.role_principal_id = rm.principal_id
    WHERE dp.type = 'R' -- Database role
)
SELECT 
    u.name AS UserName,
    u.type_desc AS UserType,
    r.RoleName,
    r.NestLevel,
    r.RoleHierarchy
FROM sys.database_principals u
JOIN sys.database_role_members drm ON u.principal_id = drm.member_principal_id
JOIN RoleMembers r ON drm.role_principal_id = r.principal_id
WHERE u.type IN ('S', 'U', 'G') -- SQL users, Windows users, Windows groups
ORDER BY u.name, r.NestLevel;
-- Shows database role hierarchy
-- Maps users to their roles
-- Displays nested role relationships
-- Helps understand permission inheritance

-- 28. Temporal Table Information
-- View system-versioned temporal tables
SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    h.name AS HistoryTableName,
    c.name AS PeriodColumnStart,
    c2.name AS PeriodColumnEnd,
    t.temporal_type_desc AS TemporalType,
    CASE 
        WHEN t.history_retention_period IS NULL THEN 'INFINITE'
        ELSE CAST(t.history_retention_period AS VARCHAR) + ' ' + t.history_retention_period_unit_desc
    END AS RetentionPeriod
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.periods p ON t.object_id = p.object_id
JOIN sys.columns c ON p.start_column_id = c.column_id AND p.object_id = c.object_id
JOIN sys.columns c2 ON p.end_column_id = c2.column_id AND p.object_id = c2.object_id
LEFT JOIN sys.tables h ON t.history_table_id = h.object_id
WHERE t.temporal_type = 2 -- SYSTEM_VERSIONED_TEMPORAL_TABLE
ORDER BY s.name, t.name;
-- Lists all temporal tables in the database
-- Shows history table and period columns
-- Includes retention period settings
-- Helps understand temporal data architecture

-- 29. Extended Events Sessions
-- View active extended events sessions
SELECT 
    s.name AS SessionName,
    s.create_time AS CreatedTime,
    CASE s.start_time 
        WHEN NULL THEN 'Stopped' 
        ELSE 'Running' 
    END AS Status,
    t.target_name AS TargetName,
    t.execution_count AS ExecutionCount,
    CAST(t.execution_duration_ms / 1000.0 AS DECIMAL(10,2)) AS ExecutionDurationSec,
    CAST(t.target_data AS XML) AS TargetData
FROM sys.dm_xe_sessions s
JOIN sys.dm_xe_session_targets t ON s.address = t.event_session_address
ORDER BY s.name;
-- Lists active extended events sessions
-- Shows session status and targets
-- Includes execution statistics
-- Helps monitor and troubleshoot performance issues

-- 30. Database Mail Configuration
-- View Database Mail configuration
SELECT 
    a.name AS AccountName,
    a.description AS AccountDescription,
    a.email_address AS EmailAddress,
    a.display_name AS DisplayName,
    s.servername AS SMTPServer,
    s.port AS SMTPPort,
    CASE s.enable_ssl WHEN 1 THEN 'Yes' ELSE 'No' END AS SSLEnabled,
    p.name AS ProfileName,
    p.description AS ProfileDescription
FROM msdb.dbo.sysmail_account a
JOIN msdb.dbo.sysmail_server s ON a.account_id = s.account_id
JOIN msdb.dbo.sysmail_profileaccount pa ON a.account_id = pa.account_id
JOIN msdb.dbo.sysmail_profile p ON pa.profile_id = p.profile_id
ORDER BY p.name, a.name;
-- Shows Database Mail configuration
-- Lists mail accounts, profiles, and SMTP servers
-- Helps verify mail settings for notifications

-- 31. SQL Agent Jobs
-- View SQL Agent jobs and schedules
SELECT 
    j.name AS JobName,
    j.description AS JobDescription,
    CASE j.enabled WHEN 1 THEN 'Yes' ELSE 'No' END AS IsEnabled,
    c.name AS CategoryName,
    SUSER_SNAME(j.owner_sid) AS JobOwner,
    s.name AS ScheduleName,
    CASE s.enabled WHEN 1 THEN 'Yes' ELSE 'No' END AS ScheduleEnabled,
    CASE 
        WHEN s.freq_type = 1 THEN 'Once'
        WHEN s.freq_type = 4 THEN 'Daily'
        WHEN s.freq_type = 8 THEN 'Weekly'
        WHEN s.freq_type = 16 THEN 'Monthly'
        WHEN s.freq_type = 32 THEN 'Monthly relative'
        WHEN s.freq_type = 64 THEN 'When SQL Server Agent starts'
        WHEN s.freq_type = 128 THEN 'When computer is idle'
        ELSE 'Unknown'
    END AS Frequency,
    CASE WHEN s.freq_subday_type = 1 THEN 'At specified time'
         WHEN s.freq_subday_type = 2 THEN 'Seconds'
         WHEN s.freq_subday_type = 4 THEN 'Minutes'
         WHEN s.freq_subday_type = 8 THEN 'Hours'
         ELSE 'Unknown'
    END AS SubdayFrequency,
    CASE WHEN s.freq_subday_type = 1 THEN 'Once at ' + STUFF(STUFF(RIGHT('000000' + CAST(s.active_start_time AS VARCHAR), 6), 5, 0, ':'), 3, 0, ':')
         ELSE 'Every ' + CAST(s.freq_subday_interval AS VARCHAR) + ' ' + 
              CASE WHEN s.freq_subday_type = 2 THEN 'seconds'
                   WHEN s.freq_subday_type = 4 THEN 'minutes'
                   WHEN s.freq_subday_type = 8 THEN 'hours'
                   ELSE 'unknown'
              END
    END AS ScheduleDetails,
    STUFF(STUFF(RIGHT('000000' + CAST(s.active_start_time AS VARCHAR), 6), 5, 0, ':'), 3, 0, ':') AS StartTime,
    STUFF(STUFF(RIGHT('000000' + CAST(s.active_end_time AS VARCHAR), 6), 5, 0, ':'), 3, 0, ':') AS EndTime
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
LEFT JOIN msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
LEFT JOIN msdb.dbo.syscategories c ON j.category_id = c.category_id
ORDER BY j.name, s.name;
-- Lists SQL Agent jobs and their schedules
-- Shows job status, frequency, and timing details
-- Helps verify automation configuration

-- 32. Linked Servers
-- View linked server configuration
SELECT 
    s.name AS LinkedServerName,
    s.product AS Product,
    s.provider AS Provider,
    s.data_source AS DataSource,
    s.catalog AS Catalog,
    CASE s.is_linked WHEN 1 THEN 'Yes' ELSE 'No' END AS IsLinked,
    CASE s.is_remote_login_enabled WHEN 1 THEN 'Yes' ELSE 'No' END AS IsRemoteLoginEnabled,
    CASE s.is_rpc_out_enabled WHEN 1 THEN 'Yes' ELSE 'No' END AS IsRPCOutEnabled,
    CASE s.is_data_access_enabled WHEN 1 THEN 'Yes' ELSE 'No' END AS IsDataAccessEnabled,
    l.remote_name AS RemoteLogin,
    CASE l.uses_self_credential WHEN 1 THEN 'Yes' ELSE 'No' END AS UsesSelfCredential
FROM sys.servers s
LEFT JOIN sys.linked_logins l ON s.server_id = l.server_id
WHERE s.server_id <> 0 -- Exclude local server
ORDER BY s.name;
-- Lists linked server configuration
-- Shows connection and security settings
-- Helps verify distributed query capabilities

-- 33. Database Encryption
-- View Transparent Data Encryption (TDE) status
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    encryption_state_desc AS EncryptionState,
    key_algorithm AS KeyAlgorithm,
    key_length AS KeyLength,
    encryptor_type AS EncryptorType,
    percent_complete AS PercentComplete,
    encryption_scan_state_desc AS ScanState,
    encryption_scan_modify_date AS LastScanDate
FROM sys.dm_database_encryption_keys
ORDER BY DatabaseName;
-- Shows database encryption status
-- Includes encryption algorithm and progress
-- Helps verify security compliance

-- 34. Database Mirroring
-- View database mirroring status
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    mirroring_state_desc AS MirroringState,
    mirroring_role_desc AS MirroringRole,
    mirroring_safety_level_desc AS SafetyLevel,
    mirroring_partner_name AS PartnerServer,
    mirroring_partner_instance AS PartnerInstance,
    mirroring_witness_name AS WitnessServer,
    mirroring_witness_state_desc AS WitnessState,
    mirroring_connection_timeout AS ConnectionTimeout,
    mirroring_redo_queue AS RedoQueueSize,
    mirroring_redo_queue_type AS RedoQueueType
FROM sys.database_mirroring
WHERE mirroring_guid IS NOT NULL
ORDER BY DatabaseName;
-- Shows database mirroring configuration
-- Includes partner and witness information
-- Helps monitor high availability status

-- 35. Always On Availability Groups
-- View availability group status
SELECT 
    ag.name AS AvailabilityGroupName,
    ar.replica_server_name AS ReplicaServerName,
    ar.availability_mode_desc AS AvailabilityMode,
    ar.failover_mode_desc AS FailoverMode,
    ar.primary_role_allow_connections_desc AS PrimaryConnections,
    ar.secondary_role_allow_connections_desc AS SecondaryConnections,
    ars.role_desc AS CurrentRole,
    ars.operational_state_desc AS OperationalState,
    ars.connected_state_desc AS ConnectedState,
    ars.synchronization_health_desc AS SynchronizationHealth,
    ars.last_connect_error_description AS LastConnectionError
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
ORDER BY ag.name, ar.replica_server_name;
-- Shows Always On Availability Group configuration
-- Includes replica status and synchronization health
-- Helps monitor high availability environment

-- 36. Database Files IO Statistics
-- View IO statistics for database files
SELECT 
    DB_NAME(vfs.database_id) AS DatabaseName,
    mf.name AS FileName,
    mf.physical_name AS PhysicalName,
    mf.type_desc AS FileType,
    vfs.num_of_reads AS NumberOfReads,
    vfs.num_of_bytes_read / 1024 / 1024 AS MBRead,
    vfs.io_stall_read_ms AS ReadStallMs,
    CASE WHEN vfs.num_of_reads = 0 THEN 0 ELSE vfs.io_stall_read_ms / vfs.num_of_reads END AS AvgReadStallMs,
    vfs.num_of_writes AS NumberOfWrites,
    vfs.num_of_bytes_written / 1024 / 1024 AS MBWritten,
    vfs.io_stall_write_ms AS WriteStallMs,
    CASE WHEN vfs.num_of_writes = 0 THEN 0 ELSE vfs.io_stall_write_ms / vfs.num_of_writes END AS AvgWriteStallMs,
    vfs.io_stall AS TotalStallMs
FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
JOIN sys.master_files mf ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
ORDER BY vfs.io_stall DESC;
-- Shows IO statistics for all database files
-- Includes read/write counts and stall times
-- Helps identify IO bottlenecks

-- 37. Database Collation Information
-- View collation settings for databases and columns
SELECT 
    DB_NAME() AS DatabaseName,
    DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS DatabaseCollation,
    s.name AS SchemaName,
    t.name AS TableName,
    c.name AS ColumnName,
    ty.name AS DataType,
    c.collation_name AS ColumnCollation,
    CASE WHEN c.collation_name <> DATABASEPROPERTYEX(DB_NAME(), 'Collation') THEN 'Different' ELSE 'Same' END AS CollationStatus
FROM sys.columns c
JOIN sys.tables t ON c.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.types ty ON c.user_type_id = ty.user_type_id
WHERE c.collation_name IS NOT NULL
AND t.is_ms_shipped = 0
ORDER BY s.name, t.name, c.name;
-- Shows collation settings for database and columns
-- Identifies columns with non-default collations
-- Helps troubleshoot collation conflicts

-- 38. Database Compatibility Level
-- View compatibility level for all databases
SELECT 
    name AS DatabaseName,
    compatibility_level AS CompatibilityLevel,
    CASE compatibility_level
        WHEN 80 THEN 'SQL Server 2000'
        WHEN 90 THEN 'SQL Server 2005'
        WHEN 100 THEN 'SQL Server 2008/2008 R2'
        WHEN 110 THEN 'SQL Server 2012'
        WHEN 120 THEN 'SQL Server 2014'
        WHEN 130 THEN 'SQL Server 2016'
        WHEN 140 THEN 'SQL Server 2017'
        WHEN 150 THEN 'SQL Server 2019'
        WHEN 160 THEN 'SQL Server 2022'
        ELSE 'Unknown'
    END AS CompatibilityVersion,
    create_date AS CreatedDate,
    state_desc AS State,
    recovery_model_desc AS RecoveryModel
FROM sys.databases
ORDER BY name;
-- Shows compatibility level for all databases
-- Maps compatibility level to SQL Server version
-- Helps identify databases running in legacy compatibility mode

-- 39. Database Principal Permissions
-- View effective permissions for database principals
SELECT 
    dp.name AS PrincipalName,
    dp.type_desc AS PrincipalType,
    p.class_desc AS PermissionScope,
    OBJECT_NAME(p.major_id) AS ObjectName,
    p.permission_name AS Permission,
    p.state_desc AS PermissionState
FROM sys.database_permissions p
JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
WHERE dp.name NOT IN ('public', 'guest')
ORDER BY dp.name, p.class_desc, OBJECT_NAME(p.major_id), p.permission_name;
-- Shows effective permissions for database users and roles
-- Includes permission scope and state
-- Helps audit security configuration

-- 40. Database Snapshot Information
-- View database snapshots
SELECT 
    d.name AS SnapshotName,
    d.create_date AS CreatedDate,
    CASE WHEN d.source_database_id IS NOT NULL THEN DB_NAME(d.source_database_id) ELSE NULL END AS SourceDatabase,
    f.name AS FileName,
    f.physical_name AS PhysicalName,
    CAST(f.size * 8.0 / 1024 AS DECIMAL(10,2)) AS FileSizeMB,
    CAST(FILEPROPERTY(f.name, 'SpaceUsed') * 8.0 / 1024 AS DECIMAL(10,2)) AS UsedSpaceMB,
    CAST((f.size - FILEPROPERTY(f.name, 'SpaceUsed')) * 8.0 / 1024 AS DECIMAL(10,2)) AS FreeSpaceMB
FROM sys.databases d
JOIN sys.master_files f ON d.database_id = f.database_id
WHERE d.source_database_id IS NOT NULL
ORDER BY d.name, f.name;
-- Lists all database snapshots
-- Shows source database and file information
-- Includes space usage statistics
-- Helps monitor snapshot storage consumption