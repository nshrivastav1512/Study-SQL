-- =============================================
-- SQL Server PERMISSIONS Guide
-- =============================================

USE HRSystem;
GO

-- 1. Granting Permissions
-- Database-level permissions
GRANT CREATE TABLE, CREATE VIEW, CREATE PROCEDURE TO HRDevelopers;
GO

-- Schema-level permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::HR TO HRUsers;
GO

-- Object-level permissions
GRANT SELECT, INSERT, UPDATE ON HR.Departments TO DepartmentManagers;
GO

-- Column-level permissions
GRANT SELECT ON HR.Employees(EmployeeID, FirstName, LastName, Email) TO ReceptionStaff;
GO

-- Granting with GRANT OPTION
GRANT SELECT ON HR.Departments TO HRManagers WITH GRANT OPTION;
GO

-- Granting execute permissions
GRANT EXECUTE ON HR.AddEmployee TO HRClerks;
GO

-- 2. Denying Permissions
-- Deny overrides grant, even if granted through role membership
DENY DELETE ON HR.Employees TO HRClerks;
GO

-- Deny at schema level
DENY ALTER ON SCHEMA::HR TO HRDevelopers;
GO

-- Deny at column level
DENY SELECT ON HR.Employees(Salary, BankAccountNumber) TO HRClerks;
GO

-- 3. Revoking Permissions
-- Revoke previously granted permissions
REVOKE INSERT ON HR.Departments FROM DepartmentManagers;
GO

-- Revoke permissions granted with GRANT OPTION
REVOKE SELECT ON HR.Departments FROM HRManagers CASCADE;
GO

-- Revoke previously denied permissions
REVOKE DENY DELETE ON HR.Employees FROM HRClerks;
GO

-- 4. Permission Inheritance and Scope
-- Create a hierarchy of schemas and objects to demonstrate inheritance
CREATE SCHEMA Finance;
GO

-- Create tables in the Finance schema
CREATE TABLE Finance.Budget (
    BudgetID INT PRIMARY KEY,
    DepartmentID INT,
    FiscalYear INT,
    Amount DECIMAL(15,2),
    CONSTRAINT FK_Budget_Departments FOREIGN KEY (DepartmentID) 
        REFERENCES HR.Departments(DepartmentID)
);
GO

-- Grant permissions at different levels
-- Schema-level permission affects all objects in the schema
GRANT SELECT ON SCHEMA::Finance TO FinanceAnalysts;
GO

-- Object-level permission affects only the specific object
GRANT UPDATE ON Finance.Budget TO BudgetAdministrators;
GO

-- 5. Managing Permissions for Special Principals
-- Grant permissions to public (all users)
GRANT SELECT ON HR.Departments TO PUBLIC;
GO

-- Grant permissions to guest user
GRANT SELECT ON HR.EmployeeSkills TO GUEST;
GO

-- 6. Querying Permission Information
-- List all permissions in the database
SELECT 
    pr.name AS PrincipalName,
    pr.type_desc AS PrincipalType,
    perm.permission_name,
    perm.state_desc AS PermissionState,
    CASE 
        WHEN perm.class = 0 THEN 'Database'
        WHEN perm.class = 1 THEN 'Object or Column'
        WHEN perm.class = 3 THEN 'Schema'
        WHEN perm.class = 4 THEN 'Database Principal'
        WHEN perm.class = 5 THEN 'Assembly'
        WHEN perm.class = 6 THEN 'Type'
        WHEN perm.class = 10 THEN 'XML Schema Collection'
        WHEN perm.class = 15 THEN 'Message Type'
        WHEN perm.class = 16 THEN 'Service Contract'
        WHEN perm.class = 17 THEN 'Service'
        WHEN perm.class = 18 THEN 'Remote Service Binding'
        WHEN perm.class = 19 THEN 'Route'
        WHEN perm.class = 23 THEN 'Full-Text Catalog'
        WHEN perm.class = 24 THEN 'Symmetric Key'
        WHEN perm.class = 25 THEN 'Certificate'
        WHEN perm.class = 26 THEN 'Asymmetric Key'
        ELSE CAST(perm.class AS VARCHAR(10))
    END AS PermissionClass,
    CASE 
        WHEN perm.class = 0 THEN DB_NAME()
        WHEN perm.class = 1 THEN OBJECT_NAME(perm.major_id)
        WHEN perm.class = 3 THEN SCHEMA_NAME(perm.major_id)
        WHEN perm.class = 4 THEN USER_NAME(perm.major_id)
        WHEN perm.class = 5 THEN (SELECT name FROM sys.assemblies WHERE assembly_id = perm.major_id)
        WHEN perm.class = 6 THEN (SELECT name FROM sys.types WHERE user_type_id = perm.major_id)
        ELSE CAST(perm.major_id AS VARCHAR(10))
    END AS PermissionObject,
    CASE 
        WHEN perm.minor_id > 0 AND perm.class = 1 THEN COL_NAME(perm.major_id, perm.minor_id)
        ELSE NULL
    END AS ColumnName
