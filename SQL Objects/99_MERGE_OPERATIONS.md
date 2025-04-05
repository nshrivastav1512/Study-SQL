# SQL Deep Dive: `MERGE` Operations

## 1. Introduction: Revisiting `MERGE`

The `MERGE` statement is a powerful T-SQL command that allows you to perform `INSERT`, `UPDATE`, or `DELETE` operations on a target table based on comparing it with a source dataset, all within a single atomic statement. It's particularly effective for synchronizing data between tables, such as applying changes from a staging table to a production table or managing slowly changing dimensions.

**Core Concepts:**

*   **Target:** The table to be modified.
*   **Source:** The dataset (table, view, derived table, TVC, etc.) containing the changes or reference data.
*   **`ON` Clause:** Defines the join condition to match rows between the source and target.
*   **`WHEN MATCHED`:** Specifies actions (`UPDATE` or `DELETE`) for rows found in both source and target. Can include additional `AND` conditions.
*   **`WHEN NOT MATCHED [BY TARGET]`:** Specifies the `INSERT` action for rows present in the source but not in the target. Can include additional `AND` conditions.
*   **`WHEN NOT MATCHED BY SOURCE`:** Specifies actions (`UPDATE` or `DELETE`) for rows present in the target but not in the source. Can include additional `AND` conditions.
*   **`OUTPUT` Clause:** Captures information about the rows affected by each action (`INSERT`, `UPDATE`, `DELETE`) performed by the `MERGE`.

## 2. `MERGE` in Action: Analysis of `99_MERGE_OPERATIONS.sql`

This script provides practical examples of using `MERGE` for employee data management.

**Part 1: Basic `MERGE` Operation**

```sql
-- Source data (e.g., from staging or input)
DECLARE @SourceEmployees TABLE (...);
INSERT INTO @SourceEmployees VALUES (1, ...), (2, ...), (4, ...);

-- MERGE statement
MERGE HR.Employees AS TARGET -- Target table
USING @SourceEmployees AS SOURCE -- Source data
ON (TARGET.EmployeeID = SOURCE.EmployeeID) -- Join condition
WHEN MATCHED THEN -- If EmployeeID exists in both
    UPDATE SET -- Update target with source values
        TARGET.Salary = SOURCE.Salary,
        TARGET.FirstName = SOURCE.FirstName, ...
WHEN NOT MATCHED BY TARGET THEN -- If EmployeeID exists in Source but not Target
    INSERT (EmployeeID, FirstName, ...) -- Insert new row into target
    VALUES (SOURCE.EmployeeID, SOURCE.FirstName, ...);
```

*   **Explanation:** This performs a typical "upsert" operation. It synchronizes the `HR.Employees` table with the data in `@SourceEmployees`. If an employee ID matches, the existing employee record is updated with the source data. If an employee ID from the source doesn't exist in the target, a new employee record is inserted.

**Part 2: Advanced `MERGE` with `OUTPUT`**

```sql
CREATE TABLE #MergeLog (...); -- Temp table to store changes

MERGE HR.Employees AS TARGET
USING @SourceEmployees AS SOURCE
ON (TARGET.EmployeeID = SOURCE.EmployeeID)
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED BY TARGET THEN INSERT (...) VALUES (...)
OUTPUT -- Capture details about the changes
    $action AS Action, -- What happened? 'INSERT' or 'UPDATE'
    INSERTED.EmployeeID,
    INSERTED.FirstName,
    INSERTED.LastName,
    DELETED.Salary AS OldSalary, -- Value before UPDATE (NULL for INSERT)
    INSERTED.Salary AS NewSalary, -- Value after INSERT or UPDATE
    GETDATE() AS ModifiedDate
INTO #MergeLog; -- Store the output in the log table
```

*   **Explanation:** Extends the basic merge by adding an `OUTPUT` clause.
    *   `$action`: A special variable indicating whether the row was 'INSERT'ed, 'UPDATE'd, or 'DELETE'd (if a delete clause were present).
    *   `INSERTED.*`: Refers to the state of the row *after* the `INSERT` or `UPDATE`.
    *   `DELETED.*`: Refers to the state of the row *before* the `UPDATE` or `DELETE` (columns are `NULL` for `INSERT` actions).
    *   `INTO #MergeLog`: Directs the output rows into the `#MergeLog` temporary table, creating an audit trail of the changes made by the `MERGE` statement.

**Part 3: Conditional `MERGE` Operations**

