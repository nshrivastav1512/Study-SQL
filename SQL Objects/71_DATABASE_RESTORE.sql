-- =============================================
-- DATABASE RESTORE Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Database Restore operations, including:
- Types of restore operations
- Point-in-time recovery
- Piecemeal restore operations
- Restore verification and validation
- Restore strategies for different scenarios
- Real-world disaster recovery examples
- Monitoring restore operations
*/

USE master;
GO

-- =============================================
-- PART 1: DATABASE RESTORE FUNDAMENTALS
-- =============================================

-- What is a Database Restore?
-- A database restore is the process of copying data from a backup into a database and then rolling forward
-- any transactions that were recorded in the transaction log to bring the database to the desired recovery point

-- Types of Restore Operations:
-- 1. Complete Restore: Restores the entire database to a specific point in time
-- 2. File or Filegroup Restore: Restores specific files or filegroups
-- 3. Page Restore: Restores specific damaged pages
-- 4. Piecemeal Restore: Restores and recovers a database in stages

-- Restore Phases:
-- 1. Data Copy Phase: Copies data from backup media to the data files
-- 2. Redo Phase: Rolls forward committed transactions from the log
-- 3. Undo Phase: Rolls back uncommitted transactions

-- =============================================
-- PART 2: BASIC DATABASE RESTORE OPERATIONS
-- =============================================

-- First, let's ensure we have a database to restore
-- Note: This assumes you've run the 70_DATABASE_BACKUP.sql script to create backups

-- 1. Complete Database Restore from a Full Backup
-- Restores the entire database from a full backup

-- Basic Restore Syntax
RESTORE DATABASE HRSystem_Restored
FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak'
WITH 
    MOVE 'HRSystem' TO 'C:\SQLData\HRSystem_Restored.mdf',
    MOVE 'HRSystem_log' TO 'C:\SQLData\HRSystem_Restored_log.ldf',
    RECOVERY,
    STATS = 10;
-- Note: RECOVERY option brings the database online after restore

-- 2. Restore with NORECOVERY
-- Leaves the database in a restoring state for additional restores

RESTORE DATABASE HRSystem_Restored
FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak'
WITH 
    MOVE 'HRSystem' TO 'C:\SQLData\HRSystem_Restored.mdf',
    MOVE 'HRSystem_log' TO 'C:\SQLData\HRSystem_Restored_log.ldf',
    NORECOVERY,
    STATS = 10;

-- 3. Restore a Differential Backup
-- Must be applied after a full backup with NORECOVERY

RESTORE DATABASE HRSystem_Restored
FROM DISK = 'C:\SQLBackups\HRSystem_Diff.bak'
WITH 
    NORECOVERY,
    STATS = 10;

-- 4. Restore Transaction Log Backups
-- Must be applied in sequence after a full or differential backup with NORECOVERY

RESTORE LOG HRSystem_Restored
FROM DISK = 'C:\SQLBackups\HRSystem_Log.bak'
WITH 
    RECOVERY, -- Last restore in sequence uses RECOVERY to bring database online
    STATS = 10;

-- =============================================
-- PART 3: POINT-IN-TIME RECOVERY
-- =============================================

-- Point-in-time recovery allows restoring a database to a specific moment in time
-- This is useful for recovering from logical errors or user mistakes

-- 1. Restore to a Specific Date and Time
-- Requires FULL or BULK_LOGGED recovery model and transaction log backups

-- First, restore the full backup with NORECOVERY
RESTORE DATABASE HRSystem_PITR
FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak'
WITH 
    MOVE 'HRSystem' TO 'C:\SQLData\HRSystem_PITR.mdf',
    MOVE 'HRSystem_log' TO 'C:\SQLData\HRSystem_PITR_log.ldf',
    NORECOVERY,
    STATS = 10;

-- Then restore differential backup (if applicable) with NORECOVERY
RESTORE DATABASE HRSystem_PITR
FROM DISK = 'C:\SQLBackups\HRSystem_Diff.bak'
WITH 
    NORECOVERY,
    STATS = 10;

