-- =============================================
-- SQL SERVER LOCKS Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server locks, including:
- Lock fundamentals and types
- Lock modes and compatibility
- Lock escalation
- Lock hints
- Deadlocks and how to handle them
- Lock monitoring and troubleshooting
- Best practices for managing locks
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: LOCK FUNDAMENTALS
-- =============================================

/*
Locks are mechanisms used by SQL Server to ensure data integrity in a multi-user environment.
They prevent users from modifying data being used by others in a way that would produce inconsistencies.

Key concepts:
- Lock granularity: The size of the resource being locked (row, page, table, etc.)
- Lock modes: The type of lock (shared, exclusive, update, etc.)
- Lock duration: How long the lock is held
- Lock compatibility: Which lock types can coexist on the same resource
*/

-- 1.1 Lock Resources (Granularity)
/*
SQL Server can lock resources at different levels:
- RID: Row identifier (specific row in a heap)
- KEY: Row lock within an index
- PAGE: 8KB data or index page
- EXTENT: 8 contiguous pages (64KB)
- HoBT: Heap or B-Tree (table or index)
- TABLE: Entire table including all indexes
- DATABASE: Entire database
*/

-- Example showing lock escalation from row to table
BEGIN TRANSACTION;
    -- This will initially acquire row locks
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.01
    WHERE DepartmentID = 1;
    
    -- If enough rows are affected, SQL Server may escalate to a table lock
    
    -- View locks held by this session (run in another session)
    -- SELECT * FROM sys.dm_tran_locks WHERE request_session_id = @@SPID;
ROLLBACK TRANSACTION;

-- =============================================
-- PART 2: LOCK MODES
-- =============================================

/*
SQL Server uses different lock modes depending on the operation:

- Shared (S): Used for read operations, allows other shared locks
- Update (U): Used before modifying data, prevents deadlocks with other update locks
- Exclusive (X): Used for data modification, prevents any other locks
- Intent Shared (IS): Signals intention to place S locks at lower level
- Intent Exclusive (IX): Signals intention to place X locks at lower level
- Schema Stability (Sch-S): Used during query execution, allows schema changes that don't affect the query
- Schema Modification (Sch-M): Used for DDL operations, blocks all access to the table
- Bulk Update (BU): Used during bulk operations with TABLOCK hint
- Key-Range: Protects a range of keys in serializable transactions
*/

-- 2.1 Shared Locks (S)
-- Used for read operations
BEGIN TRANSACTION;
    -- This SELECT acquires shared locks
    SELECT * FROM HR.EMP_Details WITH (HOLDLOCK)
    WHERE DepartmentID = 1;
    
    -- Other sessions can read but not modify the selected rows
    
    -- View locks (run in another session)
    -- SELECT * FROM sys.dm_tran_locks WHERE request_session_id = @@SPID;
ROLLBACK TRANSACTION;

-- 2.2 Update Locks (U)
-- Used before modifying data
BEGIN TRANSACTION;
    -- This acquires update locks
    SELECT * FROM HR.EMP_Details WITH (UPDLOCK)
    WHERE EmployeeID = 1001;
    
    -- Then modifies the data, converting to exclusive locks
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE EmployeeID = 1001;
    
    -- View locks (run in another session)
    -- SELECT * FROM sys.dm_tran_locks WHERE request_session_id = @@SPID;
ROLLBACK TRANSACTION;

-- 2.3 Exclusive Locks (X)
-- Used for data modification
BEGIN TRANSACTION;
    -- This acquires exclusive locks
    UPDATE HR.EMP_Details
    SET LastModifiedDate = GETDATE()
    WHERE EmployeeID = 1002;
    
    -- No other session can read or modify this row until the transaction completes
    
    -- View locks (run in another session)
    -- SELECT * FROM sys.dm_tran_locks WHERE request_session_id = @@SPID;
ROLLBACK TRANSACTION;

-- 2.4 Intent Locks (IS, IX)
-- Used to establish a lock hierarchy
BEGIN TRANSACTION;
    -- This acquires intent-exclusive locks at the table level
    -- and exclusive locks at the row level
    UPDATE HR.EMP_Details
    SET Email = LOWER(Email)
    WHERE DepartmentID = 2;
    
    -- View locks (run in another session)
    -- SELECT * FROM sys.dm_tran_locks WHERE request_session_id = @@SPID;
