-- =============================================
-- TRANSACTIONS AND SAVEPOINTS Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server transactions, including:
- Transaction fundamentals and ACID properties
- Transaction control statements (BEGIN, COMMIT, ROLLBACK)
- Savepoints for partial transaction control
- Error handling within transactions
- Transaction state management
- Nested and distributed transactions
- Real-world scenarios and best practices
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: TRANSACTION FUNDAMENTALS
-- =============================================

/*
A transaction is a logical unit of work that must be completed in its entirety.
Transactions follow ACID properties:
- Atomicity: All operations complete successfully or none do
- Consistency: Database remains in a consistent state before and after transaction
- Isolation: Transactions are isolated from each other until completion
- Durability: Once committed, changes are permanent
*/

-- 1.1 Basic Transaction Structure
BEGIN TRY
    BEGIN TRANSACTION;
        -- Operation 1
        INSERT INTO HR.Departments (DepartmentName, LocationID)
        VALUES ('Strategic Planning', 1);
        
        -- Operation 2
        INSERT INTO HR.AuditLog (Action, TableName)
        VALUES ('Department Created', 'HR.Departments');
    COMMIT TRANSACTION;
    
    PRINT 'Transaction completed successfully.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
        
    PRINT 'Error occurred: ' + ERROR_MESSAGE();
    THROW;
END CATCH;

-- 1.2 Transaction States
/*
Transactions can be in one of three states:
- 1: The transaction is active and can be committed
- 0: No transaction is in progress
- -1: The transaction has been rolled back or a fatal error occurred

XACT_STATE() function returns the transaction state
*/

BEGIN TRY
    BEGIN TRANSACTION;
        INSERT INTO HR.Departments (DepartmentName, LocationID)
        VALUES ('Data Analytics', 1);
        
        -- Check transaction state
        SELECT 'Current Transaction State' = 
            CASE XACT_STATE()
                WHEN 1 THEN 'Active, committable'
                WHEN 0 THEN 'No transaction in progress'
                WHEN -1 THEN 'Uncommittable, rollback only'
            END;
            
        -- Intentional error (for demonstration)
        -- INSERT INTO NonExistentTable VALUES (1);
        
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    SELECT 'Transaction State After Error' = 
        CASE XACT_STATE()
            WHEN 1 THEN 'Active, committable'
            WHEN 0 THEN 'No transaction in progress'
            WHEN -1 THEN 'Uncommittable, rollback only'
        END;
        
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
        
    SELECT ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

-- =============================================
-- PART 2: TRANSACTION CONTROL STATEMENTS
-- =============================================

-- 2.1 BEGIN TRANSACTION Types

-- Simple BEGIN TRANSACTION
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.05
    WHERE Performance_Rating >= 4;
COMMIT TRANSACTION;

-- Named Transaction
BEGIN TRANSACTION AnnualRaise;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.03
    WHERE HireDate < DATEADD(YEAR, -5, GETDATE());
    
    IF @@ROWCOUNT > 50
    BEGIN
        ROLLBACK TRANSACTION AnnualRaise;
        PRINT 'Too many employees affected. Transaction rolled back.';
    END
    ELSE
    BEGIN
        COMMIT TRANSACTION AnnualRaise;
        PRINT 'Annual raise applied successfully.';
    END

-- Marked Transaction (for use with log marks)
BEGIN TRANSACTION QuarterlyUpdate WITH MARK 'Q2 2023 Updates';
    UPDATE HR.Departments
    SET Budget = Budget * 1.1;
    
    UPDATE HR.EMP_Details
    SET TargetBonus = TargetBonus * 1.05;
COMMIT TRANSACTION QuarterlyUpdate;

-- 2.2 COMMIT Types

-- Standard COMMIT
BEGIN TRANSACTION;
    DELETE FROM HR.EMP_Details
    WHERE TerminationDate IS NOT NULL
    AND DATEDIFF(YEAR, TerminationDate, GETDATE()) > 7;
COMMIT TRANSACTION;

-- COMMIT WORK (ANSI SQL Standard)
BEGIN TRANSACTION;
    UPDATE HR.Departments
    SET DepartmentName = UPPER(DepartmentName);
COMMIT WORK;

