-- =============================================
-- SQL Server Alerts Configuration and Management
-- =============================================

/*
This script demonstrates SQL Server Alerts configuration for HR system monitoring:
- Creating and managing alerts for critical HR events
- Setting up error condition monitoring
- Configuring performance monitoring alerts
- Managing alert responses and notifications
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: CREATING HR SYSTEM ALERTS
-- =============================================

-- 1. Create Alert for Failed HR Jobs
EXEC msdb.dbo.sp_add_alert
    @name = 'HR_Job_Failure_Alert',
    @message_id = 0,
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 60,
    @include_event_description_in = 1,
    @category_name = 'HR Automation',
    @job_id = NULL;

-- Add Response to Alert
EXEC msdb.dbo.sp_add_notification
    @alert_name = 'HR_Job_Failure_Alert',
    @operator_name = 'HR_DBA_Team',
    @notification_method = 1; -- Email

-- 2. Create Alert for Database Errors
EXEC msdb.dbo.sp_add_alert
    @name = 'HR_Database_Error_Alert',
    @severity = 16, -- Errors that can be corrected by user
    @enabled = 1,
    @delay_between_responses = 60,
    @include_event_description_in = 1,
    @database_name = 'HRSystem';

-- =============================================
-- PART 2: PERFORMANCE MONITORING ALERTS
-- =============================================

-- 1. Create Alert for High CPU Usage
EXEC msdb.dbo.sp_add_alert
    @name = 'HR_High_CPU_Alert',
    @enabled = 1,
    @message_id = 0,
    @severity = 0,
    @performance_condition = 'CPU Usage|Process(sqlservr)|%Processor Time|>|90',
    @delay_between_responses = 300;

-- 2. Create Alert for Low Disk Space
EXEC msdb.dbo.sp_add_alert
    @name = 'HR_Low_Disk_Space_Alert',
    @enabled = 1,
    @message_id = 0,
    @severity = 0,
    @performance_condition = 'LogicalDisk|C:|Free Megabytes|<|1000',
    @delay_between_responses = 3600;

-- =============================================
-- PART 3: SECURITY MONITORING ALERTS
-- =============================================

-- 1. Create Alert for Failed Logins
EXEC msdb.dbo.sp_add_alert
    @name = 'HR_Failed_Login_Alert',
    @message_id = 18456, -- Login failed message
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 300,
    @include_event_description_in = 1;

-- 2. Create Alert for Permission Changes
EXEC msdb.dbo.sp_add_alert
    @name = 'HR_Permission_Change_Alert',
    @message_id = 33205, -- Permission granted message
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 60,
    @include_event_description_in = 1;

-- =============================================
-- PART 4: ALERT MANAGEMENT
-- =============================================

-- 1. View Configured Alerts
SELECT 
    name,
    message_id,
    severity,
    enabled,
    delay_between_responses,
    last_occurrence_date,
    last_occurrence_time
FROM msdb.dbo.sysalerts;

-- 2. Check Alert History
SELECT 
    a.name AS alert_name,
    h.occurrence_date,
    h.occurrence_time,
    h.alert_error_code,
    h.severity,
    h.message_text
FROM msdb.dbo.sysalerts a
JOIN msdb.dbo.sysalerthistory h 
    ON a.id = h.alert_id
ORDER BY 
    h.occurrence_date DESC,
    h.occurrence_time DESC;

-- =============================================
-- PART 5: BEST PRACTICES
-- =============================================

/*
1. Alert Configuration Best Practices:
   - Set appropriate severity levels
   - Configure meaningful delay between responses
   - Include detailed error descriptions
   - Test alerts in non-production environment

2. Performance Alert Best Practices:
   - Set realistic thresholds
   - Consider time of day for different thresholds
   - Monitor alert frequency
   - Adjust thresholds based on patterns

3. Maintenance Best Practices:
   - Regular review of alert effectiveness
   - Clean up unnecessary alerts
   - Document alert purposes and responses
   - Maintain up-to-date operator information
*/

-- =============================================
-- PART 6: TROUBLESHOOTING
-- =============================================

-- 1. Check Alert Status
SELECT 
    name,
    enabled,
    has_notification,
    delay_between_responses,
    notification_message,
    include_event_description_in
FROM msdb.dbo.sysalerts;

-- 2. View Recent Alert Occurrences
SELECT TOP 100
    a.name AS alert_name,
    h.occurrence_date,
    h.occurrence_time,
    h.message_text
FROM msdb.dbo.sysalerts a
JOIN msdb.dbo.sysalerthistory h 
    ON a.id = h.alert_id
ORDER BY 
    h.occurrence_date DESC,
    h.occurrence_time DESC;

-- 3. Check Alert Notifications
SELECT 
    a.name AS alert_name,
    o.name AS operator_name,
    n.notification_method
FROM msdb.dbo.sysalerts a
JOIN msdb.dbo.sysnotifications n 
    ON a.id = n.alert_id
JOIN msdb.dbo.sysoperators o 
    ON n.operator_id = o.id;