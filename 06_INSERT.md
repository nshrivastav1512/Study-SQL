# SQL Deep Dive: The `INSERT` Statement

## 1. Introduction: What is `INSERT`?

The `INSERT` statement is a fundamental **Data Manipulation Language (DML)** command in SQL. Its primary purpose is to **add new rows (records) of data into a table**. Without `INSERT`, you can create structures (`CREATE`) and modify them (`ALTER`), but you can't populate your database with information.

**Key Characteristics:**

*   **Adding Data:** The core function is to introduce new data points into your tables.
*   **Row-Based:** Operates on a row-by-row basis, adding complete records.
*   **Flexibility:** Supports inserting single rows, multiple rows explicitly defined, or rows resulting from a query (`SELECT`).
*   **Constraint Adherence:** `INSERT` operations must comply with all constraints defined on the table (e.g., `NOT NULL`, `UNIQUE`, `CHECK`, `FOREIGN KEY`). Violating a constraint will typically cause the `INSERT` statement to fail.
*   **Defaults:** Can utilize `DEFAULT` values defined for columns if a value isn't explicitly provided for that column during the insert.
*   **Identity & Computed Columns:** Interacts with special column types like `IDENTITY` (auto-incrementing) and computed columns.
*   **Logging:** `INSERT` operations are fully logged in the transaction log, allowing for rollback and recovery.

**General Syntax:**

There are several common forms:

1.  **Inserting Explicit Values (Single or Multiple Rows):**
    ```sql
    INSERT INTO table_name (column1, column2, ...)
    VALUES (value1, value2, ...),
           (valueA, valueB, ...); -- Optional second row
    ```
    *(The column list is optional if providing values for *all* columns in their defined order, but explicitly listing columns is best practice).*

2.  **Inserting Results of a Query:**
    ```sql
    INSERT INTO table_name (column1, column2, ...)
    SELECT expression1, expression2, ...
    FROM source_table
    WHERE condition;
    ```

3.  **Inserting Default Values:**
    ```sql
    INSERT INTO table_name DEFAULT VALUES;
    ```
    *(Inserts a row using default values for all columns that have them. Fails if any column without a default is non-nullable).*

## 2. `INSERT` in Action: Analysis of `06_INSERT.sql`

This script showcases the versatility of the `INSERT` statement.

**a) Basic `INSERT` Operations**

```sql
-- Single Row
INSERT INTO HR.Departments (DepartmentName, LocationID) VALUES ('Research & Development', 1);

-- Multi-Row (using VALUES clause multiple times)
INSERT INTO HR.Locations (City, State, Country) VALUES
    ('Seattle', 'Washington', 'USA'),
    ('London', NULL, 'UK'),
    ('Mumbai', 'Maharashtra', 'India');

-- Using DEFAULT keyword for HireDate and relying on default for CreatedDate
INSERT INTO HR.EMP_Details (FirstName, LastName, Email, HireDate, DepartmentID, Salary)
VALUES ('John', 'Doe', 'john.doe@hr.com', DEFAULT, 1, 50000);
```

*   **Explanation:** Demonstrates inserting a single row, multiple rows using the `VALUES` clause constructor, handling `NULL` values explicitly, and utilizing the `DEFAULT` keyword (for `HireDate`) or implicitly relying on column defaults (`CreatedDate` in `EMP_Details`).

**b) `INSERT INTO ... SELECT`**

```sql
-- Basic: Insert salary history based on current salaries
INSERT INTO PAYROLL.Salary_History (EmployeeID, OldSalary, NewSalary, EffectiveDate)
SELECT EmployeeID, Salary, Salary * 1.1, GETDATE()
FROM HR.EMP_Details WHERE DepartmentID = 1;

-- With JOIN: Insert performance reviews based on employee/department info
INSERT INTO HR.Performance_Reviews (EmployeeID, ReviewDate, Rating, ReviewedBy)
SELECT e.EmployeeID, GETDATE(), 4, d.ManagerID
FROM HR.EMP_Details e JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID;
```

