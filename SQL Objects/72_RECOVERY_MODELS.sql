-- =============================================
-- RECOVERY MODELS Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Recovery Models, including:
- Types of recovery models (Full, Simple, Bulk-Logged)
- How each recovery model affects backup and restore operations
- When to use each recovery model
- Switching between recovery models
- Impact on transaction log management
- Performance considerations
- Real-world scenarios and best practices
*/

USE master;
GO

-- =============================================
-- PART 1: RECOVERY MODEL FUNDAMENTALS
-- =============================================

-- What is a Recovery Model?
-- A recovery model is a database configuration that controls how transactions are logged,
-- whether the transaction log requires backing up, and what kinds of restore operations are available

-- SQL Server provides three recovery models:
-- 1. FULL: Provides complete protection against data loss by logging all transactions
-- 2. SIMPLE: Automatically reclaims log space to keep the log file small
-- 3. BULK_LOGGED: Minimally logs bulk operations to improve performance

-- View the current recovery model of all databases
SELECT name, recovery_model_desc
FROM sys.databases
ORDER BY name;

-- =============================================
-- PART 2: FULL RECOVERY MODEL
-- =============================================

-- 1. Characteristics of FULL Recovery Model
-- - All operations are fully logged
-- - Provides complete point-in-time recovery
-- - Requires transaction log backups to manage log size
-- - Supports all recovery scenarios

