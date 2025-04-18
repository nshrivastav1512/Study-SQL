# SQL Deep Dive: Stored Procedures

## 1. Introduction: What are Stored Procedures?

A **Stored Procedure** is a pre-compiled collection of one or more Transact-SQL (T-SQL) statements grouped together as a logical unit and stored within the database. Instead of sending individual SQL statements from an application, the application can simply execute the stored procedure by name, optionally passing parameters.

**Why use Stored Procedures?**

*   **Encapsulation & Reusability:** Group related SQL logic into a single, reusable unit. Call it multiple times from different applications or scripts without rewriting the code.
*   **Performance:** Stored procedures are parsed and compiled once when first executed (or created), and the execution plan is cached. Subsequent executions reuse the cached plan (usually), leading to faster execution compared to sending ad-hoc SQL statements repeatedly.
*   **Security:** Grant users `EXECUTE` permission on the procedure without granting direct permissions on the underlying tables or views accessed within the procedure (leveraging ownership chaining). This provides a controlled interface for data access and modification.
*   **Reduced Network Traffic:** Instead of sending potentially large SQL statements over the network, the client only sends the `EXECUTE procedure_name` command and any parameters, reducing network bandwidth usage.
*   **Maintainability:** Business logic stored in procedures can be updated centrally in the database without requiring changes to application code (as long as the procedure's parameters and output remain consistent).
*   **Transactional Integrity:** Can encapsulate multiple DML statements within a transaction (`BEGIN TRAN`/`COMMIT`/`ROLLBACK`) to ensure atomicity.

## 2. Stored Procedures in Action: Analysis of `44_STORED_PROCEDURES.sql`

This script demonstrates creating, altering, dropping, and executing stored procedures with various features.

**a) Basic Stored Procedure (`CREATE PROCEDURE`)**

```sql
CREATE PROCEDURE sp_GetAllProjects
AS
BEGIN
    -- Prevent "X rows affected" messages
    SET NOCOUNT ON;
    SELECT ProjectID, ProjectName, ... FROM Projects ORDER BY StartDate DESC;
END;
GO
```

*   **Explanation:** Creates a simple procedure named `sp_GetAllProjects` that selects and returns data from the `Projects` table. `AS BEGIN ... END` defines the procedure body. `SET NOCOUNT ON` is a best practice to reduce network traffic.

**b) Procedure with Input Parameters**

```sql
CREATE PROCEDURE sp_GetProjectsByStatus
    @Status VARCHAR(20) -- Input parameter declaration
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ... FROM Projects WHERE Status = @Status ORDER BY ...;
END;
GO
```

*   **Explanation:** Accepts an input parameter (`@Status`) which is used in the `WHERE` clause to filter results. Parameters are declared after the procedure name with their data type.

**c) Procedure with Optional Parameters (Default Values)**

```sql
CREATE PROCEDURE sp_SearchProjects
    @ProjectName VARCHAR(100) = NULL, -- Default value is NULL
    @Status VARCHAR(20) = NULL,
    @MinBudget DECIMAL(15,2) = NULL,
    @MaxBudget DECIMAL(15,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ... FROM Projects
    WHERE (@ProjectName IS NULL OR ProjectName LIKE '%' + @ProjectName + '%') AND ...;
END;
GO
```

*   **Explanation:** Uses default values (`= NULL`) for parameters, making them optional when calling the procedure. The `WHERE` clause uses the `(@Param IS NULL OR Column = @Param)` pattern to apply filters only when a non-NULL value is passed for the parameter.

**d) Procedure with Output Parameters (`OUTPUT`)**

```sql
CREATE PROCEDURE sp_GetProjectStats
    @Status VARCHAR(20), -- Input
    @ProjectCount INT OUTPUT, -- Output parameter
    @TotalBudget DECIMAL(18,2) OUTPUT, -- Output parameter
    @AvgBudget DECIMAL(18,2) OUTPUT -- Output parameter
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @ProjectCount = COUNT(*), @TotalBudget = SUM(Budget), @AvgBudget = AVG(Budget)
    FROM Projects WHERE Status = @Status;
END;
GO
```

*   **Explanation:** Uses the `OUTPUT` keyword in the parameter declaration to specify parameters that will return values back to the caller. The procedure assigns values to these parameters using `SELECT @OutputParam = ...` or `SET @OutputParam = ...`.

**e) Procedure with Return Value (`RETURN`)**

```sql
CREATE PROCEDURE sp_AddProject ...
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (...) BEGIN
        RETURN -1; -- Return an integer status code (e.g., -1 for error)
    END
    INSERT INTO Projects (...) VALUES (...);
    RETURN SCOPE_IDENTITY(); -- Return the newly generated ProjectID
END;
GO
```

