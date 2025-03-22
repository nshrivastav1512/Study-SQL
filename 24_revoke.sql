-- =============================================
-- REVOKE Commands Guide
-- Shows how to remove previously granted permissions
-- =============================================

USE HRSystem;
GO

-- 1. Basic Permission Removal
-- Remove select permission from HR clerks
REVOKE SELECT ON HR.EMP_Details FROM HRClerks;

-- 2. Multiple Permission Removal
-- Remove multiple permissions at once
REVOKE SELECT, INSERT, UPDATE ON HR.Departments FROM HRClerks;

-- 3. Schema Level Revocation
-- Remove all permissions on HR schema
REVOKE SELECT ON SCHEMA::HR FROM DataAnalysts;

-- 4. Column Level Revocation
-- Remove access to specific columns
REVOKE SELECT ON HR.EMP_Details(Salary, Bonus) FROM PayrollStaff;

-- 5. CASCADE Option
-- Remove permissions and dependent permissions
REVOKE SELECT ON HR.Departments FROM HRManagers CASCADE;

-- 6. Procedure Execution Revocation
-- Remove ability to execute procedures
REVOKE EXECUTE ON HR.AddNewEmployee FROM HRClerks;
REVOKE EXECUTE ON HR.UpdateContactInfo FROM HRClerks;

-- 7. View Access Revocation
-- Remove access to views
REVOKE SELECT ON HR.EmployeeSummary FROM Reports;
REVOKE SELECT ON HR.DepartmentBudgets FROM HRManagers;

-- 8. Database Level Revocation
-- Remove database-wide permissions
REVOKE CREATE TABLE FROM HRManagers;
REVOKE CREATE VIEW FROM DataAnalysts;

-- 9. Role Permission Revocation
-- Remove permissions from entire role
REVOKE SELECT ON HR.SalaryReports FROM PayrollManagers;

-- 10. Server Level Revocation
-- Remove server-level permissions
REVOKE VIEW SERVER STATE FROM ITSupport;
REVOKE ALTER ANY DATABASE FROM DBAdmins;

-- 11. Application Role Revocation
-- Remove application permissions
REVOKE SELECT ON HR.EMP_Details FROM HRApplication;
REVOKE EXECUTE ON HR.GetEmployeeCount FROM HRApplication;

-- 12. Function Execution Revocation
-- Remove function usage permissions
REVOKE EXECUTE ON HR.CalculateTax FROM PayrollStaff;
REVOKE EXECUTE ON HR.GetEmployeeDetails FROM HRClerks;

-- 13. Backup Permission Revocation
-- Remove backup capabilities
REVOKE BACKUP DATABASE FROM BackupOperators;
REVOKE BACKUP LOG FROM BackupOperators;

-- 14. Grant Option Revocation
-- Remove ability to grant permissions to others
REVOKE GRANT OPTION FOR SELECT ON HR.Projects FROM ProjectManagers;

-- 15. Clean Up All Permissions
-- Remove all permissions for a user
REVOKE ALL ON HR.EMP_Details FROM Contractors;