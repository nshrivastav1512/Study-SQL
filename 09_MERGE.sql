-- =============================================
-- MERGE Operations Complete Guide
-- =============================================
/*
-- MERGE Keyword Complete Guide
-- The MERGE statement is a DML (Data Manipulation Language) command that combines INSERT, UPDATE, and DELETE operations in a single statement. It allows synchronizing a target table with a source dataset by performing multiple data modifications based on matching conditions. MERGE is particularly useful for data warehouse loading, slowly changing dimensions, and data synchronization scenarios.

Facts and Notes:
- Introduced in SQL Server 2008 and requires a minimum compatibility level of 100
- Provides atomic operation for multiple DML actions
- Supports both matched and unmatched conditions for source and target
- Can handle multiple rows with a single statement
- Requires HOLDLOCK hint to prevent potential race conditions
- Maximum of three MATCHED clauses allowed (MATCHED, NOT MATCHED BY TARGET, NOT MATCHED BY SOURCE)
- Cannot update the same row multiple times in a single MERGE statement
- Target table cannot participate in a foreign key reference during MERGE

Important Considerations:
- Always use explicit transaction control for consistency
- Include proper error handling to manage potential failures
- Be cautious with large dataset merges due to lock escalation
- Avoid updating matching columns during MERGE operation
- Consider using HOLDLOCK hint to prevent Halloween Protection issues
- Monitor transaction log usage during large MERGE operations
- Ensure proper indexing on matching columns for better performance
- Validate source data before MERGE to prevent constraint violations

1. Basic MERGE Operation: This section demonstrates the fundamental MERGE statement structure combining INSERT and UPDATE operations based on matching conditions between source and target tables.
2. MERGE with Multiple Conditions and OUTPUT: This section shows complex matching conditions with OUTPUT clause to capture the results of the merge operation, including tracking of inserted, updated, and deleted rows.
3. MERGE with Table Variable Source: This section illustrates using table variables as source data for MERGE operations, useful for small-scale data modifications and testing scenarios.
4. MERGE with Complex Join Source: This section demonstrates using complex joins and subqueries in the source dataset, allowing for sophisticated data matching and transformation logic.
5. MERGE with OUTPUT into Table: This section covers capturing MERGE operation results into a table for auditing and verification purposes, including tracking all changes made during the operation.
6. MERGE with Error Handling: This section shows implementing proper error handling and transaction management for MERGE operations, including rollback scenarios and business rule validation.
7. MERGE with Dynamic SQL: This section illustrates constructing and executing dynamic MERGE statements safely, including proper parameter handling and SQL injection prevention.
8. MERGE with Conditional Logic: This section demonstrates using complex conditional logic within MERGE operations, including CASE expressions and multiple criteria for matching and actions.
9. MERGE with Partition Hint: This section covers using table hints and handling partitioned tables in MERGE operations, including performance optimization techniques.

Author: Nikhil Shrivastav
Date: February 2025
*/

USE HRSystem;
GO

-- 1. Basic MERGE Operation
MERGE INTO HR.EMP_Details AS Target
USING (
    SELECT EmployeeID, FirstName, LastName, Email, DepartmentID, Salary
    FROM HR.TempEmployees
) AS Source
ON Target.EmployeeID = Source.EmployeeID
WHEN MATCHED THEN
    UPDATE SET 
        Target.FirstName = Source.FirstName,
        Target.LastName = Source.LastName,
        Target.Email = Source.Email,
        Target.ModifiedDate = GETDATE()
WHEN NOT MATCHED THEN
    INSERT (FirstName, LastName, Email, DepartmentID, Salary)
    VALUES (Source.FirstName, Source.LastName, Source.Email, 
            Source.DepartmentID, Source.Salary);

-- 2. MERGE with Multiple Conditions and OUTPUT
MERGE HR.Performance_Reviews AS Target
USING (
    SELECT e.EmployeeID, d.ManagerID as ReviewedBy, 
           GETDATE() as ReviewDate, 3 as DefaultRating
    FROM HR.EMP_Details e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
) AS Source
ON Target.EmployeeID = Source.EmployeeID 
   AND YEAR(Target.ReviewDate) = YEAR(GETDATE())
WHEN MATCHED THEN
    UPDATE SET 
        Target.ReviewedBy = Source.ReviewedBy,
        Target.ModifiedDate = GETDATE()
WHEN NOT MATCHED THEN
    INSERT (EmployeeID, ReviewDate, Rating, ReviewedBy)
    VALUES (Source.EmployeeID, Source.ReviewDate, 
            Source.DefaultRating, Source.ReviewedBy)
