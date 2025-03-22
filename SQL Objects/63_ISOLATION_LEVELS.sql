-- =============================================
-- SQL SERVER ISOLATION LEVELS Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server isolation levels, including:
- Understanding transaction isolation levels
- The different isolation levels available in SQL Server
- Concurrency phenomena (dirty reads, non-repeatable reads, phantom reads)
- How each isolation level prevents or allows these phenomena
- Performance implications of different isolation levels
- Best practices for choosing the right isolation level
- Real-world scenarios and examples
*/

USE HRSystem;
GO

-- Enable SNAPSHOT isolation for this database
ALTER DATABASE HRSystem SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

ALTER DATABASE HRSystem SET READ_COMMITTED_SNAPSHOT OFF; -- Default setting
GO

-- =============================================
-- PART 1: UNDERSTANDING ISOLATION LEVELS
-- =============================================

/*
Transaction isolation levels control how data modified by one transaction is visible to other
concurrent transactions. They determine the level of consistency and concurrency in the database.

Concurrency phenomena that can occur:
1. Dirty reads: Reading uncommitted data from another transaction
2. Non-repeatable reads: Getting different values when reading the same row twice
3. Phantom reads: Getting different rows when executing the same query twice
4. Lost updates: One transaction overwrites changes made by another transaction

SQL Server isolation levels:
- READ UNCOMMITTED: Lowest isolation, allows dirty reads
- READ COMMITTED: Default level, prevents dirty reads
- REPEATABLE READ: Prevents dirty and non-repeatable reads
- SNAPSHOT: Provides statement-level consistency without blocking
- SERIALIZABLE: Highest isolation, prevents all concurrency phenomena
*/

-- =============================================
-- PART 2: READ UNCOMMITTED
-- =============================================

/*
READ UNCOMMITTED is the lowest isolation level.

Characteristics:
- Allows dirty reads (reading uncommitted data)
- Allows non-repeatable reads
- Allows phantom reads
- No shared locks on read operations
- Minimal blocking, highest concurrency
- Lowest consistency guarantees
*/

-- 2.1 Basic READ UNCOMMITTED Example
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
BEGIN TRANSACTION;
    -- This can read uncommitted changes from other transactions
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 2.2 Dirty Read Scenario
-- Run these in separate sessions to demonstrate dirty reads

-- Session 1: Start a transaction and make changes but don't commit yet
/*
BEGIN TRANSACTION;
    -- Update salary
    UPDATE HR.EMP_Details
    SET Salary = Salary * 2 -- Double the salary temporarily
    WHERE EmployeeID = 1001;
    
    -- Wait for Session 2 to read this uncommitted data
    WAITFOR DELAY '00:00:10';
    
    -- Roll back the change
    ROLLBACK TRANSACTION;
*/

-- Session 2: Read the uncommitted data (dirty read)
/*
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- Or use the NOLOCK hint
-- SELECT * FROM HR.EMP_Details WITH (NOLOCK) WHERE EmployeeID = 1001;

SELECT EmployeeID, FirstName, LastName, Salary
FROM HR.EMP_Details
WHERE EmployeeID = 1001;
*/

-- 2.3 Using NOLOCK Hint (Same as READ UNCOMMITTED)
SELECT * FROM HR.EMP_Details WITH (NOLOCK)
WHERE DepartmentID = 1;

-- 2.4 When to Use READ UNCOMMITTED
/*
Appropriate uses:
- Reporting queries where absolute accuracy is not critical
- Aggregate queries where small discrepancies are acceptable
- Troubleshooting blocking issues
- Data exploration and ad-hoc queries

Not appropriate for:
- Financial transactions
- Data that must be consistent
- Calculations where accuracy is critical
*/

-- Example: Quick count of records (acceptable use)
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT COUNT(*) AS TotalEmployees FROM HR.EMP_Details;

-- =============================================
-- PART 3: READ COMMITTED
-- =============================================

/*
READ COMMITTED is the default isolation level in SQL Server.

Characteristics:
- Prevents dirty reads
- Allows non-repeatable reads
- Allows phantom reads
- Uses shared locks for reading, released immediately after read
- Good balance between concurrency and consistency
*/

