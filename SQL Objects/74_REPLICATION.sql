-- =============================================
-- REPLICATION Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Replication, including:
- Types of replication (Snapshot, Transactional, Merge)
- Components of replication architecture
- Setting up and configuring replication
- Monitoring and troubleshooting replication
- Performance considerations and best practices
- Real-world scenarios and use cases
*/

USE master;
GO

-- =============================================
-- PART 1: REPLICATION FUNDAMENTALS
-- =============================================

-- What is Replication?
-- Replication is a set of technologies for copying and distributing data and database objects
-- from one database to another, and then synchronizing them to maintain consistency

-- Replication Components:
-- 1. Publisher: The source server that makes data available for replication
-- 2. Distributor: The server that stores metadata and history for replication
-- 3. Subscriber: The destination server that receives replicated data
-- 4. Publication: A collection of articles (tables, stored procedures, etc.) to be replicated
-- 5. Article: A database object to be replicated (e.g., a table or stored procedure)
-- 6. Subscription: The destination database that receives the replicated objects

-- Types of Replication:
-- 1. Snapshot Replication: Distributes data exactly as it appears at a specific moment in time
-- 2. Transactional Replication: Initial snapshot followed by continuous replication of changes
-- 3. Merge Replication: Allows changes at both publisher and subscriber with conflict resolution
-- 4. Peer-to-Peer Replication: Transactional replication with multiple publishers/subscribers

-- =============================================
-- PART 2: PREPARING FOR REPLICATION
-- =============================================

-- 1. Create Sample Databases for Replication

