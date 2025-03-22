-- =============================================
-- SQL Server Agent Configuration and Management
-- =============================================

/*
This script demonstrates SQL Server Agent configuration and management for HR automation:
- Enabling and configuring SQL Server Agent
- Managing Agent service settings
- Setting up Agent security and permissions
- Configuring Agent logging and error reporting
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: SQL SERVER AGENT CONFIGURATION
-- =============================================

-- 1. Check SQL Server Agent Status
SELECT 
    servicename,
    process_id,
    startup_type_desc,
    status_desc,
    last_startup_time
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server Agent%';

-- 2. Configure SQL Server Agent Properties
SP_CONFIGURE 'show advanced options', 1;
GO
RECONFIGURE;
GO

-- Set Agent Mail Profile
SP_CONFIGURE 'Database Mail XPs', 1;
GO
RECONFIGURE;
GO

-- =============================================
-- PART 2: AGENT SECURITY CONFIGURATION
-- =============================================

-- 1. Create SQL Server Agent Proxy Account
-- Note: Replace with appropriate credentials in production
/*
EXEC msdb.dbo.sp_add_proxy 
    @proxy_name = 'HRAutomationProxy',
    @credential_name = 'HRAutomationCredential',
    @enabled = 1;
*/

-- 2. Grant Proxy Access to Subsystems
/*
EXEC msdb.dbo.sp_grant_proxy_to_subsystem
    @proxy_name = 'HRAutomationProxy',
    @subsystem_id = 3; -- PowerShell
*/

-- 3. Configure Agent Service Account Permissions
-- Note: This should be done in SQL Server Configuration Manager
-- Ensure the Agent service account has:
-- - Log on as a service rights
-- - Access to required network resources
-- - Appropriate SQL Server permissions

-- =============================================
-- PART 3: AGENT LOGGING AND ERROR REPORTING
-- =============================================

-- 1. View Agent Error Log
EXEC msdb.dbo.sp_help_jobactivity;

-- 2. Configure Agent Error Log Settings
-- Note: This is typically done through SQL Server Management Studio
-- Agent Properties > Error Log tab

-- 3. Set Up Agent Error Log Cycling
EXEC msdb.dbo.sp_cycle_agent_errorlog;

-- =============================================
-- PART 4: AGENT MAINTENANCE
-- =============================================

-- 1. Clean Up Agent History
EXEC msdb.dbo.sp_purge_jobhistory 
    @oldest_date = '2023-01-01';

-- 2. Delete Old Job History
EXEC msdb.dbo.sp_help_job;

-- 3. Monitor Agent Resource Usage
SELECT * FROM msdb.dbo.sysschedules;
SELECT * FROM msdb.dbo.sysjobhistory;

-- =============================================
-- PART 5: BEST PRACTICES
-- =============================================

/*
1. Security Best Practices:
   - Use Windows Authentication when possible
   - Implement least-privilege access
   - Regularly audit proxy accounts

2. Performance Best Practices:
   - Monitor job history retention
   - Schedule jobs during off-peak hours
   - Implement proper error handling

3. Maintenance Best Practices:
   - Regular backup of msdb database
   - Monitor Agent service status
   - Review and clean up job history
*/

-- =============================================
-- PART 6: TROUBLESHOOTING
-- =============================================

-- 1. Check Failed Jobs
SELECT 
    j.name AS job_name,
    h.step_name,
    h.message,
    h.run_date,
    h.run_time
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j 
    ON h.job_id = j.job_id
WHERE h.run_status = 0; -- Failed jobs

-- 2. View Agent Error Log
EXEC xp_readerrorlog 
    1, -- Log file number (1 = current)
    'SQLSERVERAGENT'; -- Filter for Agent messages

-- 3. Check Agent Service Account
SELECT service_account
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server Agent%';