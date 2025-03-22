-- =============================================
-- Security Best Practices Guide
-- Shows recommended patterns for SQL Server security
-- =============================================

USE HRSystem;
GO

-- 1. Role-Based Access Control (RBAC)
-- Create functional roles instead of individual permissions
CREATE ROLE HRDataEntry;
CREATE ROLE HRReporting;
CREATE ROLE PayrollProcessing;

-- Assign permissions to roles
GRANT SELECT, INSERT ON HR.EMP_Details TO HRDataEntry;
GRANT SELECT ON HR.SalaryReports TO HRReporting;
GRANT EXECUTE ON HR.ProcessPayroll TO PayrollProcessing;

-- 2. Least Privilege Principle
-- Give minimum required permissions
CREATE ROLE CustomerService;
GRANT SELECT ON HR.EMP_Details(EmployeeID, FirstName, LastName, Email) 
    TO CustomerService;

-- 3. Schema-Based Security
-- Group related objects in schemas
CREATE SCHEMA Confidential;
GO
CREATE TABLE Confidential.SalaryData(
    EmployeeID INT,
    Salary DECIMAL(10,2)
);
GRANT SELECT ON SCHEMA::Confidential TO PayrollProcessing;

-- 4. Application Security
-- Use application roles for better control
CREATE APPLICATION ROLE AppRole 
    WITH PASSWORD = 'SecurePass123!';
GRANT SELECT ON HR.EMP_Details TO AppRole;

-- 5. Stored Procedure Encapsulation
-- Use procedures instead of direct table access
CREATE PROCEDURE HR.UpdateEmployeeSalary
    @EmpID INT,
    @NewSalary DECIMAL(10,2)
AS
BEGIN
    UPDATE HR.EMP_Details 
    SET Salary = @NewSalary 
    WHERE EmployeeID = @EmpID;
END;
GRANT EXECUTE ON HR.UpdateEmployeeSalary TO PayrollProcessing;

-- 6. Regular Permission Review
CREATE VIEW HR.PermissionAudit
AS
SELECT 
    dp.name AS PrincipalName,
    dp.type_desc AS PrincipalType,
    OBJECT_NAME(p.major_id) AS ObjectName,
    p.permission_name,
    p.state_desc AS PermissionState
FROM sys.database_permissions p
JOIN sys.database_principals dp 
    ON p.grantee_principal_id = dp.principal_id;

-- 7. Separation of Duties
CREATE ROLE AuditReview;
DENY SELECT ON HR.EMP_Details TO AuditReview;
GRANT SELECT ON HR.AuditLogs TO AuditReview;

-- 8. Object Ownership Chains
-- Keep consistent schema ownership
ALTER AUTHORIZATION ON SCHEMA::HR TO dbo;

-- 9. Dynamic Data Masking
ALTER TABLE HR.EMP_Details
ALTER COLUMN SSN ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XX-",4)');

-- 10. Row-Level Security
CREATE FUNCTION HR.DepartmentAccessPredicate(@DepartmentID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS AccessResult
    WHERE IS_MEMBER('HRManagers') = 1 
    OR @DepartmentID IN (SELECT DeptID FROM HR.UserDepartments);

-- 11. Regular Cleanup
-- Remove unused permissions
CREATE PROCEDURE HR.CleanupUnusedPermissions
AS
BEGIN
    -- Example cleanup logic
    REVOKE ALL FROM InactiveUsers;
END;

-- 12. Monitoring and Auditing
CREATE SERVER AUDIT SecurityAudit
TO FILE (FILEPATH = 'C:\Audits\');

-- 13. Emergency Access Protocol
CREATE ROLE EmergencyAccess;
GRANT CONTROL ON DATABASE::HRSystem TO EmergencyAccess;

-- 14. Version Control for Permissions
-- Keep permission scripts in source control
-- Example comment format for tracking:
/* Permission Change Log
   Date: 2024-01-20
   Changed By: Admin
   Reason: Compliance requirement
*/

-- 15. Documentation
CREATE TABLE HR.SecurityDocumentation(
    RoleName NVARCHAR(128),
    Purpose NVARCHAR(MAX),
    LastReviewed DATE,
    ApprovedBy NVARCHAR(128)
);