ROLLBACK TRANSACTION;

-- 2.5 Schema Locks (Sch-S, Sch-M)
-- Used for schema operations
BEGIN TRANSACTION;
    -- This acquires a schema modification lock
    ALTER TABLE HR.EMP_Details ADD MiddleName NVARCHAR(50) NULL;
    
    -- No other session can access the table during this operation
    
    -- View locks (run in another session)
    -- SELECT * FROM sys.dm_tran_locks WHERE request_session_id = @@SPID;
ROLLBACK TRANSACTION;

-- =============================================
-- PART 3: LOCK COMPATIBILITY
-- =============================================

/*
Lock compatibility matrix:

    | S  | U  | X  | IS | IX | SIX | Sch-S | Sch-M |
----+----+----+----+----+----+-----+-------+-------+
S   | Y  | Y  | N  | Y  | N  | N   | Y     | N     |
U   | Y  | N  | N  | Y  | N  | N   | Y     | N     |
X   | N  | N  | N  | N  | N  | N   | N     | N     |
IS  | Y  | Y  | N  | Y  | Y  | Y   | Y     | N     |
IX  | N  | N  | N  | Y  | Y  | Y   | Y     | N     |
SIX | N  | N  | N  | Y  | Y  | N   | Y     | N     |
Sch-S| Y | Y  | N  | Y  | Y  | Y   | Y     | N     |
Sch-M| N | N  | N  | N  | N  | N   | N     | N     |

Y = Compatible, N = Not compatible
*/

-- 3.1 Demonstrating Lock Compatibility
-- Run these in separate sessions to observe lock behavior

-- Session 1: Acquire shared lock
/*
BEGIN TRANSACTION;
    SELECT * FROM HR.EMP_Details WITH (HOLDLOCK)
    WHERE EmployeeID = 1001;
    
    -- Wait for 30 seconds to observe behavior in other sessions
    WAITFOR DELAY '00:00:30';
COMMIT TRANSACTION;
*/

-- Session 2: Try to acquire another shared lock (will succeed)
/*
BEGIN TRANSACTION;
    SELECT * FROM HR.EMP_Details WITH (HOLDLOCK)
    WHERE EmployeeID = 1001;
COMMIT TRANSACTION;
*/

-- Session 3: Try to acquire exclusive lock (will wait/block)
/*
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE EmployeeID = 1001;
COMMIT TRANSACTION;
*/

-- =============================================
-- PART 4: LOCK ESCALATION
-- =============================================

/*
Lock escalation is the process of converting many fine-grained locks into fewer
coarse-grained locks, reducing system overhead at the cost of concurrency.

Escalation typically occurs when:
- A single transaction acquires many locks on a single object
- The number of locks exceeds a threshold
- The system is under memory pressure
*/

-- 4.1 Controlling Lock Escalation
-- Disable lock escalation for a table
ALTER TABLE HR.EMP_Details SET (LOCK_ESCALATION = DISABLE);

-- Allow escalation to the table level only (default)
ALTER TABLE HR.EMP_Details SET (LOCK_ESCALATION = TABLE);

-- Allow escalation to the partition level
ALTER TABLE HR.EMP_Details SET (LOCK_ESCALATION = AUTO);

-- 4.2 Demonstrating Lock Escalation
BEGIN TRANSACTION;
    -- This will acquire many row locks
    UPDATE HR.EMP_Details
    SET LastModifiedDate = GETDATE();
    
    -- SQL Server may escalate to a table lock
    -- Check lock escalation (run in another session)
    /*
    SELECT 
        DB_NAME(resource_database_id) AS DatabaseName,
        OBJECT_NAME(resource_associated_entity_id) AS TableName,
        resource_type,
        resource_description,
        request_mode,
        request_status
    FROM sys.dm_tran_locks
    WHERE request_session_id = <SPID>; -- Replace <SPID> with the session ID
    */
ROLLBACK TRANSACTION;

