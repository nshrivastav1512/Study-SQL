-- =============================================
-- SQL Server SEQUENCES Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating Basic Sequences
-- Create a simple sequence that starts at 1 and increments by 1
CREATE SEQUENCE BasicSequence
AS INT
START WITH 1
INCREMENT BY 1;
GO

-- Create a sequence in a specific schema
CREATE SEQUENCE HR.EmployeeIDSequence
AS INT
START WITH 2000
INCREMENT BY 1;
GO

-- Create a sequence with minimum and maximum values
CREATE SEQUENCE Finance.InvoiceNumberSequence
AS INT
START WITH 10000
INCREMENT BY 1
MINVALUE 10000
MAXVALUE 99999
CYCLE;  -- Restart when reaching the maximum value
GO

-- Create a sequence with a custom increment value
CREATE SEQUENCE dbo.EvenNumberSequence
AS INT
START WITH 2
INCREMENT BY 2;
GO

-- Create a descending sequence
CREATE SEQUENCE dbo.CountdownSequence
AS INT
START WITH 100
INCREMENT BY -1
MINVALUE 1
MAXVALUE 100
NO CYCLE;
GO

-- 2. Using Sequences
-- Get the next value from a sequence
SELECT NEXT VALUE FOR BasicSequence AS NextValue;
GO

-- Get multiple values in a single query
SELECT 
    NEXT VALUE FOR BasicSequence AS Value1,
    NEXT VALUE FOR BasicSequence AS Value2,
    NEXT VALUE FOR BasicSequence AS Value3;
GO

-- Use a sequence in an INSERT statement
CREATE TABLE HR.Departments_Seq (
    DepartmentID INT PRIMARY KEY,
    DepartmentName VARCHAR(50) NOT NULL,
    LocationID INT,
    ManagerID INT,
    CreatedDate DATETIME DEFAULT GETDATE()
);
GO

INSERT INTO HR.Departments_Seq (DepartmentID, DepartmentName, LocationID, ManagerID)
VALUES (NEXT VALUE FOR HR.EmployeeIDSequence, 'Research', 1, 1001);
GO

-- Use a sequence as a default value
CREATE TABLE Finance.Invoices_Seq (
    InvoiceID INT PRIMARY KEY DEFAULT (NEXT VALUE FOR Finance.InvoiceNumberSequence),
    CustomerID INT,
    InvoiceDate DATE DEFAULT GETDATE(),
    Amount DECIMAL(15,2),
    Status VARCHAR(20) DEFAULT 'Unpaid'
);
GO

-- Insert without specifying the ID
INSERT INTO Finance.Invoices_Seq (CustomerID, Amount)
VALUES (101, 1250.75);
GO

-- 3. Modifying Sequences
-- Alter a sequence to change its increment value
ALTER SEQUENCE dbo.EvenNumberSequence
INCREMENT BY 4;
GO

-- Alter a sequence to change its minimum and maximum values
ALTER SEQUENCE Finance.InvoiceNumberSequence
MAXVALUE 999999;
GO

-- Alter a sequence to restart from a specific value
ALTER SEQUENCE HR.EmployeeIDSequence
RESTART WITH 3000;
GO

-- Alter a sequence to add cycling behavior
ALTER SEQUENCE dbo.CountdownSequence
CYCLE;
GO

-- 4. Restarting Sequences
-- Restart a sequence from its start value
ALTER SEQUENCE BasicSequence
RESTART;
GO

-- 5. Dropping Sequences
-- Drop a sequence
DROP SEQUENCE IF EXISTS TempSequence;
GO

-- Create and then drop a sequence
CREATE SEQUENCE TempSequence
AS INT
START WITH 1
INCREMENT BY 1;
GO

DROP SEQUENCE TempSequence;
GO

-- 6. Querying Sequence Information
-- List all sequences in the database
SELECT 
    s.name AS SequenceName,
    SCHEMA_NAME(s.schema_id) AS SchemaName,
    TYPE_NAME(s.user_type_id) AS DataType,
    s.start_value,
    s.increment,
    s.minimum_value,
    s.maximum_value,
    s.is_cycling,
    s.is_cached,
    s.cache_size,
    s.current_value,
    s.create_date,
    s.modify_date
FROM sys.sequences s
ORDER BY SchemaName, SequenceName;
GO

-- Get the current value of a sequence without incrementing it
SELECT 
    current_value 
FROM sys.sequences
WHERE name = 'BasicSequence' AND schema_id = SCHEMA_ID('dbo');
GO

-- Find dependencies on a sequence
SELECT 
    OBJECT_SCHEMA_NAME(o.object_id) + '.' + o.name AS ObjectName,
    o.type_desc AS ObjectType
FROM sys.sql_dependencies d
JOIN sys.objects o ON d.object_id = o.object_id
JOIN sys.sequences s ON d.referenced_major_id = s.object_id
WHERE s.name = 'InvoiceNumberSequence' AND s.schema_id = SCHEMA_ID('Finance');
GO