-- Finally, restore transaction log with STOPAT time
RESTORE LOG HRSystem_PITR
FROM DISK = 'C:\SQLBackups\HRSystem_Log.bak'
WITH 
    RECOVERY,
    STOPAT = '2023-06-15T14:30:00', -- Specify the exact point in time
    STATS = 10;

-- 2. Restore to a Marked Transaction
-- Useful when you've marked important transactions in the log

-- First, let's see how to mark a transaction (for demonstration)
USE HRSystem;
GO

BEGIN TRANSACTION ImportantUpdate WITH MARK 'Major salary adjustment';
    UPDATE HR.Employees SET Salary = Salary * 1.10 WHERE EmployeeID = 1;
COMMIT TRANSACTION ImportantUpdate;
GO

-- Backup the transaction log to capture the mark
BACKUP LOG HRSystem TO DISK = 'C:\SQLBackups\HRSystem_MarkedTran_Log.bak';
GO

-- View marked transactions in backup
RESTORE HEADERONLY FROM DISK = 'C:\SQLBackups\HRSystem_MarkedTran_Log.bak';
GO

-- Restore to the marked transaction
RESTORE DATABASE HRSystem_Marked
FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak'
WITH 
    MOVE 'HRSystem' TO 'C:\SQLData\HRSystem_Marked.mdf',
    MOVE 'HRSystem_log' TO 'C:\SQLData\HRSystem_Marked_log.ldf',
    NORECOVERY,
    STATS = 10;

RESTORE LOG HRSystem_Marked
FROM DISK = 'C:\SQLBackups\HRSystem_MarkedTran_Log.bak'
WITH 
    RECOVERY,
    STOPBEFOREMARK = 'Major salary adjustment', -- or STOPATMARK to include the transaction
    STATS = 10;

-- =============================================
-- PART 4: ADVANCED RESTORE SCENARIOS
-- =============================================

-- 1. Piecemeal Restore
-- Restores and recovers a database in stages, starting with the primary filegroup

-- First, restore the primary filegroup
RESTORE DATABASE HRSystem_Piecemeal FILEGROUP = 'PRIMARY'
FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak'
WITH 
    PARTIAL, -- Indicates a piecemeal restore
    MOVE 'HRSystem' TO 'C:\SQLData\HRSystem_Piecemeal.mdf',
    MOVE 'HRSystem_log' TO 'C:\SQLData\HRSystem_Piecemeal_log.ldf',
    NORECOVERY,
    STATS = 10;

-- Bring the primary filegroup online
RESTORE DATABASE HRSystem_Piecemeal WITH RECOVERY;

-- Later, restore additional filegroups as needed
RESTORE DATABASE HRSystem_Piecemeal FILEGROUP = 'ArchiveData'
FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak'
WITH 
    RECOVERY,
    STATS = 10;

-- 2. Page Restore
-- Restores specific damaged pages identified by their page ID

-- First, identify corrupted pages
DBCC CHECKDB (HRSystem) WITH TABLERESULTS;

-- Restore specific pages (example with hypothetical page IDs)
RESTORE DATABASE HRSystem PAGE = '1:57, 1:202'
FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak'
WITH 
    NORECOVERY;

-- Apply transaction log to bring pages up to date
RESTORE LOG HRSystem
FROM DISK = 'C:\SQLBackups\HRSystem_Log.bak'
WITH 
    RECOVERY;

-- 3. Restore from Multiple Backup Files
-- When a backup spans multiple files

RESTORE DATABASE HRSystem_Multi
FROM 
    DISK = 'C:\SQLBackups\HRSystem_Multi_1.bak',
    DISK = 'C:\SQLBackups\HRSystem_Multi_2.bak',
    DISK = 'C:\SQLBackups\HRSystem_Multi_3.bak'
WITH 
    MOVE 'HRSystem' TO 'C:\SQLData\HRSystem_Multi.mdf',
    MOVE 'HRSystem_log' TO 'C:\SQLData\HRSystem_Multi_log.ldf',
    RECOVERY,
    STATS = 10;

