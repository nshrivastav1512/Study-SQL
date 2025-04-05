# SQL Deep Dive: Table Variables vs. Temporary Tables

## 1. Introduction: Temporary Data Storage

In T-SQL development, you often need temporary storage to hold intermediate results, process data in stages, or pass structured data between procedures. SQL Server provides two primary mechanisms for this: **Table Variables** and **Temporary Tables**. While they serve similar purposes, they have significant differences in scope, features, performance characteristics, and logging behavior.

**Table Variables (`DECLARE @MyTable TABLE (...)`)**

*   Declared using `DECLARE`.
*   Scope is limited to the batch, stored procedure, or function in which they are declared. They are automatically cleaned up when the scope ends.
*   Stored primarily in memory (though can spill to `tempdb` under pressure).
*   Limited indexing capabilities (only PRIMARY KEY and UNIQUE constraints, which implicitly create indexes, allowed *within the DECLARE statement* in most versions; no explicit `CREATE INDEX` allowed after declaration).
*   Do not maintain statistics (or very limited statistics in newer versions), which can sometimes lead to poor query plan choices when joined with large tables.
*   Participate fully in transactions (operations are logged).
*   Cannot be targets of `TRUNCATE TABLE`.
*   Cannot be used as parameters directly in dynamic SQL executed via `EXEC()`, but can be used with `sp_executesql` if passed correctly.
*   Often preferred for smaller datasets or when passing structured data as parameters (Table-Valued Parameters are based on table variables).

**Temporary Tables (`CREATE TABLE #MyTempTable (...)`)**

*   Created using `CREATE TABLE` with a `#` prefix (local temp table) or `##` prefix (global temp table).
*   **Local (`#`)**: Visible only within the session (connection) that created it. Automatically dropped when the session ends or explicitly dropped. Can be accessed by nested stored procedures called within the same session.
*   **Global (`##`)**: Visible to *all* sessions. Dropped automatically only when the creating session ends *and* no other sessions are actively referencing it. Use with caution due to potential naming conflicts and broader scope.
*   Physically created in the `tempdb` database.
*   Support full indexing capabilities (`CREATE INDEX`, constraints).
*   Maintain statistics, allowing the query optimizer to make better cardinality estimates.
*   Operations are logged (though potentially less than table variables for certain operations if `tempdb` is in SIMPLE recovery model).
*   Can be targets of `TRUNCATE TABLE`.
*   Can be referenced in dynamic SQL executed via `EXEC()`.
*   Generally preferred for larger datasets, complex processing requiring indexes or statistics, or when data needs to persist across multiple procedure calls within the same session.

## 2. Table Variables vs. Temp Tables in Action: Analysis of `101_TABLE_VARIABLES_TEMP_TABLES.sql`

This script demonstrates the creation, population, scope, and use cases for both types.

**Part 1: Basic Table Variable Usage**

```sql
DECLARE @EmployeeUpdates TABLE (EmployeeID INT, ...); -- Declaration
INSERT INTO @EmployeeUpdates VALUES (1, ...); -- Single row insert
INSERT INTO @EmployeeUpdates SELECT ... FROM HR.Employees WHERE ...; -- Multi-row insert
-- @EmployeeUpdates goes out of scope and is cleaned up at the end of the batch/procedure
```

*   **Explanation:** Shows the basic syntax for declaring a table variable and populating it using standard `INSERT` statements.

**Part 2: Temporary Table Usage**

```sql
-- Create local temp table with an index
CREATE TABLE #EmployeeTemp (EmployeeID INT, ..., INDEX IX_EmployeeID (EmployeeID));
INSERT INTO #EmployeeTemp SELECT ... FROM HR.Employees WHERE ...;
-- #EmployeeTemp persists until the session ends or it's explicitly dropped
-- DROP TABLE #EmployeeTemp; (Needed for cleanup if session continues)
```

