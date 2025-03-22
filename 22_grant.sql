-- =============================================
-- GRANT Commands Guide
-- Shows how to give permissions to users/roles
-- =============================================

USE HRSystem;
GO

-- 1. Basic Table Permissions
-- Give basic read access to HR clerks
GRANT SELECT ON HR.EMP_Details TO HRClerks;

-- Give full access to HR managers
GRANT SELECT, INSERT, UPDATE, DELETE ON HR.EMP_Details TO HRManagers;

-- 2. Multiple Object Permissions
-- Grant access to multiple HR tables at once
GRANT SELECT, INSERT ON HR.Departments, HR.Locations TO HRClerks;

-- 3. Schema-Wide Permissions
-- Give read access to everything in HR schema
GRANT SELECT ON SCHEMA::HR TO DataAnalysts;

-- 4. Column-Level Permissions
-- Allow payroll to see only salary-related columns
GRANT SELECT ON HR.EMP_Details(EmployeeID, Salary, Bonus) TO PayrollStaff;

-- 5. WITH GRANT OPTION
-- Allow HR managers to give permissions to others
GRANT SELECT ON HR.Departments TO HRManagers WITH GRANT OPTION;

-- 6. Stored Procedure Execution
-- Allow clerks to run specific procedures
GRANT EXECUTE ON HR.AddNewEmployee TO HRClerks;
GRANT EXECUTE ON HR.UpdateContactInfo TO HRClerks;

-- 7. View Permissions
-- Grant access to specific views
GRANT SELECT ON HR.EmployeeSummary TO Reports;
GRANT SELECT ON HR.DepartmentBudgets TO HRManagers;

-- 8. Function Execution
-- Allow use of specific functions
GRANT EXECUTE ON HR.CalculateTax TO PayrollStaff;
GRANT EXECUTE ON HR.GetEmployeeDetails TO HRClerks;

-- 9. Database-Level Permissions
-- Allow creating new tables
GRANT CREATE TABLE TO HRManagers;
GRANT CREATE VIEW TO DataAnalysts;

-- 10. Server-Level Permissions
-- Allow monitoring server status
GRANT VIEW SERVER STATE TO ITSupport;
GRANT ALTER ANY DATABASE TO DBAdmins;

-- 11. Application Role Permissions
-- Grant permissions to application role
GRANT SELECT ON HR.EMP_Details TO HRApplication;
GRANT EXECUTE ON HR.GetEmployeeCount TO HRApplication;

-- 12. Role to Role Permissions
-- Grant permissions through role hierarchy
GRANT SELECT ON HR.SalaryReports TO PayrollManagers;
ALTER ROLE PayrollManagers ADD MEMBER PayrollStaff;

-- 13. Backup Permissions
-- Allow backup operations
GRANT BACKUP DATABASE TO BackupOperators;
GRANT BACKUP LOG TO BackupOperators;

-- 14. Special Permissions
-- Allow running DBCC commands
GRANT VIEW DATABASE STATE TO DBMonitors;

-- 15. Chain of Permissions
-- Create permission inheritance
GRANT SELECT ON HR.Projects TO ProjectManagers WITH GRANT OPTION;
GRANT SELECT ON HR.Tasks TO ProjectManagers WITH GRANT OPTION;