WHEN NOT MATCHED BY SOURCE AND YEAR(Target.ReviewDate) = YEAR(GETDATE()) THEN
    DELETE
OUTPUT 
    $action AS MergeAction,
    inserted.ReviewID,
    deleted.ReviewID,
    inserted.EmployeeID;

-- 3. MERGE with Table Variable Source
DECLARE @SalaryUpdates TABLE (
    EmployeeID INT,
    NewSalary DECIMAL(12,2)
);

INSERT INTO @SalaryUpdates
VALUES (1000, 65000), (1001, 72000), (1002, 58000);

MERGE HR.EMP_Details AS Target
USING @SalaryUpdates AS Source
ON Target.EmployeeID = Source.EmployeeID
WHEN MATCHED AND Target.Salary <> Source.NewSalary THEN
    UPDATE SET 
        Target.Salary = Source.NewSalary,
        Target.ModifiedDate = GETDATE();

-- 4. MERGE with Complex Join Source
MERGE HR.Departments AS Target
USING (
    SELECT 
        d.DepartmentID,
        d.DepartmentName,
        e.EmployeeID as NewManagerID,
        d.LocationID
    FROM HR.Departments d
    CROSS APPLY (
        SELECT TOP 1 EmployeeID
        FROM HR.EMP_Details
        WHERE DepartmentID = d.DepartmentID
        ORDER BY HireDate DESC
    ) e
) AS Source
ON Target.DepartmentID = Source.DepartmentID
WHEN MATCHED THEN
    UPDATE SET 
        Target.ManagerID = Source.NewManagerID,
        Target.ModifiedDate = GETDATE();

-- 5. MERGE with OUTPUT into Table
DECLARE @MergeResults TABLE (
    Action VARCHAR(10),
    EmployeeID INT,
    OldSalary DECIMAL(12,2),
    NewSalary DECIMAL(12,2),
    ModifiedDate DATETIME
);

MERGE HR.EMP_Details AS Target
USING HR.SalaryAdjustments AS Source
ON Target.EmployeeID = Source.EmployeeID
WHEN MATCHED THEN
    UPDATE SET 
        Target.Salary = Source.NewSalary
OUTPUT 
    $action,
    inserted.EmployeeID,
    deleted.Salary,
    inserted.Salary,
    GETDATE()
INTO @MergeResults;

-- 6. MERGE with Error Handling
BEGIN TRY
    BEGIN TRANSACTION;

    MERGE HR.EMP_Details AS Target
    USING HR.TempEmployees AS Source
    ON Target.EmployeeID = Source.EmployeeID
    WHEN MATCHED AND Source.Salary > Target.Salary THEN
        UPDATE SET 
            Target.Salary = Source.Salary,
            Target.ModifiedDate = GETDATE()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (FirstName, LastName, Email, DepartmentID, Salary)
        VALUES (Source.FirstName, Source.LastName, Source.Email,
                Source.DepartmentID, Source.Salary)
    WHEN NOT MATCHED BY SOURCE THEN
        UPDATE SET 
            Target.IsActive = 0;

    IF @@ROWCOUNT > 100
    BEGIN
        THROW 50001, 'Too many rows affected', 1;
    END

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    INSERT INTO HR.AuditLog (Action, TableName, UserName)
    VALUES ('Failed Merge', 'HR.EMP_Details', SYSTEM_USER);
    
    THROW;
END CATCH;

-- 7. MERGE with Dynamic SQL
DECLARE @SQL NVARCHAR(MAX);
DECLARE @TableName NVARCHAR(100) = 'HR.Departments';

SET @SQL = N'
MERGE ' + @TableName + ' AS Target
USING (SELECT DepartmentID, DepartmentName FROM @SourceTable)
    AS Source ON Target.DepartmentID = Source.DepartmentID
WHEN MATCHED THEN
    UPDATE SET Target.DepartmentName = Source.DepartmentName;'

-- 8. MERGE with Conditional Logic
MERGE HR.EMP_Details AS Target
USING HR.SalaryReviews AS Source
ON Target.EmployeeID = Source.EmployeeID
WHEN MATCHED AND 
     CASE 
        WHEN Source.Performance = 'Excellent' THEN 1
        WHEN Source.YearsOfService > 5 THEN 1
        ELSE 0
     END = 1
THEN
    UPDATE SET 
        Target.Salary = Target.Salary * 1.1,
        Target.ModifiedDate = GETDATE();

-- 9. MERGE with Partition Hint
MERGE HR.PartitionedEmployees WITH (HOLDLOCK) AS Target
USING HR.TempEmployees AS Source
ON Target.EmployeeID = Source.EmployeeID
WHEN MATCHED THEN
    UPDATE SET 
        Target.Department = Source.Department;