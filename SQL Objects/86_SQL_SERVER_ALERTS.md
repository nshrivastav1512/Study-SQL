# SQL Deep Dive: SQL Server Agent Alerts

## 1. Introduction: What are SQL Server Agent Alerts?

**SQL Server Agent Alerts** are automated responses defined to react to specific SQL Server events, performance conditions, or Windows Management Instrumentation (WMI) events. When an event occurs that matches an alert's definition, the alert can trigger a predefined response, such as executing a SQL Server Agent job or notifying an operator via Database Mail or `net send`.

**Why use Alerts?**

*   **Proactive Monitoring:** Automatically detect and respond to critical server events (e.g., severe errors, security issues like failed logins) or performance bottlenecks (e.g., high CPU, low disk space) without constant manual monitoring.
*   **Automated Response:** Trigger corrective actions by executing jobs (e.g., run a cleanup procedure if disk space is low, start a diagnostic trace if errors occur).
*   **Notification:** Inform DBAs or relevant personnel immediately when specific conditions are met.

**Key Components:**

*   **Alert Definition:** Specifies the condition that triggers the alert. This can be:
    *   **SQL Server Event:** Based on specific error numbers or severity levels written to the Windows Application Event Log by SQL Server.
    *   **SQL Server Performance Condition:** Based on a specific performance counter crossing a defined threshold (e.g., `CPU Usage > 90%`).
    *   **WMI Event:** Based on a WMI Query Language (WQL) query detecting a specific system event.
*   **Response:** Defines the action(s) to take when the alert is triggered:
    *   **Execute Job:** Runs a specified SQL Server Agent job.
    *   **Notify Operators:** Sends a notification (email, pager - via Database Mail) to one or more defined SQL Server Agent Operators.
*   **Options:** Include enabling/disabling the alert, specifying a delay between responses, including event text in notifications, and associating with a specific database (for event alerts).

## 2. Agent Alerts in Action: Analysis of `86_SQL_SERVER_ALERTS.sql`

This script demonstrates creating various types of alerts using the `msdb.dbo.sp_add_alert` system stored procedure.

**Part 1: Creating Event-Based Alerts**

*   **1. Alert for Failed HR Jobs:**
    ```sql
    EXEC msdb.dbo.sp_add_alert @name = 'HR_Job_Failure_Alert',
        @message_id = 0, -- Any message ID
        @severity = 0, -- Any severity
        @enabled = 1,
        @delay_between_responses = 60, -- Wait 60s before firing again
        @include_event_description_in = 1, -- Include error details in notification
        @category_name = 'HR Automation', -- Filter: Only fire for jobs in this category
        @job_id = NULL; -- Fire for ANY job failure in the category
    -- Add notification response
    EXEC msdb.dbo.sp_add_notification @alert_name = 'HR_Job_Failure_Alert',
        @operator_name = 'HR_DBA_Team', @notification_method = 1; -- 1=Email
    ```
    *   **Explanation:** Creates an alert that fires when *any* job within the 'HR Automation' category fails. It uses `@category_name` to filter job failures. It then adds a notification to email the 'HR_DBA_Team' operator.
*   **2. Alert for Database Errors:**
    ```sql
    EXEC msdb.dbo.sp_add_alert @name = 'HR_Database_Error_Alert',
        @severity = 16, -- Specific severity level (user correctable errors)
        @enabled = 1, ...,
        @database_name = 'HRSystem'; -- Only for errors in HRSystem DB
    ```
    *   **Explanation:** Creates an alert that fires specifically for errors with severity level 16 occurring within the `HRSystem` database.

**Part 2: Performance Condition Alerts**

*   **1. High CPU Usage:**
    ```sql
    EXEC msdb.dbo.sp_add_alert @name = 'HR_High_CPU_Alert', ...,
        @performance_condition = 'SQLServer:Processor|Process(sqlservr)|% Processor Time|>|90';
        -- Object|Instance|Counter|Comparator|Value
    ```
    *   **Explanation:** Creates an alert based on a performance counter. It monitors the `% Processor Time` for the `sqlservr` process instance within the `SQLServer:Processor` object. It fires if the value goes *above* (`>`) 90%.
*   **2. Low Disk Space:**
    ```sql
    EXEC msdb.dbo.sp_add_alert @name = 'HR_Low_Disk_Space_Alert', ...,
        @performance_condition = 'LogicalDisk|C:|Free Megabytes|<|1000';
    ```
    *   **Explanation:** Monitors the `Free Megabytes` counter for the `C:` instance of the `LogicalDisk` object. Fires if the value drops *below* (`<`) 1000 MB.

**Part 3: Security Monitoring Alerts**

*   **1. Failed Logins:**
    ```sql
    EXEC msdb.dbo.sp_add_alert @name = 'HR_Failed_Login_Alert',
        @message_id = 18456, -- Specific error number for login failure
        @severity = 0, ...;
    ```
    *   **Explanation:** Creates an event alert specifically for error number 18456 (Login failed for user...).
*   **2. Permission Changes:**
    ```sql
    EXEC msdb.dbo.sp_add_alert @name = 'HR_Permission_Change_Alert',
        @message_id = 33205, -- Example error for permission changes (might vary)
        @severity = 0, ...;
    ```
    *   **Explanation:** Attempts to create an alert for permission changes by monitoring a specific message ID. *Note: Reliably alerting on all permission changes often requires SQL Server Audit or Extended Events, as specific error numbers might not cover all scenarios.*

**Part 4: Alert Management**

*   **1. View Alerts:** Queries `msdb.dbo.sysalerts` to list configured alerts and their properties.
*   **2. Check History:** Queries `msdb.dbo.sysalerthistory` (joined with `sysalerts`) to see when alerts were last triggered and associated details.

