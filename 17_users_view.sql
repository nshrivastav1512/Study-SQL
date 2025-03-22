-- =============================================
-- SQL Server User Query Guide
-- =============================================

USE HRSystem;
GO

-- 1. View All Database Users
SELECT name, type_desc, create_date
FROM sys.database_principals
WHERE type IN ('S', 'U', 'G');

-- 2. View Server Logins
SELECT name, type_desc, create_date, is_disabled
FROM sys.server_principals
WHERE type IN ('S', 'U', 'G');

-- 3. View User-Role Memberships
SELECT 
    DP1.name AS DatabaseUserName,
    DP2.name AS RoleName
FROM sys.database_role_members DRM
JOIN sys.database_principals DP1
    ON DRM.member_principal_id = DP1.principal_id
JOIN sys.database_principals DP2
    ON DRM.role_principal_id = DP2.principal_id;

-- 4. View User Permissions
SELECT 
    CASE WHEN DP.name IS NULL 
        THEN 'No users found' 
        ELSE DP.name 
    END AS UserName,
    CASE WHEN PE.permission_name IS NULL 
        THEN 'No permissions found' 
        ELSE PE.permission_name 
    END AS PermissionName,
    CASE WHEN OB.name IS NULL 
        THEN 'No object' 
        ELSE OB.name 
    END AS ObjectName
FROM sys.database_principals DP
LEFT JOIN sys.database_permissions PE 
    ON DP.principal_id = PE.grantee_principal_id
LEFT JOIN sys.objects OB 
    ON PE.major_id = OB.object_id
WHERE DP.type IN ('S', 'U', 'G');

-- 5. View Orphaned Users
SELECT name AS OrphanedUser
FROM sys.database_principals
WHERE type IN ('S', 'U', 'G')
    AND authentication_type_desc = 'INSTANCE'
    AND NOT EXISTS (
        SELECT * 
        FROM sys.server_principals SP
        WHERE SP.sid = sys.database_principals.sid
    );

-- 6. View User Default Schemas
SELECT 
    name AS UserName,
    default_schema_name AS DefaultSchema
FROM sys.database_principals
WHERE type IN ('S', 'U', 'G')
    AND default_schema_name IS NOT NULL;

-- 7. View Database Access
SELECT 
    SP.name AS LoginName,
    SP.type_desc AS LoginType,
    CASE WHEN DP.name IS NULL 
        THEN 'No database access' 
        ELSE 'Has database access' 
    END AS DatabaseAccess
FROM sys.server_principals SP
LEFT JOIN sys.database_principals DP
    ON SP.sid = DP.sid
WHERE SP.type IN ('S', 'U', 'G');

-- 8. View Last Login Times
SELECT 
    login_name,
    MAX(login_time) AS LastLoginTime
FROM sys.dm_exec_sessions
GROUP BY login_name;

-- 9. View User-Created Objects
SELECT 
    DP.name AS UserName,
    OB.name AS ObjectName,
    OB.type_desc AS ObjectType,
    OB.create_date
FROM sys.objects OB
JOIN sys.database_principals DP
    ON OB.principal_id = DP.principal_id
WHERE DP.type IN ('S', 'U', 'G');

-- 10. View Connection Information
SELECT 
    login_name,
    COUNT(*) AS ConnectionCount,
    MIN(login_time) AS OldestConnection,
    MAX(login_time) AS NewestConnection
FROM sys.dm_exec_sessions
WHERE login_name IS NOT NULL
GROUP BY login_name;