# SQL Deep Dive: The `DELETE` Statement

## 1. Introduction: What is `DELETE`?

The `DELETE` statement is a fundamental **Data Manipulation Language (DML)** command in SQL used to **remove existing rows (records)** from a table. It allows for precise removal of data based on specified conditions.

**Key Characteristics:**

*   **Removing Data:** Its core function is to remove rows from a table.
*   **Targeted Removal:** Crucially uses a `WHERE` clause to specify *which* rows should be removed. **Omitting the `WHERE` clause is dangerous as it will delete *all* rows in the table.**
*   **Row-Based:** Operates on rows matching the `WHERE` condition.
*   **Flexibility:** The `WHERE` clause can include simple comparisons, subqueries, joins (via `FROM` clause), `EXISTS`, etc., allowing for complex deletion criteria.
*   **Logging:** `DELETE` operations are fully logged in the transaction log (typically logging information about each deleted row), which allows for rollback but can consume significant log space for large deletions.
*   **Triggers:** Fires `DELETE` triggers (`AFTER DELETE`, `INSTEAD OF DELETE`) associated with the table.
*   **Identity Columns:** Does *not* reset `IDENTITY` column values.
*   **Permissions:** Requires `DELETE` permission on the table.

**`DELETE` vs. `TRUNCATE`:**

*   `DELETE` removes rows based on a `WHERE` clause (or all rows if omitted), is fully logged per row, fires `DELETE` triggers, doesn't reset identity, and requires `DELETE` permission.
*   `TRUNCATE` removes *all* rows quickly, is minimally logged, does *not* fire `DELETE` triggers (but can fire `AFTER TRUNCATE` triggers), *does* reset identity, and requires `ALTER TABLE` permission. Use `TRUNCATE` only when you need to empty an entire table quickly and don't need the row-by-row logging or trigger firing.

## 2. `DELETE` in Action: Analysis of `08_DELETE.sql`

This script demonstrates various techniques for using the `DELETE` statement.

**a) Basic `DELETE` Operations**

```sql
-- Simple WHERE clause
DELETE FROM HR.Performance_Reviews WHERE ReviewDate < DATEADD(YEAR, -3, GETDATE());

-- WHERE clause with IN and Subquery
DELETE FROM HR.EMP_Details WHERE DepartmentID IN (SELECT DepartmentID FROM HR.Departments WHERE DepartmentName = 'Temporary');
```

*   **Explanation:** Shows basic row removal based on a condition (`ReviewDate`) and using a subquery to identify rows based on related data (`DepartmentName`).

**b) `DELETE` with `JOIN` (using `FROM` clause)**

```sql
DELETE e -- Alias for the table rows are being deleted from
FROM HR.EMP_Details e -- Alias declared in FROM
INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE d.IsActive = 0;
```

*   **Explanation:** Deletes rows from one table (`HR.EMP_Details`, aliased as `e`) based on conditions involving joined tables (`HR.Departments`). The table specified immediately after `DELETE` (or its alias) is the target for deletion.

**c) `DELETE` with `OUTPUT` Clause**

```sql
DELETE FROM HR.Performance_Reviews
OUTPUT deleted.ReviewID, deleted.EmployeeID, deleted.ReviewDate, deleted.Rating
WHERE Rating < 2;
```

*   **Explanation:** The `OUTPUT` clause can capture information about the rows being deleted.
    *   `deleted.*`: Accesses the values from the rows *before* they are removed.
    *   This example returns details of the performance reviews being deleted (those with `Rating < 2`).

**d) `DELETE` with `OUTPUT INTO` Table**

```sql
DECLARE @DeletedEmployees TABLE (...);
DELETE FROM HR.EMP_Details
OUTPUT deleted.EmployeeID, deleted.FirstName + ' ' + deleted.LastName, GETDATE()
INTO @DeletedEmployees -- Capture output into table variable
WHERE Salary < 30000;
```

*   **Explanation:** Captures the data from the deleted rows (using `deleted.*`) into a table variable (or temporary table) for auditing, archiving, or further processing.

**e) `DELETE` with `TOP`**

```sql
DELETE TOP (10)
FROM HR.AuditLog
WHERE LogDate < DATEADD(MONTH, -6, GETDATE());
```

*   **Explanation:** Limits the `DELETE` statement to affect only the specified number (`TOP (10)`) or percentage of rows that match the `WHERE` clause. **Important:** Similar to `UPDATE TOP`, without an `ORDER BY` (which isn't directly allowed here but can be used in CTEs/subqueries), the specific rows deleted by `TOP` are **not guaranteed**. Often used for batching large delete operations.

**f) `DELETE` with Transaction and Error Handling**

