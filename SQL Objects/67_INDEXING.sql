-- =============================================
-- INDEXING Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Indexing, including:
- What indexes are and how they improve performance
- Types of indexes (Clustered, Nonclustered, Columnstore, etc.)
- Index design strategies and best practices
- Index maintenance and monitoring
- Special index features (filtered, included columns, etc.)
- Real-world scenarios and optimization techniques
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: INDEX FUNDAMENTALS
-- =============================================

-- What are Indexes?
-- Indexes are database objects that improve the speed of data retrieval operations
-- They work similar to a book's index, providing quick lookup of data based on the indexed columns

-- Benefits of Indexes:
-- 1. Faster data retrieval for SELECT queries
-- 2. Improved performance for JOIN operations
-- 3. Efficient enforcement of uniqueness constraints
-- 4. Support for ORDER BY and GROUP BY operations without sorting

-- Costs of Indexes:
-- 1. Additional disk space
-- 2. Overhead on INSERT, UPDATE, and DELETE operations
-- 3. Maintenance requirements

-- =============================================
-- PART 2: TYPES OF INDEXES
-- =============================================

-- 1. Clustered Indexes
-- Determines the physical order of data in a table
-- Only one clustered index per table

-- Create a clustered index
CREATE CLUSTERED INDEX CIX_EMP_EmployeeID ON HR.EMP_Details(EmployeeID);

-- Alternatively, create with a PRIMARY KEY constraint (creates clustered index by default)
ALTER TABLE HR.EMP_Details ADD CONSTRAINT PK_EMP_EmployeeID 
    PRIMARY KEY CLUSTERED (EmployeeID);

-- 2. Nonclustered Indexes
-- Separate structure that contains the index key and a pointer to the data
-- Up to 999 nonclustered indexes per table

-- Create a nonclustered index
CREATE NONCLUSTERED INDEX IX_EMP_LastName ON HR.EMP_Details(LastName);

-- Create a nonclustered index with multiple columns (composite index)
CREATE NONCLUSTERED INDEX IX_EMP_Dept_HireDate ON HR.EMP_Details(DepartmentID, HireDate);

-- 3. Unique Indexes
-- Ensures uniqueness of the key values

-- Create a unique nonclustered index
CREATE UNIQUE NONCLUSTERED INDEX UX_EMP_Email ON HR.EMP_Details(Email);

-- 4. Columnstore Indexes
-- Stores data in a column-based format, optimized for analytical queries
-- Introduced in SQL Server 2012, enhanced in later versions

-- Create a clustered columnstore index
CREATE CLUSTERED COLUMNSTORE INDEX CCI_OrderHistory ON HR.OrderHistory;

-- Create a nonclustered columnstore index
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_EMP_Dept_Salary_HireDate 
ON HR.EMP_Details(DepartmentID, Salary, HireDate);

-- 5. Spatial Indexes
-- Optimizes queries against spatial data types (geometry, geography)

-- Create a spatial index
CREATE SPATIAL INDEX SIndx_Locations_Geo 
ON HR.Locations(LocationGeo)
USING GEOGRAPHY_GRID
WITH (
    GRIDS = (LEVEL_1 = MEDIUM, LEVEL_2 = MEDIUM, LEVEL_3 = MEDIUM, LEVEL_4 = MEDIUM),
    CELLS_PER_OBJECT = 16
);

-- 6. XML Indexes
-- Improves performance of queries against XML data

-- Create a primary XML index
CREATE PRIMARY XML INDEX PX_Employee_Resume 
ON HR.EMP_Details(Resume);

-- Create a secondary XML index
CREATE XML INDEX SX_Employee_Resume_Path 
ON HR.EMP_Details(Resume)
USING XML INDEX PX_Employee_Resume FOR PATH;

-- 7. Full-Text Indexes
-- Enables efficient text-based searches

-- Create a full-text catalog
CREATE FULLTEXT CATALOG HR_FTCatalog AS DEFAULT;

