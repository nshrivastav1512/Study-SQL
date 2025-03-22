-- =============================================
-- SQL Server User Modification Guide
-- =============================================
/*
-- User Modification Complete Guide
-- SQL Server provides various ALTER statements for modifying existing users, logins, and roles. These statements allow administrators to update security principal properties, change authentication settings, modify role memberships, and manage database access without recreating the principals.

Facts and Notes:
- ALTER statements modify existing security principals
- Supports both server and database level modifications
- Can change names, passwords, and default schemas
- Allows enabling/disabling logins
- Supports role membership changes
- Can modify authentication settings
- Fixes orphaned users
- Changes schema ownership

Important Considerations:
- Some modifications require server admin privileges
- Password changes follow policy requirements
- Renaming users may affect dependent objects
- Login disabling affects all database access
- Schema changes impact object resolution
- Connection settings affect new connections only
- Certificate mappings require certificate maintenance
- Role membership changes take effect immediately

1. Rename User: This section demonstrates changing a database user's name.
2. Change Default Schema: This section shows modifying a user's default schema assignment.
3. Change Login Password: This section covers updating SQL authentication passwords.
4. Enable/Disable Login: This section illustrates controlling login access without deletion.
5. Change User Role Membership: This section demonstrates adding and removing users from roles.
6. Modify Login Authentication Mode: This section shows configuring password policies and expiration.
7. Map User to Different Login: This section covers remapping database users to different logins.
8. Change Database Access: This section illustrates modifying user database settings.
9. Modify Application Role: This section demonstrates updating application role properties.
10. Fix Orphaned User: This section shows resolving orphaned user issues.
11. Change Connection Settings: This section covers modifying login default connection properties.
12. Modify Service Account Settings: This section illustrates configuring service account security settings.
13. Change Certificate Mapping: This section demonstrates updating certificate-based user configurations.
14. Modify User Connection Limits: This section shows setting database access limitations.
15. Change Schema Ownership: This section covers transferring schema ownership between users.

Author: Nikhil Shrivastav
Date: February 2025
*/

USE HRSystem;
GO

-- 1. Rename User
ALTER USER JohnDoe
WITH NAME = JohnDoeNew;

-- 2. Change Default Schema
ALTER USER JohnDoeNew
WITH DEFAULT_SCHEMA = Sales;

-- 3. Change Login Password
ALTER LOGIN JohnDoeNew
WITH PASSWORD = 'NewPass123!';

-- 4. Enable/Disable Login
ALTER LOGIN JohnDoeNew DISABLE;  -- Disable
ALTER LOGIN JohnDoeNew ENABLE;   -- Enable

-- 5. Change User Role Membership
ALTER ROLE HRStaff
ADD MEMBER JohnDoeNew;

ALTER ROLE HRStaff
DROP MEMBER JohnDoeNew;

-- 6. Modify Login Authentication Mode
ALTER LOGIN JohnDoeNew
WITH CHECK_POLICY = ON,
     CHECK_EXPIRATION = ON;

-- 7. Map User to Different Login
ALTER USER JohnDoeNew
WITH LOGIN = NewLoginName;

-- 8. Change Database Access
ALTER USER JohnDoeNew
WITH DEFAULT_LANGUAGE = French;

-- 9. Modify Application Role
ALTER APPLICATION ROLE HRApp
WITH PASSWORD = 'NewAppPass123!';

-- 10. Fix Orphaned User
ALTER USER JohnDoeNew
WITH LOGIN = JohnDoeNew;

-- 11. Change Connection Settings
ALTER LOGIN JohnDoeNew
WITH 
    DEFAULT_DATABASE = HRSystem,
    DEFAULT_LANGUAGE = [us_english];

-- 12. Modify Service Account Settings
ALTER LOGIN ServiceAccount
WITH CHECK_POLICY = OFF,
     CHECK_EXPIRATION = OFF;

-- 13. Change Certificate Mapping
ALTER USER CertUser
WITH NAME = NewCertUser;

-- 14. Modify User Connection Limits
ALTER LOGIN JohnDoeNew
WITH DEFAULT_DATABASE = HRSystem;

-- 15. Change Schema Ownership
ALTER AUTHORIZATION 
ON SCHEMA::HR 
TO JohnDoeNew;