*   **Explanation:** Uses the `RETURN` statement to immediately exit the procedure and optionally return an integer status code. By convention, 0 indicates success, and non-zero values indicate different error or status conditions. `RETURN` is limited to returning integers. `SCOPE_IDENTITY()` is often returned to get the ID generated by an `INSERT`.

**f) Procedure with Error Handling (`TRY...CATCH`, `THROW`, `RAISERROR`)**

```sql
CREATE PROCEDURE sp_AssignEmployeeToProject ...
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (...) THROW 50001, 'Project does not exist.', 1;
        IF EXISTS (...) THROW 50003, 'Employee already assigned...', 1;
        INSERT INTO ProjectAssignments (...);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        -- Option 1: Re-throw original error (modern)
        -- THROW;
        -- Option 2: Raise a custom error (older method)
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE(), ...;
        RAISERROR(@ErrorMessage, ERROR_SEVERITY(), ERROR_STATE());
    END CATCH;
END;
GO
```

*   **Explanation:** Implements robust error handling using `TRY...CATCH` and transactions.
    *   `TRY` block contains the main logic within a transaction.
    *   `THROW` (SQL 2012+) or `RAISERROR` (older) is used to signal custom errors or constraint violations.
    *   `CATCH` block executes if any error occurs in the `TRY` block.
    *   `IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;` ensures the transaction is rolled back on error.
    *   Error information (`ERROR_MESSAGE()`, etc.) can be logged or re-raised.

**g) Procedure with Dynamic SQL (`sp_executesql`)**

```sql
CREATE PROCEDURE sp_DynamicProjectQuery @SortColumn VARCHAR(50) = ..., @WhereClause NVARCHAR(500) = NULL
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    -- Validate input parameters (@SortColumn, @SortDirection) to prevent injection
    -- Build SQL string dynamically
    SET @SQL = 'SELECT ... FROM Projects';
    IF @WhereClause IS NOT NULL SET @SQL = @SQL + ' WHERE ' + @WhereClause;
    SET @SQL = @SQL + ' ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection;
    -- Execute using sp_executesql (safer than EXEC())
    EXEC sp_executesql @SQL;
END;
GO
```

*   **Explanation:** Constructs a SQL query as a string based on input parameters (e.g., for dynamic sorting or filtering).
*   **Security:** Crucial to validate input parameters (`@SortColumn`, `@WhereClause`) rigorously to prevent SQL injection vulnerabilities. Use `QUOTENAME()` for object names. Prefer `sp_executesql` over `EXEC()` as it allows parameterization for values passed into the dynamic query (though not shown in this specific example's dynamic part).

**h) Procedure with Table-Valued Parameter (TVP)**

```sql
-- First, define the table type
CREATE TYPE ProjectMilestoneTableType AS TABLE (...);
GO
-- Then, use it as a parameter (READONLY)
CREATE PROCEDURE sp_AddProjectWithMilestones ..., @Milestones ProjectMilestoneTableType READONLY
AS
BEGIN ...
    INSERT INTO ProjectMilestones (...) SELECT ... FROM @Milestones; -- Use TVP like a table
... END;
GO
```

*   **Explanation:** Allows passing multiple rows of data into a stored procedure as a single parameter.
    1.  A user-defined table type (`ProjectMilestoneTableType`) is created first.
    2.  The procedure declares a parameter of this table type, marked `READONLY`.
    3.  The caller populates a table variable of this type and passes it to the procedure.
    4.  Inside the procedure, the TVP (`@Milestones`) can be queried like a regular read-only table. Efficient way to pass structured lists of data.

**i) Procedure with Temporary Tables (`#temp`)**

```sql
CREATE PROCEDURE sp_AnalyzeProjectPerformance AS
BEGIN
    CREATE TABLE #ProjectPerformance (...); -- Create temp table
    INSERT INTO #ProjectPerformance SELECT ...; -- Populate
    UPDATE #ProjectPerformance SET ...; -- Process data
    SELECT * FROM #ProjectPerformance ORDER BY ...; -- Return results
    DROP TABLE #ProjectPerformance; -- Clean up
END;
GO
```

*   **Explanation:** Uses temporary tables (`#ProjectPerformance`) for storing intermediate results during complex processing within the procedure. Temp tables are useful for larger datasets where indexing or statistics might be beneficial, unlike table variables. Remember to drop them explicitly.

**j) Procedure with Cursor (Use Sparingly)**

