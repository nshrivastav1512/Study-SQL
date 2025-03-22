-- =============================================
-- SQL Server User Deletion Guide
-- =============================================

USE HRSystem;
GO

-- 1. Basic User Deletion
DROP USER JohnDoeNew;

-- 2. Delete Login
DROP LOGIN JohnDoeNew;

-- 3. Delete User and Clean Up Permissions
-- First remove from roles
ALTER ROLE HRStaff DROP MEMBER JohnDoeNew;
-- Then remove permissions
REVOKE ALL FROM JohnDoeNew;
-- Finally drop user
DROP USER JohnDoeNew;

-- 4. Delete Application Role
DROP APPLICATION ROLE HRApp;

-- 5. Delete Database Role
DROP ROLE HRStaff;

-- 6. Clean Up Orphaned Users
-- First identify orphaned users
DECLARE @OrphanUser nvarchar(128);
DECLARE orphan_cursor CURSOR FOR
    SELECT name
    FROM sys.database_principals
    WHERE type IN ('S', 'U', 'G')
        AND authentication_type_desc = 'INSTANCE'
        AND NOT EXISTS (
            SELECT * 
            FROM sys.server_principals SP
            WHERE SP.sid = sys.database_principals.sid
        );

OPEN orphan_cursor;
FETCH NEXT FROM orphan_cursor INTO @OrphanUser;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC('DROP USER [' + @OrphanUser + ']');
    FETCH NEXT FROM orphan_cursor INTO @OrphanUser;
END

CLOSE orphan_cursor;
DEALLOCATE orphan_cursor;

-- 7. Delete Certificate User
DROP USER CertUser;
DROP CERTIFICATE HRCertificate;

-- 8. Delete User with Dependencies Check
IF EXISTS (
    SELECT 1 
    FROM sys.objects 
    WHERE schema_id IN (
        SELECT principal_id 
        FROM sys.database_principals 
        WHERE name = 'JohnDoeNew'
    )
)
BEGIN
    RAISERROR ('User owns schema objects. Clean up required.', 16, 1);
    RETURN;
END
ELSE
    DROP USER JohnDoeNew;

-- 9. Delete Windows Authentication User
DROP USER [DOMAIN\JaneSmith];
DROP LOGIN [DOMAIN\JaneSmith];

-- 10. Delete Service Account
-- First disable login
ALTER LOGIN ServiceAccount DISABLE;
-- Wait for connections to close
WAITFOR DELAY '00:00:05';
-- Then drop login and user
DROP USER ServiceUser;
DROP LOGIN ServiceAccount;