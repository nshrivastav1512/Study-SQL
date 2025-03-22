-- =============================================
-- DROP Keyword Complete Guide
-- =============================================
/*
Explnation: The DROP keyword is used to remove or delete various database objects in Microsoft SQL Server. It allows you to drop databases, schemas, tables, columns, constraints, indexes, views, stored procedures, functions, triggers, users, roles, and temporary objects. The DROP keyword is a powerful tool, but it should be used with caution as it permanently deletes the specified objects and their associated data.

1. Dropping Database Objects (Cautionary Examples): This section demonstrates various examples of dropping different types of database objects. It includes cautionary examples and provides guidance on how to drop objects safely.
1.1 Dropping a Database (USE master first to avoid being in the database you're dropping): This example shows how to drop a database using the DROP DATABASE statement. It is important to switch to the master database before dropping the target database to avoid being in the database being dropped.
2. Dropping Schemas: This section explains how to drop schemas using the DROP SCHEMA statement. It also highlights that schemas cannot be dropped if they contain objects.
3. Dropping Tables: This section demonstrates how to drop tables using the DROP TABLE statement. It covers scenarios where tables have no dependencies and where tables have foreign key relationships. It emphasizes the importance of dropping tables in the correct order or dropping foreign keys first.
3.1 Dropping a table with no dependencies: This example shows how to drop a table that has no dependencies using the DROP TABLE statement.
3.2 Dropping a table with CASCADE to automatically drop dependent objects (Use with extreme caution): This example demonstrates how to drop a table and automatically drop its dependent objects using the CASCADE option in the DROP TABLE statement. It warns about the potential risks and advises extreme caution when using CASCADE.
4. Dropping Columns: This section illustrates how to drop columns from a table using the ALTER TABLE statement with the DROP COLUMN clause.
5. Dropping Constraints:This section explains how to drop constraints from a table using the ALTER TABLE statement with the DROP CONSTRAINT clause.
6. Dropping Indexes:This section demonstrates how to drop indexes from a table using the DROP INDEX statement.
7. Dropping Views:This section shows how to drop views using the DROP VIEW statement.
8. Dropping Stored Procedures:This section explains how to drop stored procedures using the DROP PROCEDURE statement.
9. Dropping Functions:This section demonstrates how to drop functions using the DROP FUNCTION statement.
10. Dropping Triggers:This section illustrates how to drop triggers using the DROP TRIGGER statement.
11. Dropping Users and Roles:This section explains how to drop users and roles using the DROP USER and DROP ROLE statements.
12. Dropping Multiple Objects in One Statement:This section demonstrates how to drop multiple objects in a single statement using the DROP TABLE statement with the IF EXISTS clause.
13. Dropping Temporary Objects:This section shows how to drop temporary objects, such as temporary tables, using the DROP TABLE statement.
14. Conditional Drops using IF EXISTS:This section explains how to conditionally drop an object only if it exists using the IF EXISTS clause.
15. Dropping with Dependencies Check:This section demonstrates how to drop a table with a dependencies check using the TRY...CATCH block. It shows how to handle the scenario where the table cannot be dropped due to dependencies.

Author: Nikhil Shrivastav
Date: february 2025

*/

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