-- Conditional COMMIT
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET VacationDays = VacationDays + 1
    WHERE DATEDIFF(MONTH, HireDate, GETDATE()) % 12 = 0; -- Anniversary month
    
    DECLARE @AffectedEmployees INT = @@ROWCOUNT;
    
    IF @AffectedEmployees > 0 AND @AffectedEmployees <= 20
    BEGIN
        COMMIT TRANSACTION;
        PRINT CAST(@AffectedEmployees AS VARCHAR) + ' employees received anniversary vacation day.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'No employees or too many employees in anniversary month. No updates made.';
    END

-- 2.3 ROLLBACK Types

-- Standard ROLLBACK
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 2; -- Potentially dangerous operation
    
    IF (SELECT AVG(Salary) FROM HR.EMP_Details) > 100000
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'Average salary too high after update. Changes rolled back.';
    END
    ELSE
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'Salary update completed successfully.';
    END

-- ROLLBACK WORK (ANSI SQL Standard)
BEGIN TRANSACTION;
    DELETE FROM HR.AuditLog
    WHERE LogDate < DATEADD(YEAR, -1, GETDATE());
    
    IF @@ROWCOUNT > 1000
    BEGIN
        ROLLBACK WORK;
        PRINT 'Too many audit records would be deleted. Operation cancelled.';
    END
    ELSE
    BEGIN
        COMMIT WORK;
        PRINT 'Old audit records cleaned up successfully.';
    END

-- =============================================
-- PART 3: SAVEPOINTS
-- =============================================

-- 3.1 Basic SAVEPOINT Usage
BEGIN TRANSACTION;
    -- First operation
    INSERT INTO HR.Departments (DepartmentName, LocationID)
    VALUES ('Customer Success', 1);
    
    -- Create a savepoint after department creation
    SAVE TRANSACTION DeptCreated;
    
    -- Second operation
    INSERT INTO HR.EMP_Details 
        (FirstName, LastName, Email, DepartmentID)
    VALUES 
        ('Alex', 'Johnson', 'alex@example.com', SCOPE_IDENTITY());
    
    -- If there's an error with employee creation, rollback to savepoint
    IF @@ERROR <> 0
    BEGIN
        ROLLBACK TRANSACTION DeptCreated;
        -- Department creation is preserved, only employee insert is rolled back
        PRINT 'Employee creation failed, but department was created.';
    END
    
    COMMIT TRANSACTION;

-- 3.2 Multiple SAVEPOINTS for Complex Operations
BEGIN TRANSACTION;
    -- Stage 1: Department Budget Update
    UPDATE HR.Departments
    SET Budget = Budget * 1.15
    WHERE DepartmentName LIKE '%Sales%';
    SAVE TRANSACTION SalesBudgetUpdate;
    
    -- Stage 2: Employee Salary Update
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID IN (
        SELECT DepartmentID 
        FROM HR.Departments 
        WHERE DepartmentName LIKE '%Sales%'
    );
    SAVE TRANSACTION SalesSalaryUpdate;
    
    -- Stage 3: Bonus Allocation
    UPDATE HR.EMP_Details
    SET Bonus = Salary * 0.15
    WHERE DepartmentID IN (
        SELECT DepartmentID 
        FROM HR.Departments 
        WHERE DepartmentName LIKE '%Sales%'
    );
    
    -- Validation checks
    DECLARE @TotalBudgetIncrease DECIMAL(18,2);
    DECLARE @TotalSalaryIncrease DECIMAL(18,2);
    DECLARE @TotalBonusAmount DECIMAL(18,2);
    
    SELECT @TotalBudgetIncrease = SUM(Budget * 0.15)
    FROM HR.Departments
    WHERE DepartmentName LIKE '%Sales%';
    
    SELECT @TotalSalaryIncrease = SUM(Salary * 0.1)
    FROM HR.EMP_Details
    WHERE DepartmentID IN (
        SELECT DepartmentID 
        FROM HR.Departments 
        WHERE DepartmentName LIKE '%Sales%'
    );
    
    SELECT @TotalBonusAmount = SUM(Bonus)
    FROM HR.EMP_Details
    WHERE DepartmentID IN (
        SELECT DepartmentID 
        FROM HR.Departments 
        WHERE DepartmentName LIKE '%Sales%'
    );
    
    -- Check if budget can cover salary increases and bonuses
    IF @TotalBudgetIncrease < (@TotalSalaryIncrease + @TotalBonusAmount)
    BEGIN
        ROLLBACK TRANSACTION SalesSalaryUpdate;
        PRINT 'Budget insufficient for both salary increases and bonuses. Reverting to budget update only.';
    END
    ELSE IF @TotalBonusAmount > @TotalBudgetIncrease * 0.5
    BEGIN
        ROLLBACK TRANSACTION SalesBudgetUpdate;
        PRINT 'Bonus allocation exceeds 50% of budget increase. All changes reverted.';
    END
    ELSE
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'All sales department updates completed successfully.';
    END

