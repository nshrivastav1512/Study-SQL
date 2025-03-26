# SQL Deep Dive: The `MERGE` Statement

## 1. Introduction: What is `MERGE`?

The `MERGE` statement (introduced in SQL Server 2008) is a versatile **Data Manipulation Language (DML)** command that performs `INSERT`, `UPDATE`, or `DELETE` operations on a target table based on the results of a join with a source data set. It allows you to synchronize data between two tables efficiently in a single, atomic statement.

**Why use `MERGE`?**

*   **Synchronization:** Ideal for synchronizing a target table (like a dimension table in a data warehouse or production data) with a source (like a staging table or incoming data feed).
*   **Efficiency:** Combines multiple potential actions (`INSERT`, `UPDATE`, `DELETE`) into one operation, often reducing the code complexity and potentially improving performance compared to writing separate `IF EXISTS`/`UPDATE`/`ELSE`/`INSERT` logic.
*   **Atomicity:** The entire `MERGE` operation is atomic; either all actions succeed, or none do (if part of a transaction that rolls back).
*   **Conditional Logic:** Supports complex conditions to determine whether to insert, update, or delete based on whether rows match between the source and target.

**Key Concepts:**

*   **Target:** The table being modified.
*   **Source:** A table, view, table variable, derived table, or CTE providing the data to compare against the target.
*   **`ON` Clause:** Specifies the join condition(s) used to match rows between the source and target (similar to a `JOIN` condition).
*   **`WHEN MATCHED THEN [UPDATE | DELETE]`:** Defines the action(s) to take when a row exists in *both* the source and the target based on the `ON` condition. You can add further `AND` conditions here.
*   **`WHEN NOT MATCHED [BY TARGET] THEN INSERT`:** Defines the action (always `INSERT`) to take when a row exists in the *source* but *not* in the target.
*   **`WHEN NOT MATCHED BY SOURCE THEN [UPDATE | DELETE]`:** Defines the action(s) to take when a row exists in the *target* but *not* in the source.

**Important Considerations (from script comments):**

*   Requires compatibility level 100+.
*   Atomic operation.
*   Can use `OUTPUT` clause.
*   Requires `HOLDLOCK` hint in some scenarios to prevent race conditions (Halloween Protection).
*   Cannot update the same target row multiple times in one statement.
*   Use explicit transactions and error handling.
*   Be mindful of locking and performance with large datasets.
*   Proper indexing on join columns is crucial for performance.

**General Syntax:**

```sql
MERGE INTO target_table [AS TargetAlias]
USING source_data [AS SourceAlias]
ON join_condition
WHEN MATCHED [AND additional_condition] THEN
    UPDATE SET TargetAlias.column1 = SourceAlias.value1, ...
    -- or DELETE
WHEN NOT MATCHED [BY TARGET] [AND additional_condition] THEN
    INSERT (column1, column2, ...) VALUES (SourceAlias.value1, SourceAlias.value2, ...)
WHEN NOT MATCHED BY SOURCE [AND additional_condition] THEN
    UPDATE SET TargetAlias.column1 = some_value, ...
    -- or DELETE
[OUTPUT $action, inserted.*, deleted.* INTO @table_variable]; -- Optional
```

## 2. `MERGE` in Action: Analysis of `09_MERGE.sql`

This script demonstrates various applications of the `MERGE` statement.

**a) Basic `MERGE` (Insert/Update)**

```sql
MERGE INTO HR.EMP_Details AS Target
USING HR.TempEmployees AS Source -- Assuming TempEmployees exists and has matching columns
ON Target.EmployeeID = Source.EmployeeID
WHEN MATCHED THEN -- Row exists in both Target and Source
    UPDATE SET Target.FirstName = Source.FirstName, ..., Target.ModifiedDate = GETDATE()
WHEN NOT MATCHED THEN -- Row exists in Source but not Target
    INSERT (FirstName, ...) VALUES (Source.FirstName, ...);
```

*   **Explanation:** Synchronizes `HR.EMP_Details` (Target) with `HR.TempEmployees` (Source) based on `EmployeeID`. If an employee exists in both, their details are updated in the target. If an employee exists in the source but not the target, they are inserted into the target.

**b) `MERGE` with Multiple Conditions, `DELETE`, and `OUTPUT`**