```sql
CREATE PROCEDURE sp_UpdateProjectStatus AS
BEGIN ...
    DECLARE ProjectCursor CURSOR FOR SELECT ...; -- Declare cursor
    OPEN ProjectCursor;
    FETCH NEXT FROM ProjectCursor INTO @ProjectID, ...; -- Fetch first row
    WHILE @@FETCH_STATUS = 0 BEGIN -- Loop while rows exist
        -- Process current row data (@ProjectID, ...)
        UPDATE Projects SET Status = @NewStatus WHERE ProjectID = @ProjectID;
        IF @@ROWCOUNT > 0 INSERT INTO ProjectStatus (...);
        FETCH NEXT FROM ProjectCursor INTO @ProjectID, ...; -- Fetch next row
    END
    CLOSE ProjectCursor; DEALLOCATE ProjectCursor; -- Clean up
END;
GO
```

*   **Explanation:** Uses a cursor (`DECLARE CURSOR`, `OPEN`, `FETCH`, `CLOSE`, `DEALLOCATE`) to iterate through a result set row by row and perform actions based on each row's data.
*   **Caution:** Cursors are generally **less performant** than set-based operations (`UPDATE ... FROM ... JOIN`, window functions, etc.) in SQL Server. Avoid them unless row-by-row processing is absolutely necessary and cannot be achieved efficiently with set-based logic.

**k) Altering a Stored Procedure (`ALTER PROCEDURE`)**

```sql
ALTER PROCEDURE sp_GetAllProjects AS BEGIN ... -- Modified SELECT list END;
GO
```

*   **Explanation:** Modifies the definition of an existing stored procedure without dropping and recreating it. Preserves existing permissions granted on the procedure.

**l) Dropping a Stored Procedure (`DROP PROCEDURE`)**

```sql
DROP PROCEDURE sp_GetProjectsByStatus;
GO
```

*   **Explanation:** Permanently removes the stored procedure definition from the database.

**m) Executing Stored Procedures (`EXEC` or `EXECUTE`)**

```sql
-- Basic execution
EXEC sp_GetAllProjects;
-- With input parameters
EXEC sp_SearchProjects @ProjectName = 'Website', @MinBudget = 50000;
-- With output parameters
DECLARE @Count INT, ...;
EXEC sp_GetProjectStats @Status = 'In Progress', @ProjectCount = @Count OUTPUT, ...;
SELECT @Count, ...;
-- With return value
DECLARE @ReturnValue INT;
EXEC @ReturnValue = sp_AddProject @ProjectName = ..., ...;
SELECT @ReturnValue AS ResultCode;
```

*   **Explanation:** Demonstrates different ways to call stored procedures using `EXEC` or `EXECUTE`. Input parameters are passed by name (`@ParamName = value`) or position. `OUTPUT` parameters require the `OUTPUT` keyword in the `EXEC` call and a variable to receive the value. The integer `RETURN` value is captured by assigning the `EXEC` call to a variable.

## 3. Targeted Interview Questions (Based on `44_STORED_PROCEDURES.sql`)

**Question 1:** What are two main benefits of using stored procedures compared to embedding SQL queries directly in application code?

**Solution 1:** Two main benefits are:
1.  **Performance:** Stored procedures are compiled and their execution plans cached by SQL Server, leading to faster execution on subsequent calls compared to ad-hoc queries which might need parsing and compiling each time.
2.  **Security:** You can grant users `EXECUTE` permission on a stored procedure without granting them direct permissions on the underlying tables accessed by the procedure. This provides a controlled interface and limits direct data access (Principle of Least Privilege).
(Other valid answers include reduced network traffic, code reusability, maintainability, encapsulation of business logic).

**Question 2:** Explain the difference between an `OUTPUT` parameter and a `RETURN` value in a stored procedure.

**Solution 2:**

*   **`OUTPUT` Parameter:** Declared using the `OUTPUT` keyword. Used to pass data *back* from the procedure to the calling batch/procedure. Can be of various data types (not just integer). Multiple `OUTPUT` parameters can be used. The caller must also use the `OUTPUT` keyword when executing the procedure to receive the value into a variable.
*   **`RETURN` Value:** Used to immediately exit a procedure and return an integer status code (by convention, 0 for success, non-zero for failure/status). Only one integer value can be returned this way. It's primarily for indicating success/failure status, not for returning general data.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What T-SQL statement is used to execute a stored procedure?
    *   **Answer:** `EXECUTE` or `EXEC`.
2.  **[Easy]** What keyword is used to modify an existing stored procedure?
    *   **Answer:** `ALTER PROCEDURE`.
