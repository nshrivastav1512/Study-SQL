-- =============================================
-- SQL Server USER-DEFINED DATA TYPES Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating User-Defined Data Types
-- Basic user-defined data type creation
CREATE TYPE PhoneNumberType FROM VARCHAR(20) NOT NULL;
GO

-- Creating a user-defined data type with a rule
CREATE TYPE EmailType FROM VARCHAR(100) NULL;
GO

-- Creating a user-defined data type with a default
CREATE TYPE StatusType FROM VARCHAR(20) NOT NULL;
GO

-- Creating a user-defined data type in a specific schema
CREATE TYPE HR.EmployeeIDType FROM INT NOT NULL;
GO

-- 2. Creating Rules and Binding to User-Defined Data Types
-- Create a rule for email validation
CREATE RULE EmailRule AS 
    @value LIKE '%_@_%.__%';
GO

-- Bind the rule to the EmailType
EXEC sp_bindrule 'EmailRule', 'EmailType';
GO

-- Create a rule for status values
CREATE RULE StatusRule AS
    @value IN ('Active', 'Inactive', 'On Leave', 'Terminated');
GO

-- Bind the rule to the StatusType
EXEC sp_bindrule 'StatusRule', 'StatusType';
GO

-- 3. Creating Defaults and Binding to User-Defined Data Types
-- Create a default for status
CREATE DEFAULT StatusDefault AS 'Active';
GO

-- Bind the default to the StatusType
EXEC sp_bindefault 'StatusDefault', 'StatusType';
GO

-- 4. Using User-Defined Data Types in Tables
-- Create a table using the user-defined data types
CREATE TABLE HR.ContactInfo (
    ContactID INT PRIMARY KEY IDENTITY(1,1),
    EmployeeID HR.EmployeeIDType,
    Phone PhoneNumberType,
    Email EmailType,
    Status StatusType,
    LastUpdated DATETIME DEFAULT GETDATE()
);
GO

-- Insert data into the table
INSERT INTO HR.ContactInfo (EmployeeID, Phone, Email, Status)
VALUES 
    (1001, '555-123-4567', 'john.doe@example.com', 'Active'),
    (1002, '555-987-6543', 'jane.smith@example.com', 'On Leave');
GO

-- 5. Modifying User-Defined Data Types
-- SQL Server doesn't support direct ALTER TYPE statements for scalar types
-- You need to drop and recreate the type, but first handle dependencies

-- Create a new type for demonstration
CREATE TYPE TempType FROM VARCHAR(50) NULL;
GO

-- Create a table using this type
CREATE TABLE TempTable (
    ID INT PRIMARY KEY,
    Description TempType
);
GO

-- To modify the type, we need to:
-- 1. Find all dependencies
SELECT 
    o.name AS DependentObject,
    o.type_desc AS ObjectType
FROM sys.columns c
JOIN sys.types t ON c.user_type_id = t.user_type_id
JOIN sys.objects o ON c.object_id = o.object_id
WHERE t.name = 'TempType';
GO

-- 2. Drop the dependent objects or modify them to use a different type
DROP TABLE TempTable;
GO

-- 3. Drop the type
DROP TYPE TempType;
GO

-- 4. Recreate the type with new definition
CREATE TYPE TempType FROM VARCHAR(100) NULL;
GO

-- 5. Recreate the dependent objects
CREATE TABLE TempTable (
    ID INT PRIMARY KEY,
    Description TempType
);
GO

-- 6. Unbinding Rules and Defaults
-- Create a new type for demonstration
CREATE TYPE DemoType FROM VARCHAR(20) NULL;
GO

-- Create and bind a rule
CREATE RULE DemoRule AS @value LIKE 'DEMO-%';
GO

EXEC sp_bindrule 'DemoRule', 'DemoType';
GO

-- Create and bind a default
CREATE DEFAULT DemoDefault AS 'DEMO-DEFAULT';
GO

EXEC sp_bindefault 'DemoDefault', 'DemoType';
GO

-- Unbind the rule
EXEC sp_unbindrule 'DemoType';
GO

-- Unbind the default
EXEC sp_unbindefault 'DemoType';
GO

-- 7. Dropping User-Defined Data Types
-- First, drop any dependencies
DROP TABLE TempTable;
GO

-- Then drop the type
DROP TYPE TempType;
GO

-- Drop the demo type
DROP TYPE DemoType;
GO

-- 8. Querying User-Defined Data Type Information
-- List all user-defined data types in the database
SELECT 
    t.name AS TypeName,
    SCHEMA_NAME(t.schema_id) AS SchemaName,
    st.name AS BaseType,
    t.max_length,
    t.precision,
    t.scale,
    t.is_nullable,
    t.is_user_defined,
    t.is_table_type,
    t.create_date,
    t.modify_date
FROM sys.types t
JOIN sys.types st ON t.system_type_id = st.user_type_id
WHERE t.is_user_defined = 1 AND t.is_table_type = 0
ORDER BY SchemaName, TypeName;
GO

-- Find rules bound to user-defined data types
SELECT 
    t.name AS TypeName,
    SCHEMA_NAME(t.schema_id) AS SchemaName,
    o.name AS RuleName
FROM sys.types t
JOIN sys.objects o ON t.rule_object_id = o.object_id
WHERE t.is_user_defined = 1
ORDER BY SchemaName, TypeName;
GO

-- Find defaults bound to user-defined data types
SELECT 
    t.name AS TypeName,
    SCHEMA_NAME(t.schema_id) AS SchemaName,
    o.name AS DefaultName