```sql
MERGE HR.Performance_Reviews AS Target
USING (...) AS Source -- Source derived from EMP_Details and Departments
ON Target.EmployeeID = Source.EmployeeID AND YEAR(Target.ReviewDate) = YEAR(GETDATE())
WHEN MATCHED THEN -- Employee has a review this year
    UPDATE SET Target.ReviewedBy = Source.ReviewedBy, ...
WHEN NOT MATCHED THEN -- Employee exists in Source but has no review this year in Target
    INSERT (EmployeeID, ReviewDate, Rating, ReviewedBy) VALUES (...)
WHEN NOT MATCHED BY SOURCE AND YEAR(Target.ReviewDate) = YEAR(GETDATE()) THEN -- Employee has review this year in Target, but is NOT in Source (e.g., inactive employee)
    DELETE
OUTPUT $action AS MergeAction, inserted.ReviewID, deleted.ReviewID, inserted.EmployeeID;
```

*   **Explanation:** A more complex example synchronizing performance reviews for the current year.
    *   Updates existing reviews for the year.
    *   Inserts new reviews for employees found in the source who don't have one this year.
    *   Deletes reviews from the target if the employee isn't found in the source (perhaps indicating an inactive employee whose review should be removed).
    *   Uses `OUTPUT $action` to show whether each affected row resulted in an 'INSERT', 'UPDATE', or 'DELETE'.

**c) `MERGE` with Table Variable Source**

```sql
DECLARE @SalaryUpdates TABLE (...);
INSERT INTO @SalaryUpdates VALUES (...);

MERGE HR.EMP_Details AS Target
USING @SalaryUpdates AS Source
ON Target.EmployeeID = Source.EmployeeID
WHEN MATCHED AND Target.Salary <> Source.NewSalary THEN -- Update only if salary differs
    UPDATE SET Target.Salary = Source.NewSalary, ...;
```

*   **Explanation:** Demonstrates using a table variable (`@SalaryUpdates`) as the source for the `MERGE`. This is useful for applying smaller, targeted changes prepared in memory. The `WHEN MATCHED` clause includes an additional condition (`Target.Salary <> Source.NewSalary`) to avoid unnecessary updates if the salary is already correct.

**d) `MERGE` with Complex Join Source (`CROSS APPLY`)**

```sql
MERGE HR.Departments AS Target
USING (SELECT d.DepartmentID, ..., e.EmployeeID as NewManagerID, ...
       FROM HR.Departments d
       CROSS APPLY (SELECT TOP 1 EmployeeID FROM HR.EMP_Details ... ORDER BY HireDate DESC) e -- Find latest hire in dept
      ) AS Source
ON Target.DepartmentID = Source.DepartmentID
WHEN MATCHED THEN
    UPDATE SET Target.ManagerID = Source.NewManagerID, ...;
```

*   **Explanation:** Shows that the `USING` clause can contain complex queries, including joins or `APPLY` operators, to generate the source data. Here, it finds the most recently hired employee in each department using `CROSS APPLY` and updates the `ManagerID` in the `HR.Departments` table accordingly.

**e) `MERGE` with `OUTPUT INTO` Table**

```sql
DECLARE @MergeResults TABLE (...);
MERGE HR.EMP_Details AS Target
USING HR.SalaryAdjustments AS Source -- Assuming SalaryAdjustments table exists
ON Target.EmployeeID = Source.EmployeeID
WHEN MATCHED THEN
    UPDATE SET Target.Salary = Source.NewSalary
OUTPUT $action, inserted.EmployeeID, deleted.Salary, inserted.Salary, GETDATE()
INTO @MergeResults; -- Capture results into table variable
```

*   **Explanation:** Captures the detailed results of the `MERGE` operation (action type, IDs, old/new values) into a table variable for auditing or logging purposes.

**f) `MERGE` with Error Handling**

```sql
BEGIN TRY
    BEGIN TRANSACTION;
    MERGE HR.EMP_Details AS Target USING HR.TempEmployees AS Source ON ...
    WHEN MATCHED AND Source.Salary > Target.Salary THEN UPDATE ...
    WHEN NOT MATCHED BY TARGET THEN INSERT ...
    WHEN NOT MATCHED BY SOURCE THEN UPDATE SET Target.IsActive = 0; -- Deactivate employees not in source

    IF @@ROWCOUNT > 100 THROW 50001, 'Too many rows affected', 1; -- Custom validation
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT INTO HR.AuditLog (...); -- Log error
    THROW;
END CATCH;
```

*   **Explanation:** Wraps the `MERGE` statement in a `TRY...CATCH` block and an explicit transaction. This ensures atomicity and allows for custom validation (checking `@@ROWCOUNT`) and error logging/handling if the `MERGE` fails or violates a business rule.

**g) `MERGE` with Dynamic SQL (Partial Example)**

