-- =============================================
-- PARTITIONING Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Partitioning, including:
- What partitioning is and its benefits
- How to implement table and index partitioning
- Partition switching and sliding window scenarios
- Partition-aligned indexes
- Query optimization with partitioned tables
- Maintenance strategies for partitioned tables
- Real-world scenarios and best practices
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: PARTITIONING FUNDAMENTALS
-- =============================================

-- What is Partitioning?
-- Partitioning divides large tables or indexes into smaller, more manageable pieces
-- Each partition can be managed independently while still being part of a single logical table

-- Benefits of Partitioning:
-- 1. Improved query performance through partition elimination
-- 2. Faster data loading and archiving operations
-- 3. More efficient index maintenance
-- 4. Better scalability for very large tables
-- 5. Improved availability (operations can target specific partitions)

-- Components of Partitioning:
-- 1. Partition Function: Defines how data is divided
-- 2. Partition Scheme: Maps partitions to filegroups
-- 3. Partitioned Table/Index: Uses the partition scheme

-- =============================================
-- PART 2: SETTING UP PARTITIONING
-- =============================================

-- 1. Create Filegroups (Optional but recommended for performance)
-- Filegroups allow you to store partitions on different physical drives

-- Create filegroups for partitions
ALTER DATABASE HRSystem ADD FILEGROUP FG_Archive;
ALTER DATABASE HRSystem ADD FILEGROUP FG_Historical;
ALTER DATABASE HRSystem ADD FILEGROUP FG_Current;
ALTER DATABASE HRSystem ADD FILEGROUP FG_Future;

-- Add files to filegroups
ALTER DATABASE HRSystem ADD FILE (
    NAME = 'HRSystem_Archive',
    FILENAME = 'C:\SQLData\HRSystem_Archive.ndf',
    SIZE = 100MB,
    FILEGROWTH = 50MB
) TO FILEGROUP FG_Archive;

ALTER DATABASE HRSystem ADD FILE (
    NAME = 'HRSystem_Historical',
    FILENAME = 'C:\SQLData\HRSystem_Historical.ndf',
    SIZE = 100MB,
    FILEGROWTH = 50MB
) TO FILEGROUP FG_Historical;

ALTER DATABASE HRSystem ADD FILE (
    NAME = 'HRSystem_Current',
    FILENAME = 'C:\SQLData\HRSystem_Current.ndf',
    SIZE = 100MB,
    FILEGROWTH = 50MB
) TO FILEGROUP FG_Current;

ALTER DATABASE HRSystem ADD FILE (
    NAME = 'HRSystem_Future',
    FILENAME = 'C:\SQLData\HRSystem_Future.ndf',
    SIZE = 100MB,
    FILEGROWTH = 50MB
) TO FILEGROUP FG_Future;

-- 2. Create a Partition Function
-- Defines the boundaries for partitioning

-- Create a partition function by year
CREATE PARTITION FUNCTION PF_OrderDate_Yearly(DATE)
AS RANGE RIGHT FOR VALUES (
    '2020-01-01', -- Partition 1: < 2020-01-01 (Archive)
    '2021-01-01', -- Partition 2: >= 2020-01-01 AND < 2021-01-01 (Historical)
    '2022-01-01', -- Partition 3: >= 2021-01-01 AND < 2022-01-01 (Historical)
    '2023-01-01'  -- Partition 4: >= 2022-01-01 AND < 2023-01-01 (Current)
                  -- Partition 5: >= 2023-01-01 (Future)
);

-- Create a partition function by quarter
CREATE PARTITION FUNCTION PF_OrderDate_Quarterly(DATE)
AS RANGE RIGHT FOR VALUES (
    '2022-01-01', '2022-04-01', '2022-07-01', '2022-10-01',
    '2023-01-01', '2023-04-01', '2023-07-01', '2023-10-01'
);

-- 3. Create a Partition Scheme
-- Maps partitions to filegroups

-- Create a partition scheme for yearly partitioning
CREATE PARTITION SCHEME PS_OrderDate_Yearly
AS PARTITION PF_OrderDate_Yearly
TO (
    FG_Archive,     -- Partition 1: < 2020-01-01
    FG_Historical,   -- Partition 2: >= 2020-01-01 AND < 2021-01-01
    FG_Historical,   -- Partition 3: >= 2021-01-01 AND < 2022-01-01
    FG_Current,      -- Partition 4: >= 2022-01-01 AND < 2023-01-01
    FG_Future        -- Partition 5: >= 2023-01-01
);