FROM sys.types t
JOIN sys.objects o ON t.default_object_id = o.object_id
WHERE t.is_user_defined = 1
ORDER BY SchemaName, TypeName;
GO

-- 9. Table-Valued Parameters (TVPs)
-- Create a table type for passing multiple employees
CREATE TYPE HR.EmployeeTableType AS TABLE (
    EmployeeID INT,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Email VARCHAR(100),
    DepartmentID INT
);
GO

-- Create a stored procedure that uses the table type
CREATE PROCEDURE HR.BulkInsertEmployees
    @Employees HR.EmployeeTableType READONLY
AS
BEGIN
    INSERT INTO HR.Employees (EmployeeID, FirstName, LastName, Email, DepartmentID)
    SELECT EmployeeID, FirstName, LastName, Email, DepartmentID
    FROM @Employees;
END;
GO

-- Example of using the table-valued parameter
DECLARE @NewEmployees HR.EmployeeTableType;

-- Insert data into the table variable
INSERT INTO @NewEmployees (EmployeeID, FirstName, LastName, Email, DepartmentID)
VALUES 
    (1005, 'Robert', 'Johnson', 'robert.johnson@example.com', 2),
    (1006, 'Sarah', 'Williams', 'sarah.williams@example.com', 3);

-- Execute the procedure with the table parameter
EXEC HR.BulkInsertEmployees @NewEmployees;
GO

-- 10. Querying Table Types
-- List all table types in the database
SELECT 
    t.name AS TypeName,
    SCHEMA_NAME(t.schema_id) AS SchemaName,
    t.create_date,
    t.modify_date
FROM sys.types t
WHERE t.is_table_type = 1
ORDER BY SchemaName, TypeName;
GO

-- Get columns for a specific table type
SELECT 
    c.name AS ColumnName,
    t.name AS DataType,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM sys.table_types tt
JOIN sys.columns c ON tt.type_table_object_id = c.object_id
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE tt.name = 'EmployeeTableType' AND SCHEMA_NAME(tt.schema_id) = 'HR'
ORDER BY c.column_id;
GO

-- 11. Best Practices for User-Defined Data Types
-- Example of standardizing common data types across the database
CREATE TYPE MoneyType FROM DECIMAL(15, 2) NOT NULL;
GO

CREATE TYPE DateType FROM DATE NOT NULL;
GO

CREATE TYPE NameType FROM VARCHAR(100) NOT NULL;
GO

-- Create a table using standardized types
CREATE TABLE Finance.Invoices (
    InvoiceID INT PRIMARY KEY IDENTITY(1,1),
    CustomerName NameType,
    InvoiceDate DateType,
    Amount MoneyType,
    DueDate DateType,
    Status VARCHAR(20) DEFAULT 'Unpaid'
);
GO

-- 12. Using SYNONYM with User-Defined Data Types
-- Create a synonym for a user-defined data type
CREATE SYNONYM EmployeeID FOR HR.EmployeeIDType;
GO

-- Create a table using the synonym
CREATE TABLE Projects.TeamMembers (
    MemberID INT PRIMARY KEY IDENTITY(1,1),
    EmployeeID EmployeeID,  -- Using the synonym
    RoleInProject VARCHAR(50),
    JoinDate DATE DEFAULT GETDATE()
);
GO

-- 13. Migrating from User-Defined Data Types
-- If you need to migrate away from a user-defined data type
-- First, identify all columns using the type
SELECT 
    OBJECT_SCHEMA_NAME(c.object_id) + '.' + OBJECT_NAME(c.object_id) AS TableName,
    c.name AS ColumnName,
    t.name AS TypeName
FROM sys.columns c
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE t.name = 'PhoneNumberType'
ORDER BY TableName, c.column_id;
GO

-- Then, for each column, alter it to use the base type
-- Example:
ALTER TABLE HR.ContactInfo
ALTER COLUMN Phone VARCHAR(20) NOT NULL;
GO

-- 14. Comparing User-Defined Data Types vs. CHECK Constraints
-- Example using CHECK constraint instead of user-defined type
CREATE TABLE HR.EmployeeStatus (
    StatusID INT PRIMARY KEY IDENTITY(1,1),
    EmployeeID INT,
    Status VARCHAR(20) NOT NULL CHECK (Status IN ('Active', 'Inactive', 'On Leave', 'Terminated')),
    EffectiveDate DATE DEFAULT GETDATE()
);
GO

-- 15. Cleanup
-- Drop all objects created in this script
DROP TABLE IF EXISTS HR.ContactInfo;
DROP TABLE IF EXISTS TempTable;
DROP TABLE IF EXISTS Finance.Invoices;
DROP TABLE IF EXISTS Projects.TeamMembers;
DROP TABLE IF EXISTS HR.EmployeeStatus;
DROP PROCEDURE IF EXISTS HR.BulkInsertEmployees;
DROP TYPE IF EXISTS PhoneNumberType;
DROP TYPE IF EXISTS EmailType;
DROP TYPE IF EXISTS StatusType;
DROP TYPE IF EXISTS HR.EmployeeIDType;
DROP TYPE IF EXISTS HR.EmployeeTableType;
DROP TYPE IF EXISTS MoneyType;
DROP TYPE IF EXISTS DateType;
DROP TYPE IF EXISTS NameType;
DROP RULE IF EXISTS EmailRule;
DROP RULE IF EXISTS StatusRule;
DROP RULE IF EXISTS DemoRule;
DROP DEFAULT IF EXISTS StatusDefault;
DROP DEFAULT IF EXISTS DemoDefault;
DROP SYNONYM IF EXISTS EmployeeID;
GO