-- Publisher database
IF DB_ID('HRSystem_Publisher') IS NULL
BEGIN
    CREATE DATABASE HRSystem_Publisher;
    
    -- Create a simple table for demonstration
    EXEC('USE HRSystem_Publisher; 
         CREATE SCHEMA HR;
         CREATE TABLE HR.Employees (
             EmployeeID INT PRIMARY KEY IDENTITY(1,1),
             FirstName NVARCHAR(50),
             LastName NVARCHAR(50),
             HireDate DATE,
             Salary DECIMAL(10,2),
             DepartmentID INT,
             LastModified DATETIME DEFAULT GETDATE()
         );
         
         -- Insert sample data
         INSERT INTO HR.Employees (FirstName, LastName, HireDate, Salary, DepartmentID)
         VALUES 
            (''John'', ''Smith'', ''2020-01-15'', 55000, 1),
            (''Jane'', ''Doe'', ''2019-03-20'', 65000, 2),
            (''Robert'', ''Johnson'', ''2021-05-10'', 48000, 1);
            
         CREATE TABLE HR.Departments (
             DepartmentID INT PRIMARY KEY IDENTITY(1,1),
             DepartmentName NVARCHAR(50),
             Location NVARCHAR(50),
             LastModified DATETIME DEFAULT GETDATE()
         );
         
         -- Insert sample data
         INSERT INTO HR.Departments (DepartmentName, Location)
         VALUES 
            (''HR'', ''New York''),
            (''IT'', ''San Francisco''),
            (''Finance'', ''Chicago'');
    ');
    
    PRINT 'HRSystem_Publisher database created for replication demonstration.';
END
ELSE
BEGIN
    PRINT 'Using existing HRSystem_Publisher database.';
END
GO

-- Subscriber database
IF DB_ID('HRSystem_Subscriber') IS NULL
BEGIN
    CREATE DATABASE HRSystem_Subscriber;
    PRINT 'HRSystem_Subscriber database created for replication demonstration.';
END
ELSE
BEGIN
    PRINT 'Using existing HRSystem_Subscriber database.';
END
GO

-- 2. Configure Distribution
-- Note: In a production environment, this would be done through SQL Server Management Studio
-- or with more comprehensive T-SQL scripts

-- The following is a simplified example of configuring a distributor
-- EXEC sp_adddistributor @distributor = @@SERVERNAME, @password = 'P@ssw0rd';
-- EXEC sp_adddistributiondb @database = 'distribution', @data_folder = 'C:\SQLData', @log_folder = 'C:\SQLData';

-- =============================================
-- PART 3: SNAPSHOT REPLICATION
-- =============================================

-- 1. Snapshot Replication Overview
-- - Periodically takes a complete copy of the data to be replicated
-- - Suitable for data that changes infrequently
-- - Higher resource usage during snapshot generation
-- - No continuous tracking of changes between snapshots

-- 2. Setting Up Snapshot Replication
-- Note: In a production environment, this would be done through SQL Server Management Studio
-- or with more comprehensive T-SQL scripts

-- The following is a simplified example of setting up snapshot replication

-- Create a publication
-- EXEC sp_addpublication 
--     @publication = 'HRSystem_SnapshotPub',
--     @description = 'Snapshot publication of HR System data',
--     @retention = 0,
--     @allow_push = N'true',
--     @repl_freq = N'snapshot',
--     @status = N'active',
--     @snapshot_in_defaultfolder = N'true';

-- Add articles to the publication
-- EXEC sp_addarticle 
--     @publication = 'HRSystem_SnapshotPub',
--     @article = 'Employees',
--     @source_owner = 'HR',
--     @source_object = 'Employees',
--     @type = 'logbased',
--     @description = 'Snapshot replication of Employees table',
--     @creation_script = NULL,
--     @pre_creation_cmd = 'drop',
--     @schema_option = 0x000000000803509F;

-- EXEC sp_addarticle 
--     @publication = 'HRSystem_SnapshotPub',
--     @article = 'Departments',
--     @source_owner = 'HR',
--     @source_object = 'Departments',
--     @type = 'logbased',
--     @description = 'Snapshot replication of Departments table',
--     @creation_script = NULL,
--     @pre_creation_cmd = 'drop',
--     @schema_option = 0x000000000803509F;

-- Create a snapshot agent job
-- EXEC sp_addpublication_snapshot 
--     @publication = 'HRSystem_SnapshotPub',
--     @frequency_type = 4, -- Daily
--     @frequency_interval = 1, -- Every day
--     @frequency_subday_type = 1, -- Once per day
--     @frequency_subday_interval = 0,
--     @active_start_time_of_day = 010000; -- 1:00 AM

-- Add a subscription
-- EXEC sp_addsubscription 
--     @publication = 'HRSystem_SnapshotPub',
--     @subscriber = @@SERVERNAME,
--     @destination_db = 'HRSystem_Subscriber',
--     @subscription_type = 'Push',
--     @sync_type = 'automatic',
--     @article = 'all',
--     @update_mode = 'read only';

-- 3. Monitoring Snapshot Replication

-- View snapshot agent status
SELECT 
    ja.job_id,
    j.name AS job_name,
    ja.start_execution_date,
    ja.last_executed_step_id,
    ja.last_executed_step_date,
    ja.stop_execution_date,
    ja.next_scheduled_run_date
FROM msdb.dbo.sysjobactivity ja
JOIN msdb.dbo.sysjobs j ON ja.job_id = j.job_id
WHERE j.name LIKE '%snapshot%'
AND ja.start_execution_date IS NOT NULL
AND ja.stop_execution_date IS NULL;

-- View replication agent history
SELECT TOP 10
    h.agent_id,
    h.runstatus,
    h.start_time,
    h.duration,
    h.comments,
    h.delivered_transactions,
    h.delivered_commands,
    h.error_id,
    h.error_text
FROM msdb.dbo.MSreplication_monitordata h
WHERE h.agent_type = 1 -- Snapshot Agent
ORDER BY h.start_time DESC;

-- =============================================
-- PART 4: TRANSACTIONAL REPLICATION
-- =============================================

-- 1. Transactional Replication Overview
-- - Initial snapshot followed by continuous replication of changes
-- - Suitable for high-volume, frequently changing data
-- - Low latency between changes at publisher and subscriber
-- - Subscribers are typically read-only

-- 2. Setting Up Transactional Replication
-- Note: In a production environment, this would be done through SQL Server Management Studio
-- or with more comprehensive T-SQL scripts

-- The following is a simplified example of setting up transactional replication

-- Create a publication
-- EXEC sp_addpublication 
--     @publication = 'HRSystem_TransPub',
--     @description = 'Transactional publication of HR System data',
--     @retention = 14, -- Retain transactions for 14 days
--     @allow_push = N'true',
--     @repl_freq = N'continuous', -- Continuous replication
--     @status = N'active',
--     @sync_method = N'concurrent',
--     @allow_sync_tran = N'false',
--     @autogen_sync_procs = N'false';

-- Add articles to the publication
-- EXEC sp_addarticle 
--     @publication = 'HRSystem_TransPub',
--     @article = 'Employees',
--     @source_owner = 'HR',
--     @source_object = 'Employees',
--     @type = 'logbased',
--     @description = 'Transactional replication of Employees table',
--     @creation_script = NULL,
--     @pre_creation_cmd = 'drop',
--     @schema_option = 0x000000000803509F;

-- EXEC sp_addarticle 
--     @publication = 'HRSystem_TransPub',
--     @article = 'Departments',
--     @source_owner = 'HR',
--     @source_object = 'Departments',
--     @type = 'logbased',
--     @description = 'Transactional replication of Departments table',
--     @creation_script = NULL,
--     @pre_creation_cmd = 'drop',
--     @schema_option = 0x000000000803509F;

-- Create a snapshot agent job for initial synchronization
-- EXEC sp_addpublication_snapshot 
--     @publication = 'HRSystem_TransPub',
--     @frequency_type = 1; -- Once only (for initial snapshot)

-- Add a subscription
-- EXEC sp_addsubscription 
--     @publication = 'HRSystem_TransPub',
--     @subscriber = @@SERVERNAME,
--     @destination_db = 'HRSystem_Subscriber',
--     @subscription_type = 'Push',
--     @sync_type = 'automatic',
--     @article = 'all',
--     @update_mode = 'read only';

-- Add a distribution agent job
-- EXEC sp_addpushsubscription_agent 
--     @publication = 'HRSystem_TransPub',
--     @subscriber = @@SERVERNAME,
--     @subscriber_db = 'HRSystem_Subscriber',
--     @frequency_type = 4, -- Daily
--     @frequency_interval = 1, -- Every day
--     @frequency_relative_interval = 1,
--     @frequency_recurrence_factor = 0,
--     @frequency_subday_type = 2, -- Seconds
--     @frequency_subday_interval = 10, -- Every 10 seconds
--     @active_start_time_of_day = 0;

-- 3. Monitoring Transactional Replication

-- View log reader agent status
SELECT 
    ja.job_id,
    j.name AS job_name,
    ja.start_execution_date,
    ja.last_executed_step_id,
    ja.last_executed_step_date,
    ja.stop_execution_date,
    ja.next_scheduled_run_date
FROM msdb.dbo.sysjobactivity ja
JOIN msdb.dbo.sysjobs j ON ja.job_id = j.job_id
WHERE j.name LIKE '%logreader%'
AND ja.start_execution_date IS NOT NULL
AND ja.stop_execution_date IS NULL;

-- View distribution agent status
SELECT 
    ja.job_id,
    j.name AS job_name,
    ja.start_execution_date,
    ja.last_executed_step_id,
    ja.last_executed_step_date,
    ja.stop_execution_date,
    ja.next_scheduled_run_date
FROM msdb.dbo.sysjobactivity ja
JOIN msdb.dbo.sysjobs j ON ja.job_id = j.job_id
WHERE j.name LIKE '%distribution%'
AND ja.start_execution_date IS NOT NULL
AND ja.stop_execution_date IS NULL;

-- View replication agent history
SELECT TOP 10
    h.agent_id,
    h.runstatus,
    h.start_time,
    h.duration,
    h.comments,
    h.delivered_transactions,
    h.delivered_commands,
    h.error_id,
    h.error_text
FROM msdb.dbo.MSreplication_monitordata h
WHERE h.agent_type IN (2, 3) -- Log Reader and Distribution Agents
ORDER BY h.start_time DESC;

-- =============================================
-- PART 5: MERGE REPLICATION
-- =============================================

-- 1. Merge Replication Overview
-- - Allows changes at both publisher and subscriber
-- - Includes conflict detection and resolution
-- - Suitable for disconnected or occasionally connected systems
-- - Higher overhead than transactional replication