-- =============================================
-- PART 5: LOCK HINTS
-- =============================================

/*
Lock hints allow you to override SQL Server's default locking behavior.
Use with caution as they can affect concurrency and performance.
*/

-- 5.1 Common Lock Hints

-- NOLOCK (READ UNCOMMITTED) - Dirty reads possible
SELECT * FROM HR.EMP_Details WITH (NOLOCK)
WHERE DepartmentID = 1;

-- HOLDLOCK (SERIALIZABLE) - Holds shared locks until transaction completes
BEGIN TRANSACTION;
    SELECT * FROM HR.EMP_Details WITH (HOLDLOCK)
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- UPDLOCK - Takes update locks instead of shared locks
BEGIN TRANSACTION;
    SELECT * FROM HR.EMP_Details WITH (UPDLOCK)
    WHERE EmployeeID = 1001;
    
    -- Later update (no blocking)
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE EmployeeID = 1001;
COMMIT TRANSACTION;

-- ROWLOCK - Forces row-level locking
UPDATE HR.EMP_Details WITH (ROWLOCK)
SET Email = LOWER(Email)
WHERE EmployeeID = 1002;

-- PAGLOCK - Forces page-level locking
UPDATE HR.EMP_Details WITH (PAGLOCK)
SET LastModifiedDate = GETDATE()
WHERE DepartmentID = 3;

-- TABLOCK - Forces table-level locking
UPDATE HR.EMP_Details WITH (TABLOCK)
SET ReviewDate = DATEADD(YEAR, 1, GETDATE());

-- XLOCK - Forces exclusive locks
SELECT * FROM HR.EMP_Details WITH (XLOCK)
WHERE EmployeeID = 1003;

-- 5.2 Multiple Lock Hints
-- You can combine multiple lock hints
SELECT * FROM HR.EMP_Details WITH (ROWLOCK, UPDLOCK, HOLDLOCK)
WHERE EmployeeID = 1004;

-- 5.3 Table Hints for Specific Operations
-- READPAST - Skip locked rows
SELECT * FROM HR.EMP_Details WITH (READPAST)
WHERE DepartmentID = 1;

-- READCOMMITTEDLOCK - Explicitly use read committed isolation
SELECT * FROM HR.EMP_Details WITH (READCOMMITTEDLOCK)
WHERE DepartmentID = 1;

-- =============================================
-- PART 6: DEADLOCKS
-- =============================================

/*
A deadlock occurs when two or more sessions are waiting for each other to release locks,
resulting in a circular dependency where none can proceed.

SQL Server automatically detects deadlocks and chooses a victim to terminate,
allowing the other session(s) to continue.
*/

-- 6.1 Deadlock Example
-- Run these in separate sessions to create a deadlock

-- Session 1
/*
BEGIN TRANSACTION;
    -- First, update Table A
    UPDATE HR.Departments
    SET Budget = Budget * 1.1
    WHERE DepartmentID = 1;
    
    -- Wait to simulate business logic
    WAITFOR DELAY '00:00:05';
    
    -- Then, try to update Table B
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;
*/

-- Session 2
/*
BEGIN TRANSACTION;
    -- First, update Table B
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.05
    WHERE DepartmentID = 1;
    
    -- Wait to simulate business logic
    WAITFOR DELAY '00:00:05';
    
    -- Then, try to update Table A
    UPDATE HR.Departments
    SET Budget = Budget * 1.05
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;
*/

-- 6.2 Deadlock Prevention Techniques

-- 1. Access objects in the same order
BEGIN TRANSACTION;
    -- Always update Departments first, then EMP_Details
    UPDATE HR.Departments
    SET Budget = Budget * 1.1
    WHERE DepartmentID = 1;
    
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 2. Use UPDLOCK to acquire locks early
BEGIN TRANSACTION;
    -- Acquire all needed locks at the beginning
    SELECT * FROM HR.Departments WITH (UPDLOCK)
    WHERE DepartmentID = 1;
    
    SELECT * FROM HR.EMP_Details WITH (UPDLOCK)
    WHERE DepartmentID = 1;
    
    -- Now perform updates
    UPDATE HR.Departments
    SET Budget = Budget * 1.1
    WHERE DepartmentID = 1;
    
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 3. Keep transactions short
-- Instead of one long transaction, use multiple short ones

