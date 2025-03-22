-- =============================================
-- LOG SHIPPING Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Log Shipping, including:
- What log shipping is and how it works
- Setting up log shipping between servers
- Monitoring log shipping status
- Failover and recovery procedures
- Performance considerations and best practices
- Real-world scenarios and troubleshooting
*/

USE master;
GO

-- =============================================
-- PART 1: LOG SHIPPING FUNDAMENTALS
-- =============================================

-- What is Log Shipping?
-- Log shipping is a high-availability solution that maintains one or more warm standby databases
-- for a production database by automatically copying and restoring transaction log backups

-- Log Shipping Components:
-- 1. Primary server: The production server containing the primary database
-- 2. Secondary server(s): The server(s) containing the warm standby database(s)
-- 3. Monitor server (optional): A server that tracks and stores log shipping history and status

-- Log Shipping Process:
-- 1. Backup: Transaction log backups are taken on the primary database
-- 2. Copy: Backup files are copied to the secondary server(s)
-- 3. Restore: Backup files are restored on the secondary database(s)

-- Log Shipping vs. Other HA/DR Solutions:
-- - Simpler to set up than Always On Availability Groups
-- - Less expensive than database mirroring (no Enterprise Edition required)
-- - More flexible than replication for disaster recovery
-- - Secondary databases can be used for read-only operations (with STANDBY mode)

-- =============================================
-- PART 2: PREREQUISITES FOR LOG SHIPPING
-- =============================================

-- 1. Primary Database Requirements
-- - Must be using FULL or BULK_LOGGED recovery model
-- - Initial full backup must be available

