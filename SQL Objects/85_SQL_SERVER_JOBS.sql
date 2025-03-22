-- =============================================
-- SQL Server Jobs Configuration and Management
-- =============================================

/*
This script demonstrates SQL Server Jobs configuration and management for HR automation:
- Creating and managing jobs for HR tasks
- Scheduling job execution
- Implementing job steps and workflows
- Handling job execution results
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: CREATING HR AUTOMATION JOBS
-- =============================================

-- 1. Create Job Category for HR
EXEC msdb.dbo.sp_add_category
    @class = 'JOB',
    @type = 'LOCAL',
    @name = 'HR Automation';

-- 2. Create Job for Payroll Processing
-- Note: Replace with appropriate values in production
BEGIN TRANSACTION
    DECLARE @jobId BINARY(16);
    EXEC msdb.dbo.sp_add_job
        @job_name = 'HR_Monthly_Payroll_Processing',
        @enabled = 1,
        @description = 'Monthly payroll calculation and processing',
        @category_name = 'HR Automation',
        @owner_login_name = 'sa',
        @job_id = @jobId OUTPUT;

    -- Add Job Step 1: Data Validation
    EXEC msdb.dbo.sp_add_jobstep
        @job_id = @jobId,
        @step_name = 'Validate Employee Data',
        @subsystem = 'TSQL',
        @command = '
            EXEC HR.ValidateEmployeeData;
            IF @@ERROR <> 0
                THROW 50001, ''Employee data validation failed'', 1;
        ',
        @retry_attempts = 1,
        @retry_interval = 5;

    -- Add Job Step 2: Calculate Payroll
    EXEC msdb.dbo.sp_add_jobstep
        @job_id = @jobId,
        @step_name = 'Calculate Payroll',
        @subsystem = 'TSQL',
        @command = '
            EXEC HR.CalculateMonthlyPayroll
                @ProcessingMonth = DATEADD(MONTH, -1, GETDATE());
        ';

    -- Add Job Step 3: Generate Reports
    EXEC msdb.dbo.sp_add_jobstep
        @job_id = @jobId,
        @step_name = 'Generate Reports',
        @subsystem = 'TSQL',
        @command = '
            EXEC HR.GeneratePayrollReports
                @ProcessingMonth = DATEADD(MONTH, -1, GETDATE());
        ';

    -- Set Job Schedule (Monthly)
    EXEC msdb.dbo.sp_add_schedule
        @schedule_name = 'Monthly_Payroll_Schedule',
        @freq_type = 16,          -- Monthly
        @freq_interval = 1,       -- 1st day of month
        @active_start_time = 20000; -- 2:00 AM

    -- Attach Schedule to Job
    EXEC msdb.dbo.sp_attach_schedule
        @job_id = @jobId,
        @schedule_name = 'Monthly_Payroll_Schedule';

COMMIT TRANSACTION;

-- =============================================
-- PART 2: EMPLOYEE ONBOARDING JOB
-- =============================================

-- Create Job for Employee Onboarding
/*
BEGIN TRANSACTION
    DECLARE @onboardingJobId BINARY(16);
    EXEC msdb.dbo.sp_add_job
        @job_name = 'HR_Employee_Onboarding',
        @enabled = 1,
        @description = 'Process new employee onboarding tasks',
        @category_name = 'HR Automation',
        @owner_login_name = 'sa',
        @job_id = @onboardingJobId OUTPUT;

    -- Add Job Steps for Onboarding Process
    EXEC msdb.dbo.sp_add_jobstep
        @job_id = @onboardingJobId,
        @step_name = 'Setup Employee Account',
        @subsystem = 'TSQL',
        @command = 'EXEC HR.SetupEmployeeAccount @EmployeeId = $(EmployeeId);';

    -- Additional steps as needed...
COMMIT TRANSACTION;
*/

-- =============================================
-- PART 3: JOB MONITORING AND MAINTENANCE
-- =============================================

-- 1. View Job Execution History
SELECT 
    j.name AS job_name,
    h.step_name,
    h.message,
    h.run_date,
    h.run_time,
    h.run_duration,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
    END AS status
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j 
    ON h.job_id = j.job_id
WHERE j.category_id = (
    SELECT category_id 
    FROM msdb.dbo.syscategories 
    WHERE name = 'HR Automation'
)
ORDER BY h.run_date DESC, h.run_time DESC;

-- 2. Check Job Status
SELECT 
    name,
    enabled,
    description,
    date_created,
    date_modified
FROM msdb.dbo.sysjobs
WHERE category_id = (
    SELECT category_id 
    FROM msdb.dbo.syscategories 
    WHERE name = 'HR Automation'
);

-- =============================================
-- PART 4: BEST PRACTICES
-- =============================================

/*
1. Job Design Best Practices:
   - Break complex jobs into manageable steps
   - Implement proper error handling in each step
   - Use job categories for organization
   - Document job purpose and dependencies

2. Scheduling Best Practices:
   - Consider business hours and peak times
   - Avoid scheduling conflicts
   - Plan for holidays and maintenance windows
   - Set appropriate retry intervals

3. Maintenance Best Practices:
   - Regular review of job history
   - Clean up old job history
   - Monitor job performance
   - Keep job documentation updated
*/

-- =============================================
-- PART 5: TROUBLESHOOTING
-- =============================================

-- 1. Find Failed Jobs in Last 24 Hours
SELECT 
    j.name AS job_name,
    h.step_name,
    h.message,
    h.run_date,
    h.run_time
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j 
    ON h.job_id = j.job_id
WHERE 
    h.run_status = 0 -- Failed
    AND CAST(CAST(h.run_date AS CHAR(8)) AS DATETIME) >= DATEADD(day, -1, GETDATE());

-- 2. Check Job Step Details
SELECT 
    j.name AS job_name,
    s.step_id,
    s.step_name,
    s.subsystem,
    s.command,
    s.last_run_outcome,
    s.last_run_date,
    s.last_run_time
FROM msdb.dbo.sysjobsteps s
JOIN msdb.dbo.sysjobs j 
    ON s.job_id = j.job_id
WHERE j.category_id = (
    SELECT category_id 
    FROM msdb.dbo.syscategories 
    WHERE name = 'HR Automation'
);