-- Create a partition scheme for quarterly partitioning
CREATE PARTITION SCHEME PS_OrderDate_Quarterly
AS PARTITION PF_OrderDate_Quarterly
TO (PRIMARY, PRIMARY, PRIMARY, PRIMARY, PRIMARY, PRIMARY, PRIMARY, PRIMARY, PRIMARY);

-- =============================================
-- PART 3: CREATING PARTITIONED TABLES
-- =============================================

-- 1. Create a new partitioned table

CREATE TABLE HR.OrdersPartitioned (
    OrderID INT NOT NULL,
    CustomerID INT NOT NULL,
    EmployeeID INT NOT NULL,
    OrderDate DATE NOT NULL,
    ShipDate DATE NULL,
    Amount DECIMAL(12,2) NOT NULL,
    Status NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_OrdersPartitioned PRIMARY KEY CLUSTERED (OrderDate, OrderID)
) ON PS_OrderDate_Yearly(OrderDate);

-- 2. Convert an existing table to a partitioned table

-- First, create a staging table with the desired partitioning
CREATE TABLE HR.Orders_Staged (
    OrderID INT NOT NULL,
    CustomerID INT NOT NULL,
    EmployeeID INT NOT NULL,
    OrderDate DATE NOT NULL,
    ShipDate DATE NULL,
    Amount DECIMAL(12,2) NOT NULL,
    Status NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_Orders_Staged PRIMARY KEY CLUSTERED (OrderDate, OrderID)
) ON PS_OrderDate_Yearly(OrderDate);

-- Then, insert data from the original table
INSERT INTO HR.Orders_Staged
SELECT * FROM HR.Orders;

-- Finally, rename tables to complete the switch
EXEC sp_rename 'HR.Orders', 'Orders_Old';
EXEC sp_rename 'HR.Orders_Staged', 'Orders';

-- 3. Create partitioned indexes

-- Create a partitioned nonclustered index
CREATE NONCLUSTERED INDEX IX_Orders_EmployeeID 
ON HR.OrdersPartitioned(EmployeeID, OrderDate)
ON PS_OrderDate_Yearly(OrderDate);

-- Create a non-aligned index (not recommended for most scenarios)
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID 
ON HR.OrdersPartitioned(CustomerID);

-- =============================================
-- PART 4: PARTITION MANAGEMENT
-- =============================================

-- 1. Adding a new partition (extending the range)

-- Alter the partition function to add a new boundary point
ALTER PARTITION FUNCTION PF_OrderDate_Yearly() 
SPLIT RANGE ('2024-01-01');

-- If using a partition scheme with specific filegroups, specify the new filegroup
ALTER PARTITION SCHEME PS_OrderDate_Yearly
NEXT USED FG_Future;

-- 2. Removing an old partition (merging ranges)

-- Merge the oldest partition with the next one
ALTER PARTITION FUNCTION PF_OrderDate_Yearly() 
MERGE RANGE ('2020-01-01');

-- 3. Partition switching (fast data loading and archiving)

-- Create a staging table with identical structure to the target partition
CREATE TABLE HR.Orders_2023Q1 (
    OrderID INT NOT NULL,
    CustomerID INT NOT NULL,
    EmployeeID INT NOT NULL,
    OrderDate DATE NOT NULL,
    ShipDate DATE NULL,
    Amount DECIMAL(12,2) NOT NULL,
    Status NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_Orders_2023Q1 PRIMARY KEY CLUSTERED (OrderDate, OrderID)
);

-- Load data into the staging table
INSERT INTO HR.Orders_2023Q1
SELECT * FROM HR.ExternalOrders
WHERE OrderDate >= '2023-01-01' AND OrderDate < '2023-04-01';

-- Switch the staging table into the partition
ALTER TABLE HR.Orders_2023Q1 
SWITCH TO HR.OrdersPartitioned PARTITION 6;

-- 4. Archiving data with partition switching

-- Create an archive table with identical structure
CREATE TABLE HR.Orders_Archive (
    OrderID INT NOT NULL,
    CustomerID INT NOT NULL,
    EmployeeID INT NOT NULL,
    OrderDate DATE NOT NULL,
    ShipDate DATE NULL,
    Amount DECIMAL(12,2) NOT NULL,
    Status NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_Orders_Archive PRIMARY KEY CLUSTERED (OrderDate, OrderID)
);

