-- =============================================
-- DENY Commands Guide
-- Shows how to explicitly prevent access
-- =============================================

USE HRSystem;
GO

-- 1. Basic Table Denial
-- Prevent HR clerks from deleting records
DENY DELETE ON HR.EMP_Details TO HRClerks;

-- 2. Column Level Denial
-- Prevent viewing sensitive salary information
DENY SELECT ON HR.EMP_Details(Salary, BankAccount) TO HRClerks;

-- 3. Schema Level Denial
-- Prevent access to entire payroll schema
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Payroll TO Interns;

-- 4. Override GRANT
-- Even if someone GRANTs permission, DENY will prevail
GRANT SELECT ON HR.SalaryHistory TO HRClerks;  -- This won't work
DENY SELECT ON HR.SalaryHistory TO HRClerks;   -- This takes precedence

-- 5. Multiple Object Denial
-- Prevent access to multiple sensitive tables
DENY SELECT ON HR.Salaries, HR.BankDetails TO Contractors;

-- 6. Procedure Execution Denial
-- Prevent running specific procedures
DENY EXECUTE ON HR.UpdateSalary TO HRClerks;
DENY EXECUTE ON HR.ModifyBenefits TO Temps;

-- 7. View Access Denial
-- Prevent access to specific views
DENY SELECT ON HR.ExecutiveSalaries TO HRClerks;
DENY SELECT ON HR.ConfidentialReports TO Contractors;

-- 8. Database Level Denial
-- Prevent creating objects
DENY CREATE TABLE TO Interns;
DENY CREATE VIEW TO Contractors;

-- 9. Cascading Denial
-- Deny will affect all users in role
DENY SELECT ON HR.PerformanceReviews TO TeamLeads;
ALTER ROLE TeamLeads ADD MEMBER NewManager;  -- NewManager can't view either

-- 10. Function Execution Denial
-- Prevent using specific functions
DENY EXECUTE ON HR.CalculateBonus TO HRClerks;
DENY EXECUTE ON HR.GetConfidentialData TO Contractors;

-- 11. Application Role Denial
-- Prevent application access to sensitive data
DENY SELECT ON HR.Salaries TO HRApplication;

-- 12. Specific Operation Denial
-- Prevent specific DML operations
DENY UPDATE ON HR.EMP_Details(Salary) TO HRClerks;
DENY INSERT ON HR.BonusPayments TO TeamLeads;

-- 13. Time-Based Reports Denial
-- Prevent access to historical data
DENY SELECT ON HR.SalaryHistory TO DataAnalysts;
DENY SELECT ON HR.AuditLogs TO HRClerks;

-- 14. Backup Operation Denial
-- Prevent backup operations
DENY BACKUP DATABASE TO Contractors;
DENY BACKUP LOG TO Temps;

-- 15. Server Level Denial
-- Prevent server monitoring
DENY VIEW SERVER STATE TO Interns;
DENY ALTER ANY DATABASE TO Contractors;