-- Update departments
BEGIN TRANSACTION;
    UPDATE HR.Departments
    SET Budget = Budget * 1.1
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- Update employees
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 6.3 Handling Deadlocks in Applications
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE HR.Departments
        SET Budget = Budget * 1.1
        WHERE DepartmentID = 1;
        
        UPDATE HR.EMP_Details
        SET Salary = Salary * 1.1
        WHERE DepartmentID = 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 1205 -- Deadlock victim error number
    BEGIN
        -- Log the deadlock
        INSERT INTO HR.ErrorLog (ErrorMessage, ErrorType)
        VALUES ('Deadlock detected and transaction was rolled back', 'Deadlock');
        
        -- Could retry the transaction here
        -- EXEC ProcessDepartmentUpdates @DeptID = 1;
    END
    ELSE
    BEGIN
        -- Handle other errors
        IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    
    -- Log error
    INSERT INTO Inventory.ErrorLog (ErrorMessage, ErrorNumber, ErrorProcedure)
    VALUES (ERROR_MESSAGE(), ERROR_NUMBER(), ERROR_PROCEDURE());
    
    -- Rethrow error
    THROW;
END CATCH;

-- 9.2 Concurrent User Access in Web Application
-- Simulating how to handle concurrent edits to the same record
BEGIN TRY
    DECLARE @EmployeeID INT = 1001;
    DECLARE @LastModifiedDate DATETIME;
    DECLARE @ClientLastModifiedDate DATETIME = '2023-01-15 14:30:00'; -- From web form
    
    -- First check if record has been modified since client loaded it
    SELECT @LastModifiedDate = LastModifiedDate
    FROM HR.EMP_Details
    WHERE EmployeeID = @EmployeeID;
    
    -- If someone else modified it since the client loaded it
    IF @LastModifiedDate > @ClientLastModifiedDate
    BEGIN
        -- Handle concurrent modification
        THROW 50002, 'Record was modified by another user. Please refresh and try again.', 1;
    END
    
    -- If no conflict, proceed with update
    BEGIN TRANSACTION;
        UPDATE HR.EMP_Details
        SET Salary = 75000, -- New value from web form
            LastModifiedDate = GETDATE()
        WHERE EmployeeID = @EmployeeID
        AND LastModifiedDate = @ClientLastModifiedDate; -- Optimistic concurrency check
        
        IF @@ROWCOUNT = 0
        BEGIN
            -- Another update happened between our check and update
            ROLLBACK TRANSACTION;
            THROW 50002, 'Record was modified by another user. Please refresh and try again.', 1;
        END
        
        -- Log the change
        INSERT INTO HR.AuditLog (Action, TableName, RecordID)
        VALUES ('Update', 'HR.EMP_Details', @EmployeeID);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    
    -- Return error to application
    THROW;
END CATCH;

-- =============================================
-- PART 10: CONCLUSION
-- =============================================

/*
Understanding SQL Server locks is crucial for developing high-performance, 
concurrent database applications. Key takeaways:

1. Locks ensure data integrity in multi-user environments
2. Different lock modes serve different purposes (shared, exclusive, update, etc.)
3. Lock granularity affects the balance between concurrency and overhead
4. Deadlocks occur when transactions block each other in a circular pattern
5. Proper transaction design minimizes blocking and deadlocks
6. Monitoring tools help identify and resolve locking issues
7. Appropriate isolation levels balance consistency and concurrency

By applying the techniques and best practices in this guide, you can develop
database applications that efficiently handle concurrent access while
maintaining data integrity.
*/
            ROLLBACK TRANSACTION;
            
        INSERT INTO HR.ErrorLog (ErrorMessage, ErrorNumber, ErrorLine)
        VALUES (ERROR_MESSAGE(), ERROR_NUMBER(), ERROR_LINE());
    END
END CATCH;

-- 6.4 Monitoring Deadlocks

-- Enable trace flag to log deadlocks to SQL Server error log
DBCC TRACEON (1222, -1);

