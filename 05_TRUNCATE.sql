-- =============================================
-- TRUNCATE Keyword Complete Guide
-- =============================================

/*
 TRUNCATE Keyword Complete Guide
 The provided SQL file is a comprehensive guide to the TRUNCATE keyword in Microsoft SQL Server. It covers various aspects of using the TRUNCATE statement, including basic usage, comparison with the DELETE statement, resetting identity values, handling foreign keys, table partitioning, working with table variables and temporary tables, logging considerations, transaction control, and triggers.
 Explanation: The TRUNCATE statement is a DDL command that quickly removes all rows from a table or specified partition while preserving the table structure, resetting identity values, and using minimal transaction log space compared to DELETE; it cannot be filtered with WHERE clause, requires table-level permissions, cannot be used on tables referenced by foreign keys, doesn't fire AFTER/FOR triggers by default (only INSTEAD OF triggers), cannot be used with indexed views, doesn't activate change tracking/change data capture, bypasses CHECK constraints, cannot be used on tables involved in replication, and requires exclusive table access (table-level lock).
1. Basic TRUNCATE Statement:The section demonstrates the basic usage of the TRUNCATE statement. It creates a sample table, inserts data, and then truncates the table using the TRUNCATE TABLE statement. The TRUNCATE statement removes all rows from the table while keeping the table structure intact.
2. TRUNCATE vs DELETE Comparison:This section compares the TRUNCATE and DELETE statements. It creates two tables, inserts identical data into them, and then demonstrates the differences between TRUNCATE and DELETE. The TRUNCATE statement is faster and uses fewer resources, while the DELETE statement can be filtered using a WHERE clause.
3. TRUNCATE with IDENTITY Reset:In this section, new data is inserted after truncating a table. It highlights that when a table is truncated, the identity values restart from the seed value.
4. TRUNCATE with Foreign Keys:The section demonstrates the behavior of the TRUNCATE statement when foreign key constraints are present. It creates parent-child tables and inserts sample data. It shows that truncating a table with foreign key constraints will fail due to the constraint.
5. TRUNCATE with Table Partitioning:This section focuses on using the TRUNCATE statement with table partitioning. It creates a partition function, scheme, and a partitioned table. Data is inserted across partitions, and then the entire table is truncated using the TRUNCATE TABLE statement.
6. TRUNCATE with Table Variables and Temporary Tables:The section discusses the usage of the TRUNCATE statement with table variables and temporary tables. It demonstrates that table variables cannot be truncated and must be deleted using the DELETE statement. Temporary tables, on the other hand, can be truncated.
7. TRUNCATE with Logging Considerations:This section covers the logging considerations when using the TRUNCATE statement. It creates an audit log table and shows that TRUNCATE has minimal logging. It inserts records before and after truncating the table to demonstrate the logging behavior.
8. TRUNCATE with Transaction Control:In this section, the usage of the TRUNCATE statement within a transaction is demonstrated. It shows that a TRUNCATE operation can be rolled back if it is within a transaction.
9. TRUNCATE with Triggers:The section focuses on using the TRUNCATE statement with triggers. It creates a table with a trigger that fires after a TRUNCATE operation. The trigger logs the truncate operation in an audit log table.
10. Clean up demonstration tables:The final section cleans up all the demonstration tables created in the previous sections.
Note: The provided SQL file includes comments and explanations for each section, providing additional context and details for better understanding.

Author: Nikhil Shrivastav
Date: February 2025
*/


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
