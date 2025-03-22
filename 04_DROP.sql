-- =============================================
-- DROP Keyword Complete Guide
-- =============================================

USE HRSystem;
GO

-- 1. Dropping Database Objects (Cautionary Examples)
-- Uncomment only what you need to drop

-- 1.1 Dropping a Database (USE master first to avoid being in the database you're dropping)
/*
USE master;
GO
DROP DATABASE HRSystem;
GO
*/

-- 2. Dropping Schemas
-- Note: Cannot drop schemas that contain objects
/*
DROP SCHEMA EXEC;
GO
*/

-- 3. Dropping Tables
-- Note: Tables with foreign key relationships must be dropped in the correct order
-- or foreign keys must be dropped first

-- 3.1 Dropping a table with no dependencies
/*
DROP TABLE HR.Performance_Reviews;
GO
*/

-- 3.2 Dropping a table with CASCADE to automatically drop dependent objects
-- (Use with extreme caution)
/*
DROP TABLE HR.EMP_Details CASCADE;
GO
*/

-- 4. Dropping Columns
ALTER TABLE HR.Departments
DROP COLUMN Description;
GO

-- 5. Dropping Constraints
ALTER TABLE HR.Departments
DROP CONSTRAINT FK_Departments_Locations;
GO

-- 6. Dropping Indexes
DROP INDEX IX_EMP_Details_Email ON HR.EMP_Details;
GO

-- 7. Dropping Views
DROP VIEW IF EXISTS HR.vw_EmployeeDetails;
GO

-- 8. Dropping Stored Procedures
DROP PROCEDURE HR.sp_UpdateEmployeeSalary;
GO

-- 9. Dropping Functions
DROP FUNCTION HR.fn_GetEmployeeYearsOfService;
GO

-- 10. Dropping Triggers
DROP TRIGGER HR.trg_AuditEmployeeChanges;
GO

-- 11. Dropping Users and Roles
DROP USER HRManager;
GO

-- 12. Dropping Multiple Objects in One Statement
DROP TABLE IF EXISTS 
    HR.EMP_Details_Audit,
    PAYROLL.Salary_History;
GO

-- 13. Dropping Temporary Objects
-- Create a temp table for demonstration
CREATE TABLE #TempEmployees (
    ID INT,
    Name VARCHAR(100)
);
GO

-- Drop the temp table
DROP TABLE #TempEmployees;
GO

-- 14. Conditional Drops using IF EXISTS
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Performance_Reviews' AND schema_id = SCHEMA_ID('HR'))
BEGIN
    DROP TABLE HR.Performance_Reviews;
END
GO

-- 15. Dropping with Dependencies Check
-- This will fail if there are dependencies
BEGIN TRY
    DROP TABLE HR.Departments;
    PRINT 'Table dropped successfully';
END TRY
BEGIN CATCH
    PRINT 'Cannot drop table due to dependencies: ' + ERROR_MESSAGE();
END CATCH
GO