-- Create a full-text index
CREATE FULLTEXT INDEX ON HR.JobPostings(Description) 
KEY INDEX PK_JobPostings_ID 
WITH STOPLIST = SYSTEM;

-- =============================================
-- PART 3: ADVANCED INDEX FEATURES
-- =============================================

-- 1. Included Columns
-- Adds non-key columns to the leaf level of the index
-- Enables covering queries without adding columns to the key

-- Create an index with included columns
CREATE NONCLUSTERED INDEX IX_EMP_Dept_Include 
ON HR.EMP_Details(DepartmentID)
INCLUDE (FirstName, LastName, Salary);

-- 2. Filtered Indexes
-- Index on a subset of rows, reducing index size and maintenance overhead

-- Create a filtered index
CREATE NONCLUSTERED INDEX IX_EMP_HighSalary 
ON HR.EMP_Details(EmployeeID, Salary)
WHERE Salary > 50000;

-- 3. Computed Column Indexes
-- Index on a computed column

-- First, add a computed column
ALTER TABLE HR.EMP_Details ADD FullName AS (FirstName + ' ' + LastName) PERSISTED;

-- Then create an index on the computed column
CREATE NONCLUSTERED INDEX IX_EMP_FullName 
ON HR.EMP_Details(FullName);

-- 4. Index with specific fill factor
-- Controls how full each index page is built

CREATE NONCLUSTERED INDEX IX_EMP_JobTitle 
ON HR.EMP_Details(JobTitle)
WITH (FILLFACTOR = 80);

-- 5. Indexes with specific sort order
-- Control ascending or descending order

CREATE NONCLUSTERED INDEX IX_EMP_Salary_Desc 
ON HR.EMP_Details(Salary DESC);

-- =============================================
-- PART 4: INDEX DESIGN STRATEGIES
-- =============================================

-- 1. Choosing the right columns to index

-- Good candidates for indexes:
-- - Columns used in WHERE clauses
-- - Columns used in JOIN conditions
-- - Columns used in ORDER BY or GROUP BY
-- - Columns with high selectivity (many unique values)

-- Poor candidates for indexes:
-- - Columns rarely used in queries
-- - Columns with low selectivity (few unique values)
-- - Small tables that fit in a single page
-- - Columns frequently updated

-- 2. Composite index design

-- Consider column order in composite indexes
-- Most selective column first for equality searches
-- Order by query pattern for range searches

CREATE NONCLUSTERED INDEX IX_EMP_Dept_JobTitle_Salary 
ON HR.EMP_Details(DepartmentID, JobTitle, Salary);

-- 3. Covering indexes for frequently used queries

-- Identify frequently used queries
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    e.Salary
FROM HR.EMP_Details e
WHERE e.DepartmentID = 3
ORDER BY e.LastName;

-- Create a covering index for this query
CREATE NONCLUSTERED INDEX IX_EMP_Dept_LastName_Cover 
ON HR.EMP_Details(DepartmentID, LastName)
INCLUDE (EmployeeID, FirstName, Salary);

-- 4. Balancing read vs. write performance

-- For OLTP systems (high write workload):
-- - Fewer, more selective indexes
-- - Consider filtered indexes for frequently queried subsets

-- For OLAP/reporting systems (high read workload):
-- - More covering indexes
-- - Consider columnstore indexes

-- =============================================
-- PART 5: INDEX USAGE AND MONITORING
-- =============================================

-- 1. Identifying missing indexes

-- Query the missing index DMVs
SELECT 
    DB_NAME(mid.database_id) AS DatabaseName,
    OBJECT_NAME(mid.object_id) AS TableName,
    migs.avg_user_impact, 
    migs.user_seeks,
    migs.user_scans,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns
FROM sys.dm_db_missing_index_details mid
JOIN sys.dm_db_missing_index_groups mig ON mid.index_handle = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
WHERE mid.database_id = DB_ID()
ORDER BY migs.avg_user_impact * migs.user_seeks DESC;

-- 2. Identifying unused indexes

