# SQL Deep Dive: SQL Server Audit

## 1. Introduction: What is SQL Server Audit?

**SQL Server Audit** is a feature that allows you to track and log server-level and database-level events occurring on your SQL Server instance. It provides a robust and configurable mechanism for auditing user actions, data changes, security events, and other activities for security monitoring, compliance, and troubleshooting purposes.

**Why use SQL Server Audit?**

*   **Security Monitoring:** Track sensitive data access, permission changes, failed logins, and other security-related events.
*   **Compliance:** Meet regulatory requirements (like SOX, HIPAA, GDPR) that mandate auditing of specific database activities.
*   **Troubleshooting:** Investigate unauthorized changes or diagnose application behavior by reviewing the sequence of events.
*   **Accountability:** Determine who performed specific actions on the database.

**Key Components:**

1.  **Server Audit:** Defines the *destination* for audit records (e.g., File, Windows Security Log, Windows Application Log) and configures options like file size, rollover, and queue delay. Created at the server level.
2.  **Server Audit Specification:** Defines *which server-level actions* should be audited (e.g., `FAILED_LOGIN_GROUP`, `DATABASE_OBJECT_CHANGE_GROUP`). Linked to a Server Audit object. Only one per Server Audit.
3.  **Database Audit Specification:** Defines *which database-level actions* should be audited *within a specific database* (e.g., `SELECT`, `UPDATE`, `DELETE` on specific tables or schemas, `DATABASE_ROLE_MEMBER_CHANGE_GROUP`). Linked to a Server Audit object. Multiple can exist per database, linked to the same Server Audit.

**Audit Destination Options:**

*   **File:** Writes audit records to binary `.sqlaudit` files in a specified path. Most common and flexible option. Requires managing file size and archiving.
*   **Windows Security Log:** Writes audit records to the Windows Security event log. Requires specific OS permissions and configuration (`auditpol`). Integrates with Windows event collection systems.
*   **Windows Application Log:** Writes audit records to the Windows Application event log. Easier to set up than the Security Log but less secure and potentially noisier.

## 2. SQL Server Audit in Action: Analysis of `92_DATABASE_AUDIT.sql`

This script demonstrates setting up a file-based audit for HR data access.

**Part 1: Server Audit Setup (`CREATE SERVER AUDIT`)**

```sql
USE master;
GO
CREATE SERVER AUDIT HR_System_Audit
TO FILE (
    FILEPATH = 'C:\SQLAudit\', -- Destination folder
    MAXSIZE = 100 MB,         -- Max size per file
    MAX_ROLLOVER_FILES = 5    -- Max number of files before overwriting oldest
)
WITH ( QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE ); -- Options
GO
ALTER SERVER AUDIT HR_System_Audit WITH (STATE = ON); -- Enable the audit
GO
```

*   **Explanation:**
    *   Creates a server-level audit named `HR_System_Audit`.
    *   Specifies the destination `TO FILE` with a path, max file size, and rollover file count.
    *   `QUEUE_DELAY`: Milliseconds SQL Server can wait before forcing audit writes to disk.
    *   `ON_FAILURE`: Action if audit write fails (`CONTINUE`, `SHUTDOWN`, `FAIL_OPERATION`). `CONTINUE` logs the failure but allows the original operation to proceed (potential audit loss). `SHUTDOWN` stops the instance (drastic!). `FAIL_OPERATION` causes the user action that triggered the audit event to fail.
    *   `ALTER SERVER AUDIT ... WITH (STATE = ON)` activates the audit to start collecting records.

**Part 2: Database Audit Specification (`CREATE DATABASE AUDIT SPECIFICATION`)**

```sql
USE HRSystem;
GO
CREATE DATABASE AUDIT SPECIFICATION HR_Data_Access_Audit
FOR SERVER AUDIT HR_System_Audit -- Link to the server audit destination
-- Define actions to audit:
ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Employees BY public), -- DML on Employees by anyone
ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Salaries BY public), -- DML on Salaries by anyone
ADD (SCHEMA_OBJECT_ACCESS_GROUP), -- Access to any schema object (tables, views, procs)
ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP) -- Changes to database role membership
WITH (STATE = ON); -- Enable this specification
GO
```

