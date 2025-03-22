-- =============================================
-- SQL Server User Creation Guide
-- =============================================

USE master;
GO

-- 1. Create SQL Server Authentication Login
CREATE LOGIN JohnDoe 
WITH PASSWORD = 'StrongPass123!';

-- 2. Create Windows Authentication Login
CREATE LOGIN [DOMAIN\JaneSmith] 
FROM WINDOWS;

-- 3. Create Database User from SQL Login
USE HRSystem;
CREATE USER JohnDoe 
FOR LOGIN JohnDoe;

-- 4. Create Database User from Windows Login
CREATE USER [DOMAIN\JaneSmith] 
FOR LOGIN [DOMAIN\JaneSmith];

-- 5. Create User Without Login (Contained Database User)
CREATE USER ContainedUser 
WITH PASSWORD = 'Pass123!';

-- 6. Create User Mapped to Certificate
CREATE CERTIFICATE HRCertificate
WITH SUBJECT = 'HR Department Certificate';
CREATE USER CertUser 
FOR CERTIFICATE HRCertificate;

-- 7. Create Application Role
CREATE APPLICATION ROLE HRApp 
WITH PASSWORD = 'AppPass123!';

-- 8. Create User with Default Schema
CREATE USER SchemaUser 
FOR LOGIN JohnDoe 
WITH DEFAULT_SCHEMA = HR;

-- 9. Create Group User (Database Role)
CREATE ROLE HRStaff;
CREATE USER NewHRUser 
FOR LOGIN NewHRLogin;
ALTER ROLE HRStaff 
ADD MEMBER NewHRUser;

-- 10. Create Service Account User
CREATE LOGIN ServiceAccount 
WITH PASSWORD = 'Service123!',
CHECK_POLICY = OFF;
CREATE USER ServiceUser 
FOR LOGIN ServiceAccount;