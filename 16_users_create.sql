-- =============================================
-- SQL Server User Creation Guide
-- =============================================
/*
-- User Creation Complete Guide
-- SQL Server user management involves creating and managing different types of security principals that can access and perform operations in SQL Server instances and databases. This includes SQL logins, database users, and application roles, each serving specific authentication and authorization purposes.

Facts and Notes:
- Supports both Windows and SQL Server authentication
- Database users are database-level principals
- Logins are server-level principals
- Contained database users don't require server logins
- Certificates can be used for user authentication
- Application roles provide application-level security
- Users can be assigned to multiple roles
- Default schema affects object resolution

Important Considerations:
- Password policies affect SQL authentication
- Windows authentication is generally more secure
- Contained databases require special configuration
- Certificate-based users need certificate maintenance
- Service accounts should use minimal permissions
- Regular security audit recommended
- Password complexity requirements must be met
- Login names must be unique at server level

1. Create SQL Server Authentication Login: This section demonstrates creating a basic SQL Server authentication login with password.
2. Create Windows Authentication Login: This section shows creating a login using Windows authentication for domain users.
3. Create Database User from SQL Login: This section covers mapping SQL Server logins to database users.
4. Create Database User from Windows Login: This section illustrates creating database users for Windows authentication logins.
5. Create User Without Login: This section demonstrates creating contained database users independent of server logins.
6. Create User Mapped to Certificate: This section shows certificate-based user authentication setup.
7. Create Application Role: This section covers creating application-level security roles.
8. Create User with Default Schema: This section illustrates user creation with schema binding.
9. Create Group User: This section demonstrates creating and managing database roles and role membership.
10. Create Service Account User: This section shows creating and configuring service account users.

Author: Nikhil Shrivastav
Date: February 2025
*/

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