*   **Explanation:**
    *   Creates a database-level specification named `HR_Data_Access_Audit` within the `HRSystem` database.
    *   Links it `FOR SERVER AUDIT HR_System_Audit` to direct its records to the previously defined file destination.
    *   Uses `ADD (...)` to define specific **Audit Action Groups** (predefined collections like `SCHEMA_OBJECT_ACCESS_GROUP`) or specific actions (`SELECT`, `INSERT`, etc.) on specific objects (`dbo.Employees`) by specific principals (`public`).
    *   `WITH (STATE = ON)` activates this specification.

**Part 3: Audit Log Analysis (`sys.fn_get_audit_file`)**

```sql
-- Read all records from audit files in the specified path
SELECT event_time, action_id, server_principal_name, ... statement
FROM sys.fn_get_audit_file('C:\SQLAudit\*', DEFAULT, DEFAULT);

-- Filter specific actions on a specific object
SELECT ... FROM sys.fn_get_audit_file(...)
WHERE action_id IN ('INS', 'UPD', 'DEL') AND object_name LIKE '%Employees%';
```

*   **Explanation:** Uses the system function `sys.fn_get_audit_file` to read the binary `.sqlaudit` files.
    *   Takes the file path pattern, initial file, and offset as arguments (`DEFAULT`, `DEFAULT` usually reads all files from the beginning).
    *   Returns a table with detailed information about each captured event, including time, action ID, principal names, object names, and the T-SQL statement executed (if applicable).
    *   Standard `WHERE` clauses can be used to filter the results.

**Part 4: Audit Maintenance**

*   **`Maintain_HR_Audit` Procedure:** Demonstrates a conceptual stored procedure for managing audit files.
    *   Uses `xp_cmdshell` (requires enabling) to execute OS commands (`MOVE`, `FORFILES`) to archive old `.sqlaudit` files to a dated subfolder and delete archives older than a specified retention period (e.g., 30 days). *Note: Using `xp_cmdshell` has security implications and might be restricted. Alternative methods like PowerShell scripts run via SQL Agent are often preferred.*
*   **Scheduling:** Shows conceptual T-SQL for creating a SQL Server Agent job to run the maintenance procedure regularly (e.g., daily).

**Part 5: Audit Reporting**

*   **`HR_Audit_Summary` View:** Creates a view summarizing audit actions by date, principal, action type, and object, providing a high-level overview.
*   **`Report_Suspicious_Activity` Procedure:** Demonstrates querying the audit log for potentially suspicious patterns:
    *   Failed access attempts (`succeeded = 0`).
    *   Access outside business hours (`DATEPART(HOUR, ...)`).
    *   Potentially large data modifications (`HAVING COUNT(*) > 1000`).

## 3. Targeted Interview Questions (Based on `92_DATABASE_AUDIT.sql`)

**Question 1:** What are the two main components you need to create to start auditing database-level actions (like `SELECT` on a table) to a file using SQL Server Audit?

**Solution 1:**
1.  **Server Audit (`CREATE SERVER AUDIT ... TO FILE ...`):** Defines the destination (the file path, size, etc.) for the audit records at the server level.
2.  **Database Audit Specification (`CREATE DATABASE AUDIT SPECIFICATION ... FOR SERVER AUDIT ... ADD (...)`):** Defined within the specific database, this specifies *which database-level actions* (e.g., `SELECT ON dbo.Employees BY public`) should be captured and links them to the Server Audit created in step 1. Both must be enabled (`WITH (STATE = ON)`).

**Question 2:** What function is used to read the data captured by SQL Server Audit when the destination is set `TO FILE`?

**Solution 2:** The system function `sys.fn_get_audit_file()` is used. It takes the file path pattern as input and returns the audit records as a relational table.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can you have multiple Server Audit objects active on a single SQL Server instance?
    *   **Answer:** Yes, you can create and enable multiple Server Audit objects, potentially writing to different destinations (e.g., one to file, one to the Security Log).
2.  **[Easy]** Can a single Database Audit Specification audit actions across multiple databases?
    *   **Answer:** No. A Database Audit Specification is defined *within* a specific database and audits actions only *within that database*. To audit actions in multiple databases, you need to create a separate Database Audit Specification in each database (though they can all point to the same Server Audit destination).
