-- =============================================
-- BEGIN TRANSACTION Operations Guide
-- =============================================
/*
-- BEGIN TRANSACTION Complete Guide
-- Transactions in SQL Server are units of work that provide data integrity and database consistency. They follow the ACID properties (Atomicity, Consistency, Isolation, Durability) and allow multiple operations to be treated as a single logical unit that either succeeds completely or fails completely.

Facts and Notes:
- Transactions can be explicit (user-defined) or implicit (auto-generated)
- Supports nested transactions with @@TRANCOUNT tracking
- Can be named or unnamed (anonymous)
- Supports save points for partial rollbacks
- Can be marked for easier identification in logs
- Supports distributed transactions across multiple databases
- Maximum nesting level is 32
- Implicit transactions can be enabled using SET IMPLICIT_TRANSACTIONS ON

Important Considerations:
- Long-running transactions can impact system performance
- Lock escalation may occur during large transactions
- Nested transactions only roll back to outermost savepoint
- Transaction logs grow during active transactions
- Proper error handling is crucial for transaction management
- Connection termination automatically rolls back active transactions
- Different isolation levels affect concurrency and consistency
- Resource locks should be managed carefully to prevent deadlocks

1. Basic Transaction: This section demonstrates fundamental transaction structure with error handling, including basic commit and rollback operations with TRY-CATCH blocks.
2. Named Transaction: This section shows how to create and manage named transactions, providing better identification and control over specific transaction blocks.
3. Nested Transactions: This section illustrates handling nested transaction scopes, including proper management of transaction counts and rollback scenarios.
4. Transaction with Save Points: This section covers using save points within transactions to allow partial rollbacks while maintaining data consistency.
5. Marked Transaction: This section demonstrates marking transactions for better tracking and logging in transaction logs and monitoring tools.
6. Transaction with Isolation Level: This section shows how to set and use different transaction isolation levels to manage concurrency and data consistency.
7. Distributed Transaction: This section covers managing transactions across multiple databases or servers, including proper coordination and error handling.
8. Transaction with Error Handling and State Check: This section illustrates comprehensive error handling with transaction state verification using XACT_STATE().

Author: Nikhil Shrivastav
Date: February 2025
*/

USE HRSystem;
GO

-- 1. Basic Transaction
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE HR.EMP_Details
        SET Salary = Salary * 1.1
        WHERE DepartmentID = 1;

        INSERT INTO HR.AuditLog (Action, TableName)
        VALUES ('Salary Update', 'HR.EMP_Details');
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;

-- 2. Named Transaction
BEGIN TRANSACTION SalaryUpdate
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.05
    WHERE EmployeeID = 1000;

    IF @@ERROR = 0
        COMMIT TRANSACTION SalaryUpdate
    ELSE
        ROLLBACK TRANSACTION SalaryUpdate;

-- 3. Nested Transactions
BEGIN TRANSACTION OuterTran;
    INSERT INTO HR.Departments (DepartmentName, LocationID)
    VALUES ('New Department', 1);

    BEGIN TRANSACTION InnerTran;
        INSERT INTO HR.EMP_Details 
            (FirstName, LastName, Email, DepartmentID)
        VALUES 
            ('John', 'Doe', 'john@hr.com', SCOPE_IDENTITY());

        IF @@TRANCOUNT > 0
            COMMIT TRANSACTION InnerTran;
    
    IF @@ERROR = 0
        COMMIT TRANSACTION OuterTran
    ELSE
        ROLLBACK TRANSACTION OuterTran;

-- 4. Transaction with Save Points
BEGIN TRANSACTION;
    INSERT INTO HR.Departments (DepartmentName, LocationID)
    VALUES ('IT Support', 1);
    
    SAVE TRANSACTION DeptCreated;

    INSERT INTO HR.EMP_Details 
        (FirstName, LastName, Email, DepartmentID)
    VALUES 
        ('Jane', 'Smith', 'jane@hr.com', SCOPE_IDENTITY());

    IF @@ERROR <> 0
        ROLLBACK TRANSACTION DeptCreated;
    ELSE
        COMMIT TRANSACTION;

-- 5. Marked Transaction
BEGIN TRANSACTION ProcessPayroll WITH MARK 'Monthly Payroll Update';
    UPDATE HR.EMP_Details
    SET LastPaymentDate = GETDATE()
    WHERE LastPaymentDate IS NULL;

    IF @@ROWCOUNT > 100
        ROLLBACK TRANSACTION ProcessPayroll
    ELSE
        COMMIT TRANSACTION ProcessPayroll;

-- 6. Transaction with Isolation Level
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID IN (
        SELECT DepartmentID 
        FROM HR.Departments 
        WHERE DepartmentName = 'IT'
    );
COMMIT TRANSACTION;

-- 7. Distributed Transaction
BEGIN DISTRIBUTED TRANSACTION;
    -- First database operation
    INSERT INTO HR.AuditLog (Action, TableName)
    VALUES ('Start Distributed', 'Multiple');

    -- Second database operation (commented as example)
    /*
    INSERT INTO RemoteDB.HR.AuditLog (Action, TableName)
    VALUES ('Remote Update', 'Remote.Table');
    */
COMMIT TRANSACTION;

-- 8. Transaction with Error Handling and State Check
BEGIN TRY
    BEGIN TRANSACTION;
        INSERT INTO HR.Departments (DepartmentName, LocationID)
        VALUES ('Test Dept', 1);

        -- Intentional error for demonstration
        UPDATE HR.EMP_Details
        SET DepartmentID = 999; -- Non-existent department

        IF XACT_STATE() = -1
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 51000, 'Transaction failed', 1;
        END
        ELSE IF XACT_STATE() = 1
            COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    
    INSERT INTO HR.ErrorLog (ErrorMessage)
    VALUES (ERROR_MESSAGE());
END CATCH;