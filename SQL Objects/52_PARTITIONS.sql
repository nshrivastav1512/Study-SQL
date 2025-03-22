-- =============================================
-- SQL Server PARTITIONS Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating a Partition Function
-- Create a partition function that will divide data into yearly partitions
CREATE PARTITION FUNCTION YearlyPartitionFunction (DATE)
AS RANGE RIGHT FOR VALUES (
    '2020-01-01', '2021-01-01', '2022-01-01', '2023-01-01', '2024-01-01'
);
GO

-- 2. Creating a Partition Scheme
-- Create a partition scheme that maps partitions to filegroups
-- Note: In a real environment, you would create multiple filegroups for better performance
CREATE PARTITION SCHEME YearlyPartitionScheme
AS PARTITION YearlyPartitionFunction
ALL TO ([PRIMARY]);
GO

-- 3. Creating a Partitioned Table
-- Create a table that uses the partition scheme
CREATE TABLE HR.EmployeeAttendance (
    AttendanceID INT IDENTITY(1,1) NOT NULL,
    EmployeeID INT NOT NULL,
    AttendanceDate DATE NOT NULL,
    CheckInTime TIME,
    CheckOutTime TIME,
    Status VARCHAR(20),
    Notes VARCHAR(500),
    CONSTRAINT PK_EmployeeAttendance PRIMARY KEY (AttendanceID, AttendanceDate)
) ON YearlyPartitionScheme(AttendanceDate);
GO

-- 4. Inserting Data into Partitioned Table
-- Insert sample data that will be distributed across partitions
INSERT INTO HR.EmployeeAttendance (EmployeeID, AttendanceDate, CheckInTime, CheckOutTime, Status)
VALUES
    -- 2019 data (will go to partition 1)
    (1001, '2019-12-15', '09:00', '17:30', 'Present'),
    (1002, '2019-12-15', '08:45', '17:15', 'Present'),
    
    -- 2020 data (will go to partition 2)
    (1001, '2020-02-10', '09:05', '17:45', 'Present'),
    (1002, '2020-02-10', '08:50', '17:20', 'Present'),
    (1001, '2020-06-15', '09:15', '17:30', 'Present'),
    
    -- 2021 data (will go to partition 3)
    (1001, '2021-03-22', '09:00', '17:30', 'Present'),
    (1002, '2021-03-22', '08:45', '17:15', 'Present'),
    (1003, '2021-07-10', NULL, NULL, 'Absent'),
    
    -- 2022 data (will go to partition 4)
    (1001, '2022-01-05', '09:10', '17:40', 'Present'),
    (1002, '2022-05-20', '08:55', '17:25', 'Present'),
    (1003, '2022-09-15', '09:30', '16:45', 'Present'),
    
    -- 2023 data (will go to partition 5)
    (1001, '2023-02-14', '09:00', '17:30', 'Present'),
    (1002, '2023-04-05', '08:45', '17:15', 'Present'),
    (1003, '2023-08-22', '09:20', '17:50', 'Present'),
    
    -- 2024 data (will go to partition 6)
    (1001, '2024-01-10', '09:05', '17:35', 'Present'),
    (1002, '2024-01-10', '08:50', '17:20', 'Present');
GO

-- 5. Querying Partition Information
-- View partition information for the table
SELECT 
    p.partition_number,
    p.rows,
    prv.value AS boundary_value,
    fg.name AS filegroup_name
FROM sys.partitions p
JOIN sys.indexes i ON p.object_id = i.object_id AND p.index_id = i.index_id
JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
LEFT JOIN sys.partition_range_values prv ON pf.function_id = prv.function_id AND p.partition_number = prv.boundary_id + 1
JOIN sys.destination_data_spaces dds ON ps.data_space_id = dds.partition_scheme_id AND p.partition_number = dds.destination_id
JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id
WHERE p.object_id = OBJECT_ID('HR.EmployeeAttendance') AND i.index_id = 1
ORDER BY p.partition_number;
GO