-- Query for unused indexes
SELECT 
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    ius.user_seeks,
    ius.user_scans,
    ius.user_lookups,
    ius.user_updates,
    ius.last_user_seek,
    ius.last_user_scan
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats ius ON 
    i.object_id = ius.object_id AND 
    i.index_id = ius.index_id AND 
    ius.database_id = DB_ID()
WHERE 
    OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1 AND
    i.type_desc <> 'HEAP'
ORDER BY ius.user_seeks + ius.user_scans + ius.user_lookups ASC;

-- 3. Identifying index fragmentation

-- Query for index fragmentation
SELECT 
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    ips.index_type_desc,
    ips.avg_fragmentation_in_percent,
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON 
    ips.object_id = i.object_id AND 
    ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- 4. Monitoring index usage over time

-- Create a table to store index usage metrics
CREATE TABLE HR.IndexUsageStats (
    CaptureDate DATETIME DEFAULT GETDATE(),
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    UserSeeks BIGINT,
    UserScans BIGINT,
    UserLookups BIGINT,
    UserUpdates BIGINT
);

-- Create a procedure to capture index usage
CREATE OR ALTER PROCEDURE HR.CaptureIndexUsage
AS
BEGIN
    INSERT INTO HR.IndexUsageStats (TableName, IndexName, UserSeeks, UserScans, UserLookups, UserUpdates)
    SELECT 
        OBJECT_NAME(i.object_id) AS TableName,
        i.name AS IndexName,
        ius.user_seeks,
        ius.user_scans,
        ius.user_lookups,
        ius.user_updates
    FROM sys.indexes i
    LEFT JOIN sys.dm_db_index_usage_stats ius ON 
        i.object_id = ius.object_id AND 
        i.index_id = ius.index_id AND 
        ius.database_id = DB_ID()
    WHERE 
        OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1 AND
        i.type_desc <> 'HEAP';
END;
GO

-- Execute the procedure (would typically be scheduled as a job)
EXEC HR.CaptureIndexUsage;

-- =============================================
-- PART 6: INDEX MAINTENANCE
-- =============================================

-- 1. Rebuilding indexes
-- Completely recreates the index with a new fill factor

-- Rebuild a single index
ALTER INDEX IX_EMP_LastName ON HR.EMP_Details REBUILD WITH (FILLFACTOR = 80);

-- Rebuild all indexes on a table
ALTER INDEX ALL ON HR.EMP_Details REBUILD WITH (FILLFACTOR = 80);

-- 2. Reorganizing indexes
-- Defragments the leaf level of the index by physically reordering pages

-- Reorganize a single index
ALTER INDEX IX_EMP_LastName ON HR.EMP_Details REORGANIZE;

-- 3. Updating statistics
-- Updates the statistics used by the query optimizer

-- Update statistics for an index
UPDATE STATISTICS HR.EMP_Details IX_EMP_LastName WITH FULLSCAN;

-- 4. Automated index maintenance

-- Create a procedure for automated index maintenance
CREATE OR ALTER PROCEDURE HR.MaintainIndexes
AS
BEGIN
    DECLARE @TableName NVARCHAR(128);
    DECLARE @IndexName NVARCHAR(128);
    DECLARE @Fragmentation FLOAT;
    
    -- Create a temporary table to hold fragmentation info
    CREATE TABLE #FragmentedIndexes (
        TableName NVARCHAR(128),
        IndexName NVARCHAR(128),
        Fragmentation FLOAT
    );
    
    -- Get fragmentation information
    INSERT INTO #FragmentedIndexes
    SELECT 
        OBJECT_NAME(ips.object_id),
        i.name,
        ips.avg_fragmentation_in_percent
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    JOIN sys.indexes i ON 
        ips.object_id = i.object_id AND 
        ips.index_id = i.index_id
    WHERE 
        ips.avg_fragmentation_in_percent > 5 AND
        ips.page_count > 100;
    
    -- Process each fragmented index
    DECLARE fragmented_cursor CURSOR FOR
    SELECT TableName, IndexName, Fragmentation FROM #FragmentedIndexes;
    
    OPEN fragmented_cursor;