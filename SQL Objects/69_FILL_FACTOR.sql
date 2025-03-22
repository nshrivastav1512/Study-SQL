-- =============================================
-- FILL FACTOR Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Fill Factor, including:
- What fill factor is and how it affects performance
- How to set and modify fill factor
- Optimal fill factor settings for different workloads
- Monitoring and tuning fill factor
- Real-world scenarios and best practices
- Relationship with page splits and fragmentation
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: FILL FACTOR FUNDAMENTALS
-- =============================================

-- What is Fill Factor?
-- Fill factor is a setting that determines how full SQL Server makes each index page when an index is created or rebuilt
-- It is specified as a percentage value from 1 to 100
-- A lower fill factor leaves more free space on each page for future inserts

-- Default Fill Factor:
-- The server-wide default fill factor is 0 (equivalent to 100%)
-- This means pages are filled completely, with no free space reserved

-- How Fill Factor Works:
-- When fill factor is 100%: Each page is filled completely
-- When fill factor is 70%: Each page is filled to 70%, leaving 30% free space
-- Free space is only reserved during index creation or rebuilds
-- Over time, pages will fill up as new data is inserted

-- =============================================
-- PART 2: CONFIGURING FILL FACTOR
-- =============================================

-- 1. Setting server-wide default fill factor
-- This affects all new indexes created without an explicit fill factor

-- View current server-wide fill factor setting
SELECT name, value, value_in_use, description 
FROM sys.configurations 
WHERE name = 'fill factor (%)';

-- Change server-wide fill factor (requires server restart)
-- EXEC sp_configure 'show advanced options', 1;
-- RECONFIGURE;
-- EXEC sp_configure 'fill factor', 80;
-- RECONFIGURE;

-- 2. Setting fill factor for a specific index
-- Overrides the server-wide default

-- Create a new index with a specific fill factor
CREATE NONCLUSTERED INDEX IX_EMP_LastName 
ON HR.EMP_Details(LastName)
WITH (FILLFACTOR = 80);

-- Rebuild an existing index with a new fill factor
ALTER INDEX IX_EMP_LastName ON HR.EMP_Details 
REBUILD WITH (FILLFACTOR = 75);

-- 3. Setting fill factor for all indexes on a table

-- Rebuild all indexes on a table with the same fill factor
ALTER INDEX ALL ON HR.EMP_Details 
REBUILD WITH (FILLFACTOR = 80);

-- =============================================
-- PART 3: FILL FACTOR AND WORKLOAD TYPES
-- =============================================

-- 1. OLTP (Online Transaction Processing) Systems
-- Characterized by many small transactions, frequent inserts/updates

-- For heavily modified indexes in OLTP systems:
-- - Use lower fill factor (70-85%) to reduce page splits
-- - Example: Customer or Order tables with frequent inserts

CREATE NONCLUSTERED INDEX IX_Orders_OrderDate 
ON HR.Orders(OrderDate)
WITH (FILLFACTOR = 75);

-- 2. OLAP (Online Analytical Processing) Systems
-- Characterized by read-heavy workloads, infrequent data modifications

-- For read-only or rarely modified indexes:
-- - Use higher fill factor (90-100%) to maximize data density
-- - Example: Historical or archive tables

CREATE NONCLUSTERED INDEX IX_OrderHistory_OrderDate 
ON HR.OrderHistory(OrderDate)
WITH (FILLFACTOR = 100);

-- 3. Mixed Workload Systems
-- Balance between reads and writes

-- For balanced workloads:
-- - Use moderate fill factor (80-90%)
-- - Example: Tables used for both reporting and transactions

CREATE NONCLUSTERED INDEX IX_Products_ProductName 
ON HR.Products(ProductName)
WITH (FILLFACTOR = 85);

-- =============================================
-- PART 4: MONITORING PAGE SPLITS AND FRAGMENTATION
-- =============================================

-- 1. Monitoring page splits
-- Page splits occur when a page is full and new data needs to be inserted

-- Enable trace flag to capture page splits (server-wide setting)
-- DBCC TRACEON(1222, -1); -- Commented out as it affects server performance

