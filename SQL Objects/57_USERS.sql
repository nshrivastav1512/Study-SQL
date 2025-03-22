-- =============================================
-- SQL Server USERS Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating Database Users
-- Create a user mapped to a SQL Server login
CREATE USER SQLUser1 FOR LOGIN SQLLogin1;
GO

-- Create a user with a custom default schema
CREATE USER SQLUser2 FOR LOGIN SQLLogin2 WITH DEFAULT_SCHEMA = HR;
GO

-- Create a Windows user mapped to a Windows login
CREATE USER [DOMAIN\WindowsUser1] FOR LOGIN [DOMAIN\WindowsUser1];
GO

-- Create a Windows group user mapped to a Windows group login
CREATE USER [DOMAIN\HRGroup] FOR LOGIN [DOMAIN\HRGroup];
GO

-- Create a user without login (contained user) - for contained databases only
-- Note: Database must be set to CONTAINMENT = PARTIAL first
CREATE USER ContainedUser1 WITH PASSWORD = 'StrongP@ssw0rd3';
GO

-- Create a user based on a certificate
-- First create a certificate in the database
CREATE CERTIFICATE UserCert
    WITH SUBJECT = 'Certificate for user creation';
GO

CREATE USER CertUser FROM CERTIFICATE UserCert;
GO

-- Create a user based on an asymmetric key
-- First create an asymmetric key in the database
CREATE ASYMMETRIC KEY UserAsymKey
    WITH ALGORITHM = RSA_2048;
GO

CREATE USER AsymKeyUser FROM ASYMMETRIC KEY UserAsymKey;
GO

-- Create a user without specifying a login or authentication method
-- This is useful for granting permissions to an entity that doesn't need to connect
CREATE USER NoLoginUser WITHOUT LOGIN;
GO

-- Create an Azure Active Directory user (SQL Azure only)
-- CREATE USER [user@domain.com] FROM EXTERNAL PROVIDER;
-- GO

-- 2. Altering Database Users
-- Change the default schema for a user
ALTER USER SQLUser1 WITH DEFAULT_SCHEMA = Sales;
GO

-- Change the name of a user
ALTER USER SQLUser2 WITH NAME = SQLUser2Renamed;
GO

-- Map a user to a different login
ALTER USER SQLUser1 WITH LOGIN = SQLLogin2;
GO

-- Change the password for a contained user
ALTER USER ContainedUser1 WITH PASSWORD = 'NewStrongP@ssw0rd3';
GO

-- 3. Dropping Database Users
-- Drop a SQL user
DROP USER SQLUser1;
GO

-- Drop a Windows user
DROP USER [DOMAIN\WindowsUser1];
GO

-- Drop a certificate-based user
DROP USER CertUser;
GO

-- Drop an asymmetric key-based user
DROP USER AsymKeyUser;
GO

-- 4. Managing User Properties and Permissions
-- Grant database-level permissions to a user
GRANT CREATE TABLE TO SQLUser2Renamed;
GO

-- Add a user to a database role
ALTER ROLE db_datareader ADD MEMBER SQLUser2Renamed;
GO

-- Remove a user from a database role
ALTER ROLE db_datareader DROP MEMBER SQLUser2Renamed;
GO

-- Grant object-level permissions to a user
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::HR TO SQLUser2Renamed;
GO

-- 5. Querying User Information
-- List all database users
SELECT 
    name AS UserName,
    type_desc AS UserType,
    authentication_type_desc AS AuthenticationType,
    default_schema_name AS DefaultSchema,
    create_date,
    modify_date,
    CASE 
        WHEN is_fixed_role = 1 THEN 'Fixed Role'
        ELSE 'Regular User'
    END AS UserCategory
FROM sys.database_principals
WHERE type IN ('S', 'U', 'G', 'C', 'K', 'E', 'X')
  AND is_fixed_role = 0
  AND name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
ORDER BY UserType, UserName;
GO

-- List users mapped to logins
SELECT 
    dp.name AS UserName,
    dp.type_desc AS UserType,
    dp.default_schema_name AS DefaultSchema,
    sp.name AS LoginName,
    sp.type_desc AS LoginType
FROM sys.database_principals dp
LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid
WHERE dp.type IN ('S', 'U', 'G')
  AND dp.is_fixed_role = 0
  AND dp.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
ORDER BY UserType, UserName;
GO

-- List contained users (SQL Server 2012 and later)
SELECT 
    name AS UserName,
    type_desc AS UserType,
    authentication_type_desc AS AuthenticationType,
    default_schema_name AS DefaultSchema,
    create_date,
    modify_date
FROM sys.database_principals
WHERE authentication_type > 0
  AND type = 'S'
ORDER BY UserName;
GO

-- List certificate and asymmetric key users
SELECT 
    dp.name AS UserName,
    dp.type_desc AS UserType,
    dp.create_date,
    dp.modify_date,
    CASE 
        WHEN dp.type = 'C' THEN c.name 
        WHEN dp.type = 'K' THEN k.name
        ELSE NULL
    END AS CertificateOrKeyName
FROM sys.database_principals dp
LEFT JOIN sys.certificates c ON dp.sid = c.sid
LEFT JOIN sys.asymmetric_keys k ON dp.sid = k.sid
WHERE dp.type IN ('C', 'K')
ORDER BY UserType, UserName;
GO

-- List database role memberships
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

-- List user permissions
SELECT 
    pr.name AS UserName,
    pr.type_desc AS UserType,
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
WHERE pr.type IN ('S', 'U', 'G', 'C', 'K', 'E', 'X')
  AND pr.is_fixed_role = 0
  AND pr.name NOT IN ('dbo', 'guest', 'INFORMATION_SCHEMA', 'sys')
ORDER BY UserName, PermissionClass, PermissionObject, permission_name;
GO