```sql
BEGIN TRY
    BEGIN TRANSACTION;
        DELETE FROM HR.Performance_Reviews WHERE EmployeeID IN (...);
        -- Custom validation using @@ROWCOUNT
        IF @@ROWCOUNT > 50 THROW 50001, 'Too many reviews being deleted', 1;
        DELETE FROM HR.EMP_Details WHERE DepartmentID = 5;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO HR.AuditLog (...); -- Log error
    THROW; -- Re-throw error
END CATCH;
```

*   **Explanation:** Ensures multiple `DELETE` operations (and custom validation) are treated as a single atomic unit. If any part fails or the validation (`IF @@ROWCOUNT > 50`) triggers a `THROW`, the entire transaction is rolled back, leaving the data unchanged. Errors are logged before being re-thrown.

**g) `DELETE` with Dynamic SQL**

```sql
DECLARE @TableName NVARCHAR(100) = 'HR.AuditLog';
DECLARE @SQL NVARCHAR(MAX);
SET @SQL = N'DELETE FROM ' + @TableName + N' WHERE LogDate < @OldDate';
EXECUTE sp_executesql @SQL, N'@OldDate DATETIME', @OldDate = ...;
```

*   **Explanation:** Constructs a `DELETE` statement dynamically and executes it using `sp_executesql` with parameterization. Useful when the table or conditions are determined at runtime.

**h) `DELETE` with Locking Hints (`TABLOCKX`)**

```sql
DELETE FROM HR.InventoryItems WITH (TABLOCKX)
WHERE Quantity = 0;
```

*   **Explanation:** Uses a table hint (`WITH (TABLOCKX)`) to request an exclusive lock on the entire table during the delete. Similar implications to using it with `UPDATE` - potentially faster for large deletes by reducing locking overhead but severely impacts concurrency.

**i) `DELETE` with Partitioned Table**

```sql
DELETE FROM HR.PartitionedEmployees
WHERE EmployeeID BETWEEN 1500 AND 2000;
```

*   **Explanation:** Deleting from a partitioned table uses standard `WHERE` clause syntax. SQL Server identifies the relevant partition(s) based on the condition and the partitioning key (`EmployeeID`).

**j) `DELETE` with `EXISTS`**

```sql
DELETE FROM HR.Performance_Reviews
WHERE EXISTS (SELECT 1 FROM HR.EMP_Details
              WHERE EmployeeID = Performance_Reviews.EmployeeID AND TerminationDate IS NOT NULL);
```

*   **Explanation:** Deletes rows from `HR.Performance_Reviews` if a corresponding record exists in `HR.EMP_Details` indicating the employee is terminated. `EXISTS` checks for the presence of related rows efficiently.

**k) `DELETE` with Multiple Joins**

```sql
DELETE pr -- Alias for the table rows are being deleted from
FROM HR.Performance_Reviews pr
INNER JOIN HR.EMP_Details e ON pr.EmployeeID = e.EmployeeID
INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE d.IsActive = 0 AND e.TerminationDate IS NOT NULL;
```

*   **Explanation:** Deletes rows from one table (`HR.Performance_Reviews`) based on conditions involving multiple joined tables (`HR.EMP_Details`, `HR.Departments`).

**l) `DELETE` with `CASE` (Less Common Pattern)**

```sql
-- Example seems slightly contrived, usually WHERE clause is clearer
DELETE FROM HR.AuditLog
WHERE (CASE WHEN TableName = 'HR.EMP_Details' THEN ... ELSE 0 END) = 1;
```

*   **Explanation:** While syntactically possible to use `CASE` in a `WHERE` clause, it's often less clear than using standard `AND`/`OR` logic. This example tries to delete based on conditional logic applied to `TableName` and `Action`. A more typical `WHERE` clause would likely be more readable.

**m) Batch `DELETE`**

```sql
WHILE 1 = 1
BEGIN
    DELETE TOP (1000) FROM HR.AuditLog WHERE LogDate < DATEADD(YEAR, -1, GETDATE());
    IF @@ROWCOUNT < 1000 BREAK; -- Exit if fewer than batch size deleted
    WAITFOR DELAY '00:00:01'; -- Optional delay
END;
```

*   **Explanation:** A common pattern for deleting large numbers of rows without overwhelming the transaction log or causing excessive blocking. It repeatedly deletes a small batch (`TOP (1000)`) of rows matching the criteria until no more matching rows are found (`@@ROWCOUNT < 1000`). A small delay (`WAITFOR DELAY`) can be added to reduce continuous load.

**n) `DELETE` with Cross-Database Reference (Commented Out)**

```sql
/* DELETE FROM HR.EMP_Details WHERE EmployeeID IN (SELECT EmployeeID FROM Archive.dbo.TerminatedEmployees); */
```

*   **Explanation:** Shows that `DELETE` statements can reference tables in other databases (e.g., `Archive.dbo.TerminatedEmployees`), provided the necessary permissions are in place and the databases are on the same server instance (or linked servers are configured).