-- 3.1 Basic READ COMMITTED Example
SET TRANSACTION ISOLATION LEVEL READ COMMITTED; -- This is the default
BEGIN TRANSACTION;
    -- This will only read committed data
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 3.2 Non-repeatable Read Scenario
-- Run these in separate sessions

-- Session 1: Read data twice with a delay between reads
/*
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;
    -- First read
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE EmployeeID = 1001;
    
    -- Wait for Session 2 to modify the data
    WAITFOR DELAY '00:00:10';
    
    -- Second read - may see different data (non-repeatable read)
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE EmployeeID = 1001;
COMMIT TRANSACTION;
*/

-- Session 2: Modify data between Session 1's reads
/*
BEGIN TRANSACTION;
    -- Update the salary
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1 -- 10% raise
    WHERE EmployeeID = 1001;
    
    -- Commit the change
    COMMIT TRANSACTION;
*/

-- 3.3 READ COMMITTED SNAPSHOT Isolation
-- This is a variation of READ COMMITTED that uses row versioning instead of locks

-- Enable READ_COMMITTED_SNAPSHOT for the database
ALTER DATABASE HRSystem SET READ_COMMITTED_SNAPSHOT ON;
GO

-- Now READ COMMITTED behaves like SNAPSHOT for read operations
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;
    -- This will see a consistent view of committed data as of transaction start
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- Disable READ_COMMITTED_SNAPSHOT to return to default behavior
ALTER DATABASE HRSystem SET READ_COMMITTED_SNAPSHOT OFF;
GO

-- 3.4 When to Use READ COMMITTED
/*
Appropriate uses:
- General OLTP workloads
- Most business applications
- Default choice for most scenarios
- Balance between consistency and concurrency

Considerations:
- May experience blocking under heavy write loads
- Non-repeatable reads can be an issue for some applications
*/

-- =============================================
-- PART 4: REPEATABLE READ
-- =============================================

/*
REPEATABLE READ provides stronger consistency than READ COMMITTED.

Characteristics:
- Prevents dirty reads
- Prevents non-repeatable reads
- Allows phantom reads
- Holds shared locks until end of transaction
- More blocking than READ COMMITTED
*/

-- 4.1 Basic REPEATABLE READ Example
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;
    -- First read
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE DepartmentID = 1;
    
    -- Do some processing (simulated)
    WAITFOR DELAY '00:00:02';
    
    -- Second read - guaranteed to get same results for existing rows
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 4.2 Phantom Read Scenario
-- Run these in separate sessions

-- Session 1: Read data twice with a delay between reads
/*
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;
    -- First read
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE Salary > 50000;
    
    -- Wait for Session 2 to insert new data
    WAITFOR DELAY '00:00:10';
    
    -- Second read - may see new rows (phantom read)
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE Salary > 50000;
COMMIT TRANSACTION;
*/

-- Session 2: Insert new data between Session 1's reads
/*
BEGIN TRANSACTION;
    -- Insert a new employee with high salary
    INSERT INTO HR.EMP_Details 
        (FirstName, LastName, Email, Salary, DepartmentID)
    VALUES 
        ('New', 'Executive', 'exec@example.com', 120000, 1);
    
    -- Commit the change
    COMMIT TRANSACTION;
*/

-- 4.3 When to Use REPEATABLE READ
/*
Appropriate uses:
- Reports that need consistent data throughout execution
- Transactions that read and re-read the same data
- Calculations that depend on values not changing

Considerations:
- Increased blocking compared to READ COMMITTED
- Can still experience phantom reads
- May impact concurrency in busy systems
*/

-- =============================================
-- PART 5: SERIALIZABLE
-- =============================================

/*
SERIALIZABLE is the highest isolation level in the SQL standard.

Characteristics:
- Prevents dirty reads
- Prevents non-repeatable reads
- Prevents phantom reads
- Holds range locks until end of transaction
- Highest consistency, lowest concurrency
- Most blocking of all isolation levels
*/

-- 5.1 Basic SERIALIZABLE Example
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
    -- This query will place range locks
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE DepartmentID = 1;
    
    -- No other transaction can insert, update, or delete
    -- rows that would match this query until this transaction completes
    
    -- Do some processing (simulated)
    WAITFOR DELAY '00:00:02';
    
    -- Second read - guaranteed to get same results, no phantoms
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 5.2 Preventing Phantom Reads
-- Run these in separate sessions