**Part 5: Best Practices**

*   Configure alerts meaningfully (appropriate severity/performance thresholds).
*   Set reasonable delays between responses to avoid alert storms.
*   Test alerts.
*   Monitor alert frequency and adjust thresholds.
*   Keep operator information up-to-date.
*   Document alerts.

**Part 6: Troubleshooting**

*   **Check Status:** Query `msdb.dbo.sysalerts` to ensure the alert is enabled and configured correctly.
*   **View History:** Query `msdb.dbo.sysalerthistory` for recent occurrences.
*   **Check Notifications:** Query `msdb.dbo.sysnotifications` (joined with `sysalerts` and `sysoperators`) to verify operators are correctly assigned to alerts.
*   **Check Agent Error Log:** Use `xp_readerrorlog` to look for Agent-specific errors related to alert processing or notifications (e.g., Database Mail issues).

## 3. Targeted Interview Questions (Based on `86_SQL_SERVER_ALERTS.sql`)

**Question 1:** What are the three main types of conditions that can trigger a SQL Server Agent Alert?

**Solution 1:**
1.  **SQL Server Event:** Based on a specific error number or a minimum severity level occurring.
2.  **SQL Server Performance Condition:** Based on a specific performance counter value crossing a defined threshold (e.g., going above or below a value).
3.  **WMI Event:** Based on a Windows Management Instrumentation (WMI) event occurring on the server, detected via a WQL query.

**Question 2:** An alert named 'HR_Job_Failure_Alert' is configured as shown in the script. If a job named 'NonHR_Maintenance' (which is *not* in the 'HR Automation' category) fails, will this alert fire? Why or why not?

**Solution 2:** No, the alert will not fire. The alert definition includes the parameter `@category_name = 'HR Automation'`. This acts as a filter, meaning the alert will only respond to events (in this case, job failures, indicated by `@job_id = NULL`) related to jobs within that specific category. Since 'NonHR_Maintenance' is not in the 'HR Automation' category, its failure won't trigger this particular alert.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What SQL Server Agent component must be configured for alerts to send email notifications?
    *   **Answer:** Database Mail (and associated Operators).
2.  **[Easy]** Can an alert directly execute a T-SQL script as its response?
    *   **Answer:** No. The direct responses for an alert are either "Execute Job" or "Notify Operators". To run a T-SQL script in response to an alert, you must create a job containing a T-SQL job step with that script, and then configure the alert to execute that job.
3.  **[Medium]** What does the `@delay_between_responses` parameter in `sp_add_alert` control?
    *   **Answer:** It specifies the minimum time (in seconds) that must pass after an alert fires and notifies an operator before the alert can notify that *same operator* again, even if the triggering condition occurs multiple times within that period. It helps prevent "alert storms" for frequently occurring events.
4.  **[Medium]** If you create an alert for severity level 19, will it also fire for errors with severity level 20?
    *   **Answer:** Yes. When an alert is defined for a specific severity level (e.g., 19), it responds to any error occurring with that severity level *or higher* (so it would fire for severity 19, 20, 21, ..., 25).
5.  **[Medium]** Can you configure an alert to only fire if a specific error message occurs within a specific database?
    *   **Answer:** Yes. You use the `@message_id` parameter to specify the error number and the `@database_name` parameter to restrict the alert to events occurring only within that database.
6.  **[Medium]** Where is the history of alert occurrences stored?
    *   **Answer:** In the `msdb.dbo.sysalerthistory` table.
7.  **[Hard]** How would you create an alert that fires only if a specific performance counter (e.g., 'Buffer cache hit ratio') drops *below* a certain value (e.g., 95)?
    *   **Answer:** You would use `sp_add_alert` and specify the `@performance_condition` parameter using the less than (`<`) comparator. The format would be similar to: `'SQLServer:Buffer Manager|Buffer cache hit ratio|<|95'`. (The exact object name 'SQLServer:Buffer Manager' might vary slightly based on instance naming).
8.  **[Hard]** Can SQL Server Agent alerts detect conditions *within* query results (e.g., alert if `SELECT COUNT(*) FROM Orders WHERE Status = 'Error'` returns a value greater than 0)?
    *   **Answer:** Not directly using the built-in alert condition types (Event, Performance, WMI). To achieve this, you would typically create a **SQL Server Agent Job** scheduled to run periodically (e.g., every 5 minutes). This job would contain a T-SQL step that executes the query (`SELECT COUNT(*)...`). If the count exceeds the threshold, the job step would use `RAISERROR` to raise a custom error message (with a specific error number and severity). You would then create a separate **SQL Server Event Alert** configured to respond to that specific custom error number raised by the job.
9.  **[Hard]** What happens if the event triggering an alert occurs while the SQL Server Agent service is stopped?
    *   **Answer:** The alert will not fire. SQL Server Agent must be running to monitor for alert conditions and execute responses. If the condition is based on an event written to the Windows Application Event Log, the event will still be logged there, but the Agent won't react until it's restarted (and it typically doesn't process past events upon restart). Performance condition alerts are only evaluated while the Agent is running.
10. **[Hard/Tricky]** If an alert is configured to execute `JobA` upon firing, and `JobA` is already running when the alert fires again (before the `@delay_between_responses` has elapsed), what happens? Will a second instance of `JobA` be started?
    *   **Answer:** No. By default, SQL Server Agent will not start a second instance of a job if it is already running. The second alert trigger (within the delay period) would typically be ignored in terms of executing the job response, although the alert occurrence might still be logged in `sysalerthistory`.