-- 7. Sequence Performance and Caching
-- Create a sequence with caching for better performance
CREATE SEQUENCE HR.PerformanceSequence
AS BIGINT
START WITH 1
INCREMENT BY 1
CACHE 100;  -- Cache 100 values for better performance
GO

-- Create a sequence without caching
CREATE SEQUENCE HR.NoCache_Sequence
AS INT
START WITH 1
INCREMENT BY 1
NO CACHE;  -- Do not cache values
GO

-- 8. Sequence vs. Identity
-- Example table with IDENTITY
CREATE TABLE HR.Employees_Identity (
    EmployeeID INT IDENTITY(1000,1) PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Email VARCHAR(100)
);
GO

-- Example table with SEQUENCE
CREATE SEQUENCE HR.Emp_Sequence
AS INT
START WITH 1000
INCREMENT BY 1;
GO

CREATE TABLE HR.Employees_Sequence (
    EmployeeID INT PRIMARY KEY DEFAULT (NEXT VALUE FOR HR.Emp_Sequence),
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Email VARCHAR(100)
);
GO

-- 9. Sequence Best Practices
-- Using sequences for multi-table ID generation
CREATE SEQUENCE dbo.GlobalIDSequence
AS BIGINT
START WITH 1
INCREMENT BY 1
CACHE 1000;
GO

-- Create tables that share the same ID sequence
CREATE TABLE HR.Employees_Global (
    EntityID BIGINT PRIMARY KEY DEFAULT (NEXT VALUE FOR dbo.GlobalIDSequence),
    EntityType VARCHAR(10) DEFAULT 'EMPLOYEE',
    FirstName VARCHAR(50),
    LastName VARCHAR(50)
);
GO

CREATE TABLE HR.Contractors_Global (
    EntityID BIGINT PRIMARY KEY DEFAULT (NEXT VALUE FOR dbo.GlobalIDSequence),
    EntityType VARCHAR(10) DEFAULT 'CONTRACTOR',
    CompanyName VARCHAR(100),
    ContactName VARCHAR(100)
);
GO

-- 10. Generating Sequential Codes with Sequences
-- Create a sequence for generating invoice numbers with prefix
CREATE SEQUENCE Finance.InvoiceCodeSequence
AS INT
START WITH 1
INCREMENT BY 1;
GO

-- Function to generate formatted invoice numbers
CREATE FUNCTION Finance.GenerateInvoiceNumber()
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @NextVal INT = NEXT VALUE FOR Finance.InvoiceCodeSequence;
    RETURN 'INV-' + FORMAT(@NextVal, '000000');
END;
GO

-- Use the function to generate invoice numbers
CREATE TABLE Finance.InvoiceHeaders (
    InvoiceNumber VARCHAR(20) PRIMARY KEY DEFAULT (Finance.GenerateInvoiceNumber()),
    CustomerID INT,
    InvoiceDate DATE DEFAULT GETDATE(),
    TotalAmount DECIMAL(15,2)
);
GO

-- Insert a record using the generated invoice number
INSERT INTO Finance.InvoiceHeaders (CustomerID, TotalAmount)
VALUES (101, 1500.75);
GO

-- 11. Sequence Gaps and Handling
-- Sequences can have gaps if server restarts or transactions roll back
-- Demonstrate a gap by getting values and not using them
DECLARE @Unused1 INT = NEXT VALUE FOR BasicSequence;
DECLARE @Unused2 INT = NEXT VALUE FOR BasicSequence;
SELECT 'Skipped values to demonstrate gaps' AS Info;
GO

-- Get the next value after the gap
SELECT NEXT VALUE FOR BasicSequence AS NextValueAfterGap;
GO

-- 12. Cleanup
-- Drop all objects created in this script
DROP TABLE IF EXISTS HR.Departments_Seq;
DROP TABLE IF EXISTS Finance.Invoices_Seq;
DROP TABLE IF EXISTS HR.Employees_Identity;
DROP TABLE IF EXISTS HR.Employees_Sequence;
DROP TABLE IF EXISTS HR.Employees_Global;
DROP TABLE IF EXISTS HR.Contractors_Global;
DROP TABLE IF EXISTS Finance.InvoiceHeaders;

DROP SEQUENCE IF EXISTS BasicSequence;
DROP SEQUENCE IF EXISTS HR.EmployeeIDSequence;
DROP SEQUENCE IF EXISTS Finance.InvoiceNumberSequence;
DROP SEQUENCE IF EXISTS dbo.EvenNumberSequence;
DROP SEQUENCE IF EXISTS dbo.CountdownSequence;
DROP SEQUENCE IF EXISTS HR.PerformanceSequence;
DROP SEQUENCE IF EXISTS HR.NoCache_Sequence;
DROP SEQUENCE IF EXISTS HR.Emp_Sequence;
DROP SEQUENCE IF EXISTS dbo.GlobalIDSequence;
DROP SEQUENCE IF EXISTS Finance.InvoiceCodeSequence;

DROP FUNCTION IF EXISTS Finance.GenerateInvoiceNumber;
GO