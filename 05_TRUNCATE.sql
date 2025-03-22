-- =============================================
-- TRUNCATE Keyword Complete Guide
-- =============================================

USE HRSystem;
GO

-- 1. Basic TRUNCATE Statement
-- Let's create a sample table for demonstration
CREATE TABLE HR.EmployeeTraining (
    TrainingID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT FOREIGN KEY REFERENCES HR.EMP_Details(EmployeeID),
    TrainingName VARCHAR(100),
    CompletionDate DATE,
    Score INT
);
GO

-- Insert some sample data
INSERT INTO HR.EmployeeTraining (EmployeeID, TrainingName, CompletionDate, Score)
VALUES 
    (1000, 'SQL Basics', '2023-01-15', 95),
    (1001, 'Data Security', '2023-02-20', 88),
    (1002, 'Leadership', '2023-03-10', 92);
GO

-- Basic TRUNCATE - removes all rows but keeps the table structure
TRUNCATE TABLE HR.EmployeeTraining;
GO

-- 2. TRUNCATE vs DELETE Comparison
-- Create tables to demonstrate differences
CREATE TABLE HR.TruncateDemo (ID INT IDENTITY(1,1), Value VARCHAR(50));
CREATE TABLE HR.DeleteDemo (ID INT IDENTITY(1,1), Value VARCHAR(50));
GO

-- Insert identical data
INSERT INTO HR.TruncateDemo (Value) VALUES ('Test1'), ('Test2'), ('Test3');
INSERT INTO HR.DeleteDemo (Value) VALUES ('Test1'), ('Test2'), ('Test3');
GO

-- TRUNCATE is faster and uses fewer resources
TRUNCATE TABLE HR.TruncateDemo;
-- DELETE can be filtered with WHERE clause
DELETE FROM HR.DeleteDemo WHERE Value = 'Test2';
GO

-- 3. TRUNCATE with IDENTITY Reset
-- Insert new data after TRUNCATE - notice IDENTITY values restart from seed
INSERT INTO HR.TruncateDemo (Value) VALUES ('New1'), ('New2');
GO

-- 4. TRUNCATE with Foreign Keys
-- Create parent-child tables to demonstrate constraints
CREATE TABLE HR.TrainingCourses (
    CourseID INT PRIMARY KEY,
    CourseName VARCHAR(100)
);

CREATE TABLE HR.CourseParticipants (
    ParticipantID INT IDENTITY(1,1) PRIMARY KEY,
    CourseID INT FOREIGN KEY REFERENCES HR.TrainingCourses(CourseID),
    EmployeeID INT
);
GO

-- Insert sample data
INSERT INTO HR.TrainingCourses VALUES (1, 'Advanced SQL');
INSERT INTO HR.CourseParticipants (CourseID, EmployeeID) VALUES (1, 1000);
GO

-- This will fail due to foreign key constraint
-- TRUNCATE TABLE HR.TrainingCourses;

-- 5. TRUNCATE with Table Partitioning
-- Create a partition function and scheme (for demonstration)
CREATE PARTITION FUNCTION PF_EmployeeIDRange (INT)
AS RANGE RIGHT FOR VALUES (1500, 2000, 2500);
GO

CREATE PARTITION SCHEME PS_EmployeeIDRange
AS PARTITION PF_EmployeeIDRange ALL TO ([PRIMARY]);
GO

-- Create a partitioned table
CREATE TABLE HR.PartitionedEmployees (
    EmployeeID INT PRIMARY KEY,
    Name VARCHAR(100),
    Department VARCHAR(50)
) ON PS_EmployeeIDRange(EmployeeID);
GO

-- Insert data across partitions
INSERT INTO HR.PartitionedEmployees VALUES 
    (1200, 'John Smith', 'IT'),
    (1600, 'Jane Doe', 'HR'),
    (2200, 'Bob Johnson', 'Finance'),
    (2700, 'Alice Brown', 'Marketing');
GO

-- Truncate entire table
TRUNCATE TABLE HR.PartitionedEmployees;
GO

-- 6. TRUNCATE with Table Variables and Temporary Tables
-- Table variables cannot be truncated
DECLARE @TempEmployees TABLE (ID INT, Name VARCHAR(50));
INSERT INTO @TempEmployees VALUES (1, 'Test');
-- This would fail: TRUNCATE TABLE @TempEmployees;
-- Must use DELETE instead: DELETE FROM @TempEmployees;

-- Temporary tables can be truncated
CREATE TABLE #TempTraining (ID INT, Course VARCHAR(50));
INSERT INTO #TempTraining VALUES (1, 'SQL Advanced');
TRUNCATE TABLE #TempTraining;
DROP TABLE #TempTraining;
GO

-- 7. TRUNCATE with Logging Considerations
-- Create a table for demonstration
CREATE TABLE HR.AuditLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    Action VARCHAR(50),
    TableName VARCHAR(100),
    UserName VARCHAR(100) DEFAULT SYSTEM_USER,
    LogDate DATETIME DEFAULT GETDATE()
);
GO

-- Minimal logging with TRUNCATE
INSERT INTO HR.AuditLog (Action, TableName) VALUES ('Before TRUNCATE', 'DemoTable');
TRUNCATE TABLE HR.AuditLog;
INSERT INTO HR.AuditLog (Action, TableName) VALUES ('After TRUNCATE', 'DemoTable');
GO

-- 8. TRUNCATE with Transaction Control
BEGIN TRANSACTION;
    -- This can be rolled back if within a transaction
    TRUNCATE TABLE HR.AuditLog;
    -- Decide to roll back
    ROLLBACK TRANSACTION;
GO

-- 9. TRUNCATE with Triggers
-- Create a table with a trigger
CREATE TABLE HR.InventoryItems (
    ItemID INT IDENTITY(1,1) PRIMARY KEY,
    ItemName VARCHAR(100),
    Quantity INT
);
GO

-- Create a trigger that fires on TRUNCATE
CREATE TRIGGER TR_Inventory_Truncate
ON HR.InventoryItems
AFTER TRUNCATE
AS
BEGIN
    INSERT INTO HR.AuditLog (Action, TableName)
    VALUES ('Table Truncated', 'HR.InventoryItems');
    PRINT 'Truncate operation logged';
END;
GO

-- Truncate will fire the trigger
TRUNCATE TABLE HR.InventoryItems;
GO

-- 10. Clean up demonstration tables
DROP TABLE IF EXISTS 
    HR.EmployeeTraining, 
    HR.TruncateDemo, 
    HR.DeleteDemo,
    HR.CourseParticipants,
    HR.TrainingCourses,
    HR.PartitionedEmployees,
    HR.InventoryItems,
    HR.AuditLog;
GO

DROP PARTITION SCHEME PS_EmployeeIDRange;
DROP PARTITION FUNCTION PF_EmployeeIDRange;
GO