-- Query to view page split information from system DMVs
SELECT 
    OBJECT_NAME(object_id) AS TableName,
    leaf_insert_count,
    leaf_delete_count,
    leaf_update_count,
    leaf_ghost_count,
    page_io_latch_wait_count
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL)
WHERE OBJECTPROPERTY(object_id, 'IsUserTable') = 1
ORDER BY leaf_insert_count + leaf_update_count DESC;

-- 2. Monitoring index fragmentation
-- Fragmentation increases as page splits occur

-- Query to check fragmentation levels
SELECT 
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    ips.index_type_desc,
    ips.avg_fragmentation_in_percent,
    ips.page_count,
    i.fill_factor
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON 
    ips.object_id = i.object_id AND 
    ips.index_id = i.index_id
WHERE ips.page_count > 100
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- 3. Correlation between fill factor and fragmentation

-- Create a table to track fragmentation over time
CREATE TABLE HR.IndexFragmentationHistory (
    CaptureDate DATETIME DEFAULT GETDATE(),
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    FillFactor TINYINT,
    FragmentationPct FLOAT,
    PageCount INT
);

-- Create a procedure to capture fragmentation metrics
CREATE OR ALTER PROCEDURE HR.CaptureFragmentationMetrics
AS
BEGIN
    INSERT INTO HR.IndexFragmentationHistory 
        (TableName, IndexName, FillFactor, FragmentationPct, PageCount)
    SELECT 
        OBJECT_NAME(ips.object_id) AS TableName,
        i.name AS IndexName,
        ISNULL(i.fill_factor, 0) AS FillFactor,
        ips.avg_fragmentation_in_percent,
        ips.page_count
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    JOIN sys.indexes i ON 
        ips.object_id = i.object_id AND 
        ips.index_id = i.index_id
    WHERE 
        ips.page_count > 100 AND
        OBJECTPROPERTY(ips.object_id, 'IsUserTable') = 1;
END;
GO

-- Execute the procedure (would typically be scheduled as a job)
EXEC HR.CaptureFragmentationMetrics;

-- =============================================
-- PART 5: OPTIMIZING FILL FACTOR
-- =============================================

-- 1. Determining optimal fill factor
-- The ideal fill factor depends on the specific workload and data patterns

