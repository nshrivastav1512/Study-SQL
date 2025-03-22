-- =============================================
-- SQL Server LOGINS Guide
-- =============================================

USE master;
GO

-- 1. Creating SQL Server Logins
-- SQL Authentication Login
CREATE LOGIN SQLLogin1 WITH PASSWORD = 'StrongP@ssw0rd1';
GO

-- SQL Authentication Login with additional options
CREATE LOGIN SQLLogin2 WITH 
    PASSWORD = 'StrongP@ssw0rd2',
    DEFAULT_DATABASE = HRSystem,
    DEFAULT_LANGUAGE = us_english,
    CHECK_EXPIRATION = ON,
    CHECK_POLICY = ON;
GO

-- Windows Authentication Login (individual user)
CREATE LOGIN [DOMAIN\WindowsUser1] FROM WINDOWS;
GO

-- Windows Authentication Login (group)
CREATE LOGIN [DOMAIN\HRGroup] FROM WINDOWS;
GO

-- Creating a login from a certificate
-- First create a certificate in master database
CREATE CERTIFICATE LoginCert
    WITH SUBJECT = 'Certificate for login creation';
GO

CREATE LOGIN CertLogin FROM CERTIFICATE LoginCert;
GO

-- Creating a login from an asymmetric key
-- First create an asymmetric key in master database
CREATE ASYMMETRIC KEY LoginAsymKey
    WITH ALGORITHM = RSA_2048;
GO

CREATE LOGIN AsymKeyLogin FROM ASYMMETRIC KEY LoginAsymKey;
GO

-- 2. Altering SQL Server Logins
-- Change password
ALTER LOGIN SQLLogin1 WITH PASSWORD = 'NewStrongP@ssw0rd1';
GO

-- Change default database
ALTER LOGIN SQLLogin2 WITH DEFAULT_DATABASE = master;
GO

-- Change default language
ALTER LOGIN SQLLogin2 WITH DEFAULT_LANGUAGE = British;
GO

-- Enable or disable a login
ALTER LOGIN SQLLogin1 DISABLE;
GO

ALTER LOGIN SQLLogin1 ENABLE;
GO

-- Change password policy settings
ALTER LOGIN SQLLogin2 WITH CHECK_EXPIRATION = OFF, CHECK_POLICY = OFF;
GO

-- Unlock a login
ALTER LOGIN SQLLogin1 WITH PASSWORD = 'NewStrongP@ssw0rd1' UNLOCK;
GO

-- 3. Dropping SQL Server Logins
-- Drop a SQL Authentication login
DROP LOGIN SQLLogin1;
GO

-- Drop a Windows Authentication login
DROP LOGIN [DOMAIN\WindowsUser1];
GO

-- Drop a certificate-based login
DROP LOGIN CertLogin;
GO

-- Drop an asymmetric key-based login
DROP LOGIN AsymKeyLogin;
GO

-- 4. Managing Login Properties
-- Grant server-level permissions to a login
GRANT VIEW SERVER STATE TO SQLLogin2;
GO

-- Add a login to a server role
ALTER SERVER ROLE sysadmin ADD MEMBER SQLLogin2;
GO

-- Remove a login from a server role
ALTER SERVER ROLE sysadmin DROP MEMBER SQLLogin2;
GO

-- 5. Querying Login Information
-- List all logins
SELECT 
    name AS LoginName,
    type_desc AS LoginType,
    create_date,
    modify_date,
    is_disabled
FROM sys.server_principals
WHERE type IN ('S', 'U', 'G', 'C', 'K')
ORDER BY LoginType, LoginName;
GO

-- List SQL Authentication logins
SELECT 
    name AS LoginName,
    create_date,
    modify_date,
    is_disabled,
    LOGINPROPERTY(name, 'PasswordLastSetTime') AS PasswordLastSet,
    LOGINPROPERTY(name, 'DaysUntilExpiration') AS DaysUntilExpiration,
    LOGINPROPERTY(name, 'IsExpired') AS IsExpired,
    LOGINPROPERTY(name, 'IsMustChange') AS IsMustChange,
    LOGINPROPERTY(name, 'IsLocked') AS IsLocked,
    LOGINPROPERTY(name, 'LockoutTime') AS LockoutTime,
    LOGINPROPERTY(name, 'BadPasswordCount') AS BadPasswordCount,
    LOGINPROPERTY(name, 'BadPasswordTime') AS BadPasswordTime
FROM sys.sql_logins
ORDER BY LoginName;
GO

-- List Windows Authentication logins
SELECT 
    name AS LoginName,
    type_desc AS LoginType,
    default_database_name AS DefaultDatabase,
    default_language_name AS DefaultLanguage,
    create_date,
    modify_date,
    is_disabled
FROM sys.server_principals
WHERE type IN ('U', 'G')
ORDER BY LoginType, LoginName;
GO

-- List certificate and asymmetric key logins
SELECT 
    p.name AS LoginName,
    p.type_desc AS LoginType,
    p.create_date,
    p.modify_date,
    CASE 
        WHEN p.type = 'C' THEN c.name 
        WHEN p.type = 'K' THEN k.name
        ELSE NULL
    END AS CertificateOrKeyName
FROM sys.server_principals p
LEFT JOIN sys.certificates c ON p.sid = c.sid
LEFT JOIN sys.asymmetric_keys k ON p.sid = k.sid
WHERE p.type IN ('C', 'K')
ORDER BY LoginType, LoginName;
GO

-- List server role memberships
SELECT 
    r.name AS RoleName,
    m.name AS MemberName,
    m.type_desc AS MemberType,
    m.create_date,
    m.modify_date,
    m.is_disabled
FROM sys.server_role_members rm
JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
ORDER BY RoleName, MemberName;
GO

-- List login permissions
SELECT 
    p.name AS LoginName,
    p.type_desc AS LoginType,
    perm.permission_name,
    perm.state_desc AS PermissionState,
    CASE 
        WHEN perm.class = 100 THEN 'Server'
        WHEN perm.class = 101 THEN 'Server Role'
        WHEN perm.class = 105 THEN 'Endpoint'
        WHEN perm.class = 108 THEN 'Availability Group'
        ELSE CAST(perm.class AS VARCHAR(10))
    END AS PermissionClass,
    CASE 
        WHEN perm.class = 101 THEN OBJECT_NAME(perm.major_id)
        WHEN perm.class = 105 THEN (SELECT name FROM sys.endpoints WHERE endpoint_id = perm.major_id)
        WHEN perm.class = 108 THEN (SELECT name FROM sys.availability_groups WHERE group_id = perm.major_id)
        ELSE NULL
    END AS PermissionObject
FROM sys.server_principals p
JOIN sys.server_permissions perm ON p.principal_id = perm.grantee_principal_id
WHERE p.type IN ('S', 'U', 'G', 'C', 'K')
ORDER BY LoginName, PermissionClass, PermissionObject, permission_name;
GO