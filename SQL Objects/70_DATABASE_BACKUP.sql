-- =============================================
-- DATABASE BACKUP Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Database Backups, including:
- Types of backups (Full, Differential, Transaction Log)
- Backup strategies and best practices
- Backup compression and encryption
- Backup verification and validation
- Backup automation and scheduling
- Real-world backup scenarios
- Monitoring backup performance and history
*/

USE master;
GO

-- =============================================
-- PART 1: DATABASE BACKUP FUNDAMENTALS
-- =============================================

-- What is a Database Backup?
-- A database backup is a copy of data from a database that can be used to reconstruct data
-- SQL Server supports several types of backups to provide flexibility in recovery strategies

-- Types of Backups:
-- 1. Full Backup: Complete copy of the entire database including all objects, data, and transaction log files
-- 2. Differential Backup: Backup of all data that has changed since the last full backup
-- 3. Transaction Log Backup: Backup of the transaction log containing all log records not backed up previously

-- Backup Devices and Destinations:
-- - Disk: Local or network attached storage
-- - URL: Azure Blob Storage
-- - Tape: Physical tape devices (legacy)

-- =============================================
-- PART 2: CREATING DATABASE BACKUPS
-- =============================================

-- First, let's create a sample database for demonstration
IF DB_ID('HRSystem') IS NULL
BEGIN
    CREATE DATABASE HRSystem;
    
    -- Create a simple table for demonstration
    EXEC('USE HRSystem; 
         CREATE SCHEMA HR;
         CREATE TABLE HR.Employees (
             EmployeeID INT PRIMARY KEY IDENTITY(1,1),
             FirstName NVARCHAR(50),
             LastName NVARCHAR(50),
             HireDate DATE,
             Salary DECIMAL(10,2)
         );
         
         -- Insert sample data
         INSERT INTO HR.Employees (FirstName, LastName, HireDate, Salary)
         VALUES 
            (''John'', ''Smith'', ''2020-01-15'', 55000),
            (''Jane'', ''Doe'', ''2019-03-20'', 65000),
            (''Robert'', ''Johnson'', ''2021-05-10'', 48000);
    ');
    
    PRINT 'HRSystem database created for backup demonstration.';
END
ELSE
BEGIN
    PRINT 'Using existing HRSystem database for backup demonstration.';
END
GO

-- 1. Full Database Backup
-- Captures the entire database at the point in time when the backup is created

-- Basic Full Backup Syntax
BACKUP DATABASE HRSystem
TO DISK = 'C:\SQLBackups\HRSystem_Full.bak'
WITH 
    NAME = 'HRSystem-Full Database Backup',
    DESCRIPTION = 'Full backup of HRSystem database';
-- Note: Ensure the backup directory exists or the command will fail

-- Full Backup with Compression (reduces backup size, increases CPU usage)
BACKUP DATABASE HRSystem
TO DISK = 'C:\SQLBackups\HRSystem_Full_Compressed.bak'
WITH 
    COMPRESSION,
    NAME = 'HRSystem-Full Compressed Backup',
    DESCRIPTION = 'Compressed full backup of HRSystem database';

-- Full Backup with Checksums (validates backup integrity)
BACKUP DATABASE HRSystem
TO DISK = 'C:\SQLBackups\HRSystem_Full_Checksum.bak'
WITH 
    CHECKSUM,
    CONTINUE_AFTER_ERROR,
    NAME = 'HRSystem-Full Backup with Checksum',
    DESCRIPTION = 'Full backup with checksum validation';

-- Full Backup with Copy-Only (doesn't affect the backup sequence)
BACKUP DATABASE HRSystem
TO DISK = 'C:\SQLBackups\HRSystem_Full_CopyOnly.bak'
WITH 
    COPY_ONLY,
    NAME = 'HRSystem-Full Copy-Only Backup',
    DESCRIPTION = 'Copy-only full backup of HRSystem database';

-- 2. Differential Database Backup
-- Captures only the data that has changed since the last full backup

-- First, make some changes to the database
USE HRSystem;
GO

INSERT INTO HR.Employees (FirstName, LastName, HireDate, Salary)
VALUES ('Sarah', 'Williams', '2022-02-01', 72000);
GO

-- Basic Differential Backup Syntax
BACKUP DATABASE HRSystem
TO DISK = 'C:\SQLBackups\HRSystem_Diff.bak'
WITH 
    DIFFERENTIAL,
    NAME = 'HRSystem-Differential Backup',
    DESCRIPTION = 'Differential backup of HRSystem database';

-- 3. Transaction Log Backup
-- Captures the transaction log records since the last log backup

-- First, ensure the database is using the FULL recovery model
ALTER DATABASE HRSystem SET RECOVERY FULL;
GO

-- Make some transactional changes
USE HRSystem;
GO

BEGIN TRANSACTION;
    UPDATE HR.Employees SET Salary = Salary * 1.05 WHERE EmployeeID = 1;
    INSERT INTO HR.Employees (FirstName, LastName, HireDate, Salary)
    VALUES ('Michael', 'Brown', '2022-03-15', 61000);
COMMIT;
GO

-- Basic Transaction Log Backup Syntax
BACKUP LOG HRSystem
TO DISK = 'C:\SQLBackups\HRSystem_Log.bak'
WITH 
    NAME = 'HRSystem-Transaction Log Backup',
    DESCRIPTION = 'Transaction log backup of HRSystem database';

-- Transaction Log Backup with NORECOVERY (for log shipping)
BACKUP LOG HRSystem
TO DISK = 'C:\SQLBackups\HRSystem_Log_NoRecovery.bak'
WITH 
    NORECOVERY,
    NAME = 'HRSystem-Transaction Log Backup with NORECOVERY',
    DESCRIPTION = 'Transaction log backup with NORECOVERY option';
-- Note: This would leave the database in a restoring state, so it's commented out

-- =============================================
-- PART 3: BACKUP STRATEGIES FOR DIFFERENT SCENARIOS
-- =============================================

-- 1. Simple Recovery Model Strategy
-- Suitable for development environments or databases where some data loss is acceptable

-- Set database to SIMPLE recovery model
ALTER DATABASE HRSystem SET RECOVERY SIMPLE;
GO

-- Simple Recovery Backup Strategy:
-- - Regular full backups (e.g., daily)
-- - Differential backups between full backups (e.g., every 4 hours)
-- Note: Transaction log backups are not possible in SIMPLE recovery model

-- Example: Full backup for simple recovery model
BACKUP DATABASE HRSystem
TO DISK = 'C:\SQLBackups\HRSystem_Simple_Full.bak'
WITH 
    NAME = 'HRSystem-Simple Recovery Full Backup',
    DESCRIPTION = 'Full backup with simple recovery model';

-- 2. Full Recovery Model Strategy
-- Suitable for production environments where minimal data loss is required

-- Set database back to FULL recovery model
ALTER DATABASE HRSystem SET RECOVERY FULL;
GO

-- Full Recovery Backup Strategy:
-- - Regular full backups (e.g., weekly)
-- - Differential backups between full backups (e.g., daily)
-- - Transaction log backups (e.g., every 15-30 minutes)

-- 3. Bulk-Logged Recovery Model Strategy
-- Suitable for periods of bulk operations to minimize transaction log size

-- Set database to BULK_LOGGED recovery model
ALTER DATABASE HRSystem SET RECOVERY BULK_LOGGED;
GO

-- Perform a bulk operation
USE HRSystem;
GO

-- Create a temporary table for bulk insert
CREATE TABLE HR.TempEmployees (
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    HireDate DATE,
    Salary DECIMAL(10,2)
);
GO

-- Simulate bulk insert (in real scenario, this would be a BULK INSERT command)
INSERT INTO HR.TempEmployees (FirstName, LastName, HireDate, Salary)
VALUES 
    ('William', 'Davis', '2021-06-15', 59000),
    ('Emma', 'Wilson', '2021-07-22', 63000),
    ('James', 'Taylor', '2021-08-10', 57000);
GO

-- Backup after bulk operation
BACKUP DATABASE HRSystem
TO DISK = 'C:\SQLBackups\HRSystem_BulkLogged_Full.bak'
WITH 
    NAME = 'HRSystem-Bulk-Logged Recovery Full Backup',
    DESCRIPTION = 'Full backup after bulk operations';

-- Set database back to FULL recovery model
ALTER DATABASE HRSystem SET RECOVERY FULL;
GO

-- =============================================
-- PART 4: ADVANCED BACKUP TECHNIQUES
-- =============================================

-- 1. Backup to Multiple Files
-- Improves backup performance by writing to multiple files simultaneously

BACKUP DATABASE HRSystem
TO 
    DISK = 'C:\SQLBackups\HRSystem_Multi_1.bak',
    DISK = 'C:\SQLBackups\HRSystem_Multi_2.bak',
    DISK = 'C:\SQLBackups\HRSystem_Multi_3.bak'
WITH 
    NAME = 'HRSystem-Multifile Backup',
    DESCRIPTION = 'Backup to multiple files for improved performance';

-- 2. Backup with Encryption
-- Secures backup files with encryption

-- First, create a master key and certificate (if not exists)
-- Note: In production, store certificates securely and back them up separately
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'StrongP@ssw0rd!';
    CREATE CERTIFICATE BackupEncryptionCert WITH SUBJECT = 'Backup Encryption Certificate';
END
GO

-- Encrypted backup
BACKUP DATABASE HRSystem
TO DISK = 'C:\SQLBackups\HRSystem_Encrypted.bak'
WITH 
    ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = BackupEncryptionCert),
    NAME = 'HRSystem-Encrypted Backup',
    DESCRIPTION = 'Encrypted backup of HRSystem database';

-- 3. Partial Backup
-- Backs up only specified filegroups

-- For demonstration, let's add a filegroup and file to our database
ALTER DATABASE HRSystem ADD FILEGROUP ArchiveData;
GO

ALTER DATABASE HRSystem 
ADD FILE (
    NAME = 'HRSystem_Archive',
    FILENAME = 'C:\SQLData\HRSystem_Archive.ndf',
    SIZE = 10MB,
    MAXSIZE = 100MB,
    FILEGROWTH = 5MB
) TO FILEGROUP ArchiveData;
GO

-- Create a table in the new filegroup
USE HRSystem;
GO

CREATE TABLE HR.ArchivedEmployees (
    EmployeeID INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    HireDate DATE,
    TerminationDate DATE,
    FinalSalary DECIMAL(10,2)
) ON ArchiveData;
GO

-- Partial backup (only PRIMARY filegroup)
BACKUP DATABASE HRSystem FILEGROUP = 'PRIMARY'
TO DISK = 'C:\SQLBackups\HRSystem_Partial.bak'
WITH 
    NAME = 'HRSystem-Partial Backup',
    DESCRIPTION = 'Partial backup of HRSystem PRIMARY filegroup';

-- =============================================
-- PART 5: MONITORING AND MANAGING BACKUPS
-- =============================================

-- 1. View Backup History
-- Query to see backup history for a specific database

SELECT 
    bs.database_name,
    bs.backup_start_date,
    bs.backup_finish_date,
    bs.backup_size/1024/1024 AS [Backup Size (MB)],
    CASE bs.type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Transaction Log'
        ELSE 'Other'
    END AS [Backup Type],
    bmf.physical_device_name,
    bs.name AS [Backup Set Name],
    bs.description
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = 'HRSystem'
ORDER BY bs.backup_start_date DESC;

-- 2. Check Backup Integrity
-- Verifies the backup without restoring it

RESTORE VERIFYONLY FROM DISK = 'C:\SQLBackups\HRSystem_Full.bak';

-- 3. Backup Cleanup
-- Delete backup files older than a certain date
-- Note: This would typically be implemented as a SQL Agent job

-- Example T-SQL to identify old backup files (for demonstration only)
DECLARE @CutoffDate DATETIME = DATEADD(DAY, -30, GETDATE());

SELECT 
    bs.database_name,
    bs.backup_start_date,
    bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE 
    bs.database_name = 'HRSystem' AND
    bs.backup_start_date < @CutoffDate
ORDER BY bs.backup_start_date;

-- =============================================
-- PART 6: REAL-WORLD BACKUP SCENARIOS
-- =============================================

-- 1. High-Availability Production Environment
-- For mission-critical databases with minimal downtime and data loss requirements

-- Backup Strategy:
-- - Weekly full backups (during low-traffic periods)
-- - Daily differential