-- 3.3 SAVEPOINT with Batch Processing
BEGIN TRANSACTION;
    DECLARE @DeptID INT = 1;
    DECLARE @MaxDeptID INT;
    DECLARE @SuccessCount INT = 0;
    DECLARE @FailureCount INT = 0;
    
    SELECT @MaxDeptID = MAX(DepartmentID) FROM HR.Departments;
    
    WHILE @DeptID <= @MaxDeptID
    BEGIN
        IF EXISTS (SELECT 1 FROM HR.Departments WHERE DepartmentID = @DeptID)
        BEGIN
            SAVE TRANSACTION ProcessDept;
            
            BEGIN TRY
                -- Update department budget
                UPDATE HR.Departments
                SET Budget = Budget * 1.05,
                    LastModifiedDate = GETDATE()
                WHERE DepartmentID = @DeptID;
                
                -- Update employee records
                UPDATE HR.EMP_Details
                SET ReviewDate = DATEADD(YEAR, 1, GETDATE())
                WHERE DepartmentID = @DeptID;
                
                SET @SuccessCount = @SuccessCount + 1;
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION ProcessDept;
                
                INSERT INTO HR.ErrorLog (ErrorMessage, ErrorProcedure, ErrorLine)
                VALUES (
                    ERROR_MESSAGE(),
                    ERROR_PROCEDURE(),
                    ERROR_LINE()
                );
                
                SET @FailureCount = @FailureCount + 1;
            END CATCH
        END
        
        SET @DeptID = @DeptID + 1;
    END
    
    COMMIT TRANSACTION;
    
    PRINT 'Batch processing complete. Successful departments: ' + 
          CAST(@SuccessCount AS VARCHAR) + ', Failed departments: ' + 
          CAST(@FailureCount AS VARCHAR);

-- =============================================
-- PART 4: NESTED TRANSACTIONS
-- =============================================

-- 4.1 Basic Nested Transaction
BEGIN TRANSACTION OuterTran;
    PRINT 'Outer transaction started. @@TRANCOUNT = ' + CAST(@@TRANCOUNT AS VARCHAR);
    
    INSERT INTO HR.Departments (DepartmentName, LocationID)
    VALUES ('Business Development', 1);
    
    BEGIN TRANSACTION InnerTran;
        PRINT 'Inner transaction started. @@TRANCOUNT = ' + CAST(@@TRANCOUNT AS VARCHAR);
        
        INSERT INTO HR.EMP_Details 
            (FirstName, LastName, Email, DepartmentID)
        VALUES 
            ('Sarah', 'Williams', 'sarah@example.com', SCOPE_IDENTITY());
    COMMIT TRANSACTION InnerTran;
    
    PRINT 'Inner transaction committed. @@TRANCOUNT = ' + CAST(@@TRANCOUNT AS VARCHAR);
    
    -- Note: The outer transaction is still active
    -- Only when the outermost transaction is committed are all changes made permanent
    
COMMIT TRANSACTION OuterTran;
PRINT 'Outer transaction committed. @@TRANCOUNT = ' + CAST(@@TRANCOUNT AS VARCHAR);

-- 4.2 Nested Transaction with Rollback
BEGIN TRANSACTION MainProcess;
    PRINT 'Main transaction started. @@TRANCOUNT = ' + CAST(@@TRANCOUNT AS VARCHAR);
    
    UPDATE HR.Departments
    SET Budget = Budget * 1.1;
    
    BEGIN TRANSACTION SubProcess;
        PRINT 'Sub transaction started. @@TRANCOUNT = ' + CAST(@@TRANCOUNT AS VARCHAR);
        
        -- Intentional error condition
        UPDATE HR.EMP_Details
        SET Salary = Salary * 1.2
        WHERE Performance_Rating >= 4;
        
        IF (SELECT AVG(Salary) FROM HR.EMP_Details WHERE Performance_Rating >= 4) > 100000
        BEGIN
            ROLLBACK TRANSACTION SubProcess;
            PRINT 'Sub transaction rolled back. @@TRANCOUNT = ' + CAST(@@TRANCOUNT AS VARCHAR);
            -- Note: This doesn't actually roll back the sub-transaction in SQL Server
            -- It rolls back the entire transaction to the outermost BEGIN TRANSACTION
        END
        ELSE
        BEGIN
            COMMIT TRANSACTION SubProcess;
            PRINT 'Sub transaction committed. @@TRANCOUNT = ' + CAST(@@TRANCOUNT AS VARCHAR);
        END
    
