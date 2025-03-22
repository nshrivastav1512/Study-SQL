-- =============================================
-- COMMIT Operations Guide
-- =============================================
/*
-- COMMIT Complete Guide
-- The COMMIT statement in SQL Server finalizes a database transaction, making all data modifications permanent and releasing transaction-related locks. It represents the successful completion of a transaction and ensures data changes are durably stored in the database according to the ACID properties.

Facts and Notes:
- Marks the end of a successful transaction
- Can be explicit (COMMIT) or implicit (auto-commit)
- Supports both COMMIT TRANSACTION and COMMIT WORK syntax
- Releases all transaction-related locks
- Decrements @@TRANCOUNT by 1
- Cannot be rolled back once executed
- Supports delayed durability option
- Works with both local and distributed transactions

Important Considerations:
- Only commits the innermost transaction when nested
- Resource locks are held until final COMMIT
- Transaction log truncation depends on successful commits
- Delayed durability affects transaction durability guarantees
- Large transactions impact system performance until committed
- Implicit transactions can affect commit behavior
- Connection termination before COMMIT causes automatic rollback
- Proper error handling crucial before committing

1. Basic COMMIT: This section demonstrates the fundamental usage of COMMIT statement to finalize a simple transaction with a single operation.
2. COMMIT with Multiple Operations: This section shows managing multiple database operations within a single transaction, ensuring atomic execution.
3. COMMIT WORK: This section illustrates using the ANSI SQL standard COMMIT WORK syntax for better code portability and compliance.
4. Conditional COMMIT: This section covers implementing conditional transaction commits based on business rules and operation results.
5. COMMIT with @@TRANCOUNT Check: This section demonstrates managing nested transactions and proper commit handling using transaction count.
6. COMMIT with Delayed Durability: This section shows using delayed durability option for performance optimization in specific scenarios.
7. COMMIT with TRY-CATCH: This section illustrates proper error handling and transaction management using TRY-CATCH blocks.
8. COMMIT with Performance Monitoring: This section covers tracking and logging transaction performance metrics during commit operations.
9. COMMIT with Explicit Transaction Mode: This section demonstrates managing explicit transaction modes and state verification before commit.
10. COMMIT with Isolation Level: This section shows setting appropriate isolation levels for transaction consistency and concurrency control.

Author: Nikhil Shrivastav
Date: February 2025
*/

USE HRSystem;
GO

-- 1. Basic COMMIT
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID = 1;
COMMIT;

-- 2. COMMIT with Multiple Operations
BEGIN TRANSACTION;
    -- First Operation
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID = 1;

    -- Second Operation
    INSERT INTO HR.AuditLog (Action, TableName)
    VALUES ('Salary Update', 'HR.EMP_Details');

    -- Third Operation
    UPDATE HR.Departments
    SET LastModifiedDate = GETDATE()
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 3. COMMIT WORK (ANSI SQL Standard)
BEGIN TRANSACTION;
    INSERT INTO HR.Departments 
        (DepartmentName, LocationID)
    VALUES 
        ('Quality Assurance', 1);
COMMIT WORK;

-- 4. Conditional COMMIT
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.15
    WHERE Performance_Rating = 5;

    IF @@ROWCOUNT <= 10
        COMMIT TRANSACTION
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, 'Too many employees affected', 1;
    END;

-- 5. COMMIT with @@TRANCOUNT Check
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Email = LOWER(Email);

    BEGIN TRANSACTION;
        UPDATE HR.Departments
        SET DepartmentName = UPPER(DepartmentName);

        WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION;

-- 6. COMMIT with Delayed Durability
BEGIN TRANSACTION;
    INSERT INTO HR.AuditLog 
        (Action, TableName, ModifiedDate)
    VALUES 
        ('Batch Update', 'Multiple', GETDATE());
COMMIT TRANSACTION WITH (DELAYED_DURABILITY = ON);

-- 7. COMMIT with TRY-CATCH
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE HR.EMP_Details
        SET DepartmentID = 2
        WHERE DepartmentID = 1;

        UPDATE HR.Departments
        SET EmployeeCount = (
            SELECT COUNT(*) 
            FROM HR.EMP_Details 
            WHERE DepartmentID = 2
        )
        WHERE DepartmentID = 2;

        IF @@ERROR = 0
            COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    INSERT INTO HR.ErrorLog 
        (ErrorMessage, ErrorDate)
    VALUES 
        (ERROR_MESSAGE(), GETDATE());
END CATCH;

-- 8. COMMIT with Performance Monitoring
DECLARE @StartTime DATETIME = GETDATE();

BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET LastReviewDate = GETDATE()
    WHERE YEAR(LastReviewDate) < YEAR(GETDATE());

    INSERT INTO HR.PerformanceLog 
        (Operation, Duration, RowsAffected)
    VALUES 
        ('Review Date Update', 
         DATEDIFF(ms, @StartTime, GETDATE()),
         @@ROWCOUNT);
COMMIT;

-- 9. COMMIT with Explicit Transaction Mode
SET IMPLICIT_TRANSACTIONS OFF;
BEGIN TRANSACTION;
    MERGE HR.EMP_Details AS Target
    USING HR.TempEmployees AS Source
    ON Target.EmployeeID = Source.EmployeeID
    WHEN MATCHED THEN
        UPDATE SET Target.Salary = Source.Salary;

    IF XACT_STATE() = 1
        COMMIT TRANSACTION;

-- 10. COMMIT with Isolation Level
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;
    UPDATE HR.Departments
    SET Budget = Budget * 1.1
    WHERE YEAR(LastBudgetUpdate) < YEAR(GETDATE());
    
    IF @@ERROR = 0
        COMMIT TRANSACTION
    ELSE
        ROLLBACK TRANSACTION;