-- View deadlock information using Extended Events
/*
CREATE EVENT SESSION [DeadlockMonitor] ON SERVER 
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.event_file(SET filename=N'DeadlockMonitor')
WITH (MAX_MEMORY=4096 KB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS, 
      MAX_DISPATCH_LATENCY=30 SECONDS, MAX_EVENT_SIZE=0 KB, 
      MEMORY_PARTITION_MODE=NONE, TRACK_CAUSALITY=OFF, STARTUP_STATE=OFF)
GO

-- Start the session
ALTER EVENT SESSION [DeadlockMonitor] ON SERVER STATE = START;
GO
*/

-- =============================================
-- PART 7: LOCK MONITORING AND TROUBLESHOOTING
-- =============================================

-- 7.1 Viewing Current Locks
-- Shows locks held by all sessions
SELECT 
    DB_NAME(resource_database_id) AS DatabaseName,
    OBJECT_NAME(resource_associated_entity_id) AS ObjectName,
    request_session_id AS SPID,
    resource_type AS ResourceType,
    resource_description AS ResourceDescription,
    request_mode AS LockMode,
    request_status AS LockStatus
FROM sys.dm_tran_locks
WHERE resource_database_id = DB_ID();

-- 7.2 Finding Blocking Sessions
-- Shows which sessions are blocking others
SELECT 
    blocking.session_id AS BlockingSPID,
    blocked.session_id AS BlockedSPID,
    DB_NAME(blocked.database_id) AS DatabaseName,
    OBJECT_NAME(blocked_objects.object_id) AS BlockedObjectName,
    blocked.wait_type AS WaitType,
    blocked.wait_time / 1000.0 AS WaitTimeSeconds,
    blocked_sql.text AS BlockedSQL,
    blocking_sql.text AS BlockingSQL
FROM sys.dm_exec_requests blocked
JOIN sys.dm_exec_sessions blocking ON blocked.blocking_session_id = blocking.session_id
OUTER APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_sql
OUTER APPLY sys.dm_exec_sql_text(blocking.most_recent_sql_handle) blocking_sql
LEFT JOIN sys.partitions blocked_partitions ON blocked.resource_associated_entity_id = blocked_partitions.hobt_id
LEFT JOIN sys.objects blocked_objects ON blocked_partitions.object_id = blocked_objects.object_id
WHERE blocked.blocking_session_id > 0;

-- 7.3 Identifying Long-Running Transactions
SELECT 
    trans.session_id,
    sess.login_name,
    DB_NAME(trans.database_id) AS DatabaseName,
    task_state,
    command,
    OBJECT_NAME(resource_associated_entity_id) AS ObjectName,
    request_mode,
    request_status,
    wait_type,
    wait_time / 1000.0 AS WaitTimeSeconds,
    trans.transaction_id,
    trans.open_transaction_count,
    trans.transaction_begin_time,
    DATEDIFF(SECOND, trans.transaction_begin_time, GETDATE()) AS TransactionDurationSeconds,
    sql_text.text AS SQLStatement
FROM sys.dm_tran_active_transactions act_trans
JOIN sys.dm_tran_session_transactions trans ON act_trans.transaction_id = trans.transaction_id
LEFT JOIN sys.dm_exec_sessions sess ON trans.session_id = sess.session_id
LEFT JOIN sys.dm_exec_requests req ON trans.session_id = req.session_id
LEFT JOIN sys.dm_tran_locks locks ON trans.session_id = locks.request_session_id
OUTER APPLY sys.dm_exec_sql_text(req.sql_handle) sql_text
WHERE act_trans.transaction_type = 1 -- User transaction
AND DATEDIFF(SECOND, act_trans.transaction_begin_time, GETDATE()) > 60 -- Longer than 1 minute
ORDER BY TransactionDurationSeconds DESC;

-- 7.4 Killing a Blocking Process
-- Use with extreme caution!
-- KILL 52; -- Replace 52 with the actual SPID

-- =============================================
-- PART 8: LOCK BEST PRACTICES
-- =============================================

