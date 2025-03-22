-- =============================================
-- SQL Server INDEXES Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating a Clustered Index
-- Note: Only one clustered index can exist per table
-- Primary keys automatically create clustered indexes unless specified otherwise
CREATE TABLE ProjectTeam (
    TeamID INT IDENTITY(1,1),
    TeamName VARCHAR(50) NOT NULL,
    DepartmentID INT,
    TeamLead INT,
    FormationDate DATE DEFAULT GETDATE()
);
GO

-- Create a clustered index on TeamID
CREATE CLUSTERED INDEX CIX_ProjectTeam_TeamID ON ProjectTeam(TeamID);
GO

-- 2. Creating a Non-Clustered Index
-- Can have multiple non-clustered indexes per table
CREATE NONCLUSTERED INDEX IX_ProjectTeam_TeamName ON ProjectTeam(TeamName);
GO

-- 3. Creating a Unique Index
CREATE UNIQUE INDEX UIX_ProjectTeam_TeamName ON ProjectTeam(TeamName);
GO

-- 4. Creating a Composite Index (Multiple Columns)
CREATE NONCLUSTERED INDEX IX_Projects_StatusStartDate ON Projects(Status, StartDate);
GO

-- 5. Creating an Index with Included Columns
-- Adds non-key columns to the leaf level of the index
CREATE NONCLUSTERED INDEX IX_Projects_Name_IncludeBudget 
    ON Projects(ProjectName) 
    INCLUDE (Budget, Status);
GO

-- 6. Creating a Filtered Index
-- Index only a subset of rows in a table
CREATE NONCLUSTERED INDEX IX_Projects_HighBudget 
    ON Projects(ProjectName, Budget) 
    WHERE Budget > 100000;
GO

-- 7. Creating a Columnstore Index
-- Optimized for analytical queries and data warehousing
CREATE TABLE ProjectAnalytics (
    AnalyticsID INT IDENTITY(1,1),
    ProjectID INT,
    MetricDate DATE,
    MetricType VARCHAR(50),
    MetricValue DECIMAL(18,2)
);
GO

CREATE CLUSTERED COLUMNSTORE INDEX CCI_ProjectAnalytics 
    ON ProjectAnalytics;
GO

-- 8. Creating a Non-Clustered Columnstore Index
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_Projects_Budget_Dates 
    ON Projects(Budget, StartDate, EndDate);
GO

-- 9. Creating a Spatial Index
-- For geographic or geometric data
CREATE TABLE ProjectLocations (
    LocationID INT IDENTITY(1,1) PRIMARY KEY,
    ProjectID INT,
    LocationName VARCHAR(100),
    GeoLocation GEOGRAPHY
);
GO

CREATE SPATIAL INDEX SIX_ProjectLocations_GeoLocation 
    ON ProjectLocations(GeoLocation) 
    USING GEOGRAPHY_GRID;
GO

-- 10. Creating a Full-Text Index
-- For searching text data efficiently
CREATE TABLE ProjectDocumentation (
    DocID INT IDENTITY(1,1) PRIMARY KEY,
    ProjectID INT,
    Title VARCHAR(100),
    DocumentContent VARCHAR(MAX)
);
GO

-- Create a full-text catalog first
CREATE FULLTEXT CATALOG ProjectFTCatalog AS DEFAULT;
GO

-- Create a full-text index
CREATE FULLTEXT INDEX ON ProjectDocumentation(DocumentContent) 
    KEY INDEX PK__ProjectD__3E3D09C6ABCDEF12 
    WITH STOPLIST = SYSTEM;
GO

-- 11. Creating an XML Index
CREATE TABLE ProjectXMLData (
    XMLID INT IDENTITY(1,1) PRIMARY KEY,
    ProjectID INT,
    XMLData XML
);
GO

-- Primary XML index
CREATE PRIMARY XML INDEX PIX_ProjectXMLData_XMLData 
    ON ProjectXMLData(XMLData);
GO

-- Secondary XML index - PATH type
CREATE XML INDEX SIX_ProjectXMLData_XMLData_Path 
    ON ProjectXMLData(XMLData) 
    USING XML INDEX PIX_ProjectXMLData_XMLData 
    FOR PATH;
GO

-- 12. Creating an Index with Fill Factor
-- Controls how full SQL Server will make each index page
CREATE NONCLUSTERED INDEX IX_ProjectAssignments_ProjectID 
    ON ProjectAssignments(ProjectID) 
    WITH (FILLFACTOR = 80);
GO

-- 13. Creating an Index with Data Compression
CREATE NONCLUSTERED INDEX IX_ProjectMilestones_ProjectID 
    ON ProjectMilestones(ProjectID) 
    WITH (DATA_COMPRESSION = PAGE);
GO

-- 14. Creating an Index on Computed Column
ALTER TABLE Projects ADD 
    ProjectDurationDays AS DATEDIFF(DAY, StartDate, EndDate);
GO

CREATE NONCLUSTERED INDEX IX_Projects_Duration 
    ON Projects(ProjectDurationDays);
GO

-- 15. Altering an Index
-- Disable an index
ALTER INDEX IX_Projects_Name_IncludeBudget ON Projects DISABLE;
GO

-- Rebuild an index
ALTER INDEX IX_Projects_Name_IncludeBudget ON Projects REBUILD;
GO

-- Rebuild all indexes on a table
ALTER INDEX ALL ON Projects REBUILD;
GO

-- Reorganize an index
ALTER INDEX IX_Projects_Name_IncludeBudget ON Projects REORGANIZE;
GO

-- 16. Dropping an Index
DROP INDEX IX_Projects_HighBudget ON Projects;
GO

-- 17. Creating an Index with ONLINE option
-- Allows concurrent DML operations during index creation
CREATE NONCLUSTERED INDEX IX_Projects_EndDate 
    ON Projects(EndDate) 
    WITH (ONLINE = ON);
GO

-- 18. Creating an Index with Sort in Tempdb
-- Uses tempdb for sorting during index creation
CREATE NONCLUSTERED INDEX IX_Projects_Description 
    ON Projects(Description) 
    WITH (SORT_IN_TEMPDB = ON);
GO

-- 19. Creating an Index with Specific Options
CREATE NONCLUSTERED INDEX IX_Projects_Combined 
    ON Projects(Status, Budget, StartDate) 
    INCLUDE (ProjectName, EndDate) 
    WHERE Status = 'In Progress' 
    WITH (
        PAD_INDEX = ON,
        FILLFACTOR = 90,
        SORT_IN_TEMPDB = ON,
        STATISTICS_NORECOMPUTE = OFF,
        DROP_EXISTING = ON,
        ONLINE = ON,
        ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON,
        DATA_COMPRESSION = ROW
    );
GO

-- 20. Viewing Index Information
-- Get all indexes for a table
SELECT 
    i.name AS IndexName,
    i.type_desc AS IndexType,
    OBJECT_NAME(i.object_id) AS TableName,
    COL_NAME(ic.object_id, ic.column_id) AS ColumnName,
    ic.is_included_column,
    i.is_unique,
    i.is_primary_key,
    i.is_unique_constraint
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
WHERE OBJECT_NAME(i.object_id) = 'Projects'
ORDER BY i.name, ic.key_ordinal;
GO

-- Get index usage statistics
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
WHERE OBJECT_NAME(i.object_id) = 'Projects';
GO

-- Get index physical statistics
SELECT 
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    ips.index_type_desc,
    ips.avg_fragmentation_in_percent,
    ips.page_count,
    ips.record_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'DETAILED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE OBJECT_NAME(ips.object_id) = 'Projects';
GO