*   **Explanation:** A powerful way to populate tables based on existing data. The `SELECT` statement retrieves data (potentially transforming it, like `Salary * 1.1`), and the results are inserted into the target table. The column list in the `INSERT` must match the columns produced by the `SELECT`.

**c) `INSERT` with `OUTPUT` Clause**

```sql
-- Basic: Output inserted values directly
INSERT INTO HR.Locations (City, State, Country)
OUTPUT inserted.LocationID, inserted.City, inserted.Country
VALUES ('Tokyo', NULL, 'Japan');

-- Output into a Table Variable: Capture inserted data for later use
DECLARE @InsertedEmployees TABLE (...);
INSERT INTO HR.EMP_Details (...)
OUTPUT inserted.EmployeeID, inserted.FirstName + ' ' + inserted.LastName, GETDATE()
INTO @InsertedEmployees
VALUES (...);
```

*   **Explanation:** The `OUTPUT` clause is extremely useful for retrieving information about the rows affected by an `INSERT` (or `UPDATE`, `DELETE`, `MERGE`) statement.
    *   `inserted.*`: Accesses columns from the rows *after* the insert (including computed values and identity values).
    *   `OUTPUT ...`: Returns the specified columns as a result set.
    *   `OUTPUT ... INTO @TableVariable`: Captures the output into a declared table variable or temporary table for auditing, confirmation messages, or further processing within the same batch/procedure.

**d) `INSERT` with `EXECUTE` (Dynamic SQL)**

```sql
DECLARE @TableName NVARCHAR(100) = 'HR.Departments';
DECLARE @SQL NVARCHAR(MAX);
SET @SQL = N'INSERT INTO ' + @TableName + ...;
EXECUTE sp_executesql @SQL, N'@Name ..., @LocID ...', @Name = ..., @LocID = ...;
```

*   **Explanation:** Allows constructing `INSERT` statements dynamically, often used when the table name or columns are determined at runtime. `sp_executesql` is generally preferred over basic `EXEC()` for dynamic SQL as it allows parameterization, improving performance (plan caching) and security (reducing SQL injection risk).

**e) `INSERT` with Table Value Constructor (`VALUES`)**

```sql
INSERT INTO HR.TrainingCourses (CourseID, CourseName)
SELECT CourseID, CourseName
FROM (VALUES (2, '...'), (3, '...'), (4, '...')) AS Courses(CourseID, CourseName);
```

*   **Explanation:** Uses the `VALUES` clause as if it were a derived table within a `SELECT` statement. This provides a concise way to insert multiple, explicitly defined rows, especially when combined with `INSERT INTO ... SELECT`.

**f) `INSERT` with `TOP`**

```sql
INSERT TOP(5) INTO HR.Performance_Reviews (...)
SELECT EmployeeID, GETDATE(), 5, 1000
FROM HR.EMP_Details WHERE ReviewDate IS NULL;
```

*   **Explanation:** Inserts only the specified number (`TOP(5)`) or percentage (`TOP(5) PERCENT`) of rows returned by the `SELECT` statement. The order of rows selected by `TOP` without an `ORDER BY` in the subquery is not guaranteed.

**g) `INSERT` into Partitioned Table**

```sql
INSERT INTO HR.PartitionedEmployees (...) VALUES (...), (...);
```

*   **Explanation:** Inserting into a partitioned table looks like inserting into a regular table. SQL Server automatically routes the inserted row to the correct partition based on the value of the partitioning key (`EmployeeID` in this case) and the partition function definition.

**h) `INSERT` with `IDENTITY_INSERT`**

```sql
SET IDENTITY_INSERT HR.EMP_Details ON; -- Allow explicit values for identity column
INSERT INTO HR.EMP_Details (EmployeeID, ...) VALUES (9999, ...); -- Provide specific EmployeeID
SET IDENTITY_INSERT HR.EMP_Details OFF; -- Turn setting off (IMPORTANT!)
```