-- Session 1: Read with SERIALIZABLE isolation
/*
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
    -- First read
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE Salary BETWEEN 40000 AND 60000;
    
    -- Wait for Session 2 to try to insert new data
    WAITFOR DELAY '00:00:10';
    
    -- Second read - guaranteed to get same results, no phantoms
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE Salary BETWEEN 40000 AND 60000;
COMMIT TRANSACTION;
*/

-- Session 2: Try to insert new data (will be blocked)
/*
BEGIN TRANSACTION;
    -- This will be blocked until Session 1 commits
    INSERT INTO HR.EMP_Details 
        (FirstName, LastName, Email, Salary, DepartmentID)
    VALUES 
        ('New', 'Employee', 'new@example.com', 55000, 1);
    
    COMMIT TRANSACTION;
*/

-- 5.3 Using HOLDLOCK Hint (Same as SERIALIZABLE)
SELECT * FROM HR.EMP_Details WITH (HOLDLOCK)
WHERE DepartmentID = 1;

-- 5.4 When to Use SERIALIZABLE
/*
Appropriate uses:
- Critical financial transactions
- Data that must be completely isolated
- Scenarios where phantom reads are unacceptable
- Maintaining referential integrity during complex operations

Considerations:
- Significant impact on concurrency
- Can cause blocking and timeouts in busy systems
- Use sparingly and for short transactions
*/

-- =============================================
-- PART 6: SNAPSHOT
-- =============================================

/*
SNAPSHOT isolation uses row versioning instead of locks.

Characteristics:
- Prevents dirty reads
- Prevents non-repeatable reads
- Prevents phantom reads
- No blocking for readers or writers
- Readers see a consistent point-in-time snapshot
- Potential for update conflicts
*/

-- 6.1 Basic SNAPSHOT Example
-- Ensure SNAPSHOT isolation is enabled
ALTER DATABASE HRSystem SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;
    -- This sees data as it existed at the start of the transaction
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE DepartmentID = 1;
    
    -- Even if other transactions modify the data, we still see the same data
    WAITFOR DELAY '00:00:05';
    
    -- This will return the same results as the first query
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 6.2 Update Conflict Scenario
-- Run these in separate sessions

-- Session 1: Start a SNAPSHOT transaction
/*
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;
    -- Read employee data
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE EmployeeID = 1001;
    
    -- Wait for Session 2 to modify the data
    WAITFOR DELAY '00:00:10';
    
    -- Try to update the same row (will cause an update conflict)
    UPDATE HR.EMP_Details
    SET Salary = 65000
    WHERE EmployeeID = 1001;
    
    COMMIT TRANSACTION;
*/

-- Session 2: Modify the data while Session 1 is active
/*
BEGIN TRANSACTION;
    -- Update the salary
    UPDATE HR.EMP_Details
    SET Salary = 70000
    WHERE EmployeeID = 1001;
    
    COMMIT TRANSACTION;
*/

-- 6.3 Handling Update Conflicts
BEGIN TRY
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
    BEGIN TRANSACTION;
        -- Read current data
        DECLARE @CurrentSalary DECIMAL(18,2);
        
        SELECT @CurrentSalary = Salary
        FROM HR.EMP_Details
        WHERE EmployeeID = 1001;
        
        -- Simulate some processing time
        WAITFOR DELAY '00:00:02';
        
        -- Try to update
        UPDATE HR.EMP_Details
        SET Salary = @CurrentSalary * 1.1
        WHERE EmployeeID = 1001;
        
        COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    -- Check for update conflict (error 3960)
    IF ERROR_NUMBER() = 3960
    BEGIN
        IF XACT_STATE() = -1
            ROLLBACK TRANSACTION;
            
        -- Log the conflict
        INSERT INTO HR.ErrorLog (ErrorMessage, ErrorType)
        VALUES ('Snapshot update conflict detected', 'Concurrency');
        
        -- Could implement retry logic here
        PRINT 'Update conflict detected. The data was modified by another transaction.';
    END
    ELSE
    BEGIN
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
            
        -- Handle other errors
        INSERT INTO HR.ErrorLog (ErrorMessage, ErrorNumber)
        VALUES (ERROR_MESSAGE(), ERROR_NUMBER());
        
        THROW;
    END
END CATCH;

