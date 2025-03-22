-- =============================================
-- SQL Server SCHEMAS Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating Schemas
-- Basic schema creation
CREATE SCHEMA Marketing;
GO

-- Creating schema with authorization (owner)
CREATE SCHEMA Finance AUTHORIZATION dbo;
GO

-- Creating schema with authorization to a specific user
-- First create a user if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'SchemaAdmin')
BEGIN
    CREATE USER SchemaAdmin WITHOUT LOGIN;
END
GO

CREATE SCHEMA Reporting AUTHORIZATION SchemaAdmin;
GO

-- 2. Modifying Schemas
-- Transferring schema ownership
ALTER AUTHORIZATION ON SCHEMA::Marketing TO SchemaAdmin;
GO

-- 3. Schema Usage - Creating Objects in Schemas
-- Creating a table in the Marketing schema
CREATE TABLE Marketing.Campaigns (
    CampaignID INT PRIMARY KEY IDENTITY(1,1),
    CampaignName VARCHAR(100) NOT NULL,
    StartDate DATE,
    EndDate DATE,
    Budget DECIMAL(15,2),
    Description VARCHAR(500)
);
GO

-- Creating a view in the Finance schema
CREATE VIEW Finance.BudgetSummary AS
SELECT 
    p.ProjectID,
    p.ProjectName,
    p.Budget,
    SUM(ISNULL(pbi.ActualCost, 0)) AS TotalSpent,
    p.Budget - SUM(ISNULL(pbi.ActualCost, 0)) AS RemainingBudget
FROM dbo.Projects p
LEFT JOIN dbo.ProjectBudgetItems pbi ON p.ProjectID = pbi.ProjectID
GROUP BY p.ProjectID, p.ProjectName, p.Budget;
GO

-- Creating a stored procedure in the Reporting schema
CREATE PROCEDURE Reporting.GetEmployeesByDepartment
    @DepartmentID INT
AS
BEGIN
    SELECT 
        EmployeeID,
        FirstName,
        LastName,
        Email,
        Phone,
        HireDate
    FROM HR.Employees
    WHERE DepartmentID = @DepartmentID;
END;
GO

-- 4. Moving Objects Between Schemas
-- First create a table in dbo schema
CREATE TABLE dbo.MarketingContacts (
    ContactID INT PRIMARY KEY IDENTITY(1,1),
    ContactName VARCHAR(100),
    Email VARCHAR(100),
    Phone VARCHAR(20),
    CompanyName VARCHAR(100),
    CreatedDate DATETIME DEFAULT GETDATE()
);
GO

-- Move the table to Marketing schema
ALTER SCHEMA Marketing TRANSFER dbo.MarketingContacts;
GO

-- 5. Setting Default Schema for a User
-- Create a login and user if they don't exist
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'MarketingUser')
BEGIN
    CREATE LOGIN MarketingUser WITH PASSWORD = 'P@ssw0rd123';
END
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'MarketingUser')
BEGIN
    CREATE USER MarketingUser FOR LOGIN MarketingUser;
END
GO

-- Set default schema for the user
ALTER USER MarketingUser WITH DEFAULT_SCHEMA = Marketing;
GO

-- 6. Dropping a Schema
-- First, create a temporary schema
CREATE SCHEMA TempSchema;
GO

-- Create a table in the schema
CREATE TABLE TempSchema.TemporaryData (
    ID INT PRIMARY KEY,
    Data VARCHAR(100)
);
GO

-- To drop a schema, first we need to drop or move all objects in it
DROP TABLE TempSchema.TemporaryData;
GO

-- Now we can drop the schema
DROP SCHEMA TempSchema;
GO

-- 7. Querying Schema Information from System Views
-- List all schemas in the database
SELECT 
    s.name AS SchemaName,
    p.name AS SchemaOwner,
    s.schema_id,
    s.principal_id,
    CASE WHEN s.schema_id < 16384 THEN 'System Schema' ELSE 'User Schema' END AS SchemaType,
    s.create_date,
    s.modify_date
FROM sys.schemas s
LEFT JOIN sys.database_principals p ON s.principal_id = p.principal_id
ORDER BY SchemaType, s.name;
GO

-- List all objects in a specific schema
SELECT 
    o.name AS ObjectName,
    o.type_desc AS ObjectType,
    o.create_date,
    o.modify_date
FROM sys.objects o
WHERE o.schema_id = SCHEMA_ID('Marketing')
ORDER BY o.type_desc, o.name;
GO

-- Find which schema contains a specific object
SELECT 
    OBJECT_SCHEMA_NAME(object_id) AS SchemaName,
    name AS ObjectName,
    type_desc AS ObjectType
FROM sys.objects
WHERE name = 'Campaigns';
GO

-- 8. Schema Security and Permissions
-- Grant permissions on schema
GRANT SELECT ON SCHEMA::Marketing TO MarketingUser;
GO

-- Grant all permissions on schema
GRANT CONTROL ON SCHEMA::Marketing TO SchemaAdmin;
GO