*   **Explanation:** Creates a local temporary table (`#EmployeeTemp`) stored in `tempdb`. Demonstrates creating an index directly within the `CREATE TABLE` statement (or could use `CREATE INDEX` afterwards).

**Part 3: Scope and Visibility**

*   **Table Variable Scope:** Creates a procedure (`HR.DemoTableVariableScope`) where a table variable (`@DeptEmployees`) is declared, populated, and selected from. The comment correctly notes it's only visible *within* that procedure. It cannot be accessed by other procedures called from it or after the procedure finishes.
*   **Temp Table Scope:** Creates a procedure (`HR.DemoTempTableScope`) that creates a local temp table (`#DeptSummary`). It then calls another (hypothetical) procedure (`HR.ProcessDeptSummary`) which *could* access `#DeptSummary` because it's called within the same session. The temp table must be explicitly dropped at the end of the procedure if it's not needed further in the session.

**Part 4: Performance Considerations**

*   Reiterates that table variables are often better for *small* datasets due to less overhead (no `tempdb` contention for creation, fewer statistics/recompilation issues).
*   Shows creating a temp table (`#LargeDataset`) for a *large* dataset, highlighting the ability to add indexes, which is crucial for performance when joining or filtering large amounts of temporary data.

**Part 5: Common Use Cases**

*   **Table Variable (Parameter Lists):** Shows using a table variable (`@SelectedDepts`) to hold a list of IDs used later in a `JOIN` condition – a common alternative to comma-delimited strings or complex `OR` conditions. Table variables are the basis for Table-Valued Parameters (TVPs).
*   **Temp Table (Staging Data):** Demonstrates using a temp table (`#StagingEmployees`) as an intermediate staging area. Data is loaded, validated (using an `UPDATE` to mark invalid rows), and potentially transformed before being loaded into a final destination table. Temp tables are well-suited for multi-step ETL processes within a session.

**Part 6: Best Practices and Tips**

*   Summarizes when to choose each type based on dataset size, need for indexes/statistics, scope requirements, and transaction logging needs (though logging differences are often minor unless dealing with `tempdb` in SIMPLE recovery and specific operations).
*   Emphasizes monitoring and cleanup, especially for temp tables.

## 3. Targeted Interview Questions (Based on `101_TABLE_VARIABLES_TEMP_TABLES.sql`)

**Question 1:** What is the main difference in scope between a table variable (`DECLARE @T TABLE`) and a local temporary table (`CREATE TABLE #T`)?

**Solution 1:**
*   **Table Variable:** Scope is limited to the current batch, stored procedure, or function in which it is declared. It cannot be accessed outside of that scope (e.g., by called procedures or after the batch/procedure ends).
*   **Local Temporary Table:** Scope is limited to the current session (connection). It *can* be accessed by nested stored procedures called within the same session. It persists until the session ends or it is explicitly dropped.

**Question 2:** If you need to store a large amount of data (e.g., > 10,000 rows) temporarily and perform efficient joins or filtering on it, which would you generally choose: a table variable or a temporary table? Why?

**Solution 2:** You would generally choose a **temporary table (`#temp`)**.
*   **Why:** Temporary tables support the creation of explicit indexes (`CREATE INDEX`) and maintain statistics. For large datasets, indexes are crucial for efficient joins and filtering. The query optimizer can use the statistics on temp tables to generate better execution plans. Table variables have very limited indexing and statistics capabilities, which often leads to poor performance (e.g., table scans) when dealing with large amounts of data or complex joins.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which object type is physically created in the `tempdb` database: table variables or temporary tables?
    *   **Answer:** Temporary tables (`#temp`, `##global`). (Table variables primarily reside in memory but *can* spill to `tempdb` under memory pressure).
2.  **[Easy]** Can you create a non-clustered index on a table variable *after* it has been declared?
    *   **Answer:** No. Indexes (other than PRIMARY KEY or UNIQUE constraints defined inline during declaration) cannot be explicitly created on table variables after they are declared.