```sql
MERGE HR.Employees AS TARGET
USING @SourceEmployees AS SOURCE
ON (TARGET.EmployeeID = SOURCE.EmployeeID)
WHEN MATCHED AND TARGET.Salary <> SOURCE.Salary THEN -- Only update if salary changed
    UPDATE SET TARGET.Salary = SOURCE.Salary, TARGET.ModifiedDate = GETDATE()
WHEN NOT MATCHED BY TARGET AND SOURCE.Salary > 50000 THEN -- Only insert if new and salary > 50k
    INSERT (...) VALUES (...)
WHEN NOT MATCHED BY SOURCE THEN -- If employee exists in Target but not Source
    UPDATE SET TARGET.IsActive = 0; -- Deactivate the employee in the target table
```

*   **Explanation:** Demonstrates adding further conditions using `AND` within the `WHEN` clauses:
    *   `WHEN MATCHED AND TARGET.Salary <> SOURCE.Salary`: Updates only if the employee exists *and* their salary in the source is different from the target. Avoids unnecessary updates.
    *   `WHEN NOT MATCHED BY TARGET AND SOURCE.Salary > 50000`: Inserts a new employee only if their salary meets a certain threshold.
    *   `WHEN NOT MATCHED BY SOURCE`: Handles rows existing only in the target (e.g., employees who left and are no longer in the source feed). Here, it deactivates them (`IsActive = 0`) instead of deleting them.

**Part 4: `MERGE` for Historical Data (Slowly Changing Dimensions - SCD Type 2)**

```sql
CREATE TABLE HR.EmployeeHistory (... Action VARCHAR(10)); -- History table

MERGE HR.Employees AS TARGET
USING @SourceEmployees AS SOURCE
ON (TARGET.EmployeeID = SOURCE.EmployeeID)
WHEN MATCHED THEN UPDATE SET ... -- Update current record
WHEN NOT MATCHED BY TARGET THEN INSERT (...) VALUES (...) -- Insert new record
OUTPUT -- Capture changes into history table
    INSERTED.EmployeeID, INSERTED.FirstName, ..., GETDATE(), $action
INTO HR.EmployeeHistory;
```

*   **Explanation:** Uses the `OUTPUT` clause to capture the state of inserted or updated records (using `INSERTED.*`) along with the `$action` ('INSERT' or 'UPDATE') into a separate history table (`HR.EmployeeHistory`). This is a simplified way to track changes over time, related to Slowly Changing Dimension (SCD) Type 2 concepts where historical versions of records are maintained. *Note: A full SCD Type 2 implementation often involves more complex logic within the `MERGE` (e.g., expiring old records and inserting new ones upon change) rather than just logging the action.*

**Part 5: Best Practices and Tips**

*   **Performance:** Index join columns, only include necessary columns in source/target, consider batching large merges.
*   **Error Handling:** Use `TRY...CATCH` for robust error management.
*   **Concurrency:** Use appropriate isolation levels; consider `HOLDLOCK` hint to prevent anomalies if strict consistency is required during the merge evaluation and execution phases.
*   **Maintenance:** Manage history/log tables.

*   **Example with Error Handling & Locking:**
    ```sql
    BEGIN TRY
        BEGIN TRANSACTION;
        MERGE HR.Employees WITH (HOLDLOCK) AS TARGET -- Add lock hint
        USING @SourceEmployees AS SOURCE ON ...
        WHEN MATCHED THEN UPDATE ...
        WHEN NOT MATCHED BY TARGET THEN INSERT ...;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO HR.ErrorLog (...); -- Log error
        THROW;
    END CATCH;
    ```
    *   **Explanation:** Wraps the `MERGE` in a transaction with `TRY...CATCH` and applies the `HOLDLOCK` hint to the target table for increased consistency during the operation.

## 3. Targeted Interview Questions (Based on `99_MERGE_OPERATIONS.sql`)

**Question 1:** What are the three main `WHEN` clauses used in a `MERGE` statement, and what does each signify?

**Solution 1:**
1.  **`WHEN MATCHED`:** Specifies the action (`UPDATE` or `DELETE`) to take when a row exists in *both* the source and the target based on the `ON` condition.
2.  **`WHEN NOT MATCHED [BY TARGET]`:** Specifies the `INSERT` action to take when a row exists in the *source* but *not* in the target.
3.  **`WHEN NOT MATCHED BY SOURCE`:** Specifies the action (`UPDATE` or `DELETE`) to take when a row exists in the *target* but *not* in the source.

**Question 2:** In section 2, the `OUTPUT` clause references `INSERTED.Salary` and `DELETED.Salary`. What do these represent in the context of the `MERGE` statement's actions?

