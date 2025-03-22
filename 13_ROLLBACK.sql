-- =============================================
-- ROLLBACK Operations Guide
-- =============================================
/*
-- ROLLBACK Complete Guide
-- The ROLLBACK statement in SQL Server undoes all data modifications made since the beginning of a transaction or savepoint. It's a critical component of transaction management that ensures data integrity by providing the ability to revert changes when errors occur or when business rules are violated.

Facts and Notes:
- Undoes all transaction modifications
- Can rollback to specific savepoints
- Supports both ROLLBACK TRANSACTION and ROLLBACK WORK syntax
- Releases all transaction-related locks
- Decrements @@TRANCOUNT to 0 (except for savepoint rollbacks)
- Cannot be undone once executed
- Works with both local and distributed transactions
- Automatic rollback occurs on connection termination

Important Considerations:
- Rolling back nested transactions affects all inner transactions
- Resource intensive for large transactions
- Savepoint rollbacks maintain outer transaction
- Transaction log space required for potential rollbacks
- Implicit rollback occurs on server shutdown
- Cannot rollback committed transactions
- Proper error handling crucial for rollback scenarios
- Impact on tempdb and transaction log space

1. Basic ROLLBACK: This section demonstrates fundamental usage of ROLLBACK statement to undo transaction changes when errors occur or conditions aren't met.
2. ROLLBACK with Save Points: This section shows using savepoints to create restoration points within transactions, allowing partial rollbacks while maintaining transaction integrity.
3. ROLLBACK WORK: This section illustrates using the ANSI SQL standard ROLLBACK WORK syntax for better code portability and compliance.
4. Nested Transaction ROLLBACK: This section covers managing rollbacks in nested transaction scenarios, including scope and impact on parent transactions.
5. ROLLBACK with Multiple Save Points: This section demonstrates managing multiple savepoints within a transaction for fine-grained control over rollbacks.
6. ROLLBACK with Error Handling: This section shows implementing comprehensive error handling with proper transaction state verification and rollback procedures.
7. ROLLBACK with Distributed Transaction: This section covers managing rollbacks in distributed transaction scenarios across multiple databases or servers.
8. Partial ROLLBACK with Batch Operations: This section illustrates implementing partial rollbacks in batch processing scenarios using savepoints.
9. ROLLBACK with Isolation Level: This section demonstrates managing rollbacks with different transaction isolation levels for consistency control.
10. ROLLBACK with Performance Monitoring: This section shows tracking and logging rollback operations with performance metrics and error details.

Author: Nikhil Shrivastav
Date: February 2025
*/

USE HRSystem;
GO

-- 1. Basic ROLLBACK
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 2; -- Intentional error
    
    IF @@ERROR <> 0
        ROLLBACK TRANSACTION;

-- 2. ROLLBACK with Save Points
BEGIN TRANSACTION;
    -- First operation
    INSERT INTO HR.Departments (DepartmentName, LocationID)
    VALUES ('Research', 1);
    
    SAVE TRANSACTION DeptInserted;
    
    -- Second operation
    UPDATE HR.EMP_Details
    SET DepartmentID = SCOPE_IDENTITY()
    WHERE EmployeeID IN (1001, 1002);
    
    IF @@ERROR <> 0
        ROLLBACK TRANSACTION DeptInserted
    ELSE
        COMMIT TRANSACTION;

-- 3. ROLLBACK WORK (ANSI Standard)
BEGIN TRANSACTION;
    DELETE FROM HR.EMP_Details
    WHERE TerminationDate IS NOT NULL;
    
    IF @@ROWCOUNT > 100
        ROLLBACK WORK;
    ELSE
        COMMIT WORK;

-- 4. Nested Transaction ROLLBACK
BEGIN TRANSACTION MainTran;
    UPDATE HR.Departments
    SET Budget = Budget * 1.1;
    
    BEGIN TRANSACTION SubTran;
        UPDATE HR.EMP_Details
        SET Salary = Salary * 1.1;
        
        IF @@ERROR <> 0
        BEGIN
            ROLLBACK TRANSACTION SubTran;
            -- Main transaction continues
        END
    
    IF @@TRANCOUNT > 0
        COMMIT TRANSACTION MainTran;

-- 5. ROLLBACK with Multiple Save Points
BEGIN TRANSACTION;
    -- First Change
    UPDATE HR.Departments
    SET DepartmentName = UPPER(DepartmentName);
    SAVE TRANSACTION NameUpdate;
    
    -- Second Change
    UPDATE HR.Departments
    SET Budget = Budget * 1.2;
    SAVE TRANSACTION BudgetUpdate;
    
    -- Third Change
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.5;
    
    IF @@ERROR <> 0
        ROLLBACK TRANSACTION BudgetUpdate
    ELSE IF @@ROWCOUNT > 100
        ROLLBACK TRANSACTION NameUpdate
    ELSE
        COMMIT TRANSACTION;

-- 6. ROLLBACK with Error Handling
BEGIN TRY
    BEGIN TRANSACTION;
        -- Attempt risky operation
        UPDATE HR.EMP_Details
        SET DepartmentID = (
            SELECT DepartmentID 
            FROM HR.Departments 
            WHERE DepartmentName = 'NonExistent'
        );
        
        COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() = -1
    BEGIN
        ROLLBACK TRANSACTION;
        
        INSERT INTO HR.ErrorLog (ErrorMessage, ErrorTime)
        VALUES (ERROR_MESSAGE(), GETDATE());
    END
END CATCH;

-- 7. ROLLBACK with Distributed Transaction
BEGIN DISTRIBUTED TRANSACTION;
    -- Local database operation
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1;
    
    -- Remote database operation (example)
    /* 
    UPDATE RemoteDB.HR.Salaries
    SET Amount = Amount * 1.1;
    */
    
    IF @@ERROR <> 0
        ROLLBACK TRANSACTION;
    ELSE
        COMMIT TRANSACTION;

-- 8. Partial ROLLBACK with Batch Operations
BEGIN TRANSACTION;
    DECLARE @Counter INT = 1;
    
    WHILE @Counter <= 5
    BEGIN
        SAVE TRANSACTION BatchPoint;
        
        INSERT INTO HR.AuditLog (Action, TableName)
        VALUES ('Batch ' + CAST(@Counter AS VARCHAR), 'HR.EMP_Details');
        
        IF @@ERROR <> 0
        BEGIN
            ROLLBACK TRANSACTION BatchPoint;
            SET @Counter = @Counter + 1;
            CONTINUE;
        END
        
        SET @Counter = @Counter + 1;
    END
    
    COMMIT TRANSACTION;

-- 9. ROLLBACK with Isolation Level
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.2
    WHERE DepartmentID IN (
        SELECT DepartmentID
        FROM HR.Departments
        WHERE Budget > 1000000
    );
    
    IF @@ROWCOUNT > 50
        ROLLBACK TRANSACTION;
    ELSE
        COMMIT TRANSACTION;

-- 10. ROLLBACK with Performance Monitoring
DECLARE @StartTime DATETIME = GETDATE();

BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE HR.EMP_Details
        SET PerformanceRating = PerformanceRating + 1;
        
        IF @@ROWCOUNT > 1000
            THROW 50001, 'Too many rows affected', 1;
            
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        INSERT INTO HR.PerformanceLog 
            (Operation, Duration, ErrorMessage)
        VALUES 
            ('Failed Update', 
             DATEDIFF(ms, @StartTime, GETDATE()),
             ERROR_MESSAGE());
    END CATCH;