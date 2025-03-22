/*
    This script demonstrates how to rename various schema objects in a SQL Server database using the sp_rename system stored procedure.

    Steps:
    1. Renaming Tables: Renames the 'HR.EMP_Details' table to 'Employee_Details'.
    2. Renaming Columns: Renames the 'FirstName' column in the 'HR.Employee_Details' table to 'GivenName'.
    3. Renaming Constraints: Renames the 'CHK_Salary_Range' check constraint to 'CHK_Employee_Salary_Range'.
    4. Renaming Indexes: Renames the 'IX_EMP_Details_Email' index in the 'HR.Employee_Details' table to 'IX_Employee_Details_Email'.
    5. Renaming Views: Renames the 'vw_EmployeeDetails' view to 'vw_EmployeeFullDetails'.
    6. Renaming Stored Procedures: Renames the 'sp_UpdateEmployeeSalary' stored procedure to 'sp_UpdateEmployeeCompensation'.
    7. Renaming Triggers: Renames the 'trg_AuditEmployeeChanges' trigger to 'trg_TrackEmployeeModifications'.
    8. Renaming User-Defined Functions: Renames the 'fn_GetEmployeeYearsOfService' user-defined function to 'fn_CalculateEmployeeTenure'.

    Author: [Your Name]
    Date: [Current Date]
*/

-- SQL code for renaming schema objects using sp_rename
USE HRSystem;
GO

-- 1. Renaming Tables
EXEC sp_rename 'HR.EMP_Details', 'Employee_Details';
GO

-- 2. Renaming Columns
EXEC sp_rename 'HR.Employee_Details.FirstName', 'GivenName', 'COLUMN';
GO

-- 3. Renaming Constraints
EXEC sp_rename 'HR.CHK_Salary_Range', 'CHK_Employee_Salary_Range';
GO

-- 4. Renaming Indexes
EXEC sp_rename 'HR.Employee_Details.IX_EMP_Details_Email', 'IX_Employee_Details_Email';
GO

-- 5. Renaming Views
EXEC sp_rename 'HR.vw_EmployeeDetails', 'vw_EmployeeFullDetails';
GO

-- 6. Renaming Stored Procedures
EXEC sp_rename 'HR.sp_UpdateEmployeeSalary', 'sp_UpdateEmployeeCompensation';
GO

-- 7. Renaming Triggers
EXEC sp_rename 'HR.trg_AuditEmployeeChanges', 'trg_TrackEmployeeModifications';
GO

-- 8. Renaming User-Defined Functions
EXEC sp_rename 'HR.fn_GetEmployeeYearsOfService', 'fn_CalculateEmployeeTenure';
GO