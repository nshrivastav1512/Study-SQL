-- =============================================
-- ALWAYS ON AVAILABILITY GROUPS Comprehensive Guide
-- =============================================

/*
This guide provides a detailed explanation of SQL Server Always On Availability Groups, including:
- What Always On Availability Groups are and how they work
- Setting up and configuring Availability Groups
- Monitoring and managing Availability Groups
- Failover and recovery procedures
- Performance considerations and best practices
- Real-world scenarios and troubleshooting
*/

USE master;
GO

-- =============================================
-- PART 1: ALWAYS ON AVAILABILITY GROUPS FUNDAMENTALS
-- =============================================

-- What are Always On Availability Groups?
-- Always On Availability Groups provide high availability and disaster recovery solutions
-- that maximize availability of a set of user databases while maintaining data protection

-- Key Components:
-- 1. Availability Group: A container for a set of user databases (availability databases)
-- 2. Availability Replicas: SQL Server instances hosting copies of the availability databases
-- 3. Primary Replica: The read-write replica where all changes originate
-- 4. Secondary Replicas: One or more read-only or read-intent replicas that receive changes from the primary
-- 5. Availability Group Listener: A virtual network name that provides client connectivity to the appropriate replica

-- Benefits of Always On Availability Groups:
-- - High Availability: Automatic failover between replicas in the same data center
-- - Disaster Recovery: Manual failover to replicas in remote data centers
-- - Read Scale-Out: Offload read workloads to secondary replicas
-- - Backup Offload: Perform backups on secondary replicas to reduce primary workload
-- - Enhanced Data Protection: Synchronous commits ensure zero data loss

-- Prerequisites:
-- - Windows Server Failover Clustering (WSFC)
-- - SQL Server Enterprise Edition (for multiple secondary replicas)
-- - Shared storage not required (unlike Failover Cluster Instances)
-- - Network connectivity between all replicas

-- =============================================
-- PART 2: PREPARING FOR ALWAYS ON AVAILABILITY GROUPS
-- =============================================

-- 1. Windows Server Failover Clustering (WSFC) Configuration
-- Note: This would be done at the Windows Server level
-- - Install the Failover Clustering feature on all nodes
-- - Run Cluster Validation
-- - Create the Windows Failover Cluster

-- 2. SQL Server Configuration
-- Enable the Always On Availability Groups feature on each SQL Server instance

-- Enable Always On Availability Groups
SP_CONFIGURE 'show advanced options', 1;
RECONFIGURE;
GO

SP_CONFIGURE 'hadr enabled', 1;
RECONFIGURE;
GO

-- Restart SQL Server service after enabling Always On
-- SHUTDOWN WITH NOWAIT;
-- GO

-- 3. Create Sample Database for Availability Group
-- Create a database to be added to the Availability Group