COMMIT TRANSACTION MainProcess;

-- =============================================
-- PART 5: DISTRIBUTED TRANSACTIONS
-- =============================================

-- 5.1 Basic Distributed Transaction
/*
Distributed transactions span multiple databases or servers.
They use the Microsoft Distributed Transaction Coordinator (MS DTC).
*/

-- Example (commented as it requires multiple databases)
BEGIN DISTRIBUTED TRANSACTION;
    -- Operation in the local database
    INSERT INTO HR.AuditLog (Action, TableName)
    VALUES ('Cross-Database Update', 'Multiple');
    
    -- Operation in a linked server (commented as example)
    /*
    INSERT INTO LinkedServer.RemoteDB.dbo.AuditLog (Action, TableName)
    VALUES ('Remote Update', 'HR.EMP_Details');
    */
    
    -- Operation in another linked server (commented as example)
    /*
    UPDATE AnotherServer.FinanceDB.dbo.Budgets
    SET LastUpdated = GETDATE()
    WHERE DepartmentID IN (SELECT DepartmentID FROM HR.Departments);
    */
COMMIT TRANSACTION;

-- 5.2 Handling Distributed Transaction Failures
BEGIN TRY
    BEGIN DISTRIBUTED TRANSACTION;
        -- Local operation
        UPDATE HR.Departments
        SET Budget = Budget * 1.1;
        
        -- Remote operation (commented as example)
        /*
        UPDATE LinkedServer.FinanceDB.dbo.DepartmentBudgets
        SET Amount = Amount * 1.1,
            LastUpdated = GETDATE();
        */
        
        COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
        
    INSERT INTO HR.ErrorLog (ErrorMessage, ErrorSeverity, ErrorState)
    VALUES (
        ERROR_MESSAGE(),
        ERROR_SEVERITY(),
        ERROR_STATE()
    );
    
    -- Notify administrators of distributed transaction failure
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = 'AdminProfile',
        @recipients = 'dba@example.com',
        @subject = 'Distributed Transaction Failure',
        @body = 'A distributed transaction has failed. Check the ErrorLog table.';
END CATCH;

-- =============================================
-- PART 6: ERROR HANDLING IN TRANSACTIONS
-- =============================================

-- 6.1 Basic Error Handling Pattern
BEGIN TRY
    BEGIN TRANSACTION;
        INSERT INTO HR.Departments (DepartmentName, LocationID)
        VALUES ('Innovation Lab', 1);
        
        -- Intentional error - violating a constraint
        INSERT INTO HR.EMP_Details (EmployeeID, FirstName, LastName, Email)
        VALUES (1, 'Duplicate', 'Employee', 'duplicate@example.com'); -- Assuming EmployeeID is a primary key
        
        COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    -- Get transaction state
    DECLARE @TransactionState INT = XACT_STATE();
    
    IF @TransactionState = -1 -- Transaction is doomed
        ROLLBACK TRANSACTION;
    ELSE IF @TransactionState = 1 -- Transaction is active and committable
        ROLLBACK TRANSACTION;
    
    -- Log the error
    INSERT INTO HR.ErrorLog (ErrorNumber, ErrorSeverity, ErrorState, ErrorMessage, ErrorLine)
    VALUES (
        ERROR_NUMBER(),
        ERROR_SEVERITY(),
        ERROR_STATE(),
        ERROR_MESSAGE(),
        ERROR_LINE()
    );
    
    -- Re-throw the error to the calling application
    THROW;
END CATCH;