```sql
DECLARE @SQL NVARCHAR(MAX);
DECLARE @TableName NVARCHAR(100) = 'HR.Departments';
SET @SQL = N'MERGE ' + @TableName + N' AS Target USING (...) AS Source ON ... WHEN MATCHED THEN UPDATE ...';
-- EXEC sp_executesql @SQL, ... (Execution part omitted in script)
```

*   **Explanation:** Shows the construction of a dynamic `MERGE` statement string. Parameterization and execution using `sp_executesql` would be needed for a complete, safe implementation.

**h) `MERGE` with Conditional Logic (`CASE` in `WHEN`)**

```sql
MERGE HR.EMP_Details AS Target
USING HR.SalaryReviews AS Source ON Target.EmployeeID = Source.EmployeeID
WHEN MATCHED AND CASE WHEN Source.Performance = 'Excellent' THEN 1 ... ELSE 0 END = 1 THEN
    UPDATE SET Target.Salary = Target.Salary * 1.1, ...;
```

*   **Explanation:** Demonstrates embedding `CASE` expressions or other complex logic within the `WHEN MATCHED AND ...` condition to apply updates selectively based on multiple criteria derived from the source data.

**i) `MERGE` with Locking Hint (`HOLDLOCK`)**

```sql
MERGE HR.PartitionedEmployees WITH (HOLDLOCK) AS Target -- Apply hint to Target
USING HR.TempEmployees AS Source ON Target.EmployeeID = Source.EmployeeID
WHEN MATCHED THEN UPDATE SET Target.Department = Source.Department;
```

*   **Explanation:** Applies the `HOLDLOCK` hint (equivalent to `SERIALIZABLE`) to the target table. This is sometimes recommended for `MERGE` statements to prevent certain anomalies or race conditions that can occur under lower isolation levels when checking for matches and performing actions. It increases locking but ensures consistency.

## 3. Targeted Interview Questions (Based on `09_MERGE.sql`)

**Question 1:** In the basic `MERGE` operation (section 1), what happens if an `EmployeeID` exists in the `HR.EMP_Details` (Target) table but *not* in the `HR.TempEmployees` (Source) table?

**Solution 1:** Nothing happens to that specific row in the `HR.EMP_Details` table. The basic example only defines actions for `WHEN MATCHED` (row exists in both) and `WHEN NOT MATCHED [BY TARGET]` (row exists in Source but not Target). It does not include a `WHEN NOT MATCHED BY SOURCE` clause, so rows only present in the target are ignored by this specific `MERGE` statement.

**Question 2:** Section 2 includes `WHEN NOT MATCHED BY SOURCE ... THEN DELETE`. Explain what this clause does in the context of that specific `MERGE` statement.

**Solution 2:** This clause handles rows that exist in the *target* table (`HR.Performance_Reviews` for the current year) but do *not* exist in the *source* data set (derived from active employees and their managers). In this context, it likely means the employee associated with the performance review is no longer considered active or relevant according to the source query (perhaps they left the company or changed departments). Therefore, the `DELETE` action removes their performance review record for the current year from the target table, effectively cleaning up records for employees not found in the source.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What are the three main types of `WHEN` clauses available in a `MERGE` statement?
    *   **Answer:** `WHEN MATCHED`, `WHEN NOT MATCHED [BY TARGET]`, and `WHEN NOT MATCHED BY SOURCE`.
2.  **[Easy]** Can you have multiple `WHEN MATCHED` clauses in a single `MERGE` statement?
    *   **Answer:** Yes, you can have multiple `WHEN MATCHED` clauses, but they must have additional, mutually exclusive `AND` conditions to differentiate them (e.g., `WHEN MATCHED AND Target.IsActive = 0 THEN DELETE`, `WHEN MATCHED AND Target.ColA <> Source.ColA THEN UPDATE ...`). A row can only satisfy the conditions for one `WHEN MATCHED` clause.
3.  **[Medium]** Why might the `HOLDLOCK` hint be recommended when using `MERGE`? What problem does it help prevent?
    *   **Answer:** `HOLDLOCK` (equivalent to `SERIALIZABLE` isolation for the duration of the statement on the locked object) helps prevent potential race conditions or anomalies, sometimes referred to as the "Halloween Problem" variation in the context of `MERGE`. Without sufficient locking, another concurrent transaction could potentially modify a row *after* the `MERGE` statement has determined whether it matches or not but *before* the `MERGE` statement performs its `INSERT`/`UPDATE`/`DELETE` action, leading to incorrect results (like inserting a row that now exists, or updating/deleting a row that no longer meets the original match criteria). `HOLDLOCK` ensures stability during the evaluation and action phases.