-- Create a procedure to test different fill factors
CREATE OR ALTER PROCEDURE HR.TestFillFactors
    @TableName NVARCHAR(128),
    @IndexName NVARCHAR(128)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @CurrentFillFactor INT;
    
    -- Get current fill factor
    SELECT @CurrentFillFactor = ISNULL(fill_factor, 0)
    FROM sys.indexes
    WHERE 
        object_id = OBJECT_ID(@TableName) AND
        name = @IndexName;
    
    -- Store current fragmentation
    CREATE TABLE #BaselineFragmentation (
        FragmentationPct FLOAT,
        PageCount INT
    );
    
    INSERT INTO #BaselineFragmentation
    SELECT 
        ips.avg_fragmentation_in_percent,
        ips.page_count
    FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID(@TableName), NULL, NULL, 'LIMITED') ips
    JOIN sys.indexes i ON 
        ips.object_id = i.object_id AND 
        ips.index_id = i.index_id
    WHERE i.name = @IndexName;
    
    -- Log baseline
    PRINT 'Current Fill Factor: ' + CAST(@CurrentFillFactor AS NVARCHAR(10));
    PRINT 'Current Fragmentation: ' + 
          CAST((SELECT FragmentationPct FROM #BaselineFragmentation) AS NVARCHAR(10)) + '%';
    
    -- Clean up
    DROP TABLE #BaselineFragmentation;
    
    -- Note: In a real scenario, you would rebuild with different fill factors
    -- and measure performance under your workload
    PRINT 'To test different fill factors, rebuild the index with various settings';
    PRINT 'and monitor performance metrics and fragmentation levels.';
END;
GO

-- Example usage
-- EXEC HR.TestFillFactors 'HR.EMP_Details', 'IX_EMP_LastName';

-- 2. Automated fill factor adjustment

CREATE OR ALTER PROCEDURE HR.OptimizeFillFactors
AS
BEGIN
    DECLARE @TableName NVARCHAR(128);
    DECLARE @IndexName NVARCHAR(128);
    DECLARE @CurrentFillFactor INT;
    DECLARE @NewFillFactor INT;
    DECLARE @FragmentationPct FLOAT;
    DECLARE @SQL NVARCHAR(MAX);
    
    -- Create a temporary table to hold indexes to adjust
    CREATE TABLE #IndexesToAdjust (
        TableName NVARCHAR(128),
        IndexName NVARCHAR(128),
        CurrentFillFactor INT,
        NewFillFactor INT,
        FragmentationPct FLOAT
    );
    
    -- Find highly fragmented indexes with high fill factors
    INSERT INTO #IndexesToAdjust
    SELECT 
        OBJECT_NAME(ips.object_id) AS TableName,
        i.name AS IndexName,
        ISNULL(i.fill_factor, 0) AS CurrentFillFactor,
        CASE
            WHEN ISNULL(i.fill_factor, 0) IN (0, 100) THEN 90
            WHEN ISNULL(i.fill_factor, 0) > 90 THEN ISNULL(i.fill_factor, 0) - 10
            ELSE ISNULL(i.fill_factor, 0)
        END AS NewFillFactor,
        ips.avg_fragmentation_in_percent
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    JOIN sys.indexes i ON 
        ips.object_id = i.object_id AND 
        ips.index_id = i.index_id
    WHERE 
        ips.avg_fragmentation_in_percent > 30 AND
        ips.page_count > 100 AND
        OBJECTPROPERTY(ips.object_id, 'IsUserTable') = 1 AND
        (ISNULL(i.fill_factor, 0) = 0 OR ISNULL(i.fill_factor, 0) > 90);
    
    -- Find indexes with low fragmentation and low fill factors
    INSERT INTO #IndexesToAdjust
    SELECT 
        OBJECT_NAME(ips.object_id) AS TableName,
        i.name AS IndexName,
        ISNULL(i.fill_factor, 0) AS CurrentFillFactor,
        CASE
            WHEN ISNULL(i.fill_factor, 0) < 80 THEN ISNULL(i.fill_factor, 0) + 10
            ELSE ISNULL(i.fill_factor, 0)
        END AS NewFillFactor,
        ips.avg_fragmentation_in_percent
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    JOIN sys.indexes i ON 
        ips.object_id = i.object_id AND 
        ips.index_id = i.index_id
    WHERE 
        ips.avg_fragmentation_in_percent < 5 AND
        ips.page_count > 100 AND
        OBJECTPROPERTY(ips.object_id, 'IsUserTable') = 1 AND
        ISNULL(i.fill_factor, 0) BETWEEN 1 AND 80;
    
    -- Process each index
    DECLARE fill_factor_cursor CURSOR FOR
    SELECT TableName, IndexName, CurrentFillFactor, NewFillFactor, FragmentationPct 
    FROM #IndexesToAdjust;
    
    OPEN fill_factor_cursor;
    FETCH NEXT FROM fill_factor_cursor INTO @TableName, @IndexName, @CurrentFillFactor, @NewFillFactor, @FragmentationPct;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Log the change
        PRINT 'Adjusting ' + @TableName + '.' + @IndexName + 
              ' from fill factor ' + CAST(@CurrentFillFactor AS NVARCHAR(10)) + 
              ' to ' + CAST(@NewFillFactor AS NVARCHAR(10)) + 
              ' (Current fragmentation: ' + CAST(@FragmentationPct AS NVARCHAR(10)) + '%)';
        
        -- Build and execute the rebuild command
        SET @SQL = 'ALTER INDEX ' + QUOTENAME(@IndexName) + 
                   ' ON ' + QUOTENAME(@TableName) + 
                   ' REBUILD WITH (FILLFACTOR = ' + CAST(@NewFillFactor AS NVARCHAR(10)) + ')';
        
        -- In a real scenario, you would execute this SQL
        -- EXEC sp_executesql @SQL;
        PRINT @SQL; -- Just print for demonstration
        
        FETCH NEXT FROM fill_factor_cursor INTO @TableName, @IndexName, @CurrentFillFactor, @NewFillFactor, @FragmentationPct;
    END
    
    CLOSE fill_factor_cursor;
    DEALLOCATE fill_factor_cursor;
    
    DROP TABLE #IndexesToAdjust;
END;
GO

-- =============================================
-- PART