3.  **[Medium]** What is the difference between a Server Audit Specification and a Database Audit Specification?
    *   **Answer:**
        *   **Server Audit Specification:** Audits *server-level* actions (e.g., login failures, server role changes, database creation/alteration). Defined at the server level.
        *   **Database Audit Specification:** Audits *database-level* actions (e.g., DML on tables, EXECUTE on procedures, permission changes within the database). Defined within a specific database.
4.  **[Medium]** What does the `ON_FAILURE = CONTINUE` option mean when creating a Server Audit? What is a potential risk?
    *   **Answer:** `ON_FAILURE = CONTINUE` means that if SQL Server fails to write a record to the audit destination (e.g., disk full, permission issue), the user operation that triggered the audit event will *still be allowed to proceed*. The risk is **potential audit loss** – an auditable event occurs, but there's no record of it. `ON_FAILURE = FAIL_OPERATION` is stricter, causing the user action to fail if the audit cannot be written. `ON_FAILURE = SHUTDOWN` is the most drastic, stopping the SQL Server instance.
5.  **[Medium]** Can SQL Server Audit capture the exact values being inserted or updated in DML statements?
    *   **Answer:** No, not directly within the standard audit record. SQL Server Audit typically logs the *statement* executed (`INSERT INTO ... VALUES (...)`), the principal, object, time, etc., but not the specific *values* bound to parameters or the before/after values for updates (unless they are part of the literal statement text, which is rare with parameterized queries). For capturing actual data changes, you would typically use other features like Change Data Capture (CDC), Change Tracking, or Temporal Tables.
6.  **[Medium]** What permission is generally required to create and manage Server Audits and Server Audit Specifications?
    *   **Answer:** The `ALTER ANY SERVER AUDIT` permission or membership in the `sysadmin` fixed server role.
7.  **[Hard]** How can you audit actions performed by members of the `sysadmin` role? Is it enabled by default?
    *   **Answer:** By default, actions performed by `sysadmin` members are often *not* audited, even if covered by an audit specification. To audit `sysadmin` activity, you typically need to ensure the Server Audit itself is configured correctly and potentially enable specific trace flags or use other monitoring methods like Extended Events sessions specifically configured to capture `sysadmin` actions. Auditing privileged users requires careful setup.
8.  **[Hard]** What are Audit Action Groups (e.g., `DATABASE_ROLE_MEMBER_CHANGE_GROUP`, `SCHEMA_OBJECT_ACCESS_GROUP`) used for in Audit Specifications?
    *   **Answer:** Audit Action Groups are predefined collections of related audit actions provided by Microsoft. Using a group (like `DATABASE_ROLE_MEMBER_CHANGE_GROUP`) in an audit specification is a convenient way to audit all actions belonging to that category (e.g., `ADD MEMBER`, `DROP MEMBER` for database roles) without having to list each individual action ID explicitly. Microsoft maintains the list of actions within each group across versions.
9.  **[Hard]** Can you filter the events captured by a Database Audit Specification *before* they are written to the audit target (e.g., only audit `SELECT` statements from a specific application)?
    *   **Answer:** Yes, starting with SQL Server 2012, you can add a `WHERE` clause to a Server Audit or Database Audit Specification to filter events based on predicate expressions (e.g., `WHERE application_name = 'MyApp'` or `WHERE server_principal_name <> 'AdminLogin'`). This filtering happens *before* the record is written to the target, reducing the volume of audit data collected.
10. **[Hard/Tricky]** If you configure a Server Audit to write to the Windows Security Log, what additional steps are typically required outside of SQL Server?
    *   **Answer:**
        1.  **Grant Permission:** The SQL Server service account needs the "Generate security audits" permission (`SeAuditPrivilege`) in the Local Security Policy (or via Group Policy) on the server.
        2.  **Configure Audit Policy:** Use the `auditpol.exe` command-line tool (or Group Policy) to enable auditing for the "Object Access - Application Generated" subcategory (`auditpol /set /subcategory:"Application Generated" /success:enable /failure:enable`).
        3.  **Register SQL Server as Source:** Ensure SQL Server is registered as an audit event source with Windows. This usually happens automatically, but might require `sqlservr.exe -s` during setup or manual configuration in some cases. Without these OS-level configurations, SQL Server won't be able to write audit events to the Security Log.