-- Deny specific permission on schema
DENY DELETE ON SCHEMA::Finance TO MarketingUser;
GO

-- Revoke permissions on schema
REVOKE INSERT ON SCHEMA::Reporting FROM MarketingUser;
GO

-- 9. Schema Best Practices
-- Example of organizing objects by business function
CREATE SCHEMA Sales;
GO

CREATE TABLE Sales.Customers (
    CustomerID INT PRIMARY KEY IDENTITY(1,1),
    CustomerName VARCHAR(100),
    ContactPerson VARCHAR(100),
    Email VARCHAR(100),
    Phone VARCHAR(20),
    Address VARCHAR(200),
    City VARCHAR(50),
    Country VARCHAR(50),
    CreatedDate DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE Sales.Orders (
    OrderID INT PRIMARY KEY IDENTITY(1,1),
    CustomerID INT FOREIGN KEY REFERENCES Sales.Customers(CustomerID),
    OrderDate DATETIME DEFAULT GETDATE(),
    TotalAmount DECIMAL(15,2),
    Status VARCHAR(20) DEFAULT 'Pending'
);
GO

-- Example of organizing objects by security boundary
CREATE SCHEMA Confidential;
GO

CREATE TABLE Confidential.EmployeeSalaries (
    SalaryID INT PRIMARY KEY IDENTITY(1,1),
    EmployeeID INT FOREIGN KEY REFERENCES HR.Employees(EmployeeID),
    Salary DECIMAL(15,2),
    EffectiveDate DATE,
    EndDate DATE NULL,
    Comments VARCHAR(500) NULL
);
GO

-- 10. Using SCHEMA_NAME and SCHEMA_ID Functions
-- Get schema name from ID
SELECT SCHEMA_NAME(1) AS SchemaName;
GO

-- Get schema ID from name
SELECT SCHEMA_ID('HR') AS SchemaID;
GO

-- 11. Schema Binding for Views and Functions
CREATE VIEW Finance.ProjectFinancials WITH SCHEMABINDING AS
SELECT 
    p.ProjectID,
    p.ProjectName,
    p.Budget,
    p.StartDate,
    p.EndDate
FROM dbo.Projects p;
GO

-- 12. Default Schema for Database
-- Check current default schema
SELECT name, default_schema_name 
FROM sys.database_principals 
WHERE name = 'dbo';
GO

-- 13. Schema Search Path
-- SQL Server doesn't have a schema search path like PostgreSQL,
-- but you can use synonyms to achieve similar functionality
CREATE SYNONYM Employees FOR HR.Employees;
GO

-- Now you can query without schema prefix
SELECT EmployeeID, FirstName, LastName FROM Employees;
GO

-- 14. Schema Comparison
-- Compare objects between two schemas
SELECT 
    'HR' AS SchemaName,
    o.name AS ObjectName,
    o.type_desc AS ObjectType
FROM sys.objects o
WHERE o.schema_id = SCHEMA_ID('HR')

UNION ALL

SELECT 
    'Marketing' AS SchemaName,
    o.name AS ObjectName,
    o.type_desc AS ObjectType
FROM sys.objects o
WHERE o.schema_id = SCHEMA_ID('Marketing')

ORDER BY ObjectName, SchemaName;
GO

-- 15. Schema Cleanup Script
-- This script helps identify and drop all objects in a schema before dropping the schema
DECLARE @SchemaName NVARCHAR(128) = 'Marketing';
DECLARE @SQL NVARCHAR(MAX) = '';

-- Drop foreign keys first
SELECT @SQL = @SQL + 'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id)) + '.' + 
                      QUOTENAME(OBJECT_NAME(parent_object_id)) + 
                      ' DROP CONSTRAINT ' + QUOTENAME(name) + ';' + CHAR(13)
FROM sys.foreign_keys
WHERE OBJECT_SCHEMA_NAME(parent_object_id) = @SchemaName;

-- Drop tables
SELECT @SQL = @SQL + 'DROP TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(name) + ';' + CHAR(13)
FROM sys.tables
WHERE schema_id = SCHEMA_ID(@SchemaName);

-- Drop views
SELECT @SQL = @SQL + 'DROP VIEW ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(name) + ';' + CHAR(13)
FROM sys.views
WHERE schema_id = SCHEMA_ID(@SchemaName);

-- Drop procedures
SELECT @SQL = @SQL + 'DROP PROCEDURE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(name) + ';' + CHAR(13)
FROM sys.procedures
WHERE schema_id = SCHEMA_ID(@SchemaName);

-- Drop functions
SELECT @SQL = @SQL + 'DROP FUNCTION ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(name) + ';' + CHAR(13)
FROM sys.objects
WHERE schema_id = SCHEMA_ID(@SchemaName) AND type IN ('FN', 'IF', 'TF');

-- Drop schema
SELECT @SQL = @SQL + 'DROP SCHEMA ' + QUOTENAME(@SchemaName) + ';';

-- Print the script (in a real scenario, you might want to execute it)
PRINT @SQL;
GO