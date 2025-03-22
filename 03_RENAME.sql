USE HRSystem;
GO

-- 1. Renaming Schema Objects using EXEC sp_rename
-- Note: Direct schema renaming is not possible, need to create new and transfer objects

-- 2. Renaming Tables
EXEC sp_rename 'HR.EMP_Details', 'Employee_Details';
GO

-- 3. Renaming Columns
EXEC sp_rename 'HR.Employee_Details.FirstName', 'GivenName', 'COLUMN';
GO

-- 4. Renaming Constraints
EXEC sp_rename 'HR.CHK_Salary_Range', 'CHK_Employee_Salary_Range';
GO

-- 5. Renaming Indexes
EXEC sp_rename 'HR.Employee_Details.IX_EMP_Details_Email', 'IX_Employee_Details_Email';
GO

-- 6. Renaming Views
EXEC sp_rename 'HR.vw_EmployeeDetails', 'vw_EmployeeFullDetails';
GO

-- 7. Renaming Stored Procedures
EXEC sp_rename 'HR.sp_UpdateEmployeeSalary', 'sp_UpdateEmployeeCompensation';
GO

-- 8. Renaming Triggers
EXEC sp_rename 'HR.trg_AuditEmployeeChanges', 'trg_TrackEmployeeModifications';
GO

-- 9. Renaming User-Defined Functions
EXEC sp_rename 'HR.fn_GetEmployeeYearsOfService', 'fn_CalculateEmployeeTenure';
GO