-- 6.4 When to Use SNAPSHOT
/*
Appropriate uses:
- Reporting queries against OLTP databases
- Read-heavy applications
- Scenarios where blocking is unacceptable
- Long-running read operations

Considerations:
- Increased tempdb usage for version store
- Update conflicts must be handled
- Not suitable for all workloads
*/

-- =============================================
-- PART 7: READ COMMITTED SNAPSHOT ISOLATION (RCSI)
-- =============================================

/*
READ COMMITTED SNAPSHOT ISOLATION is a variation of READ COMMITTED that uses row versioning.

Characteristics:
- Prevents dirty reads
- Allows non-repeatable reads
- Allows phantom reads
- No blocking for readers
- Readers see the last committed version of each row
- No update conflicts (unlike SNAPSHOT)
*/

-- 7.1 Enabling RCSI
ALTER DATABASE HRSystem SET READ_COMMITTED_SNAPSHOT ON;
GO

-- 7.2 Using RCSI
-- With RCSI enabled, regular READ COMMITTED behaves differently
SET TRANSACTION ISOLATION LEVEL READ COMMITTED; -- Default
BEGIN TRANSACTION;
    -- This will see the last committed version of each row
    -- without taking or being blocked by locks
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE DepartmentID = 1;
    
    -- If another transaction updates this data and commits,
    -- a second read will see the new data (non-repeatable read still possible)
    WAITFOR DELAY '00:00:02';
    
    SELECT EmployeeID, FirstName, LastName, Salary
    FROM HR.EMP_Details
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 7.3 When to Use RCSI
/*
Appropriate uses:
- General OLTP workloads with high concurrency
- Applications that need to minimize blocking
- Default choice for many modern applications
- Balance between consistency and concurrency

Considerations:
- Increased tempdb usage
- Non-repeatable reads still possible
- May not be suitable for all applications
*/

-- Disable RCSI to return to traditional locking behavior
ALTER DATABASE HRSystem SET READ_COMMITTED_SNAPSHOT OFF;
GO

-- =============================================
-- PART 8: COMPARISON OF ISOLATION LEVELS
-- =============================================

/*
Isolation Level   | Dirty Reads | Non-repeatable Reads | Phantom Reads | Blocking | Concurrency
------------------|------------|---------------------|--------------|----------|------------
READ UNCOMMITTED  | Allowed    | Allowed             | Allowed      | Minimal  | Highest
READ COMMITTED    | Prevented  | Allowed             | Allowed      | Moderate | High
REPEATABLE READ   | Prevented  | Prevented           | Allowed      | High     | Moderate
SERIALIZABLE      | Prevented  | Prevented           | Prevented    | Highest  | Lowest
SNAPSHOT          | Prevented  | Prevented           | Prevented    | None*    | High
RCSI              | Prevented  | Allowed             | Allowed      | None*    | High

* Readers don't block writers and writers don't block readers, but update conflicts can occur in SNAPSHOT
*/

-- 8.1 Choosing the Right Isolation Level
/*
Factors to consider:
1. Consistency requirements
2. Concurrency needs
3. Performance impact
4. Application behavior
5. Database workload

General guidelines:
- Start with READ COMMITTED or RCSI for most applications
- Use SNAPSHOT for reporting queries against OLTP databases
- Use SERIALIZABLE sparingly for critical operations
- Use READ UNCOMMITTED only for non-critical reporting
*/

-- =============================================
-- PART 9: REAL-WORLD SCENARIOS
-- =============================================

-- 9.1 Financial Transaction Processing
BEGIN TRY
    -- Use highest isolation for financial transactions
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;
        -- Check account balance
        DECLARE @AccountID INT = 1001;
        DECLARE @TransferAmount DECIMAL(18,2) = 500.00;
        DECLARE @CurrentBalance DECIMAL(18,2);
        
        SELECT @CurrentBalance = Balance
        FROM Finance.Accounts
        WHERE AccountID = @AccountID;
        
        -- Validate sufficient funds
        IF @CurrentBalance < @TransferAmount
            THROW 50001, 'Insufficient funds', 1;
        
        -- Update account balance
        UPDATE Finance.Accounts
        SET Balance = Balance - @TransferAmount
        WHERE AccountID = @AccountID;
        
        -- Record transaction
        INSERT INTO Finance.Transactions
            (AccountID, TransactionType, Amount, TransactionDate)
        VALUES
            (@AccountID, 'Withdrawal', @TransferAmount, GETDATE());
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    
    -- Log error
    INSERT INTO Finance.ErrorLog (ErrorMessage)
    VALUES (ERROR_MESSAGE());
    
    THROW;
