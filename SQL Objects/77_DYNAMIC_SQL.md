# SQL Deep Dive: Dynamic SQL

## 1. Introduction: What is Dynamic SQL?

**Dynamic SQL** refers to the practice of constructing T-SQL statements as strings within your code (e.g., in stored procedures, functions, or scripts) and then executing those strings using commands like `EXECUTE` (or `EXEC`) or the system stored procedure `sp_executesql`. This allows you to build queries where parts of the SQL statement itself (like table names, column names, filter conditions, or sort orders) are determined at runtime based on parameters or other conditions.

**Why use Dynamic SQL?**

*   **Flexibility:** Enables building highly flexible queries where the structure isn't known until runtime. Essential for features like dynamic reporting tools, advanced search screens with variable criteria, or administrative tasks operating on dynamically specified objects.
*   **Generality:** Allows creating generic procedures that can operate on different tables or columns based on input parameters.

**Why be Cautious?**

*   **SQL Injection Risk:** The **biggest danger** of dynamic SQL is SQL injection vulnerability. If user input is directly concatenated into the SQL string without proper sanitization or parameterization, malicious users can inject harmful SQL code that gets executed with the privileges of the executing user/procedure.
*   **Performance:** Can hinder performance due to:
    *   **Plan Caching Issues:** Simple `EXEC(@SQL)` often leads to poor plan reuse because each variation of the SQL string might be treated as a different query, causing excessive compilations. `sp_executesql` with parameters mitigates this significantly.
    *   **Optimizer Challenges:** The optimizer has less information available at compile time when parts of the query are dynamic.
*   **Debugging & Maintainability:** Dynamically generated SQL can be harder to debug, read, and maintain than static SQL.
*   **Permissions:** Requires careful management, as the executing context needs permissions for the actions within the dynamic string.

**Key Execution Methods:**

1.  `EXECUTE (@SQLString)` or `EXEC (@SQLString)`: Simple execution of a SQL string. Prone to SQL injection if `@SQLString` includes unvalidated input. Poor plan caching.
2.  `sp_executesql @SQLString, N'@ParamDef', @Param1 = @Value1, ...`: **Preferred method.** Executes a SQL string with parameters.
    *   Allows parameterization, which **prevents SQL injection** for parameter values.
    *   Promotes **plan cache reuse**, improving performance.

## 2. Dynamic SQL in Action: Analysis of `77_DYNAMIC_SQL.sql`

This script demonstrates various aspects of dynamic SQL.

**Part 1: Fundamentals**

*   **1. Basic `EXEC`:** Shows simple string concatenation and execution. **Highlights the risk** if `@ColumnList` came from user input.
    ```sql
    SET @SQL = 'SELECT ' + @ColumnList + ' FROM HR.Employees ...'; EXEC(@SQL);
    ```
*   **2. `sp_executesql`:** Demonstrates the safer, parameterized approach. User input (`@DepartmentID`) is passed as a parameter, not concatenated into the string.
    ```sql
    SET @SQLParam = N'SELECT ... FROM HR.Employees WHERE DepartmentID = @DeptID ...';
    EXEC sp_executesql @SQLParam, N'@DeptID INT', @DeptID = @DepartmentID;
    ```

**Part 2: Dynamic Reporting**

*   **`HR.GenerateEmployeeReport` Procedure:** Creates a stored procedure that dynamically builds a `SELECT` statement based on input parameters for columns to select (`@Columns`), sorting (`@SortColumn`, `@SortDirection`), and optional filtering (`@DepartmentID`, `@Status`). Uses `sp_executesql` for safe execution with parameters for filter values.
    *   **Note:** Column names and sort columns are still concatenated, requiring validation or careful handling if they originate from user input (though less common than filter *values*).

**Part 3: Dynamic Search and Filtering**

*   **`HR.SearchEmployees` Procedure:** Creates a procedure for searching across multiple specified fields (`@SearchFields`) for a given value (`@SearchValue`), with optional additional filter criteria (`@FilterCriteria`).
    *   Dynamically builds the `WHERE` clause based on the comma-separated `@SearchFields` list, creating multiple `LIKE` conditions combined with `OR`.
    *   Appends the optional `@FilterCriteria` string.
    *   Uses `sp_executesql` to execute, passing the `@SearchValue` (wrapped in `%`) as a parameter to prevent injection through the search term.
    *   **Caution:** Concatenating `@SearchFields` and `@FilterCriteria` directly still carries risks if these strings come from untrusted sources. Validation or whitelisting of allowed field names/filter patterns would be needed in a real application.