4.  **[Medium]** Can you update the columns used in the `ON` clause (the join columns) within a `WHEN MATCHED THEN UPDATE` clause of a `MERGE` statement?
    *   **Answer:** No, you generally cannot (and should not) update the columns used in the `ON` clause within the `WHEN MATCHED THEN UPDATE` section. Doing so would change the basis on which the match was determined and is disallowed by SQL Server, resulting in an error.
5.  **[Medium]** What does the special variable `$action` represent when used in the `OUTPUT` clause of a `MERGE` statement?
    *   **Answer:** `$action` is a special column available in the `OUTPUT` clause of a `MERGE` statement that returns a string value indicating the action performed for each affected row: 'INSERT', 'UPDATE', or 'DELETE'.
6.  **[Medium]** If the source data set contains duplicate rows based on the `ON` clause criteria, how does the `MERGE` statement typically behave?
    *   **Answer:** If the source contains duplicates that match the *same* target row, the `MERGE` statement will raise an error. The statement requires that a target row matches at most one source row. You must ensure your source data set is unique based on the join columns specified in the `ON` clause before using it in a `MERGE`.
7.  **[Hard]** Can a single `MERGE` statement cause both an `UPDATE` and a `DELETE` action to be performed on the *same target row*?
    *   **Answer:** No. A single target row can only be affected by *one* action (`INSERT`, `UPDATE`, or `DELETE`) within a single `MERGE` statement execution. While you can have multiple `WHEN MATCHED` clauses (e.g., one for `UPDATE` and one for `DELETE` with different `AND` conditions), only one of these can be true for any given matched row. Similarly, a row cannot be both `MATCHED` and `NOT MATCHED BY SOURCE` simultaneously.
8.  **[Hard]** How does `MERGE` interact with `INSTEAD OF` triggers defined on the target table?
    *   **Answer:** `INSTEAD OF` triggers defined on the target table *will* fire for `INSERT`, `UPDATE`, or `DELETE` actions initiated by a `MERGE` statement. The trigger fires *instead of* the direct DML action specified in the `MERGE` clause (`WHEN MATCHED THEN UPDATE` fires `INSTEAD OF UPDATE`, `WHEN NOT MATCHED THEN INSERT` fires `INSTEAD OF INSERT`, etc.). The logic within the `INSTEAD OF` trigger then takes over, and it might or might not perform the intended action based on its code. This can significantly alter the behavior expected from the `MERGE` statement alone. `AFTER` triggers also fire *after* the `MERGE` actions are completed.
9.  **[Hard]** Can you use `MERGE` to synchronize data between two tables located on different SQL Server instances (e.g., using linked servers)? What are potential performance considerations?
    *   **Answer:** Yes, you can use `MERGE` with linked servers. The source or target table can be referenced using the four-part naming convention (`LinkedServerName.DatabaseName.SchemaName.TableName`).
        *   **Performance Considerations:** Performance can be significantly impacted. Query optimization across linked servers is more complex. Large amounts of data might need to be transferred over the network between the instances for comparison, which can be slow. Filtering data effectively on the *remote* server (in the `USING` clause if the source is remote, or in `WHEN` conditions if the target is remote) before transferring it is crucial. It might sometimes be faster to pull the necessary source data into a local temporary table first and then perform the `MERGE` locally. Distributed transaction coordination (MSDTC) might also be required depending on the setup and actions performed.
10. **[Hard/Tricky]** If a `MERGE` statement has a `WHEN MATCHED THEN UPDATE` clause and a `WHEN NOT MATCHED BY SOURCE THEN DELETE` clause, and a row initially exists in both source and target but is deleted from the source by a concurrent transaction *after* the `MERGE` has identified it as `MATCHED` but *before* the `UPDATE` occurs (assuming no `HOLDLOCK`), what might happen?
    *   **Answer:** This highlights the potential race condition `HOLDLOCK` aims to prevent. Without sufficient locking (`HOLDLOCK` or `SERIALIZABLE` isolation), the following could happen:
        1.  The `MERGE` statement reads the target row and finds a matching source row. It decides to execute the `WHEN MATCHED THEN UPDATE` clause for this row.
        2.  Before the `MERGE` acquires the necessary locks to perform the `UPDATE`, a concurrent transaction deletes the corresponding row from the source table and commits.
        3.  The `MERGE` statement proceeds to execute the `UPDATE` on the target row as originally planned based on the now-stale `MATCHED` condition.
    *   The row is updated, even though, according to the final state of the source, it should perhaps have been deleted by a (hypothetical, if the logic were re-evaluated) `WHEN NOT MATCHED BY SOURCE` condition. The `MERGE` acts based on the state it observed when evaluating the conditions, which might not reflect concurrent changes without stricter locking.