*   **Explanation:** By default, you cannot provide a value for an `IDENTITY` column; SQL Server generates it. `SET IDENTITY_INSERT TableName ON` temporarily overrides this, allowing you to insert explicit values into the identity column (e.g., for data migration, restoring specific IDs). You *must* explicitly list the identity column in the `INSERT` statement's column list when this setting is `ON`. It's crucial to `SET IDENTITY_INSERT OFF` afterward, as only one table per session can have this setting `ON`.

**i) `SELECT ... INTO` (Creating New Table)**

```sql
SELECT EmployeeID, FirstName, LastName, Salary
INTO #HighPaidEmployees -- Creates a NEW table #HighPaidEmployees
FROM HR.EMP_Details
WHERE Salary > 70000;
```

*   **Explanation:** This is *not* an `INSERT` statement, but often discussed alongside it. `SELECT ... INTO` creates a *new* table (here, a temporary table `#HighPaidEmployees`) based on the structure and data returned by the `SELECT` query. It's a quick way to create a copy or subset of data in a new structure. The target table must *not* already exist.

**j) `INSERT` with `OPENROWSET` / `BULK INSERT` (Commented Out)**

```sql
/* INSERT ... SELECT ... FROM OPENROWSET(...) */
/* BULK INSERT HR.Locations FROM 'C:\Locations.csv' WITH (...) */
```

*   **Explanation:** These demonstrate methods for inserting data from external sources.
    *   `OPENROWSET`: A versatile function to access data from external OLE DB data sources (like Excel, other databases) as if it were a table. Requires specific permissions and configuration.
    *   `BULK INSERT`: A highly efficient T-SQL command specifically designed for importing large amounts of data from flat files (like CSV) into a table. Requires file system access permissions for the SQL Server service account. Often faster than `INSERT INTO SELECT` or SSIS for simple file imports.

**k) `INSERT` with Error Handling (`TRY...CATCH`)**

```sql
BEGIN TRY
    BEGIN TRANSACTION;
        -- Attempt potentially failing INSERT (e.g., violates FK, CHECK, UNIQUE)
        INSERT INTO HR.EMP_Details (...) VALUES (...invalid data...);
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; -- Roll back if error occurred
    -- Log the error
    INSERT INTO HR.AuditLog (...) VALUES ('Failed Insert', ...);
    THROW; -- Re-throw the original error
END CATCH;
```

*   **Explanation:** Demonstrates robust error handling. The `INSERT` is attempted within a `TRY` block and an explicit transaction. If any error occurs (like a constraint violation), execution jumps to the `CATCH` block. The `CATCH` block checks if the transaction is still active (`@@TRANCOUNT > 0`) and rolls it back to ensure atomicity, logs the failure, and then uses `THROW` to re-raise the original error so the calling application is aware of the problem.

## 3. Targeted Interview Questions (Based on `06_INSERT.sql`)

**Question 1:** Look at the `INSERT` statement in section 2.1 (`INSERT INTO PAYROLL.Salary_History ... SELECT ...`). What data is being inserted into the `OldSalary` and `NewSalary` columns of the history table?

**Solution 1:**

*   `OldSalary`: The *current* value of the `Salary` column from the `HR.EMP_Details` table for employees in `DepartmentID = 1` is being inserted into the `OldSalary` column.
*   `NewSalary`: A calculated value (`Salary * 1.1`, representing a 10% increase) based on the current salary from `HR.EMP_Details` is being inserted into the `NewSalary` column.

**Question 2:** The script uses `SET IDENTITY_INSERT HR.EMP_Details ON;` in section 8. Why is this necessary, and what must be done immediately after the `INSERT` statement that uses it?

**Solution 2:**