-- Create a database with FULL recovery model
IF DB_ID('HRSystem_Full') IS NULL
BEGIN
    CREATE DATABASE HRSystem_Full;
    ALTER DATABASE HRSystem_Full SET RECOVERY FULL;
    
    -- Create a simple table for demonstration
    EXEC('USE HRSystem_Full; 
         CREATE SCHEMA HR;
         CREATE TABLE HR.Employees (
             EmployeeID INT PRIMARY KEY IDENTITY(1,1),
             FirstName NVARCHAR(50),
             LastName NVARCHAR(50),
             HireDate DATE,
             Salary DECIMAL(10,2)
         );
    ');
    
    PRINT 'HRSystem_Full database created with FULL recovery model.';
END
ELSE
BEGIN
    PRINT 'Using existing HRSystem_Full database.';
    ALTER DATABASE HRSystem_Full SET RECOVERY FULL;
END
GO

-- 2. Transaction Logging in FULL Recovery Model
-- All transactions are fully logged, enabling point-in-time recovery

USE HRSystem_Full;
GO

-- Insert sample data
INSERT INTO HR.Employees (FirstName, LastName, HireDate, Salary)
VALUES ('John', 'Smith', '2020-01-15', 55000);
GO

-- Each transaction is fully logged
BEGIN TRANSACTION;
    UPDATE HR.Employees SET Salary = 60000 WHERE EmployeeID = 1;
COMMIT TRANSACTION;
GO

-- 3. Backup Strategy for FULL Recovery Model

-- Full backup
BACKUP DATABASE HRSystem_Full
TO DISK = 'C:\SQLBackups\HRSystem_Full_DB.bak'
WITH 
    NAME = 'HRSystem_Full-Full Backup',
    DESCRIPTION = 'Full backup of HRSystem_Full database';

-- Transaction log backup (required for FULL recovery model)
BACKUP LOG HRSystem_Full
TO DISK = 'C:\SQLBackups\HRSystem_Full_Log.bak'
WITH 
    NAME = 'HRSystem_Full-Log Backup',
    DESCRIPTION = 'Transaction log backup of HRSystem_Full database';

-- 4. Recovery Scenarios with FULL Recovery Model

-- Point-in-time recovery (requires transaction log backups)
-- Example: Restore to a specific point in time

-- First, restore the full backup with NORECOVERY
RESTORE DATABASE HRSystem_Full_Restored
FROM DISK = 'C:\SQLBackups\HRSystem_Full_DB.bak'
WITH 
    MOVE 'HRSystem_Full' TO 'C:\SQLData\HRSystem_Full_Restored.mdf',
    MOVE 'HRSystem_Full_log' TO 'C:\SQLData\HRSystem_Full_Restored_log.ldf',
    NORECOVERY,
    STATS = 10;

-- Then restore the transaction log with a STOPAT time
RESTORE LOG HRSystem_Full_Restored
FROM DISK = 'C:\SQLBackups\HRSystem_Full_Log.bak'
WITH 
    RECOVERY,
    STOPAT = '2023-06-15T14:30:00',
    STATS = 10;

-- =============================================
-- PART 3: SIMPLE RECOVERY MODEL
-- =============================================

-- 1. Characteristics of SIMPLE Recovery Model
-- - Automatically truncates the transaction log when transactions are committed
-- - No transaction log backups required or possible
-- - Can only recover to the most recent full or differential backup
-- - Simplifies administration but limits recovery options

-- Create a database with SIMPLE recovery model
IF DB_ID('HRSystem_Simple') IS NULL
BEGIN
    CREATE DATABASE HRSystem_Simple;
    ALTER DATABASE HRSystem_Simple SET RECOVERY SIMPLE;
    
    -- Create a simple table for demonstration
    EXEC('USE HRSystem_Simple; 
         CREATE SCHEMA HR;
         CREATE TABLE HR.Employees (
             EmployeeID INT PRIMARY KEY IDENTITY(1,1),
             FirstName NVARCHAR(50),
             LastName NVARCHAR(50),
             HireDate DATE,
             Salary DECIMAL(10,2)
         );
    ');
    
    PRINT 'HRSystem_Simple database created with SIMPLE recovery model.';
END
ELSE
BEGIN
    PRINT 'Using existing HRSystem_Simple database.';
    ALTER DATABASE HRSystem_Simple SET RECOVERY SIMPLE;
END
GO

-- 2. Transaction Logging in SIMPLE Recovery Model
-- Transactions are logged but the log is automatically truncated at checkpoints

USE HRSystem_Simple;
GO

-- Insert sample data
INSERT INTO HR.Employees (FirstName, LastName, HireDate, Salary)
VALUES ('Jane', 'Doe', '2019-03-20', 65000);
GO

-- Each transaction is logged but the log is automatically truncated
BEGIN TRANSACTION;
    UPDATE HR.Employees SET Salary = 70000 WHERE EmployeeID = 1;
COMMIT TRANSACTION;
GO

-- 3. Backup Strategy for SIMPLE Recovery Model

-- Full backup
BACKUP DATABASE HRSystem_Simple
TO DISK = 'C:\SQLBackups\HRSystem_Simple_DB.bak'
WITH 
    NAME = 'HRSystem_Simple-Full Backup',
    DESCRIPTION = 'Full backup of HRSystem_Simple database';

-- Differential backup (useful between full backups)
BACKUP DATABASE HRSystem_Simple
TO DISK = 'C:\SQLBackups\HRSystem_Simple_Diff.bak'
WITH 
    DIFFERENTIAL,
    NAME = 'HRSystem_Simple-Differential Backup',
    DESCRIPTION = 'Differential backup of HRSystem_Simple database';

-- Note: Transaction log backups are not possible in SIMPLE recovery model
-- The following command would fail:
-- BACKUP LOG HRSystem_Simple TO DISK = 'C:\SQLBackups\HRSystem_Simple_Log.bak';

-- 4. Recovery Scenarios with SIMPLE Recovery Model

-- Recovery is limited to the most recent full or differential backup
-- Example: Restore from the most recent full backup

RESTORE DATABASE HRSystem_Simple_Restored
FROM DISK = 'C:\SQLBackups\HRSystem_Simple_DB.bak'
WITH 
    MOVE 'HRSystem_Simple' TO 'C:\SQLData\HRSystem_Simple_Restored.mdf',
    MOVE 'HRSystem_Simple_log' TO 'C:\SQLData\HRSystem_Simple_Restored_log.ldf',
    RECOVERY,
    STATS = 10;

-- =============================================
-- PART 4: BULK-LOGGED RECOVERY MODEL
-- =============================================

-- 1. Characteristics of BULK-LOGGED Recovery Model
-- - Minimally logs bulk operations (BULK INSERT, SELECT INTO, CREATE INDEX, etc.)
-- - Requires transaction log backups like FULL recovery model
-- - Improves performance for bulk operations
-- - Limited point-in-time recovery during bulk operations

-- Create a database with BULK-LOGGED recovery model
IF DB_ID('HRSystem_BulkLogged') IS NULL
BEGIN
    CREATE DATABASE HRSystem_BulkLogged;
    ALTER DATABASE HRSystem_BulkLogged SET RECOVERY BULK_LOGGED;
    
    -- Create a simple table for demonstration
    EXEC('USE HRSystem_BulkLogged; 
         CREATE SCHEMA HR;
         CREATE TABLE HR.Employees (
             EmployeeID INT PRIMARY KEY IDENTITY(1,1),
             FirstName NVARCHAR(50),
             LastName NVARCHAR(50),
             HireDate DATE,
             Salary DECIMAL(10,2)
         );
         
         CREATE TABLE HR.EmployeesBulk (
             EmployeeID INT PRIMARY KEY IDENTITY(1,1),
             FirstName NVARCHAR(50),
             LastName NVARCHAR(50),
             HireDate DATE,
             Salary DECIMAL(10,2)
         );
    ');
    
    PRINT 'HRSystem_BulkLogged database created with BULK-LOGGED recovery model.';
END
ELSE
BEGIN
    PRINT 'Using existing HRSystem_BulkLogged database.';
    ALTER DATABASE HRSystem_BulkLogged SET RECOVERY BULK_LOGGED;
END
GO

-- 2. Transaction Logging in BULK-LOGGED Recovery Model
-- Regular transactions are fully logged, but bulk operations are minimally logged

USE HRSystem_BulkLogged;
GO

-- Regular transactions are fully logged
INSERT INTO HR.Employees (FirstName, LastName, HireDate, Salary)
VALUES ('Robert', 'Johnson', '2021-05-10', 48000);
GO

-- Bulk operations are minimally logged
-- Example: SELECT INTO operation
SELECT * INTO HR.EmployeesCopy FROM HR.Employees;
GO

-- Example: BULK INSERT operation (commented out as it requires a data file)
-- BULK INSERT HR.EmployeesBulk FROM 'C:\Data\employees.csv' WITH (FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');

-- 3. Backup Strategy for BULK-LOGGED Recovery Model

-- Full backup
BACKUP DATABASE HRSystem_BulkLogged
TO DISK = 'C:\SQLBackups\HRSystem_BulkLogged_DB.bak'
WITH 
    NAME = 'HRSystem_BulkLogged-Full Backup',
    DESCRIPTION = 'Full backup of HRSystem_BulkLogged database';

-- Transaction log backup (required after bulk operations)
BACKUP LOG HRSystem_BulkLogged
TO DISK = 'C:\SQLBackups\HRSystem_BulkLogged_Log.bak'
WITH 
    NAME = 'HRSystem_BulkLogged-Log Backup',
    DESCRIPTION = 'Transaction log backup of HRSystem_BulkLogged database';

-- 4. Recovery Scenarios with BULK-LOGGED Recovery Model

-- Point-in-time recovery is limited during periods with bulk operations
-- Example: Restore to the most recent backup

RESTORE DATABASE HRSystem_BulkLogged_Restored
FROM DISK = 'C:\SQLBackups\HRSystem_BulkLogged_DB.bak'
WITH 
    MOVE 'HRSystem_BulkLogged' TO 'C:\SQLData\HRSystem_BulkLogged_Restored.mdf',
    MOVE 'HRSystem_BulkLogged_log' TO 'C:\SQLData\HRSystem_BulkLogged_Restored_log.ldf',
    RECOVERY,
    STATS = 10;

-- =============================================
-- PART 5: SWITCHING BETWEEN RECOVERY MODELS
-- =============================================

-- 1. Switching from SIMPLE to FULL Recovery Model
-- Important: Take a full backup immediately after switching

ALTER DATABASE HRSystem_Simple SET RECOVERY FULL;
GO

-- Take a full backup immediately after switching
BACKUP DATABASE HRSystem_Simple
TO DISK = 'C:\SQLBackups\HRSystem_Simple_AfterFull.bak'
WITH 
    NAME = 'HRSystem_Simple-Full Backup After Recovery Model Change',
    DESCRIPTION = 'Full backup after switching to FULL recovery model';

-- 2. Switching from FULL to SIMPLE Recovery Model
-- Important: This breaks the log chain and limits recovery options

ALTER DATABASE HRSystem_Full SET RECOVERY SIMPLE;
GO

-- 3. Switching from FULL to BULK-LOGGED Recovery Model
-- Useful for temporary bulk operations

ALTER DATABASE HRSystem_Full SET RECOVERY BULK_LOGGED;
GO

-- Perform bulk operations here

-- Switch back to FULL recovery model
ALTER DATABASE HRSystem_Full SET RECOVERY FULL;
GO

-- Take a log backup to maintain the log chain
BACKUP LOG HRSystem_Full
TO DISK = 'C:\SQLBackups\HRSystem_Full_AfterBulk_Log.bak'
WITH 
    NAME = 'HRSystem_Full-Log Backup After Bulk Operations',
    DESCRIPTION = 'Transaction log backup after bulk operations';

-- =============================================
-- PART 6: RECOVERY MODEL BEST PRACTICES
-- =============================================

-- 1. When to Use Each Recovery Model

--