-- Create a sample primary database
IF DB_ID('HRSystem_Primary') IS NULL
BEGIN
    CREATE DATABASE HRSystem_Primary;
    ALTER DATABASE HRSystem_Primary SET RECOVERY FULL;
    
    -- Create a simple table for demonstration
    EXEC('USE HRSystem_Primary; 
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
    
    PRINT 'HRSystem_Primary database created for log shipping demonstration.';
END
ELSE
BEGIN
    PRINT 'Using existing HRSystem_Primary database.';
    ALTER DATABASE HRSystem_Primary SET RECOVERY FULL;
END
GO

-- 2. Secondary Server Requirements
-- - SQL Server instance must be accessible from the primary server
-- - Sufficient disk space for database and log files
-- - Appropriate permissions for service accounts

-- 3. Shared Folder for Backup Files
-- - Network share accessible from both primary and secondary servers
-- - Appropriate permissions for SQL Server service accounts

-- Create a full backup of the primary database
BACKUP DATABASE HRSystem_Primary
TO DISK = 'C:\SQLBackups\HRSystem_Primary_Full.bak'
WITH 
    NAME = 'HRSystem_Primary-Full Backup for Log Shipping',
    DESCRIPTION = 'Full backup of HRSystem_Primary database';

-- =============================================
-- PART 3: SETTING UP LOG SHIPPING
-- =============================================

-- 1. Using SQL Server Management Studio (SSMS)
-- - Right-click the primary database > Properties > Transaction Log Shipping
-- - Enable log shipping and configure settings
-- - Add secondary servers and configure backup, copy, and restore jobs

-- 2. Using T-SQL Scripts
-- The following script demonstrates how to set up log shipping using T-SQL

-- Step 1: Configure the primary database
USE master;
GO

-- Create a backup directory if it doesn't exist
-- EXEC xp_create_subdir 'C:\SQLBackups\LogShipping';

-- Enable log shipping on the primary database
EXEC sp_add_log_shipping_primary_database
    @database = 'HRSystem_Primary',
    @backup_directory = 'C:\SQLBackups\LogShipping',
    @backup_share = '\\PrimaryServer\SQLBackups\LogShipping',
    @backup_job_name = 'LSBackup_HRSystem_Primary',
    @backup_retention_period = 4320, -- 3 days in minutes
    @monitor_server = NULL, -- No separate monitor server
    @monitor_server_security_mode = 1, -- Windows Authentication
    @backup_threshold = 60, -- Alert if no backup for 60 minutes
    @threshold_alert = 14420, -- Alert job number
    @threshold_alert_enabled = 1, -- Enable alerts
    @history_retention_period = 5760; -- 4 days in minutes
GO

-- Step 2: Configure the secondary database
-- Note: This would be run on the secondary server

-- First, restore the full backup with NORECOVERY
-- RESTORE DATABASE HRSystem_Secondary
-- FROM DISK = '\\PrimaryServer\SQLBackups\HRSystem_Primary_Full.bak'
-- WITH 
--     MOVE 'HRSystem_Primary' TO 'C:\SQLData\HRSystem_Secondary.mdf',
--     MOVE 'HRSystem_Primary_log' TO 'C:\SQLData\HRSystem_Secondary_log.ldf',
--     NORECOVERY,
--     STATS = 10;

-- Add the secondary database to log shipping
-- EXEC sp_add_log_shipping_secondary_primary
--     @primary_server = 'PrimaryServer',
--     @primary_database = 'HRSystem_Primary',
--     @backup_source_directory = '\\PrimaryServer\SQLBackups\LogShipping',
--     @backup_destination_directory = 'C:\SQLBackups\LogShipping',
--     @copy_job_name = 'LSCopy_PrimaryServer_HRSystem_Primary',
--     @restore_job_name = 'LSRestore_PrimaryServer_HRSystem_Primary',
--     @file_retention_period = 4320, -- 3 days in minutes
--     @monitor_server = NULL, -- No separate monitor server
--     @monitor_server_security_mode = 1, -- Windows Authentication
--     @copy_job_schedule_id = 0, -- Default schedule
--     @copy_job_schedule_name = '',
--     @copy_job_schedule_frequency_type = 4, -- Daily
--     @copy_job_schedule_frequency_interval = 1, -- Every day
--     @copy_job_schedule_frequency_subday_type = 4, -- Minutes
--     @copy_job_schedule_frequency_subday_interval = 15, -- Every 15 minutes
--     @copy_job_schedule_active_start_time = 0, -- 12:00 AM
--     @restore_job_schedule_id = 0, -- Default schedule
--     @restore_job_schedule_name = '',
--     @restore_job_schedule_frequency_type = 4, -- Daily
--     @restore_job_schedule_frequency_interval = 1, -- Every day
--     @restore_job_schedule_frequency_subday_type = 4, -- Minutes
--     @restore_job_schedule_frequency_subday_interval = 15, -- Every 15 minutes
--     @restore_job_schedule_active_start_time = 0; -- 12:00 AM

-- Configure the secondary database
-- EXEC sp_add_log_shipping_secondary_database
--     @secondary_database = 'HRSystem_Secondary',
--     @primary_server = 'PrimaryServer',
--     @primary_database = 'HRSystem_Primary',
--     @restore_delay = 0, -- No delay
--     @restore_mode = 0, -- NORECOVERY mode (0 = NORECOVERY, 1 = STANDBY)
--     @disconnect_users = 0, -- Don't disconnect users during restore
--     @restore_threshold = 45, -- Alert if no restore for 45 minutes
--     @threshold_alert = 14421, -- Alert job number
--     @threshold_alert_enabled = 1, -- Enable alerts
--     @history_retention_period = 5760; -- 4 days in minutes

-- =============================================
-- PART 4: MONITORING LOG SHIPPING
-- =============================================

-- 1. Using SQL Server Management Studio (SSMS)
-- - Expand Management > Log Shipping Monitor
-- - View status of primary and secondary databases

-- 2. Using T-SQL Queries
-- The following queries can be used to monitor log shipping status

-- View log shipping status for primary databases
SELECT 
    pd.primary_database,
    pd.backup_threshold,
    pd.backup_retention_period,
    pd.last_backup_date,
    pd.last_backup_file,
    pd.backup_job_id
FROM msdb.dbo.log_shipping_primary_databases pd;

-- View log shipping status for secondary databases
-- Note: This would be run on the secondary server
-- SELECT 
--     sd.secondary_database,
--     sd.restore_threshold,
--     sd.restore_delay,
--     sd.restore_mode,
--     sd.last_restored_file,
--     sd.last_restored_date,
--     sd.restore_job_id
-- FROM msdb.dbo.log_shipping_secondary_databases sd;

-- View log shipping error records
SELECT 
    agent_id,
    log_time,
    log_shipping_operation,
    CASE log_shipping_operation
        WHEN 1 THEN 'Backup'
        WHEN 2 THEN 'Copy'
        WHEN 3 THEN 'Restore'
        ELSE 'Unknown'
    END AS operation_name,
    succeeded,
    message
FROM msdb.dbo.log_shipping_monitor_error_detail
ORDER BY log_time DESC;

-- =============================================
-- PART 5: FAILOVER AND RECOVERY PROCEDURES
-- =============================================

-- 1. Planned Failover
-- A planned failover is performed during scheduled maintenance

-- Step 1: On the primary server, backup the final transaction log with NORECOVERY
-- This puts the primary database in a restoring state
BACKUP LOG HRSystem_Primary
TO DISK = 'C:\SQLBackups\LogShipping\HRSystem_Primary_FinalLog.trn'
WITH 
    NORECOVERY,
    NAME = 'HRSystem_Primary-Final Log Backup for Failover',
    DESCRIPTION = 'Final log backup before failover';

-- Step 2: On the secondary server, apply the final log backup and recover the database
-- RESTORE LOG HRSystem_Secondary
-- FROM DISK = '\\PrimaryServer\SQLBackups\LogShipping\HRSystem_Primary_FinalLog.trn'
-- WITH RECOVERY;

-- Step 3: The secondary database is now the new primary
-- Clients should be redirected to the new primary server

-- 2. Unplanned Failover
-- An unplanned failover occurs when the primary server fails unexpectedly

-- Step 1: On the secondary server, recover the database
-- This makes the database available for read/write operations
-- RESTORE DATABASE HRSystem_Secondary WITH RECOVERY;

-- Step 2: The secondary database is now the new primary
-- Clients should be redirected to the new primary server

-- 3. Failback Procedure
-- After the original primary server is back online, you can fail back to it

-- Step 1: Set up log shipping in the reverse direction
-- The new primary becomes the log shipping primary
-- The original primary becomes the log shipping secondary

-- Step 2: Once synchronized, perform a planned failover back to the original primary

-- =============================================
-- PART 6: ADVANCED LOG SHIPPING CONFIGURATIONS
-- =============================================

-- 1. Multiple Secondary Servers
-- Log shipping supports multiple secondary servers for additional redundancy

-- 2. Delayed Restore
-- Configuring a delay in the restore process can protect against logical errors

-- Example: Configure a 3-hour delay for the restore job
-- EXEC sp_update_log_shipping_secondary_database
--     @secondary_database = 'HRSystem_Secondary',
--     @restore_delay = 180; -- 3 hours in minutes

-- 3. Read-Only Access to Secondary Database
-- Configure the secondary database in STANDBY mode for read-only access

-- Example: Update the secondary database to use STANDBY mode
-- EXEC sp_update_log_shipping_secondary_database
--     @secondary_database = 'HRSystem_Secondary',
--     @restore_mode = 1, -- STANDBY mode (0 = NORECOVERY, 1 = STANDBY)
--     @disconnect_users = 1; -- Disconnect users during restore

-- 4. Custom Backup, Copy, and Restore Schedules
-- Customize the schedules for the log shipping jobs based on business requirements

-- Example: Update the backup job schedule to run every 30 minutes
-- EXEC msdb.dbo.sp_update_schedule
--     @schedule_id = <schedule_id>, -- Get from msdb.dbo.sysschedules
--     @freq_subday_type = 4, -- Minutes
--     @freq_subday_interval = 30; -- Every 30 minutes

-- =============================================
-- PART 7: TROUBLESHOOTING LOG SHIPPING
-- =============================================

-- 1. Common Issues and Solutions

-- Issue: Backup job fails
-- Solution: Check disk space, permissions, and backup directory

-- Issue: Copy job fails
-- Solution: Check network connectivity, share permissions, and service accounts

-- Issue: Restore job fails
-- Solution: Check disk space, database state, and restore permissions

-- 2. Monitoring Queries for Troubleshooting

-- Check for failed log shipping jobs
SELECT 
    j.name AS job_name,
    h.run_date,
    h.run_time,
    h.run_status,
    h.run_duration,
    h.message
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id