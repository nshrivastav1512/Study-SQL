# SQL System Functions

## Introduction

**Definition:** SQL System Functions are built-in functions that return information about values, objects, and settings within the SQL Server instance. They provide metadata, session details, error information, and other system-level data points.

**Explanation:** These functions are distinct from aggregate, string, date, or mathematical functions as they primarily provide information *about* the system or the current execution context rather than performing calculations on user data directly. They are invaluable for auditing, error handling, dynamic SQL generation, understanding the current session state, and retrieving server configuration details. Many system functions, especially global variables starting with `@@`, provide quick access to important server state information.

## Functions Covered in this Section

This document explores numerous SQL Server System Functions, demonstrated using hypothetical `HR.AuditLog`, `HR.IdentityTest`, and `HR.ErrorLog` tables:

1.  `USER_NAME([user_id])`: Returns the database user name for the specified user ID, or the current user if no ID is provided.
2.  `@@VERSION`: Returns a string containing the version, processor architecture, build date, and operating system for the current SQL Server installation.
3.  `NEWID()`: Generates a unique value of type `uniqueidentifier` (UUID/GUID).
4.  `COALESCE(expression [,...n])`: Returns the first non-NULL expression among its arguments.
5.  `ISNULL(check_expression, replacement_value)`: Replaces NULL with the specified replacement value. Data type precedence applies.
6.  `SESSION_USER`: Returns the username of the current user in the current session. ANSI SQL standard. Often same as `SYSTEM_USER`.
7.  `SYSTEM_USER`: Returns the login name for the current user.
8.  `CURRENT_USER`: Returns the username of the current security context. Often same as `USER_NAME()`.
9.  `APP_NAME()`: Returns the application name for the current session, if set by the application.
10. `HOST_NAME()`: Returns the workstation name of the client connecting to SQL Server.
11. `DB_NAME([database_id])`: Returns the database name for the specified database ID, or the current database if no ID is provided.
12. `ERROR_NUMBER()`: Returns the error number of the error that caused the CATCH block of a TRY...CATCH construct to be run. Returns NULL outside a CATCH block.
13. `ERROR_MESSAGE()`: Returns the complete message text of the error. Returns NULL outside a CATCH block.
14. `ERROR_PROCEDURE()`: Returns the name of the stored procedure or trigger where the error occurred. Returns NULL outside a CATCH block or if the error didn't occur in a module.
15. `ERROR_SEVERITY()`: Returns the severity level of the error. Returns NULL outside a CATCH block.
16. `ERROR_STATE()`: Returns the state number of the error. Returns NULL outside a CATCH block.
17. `FORMATMESSAGE(msg_number | 'string', [param_value [,...n]])`: Constructs a message from an existing message in `sys.messages` or from a provided string, substituting parameter values.
18. `SCOPE_IDENTITY()`: Returns the last identity value inserted into an identity column in the *same scope* (current stored procedure, trigger, function, or batch). Preferred over `@@IDENTITY`.
19. `IDENT_CURRENT('table_or_view')`: Returns the last identity value generated for a specific table or view, regardless of scope or session.
20. `@@TRANCOUNT`: Returns the number of active transactions for the current connection (nesting level).
21. `@@SPID`: Returns the server process ID (SPID) of the current user process.
22. `@@ERROR`: Returns the error number for the last Transact-SQL statement executed. *Legacy function; prefer TRY...CATCH with `ERROR_*` functions.* Reset after each statement.
23. `@@IDENTITY`: Returns the last identity value inserted into an identity column by the last INSERT, SELECT INTO, or bulk copy statement *in the current session*, across all scopes. *Use `SCOPE_IDENTITY()` instead to avoid issues with triggers.*
24. `@@NESTLEVEL`: Returns the nesting level of the current stored procedure execution (0 if executed directly).
25. `@@PROCID`: Returns the object ID of the currently executing stored procedure. Returns NULL if not in a procedure.
26. `SESSIONPROPERTY(option)`: Returns the setting of a specified option for the current session (e.g., 'ANSI_NULLS', 'QUOTED_IDENTIFIER').
27. `@@ROWCOUNT`: Returns the number of rows affected by the last statement executed.