**Part 4: Security Considerations**

*   **1. SQL Injection Prevention:** Explicitly contrasts unsafe string concatenation (`'...' + @UserInput + '...'`) with the safe use of `sp_executesql` and parameters (`WHERE LastName = @LastName`). **Emphasizes using `sp_executesql`**.
*   **2. Permission Validation:** Shows a conceptual procedure (`HR.ExecuteDynamicQuery`) that checks if the *current user* has a specific required permission (`fn_my_permissions`) *before* executing the dynamic SQL passed to it. This adds a layer of safety, ensuring the dynamic code doesn't run with unintended privileges.

**Part 5: Performance Optimization**

*   **1. Plan Caching:** Contrasts `EXEC` (poor plan reuse) with `sp_executesql` (good plan reuse due to parameterization) for queries where only parameter values change.
*   **2. Dynamic Index Hints:** Shows a procedure (`HR.GetEmployeesWithIndexHint`) that dynamically adds an `INDEX` hint to a query based on the column being searched. **Use index hints with extreme caution**, as they override the optimizer and can hurt performance if the data or query patterns change.

**Part 6: Best Practices**

*   **1. Error Handling:** Wraps dynamic SQL execution in `TRY...CATCH` blocks to handle potential errors gracefully, log them, and potentially re-throw.
*   **2. Code Organization:** Suggests storing dynamic query templates (e.g., in a configuration table) and using wrapper procedures (`HR.GenerateReport`) to build and execute them, separating the dynamic logic from the core application code.

## 3. Targeted Interview Questions (Based on `77_DYNAMIC_SQL.sql`)

**Question 1:** What is the primary security risk associated with using dynamic SQL, and how does `sp_executesql` help mitigate it compared to `EXEC()`?

**Solution 1:**

*   **Primary Risk:** **SQL Injection**. If user-supplied input is directly concatenated into a dynamic SQL string without proper validation or sanitization, an attacker can inject malicious SQL commands (like `DROP TABLE`, or queries to steal data) that get executed by the database.
*   **`sp_executesql` Mitigation:** `sp_executesql` allows you to pass user input as **parameters** rather than concatenating it into the main SQL string. The database engine treats these parameters strictly as data values, not as executable code, effectively preventing SQL injection through those parameters. `EXEC()` does not inherently support parameterization in the same way, making it much more vulnerable if used with concatenated user input.

**Question 2:** In the `HR.GenerateEmployeeReport` procedure, the `@Columns`, `@SortColumn`, and `@SortDirection` parameters are concatenated directly into the SQL string. Is this safe? If not, how could it be made safer?

**Solution 2:** It is **not inherently safe** if those parameter values could originate from direct, unvalidated user input. While less common than injecting filter *values*, an attacker could potentially inject harmful code or manipulate the query structure via these parameters (e.g., `@SortColumn = 'Salary; DROP TABLE HR.Employees;--'`).
*   **Making it Safer:**
    1.  **Whitelisting:** The best approach is to validate the input values against a predefined list of allowed column names and sort directions. If the input doesn't match an allowed value, reject it or use a default.
    2.  **`QUOTENAME()`:** Use the `QUOTENAME()` function around column/object names being concatenated (e.g., `ORDER BY ' + QUOTENAME(@SortColumn) + ' ...'`). This adds brackets (`[]`) around the name, preventing injection attacks that try to terminate the string or add extra commands, although it doesn't validate if the column name itself is valid.
    3.  **Metadata Check:** Query `sys.columns` to verify that `@Columns` and `@SortColumn` actually exist in the target table(s) before concatenating them.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which command is generally preferred for executing dynamic SQL with parameters: `EXEC` or `sp_executesql`?
    *   **Answer:** `sp_executesql`.
2.  **[Easy]** Can you use dynamic SQL to specify the name of the table you want to query?
    *   **Answer:** Yes (e.g., `SET @SQL = 'SELECT * FROM ' + @TableName; EXEC(@SQL);`), but this requires careful validation of `@TableName` to prevent injection.
3.  **[Medium]** Why does using `sp_executesql` with parameters generally lead to better execution plan reuse compared to `EXEC()` with concatenated values?
    *   **Answer:** `sp_executesql` allows SQL Server to recognize that the *structure* of the query string is the same, even if the parameter *values* change between executions. It can then cache and reuse the execution plan generated for that query structure, substituting the different parameter values at runtime. `EXEC()` with concatenated strings often results in slightly different SQL text for each execution (due to different literal values), causing SQL Server to treat them as distinct queries requiring separate compilation and caching, leading to plan cache bloat and reduced performance.