IF DB_ID('HRSystem_AG') IS NULL
BEGIN
    CREATE DATABASE HRSystem_AG;
    ALTER DATABASE HRSystem_AG SET RECOVERY FULL;
    
    -- Create a simple table for demonstration
    EXEC('USE HRSystem_AG; 
         CREATE SCHEMA HR;
         CREATE TABLE HR.Employees (
             EmployeeID INT PRIMARY KEY IDENTITY(1,1),
             FirstName NVARCHAR(50),
             LastName NVARCHAR(50),
             HireDate DATE,
             Salary DECIMAL(10,2),
             DepartmentID INT
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
             Location NVARCHAR(50)
         );
         
         -- Insert sample data
         INSERT INTO HR.Departments (DepartmentName, Location)
         VALUES 
            (''HR'', ''New York''),
            (''IT'', ''San Francisco''),
            (''Finance'', ''Chicago'');
    ');
    
    PRINT 'HRSystem_AG database created for Always On Availability Groups demonstration.';
END
ELSE
BEGIN
    PRINT 'Using existing HRSystem_AG database.';
    ALTER DATABASE HRSystem_AG SET RECOVERY FULL;
END
GO

-- Take a full backup of the database
BACKUP DATABASE HRSystem_AG
TO DISK = 'C:\SQLBackups\HRSystem_AG_Full.bak'
WITH 
    NAME = 'HRSystem_AG-Full Backup for AG',
    DESCRIPTION = 'Full backup of HRSystem_AG database';
GO

-- =============================================
-- PART 3: CREATING AN AVAILABILITY GROUP
-- =============================================

-- 1. Using SQL Server Management Studio (SSMS)
-- - Right-click Always On High Availability > New Availability Group Wizard
-- - Specify AG name, databases, replicas, listener, and synchronization preferences

-- 2. Using T-SQL Scripts
-- The following script demonstrates how to create an Availability Group using T-SQL

-- Create the Availability Group
-- Note: This would be run on the primary replica
CREATE AVAILABILITY GROUP [AG_HRSystem]
WITH (
    AUTOMATED_BACKUP_PREFERENCE = SECONDARY,
    DB_FAILOVER = ON,
    DTC_SUPPORT = NONE,
    CLUSTER_TYPE = WSFC
)
FOR DATABASE HRSystem_AG
REPLICA ON 
    'PrimaryServer' WITH (
        ENDPOINT_URL = 'TCP://PrimaryServer:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = AUTOMATIC,
        BACKUP_PRIORITY = 50,
        SECONDARY_ROLE(ALLOW_CONNECTIONS = READ_ONLY)
    ),
    'SecondaryServer1' WITH (
        ENDPOINT_URL = 'TCP://SecondaryServer1:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        FAILOVER_MODE = AUTOMATIC,
        BACKUP_PRIORITY = 75,
        SECONDARY_ROLE(ALLOW_CONNECTIONS = READ_ONLY)
    ),
    'SecondaryServer2' WITH (
        ENDPOINT_URL = 'TCP://SecondaryServer2:5022',
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
        FAILOVER_MODE = MANUAL,
        BACKUP_PRIORITY = 100,
        SECONDARY_ROLE(ALLOW_CONNECTIONS = READ_ONLY)
    );
GO

-- Create a database mirroring endpoint on each instance
-- Note: This would be run on each SQL Server instance
CREATE ENDPOINT [Hadr_endpoint]
STATE = STARTED
AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ALL)
FOR DATABASE_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);
GO

-- Grant connect permissions on the endpoint
-- Note: This would be run on each SQL Server instance
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [NT AUTHORITY\SYSTEM];
GO

-- Join secondary replicas to the Availability Group
-- Note: This would be run on each secondary replica
-- ALTER AVAILABILITY GROUP [AG_HRSystem] JOIN;
-- GO

-- Prepare the database on secondary replicas
-- Note: This would be run on each secondary replica after restoring the database with NORECOVERY
-- RESTORE DATABASE HRSystem_AG FROM DISK = '\\PrimaryServer\SQLBackups\HRSystem_AG_Full.bak'
-- WITH NORECOVERY, MOVE 'HRSystem_AG' TO 'C:\SQLData\HRSystem_AG.mdf',
-- MOVE 'HRSystem_AG_log' TO 'C:\SQLData\HRSystem_AG_log.ldf';
-- GO

-- Join the database to the Availability Group
-- Note: This would be run on each secondary replica
-- ALTER DATABASE HRSystem_AG SET HADR AVAILABILITY GROUP = [AG_HRSystem];
-- GO

-- Create an Availability Group Listener
-- Note: This would be run on the primary replica
ALTER AVAILABILITY GROUP [AG_HRSystem]
ADD LISTENER 'AG_HRSystem_Listener' (
    WITH IP
    (
        ('192.168.1.100', '255.255.255.0')
    ),
    PORT = 1433
);
GO

-- =============================================
-- PART 4: MONITORING AVAILABILITY GROUPS
-- =============================================

-- 1. Using SQL Server Management Studio (SSMS)
-- - Expand Always On High Availability > Availability Groups
-- - View dashboard and health status

-- 2. Using T-SQL Queries
-- The following queries can be used to monitor Availability Groups

-- View Availability Group state
SELECT 
    ag.name AS [AG Name],
    ag.is_distributed,
    ag.group_id,
    ag.cluster_type_desc,
    ag.automated_backup_preference_desc
FROM sys.availability_groups ag;

-- View Availability Replica state
SELECT 
    ar.replica_server_name,
    ar.endpoint_url,
    ar.availability_mode_desc,
    ar.failover_mode_desc,
    ar.primary_role_allow_connections_desc,
    ar.secondary_role_allow_connections_desc,
    ar.backup_priority
FROM sys.availability_replicas ar
JOIN sys.availability_groups ag ON ar.group_id = ag.group_id
WHERE ag.name = 'AG_HRSystem';