/*
1. Keep transactions as short as possible
2. Access objects in the same order in all transactions
3. Use appropriate isolation levels for your needs
4. Avoid user interaction during transactions
5. Be cautious with lock hints - use only when necessary
6. Consider using optimistic concurrency for read-heavy workloads
7. Index your data properly to minimize lock ranges
8. Monitor and resolve blocking issues promptly
9. Use snapshot isolation for reporting queries when appropriate
10. Implement proper error handling for deadlocks
*/

-- 8.1 Example of Good Transaction Design
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
    
    -- Keep transaction short and focused
    BEGIN TRANSACTION;
        -- Use proper indexing and specific updates
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
    INSERT INTO Inventory.ErrorLog (ErrorMessage, ErrorNumber, ErrorProcedure)
    VALUES (ERROR_MESSAGE(), ERROR_NUMBER(), ERROR_PROCEDURE());
    
    -- Rethrow error
    THROW;
END CATCH;

-- 9.2 Concurrent User Access in Web Application
-- Simulating how to handle concurrent edits to the same record
BEGIN TRY
    DECLARE @EmployeeID INT = 1001;
    DECLARE @LastModifiedDate DATETIME;
    DECLARE @ClientLastModifiedDate DATETIME = '2023-01-15 14:30:00'; -- From web form
    
    -- First check if record has been modified since client loaded it
    SELECT @LastModifiedDate = LastModifiedDate
    FROM HR.EMP_Details
    WHERE EmployeeID = @EmployeeID;
    
    -- If someone else modified it since the client loaded it
    IF @LastModifiedDate > @ClientLastModifiedDate
    BEGIN
        -- Handle concurrent modification
        THROW 50002, 'Record was modified by another user. Please refresh and try again.', 1;
    END
    
    -- If no conflict, proceed with update
    BEGIN TRANSACTION;
        UPDATE HR.EMP_Details
        SET Salary = 75000, -- New value from web form
            LastModifiedDate = GETDATE()
        WHERE EmployeeID = @EmployeeID
        AND LastModifiedDate = @ClientLastModifiedDate; -- Optimistic concurrency check
        
        IF @@ROWCOUNT = 0
        BEGIN
            -- Another update happened between our check and update
            ROLLBACK TRANSACTION;
            THROW 50002, 'Record was modified by another user. Please refresh and try again.', 1;
        END
        
        -- Log the change
        INSERT INTO HR.AuditLog (Action, TableName, RecordID)
        VALUES ('Update', 'HR.EMP_Details', @EmployeeID);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    
    -- Return error to application
    THROW;
END CATCH;

-- =============================================
-- PART 10: CONCLUSION
-- =============================================

/*
Understanding SQL Server locks is crucial for developing high-performance, 
concurrent database applications. Key takeaways:

1. Locks ensure data integrity in multi-user environments
2. Different lock modes serve different purposes (shared, exclusive, update, etc.)
3. Lock granularity affects the balance between concurrency and overhead
4. Deadlocks occur when transactions block each other in a circular pattern
5. Proper transaction design minimizes blocking and deadlocks
6. Monitoring tools help identify and resolve locking issues
7. Appropriate isolation levels balance consistency and concurrency

By applying the techniques and best practices in this guide, you can develop
database applications that efficiently handle concurrent access while
maintaining data integrity.
*/
        ROLLBACK TRANSACTION;
    
    IF ERROR_NUMBER() = 1205 -- Deadlock victim
    BEGIN
        -- Log and potentially retry
        INSERT INTO HR.ErrorLog (ErrorMessage)
        VALUES ('Deadlock detected during salary update');
    END
    ELSE
    BEGIN
        -- Handle other errors
        INSERT INTO HR.ErrorLog (ErrorMessage, ErrorNumber, ErrorLine)
        VALUES (ERROR_MESSAGE(), ERROR_NUMBER(), ERROR_LINE());
    END
    
    THROW;
END CATCH;

-- 8.2 Using Appropriate Isolation Levels

-- For read operations that don't need perfect consistency
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT * FROM HR.EMP_Details WHERE DepartmentID = 1;

-- For reports that shouldn't block or be blocked
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
SELECT * FROM HR.EMP_Details;

-- For operations requiring complete isolation
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
    SELECT * FROM HR.EMP_Details WHERE DepartmentID = 1;
    -- Other operations...