**Solution 2:**
*   `INSERTED.Salary`: Represents the salary value *after* the `MERGE` operation for that row. If the action was `INSERT`, it's the newly inserted salary. If the action was `UPDATE`, it's the updated salary.
*   `DELETED.Salary`: Represents the salary value *before* the `MERGE` operation affected the row. If the action was `UPDATE`, it's the original salary before the update. If the action was `INSERT`, the `DELETED` logical table is empty for that row, so `DELETED.Salary` would be `NULL`. (Similarly, if the action was `DELETE`, `INSERTED.*` would be `NULL`).

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can a `MERGE` statement perform inserts, updates, and deletes all in one go?
    *   **Answer:** Yes, by using the `WHEN NOT MATCHED BY TARGET THEN INSERT`, `WHEN MATCHED THEN UPDATE`, and `WHEN NOT MATCHED BY SOURCE THEN DELETE` clauses (or `WHEN MATCHED THEN DELETE`).
2.  **[Easy]** What clause is mandatory for matching rows between the source and target in a `MERGE` statement?
    *   **Answer:** The `ON` clause.
3.  **[Medium]** What happens if the source dataset used in a `MERGE` statement contains duplicate rows based on the `ON` clause condition?
    *   **Answer:** The `MERGE` statement will fail with an error. The source dataset must yield unique rows for the join condition specified in the `ON` clause when matching against the target. You typically need to pre-process or aggregate the source to ensure uniqueness on the join keys.
4.  **[Medium]** Can you have a `MERGE` statement with only a `WHEN MATCHED THEN UPDATE` clause and no `WHEN NOT MATCHED` clauses?
    *   **Answer:** Yes. A `MERGE` statement requires at least one `WHEN` clause, but it doesn't have to include all three types. You can perform an update-only merge if desired.
5.  **[Medium]** What does the `$action` pseudo-column in the `OUTPUT` clause of a `MERGE` statement return?
    *   **Answer:** It returns a string value indicating the action performed on the row: 'INSERT', 'UPDATE', or 'DELETE'.
6.  **[Medium]** Why might you add an extra condition like `AND TARGET.ColumnA <> SOURCE.ColumnA` to a `WHEN MATCHED THEN UPDATE` clause?
    *   **Answer:** To avoid performing unnecessary updates on rows where the source and target data are already identical for the columns being updated. This can improve performance slightly by reducing write operations and transaction log usage, and it prevents the `ModifiedDate` (if being updated) from changing when no actual data changed.
7.  **[Hard]** Can you reference columns from both the `SOURCE` and `TARGET` tables within the `SET` clause of a `WHEN MATCHED THEN UPDATE`?
    *   **Answer:** Yes. The primary purpose is usually `SET TARGET.Column = SOURCE.Column`, but you can use values from both in expressions, e.g., `SET TARGET.Salary = TARGET.Salary + SOURCE.BonusAmount`, or `SET TARGET.LastUpdatedBy = SOURCE.UserID, TARGET.Notes = TARGET.Notes + ' Updated.'`.
8.  **[Hard]** Can you update the join columns (specified in the `ON` clause) within a `WHEN MATCHED THEN UPDATE` clause?
    *   **Answer:** No. SQL Server prevents updating columns referenced in the `ON` clause within a `WHEN MATCHED` clause, as this would change the basis for the match itself during the operation. Attempting to do so will result in an error.
9.  **[Hard]** How does the `MERGE` statement interact with `INSTEAD OF` triggers on the target table?
    *   **Answer:** `INSTEAD OF` triggers (`INSERT`, `UPDATE`, `DELETE`) defined on the target table *will fire* for the corresponding actions specified in the `MERGE` statement's `WHEN` clauses. The trigger logic executes *instead of* the action defined in the `MERGE` clause. This means the trigger code must handle the intended data modification (or perform an alternative action). `AFTER` triggers will fire *after* the `MERGE` statement completes its actions.
10. **[Hard/Tricky]** Is the `MERGE` statement always guaranteed to be atomic if run without an explicit `BEGIN TRANSACTION`/`COMMIT`/`ROLLBACK`?
    *   **Answer:** Yes, a single `MERGE` statement is inherently atomic. Like any single DML statement (`INSERT`, `UPDATE`, `DELETE`), if any part of the `MERGE` operation fails (e.g., due to a constraint violation on one of the actions, or an error during evaluation), all modifications performed by that single `MERGE` statement are automatically rolled back. An explicit transaction is only needed if you want to group the `MERGE` statement with *other* separate statements into a single atomic unit of work.