## 3. Targeted Interview Questions (Based on `08_DELETE.sql`)

**Question 1:** Explain the purpose of the `WHILE` loop and `DELETE TOP (1000)` combination used in section 13 (Batch DELETE). Why is this approach often preferred over a single `DELETE` statement for removing a very large number of rows?

**Solution 1:**

*   **Purpose:** This pattern implements batch deletion. The `WHILE` loop continues as long as rows are being deleted. Inside the loop, `DELETE TOP (1000)` removes up to 1000 rows that match the `WHERE` clause in each iteration. The `IF @@ROWCOUNT < 1000 BREAK;` condition stops the loop once an iteration deletes fewer than 1000 rows, indicating all matching rows have been removed.
*   **Why Preferred:** A single `DELETE` statement removing millions of rows can:
    1.  **Consume Excessive Transaction Log Space:** Logging each row deletion can cause the transaction log to grow massively, potentially filling the disk or requiring frequent log backups.
    2.  **Cause Long Blocking:** The single large transaction holds locks for a long time, blocking other users trying to access the table.
    *   Batch deletion breaks the operation into smaller, manageable transactions. Each `DELETE TOP (1000)` is its own transaction (implicitly, or could be wrapped explicitly). This keeps individual transaction log usage lower and reduces the duration locks are held, improving concurrency and manageability. The optional `WAITFOR DELAY` further reduces continuous impact.

**Question 2:** In section 2 (`DELETE` with `JOIN`), the statement starts `DELETE e FROM HR.EMP_Details e ...`. Which table are rows actually being removed from, and how is this specified?

**Solution 2:**

*   **Table Rows Removed From:** Rows are being removed from the `HR.EMP_Details` table.
*   **How Specified:** This is specified by the alias `e` placed immediately after the `DELETE` keyword. In the `UPDATE`/`DELETE` with `FROM`/`JOIN` syntax, the alias (or full table name) right after `DELETE` or `UPDATE` indicates the target table for the modification. The tables listed in the `FROM` clause (including the target table again with its alias) are used to establish relationships and filter criteria.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** If you `DELETE` all rows from a table with an `IDENTITY` column, what will the identity value be for the next row inserted?
    *   **Answer:** The identity value will continue from the last value generated before the `DELETE`. `DELETE` does not reset the identity counter; only `TRUNCATE TABLE` or reseeding (`DBCC CHECKIDENT` with RESEED) does.
2.  **[Easy]** Can you use a `WHERE` clause with `TRUNCATE TABLE`?
    *   **Answer:** No. `TRUNCATE TABLE` always removes *all* rows from a table or specified partitions; it does not support a `WHERE` clause for conditional removal.
3.  **[Medium]** If a table has a `FOREIGN KEY` constraint referencing it (e.g., `Orders` references `Customers`), what happens if you try to `DELETE` a row from the referenced table (`Customers`) that is currently being referenced by rows in the referencing table (`Orders`)?
    *   **Answer:** The `DELETE` statement will fail with a foreign key constraint violation error. SQL Server prevents the deletion of a parent row if child rows still reference it, ensuring referential integrity. To delete the parent row, you would first need to delete or update the referencing child rows, or define `ON DELETE CASCADE` (use with caution) on the foreign key constraint.
4.  **[Medium]** Does a `DELETE` statement acquire locks? If so, what kind typically?
    *   **Answer:** Yes. `DELETE` typically acquires exclusive locks (`X`) on the rows (or pages, depending on locking granularity and escalation) that it is removing. It also acquires intent locks on higher levels (like the table). These locks prevent other transactions from reading (in some isolation levels) or modifying the affected rows until the `DELETE` transaction completes.
5.  **[Medium]** Can you use the `OUTPUT` clause with `DELETE` to capture values from columns that were *not* part of the `WHERE` clause?
    *   **Answer:** Yes. The `OUTPUT deleted.*` clause captures the entire state of the row *before* it was deleted, including values from columns not used in the `WHERE` clause filtering criteria.
6.  **[Medium]** What is the difference between `DELETE FROM MyTable WHERE ID IN (SELECT ID FROM OtherTable WHERE Condition)` and `DELETE FROM MyTable WHERE EXISTS (SELECT 1 FROM OtherTable WHERE OtherTable.ID = MyTable.ID AND Condition)`? Which is often more efficient?
    *   **Answer:** Both aim to delete rows from `MyTable` based on related data in `OtherTable`.
        *   `IN (Subquery)`: The subquery typically runs first, potentially collecting *all* matching `ID`s from `OtherTable`. The outer query then checks if `MyTable.ID` is present in this potentially large list.
        *   `EXISTS (Correlated Subquery)`: For each row in `MyTable`, the subquery checks if *any* matching row exists in `OtherTable` meeting the condition. It can often stop checking as soon as the first match is found for a given `MyTable` row.
        *   **Efficiency:** `EXISTS` is often more efficient, especially if the subquery could return many rows or if `OtherTable.ID` is indexed. `EXISTS` only needs to find *one* match, while `IN` might need to materialize and search a large list from the subquery.