3.  **[Medium]** What is the purpose of `SET NOCOUNT ON` at the beginning of a stored procedure?
    *   **Answer:** It prevents SQL Server from sending the "done message" (e.g., "(1 row affected)") back to the client for each DML statement executed within the procedure. This reduces network traffic and can improve performance, especially for procedures with many statements or those called frequently in loops.
4.  **[Medium]** Can a stored procedure call another stored procedure? Can it call itself (recursion)?
    *   **Answer:** Yes, stored procedures can call other stored procedures. Yes, stored procedures can also call themselves recursively, but care must be taken to ensure a base case exists to terminate the recursion and avoid exceeding the maximum nesting level (default 32).
5.  **[Medium]** What is a Table-Valued Parameter (TVP), and why is it useful?
    *   **Answer:** A TVP is a user-defined table type that can be used as a parameter for stored procedures (or functions). It allows passing multiple rows of data from a client application or another T-SQL batch into the procedure as a single, structured parameter. This is much more efficient than passing multiple individual parameters or using comma-delimited strings for bulk data operations.
6.  **[Medium]** When executing a procedure with output parameters, what keyword must the caller use?
    *   **Answer:** The `OUTPUT` (or `OUT`) keyword must be specified after the variable receiving the output value in the `EXECUTE` statement (e.g., `EXEC MyProc @Input = 1, @OutputVar = @MyVariable OUTPUT;`).
7.  **[Hard]** What is the difference between `RAISERROR` and `THROW` for signaling errors within a stored procedure? Which is generally preferred in modern SQL Server versions?
    *   **Answer:**
        *   `RAISERROR`: Older syntax for raising custom errors. Has complex parameter formatting for message IDs, severity, state, and arguments. Does not automatically respect `TRY...CATCH` boundaries in all cases (depending on severity).
        *   `THROW`: Newer syntax (SQL Server 2012+) for raising errors. Simpler syntax. When used *without* parameters inside a `CATCH` block, it re-throws the original error that caused execution to jump to `CATCH`. When used *with* parameters (error number, message, state), it raises a new error. It respects `TRY...CATCH` blocks properly, transferring control immediately to the `CATCH` block.
        *   **Preference:** `THROW` is generally preferred in modern SQL Server versions (2012+) due to its simpler syntax and better integration with `TRY...CATCH` error handling.
8.  **[Hard]** What are some potential risks of using dynamic SQL within stored procedures, and how can `sp_executesql` help mitigate one of them?
    *   **Answer:**
        *   **Risks:** The primary risk is **SQL Injection** if input parameters are directly concatenated into the dynamic SQL string without proper validation or quoting. Other risks include potential performance issues due to plan caching difficulties (though `sp_executesql` helps) and increased complexity in debugging.
        *   **`sp_executesql` Mitigation:** `sp_executesql` allows the dynamic SQL string to contain parameter markers (like `@ParamName`) and accepts separate arguments for the parameter definitions and their values. This allows the query plan for the parameterized dynamic string to be cached and reused, improving performance. More importantly, it helps prevent SQL injection because the parameter *values* are passed separately and are not directly embedded into the SQL string being executed, treating them as data rather than executable code.
9.  **[Hard]** What does the `WITH RECOMPILE` option do when creating or executing a stored procedure? When might you use it?
    *   **Answer:** The `WITH RECOMPILE` option forces SQL Server to generate a *new* execution plan for the stored procedure (or specific statement if used with `OPTION(RECOMPILE)`) *every time* it is executed, instead of using a potentially cached plan. You might use it when:
        *   Parameter sniffing is causing significant performance problems, and the optimal plan varies greatly depending on the input parameters (and other solutions like `OPTIMIZE FOR` are insufficient).
        *   The underlying data distribution changes frequently, making cached plans quickly become suboptimal.
        *   The procedure is run infrequently, and the cost of recompilation is negligible compared to the benefit of getting an optimal plan for the current parameters/data state.
    *   The main drawback is the increased CPU overhead of recompilation on every execution.
10. **[Hard/Tricky]** If a stored procedure uses `SET NOCOUNT ON` and performs an `INSERT` statement, will `SCOPE_IDENTITY()` still return the correct identity value generated by that `INSERT`?
    *   **Answer:** Yes. `SET NOCOUNT ON` only suppresses the "rows affected" messages sent to the client. It does not affect the functionality of functions like `SCOPE_IDENTITY()`, `@@IDENTITY`, or `IDENT_CURRENT()`, which retrieve identity values generated within their respective scopes or for specific tables. `SCOPE_IDENTITY()` will still correctly return the last identity value inserted within the current scope (the stored procedure) by that `INSERT` statement.