-- 6. Querying Data from Specific Partitions
-- Query data from a specific partition using $PARTITION function
SELECT 
    AttendanceID,
    EmployeeID,
    AttendanceDate,
    CheckInTime,
    CheckOutTime,
    Status,
    $PARTITION.YearlyPartitionFunction(AttendanceDate) AS PartitionNumber
FROM HR.EmployeeAttendance
WHERE $PARTITION.YearlyPartitionFunction(AttendanceDate) = 3;  -- Partition for 2021 data
GO

-- 7. Partition Elimination (Query Optimization)
-- This query will benefit from partition elimination
-- SQL Server will only scan the relevant partition
SELECT 
    AttendanceID,
    EmployeeID,
    AttendanceDate,
    CheckInTime,
    CheckOutTime,
    Status
FROM HR.EmployeeAttendance
WHERE AttendanceDate >= '2022-01-01' AND AttendanceDate < '2023-01-01';
GO

-- 8. Adding a New Partition Boundary
-- Extend the partition function to include a new year
ALTER PARTITION FUNCTION YearlyPartitionFunction()
SPLIT RANGE ('2025-01-01');
GO

-- 9. Removing a Partition Boundary
-- Remove the oldest partition boundary (merging partitions)
ALTER PARTITION FUNCTION YearlyPartitionFunction()
MERGE RANGE ('2020-01-01');
GO

-- 10. Switching Partitions (for archiving or loading data)
-- First, create a staging table with identical structure
CREATE TABLE HR.EmployeeAttendance_Staging (
    AttendanceID INT IDENTITY(1,1) NOT NULL,
    EmployeeID INT NOT NULL,
    AttendanceDate DATE NOT NULL,
    CheckInTime TIME,
    CheckOutTime TIME,
    Status VARCHAR(20),
    Notes VARCHAR(500),
    CONSTRAINT PK_EmployeeAttendance_Staging PRIMARY KEY (AttendanceID, AttendanceDate)
);
GO

-- Switch out a partition to the staging table
-- This is a metadata operation and is very fast
ALTER TABLE HR.EmployeeAttendance
SWITCH PARTITION 6 TO HR.EmployeeAttendance_Staging;
GO

-- 11. Creating a Partitioned Index
-- Create a nonclustered index on the partitioned table
CREATE NONCLUSTERED INDEX IX_EmployeeAttendance_EmployeeID
ON HR.EmployeeAttendance(EmployeeID)
ON YearlyPartitionScheme(AttendanceDate);
GO

-- 12. Partition-Aligned Indexed Views
-- Create a view that summarizes attendance by month
CREATE VIEW HR.MonthlyAttendanceSummary
WITH SCHEMABINDING
AS
SELECT 
    EmployeeID,
    YEAR(AttendanceDate) AS Year,
    MONTH(AttendanceDate) AS Month,
    COUNT_BIG(*) AS TotalDays,
    SUM(CASE WHEN Status = 'Present' THEN 1 ELSE 0 END) AS PresentDays,
    SUM(CASE WHEN Status = 'Absent' THEN 1 ELSE 0 END) AS AbsentDays
FROM HR.EmployeeAttendance
GROUP BY EmployeeID, YEAR(AttendanceDate), MONTH(AttendanceDate);
GO

-- Create an index on the view
CREATE UNIQUE CLUSTERED INDEX IX_MonthlyAttendanceSummary
ON HR.MonthlyAttendanceSummary(Year, Month, EmployeeID);
GO

-- 13. Partitioning by Multiple Columns (Composite Partitioning)
-- Create a partition function for department-based partitioning
CREATE PARTITION FUNCTION DepartmentPartitionFunction(INT)
AS RANGE RIGHT FOR VALUES (1, 2, 3, 4, 5);
GO

CREATE PARTITION SCHEME DepartmentPartitionScheme
AS PARTITION DepartmentPartitionFunction
ALL TO ([PRIMARY]);
GO