7.  **[Hard]** If you `DELETE` rows from a table, does the space occupied by those rows on disk become immediately available for the operating system? What happens to the table's high-water mark?
    *   **Answer:** No, the space is generally not immediately returned to the operating system.
        *   **Space Reuse:** The space within the database data file(s) formerly occupied by the deleted rows becomes available for *reuse* by subsequent `INSERT` or `UPDATE` operations *on the same table* (or other objects in the same filegroup, depending on allocation).
        *   **High-Water Mark (HWM):** `DELETE` operations generally do not lower the table's high-water mark (the conceptual boundary indicating the last page allocated to the table). The table might contain many empty or near-empty pages below the HWM.
        *   **Reclaiming Space:** To reclaim the space and potentially return it to the OS (or shrink the data file), you typically need to perform operations like rebuilding indexes (`ALTER INDEX ... REBUILD`), rebuilding the table (e.g., `ALTER TABLE ... REBUILD`), or explicitly shrinking the database file (`DBCC SHRINKFILE`), though shrinking files is often discouraged due to fragmentation issues. `TRUNCATE TABLE` *does* deallocate pages more effectively than `DELETE`.
8.  **[Hard]** Can an `INSTEAD OF DELETE` trigger prevent the actual deletion of rows from occurring? How would it typically work?
    *   **Answer:** Yes. An `INSTEAD OF DELETE` trigger fires *instead of* the actual `DELETE` operation. The code within the trigger executes, but the underlying delete from the base table does not happen automatically. The trigger code can then perform alternative actions, such as:
        *   Doing nothing (effectively ignoring the delete request).
        *   Performing validation and then explicitly deleting the row(s) from the base table if validation passes.
        *   Updating a status column (e.g., setting `IsActive = 0`) instead of physically deleting the row (soft delete).
        *   Deleting data from related tables instead of or in addition to the base table.
    *   They are commonly used on views to allow deletion logic that spans multiple base tables or performs actions other than a direct delete.
9.  **[Hard]** You need to delete duplicate rows from a table based on certain columns, keeping only one instance (e.g., the one with the lowest or highest primary key). How might you achieve this using `DELETE` with Common Table Expressions (CTEs) and window functions like `ROW_NUMBER()`?
    *   **Answer:** A common pattern uses `ROW_NUMBER()` within a CTE to identify duplicates:
        ```sql
        WITH RowNumCTE AS (
            SELECT
                PrimaryKeyColumn, -- Or CTID if no PK
                ROW_NUMBER() OVER(PARTITION BY DuplicateColumn1, DuplicateColumn2 ORDER BY PrimaryKeyColumn ASC) as rn -- Assign row number within each group of duplicates
            FROM YourTable
        )
        DELETE FROM RowNumCTE
        WHERE rn > 1; -- Delete all rows except the first one (rn=1) in each duplicate group
        ```
        *   `PARTITION BY`: Defines the columns that determine duplicates.
        *   `ORDER BY`: Determines which row within the duplicate group gets `rn = 1` (and is therefore kept).
        *   `DELETE FROM RowNumCTE WHERE rn > 1`: Deletes all rows marked with a row number greater than 1, effectively removing all duplicates while keeping one instance per group.
10. **[Hard/Tricky]** If a `DELETE` statement is blocked by another transaction holding locks, what state will the `DELETE` statement typically be in, and how could you identify the blocking session?
    *   **Answer:**
        *   **State:** The `DELETE` statement will typically be in a `SUSPENDED` state, waiting for the necessary locks to be released. Its `wait_type` (visible in DMVs like `sys.dm_os_waiting_tasks`) would likely indicate a lock wait (e.g., `LCK_M_X` for an exclusive lock).
        *   **Identifying Blocking Session:** You can use system stored procedures or Dynamic Management Views (DMVs):
            *   `sp_who2`: Look for rows where the `BlkBy` (Blocked By) column contains the SPID (Session Process ID) of your `DELETE` statement's session. The value in `BlkBy` is the SPID of the blocking session.
            *   `sys.dm_exec_requests`: Query this DMV for your session ID (`session_id`) and look at the `blocking_session_id` column. A non-zero value indicates the SPID of the blocking session.
            *   `sys.dm_tran_locks` and `sys.dm_os_waiting_tasks`: More detailed queries joining these DMVs can show exactly which resource the `DELETE` is waiting for and which session holds the conflicting lock on that resource.