*(Note: The SQL script includes logic to create and populate sample `HR.AuditLog`, `HR.IdentityTest`, and `HR.ErrorLog` tables if they don't exist, along with stored procedures for demonstration.)*

---

## Examples

### 1. USER_NAME()

**Goal:** Get the database username of the current user.

```sql
SELECT
    USER_NAME() AS CurrentDbUser,
    'Shows current database user name' AS Description;
```

**Explanation:**
*   Returns the name by which the current user is known within the current database. This might differ from the login name (`SYSTEM_USER`).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
CurrentDbUser   Description
-------------   --------------------------------
dbo             Shows current database user name
</code></pre>
</details>

### 2. @@VERSION

**Goal:** Retrieve detailed version information about the SQL Server instance.

```sql
SELECT
    @@VERSION AS SQLServerVersionInfo;
```

**Explanation:**
*   Returns a multi-line string containing product level, edition, build number, platform, etc.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
SQLServerVersionInfo
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Microsoft SQL Server 2022 (RTM) - 16.0.1000.6 (X64)
    Oct  8 2022 05:58:25
    Copyright (C) 2022 Microsoft Corporation
    Developer Edition (64-bit) on Windows 10 Pro 10.0 <X64> (Build 19045: ) (Hypervisor)
</code></pre>
</details>

### 3. NEWID()

**Goal:** Generate globally unique identifiers (GUIDs).

```sql
SELECT
    NEWID() AS UniqueID1,
    NEWID() AS UniqueID2;
```

**Explanation:**
*   Generates a new `uniqueidentifier` value each time it's called. Useful for primary keys where merging data from different sources is common.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Values will be different each time.</p>
<pre><code>
UniqueID1                              UniqueID2
------------------------------------   ------------------------------------
F47AC10B-58CC-4372-A567-0E02B2C3D479   A1B2C3D4-E5F6-7890-1234-567890ABCDEF
</code></pre>
</details>

### 4. COALESCE()

**Goal:** Display a `MiddleName` if available, otherwise display `FirstName` and `LastName` concatenated.

```sql
SELECT
    FirstName,
    MiddleName, -- Assuming MiddleName column exists and can be NULL
    LastName,
    COALESCE(MiddleName, FirstName + ' ' + LastName) AS DisplayName
FROM HR.EMP_Details; -- Assuming EMP_Details table exists
```

**Explanation:**
*   `COALESCE(value1, value2, ..., valueN)` returns the first argument that is not NULL. Here, if `MiddleName` is not NULL, it's returned; otherwise, the concatenated `FirstName` and `LastName` is returned.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Assuming some employees have NULL MiddleName:</p>
<pre><code>
FirstName  MiddleName  LastName  DisplayName
---------  ----------  --------  -----------
John       NULL        Doe       John Doe
Jane       M           Smith     M
Bob        NULL        Johnson   Bob Johnson
</code></pre>
</details>

### 5. ISNULL()

**Goal:** Display the employee's phone number, or 'No Phone Number' if it's NULL.

```sql
SELECT
    FirstName,
    Phone, -- Assuming Phone column exists and can be NULL
    ISNULL(Phone, 'No Phone Number') AS ContactNumber
FROM HR.EMP_Details; -- Assuming EMP_Details table exists
```

**Explanation:**
*   `ISNULL(check_expression, replacement_value)` returns `check_expression` if it's not NULL; otherwise, it returns `replacement_value`. The data type of the result is determined by data type precedence (usually the type of `check_expression`).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Assuming some employees have NULL Phone:</p>
<pre><code>
FirstName  Phone           ContactNumber
---------  --------------  ----------------
John       555-1234        555-1234
Jane       NULL            No Phone Number
Bob        555-5678        555-5678
</code></pre>
</details>

### 6-8. SESSION_USER, SYSTEM_USER, CURRENT_USER

**Goal:** Show different user context identifiers.

```sql
SELECT
    SESSION_USER AS SessionUser, -- Often the same as SYSTEM_USER
    SYSTEM_USER AS SystemUserLogin, -- The login name used to connect
    CURRENT_USER AS CurrentDbContextUser; -- User context within the current database
```

**Explanation:**
*   `SYSTEM_USER`: The login name that connected to the SQL Server instance.
*   `SESSION_USER` / `CURRENT_USER`: The user context within the current database. This can change via `EXECUTE AS`.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>If connected as 'MyDomain\UserA' mapped to database user 'AppUser':</p>
<pre><code>
SessionUser   SystemUserLogin   CurrentDbContextUser
-----------   ---------------   --------------------
AppUser       MyDomain\UserA    AppUser
</code></pre>
</details>

### 9. APP_NAME() and 10. HOST_NAME()

**Goal:** Identify the application and client machine connecting to the server.

```sql
SELECT
    APP_NAME() AS ApplicationName,
    HOST_NAME() AS ClientHostName;
```

**Explanation:**
*   `APP_NAME()`: Returns the name specified in the connection string (e.g., 'SQL Server Management Studio', '.Net SqlClient Data Provider', or a custom app name).
*   `HOST_NAME()`: Returns the network name of the client machine. Useful for auditing.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
ApplicationName                   ClientHostName
--------------------------------- --------------
SQL Server Management Studio      LAPTOP-XYZ123
</code></pre>
</details>

### 11. DB_NAME()

**Goal:** Get the name of the current database and the database with ID 1.

```sql
SELECT
    DB_NAME() AS CurrentDatabase,
    DB_NAME(1) AS DatabaseID1; -- Database ID 1 is typically 'master'
```

**Explanation:**
*   `DB_NAME()` returns the name of the database context the query is currently running in.
*   `DB_NAME(database_id)` returns the name for the specified ID.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
CurrentDatabase   DatabaseID1
---------------   -----------
HRSystem          master
</code></pre>
</details>

### 12-17. Error Handling Functions (within CATCH block)

**Goal:** Demonstrate capturing detailed error information within a `TRY...CATCH` block using a stored procedure.

```sql
-- Procedure definition (from SQL script)
CREATE OR ALTER PROCEDURE HR.DemoErrorHandling AS ... -- Contains TRY/CATCH
GO
-- Execution
EXEC HR.DemoErrorHandling;
GO
-- Check the log table
SELECT TOP 1 * FROM HR.ErrorLog ORDER BY ErrorID DESC;
```

**Explanation:**
*   These functions (`ERROR_NUMBER`, `ERROR_MESSAGE`, `ERROR_SEVERITY`, `ERROR_STATE`, `ERROR_PROCEDURE`, `ERROR_LINE`) **only return values within the scope of a CATCH block**.
*   They capture details about the error that transferred control to the CATCH block.
*   `FORMATMESSAGE` can be used to construct user-friendly error messages using predefined templates or custom strings with error details.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Output from the SELECT statement within the CATCH block:</p>
<pre><code>
FormattedError
-------------------------------------------------------------
Error 8134 occurred at line 166: Divide by zero error encountered.
</code></pre>
<p>Output from `SELECT * FROM HR.ErrorLog` after execution:</p>
<pre><code>
ErrorID ErrorNumber ErrorSeverity ErrorState ErrorProcedure        ErrorLine ErrorMessage                      ErrorDate
------- ----------- ------------- ---------- --------------------- --------- --------------------------------- ---------------------------
1       8134        16            1          HR.DemoErrorHandling  166       Divide by zero error encountered. 2025-04-02 16:15:30.1234567
</code></pre>
</details>

### 18. SCOPE_IDENTITY() and 19. IDENT_CURRENT()

**Goal:** Retrieve the most recently generated identity value within the current scope and the overall last identity for a specific table.

```sql
-- Insert a record
INSERT INTO HR.IdentityTest (Description, CreatedBy)
VALUES ('Test Record Scope', SYSTEM_USER);

-- Retrieve identity values
SELECT
    SCOPE_IDENTITY() AS LastIdentityInCurrentScope,
    IDENT_CURRENT('HR.IdentityTest') AS LastIdentityForTable;
```

**Explanation:**
*   `SCOPE_IDENTITY()`: Returns the last identity value inserted by a statement *in the current execution scope* (batch, procedure, function, trigger). This is generally the safest way to get the ID you just inserted.
*   `IDENT_CURRENT('TableName')`: Returns the last identity value generated for the specified table, regardless of scope or session. Useful for checking the current max identity but not reliable for getting the ID *you* just inserted in concurrent environments.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Assuming the last inserted ID was 1003:</p>
<pre><code>
LastIdentityInCurrentScope   LastIdentityForTable
--------------------------   --------------------
1003                         1003
</code></pre>
</details>

### 20. @@TRANCOUNT

**Goal:** Show the nesting level of transactions.

```sql
SELECT @@TRANCOUNT AS InitialLevel; -- Should be 0
BEGIN TRANSACTION;
    SELECT @@TRANCOUNT AS Level1; -- Should be 1
    BEGIN TRANSACTION; -- Nested transaction
        SELECT @@TRANCOUNT AS Level2; -- Should be 2
    COMMIT TRANSACTION; -- Commits inner transaction (decrements @@TRANCOUNT if > 1)
    SELECT @@TRANCOUNT AS Level1_AfterInnerCommit; -- Should be 1
COMMIT TRANSACTION; -- Commits outer transaction
SELECT @@TRANCOUNT AS FinalLevel; -- Should be 0
```

**Explanation:**
*   `@@TRANCOUNT` returns the current nesting level of transactions. `BEGIN TRAN` increments it, `COMMIT TRAN` decrements it (unless it's the outermost commit), `ROLLBACK TRAN` sets it to 0 (rolling back all nested levels).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
InitialLevel
------------
0

Level1
------
1

Level2
------
2

Level1_AfterInnerCommit
-----------------------
1

FinalLevel
----------
0
</code></pre>
</details>

### 21. @@SPID

**Goal:** Get the Server Process ID (SPID) for the current connection.

```sql
SELECT
    @@SPID AS CurrentSessionProcessID;
```

**Explanation:**
*   Returns the unique session identifier for the current connection. Useful for monitoring and troubleshooting specific sessions (e.g., using `sp_who2`).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
CurrentSessionProcessID
-----------------------
58
</code></pre>
</details>

### 22. @@ERROR

**Goal:** Show the error number of the *immediately preceding* statement (legacy approach).

```sql
-- Successful statement
SELECT * FROM HR.IdentityTest WHERE 1=1;
SELECT @@ERROR AS ErrorAfterSuccess; -- Should be 0

-- Statement causing an error (e.g., divide by zero)
SELECT 1/0;
SELECT @@ERROR AS ErrorAfterFailure; -- Should be non-zero (e.g., 8134)
```

**Explanation:**
*   `@@ERROR` holds the error number from the *last executed statement*. It's reset to 0 upon successful execution of the next statement.
*   **Important:** This is a legacy function. Modern error handling should use `TRY...CATCH` and the `ERROR_*()` functions, which are more robust and provide more detail.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
ErrorAfterSuccess
-----------------
0

(Error message: Divide by zero error encountered.)

ErrorAfterFailure
-----------------
8134
</code></pre>
</details>

### 23. @@IDENTITY

**Goal:** Retrieve the last identity value inserted in the current session (potentially across scopes).

```sql
-- Insert a record
INSERT INTO HR.IdentityTest (Description, CreatedBy)
VALUES ('Test Record Identity', SYSTEM_USER);

-- Retrieve identity value
SELECT @@IDENTITY AS LastIdentityInSession;
```

**Explanation:**
*   `@@IDENTITY` returns the last identity value generated by an INSERT or SELECT INTO statement *in the current session*, regardless of the scope (table) where it occurred.
*   **Caution:** If the INSERT statement fires a trigger that inserts into *another* table with an identity column, `@@IDENTITY` will return the identity value from the table inserted into by the *trigger*, not the original table. Use `SCOPE_IDENTITY()` to avoid this ambiguity.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Assuming the last inserted ID was 1004:</p>
<pre><code>
LastIdentityInSession
---------------------
1004
</code></pre>
</details>

### 24. @@NESTLEVEL

**Goal:** Show the procedure nesting level during execution.

```sql
-- Procedures defined in SQL script: HR.OuterProc calls HR.InnerProc
EXEC HR.OuterProc;
```

**Explanation:**
*   `@@NESTLEVEL` indicates how many levels deep the current execution is within stored procedures or triggers. Direct execution is level 0, the first procedure called is level 1, a procedure called by that one is level 2, etc.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Output from within OuterProc:</p>
<pre><code>
OuterNestLevel
--------------
1
</code></pre>
<p>Output from within InnerProc (called by OuterProc):</p>
<pre><code>
InnerNestLevel
--------------
2
</code></pre>
</details>

### 25. @@PROCID

**Goal:** Get the Object ID of the currently executing procedure.

```sql
-- Execute within a procedure context (e.g., inside HR.OuterProc)
-- SELECT OBJECT_NAME(@@PROCID) AS CurrentProcedureName, @@PROCID AS ProcedureObjectID;

-- Execute outside a procedure
SELECT OBJECT_NAME(@@PROCID) AS CurrentProcedureName, @@PROCID AS ProcedureObjectID;
```

**Explanation:**
*   `@@PROCID` returns the object ID of the currently executing stored procedure. Returns NULL if not inside a procedure. `OBJECT_NAME()` can convert this ID to the procedure name.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>When executed outside a procedure:</p>
<pre><code>
CurrentProcedureName   ProcedureObjectID
--------------------   -----------------
NULL                   0
</code></pre>
</details>

### 26. SESSIONPROPERTY()

**Goal:** Check current session settings like ANSI_NULLS and QUOTED_IDENTIFIER.

```sql
SELECT
    SESSIONPROPERTY('ANSI_NULLS') AS AnsiNullsSetting,
    SESSIONPROPERTY('QUOTED_IDENTIFIER') AS QuotedIdentifierSetting,
    SESSIONPROPERTY('TRANSACTION ISOLATION LEVEL') AS IsolationLevel;
```

**Explanation:**
*   `SESSIONPROPERTY('option')` returns the current value for various session-level SET options. Returns 1 for ON, 0 for OFF, or specific values for options like isolation level.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
AnsiNullsSetting   QuotedIdentifierSetting   IsolationLevel
----------------   -----------------------   --------------
1                  1                         2  -- (Read Committed)
</code></pre>
</details>

### 27. @@ROWCOUNT

**Goal:** Determine how many rows were affected by the previous DML statement (UPDATE, INSERT, DELETE).

```sql
-- Perform an update
UPDATE HR.IdentityTest
SET Description = 'Updated Record @@ROWCOUNT'
WHERE ID % 2 = 0; -- Update even IDs

-- Check how many rows were updated
SELECT
    @@ROWCOUNT AS RowsAffectedByUpdate;
```

**Explanation:**
*   `@@ROWCOUNT` contains the number of rows affected by the *immediately preceding* statement. It's crucial to check it right after the statement of interest, as subsequent statements (even a simple `SELECT`) will reset it.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Assuming 2 rows had even IDs > 1000:</p>
<pre><code>
RowsAffectedByUpdate
--------------------
2
</code></pre>
</details>

---

## Interview Question

**Question:** You need to insert a new record into the `HR.IdentityTest` table and immediately retrieve the `ID` (which is an IDENTITY column) that was generated for *that specific insert* to store it in an audit log. Which system function (`@@IDENTITY` or `SCOPE_IDENTITY()`) should you use and why? Write the T-SQL code to perform the insert and capture the ID safely.

### Solution Script

```sql
-- Declare a variable to hold the new ID
DECLARE @NewIdentityID INT;

-- Insert the new record
INSERT INTO HR.IdentityTest (Description, CreatedBy)
VALUES ('Audited Record Insert', SYSTEM_USER);

-- Capture the ID generated by the above INSERT in this scope
SET @NewIdentityID = SCOPE_IDENTITY();

-- Optional: Log the action with the captured ID
INSERT INTO HR.AuditLog (EventType, UserName, ObjectName, AdditionalInfo)
VALUES ('INSERT', SYSTEM_USER, 'HR.IdentityTest', FORMATMESSAGE('New record inserted with ID: %d', @NewIdentityID));

-- Display the captured ID (for verification)
SELECT @NewIdentityID AS CapturedID;
```

### Explanation

1.  **Function Choice:** `SCOPE_IDENTITY()` should be used.
2.  **Reason:** `SCOPE_IDENTITY()` returns the last identity value generated within the current execution scope (the current batch or stored procedure). This ensures you get the ID from *your* specific `INSERT` statement, even if there are triggers on the `HR.IdentityTest` table that might insert records into other tables with identity columns. `@@IDENTITY` returns the last identity generated in the current session, regardless of scope, so it could return an ID generated by a trigger, leading to incorrect auditing.
3.  **Code Breakdown:**
    *   `DECLARE @NewIdentityID INT;`: Declares a variable to store the generated ID.
    *   `INSERT INTO HR.IdentityTest ...`: Performs the actual insert operation.
    *   `SET @NewIdentityID = SCOPE_IDENTITY();`: Immediately after the `INSERT`, this captures the identity value generated by that statement *within this scope* and stores it in the variable.
    *   `INSERT INTO HR.AuditLog ...`: (Optional) Demonstrates using the captured `@NewIdentityID` for logging purposes.
    *   `SELECT @NewIdentityID ...`: Displays the captured ID.

---

## Tricky Interview Questions (Easy to Hard)

1.  **Easy:** What is the difference between `ISNULL(Value, 0)` and `COALESCE(Value, 0)`? Are there situations where they behave differently?
    *   *(Answer Hint: `ISNULL` takes 2 args, data type determined by first arg. `COALESCE` takes multiple args, data type determined by precedence. Behavior differs if `Value` has lower precedence than `0`)*
2.  **Easy:** What does `@@ROWCOUNT` return after a `SELECT` statement?
    *   *(Answer Hint: The number of rows returned by the `SELECT` statement)*
3.  **Medium:** Explain the difference between `SYSTEM_USER` and `USER_NAME()`. When might they return different values?
    *   *(Answer Hint: `SYSTEM_USER` is the login, `USER_NAME` is the database user. Different if login is mapped to a different user name in the DB, or after `EXECUTE AS`)*
4.  **Medium:** Why is `SCOPE_IDENTITY()` generally preferred over `@@IDENTITY`? Describe the trigger scenario where `@@IDENTITY` can be misleading.
    *   *(Answer Hint: `@@IDENTITY` affected by triggers inserting into other identity tables; `SCOPE_IDENTITY` is not)*
5.  **Medium:** Can you rely on `@@ERROR` to check for success after executing a stored procedure? Why or why not?
    *   *(Answer Hint: No, `@@ERROR` only reflects the *last* statement within the procedure or the `EXEC` statement itself. Use output parameters or `TRY...CATCH` within the procedure)*
6.  **Medium/Hard:** How can you get the name of the currently executing stored procedure from *within* that procedure?
    *   *(Answer Hint: Use `OBJECT_NAME(@@PROCID)`)*
7.  **Hard:** If `@@TRANCOUNT` is greater than 1, what happens when you issue a `COMMIT TRANSACTION`? What happens when you issue a `ROLLBACK TRANSACTION`?
    *   *(Answer Hint: `COMMIT` decrements `@@TRANCOUNT` by 1 but doesn't finalize the transaction. `ROLLBACK` rolls back *all* nested transactions and sets `@@TRANCOUNT` to 0)*
8.  **Hard:** You need to generate a unique key for a table that will be populated concurrently by multiple applications. Why might `NEWID()` be a better choice than an `IDENTITY` column in some high-concurrency scenarios, despite being larger?
    *   *(Answer Hint: `NEWID` generates GUIDs independently, avoiding potential bottlenecks on identity value generation. Useful in distributed or merge replication scenarios)*
9.  **Hard:** How could you use `FORMATMESSAGE` along with the `ERROR_*` functions inside a `CATCH` block to re-raise a custom, more informative error message?
    *   *(Answer Hint: Construct a message using `FORMATMESSAGE` with `ERROR_NUMBER`, `ERROR_MESSAGE`, etc., then use `THROW` or `RAISERROR` with the custom message)*
10. **Hard:** What information does `IDENT_CURRENT('MyTable')` provide, and how does its value relate to `SCOPE_IDENTITY()` and `@@IDENTITY` immediately after an `INSERT` into `MyTable`?
    *   *(Answer Hint: `IDENT_CURRENT` gives the last ID generated for that table by *any* session/scope. After your insert, if no other concurrent inserts happened, all three might be the same. But `IDENT_CURRENT` could be higher due to other sessions, while `@@IDENTITY` could be different due to triggers)*