END CATCH;

-- 9.2 Reporting Query Against OLTP Database
-- Use SNAPSHOT to avoid blocking and being blocked
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;
    -- Complex reporting query
    SELECT 
        d.DepartmentName,
        COUNT(e.EmployeeID) AS EmployeeCount,
        AVG(e.Salary) AS AverageSalary,
        SUM(e.Salary) AS TotalSalary,
        MAX(e.Salary) AS HighestSalary
    FROM HR.EMP_Details e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    GROUP BY d.DepartmentName
    ORDER BY TotalSalary DESC;
    
    -- Additional reporting queries...
    
    -- No need to worry about blocking OLTP operations
COMMIT TRANSACTION;

-- 9.3 Inventory Management with Optimistic Concurrency
-- Use SNAPSHOT for optimistic concurrency
BEGIN TRY
    SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
    BEGIN TRANSACTION;
        DECLARE @ProductID INT = 101;
        DECLARE @OrderQuantity INT = 5;
        DECLARE @CurrentStock INT;
        
        -- Read current stock
        SELECT @CurrentStock = StockQuantity
        FROM Inventory.Products
        WHERE ProductID = @ProductID;
        
        -- Check if enough stock
        IF @CurrentStock < @OrderQuantity
            THROW 50001, 'Insufficient inventory', 1;
        
        -- Process results outside transaction
    SELECT COUNT(*) AS UpdatedEmployees
    FROM @EmployeesToUpdate;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    
    -- Log error
    INSERT INTO HR.ErrorLog (ErrorMessage, ErrorNumber, ErrorLine)
    VALUES (ERROR_MESSAGE(), ERROR_NUMBER(), ERROR_LINE());
    
    THROW;
END CATCH;

-- =============================================
-- PART 11: MONITORING ISOLATION LEVELS
-- =============================================

-- 11.1 Checking Current Isolation Level
-- For current session
DBCC USEROPTIONS;

-- For all active sessions
SELECT 
    session_id,
    CASE transaction_isolation_level 
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'READ UNCOMMITTED'
        WHEN 2 THEN 'READ COMMITTED'
        WHEN 3 THEN 'REPEATABLE READ'
        WHEN 4 THEN 'SERIALIZABLE'
        WHEN 5 THEN 'SNAPSHOT'
    END AS isolation_level,
    host_name,
    program_name,
    login_name
FROM sys.dm_exec_sessions
WHERE is_user_process = 1;

-- 11.2 Monitoring Blocking Due to Isolation Levels
SELECT 
    blocking.session_id AS blocking_session_id,
    blocked.session_id AS blocked_session_id,
    CASE blocking.transaction_isolation_level 
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'READ UNCOMMITTED'
        WHEN 2 THEN 'READ COMMITTED'
        WHEN 3 THEN 'REPEATABLE READ'
        WHEN 4 THEN 'SERIALIZABLE'
        WHEN 5 THEN 'SNAPSHOT'
    END AS blocking_isolation_level,
    CASE blocked.transaction_isolation_level 
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'READ UNCOMMITTED'
        WHEN 2 THEN 'READ COMMITTED'
        WHEN 3 THEN 'REPEATABLE READ'
        WHEN 4 THEN 'SERIALIZABLE'
        WHEN 5 THEN 'SNAPSHOT'
    END AS blocked_isolation_level,
    blocked.wait_type,
    blocked.wait_time / 1000.0 AS wait_time_seconds,
    blocked_sql.text AS blocked_sql,
    blocking_sql.text AS blocking_sql
FROM sys.dm_exec_requests blocked
JOIN sys.dm_exec_sessions blocking ON blocked.blocking_session_id = blocking.session_id
JOIN sys.dm_exec_sessions blocked_sess ON blocked.session_id = blocked_sess.session_id
OUTER APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_sql
OUTER APPLY sys.dm_exec_sql_text(blocking.most_recent_sql_handle) blocking_sql
WHERE blocked.blocking_session_id > 0;