-- 6.2 Custom Error Handling with SAVE TRANSACTION
BEGIN TRY
    BEGIN TRANSACTION;
        -- First operation
        INSERT INTO HR.Departments (DepartmentName, LocationID)
        VALUES ('Product Management', 1);
        
        SAVE TRANSACTION DeptCreated;
        
        BEGIN TRY
            -- Second operation that might fail
            INSERT INTO HR.EMP_Details 
                (FirstName, LastName, Email, DepartmentID)
            VALUES 
                ('Invalid', 'Employee', 'invalid@example.com', 999); -- Invalid DepartmentID
        END TRY
        BEGIN CATCH
            -- Only roll back to the savepoint
            ROLLBACK TRANSACTION DeptCreated;
            
            -- Log the specific error
            INSERT INTO HR.ErrorLog (ErrorMessage)
            VALUES ('Employee creation failed: ' + ERROR_MESSAGE());
            
            -- Continue with the transaction
            INSERT INTO HR.AuditLog (Action, TableName, Description)
            VALUES (
                'Partial Failure', 
                'HR.EMP_Details',
                'Department created but employee creation failed'
            );
        END CATCH
        
        COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    -- Handle any errors in the outer TRY block
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
        
    INSERT INTO HR.ErrorLog (ErrorMessage)
    VALUES ('Outer transaction failed: ' + ERROR_MESSAGE());
    
    THROW;
END CATCH;

-- =============================================
-- PART 7: TRANSACTION MONITORING AND MANAGEMENT
-- =============================================

-- 7.1 Checking Active Transactions
-- This query shows currently executing transactions
SELECT 
    session_id,
    transaction_id,
    transaction_begin_time,
    CASE transaction_type
        WHEN 1 THEN 'Read/Write'
        WHEN 2 THEN 'Read-Only'
        WHEN 3 THEN 'System'
        WHEN 4 THEN 'Distributed'
    END AS transaction_type,
    CASE transaction_state
        WHEN 0 THEN 'Invalid'
        WHEN 1 THEN 'Initialized'
        WHEN 2 THEN 'Active'
        WHEN 3 THEN 'Ended'
        WHEN 4 THEN 'Commit Started'
        WHEN 5 THEN 'Prepared'
        WHEN 6 THEN 'Committed'
        WHEN 7 THEN 'Rolling Back'
        WHEN 8 THEN 'Rolled Back'
    END AS transaction_state,
    transaction_status
FROM sys.dm_tran_active_transactions AS tat
JOIN sys.dm_tran_session_transactions AS tst
    ON tat.transaction_id = tst.transaction_id;

-- 7.2 Identifying Long-Running Transactions
SELECT 
    s.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    DB_NAME(r.database_id) AS database_name,
    t.text AS query_text,
    r.status,
    r.command,
    r.wait_type,
    r.wait_time,
    r.blocking_session_id,
    DATEDIFF(SECOND, r.start_time, GETDATE()) AS duration_seconds
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.transaction_id IN (
    SELECT transaction_id 
    FROM sys.dm_tran_active_transactions 
    WHERE transaction_begin_time < DATEADD(MINUTE, -5, GETDATE())
);

-- =============================================
-- PART 8: TRANSACTION BEST PRACTICES
-- =============================================

/*
1. Keep transactions as short as possible
2. Avoid user interaction within transactions
3. Use appropriate isolation levels
4. Handle errors properly
5. Be aware of lock escalation
6. Consider using savepoints for partial rollbacks
7. Avoid distributed transactions when possible
8. Monitor long-running transactions
9. Use proper error handling with TRY-CATCH
10. Be careful with nested transactions
*/

-- 8.1 Example of a Well-Structured Transaction
BEGIN TRY
    -- Prepare data outside the transaction when possible
    DECLARE @EmployeesToUpdate TABLE (
        EmployeeID INT,
        CurrentSalary DECIMAL(18,2),
        NewSalary DECIMAL(18,2)
    );
    
    -- Gather data before starting transaction
    INSERT INTO @EmployeesToUpdate (EmployeeID, CurrentSalary, NewSalary)
    SELECT 
        EmployeeID,
        Salary,
        Salary * 1.05
    FROM HR.EMP_Details
    WHERE Performance_Rating >= 4
    AND DepartmentID IN (SELECT DepartmentID FROM HR.Departments WHERE Budget > 1000000);
    
    -- Start transaction only when ready to make changes
    BEGIN TRANSACTION;
        -- Update employee salaries
        UPDATE HR.EMP_Details
        SET Salary = eu.NewSalary
        FROM HR.EMP_Details e
        JOIN @EmployeesToUpdate eu ON e.EmployeeID = eu.EmployeeID;
        
        -- Log the changes
        INSERT INTO HR.AuditLog (Action, TableName, AffectedRows)
        VALUES ('Salary Update', 'HR.EMP_Details', @@ROWCOUNT);
        
        -- Update department last modified date
        UPDATE HR.Departments
        SET LastModifiedDate = GETDATE()
        WHERE DepartmentID IN (
            SELECT DISTINCT DepartmentID 
            FROM HR.EMP_Details e
            JOIN @EmployeesToUpdate eu ON e.EmployeeID = eu.EmployeeID
        );
    COMMIT TRANSACTION;
    
    -- Report success outside the transaction
    SELECT 
        COUNT(*) AS UpdatedEmployees,
        AVG(NewSalary - CurrentSalary) AS AverageSalaryIncrease
    FROM @EmployeesToUpdate;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    
    INSERT INTO HR.ErrorLog (ErrorMessage, ErrorProcedure, ErrorLine)
    VALUES (ERROR_MESSAGE(), ERROR_PROCEDURE(), ERROR_LINE());
    
    -- Re-throw with additional information
    THROW 50000, 'Salary update transaction failed. See error log for details.', 1;
