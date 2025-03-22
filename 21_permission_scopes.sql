-- =============================================
-- Permission Scopes Guide
-- Shows different levels where permissions can be set
-- =============================================

USE HRSystem;
GO

-- 1. Server Level Permissions
-- These affect the entire SQL Server instance
GRANT VIEW SERVER STATE TO SQLJohn;        -- Can monitor server health
GRANT ALTER ANY DATABASE TO ServerAdmins;  -- Can create/modify databases

-- 2. Database Level Permissions
-- These affect operations within a specific database
GRANT CREATE TABLE TO HRManagers;          -- Can create new tables
GRANT BACKUP DATABASE TO BackupOperators;  -- Can backup the database

-- 3. Schema Level Permissions
-- These affect all objects within a schema
GRANT SELECT, INSERT, UPDATE ON SCHEMA::HR TO HRClerks;  -- Access to all HR schema
GRANT CONTROL ON SCHEMA::Payroll TO PayrollStaff;        -- Full control of Payroll schema

-- 4. Object Level Permissions
-- These affect specific objects like tables, views, procedures
GRANT SELECT ON HR.EMP_Details TO HRClerks;        -- Can view employee details
GRANT EXECUTE ON HR.CalculateSalary TO PayrollStaff;  -- Can run salary calculations

-- 5. Column Level Permissions
-- These affect specific columns in a table
GRANT SELECT ON HR.EMP_Details(FirstName, LastName, Email) TO Reception;  -- Can only see basic info
GRANT UPDATE ON HR.EMP_Details(Salary) TO PayrollManagers;               -- Can update salaries

-- 6. Module Execution Permissions
-- These control who can run stored procedures, functions
GRANT EXECUTE ON HR.UpdateEmployeeDetails TO HRClerks;     -- Can run this procedure
GRANT EXECUTE ON HR.GetDepartmentBudget TO HRManagers;     -- Can run this function

-- 7. Role-Based Scope
-- Permissions given to roles are inherited by role members
CREATE ROLE DataAnalysts;
GRANT SELECT ON SCHEMA::HR TO DataAnalysts;    -- All analysts can read HR data
ALTER ROLE DataAnalysts ADD MEMBER JaneSmith;  -- Jane gets all analyst permissions

-- 8. Application Role Scope
-- Special permissions for applications
CREATE APPLICATION ROLE HRApplication
WITH PASSWORD = 'AppPass123!';
GRANT SELECT ON HR.EMP_Details TO HRApplication;  -- App can read employee data

-- 9. User-Defined Type Permissions
-- Control who can use custom data types
GRANT EXECUTE ON TYPE::HR.PhoneNumber TO HRClerks;  -- Can use phone number type

-- 10. Certificate-Based Scope
-- Permissions through certificates for special operations
CREATE CERTIFICATE SecurityCert
    WITH SUBJECT = 'Security Operations';
CREATE USER CertificateUser FOR CERTIFICATE SecurityCert;
GRANT CONTROL SERVER TO CertificateUser;  -- High-level access via certificate