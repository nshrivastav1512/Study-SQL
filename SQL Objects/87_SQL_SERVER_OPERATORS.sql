-- =============================================
-- SQL Server Operators Configuration and Management
-- =============================================

/*
This script demonstrates SQL Server Operators configuration for HR system notifications:
- Creating and managing operators for HR alerts
- Configuring notification methods
- Setting up operator schedules
- Managing operator responsibilities
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: CREATING HR SYSTEM OPERATORS
-- =============================================

-- 1. Create Operator for HR DBA Team
EXEC msdb.dbo.sp_add_operator
    @name = 'HR_DBA_Team',
    @enabled = 1,
    @email_address = 'hrdba@company.com',
    @pager_days_of_week = 127, -- All days
    @pager_start_time = 000000, -- 12:00 AM
    @pager_end_time = 235959; -- 11:59:59 PM

-- 2. Create Operator for HR Managers
EXEC msdb.dbo.sp_add_operator
    @name = 'HR_Managers',
    @enabled = 1,
    @email_address = 'hrmanagers@company.com',
    @weekday_pager_start_time = 090000, -- 9:00 AM
    @weekday_pager_end_time = 170000, -- 5:00 PM
    @saturday_pager_start_time = 090000,
    @saturday_pager_end_time = 130000,
    @sunday_pager_start_time = 000000,
    @sunday_pager_end_time = 000000; -- No notifications on Sunday

-- =============================================
-- PART 2: CONFIGURING NOTIFICATION METHODS
-- =============================================

-- 1. Update Operator with Multiple Notification Methods
EXEC msdb.dbo.sp_update_operator
    @name = 'HR_DBA_Team',
    @email_address = 'hrdba@company.com',
    @pager_address = '+1234567890',
    @netsend_address = 'HRDBA_WORKSTATION';

-- 2. Configure Notification Failure Handling
EXEC msdb.dbo.sp_update_operator
    @name = 'HR_Managers',
    @email_address = 'hrmanagers@company.com',
    @retry_attempts = 3,
    @retry_interval = 5; -- Minutes

-- =============================================
-- PART 3: OPERATOR MANAGEMENT
-- =============================================

-- 1. View Configured Operators
SELECT 
    name,
    enabled,
    email_address,
    last_email_date,
    last_email_time
FROM msdb.dbo.sysoperators;

-- 2. Check Operator Notifications History
SELECT 
    o.name AS operator_name,
    a.name AS alert_name,
    n.notification_method,
    n.sent_date,
    n.sent_status
FROM msdb.dbo.sysnotifications n
JOIN msdb.dbo.sysoperators o 
    ON n.operator_id = o.id
JOIN msdb.dbo.sysalerts a 
    ON n.alert_id = a.id
ORDER BY n.sent_date DESC;

-- =============================================
-- PART 4: OPERATOR ASSIGNMENTS
-- =============================================

-- 1. Assign Operators to Alerts
EXEC msdb.dbo.sp_add_notification
    @alert_name = 'HR_High_CPU_Alert',
    @operator_name = 'HR_DBA_Team',
    @notification_method = 1; -- Email

-- 2. Assign Operators to Jobs
EXEC msdb.dbo.sp_update_job
    @job_name = 'HR_Monthly_Payroll_Processing',
    @notify_level_email = 2, -- When the job fails
    @notify_email_operator_name = 'HR_Managers';

-- =============================================
-- PART 5: BEST PRACTICES
-- =============================================

/*
1. Operator Configuration Best Practices:
   - Use distribution groups for email addresses
   - Configure appropriate notification windows
   - Set up backup operators for critical alerts
   - Test notification delivery regularly

2. Notification Management Best Practices:
   - Avoid notification fatigue
   - Set appropriate retry intervals
   - Document escalation procedures
   - Maintain up-to-date contact information

3. Maintenance Best Practices:
   - Regular review of operator assignments
   - Clean up unused operator configurations
   - Monitor notification success rates
   - Update notification schedules as needed
*/

-- =============================================
-- PART 6: TROUBLESHOOTING
-- =============================================

-- 1. Check Failed Notifications
SELECT 
    o.name AS operator_name,
    n.sent_date,
    n.sent_status,
    n.error_message
FROM msdb.dbo.sysnotifications n
JOIN msdb.dbo.sysoperators o 
    ON n.operator_id = o.id
WHERE n.sent_status <> 1; -- Failed notifications

-- 2. Verify Operator Schedules
SELECT 
    name,
    weekday_pager_start_time,
    weekday_pager_end_time,
    saturday_pager_start_time,
    saturday_pager_end_time,
    sunday_pager_start_time,
    sunday_pager_end_time
FROM msdb.dbo.sysoperators;

-- 3. Test Operator Notification
-- Note: Use this for testing only
EXEC msdb.dbo.sp_notify_operator
    @name = 'HR_DBA_Team',
    @subject = 'Test Notification',
    @body = 'This is a test notification message.';