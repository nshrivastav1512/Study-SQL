/*
File: 15_ISOLATION_LEVELS.sql
Description: This script demonstrates different isolation levels in SQL Server and provides examples for each level.
Author: [Your Name]
Date: [Current Date]

-- ISOLATION LEVELS Guide --
1. READ UNCOMMITTED: This isolation level allows dirty reads, meaning it can read uncommitted data.
2. READ COMMITTED: This is the default isolation level. It only reads committed data.
3. REPEATABLE READ: This isolation level ensures that the same data is returned for the same query, even if the data is modified by other transactions.
4. SERIALIZABLE: This is the most restrictive isolation level, providing complete isolation and preventing dirty reads, non-repeatable reads, and phantom reads.
5. SNAPSHOT: This isolation level allows each transaction to see a consistent snapshot of the data as of the start of the transaction.
6. Demonstrating Dirty Reads: This section demonstrates how dirty reads can occur when one transaction reads uncommitted data from another transaction.
7. Preventing Lost Updates: This section shows how to prevent lost updates by using the SERIALIZABLE isolation level.
8. Using NOLOCK Hint: This hint is equivalent to the READ UNCOMMITTED isolation level and allows dirty reads.
9. Using READCOMMITTED Hint: This hint is equivalent to the READ COMMITTED isolation level.
10. Using ROWLOCK Hint: This hint ensures that only the rows being updated are locked, rather than the entire table.

Note: The script assumes the existence of a database named HRSystem and a table named HR.EMP_Details.
*/
-- =============================================
-- ISOLATION LEVELS Guide
-- =============================================

USE HRSystem;
GO

-- 1. READ UNCOMMITTED Example
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
BEGIN TRANSACTION;
    -- This will read even uncommitted data (dirty reads)
    SELECT * FROM HR.EMP_Details
    WHERE Salary > 50000;
COMMIT TRANSACTION;

-- 2. READ COMMITTED Example (Default)
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;
    -- This will only read committed data
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID = 1;
    
    -- Wait 5 seconds to simulate business logic
    WAITFOR DELAY '00:00:05';
COMMIT TRANSACTION;

-- 3. REPEATABLE READ Example
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;
    -- First read
    SELECT * FROM HR.EMP_Details
    WHERE DepartmentID = 1;
    
    -- Do some processing (simulated)
    WAITFOR DELAY '00:00:02';
    
    -- Second read - will get same results
    SELECT * FROM HR.EMP_Details
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 4. SERIALIZABLE Example
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
    -- Most restrictive - complete isolation
    SELECT * FROM HR.EMP_Details
    WHERE DepartmentID = 1;
    
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 5. SNAPSHOT Example (if enabled on database)
-- First, enable SNAPSHOT isolation
ALTER DATABASE HRSystem
SET ALLOW_SNAPSHOT_ISOLATION ON;

SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;
    -- Will see consistent data as of transaction start
    SELECT * FROM HR.EMP_Details;
    WAITFOR DELAY '00:00:05';
    SELECT * FROM HR.EMP_Details;
COMMIT TRANSACTION;

-- 6. Demonstrating Dirty Reads
-- Transaction 1 (in first session)
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 2
    WHERE EmployeeID = 1001;
    WAITFOR DELAY '00:00:10';
    ROLLBACK TRANSACTION;

-- Transaction 2 (in second session)
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT * FROM HR.EMP_Details
WHERE EmployeeID = 1001;

-- 7. Preventing Lost Updates
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
    -- Read current salary
    DECLARE @CurrentSalary DECIMAL(12,2);
    SELECT @CurrentSalary = Salary
    FROM HR.EMP_Details
    WHERE EmployeeID = 1001;
    
    -- Process (simulate delay)
    WAITFOR DELAY '00:00:02';
    
    -- Update salary
    UPDATE HR.EMP_Details
    SET Salary = @CurrentSalary * 1.1
    WHERE EmployeeID = 1001;
COMMIT TRANSACTION;

-- 8. Using NOLOCK Hint (Same as READ UNCOMMITTED)
SELECT * FROM HR.EMP_Details WITH (NOLOCK)
WHERE DepartmentID = 1;

-- 9. Using READCOMMITTED Hint
SELECT * FROM HR.EMP_Details WITH (READCOMMITTED)
WHERE DepartmentID = 1;

-- 10. Using ROWLOCK Hint
UPDATE HR.EMP_Details WITH (ROWLOCK)
SET Salary = Salary * 1.1
WHERE EmployeeID = 1001;