-- Create a table partitioned by department
CREATE TABLE HR.EmployeeProjects (
    ProjectAssignmentID INT IDENTITY(1,1) NOT NULL,
    EmployeeID INT NOT NULL,
    DepartmentID INT NOT NULL,
    ProjectID INT NOT NULL,
    AssignmentDate DATE NOT NULL,
    HoursAllocated INT,
    CONSTRAINT PK_EmployeeProjects PRIMARY KEY (ProjectAssignmentID, DepartmentID)
) ON DepartmentPartitionScheme(DepartmentID);
GO

-- 14. Partitioned Table Maintenance
-- Rebuild a specific partition
ALTER INDEX PK_EmployeeAttendance ON HR.EmployeeAttendance
REBUILD PARTITION = 3;
GO

-- Reorganize a specific partition
ALTER INDEX PK_EmployeeAttendance ON HR.EmployeeAttendance
REORGANIZE PARTITION = 4;
GO

-- 15. Partition Statistics
-- Update statistics for a specific partition
UPDATE STATISTICS HR.EmployeeAttendance
WITH RESAMPLE ON PARTITIONS(5);
GO

-- 16. Sliding Window Scenario (Common for Time-Based Partitioning)
-- This demonstrates how to implement a sliding window for data retention

-- 1. Create a staging table for new data
CREATE TABLE HR.EmployeeAttendance_Future (
    AttendanceID INT IDENTITY(1,1) NOT NULL,
    EmployeeID INT NOT NULL,
    AttendanceDate DATE NOT NULL,
    CheckInTime TIME,
    CheckOutTime TIME,
    Status VARCHAR(20),
    Notes VARCHAR(500),
    CONSTRAINT PK_EmployeeAttendance_Future PRIMARY KEY (AttendanceID, AttendanceDate)
);
GO

-- 2. Create a staging table for old data (to be archived)
CREATE TABLE HR.EmployeeAttendance_Archive (
    AttendanceID INT NOT NULL,
    EmployeeID INT NOT NULL,
    AttendanceDate DATE NOT NULL,
    CheckInTime TIME,
    CheckOutTime TIME,
    Status VARCHAR(20),
    Notes VARCHAR(500),
    CONSTRAINT PK_EmployeeAttendance_Archive PRIMARY KEY (AttendanceID, AttendanceDate)
);
GO

-- 3. Insert future data into staging table
INSERT INTO HR.EmployeeAttendance_Future (EmployeeID, AttendanceDate, CheckInTime, CheckOutTime, Status)
VALUES
    (1001, '2025-01-15', '09:00', '17:30', 'Present'),
    (1002, '2025-01-15', '08:45', '17:15', 'Present'),
    (1003, '2025-02-10', '09:10', '17:40', 'Present');
GO

-- 4. Add a new partition for the future data
ALTER PARTITION FUNCTION YearlyPartitionFunction()
SPLIT RANGE ('2026-01-01');
GO

-- 5. Switch in the new data
ALTER TABLE HR.EmployeeAttendance_Future
SWITCH TO HR.EmployeeAttendance PARTITION 7;
GO

-- 6. Switch out the oldest partition for archiving
ALTER TABLE HR.EmployeeAttendance
SWITCH PARTITION 1 TO HR.EmployeeAttendance_Archive;
GO

-- 7. Remove the oldest boundary point
ALTER PARTITION FUNCTION YearlyPartitionFunction()
MERGE RANGE ('2021-01-01');
GO

-- 17. Cleanup
-- Drop all objects created in this script
DROP TABLE IF EXISTS HR.EmployeeAttendance;
DROP TABLE IF EXISTS HR.EmployeeAttendance_Staging;
DROP TABLE IF EXISTS HR.EmployeeAttendance_Future;
DROP TABLE IF EXISTS HR.EmployeeAttendance_Archive;
DROP TABLE IF EXISTS HR.EmployeeProjects;
DROP VIEW IF EXISTS HR.MonthlyAttendanceSummary;

DROP PARTITION SCHEME IF EXISTS YearlyPartitionScheme;
DROP PARTITION FUNCTION IF EXISTS YearlyPartitionFunction;
DROP PARTITION SCHEME IF EXISTS DepartmentPartitionScheme;
DROP PARTITION FUNCTION IF EXISTS DepartmentPartitionFunction;
GO