*   **Why Necessary:** It's necessary because the `INSERT` statement is attempting to provide an explicit value (`9999`) for the `EmployeeID` column, which is defined as an `IDENTITY` column in the `HR.EMP_Details` table. By default, SQL Server automatically generates values for identity columns and does not allow users to insert explicit values. `SET IDENTITY_INSERT ON` temporarily disables this automatic generation for the specified table, permitting the explicit insertion.
*   **What Must Be Done After:** Immediately after the `INSERT` statement that relies on this setting, you **must** execute `SET IDENTITY_INSERT HR.EMP_Details OFF;`. Only one table in a session can have `IDENTITY_INSERT` set to `ON` at any given time. Failing to turn it off prevents `IDENTITY_INSERT` from being enabled on other tables in the same session and leaves the table in a non-standard state where subsequent inserts (without specifying the ID) might fail or behave unexpectedly.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** If you `INSERT` a row into a table but omit a value for a nullable column that has no `DEFAULT` constraint, what value gets stored in that column for the new row?
    *   **Answer:** `NULL`. If a column allows `NULL`s and has no `DEFAULT` constraint, omitting it from the `INSERT` statement (or explicitly providing `NULL` in the `VALUES` clause) will result in `NULL` being stored.
2.  **[Easy]** What is the main difference between `INSERT INTO MyTable (...) SELECT ... FROM Source` and `SELECT ... INTO MyNewTable FROM Source`?
    *   **Answer:** `INSERT INTO ... SELECT` adds rows from the `SELECT` query into an *existing* table (`MyTable`). `SELECT ... INTO` creates a *new* table (`MyNewTable`) based on the structure and data of the `SELECT` query; the target table must *not* already exist.
3.  **[Medium]** Can the `OUTPUT` clause be used with an `INSERT ... EXEC` statement (where data comes from executing a stored procedure)?
    *   **Answer:** No. The `OUTPUT` clause cannot directly capture results when the source of the `INSERT` is the execution of a stored procedure (`INSERT INTO MyTable EXEC MyProcedure;`). To capture the output in this scenario, the stored procedure itself would need to return the data (e.g., via an `OUTPUT` parameter or a result set), or you would insert the procedure's results into a temporary table or table variable first, and then potentially use `OUTPUT` when inserting from that temporary storage into the final target.
4.  **[Medium]** You are inserting multiple rows using `INSERT INTO MyTable (ColA, ColB) VALUES (1, 'A'), (2, 'B'), (3, 'C');`. If the third row `(3, 'C')` violates a `UNIQUE` constraint on `ColA`, what happens to the first two rows `(1, 'A')` and `(2, 'B')`?
    *   **Answer:** The entire `INSERT` statement is atomic. If any single row within the multi-row `VALUES` clause violates a constraint, the *entire statement fails*, and **none** of the rows (including the valid first two rows) are inserted. The table remains unchanged from before the `INSERT` attempt.
5.  **[Medium]** What does `SCOPE_IDENTITY()` return after an `INSERT` statement, and how does it differ from `@@IDENTITY` and `IDENT_CURRENT('TableName')`?
    *   **Answer:**
        *   `SCOPE_IDENTITY()`: Returns the last identity value inserted into an identity column *within the current scope* (e.g., the current stored procedure, trigger, or batch). This is generally the **safest** function to use to get the ID you just inserted.
        *   `@@IDENTITY`: Returns the last identity value inserted across *any scope* in the current session. If your `INSERT` fired a trigger that also inserted into another table with an identity column, `@@IDENTITY` would return the ID from the trigger's insert, not your original insert. This makes it unreliable in the presence of triggers.
        *   `IDENT_CURRENT('TableName')`: Returns the last identity value generated for a *specific table*, regardless of scope or session. It's not session-specific, so if another user inserts into the table after you but before you check `IDENT_CURRENT`, you'll get their ID, not yours.
6.  **[Medium]** Can you use `INSERT INTO SELECT` to insert data into a table from itself? If so, what is a potential risk?
    *   **Answer:** Yes, you can insert into a table using data selected from the same table (e.g., `INSERT INTO MyLog (Message) SELECT Message + ' - Copied' FROM MyLog WHERE IsOriginal = 1;`). The main risk is creating an **infinite loop** if the `SELECT` criteria doesn't properly exclude the newly inserted rows from being selected in subsequent iterations (if the statement were part of a loop or recursive process). Even in a single statement, careful filtering is needed to ensure you're selecting only the intended source rows.