4.  **[Medium]** Can you declare variables *inside* a dynamic SQL string executed with `EXEC()` or `sp_executesql`?
    *   **Answer:** Yes, the string passed to `EXEC()` or `sp_executesql` can contain its own T-SQL batch, including variable declarations, control flow statements, etc. These variables exist only within the scope of that dynamic execution.
5.  **[Medium]** If you build a dynamic SQL string, how can you see the exact command that will be executed before running `EXEC` or `sp_executesql`?
    *   **Answer:** Use the `PRINT` statement (e.g., `PRINT @SQL;`) before the `EXEC`/`sp_executesql` call. This will output the generated SQL string to the messages tab in SSMS, allowing you to inspect it for correctness and potential issues. Be aware of length limitations for `PRINT` (8000 bytes for `VARCHAR`, 4000 for `NVARCHAR`); for very long strings, you might need to print in chunks or select the variable.
6.  **[Medium]** Can dynamic SQL be used inside a User-Defined Function (UDF)?
    *   **Answer:** No. Standard T-SQL UDFs (scalar and multi-statement table-valued) are not allowed to execute dynamic SQL (`EXEC` or `sp_executesql`) or perform actions that modify database state. Inline table-valued functions have more restrictions. Dynamic SQL is typically used within stored procedures or ad-hoc batches.
7.  **[Hard]** Besides SQL injection, what is another potential security risk if dynamic SQL grants excessive permissions (e.g., if built inside a procedure owned by `dbo` that executes using `EXECUTE AS OWNER`)?
    *   **Answer:** **Privilege Escalation**. If a procedure using dynamic SQL runs under a high-privilege context (like `dbo` via `EXECUTE AS OWNER` or `EXECUTE AS SELF` for a `dbo` member), and the dynamic SQL string can be manipulated (even slightly) by a lower-privileged user calling the procedure, the injected or manipulated code within the dynamic string might execute with the elevated privileges of the procedure's context, allowing the user to perform actions they wouldn't normally be permitted to do.
8.  **[Hard]** How can you safely include a dynamic list of values (e.g., a list of IDs provided as a comma-separated string parameter) in the `IN` clause of a dynamic query without risking SQL injection?
    *   **Answer:** Direct concatenation is unsafe. Safe methods include:
        1.  **Table-Valued Parameters (TVPs):** (Preferred) Define a user-defined table type, pass the list of values as a TVP to the stored procedure, and join the base table with the TVP variable in the (potentially dynamic, but now safer) query.
        2.  **String Splitting Function:** Pass the comma-separated string. Inside the dynamic SQL or procedure, use a reliable string-splitting function (like `STRING_SPLIT` in modern SQL Server, or a custom one) to convert the string into a table of values, then join with that table.
        3.  **XML Parameter:** Pass the list as XML, parse it within the procedure/dynamic SQL using XQuery into a table format, and join.
        4.  **JSON Parameter:** (SQL 2016+) Pass the list as a JSON array, parse it using `OPENJSON`, and join.
9.  **[Hard]** Can `sp_executesql` return output parameters back to the calling batch?
    *   **Answer:** Yes. You can define parameters as `OUTPUT` in both the parameter definition string (`@ParamDef`) and when passing the parameter variable to `sp_executesql`. The value assigned to the output parameter within the dynamic SQL string will be available in the variable after `sp_executesql` completes.
        ```sql
        DECLARE @SQL NVARCHAR(MAX), @Count INT;
        SET @SQL = N'SELECT @RecCount = COUNT(*) FROM HR.Employees WHERE DepartmentID = @DeptID;';
        EXEC sp_executesql @SQL, N'@DeptID INT, @RecCount INT OUTPUT', @DeptID = 1, @RecCount = @Count OUTPUT;
        SELECT @Count; -- Contains the count
        ```
10. **[Hard/Tricky]** If you use `sp_executesql` to execute a batch that contains `GO` statements, what will happen?
    *   **Answer:** It will result in an error. `GO` is not a T-SQL statement; it's a batch separator recognized only by SQL Server client utilities like SSMS, `sqlcmd`, and `osql`. The `sp_executesql` procedure executes a T-SQL batch string, and `GO` is invalid syntax within that context. If you need to execute multiple batches dynamically, you would typically need to call `sp_executesql` multiple times, once for each logical batch.