FROM sys.database_principals pr
JOIN sys.database_permissions perm ON pr.principal_id = perm.grantee_principal_id
ORDER BY PrincipalName, PermissionClass, PermissionObject, permission_name;
GO

-- List permissions for a specific principal
SELECT 
    perm.permission_name,
    perm.state_desc AS PermissionState,
    CASE 
        WHEN perm.class = 0 THEN 'Database'
        WHEN perm.class = 1 THEN 'Object or Column'
        WHEN perm.class = 3 THEN 'Schema'
        WHEN perm.class = 4 THEN 'Database Principal'
        ELSE CAST(perm.class AS VARCHAR(10))
    END AS PermissionClass,
    CASE 
        WHEN perm.class = 0 THEN DB_NAME()
        WHEN perm.class = 1 THEN OBJECT_NAME(perm.major_id)
        WHEN perm.class = 3 THEN SCHEMA_NAME(perm.major_id)
        WHEN perm.class = 4 THEN USER_NAME(perm.major_id)
        ELSE CAST(perm.major_id AS VARCHAR(10))
    END AS PermissionObject,
    CASE 
        WHEN perm.minor_id > 0 AND perm.class = 1 THEN COL_NAME(perm.major_id, perm.minor_id)
        ELSE NULL
    END AS ColumnName
FROM sys.database_permissions perm
JOIN sys.database_principals pr ON perm.grantee_principal_id = pr.principal_id
WHERE pr.name = 'HRClerks'
ORDER BY PermissionClass, PermissionObject, permission_name;
GO

-- List permissions on a specific object
SELECT 
    pr.name AS PrincipalName,
    pr.type_desc AS PrincipalType,
    perm.permission_name,
    perm.state_desc AS PermissionState,
    CASE 
        WHEN perm.minor_id > 0 THEN COL_NAME(perm.major_id, perm.minor_id)
        ELSE NULL
    END AS ColumnName
FROM sys.database_permissions perm
JOIN sys.database_principals pr ON perm.grantee_principal_id = pr.principal_id
WHERE perm.major_id = OBJECT_ID('HR.Employees')
ORDER BY PrincipalName, permission_name;
GO

-- List permissions on a specific schema
SELECT 
    pr.name AS PrincipalName,
    pr.type_desc AS PrincipalType,
    perm.permission_name,
    perm.state_desc AS PermissionState
FROM sys.database_permissions perm
JOIN sys.database_principals pr ON perm.grantee_principal_id = pr.principal_id
WHERE perm.class = 3 AND perm.major_id = SCHEMA_ID('HR')
ORDER BY PrincipalName, permission_name;
GO

-- List effective permissions for current user
SELECT 
    perm.permission_name,
    CASE 
        WHEN perm.class = 0 THEN 'Database'
        WHEN perm.class = 1 THEN 'Object or Column'
        WHEN perm.class = 3 THEN 'Schema'
        WHEN perm.class = 4 THEN 'Database Principal'
        ELSE CAST(perm.class AS VARCHAR(10))
    END AS PermissionClass,
    CASE 
        WHEN perm.class = 0 THEN DB_NAME()
        WHEN perm.class = 1 THEN OBJECT_NAME(perm.major_id)
        WHEN perm.class = 3 THEN SCHEMA_NAME(perm.major_id)
        WHEN perm.class = 4 THEN USER_NAME(perm.major_id)
        ELSE CAST(perm.major_id AS VARCHAR(10))
    END AS PermissionObject
FROM fn_my_permissions(NULL, 'DATABASE') perm
ORDER BY PermissionClass, PermissionObject, permission_name;
GO

-- List effective permissions for a specific object
SELECT * FROM fn_my_permissions('HR.Employees', 'OBJECT');
GO