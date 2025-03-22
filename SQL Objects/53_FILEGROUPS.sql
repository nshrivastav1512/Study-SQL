-- =============================================
-- SQL Server FILEGROUPS Guide
-- =============================================

-- 1. Creating a Database with Multiple Filegroups
-- Note: This requires administrative permissions
-- First, create a database with a primary filegroup and a secondary filegroup
CREATE DATABASE FileGroupDemo
ON PRIMARY
(
    NAME = 'FileGroupDemo_Primary',
    FILENAME = 'C:\SQLData\FileGroupDemo_Primary.mdf',
    SIZE = 10MB,
    MAXSIZE = 100MB,
    FILEGROWTH = 5MB
),
FILEGROUP FG_Data
(
    NAME = 'FileGroupDemo_Data',
    FILENAME = 'C:\SQLData\FileGroupDemo_Data.ndf',
    SIZE = 10MB,
    MAXSIZE = 200MB,
    FILEGROWTH = 10MB
)
LOG ON
(
    NAME = 'FileGroupDemo_Log',
    FILENAME = 'C:\SQLData\FileGroupDemo_Log.ldf',
    SIZE = 5MB,
    MAXSIZE = 50MB,
    FILEGROWTH = 5MB
);
GO

-- Note: The above script is for demonstration. In a real environment,
-- you would use actual paths where you have permissions to create files.

-- 2. Adding a New Filegroup to an Existing Database
ALTER DATABASE FileGroupDemo
ADD FILEGROUP FG_Archive;
GO

-- 3. Adding a File to a Filegroup
ALTER DATABASE FileGroupDemo
ADD FILE
(
    NAME = 'FileGroupDemo_Archive',
    FILENAME = 'C:\SQLData\FileGroupDemo_Archive.ndf',
    SIZE = 10MB,
    MAXSIZE = 200MB,
    FILEGROWTH = 10MB
) TO FILEGROUP FG_Archive;
GO

-- 4. Setting the Default Filegroup
ALTER DATABASE FileGroupDemo
MODIFY FILEGROUP FG_Data DEFAULT;
GO

-- 5. Creating a Read-Only Filegroup
ALTER DATABASE FileGroupDemo
ADD FILEGROUP FG_ReadOnly;
GO

ALTER DATABASE FileGroupDemo
ADD FILE
(
    NAME = 'FileGroupDemo_ReadOnly',
    FILENAME = 'C:\SQLData\FileGroupDemo_ReadOnly.ndf',
    SIZE = 10MB,
    MAXSIZE = 100MB,
    FILEGROWTH = 5MB
) TO FILEGROUP FG_ReadOnly;
GO

-- Make the filegroup read-only
ALTER DATABASE FileGroupDemo
MODIFY FILEGROUP FG_ReadOnly READ_ONLY;
GO

-- 6. Creating Tables on Specific Filegroups
USE FileGroupDemo;
GO

-- Create a table on the default filegroup (FG_Data)
CREATE TABLE dbo.CurrentEmployees
(
    EmployeeID INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    HireDate DATE,
    Department NVARCHAR(50)
);
GO

-- Create a table on a specific filegroup
CREATE TABLE dbo.ArchivedEmployees
(
    EmployeeID INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    HireDate DATE,
    TerminationDate DATE,
    Department NVARCHAR(50)
) ON FG_Archive;
GO

-- 7. Creating Indexes on Specific Filegroups
-- Create a table with clustered index on one filegroup and nonclustered on another
CREATE TABLE dbo.Products
(
    ProductID INT PRIMARY KEY,
    ProductName NVARCHAR(100),
    CategoryID INT,
    UnitPrice MONEY,
    Discontinued BIT
) ON FG_Data;
GO

-- Create a nonclustered index on a different filegroup
CREATE NONCLUSTERED INDEX IX_Products_Category
ON dbo.Products(CategoryID)
INCLUDE (ProductName)
ON FG_Archive;
GO

-- 8. Partitioning with Filegroups
-- Create a partition function
CREATE PARTITION FUNCTION PF_EmployeesByYear(DATE)
AS RANGE RIGHT FOR VALUES ('2020-01-01', '2021-01-01', '2022-01-01', '2023-01-01');
GO

-- Create a partition scheme that uses different filegroups
CREATE PARTITION SCHEME PS_EmployeesByYear
AS PARTITION PF_EmployeesByYear
TO (FG_Archive, FG_Archive, FG_Data, FG_Data, PRIMARY);
GO