COMMIT TRANSACTION;

-- =============================================
-- PART 9: REAL-WORLD SCENARIOS
-- =============================================

-- 9.1 Inventory Management System
BEGIN TRY
    DECLARE @ProductID INT = 101;
    DECLARE @OrderQuantity INT = 5;
    DECLARE @CurrentStock INT;
    
    -- Check stock outside transaction
    SELECT @CurrentStock = StockQuantity 
    FROM Inventory.Products 
    WHERE ProductID = @ProductID;
    
    IF @CurrentStock < @OrderQuantity
        THROW 50001, 'Insufficient inventory', 1;
    
    -- Start transaction for inventory update
    BEGIN TRANSACTION;
        -- Lock the inventory record
        SELECT @CurrentStock = StockQuantity 
        FROM Inventory.Products WITH (UPDLOCK, ROWLOCK)
        WHERE ProductID = @ProductID;
        
        -- Double-check within transaction
        IF @CurrentStock < @OrderQuantity
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 50001, 'Insufficient inventory', 1;
        END
        
        -- Update inventory
        UPDATE Inventory.Products
        SET StockQuantity = StockQuantity - @OrderQuantity,
            LastUpdated = GETDATE()
        WHERE ProductID = @ProductID;
        
        -- Create order record
        INSERT INTO Sales.Orders (ProductID, Quantity, OrderDate)
        VALUES (@ProductID, @OrderQuantity, GETDATE());
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    
    -- Log error
    INSERT INTO Inventory.ErrorLog (ErrorMessage, ErrorNumber, ErrorProcedure)
    VALUES (ERROR_MESSAGE(), ERROR_NUMBER(), ERROR_PROCEDURE());
    
    -- Rethrow error
    THROW;
END CATCH;

-- 9.2 Concurrent User Access in Web Application
-- Simulating how to handle concurrent edits to the same record
BEGIN TRY
    DECLARE @EmployeeID INT = 1001;
    DECLARE @LastModifiedDate DATETIME;
    DECLARE @ClientLastModifiedDate DATETIME = '2023-01-15 14:30:00'; -- From web form
    
    -- First check if record has been modified since client loaded it
    SELECT @LastModifiedDate = LastModifiedDate
    FROM HR.EMP_Details
    WHERE EmployeeID = @EmployeeID;
    
    -- If someone else modified it since the client loaded it
    IF @LastModifiedDate > @ClientLastModifiedDate
    BEGIN
        -- Handle concurrent modification
        THROW 50002, 'Record was modified by another user. Please refresh and try again.', 1;
    END
    
    -- If no conflict, proceed with update
    BEGIN TRANSACTION;
        UPDATE HR.EMP_Details
        SET Salary = 75000, -- New value from web form
            LastModifiedDate = GETDATE()
        WHERE EmployeeID = @EmployeeID
        AND LastModifiedDate = @ClientLastModifiedDate; -- Optimistic concurrency check
        
        IF @@ROWCOUNT = 0
        BEGIN
            -- Another update happened between our check and update
            ROLLBACK TRANSACTION;
            THROW 50002, 'Record was modified by another user. Please refresh and try again.', 1;
        END
        
        -- Log the change
        INSERT INTO HR.AuditLog (Action, TableName, RecordID)
        VALUES ('Update', 'HR.EMP_Details', @EmployeeID);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    
    -- Return error to application
    THROW;
END CATCH;

-- =============================================
-- PART 10: CONCLUSION
-- =============================================

/*
Understanding SQL Server locks is crucial for developing high-performance, 
concurrent database applications. Key takeaways:

1. Locks ensure data integrity in multi-user environments
2. Different lock modes serve different purposes (shared, exclusive, update, etc.)
3. Lock granularity affects the balance between concurrency and overhead
4. Deadlocks occur when transactions block each other in a circular pattern
5. Proper transaction design minimizes blocking and deadlocks
6. Monitoring tools help identify and resolve locking issues
7. Appropriate isolation levels balance consistency and concurrency

By applying the techniques and best practices in this guide, you can develop
database applications that efficiently handle concurrent access while
maintaining data integrity.
*/