7.  **[Hard]** When using `BULK INSERT` or `bcp`, what does the `TABLOCK` hint typically do, and why is it often used for bulk load operations?
    *   **Answer:** The `TABLOCK` hint requests a table-level exclusive lock (`X`) for the duration of the bulk insert operation. This prevents other users from accessing the table while the bulk load is in progress. It's often used because:
        *   **Performance:** Holding a single table lock can be more efficient than acquiring and managing potentially millions of row or page locks.
        *   **Minimal Logging:** When combined with the `SIMPLE` or `BULK_LOGGED` recovery models, using `TABLOCK` enables minimally logged inserts, significantly reducing transaction log usage and improving performance. In `FULL` recovery, it doesn't guarantee minimal logging but can still offer performance benefits by reducing lock contention/overhead.
8.  **[Hard]** Can you insert data into a table that has a disabled non-clustered index? What about a disabled clustered index?
    *   **Answer:**
        *   **Disabled Non-Clustered Index:** Yes, you can insert data into a table even if it has one or more disabled non-clustered indexes. The disabled indexes are simply not maintained during the DML operation. You would need to rebuild them later to make them active again.
        *   **Disabled Clustered Index:** No, you **cannot** perform DML operations (including `INSERT`) on a table whose clustered index is disabled. A disabled clustered index makes the table data inaccessible. You must rebuild the clustered index before you can insert, update, delete, or select data from the table.
9.  **[Hard]** Consider inserting data into a table with a computed column. Do you need to provide a value for the computed column in your `INSERT` statement? Does it matter if the computed column is persisted?
    *   **Answer:** No, you generally **cannot** and **do not need** to provide a value for a computed column in an `INSERT` statement. The value is calculated automatically by SQL Server based on its definition. Attempting to insert an explicit value will result in an error. This applies whether the computed column is persisted or not. The difference with persisted columns is that the computed value is physically stored in the table (updated when dependencies change), potentially improving read performance but adding storage overhead and slight write overhead. Non-persisted columns are calculated only when queried.
10. **[Hard/Tricky]** You are using `INSERT INTO TargetTable (...) SELECT ... FROM SourceTable`. `SourceTable` has 1 million rows, but `TargetTable` has a trigger that performs complex validation and potentially inserts into other audit tables. What performance implications should you consider for this `INSERT` operation compared to a simple `INSERT ... VALUES`?
    *   **Answer:** The `INSERT ... SELECT` itself might be efficient for reading from the source, but the performance will be heavily dominated by the **trigger execution**.
        *   **Row-by-Row Behavior (Logical):** Although `INSERT ... SELECT` processes the source rows as a set, triggers in SQL Server (by default) fire *once per statement* but operate on the `inserted` logical table which contains *all* rows inserted by the statement. However, if the trigger logic performs complex validation or actions *row by row* (e.g., using a cursor or inefficient logic within the trigger), it can effectively serialize the operation and become extremely slow, negating the set-based advantage of `INSERT ... SELECT`.
        *   **Logging:** Both the `INSERT` into `TargetTable` and any DML operations within the trigger (like inserts into audit tables) will be fully logged, potentially generating significant transaction log activity.
        *   **Blocking:** Complex or long-running triggers can hold locks for extended periods, increasing blocking for other concurrent operations.
        *   **Comparison:** Compared to simple `INSERT ... VALUES` (which fires the trigger once per statement, potentially for multiple rows if using multi-row values), the `INSERT ... SELECT` fires the trigger once for potentially a million rows. If the trigger logic is not optimized for set-based operations, the `INSERT ... SELECT` could be significantly slower per-row than multiple smaller `INSERT ... VALUES` statements due to the trigger overhead on a large `inserted` table, despite the efficiency of the `SELECT` part itself. Careful trigger design is crucial for bulk operations.