-- View Availability Database state
SELECT 
    ag.name AS [AG Name],
    ar.replica_server_name,
    db_name(adc.database_id) AS [Database Name],
    drs.database_state_desc,
    drs.synchronization_state_desc,
    drs.synchronization_health_desc,
    drs.last_hardened_lsn,
    drs.last_redone_lsn,
    drs.last_commit_lsn
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.availability_databases_cluster adc ON drs.group_database_id = adc.group_database_id
JOIN sys.availability_groups ag ON drs.group_id = ag.group_id
JOIN sys.availability_replicas ar ON drs.replica_id = ar.replica_id
ORDER BY ag.name, ar.replica_server_name, [Database Name];

-- View Availability Group Listeners
SELECT 
    ag.name AS [AG Name],
    agl.dns_name,
    agl.port,
    agl.is_conformant,
    ip.ip_address,
    ip.ip_subnet_mask,
    ip.state_desc
FROM sys.availability_group_listeners agl
JOIN sys.availability_groups ag ON agl.group_id = ag.group_id
JOIN sys.availability_group_listener_ip_addresses ip ON agl.listener_id = ip.listener_id;

-- =============================================
-- PART 5: FAILOVER PROCEDURES
-- =============================================

-- 1. Planned Manual Failover
-- Used during scheduled maintenance

-- Perform a planned manual failover
-- Note: This would be run on the current primary replica
ALTER AVAILABILITY GROUP [AG_HRSystem] FAILOVER;
GO

-- 2. Forced Manual Failover (with potential data loss)
-- Used in disaster recovery scenarios when the primary is unavailable

-- Perform a forced failover with potential data loss
-- Note: This would be run on a secondary replica
-- ALTER AVAILABILITY GROUP [AG_HRSystem] FORCE_FAILOVER_ALLOW_DATA_LOSS;
-- GO

-- 3. Automatic Failover
-- Occurs automatically when a synchronous secondary replica detects that the primary is unavailable
-- No T-SQL command needed as this happens automatically based on WSFC quorum and health detection

-- =============================================
-- PART 6: ADVANCED AVAILABILITY GROUP CONFIGURATIONS
-- =============================================

-- 1. Read-Only Routing
-- Directs read-intent connections to a specific secondary replica

-- Configure read-only routing
-- Note: This would be run on the primary replica
ALTER AVAILABILITY GROUP [AG_HRSystem]
MODIFY REPLICA ON 'PrimaryServer' WITH 
    (PRIMARY_ROLE (READ_ONLY_ROUTING_LIST=('SecondaryServer1','SecondaryServer2')));

ALTER AVAILABILITY GROUP [AG_HRSystem]
MODIFY REPLICA ON 'SecondaryServer1' WITH 
    (PRIMARY_ROLE (READ_ONLY_ROUTING_LIST=('SecondaryServer2','PrimaryServer')));

ALTER AVAILABILITY GROUP [AG_HRSystem]
MODIFY REPLICA ON 'SecondaryServer2' WITH 
    (PRIMARY_ROLE (READ_ONLY_ROUTING_LIST=('SecondaryServer1','PrimaryServer')));
GO

-- 2. Distributed Availability Groups
-- Connect two separate Availability Groups, even across different WSFC clusters

-- Create a distributed Availability Group
-- Note: This would be run on the primary replica of the first AG
CREATE AVAILABILITY GROUP [AG_HRSystem_Distributed]
WITH 
    (DISTRIBUTED)
FOR DATABASE HRSystem_AG;
GO

-- Add the first Availability Group as a replica
ALTER AVAILABILITY GROUP [AG_HRSystem_Distributed]
    ADD DATABASE HRSystem_AG;
GO

ALTER AVAILABILITY GROUP [AG_HRSystem_Distributed] 
JOIN
AVAILABILITY GROUP [AG_HRSystem] 
ON
(
    LISTENER_URL = 'TCP://AG_HRSystem_Listener:5022',
    AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
    FAILOVER_MODE = MANUAL,
    SEEDING_MODE = AUTOMATIC
);
GO

-- Add the second Availability Group as a replica
-- Note: This would be run on the primary replica of the second AG
-- ALTER AVAILABILITY GROUP [AG_HRSystem_DR] 
-- JOIN AVAILABILITY GROUP [AG_HRSystem_Distributed]
-- ON
--