-- =============================================
-- SQL Server ROLES Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating Database Roles
-- Create a standard database role
CREATE ROLE HRManagers;
GO

-- Create a database role with authorization
CREATE ROLE PayrollAdmins AUTHORIZATION dbo;
GO

-- Create an application role
CREATE APPLICATION ROLE HRApplication 
    WITH PASSWORD = 'AppP@ssw0rd1',
    DEFAULT_SCHEMA = HR;
GO

-- 2. Altering Database Roles
-- Change the name of a role
ALTER ROLE HRManagers WITH NAME = HRSupervisors;
GO

-- Change the owner of a role
ALTER AUTHORIZATION ON ROLE::PayrollAdmins TO SQLUser2Renamed;
GO

-- Modify an application role
ALTER APPLICATION ROLE HRApplication 
    WITH PASSWORD = 'NewAppP@ssw0rd1',
    DEFAULT_SCHEMA = Sales;
GO

-- 3. Managing Role Membership
-- Add a user to a role
ALTER ROLE HRSupervisors ADD MEMBER SQLUser1;
GO

-- Add multiple users to a role
ALTER ROLE PayrollAdmins ADD MEMBER SQLUser2Renamed;
ALTER ROLE PayrollAdmins ADD MEMBER [DOMAIN\WindowsUser1];
GO

-- Remove a user from a role
ALTER ROLE HRSupervisors DROP MEMBER SQLUser1;
GO

-- Add a role to another role (nested roles)
ALTER ROLE db_datareader ADD MEMBER HRSupervisors;
GO

-- 4. Granting Permissions to Roles
-- Grant database-level permissions
GRANT CREATE TABLE, CREATE VIEW TO HRSupervisors;
GO

-- Grant schema-level permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::HR TO HRSupervisors;
GO

-- Grant object-level permissions
GRANT SELECT, INSERT, UPDATE ON HR.Departments TO PayrollAdmins;
GO

-- Grant column-level permissions
GRANT SELECT ON HR.Employees(EmployeeID, FirstName, LastName) TO HRSupervisors;
GO

-- Grant execute permissions on stored procedures
GRANT EXECUTE ON HR.AddEmployee TO HRSupervisors;
GO

-- 5. Dropping Database Roles
-- Drop a standard database role
DROP ROLE HRSupervisors;
GO

-- Drop an application role
DROP APPLICATION ROLE HRApplication;
GO

-- 6. Querying Role Information
-- List all database roles
SELECT 
    name AS RoleName,
    type_desc AS RoleType,
    is_fixed_role,
    create_date,
    modify_date,
    SUSER_SNAME(owning_principal_id) AS RoleOwner
FROM sys.database_principals
WHERE type IN ('A', 'R')
ORDER BY is_fixed_role DESC, RoleType, RoleName;
GO

-- List application roles
SELECT 
    name AS ApplicationRoleName,
    create_date,
    modify_date,
    default_schema_name AS DefaultSchema
FROM sys.database_principals
WHERE type = 'A'
ORDER BY ApplicationRoleName;
GO

-- List role members
SELECT 
    r.name AS RoleName,
    m.name AS MemberName,
    m.type_desc AS MemberType,
    m.default_schema_name AS DefaultSchema,
    m.create_date,
    m.modify_date
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
ORDER BY RoleName, MemberName;
GO

-- List nested role memberships (roles that are members of other roles)
SELECT 
    r.name AS ParentRoleName,
    m.name AS ChildRoleName,
    m.create_date,
    m.modify_date
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
WHERE m.type = 'R'
ORDER BY ParentRoleName, ChildRoleName;
GO

-- List role permissions
SELECT 
    pr.name AS RoleName,
    pr.type_desc AS RoleType,
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
WHERE pr.type IN ('A', 'R')
ORDER BY RoleName, PermissionClass, PermissionObject, permission_name;
GO

-- List fixed database roles and their descriptions
SELECT 
    name AS FixedRoleName,
    create_date,
    modify_date,
    CASE name
        WHEN 'db_owner' THEN 'Members can perform all configuration and maintenance activities on the database.'
        WHEN 'db_securityadmin' THEN 'Members can modify role membership and manage permissions.'
        WHEN 'db_accessadmin' THEN 'Members can add or remove access to the database.'
        WHEN 'db_backupoperator' THEN 'Members can back up the database.'
        WHEN 'db_ddladmin' THEN 'Members can run any DDL command in the database.'
        WHEN 'db_datawriter' THEN 'Members can add, delete, or change data in all user tables.'
        WHEN 'db_datareader' THEN 'Members can read all data from all user tables.'
        WHEN 'db_denydatawriter' THEN 'Members cannot add, modify, or delete any data in the user tables.'
        WHEN 'db_denydatareader' THEN 'Members cannot read any data in the user tables.'
    END AS Description
FROM sys.database_principals
WHERE is_fixed_role = 1
ORDER BY FixedRoleName;
GO