-- 11.3 Monitoring Version Store Usage (for SNAPSHOT and RCSI)
SELECT 
    DB_NAME(database_id) AS database_name,
    reserved_page_count,
    reserved_space_kb = reserved_page_count * 8,
    reserved_space_mb = reserved_page_count * 8 / 1024.0
FROM tempdb.sys.dm_db_file_space_usage;

SELECT 
    SUM(version_store_reserved_page_count) AS version_store_pages,
    SUM(version_store_reserved_page_count) * 8 / 1024.0 AS version_store_mb,
    SUM(version_store_reserved_page_count) * 100.0 / SUM(reserved_page_count) AS version_store_percent
FROM tempdb.sys.dm_db_file_space_usage;

-- 11.4 Checking Database Isolation Level Settings
SELECT 
    name AS database_name,
    snapshot_isolation_state_desc,
    is_read_committed_snapshot_on
FROM sys.databases
WHERE database_id > 4; -- User databases only

-- =============================================
-- PART 12: CONCLUSION
-- =============================================

/*
Understanding SQL Server isolation levels is crucial for developing applications
that balance data consistency with performance and concurrency requirements.

Key takeaways:

1. Each isolation level offers different trade-offs between consistency and concurrency
2. READ COMMITTED is the default and suitable for most general-purpose applications
3. SNAPSHOT and RCSI provide optimistic concurrency with minimal blocking
4. SERIALIZABLE provides the highest consistency but with the most blocking
5. Choose the appropriate isolation level based on your specific requirements
6. Keep transactions short and focused to minimize blocking
7. Monitor and tune your isolation level choices based on real-world performance

By applying the techniques and best practices in this guide, you can develop
database applications that efficiently handle concurrent access while
maintaining the appropriate level of data consistency for your business needs.
*/ order
        UPDATE Inventory.Products
        SET StockQuantity = StockQuantity - @OrderQuantity
        WHERE ProductID = @ProductID;
        
        -- Create order
        INSERT INTO Sales.Orders (ProductID, Quantity, OrderDate)
        VALUES (@ProductID, @OrderQuantity, GETDATE());
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    -- Check for update conflict
    IF ERROR_NUMBER() = 3960
    BEGIN
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        
        -- Implement retry logic or notify user
        PRINT 'Inventory was modified by another transaction. Please try again.';
    END
    ELSE
    BEGIN
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        
        -- Handle other errors
        PRINT ERROR_MESSAGE();
    END
END CATCH;

-- =============================================
-- PART 10: BEST PRACTICES
-- =============================================

/*
1. Choose the appropriate isolation level for each transaction
2. Keep transactions as short as possible
3. Access objects in the same order in all transactions
4. Consider using SNAPSHOT or RCSI for read-heavy workloads
5. Monitor tempdb usage when using row versioning isolation levels
6. Be aware of the performance implications of each isolation level
7. Handle update conflicts properly in SNAPSHOT isolation
8. Use SERIALIZABLE only when absolutely necessary
9. Test your application under load with different isolation levels
10. Consider the impact on blocking and deadlocks
*/

-- 10.1 Example of Well-Designed Transaction
BEGIN TRY
    -- Prepare data outside transaction
    DECLARE @EmployeesToUpdate TABLE (
        EmployeeID INT PRIMARY KEY
    );
    
    -- Gather data before starting transaction
    INSERT INTO @EmployeesToUpdate (EmployeeID)
    SELECT EmployeeID 
    FROM HR.EMP_Details
    WHERE DepartmentID = 1
    AND Performance_Rating >= 4;
    
    -- Choose appropriate isolation level
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    
    -- Keep transaction short and focused
    BEGIN TRANSACTION;
        -- Update employee records
        UPDATE HR.EMP_Details
        SET Salary = Salary * 1.1,
            LastModifiedDate = GETDATE()
        FROM HR.EMP_Details e
        JOIN @EmployeesToUpdate u ON e.EmployeeID = u.EmployeeID;
        
        -- Log the changes
        INSERT INTO HR.AuditLog (Action, TableName, AffectedRows)
        VALUES ('Salary Update', 'HR.EMP_Details', @@ROWCOUNT);
    COMMIT TRANSACTION;
    
    -- Process results outside transaction
    SELECT COUNT(*) AS UpdatedEmployees
    FROM @EmployeesToUpdate;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    
    -- Log error
    INSERT INTO HR.ErrorLog (ErrorMessage, ErrorNumber, ErrorLine)
    VALUES (ERROR_MESSAGE(), ERROR_NUMBER(), ERROR_LINE());
    
    THROW;