END CATCH;

-- 8.2 Avoiding Common Transaction Pitfalls

-- BAD: Long-running transaction with user interaction
/*
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details SET Status = 'Processing';
    -- WAITFOR DELAY '00:10:00'; -- Simulating user interaction or long process
    UPDATE HR.EMP_Details SET Status = 'Completed';
COMMIT TRANSACTION;
*/

-- GOOD: Short transactions with proper preparation
DECLARE @EmployeesToProcess TABLE (EmployeeID INT);

-- Prepare data
INSERT INTO @EmployeesToProcess (EmployeeID)
SELECT EmployeeID FROM HR.EMP_Details WHERE Status = 'Pending';

-- First transaction: Mark as processing
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details 
    SET Status = 'Processing'
    WHERE EmployeeID IN (SELECT EmployeeID FROM @EmployeesToProcess);
COMMIT TRANSACTION;

-- Processing happens outside transaction
-- WAITFOR DELAY '00:00:05'; -- Simulating processing time

-- Second transaction: Mark as completed
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details 
    SET Status = 'Completed'
    WHERE EmployeeID IN (SELECT EmployeeID FROM @EmployeesToProcess);
COMMIT TRANSACTION;

-- =============================================
-- PART 9: REAL-WORLD SCENARIOS
-- =============================================

-- 9.1 Financial Transfer Between Accounts
BEGIN TRY
    DECLARE @FromAccountID INT = 1001;
    DECLARE @ToAccountID INT = 2002;
    DECLARE @TransferAmount DECIMAL(18,2) = 5000.00;
    DECLARE @CurrentBalance DECIMAL(18,2);
    
    -- Check sufficient funds (outside transaction)
    SELECT @CurrentBalance = Balance 
    FROM Finance.Accounts 
    WHERE AccountID = @FromAccountID;
    
    IF @CurrentBalance < @TransferAmount
        THROW 50001, 'Insufficient funds for transfer', 1;
    
    BEGIN TRANSACTION;
        -- Deduct from source account
        UPDATE Finance.Accounts
        SET Balance = Balance - @TransferAmount,
            LastModified = GETDATE()
        WHERE AccountID = @FromAccountID;
        
        -- Add to destination account
        UPDATE Finance.Accounts
        SET Balance = Balance + @TransferAmount,
            LastModified = GETDATE()
        WHERE AccountID = @ToAccountID;
        
        -- Record the transaction
        INSERT INTO Finance.Transactions 
            (TransactionType, FromAccount, ToAccount, Amount, TransactionDate)
        VALUES 
            ('Transfer', @FromAccountID, @ToAccountID, @TransferAmount, GETDATE());
    COMMIT TRANSACTION;
    
    -- Send notification (outside transaction)
    EXEC Notifications.SendTransferAlert 
        @AccountID = @FromAccountID, 
        @Amount = @TransferAmount, 
        @TransactionType = 'Debit';
        
    EXEC Notifications.SendTransferAlert 
        @AccountID = @ToAccountID, 
        @Amount = @TransferAmount, 
        @TransactionType = 'Credit';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    
    INSERT INTO Finance.ErrorLog 
        (ErrorMessage, ErrorProcedure, ErrorLine, ErrorTime)
    VALUES 
        (ERROR_MESSAGE(), ERROR_PROCEDURE(), ERROR_LINE(), GETDATE());
    
    -- Send failure notification
    EXEC Notifications.SendTransferFailure 
        @FromAccountID = @FromAccountID, 
        @ToAccountID = @ToAccountID, 
        @Amount = @TransferAmount, 
        @ErrorMessage = ERROR_MESSAGE();
        
    THROW;
END CATCH;

-- 9.2 Order Processing System
BEGIN TRY