-- Switch the oldest partition to the archive table
ALTER TABLE HR.OrdersPartitioned 
SWITCH PARTITION 1 TO HR.Orders_Archive;

-- =============================================
-- PART 5: QUERYING PARTITIONED TABLES
-- =============================================

-- 1. Partition Elimination
-- SQL Server can skip partitions that don't contain relevant data

-- Query that benefits from partition elimination
SELECT * FROM HR.OrdersPartitioned
WHERE OrderDate >= '2022-01-01' AND OrderDate < '2023-01-01';

-- 2. Viewing partition metadata

-- View partitions for a table
SELECT 
    p.partition_number,
    p.rows,
    prv.value AS boundary_value,
    fg.name AS filegroup_name
FROM sys.partitions p
JOIN sys.indexes i ON p.object_id = i.object_id AND p.index_id = i.index_id
JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
LEFT JOIN sys.partition_range_values prv ON pf.function_id = prv.function_id 
    AND p.partition_number = prv.boundary_id + 1
JOIN sys.destination_data_spaces dds ON ps.data_space_id = dds.partition_scheme_id 
    AND p.partition_number = dds.destination_id
JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id
WHERE p.object_id = OBJECT_ID('HR.OrdersPartitioned')
    AND i.index_id = 1
ORDER BY p.partition_number;

-- 3. Finding which partition a row belongs to

-- Use $PARTITION function to determine partition number
SELECT 
    OrderID,
    OrderDate,
    $PARTITION.PF_OrderDate_Yearly(OrderDate) AS PartitionNumber
FROM HR.OrdersPartitioned
WHERE OrderID = 12345;

-- 4. Querying specific partitions

-- Use the PARTITION hint to query a specific partition
SELECT * FROM HR.OrdersPartitioned
WHERE $PARTITION.PF_OrderDate_Yearly(OrderDate) = 4;

-- =============================================
-- PART 6: SLIDING WINDOW SCENARIO
-- =============================================

-- Sliding window is a common pattern for managing time-based partitioned tables
-- It involves regularly adding new partitions and removing old ones

-- 1. Create a procedure to implement the sliding window pattern

CREATE OR ALTER PROCEDURE HR.Maintain_OrderPartitions
    @ArchiveDate DATE,
    @NewPartitionDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PartitionNumber INT;
    
    -- 1. Identify the partition to archive
    SELECT @PartitionNumber = $PARTITION.PF_OrderDate_Yearly(@ArchiveDate);
    
    -- 2. Create an empty staging table for the archive partition
    IF OBJECT_ID('HR.Orders_Archive_Staging', 'U') IS NOT NULL
        DROP TABLE HR.Orders_Archive_Staging;
    
    -- Create the staging table with the same structure
    CREATE TABLE HR.Orders_Archive_Staging (
        OrderID INT NOT NULL,
        CustomerID INT NOT NULL,
        EmployeeID INT NOT NULL,
        OrderDate DATE NOT NULL,
        ShipDate DATE NULL,
        Amount DECIMAL(12,2) NOT NULL,
        Status NVARCHAR(20) NOT NULL,
        CONSTRAINT PK_Orders_Archive_Staging PRIMARY KEY CLUSTERED (OrderDate, OrderID)
    );
    
    -- 3. Switch out the partition to the staging table
    ALTER TABLE HR.OrdersPartitioned
    SWITCH PARTITION @PartitionNumber TO HR.Orders_Archive_Staging;
    
    -- 4. Merge the now-empty partition
    DECLARE @BoundaryPoint DATE;
    SELECT @BoundaryPoint = value
    FROM sys.partition_range_values prv
    JOIN sys.partition_functions pf ON prv.function_id = pf.function_id
    WHERE pf.name = 'PF_OrderDate_Yearly'
    AND boundary_id = @PartitionNumber - 1;
    
    ALTER PARTITION FUNCTION PF_OrderDate_Yearly() 
    MERGE RANGE (@BoundaryPoint);
    
    -- 5. Add a new partition for future data
    ALTER PARTITION SCHEME PS_OrderDate_Yearly
    NEXT USED FG_Future;
    
    ALTER PARTITION FUNCTION PF_OrderDate_Yearly() 
    SPLIT RANGE (@NewPartitionDate);
    
    -- 6. Move data from staging to archive table
    INSERT INTO HR.Orders_Archive
    SELECT * FROM HR.Orders_Archive_Staging;
    
    -- 7. Clean up
    DROP TABLE HR.Orders_Archive_Staging