-- 4. Restore with Standby Mode
-- Leaves database in read-only mode but ready for additional restores

RESTORE DATABASE HRSystem_Standby
FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak'
WITH 
    MOVE 'HRSystem' TO 'C:\SQLData\HRSystem_Standby.mdf',
    MOVE 'HRSystem_log' TO 'C:\SQLData\HRSystem_Standby_log.ldf',
    STANDBY = 'C:\SQLBackups\HRSystem_Undo.dat', -- Undo file for standby mode
    STATS = 10;

-- =============================================
-- PART 5: RESTORE VERIFICATION AND VALIDATION
-- =============================================

-- 1. Verify Backup Before Restore
-- Checks the backup for readability and completeness without restoring

RESTORE VERIFYONLY FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak';

-- 2. View Backup Header Information
-- Shows details about the backup set

RESTORE HEADERONLY FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak';

-- 3. View Backup File List
-- Shows the database files contained in the backup

RESTORE FILELISTONLY FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak';

-- 4. View Backup Label Information
-- Shows information about the backup media

RESTORE LABELONLY FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak';

-- 5. Database Consistency Check After Restore
-- Verifies database integrity after restore

DBCC CHECKDB (HRSystem_Restored) WITH ALL_ERRORMSGS, NO_INFOMSGS;

-- =============================================
-- PART 6: REAL-WORLD DISASTER RECOVERY SCENARIOS
-- =============================================

-- 1. Complete Database Failure Recovery
-- When a database becomes corrupted or the data files are lost

-- Step 1: Restore the most recent full backup
RESTORE DATABASE HRSystem_Recovery
FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak'
WITH 
    MOVE 'HRSystem' TO 'C:\SQLData\HRSystem_Recovery.mdf',
    MOVE 'HRSystem_log' TO 'C:\SQLData\HRSystem_Recovery_log.ldf',
    NORECOVERY,
    STATS = 10;

-- Step 2: Restore the most recent differential backup (if available)
RESTORE DATABASE HRSystem_Recovery
FROM DISK = 'C:\SQLBackups\HRSystem_Diff.bak'
WITH 
    NORECOVERY,
    STATS = 10;

-- Step 3: Restore all transaction log backups in sequence
RESTORE LOG HRSystem_Recovery
FROM DISK = 'C:\SQLBackups\HRSystem_Log1.bak'
WITH 
    NORECOVERY,
    STATS = 10;

RESTORE LOG HRSystem_Recovery
FROM DISK = 'C:\SQLBackups\HRSystem_Log2.bak'
WITH 
    RECOVERY, -- Last log backup uses RECOVERY
    STATS = 10;

-- 2. Recovery from Accidental Data Deletion
-- When important data is accidentally deleted

-- Simulate accidental deletion
USE HRSystem;
GO

BEGIN TRANSACTION;
    DELETE FROM HR.Employees WHERE EmployeeID = 2; -- Accidental deletion
COMMIT TRANSACTION;
GO

-- Backup the log to capture the deletion
BACKUP LOG HRSystem TO DISK = 'C:\SQLBackups\HRSystem_AfterDelete_Log.bak';
GO

-- Restore to just before the deletion
RESTORE DATABASE HRSystem_Recovered
FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak'
WITH 
    MOVE 'HRSystem' TO 'C:\SQLData\HRSystem_Recovered.mdf',
    MOVE 'HRSystem_log' TO 'C:\SQLData\HRSystem_Recovered_log.ldf',
    NORECOVERY,
    STATS = 10;

-- Restore log backups up to a point just before the deletion
RESTORE LOG HRSystem_Recovered
FROM DISK = 'C:\SQLBackups\HRSystem_Log.bak'
WITH 
    NORECOVERY,
    STATS = 10;

RESTORE LOG HRSystem_Recovered
FROM DISK = 'C:\SQLBackups\HRSystem_AfterDelete_Log.bak'
WITH 
    RECOVERY,
    STOP