-- Create a partitioned table
CREATE TABLE dbo.EmployeeHistory
(
    HistoryID INT IDENTITY(1,1) NOT NULL,
    EmployeeID INT NOT NULL,
    ActionDate DATE NOT NULL,
    Action NVARCHAR(50),
    Details NVARCHAR(MAX),
    CONSTRAINT PK_EmployeeHistory PRIMARY KEY (HistoryID, ActionDate)
) ON PS_EmployeesByYear(ActionDate);
GO

-- 9. Moving Objects Between Filegroups
-- Create a clustered index on a table to move it to a different filegroup
-- First, drop the existing clustered index (primary key)
ALTER TABLE dbo.CurrentEmployees
DROP CONSTRAINT PK__CurrentE__7AD04FF1ABCDEF12; -- Your constraint name will be different
GO

-- Recreate the primary key on a different filegroup
ALTER TABLE dbo.CurrentEmployees
ADD CONSTRAINT PK_CurrentEmployees PRIMARY KEY (EmployeeID)
ON FG_Data;
GO

-- 10. Querying Filegroup Information
-- Get information about filegroups in the database
SELECT 
    fg.name AS FileGroupName,
    fg.type AS FileGroupType,
    fg.type_desc AS FileGroupTypeDesc,
    fg.is_read_only,
    fg.is_default
FROM sys.filegroups fg;
GO

-- Get information about database files and their filegroups
SELECT 
    f.name AS FileName,
    f.physical_name AS PhysicalName,
    fg.name AS FileGroupName,
    f.size / 128 AS FileSizeMB,
    f.max_size / 128 AS MaxSizeMB,
    f.growth / 128 AS GrowthMB,
    f.is_percent_growth
FROM sys.database_files f
LEFT JOIN sys.filegroups fg ON f.data_space_id = fg.data_space_id;
GO

-- Find which objects are stored in which filegroups
SELECT 
    OBJECT_SCHEMA_NAME(t.object_id) + '.' + t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    fg.name AS FileGroupName
FROM sys.tables t
JOIN sys.indexes i ON t.object_id = i.object_id
JOIN sys.filegroups fg ON i.data_space_id = fg.data_space_id
ORDER BY TableName, IndexName;
GO

-- 11. Filegroup Maintenance
-- Check filegroup space usage
SELECT 
    fg.name AS FileGroupName,
    SUM(f.size) / 128 AS TotalSizeMB,
    SUM(FILEPROPERTY(f.name, 'SpaceUsed')) / 128 AS UsedSpaceMB,
    (SUM(f.size) - SUM(FILEPROPERTY(f.name, 'SpaceUsed'))) / 128 AS FreeSpaceMB
FROM sys.filegroups fg
JOIN sys.database_files f ON fg.data_space_id = f.data_space_id
GROUP BY fg.name;
GO

-- 12. Removing a File from a Filegroup
-- First, empty the file (move data to other files in the same filegroup)
DBCC SHRINKFILE (FileGroupDemo_Archive, EMPTYFILE);
GO

-- Remove the file from the database
ALTER DATABASE FileGroupDemo
REMOVE FILE FileGroupDemo_Archive;
GO

-- 13. Removing a Filegroup
-- First, ensure the filegroup is empty (no files)
-- Then remove the filegroup
ALTER DATABASE FileGroupDemo
REMOVE FILEGROUP FG_Archive;
GO

-- 14. Filegroup Best Practices
-- Example of organizing data by access pattern
-- Create a filegroup for frequently accessed data
ALTER DATABASE FileGroupDemo
ADD FILEGROUP FG_HotData;
GO

ALTER DATABASE FileGroupDemo
ADD FILE
(
    NAME = 'FileGroupDemo_HotData',
    FILENAME = 'C:\SQLData\FileGroupDemo_HotData.ndf',
    SIZE = 10MB,
    MAXSIZE = 100MB,
    FILEGROWTH = 5MB
) TO FILEGROUP FG_HotData;
GO

-- Create a table for frequently accessed data
CREATE TABLE dbo.ActiveOrders
(
    OrderID INT PRIMARY KEY,
    CustomerID INT,
    OrderDate DATETIME,
    TotalAmount MONEY,
    Status NVARCHAR(20)
) ON FG_HotData;
GO

-- 15. Filegroup Backup and Restore
-- Backup a specific filegroup
-- Note: This requires administrative permissions
BACKUP DATABASE FileGroupDemo
FILEGROUP = 'FG_Data'
TO DISK = 'C:\SQLBackups\FileGroupDemo_FG_Data.bak';
GO

-- 16. Cleanup
-- Note: This script is for demonstration purposes only.
-- In a real environment, you would need to ensure no connections
-- are active before dropping a database.

-- Drop the database
USE master;
GO

DROP DATABASE IF EXISTS FileGroupDemo;
GO