END CATCH;

-- =============================================
-- PART 11: MONITORING ISOLATION LEVELS
-- =============================================

-- 11.1 Checking Current Isolation Level
-- For current session
DBCC USEROPTIONS;

-- For all active sessions
SELECT 
    session_id,
    CASE transaction_isolation_level 
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'READ UNCOMMITTED'
        WHEN 2 THEN 'READ COMMITTED'
        WHEN 3 THEN 'REPEATABLE READ'
        WHEN 4 THEN 'SERIALIZABLE'
        WHEN 5 THEN 'SNAPSHOT'
    END AS isolation_level,
    host_name,
    program_name,
    login_name
FROM sys.dm_exec_sessions
WHERE is_user_process = 1;

-- 11.2 Monitoring Blocking Due to Isolation Levels
SELECT 
    blocking.session_id AS blocking_session_id,
    blocked.session_id AS blocked_session_id,
    CASE blocking.transaction_isolation_level 
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'READ UNCOMMITTED'
        WHEN 2 THEN 'READ COMMITTED'
        WHEN 3 THEN 'REPEATABLE READ'
        WHEN 4 THEN 'SERIALIZABLE'
        WHEN 5 THEN 'SNAPSHOT'
    END AS blocking_isolation_level,
    CASE blocked.transaction_isolation_level 
        WHEN 0 THEN 'Unspecified'
        WHEN 1 THEN 'READ UNCOMMITTED'
        WHEN 2 THEN 'READ COMMITTED'
        WHEN 3 THEN 'REPEATABLE READ'
        WHEN 4 THEN 'SERIALIZABLE'
        WHEN 5 THEN 'SNAPSHOT'
    END AS blocked_isolation_level,
    blocked.wait_type,
    blocked.wait_time / 1000.0 AS wait_time_seconds,
    blocked_sql.text AS blocked_sql,
    blocking_sql.text AS blocking_sql
FROM sys.dm_exec_requests blocked
JOIN sys.dm_exec_sessions blocking ON blocked.blocking_session_id = blocking.session_id
JOIN sys.dm_exec_sessions blocked_sess ON blocked.session_id = blocked_sess.session_id
OUTER APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_sql
OUTER APPLY sys.dm_exec_sql_text(blocking.most_recent_sql_handle) blocking_sql
WHERE blocked.blocking_session_id > 0;

-- 11.3 Monitoring Version Store Usage (for SNAPSHOT and RCSI)
SELECT 
    DB_NAME(database_id) AS database_name,
    reserved_page_count,
    reserved_space_kb = reserved_page_count * 8,
    reserved_space_mb = reserved_page_count * 8 / 1024.0
FROM tempdb.sys.dm_db_file_space_usage;

SELECT 
    SUM(version_store_reserved_page_count) AS version_store_pages,
    SUM(version_store_reserved_page_count) * 8 / 1024.0 AS version_store_mb,
    SUM(version_store_reserved_page_count) * 100.0 / SUM(reserved_page_count) AS version_store_percent
FROM tempdb.sys.dm_db_file_space_usage;

-- 11.4 Checking Database Isolation Level Settings
SELECT 
    name AS database_name,
    snapshot_isolation_state_desc,
    is_read_committed_snapshot_on
FROM sys.databases
WHERE database_id > 4; -- User databases only

-- =============================================
-- PART 12: CONCLUSION
-- =============================================

/*
Understanding SQL Server isolation levels is crucial for developing applications
that balance data consistency with performance and concurrency requirements.

Key takeaways:

1. Each isolation level offers different trade-offs between consistency and concurrency
2. READ COMMITTED is the default and suitable for most general-purpose applications
3. SNAPSHOT and RCSI provide optimistic concurrency with minimal blocking
4. SERIALIZABLE provides the highest consistency but with the most blocking
5. Choose the appropriate isolation level based on your specific requirements
6. Keep transactions short and focused to minimize blocking
7. Monitor and tune your isolation level choices based on real-world performance

By applying the techniques and best practices in this guide, you can develop
database applications that efficiently handle concurrent access while
maintaining the appropriate level of data consistency for your business needs.
*/