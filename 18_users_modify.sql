-- =============================================
-- SQL Server User Modification Guide
-- =============================================

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