3.  **[Medium]** Do operations on table variables participate in user transactions (can they be rolled back)? What about temporary tables?
    *   **Answer:** Yes, operations on **both** table variables and temporary tables participate fully in user transactions. If a transaction containing modifications to either type is rolled back, the changes to the table variable or temporary table are undone.
4.  **[Medium]** Can a table variable be passed as a parameter to a stored procedure?
    *   **Answer:** Yes, but only if it's declared as a **Table-Valued Parameter (TVP)**. This requires creating a user-defined table type (`CREATE TYPE`) first, then declaring the procedure parameter and the variable using that type, and passing the variable marked as `READONLY`. You cannot pass a standard `DECLARE @T TABLE (...)` variable directly.
5.  **[Medium]** What happens to a local temporary table (`#temp`) when the stored procedure that created it finishes execution?
    *   **Answer:** The local temporary table **persists** and is still accessible within the session that called the stored procedure. It is only automatically dropped when the *session* ends (or if dropped explicitly).
6.  **[Medium]** Can you use `TRUNCATE TABLE` on a table variable? Can you use it on a temporary table?
    *   **Answer:** You **cannot** use `TRUNCATE TABLE` on a table variable (must use `DELETE`). You **can** use `TRUNCATE TABLE` on a temporary table (`#temp` or `##global`).
7.  **[Hard]** Why might the query optimizer sometimes generate suboptimal execution plans when joining a table variable to other tables, especially if the table variable contains many rows?
    *   **Answer:** Because table variables (especially in older SQL Server versions) do not have distribution statistics maintained on them (or have very limited statistics). The query optimizer often assumes a table variable contains only **one row**, regardless of its actual size. This fixed estimate can lead to poor plan choices, such as nested loop joins where a hash or merge join might be more appropriate if the actual row count is large. (Newer versions have improved cardinality estimation for table variables somewhat, but temp tables still generally provide better statistics).
8.  **[Hard]** What is a global temporary table (`##global`), and how does its scope differ from a local temporary table (`#local`)? When might you use one (cautiously)?
    *   **Answer:**
        *   **Global Temporary Table (`##`):** Visible to *all* sessions and users currently connected to the SQL Server instance. It persists until the session that *created* it disconnects *and* all other sessions have stopped referencing it.
        *   **Local Temporary Table (`#`):** Visible only to the *creating session*.
        *   **Use Case:** Global temp tables are rarely needed. A potential (but often discouraged) use case might be for sharing intermediate data between completely separate sessions/processes briefly, but they introduce potential naming conflicts and make cleanup harder to manage. Standard tables or other sharing mechanisms are usually preferred.
9.  **[Hard]** Can creating many temporary tables frequently cause contention in `tempdb`? What kind of contention?
    *   **Answer:** Yes. Frequent creation and dropping of temporary tables can cause metadata contention within `tempdb` on system tables used to track object creation/destruction. More significantly, it can cause **allocation contention** on specific `tempdb` data file pages like PFS (Page Free Space), GAM (Global Allocation Map), and SGAM (Shared Global Allocation Map) pages, especially under high concurrency. SQL Server has introduced optimizations (like caching temporary objects and using multiple `tempdb` data files) to mitigate this, but heavy `tempdb` usage from temp tables can still be a bottleneck.
10. **[Hard/Tricky]** If you declare a table variable inside a function (scalar or multi-statement table-valued function), can that function still be used in parallel execution plans?
    *   **Answer:** Generally, no. Multi-statement table-valued functions (MSTVFs), which are often used when table variables are needed for complex logic within a function, typically prevent parallelism in the execution plan that calls them. SQL Server often estimates only 1 row (or 100 in newer versions) will be returned by an MSTVF, hindering parallel plan generation. Inline table-valued functions (ITVFs) are usually better for performance and parallelism but have limitations on the complexity of statements allowed (essentially a single `SELECT`). While you *can* declare a table variable in a scalar function, scalar functions themselves executed row-by-row can also inhibit parallelism.
