# SQL Deep Dive: The `ROLLBACK` Statement

## 1. Introduction: What is `ROLLBACK`?

The `ROLLBACK TRANSACTION` (or `ROLLBACK WORK`, or simply `ROLLBACK`) statement is the essential counterpart to `COMMIT TRANSACTION` in SQL transaction management. Its purpose is to **undo all data modifications** made since the beginning of the current transaction or since a specific savepoint within the transaction. It effectively aborts the transaction and returns the database to the state it was in before the transaction (or savepoint) began.

**Why is `ROLLBACK` Crucial?**

*   **Atomicity & Consistency:** `ROLLBACK` is fundamental to ensuring atomicity (all or nothing) and consistency (maintaining a valid database state). If an error occurs or a business rule is violated mid-transaction, `ROLLBACK` prevents partial, potentially inconsistent changes from being saved.
*   **Error Handling:** It's the primary mechanism for handling errors within explicit transactions. When an error is detected (e.g., via `TRY...CATCH` or manual checks), `ROLLBACK` is used to discard the failed unit of work.
*   **Undoing Changes:** Allows discarding unwanted changes before they are made permanent by a `COMMIT`.

**Key Characteristics:**

*   Undoes data changes (`INSERT`, `UPDATE`, `DELETE`, `MERGE`) made within the current transaction scope.
*   Can roll back the entire transaction or only back to a named savepoint.
*   Resets `@@TRANCOUNT` to 0 if rolling back the entire transaction. Does *not* change `@@TRANCOUNT` if rolling back to a savepoint.
*   Releases locks acquired by the transaction (or the portion being rolled back).
*   Cannot be undone; the rollback itself is final for the undone changes.
*   Syntax: `ROLLBACK TRANSACTION [transaction_name | savepoint_name]`, `ROLLBACK WORK`, or `ROLLBACK`.

## 2. `ROLLBACK` in Action: Analysis of `13_ROLLBACK.sql`

This script demonstrates various uses and scenarios for the `ROLLBACK` statement.

**a) Basic `ROLLBACK` (with `@@ERROR`)**

```sql
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details SET Salary = Salary * 2; -- Potentially large update
    IF @@ERROR <> 0 -- Check if the UPDATE failed (older method)
        ROLLBACK TRANSACTION; -- Undo the UPDATE if error occurred
    -- ELSE: COMMIT would normally go here if no error
```

*   **Explanation:** Shows a simple rollback based on the `@@ERROR` system function (which captures the error number of the *last executed* statement). If the `UPDATE` fails, the transaction is rolled back. *Note: `TRY...CATCH` is the modern, preferred method for error handling.*

**b) `ROLLBACK` to Save Points**

```sql
BEGIN TRANSACTION;
    INSERT INTO HR.Departments (...);
    SAVE TRANSACTION DeptInserted; -- Create savepoint

    UPDATE HR.EMP_Details SET DepartmentID = SCOPE_IDENTITY() WHERE ...;

    IF @@ERROR <> 0 -- Check if UPDATE failed
        ROLLBACK TRANSACTION DeptInserted; -- Roll back ONLY the UPDATE
    ELSE
        COMMIT TRANSACTION; -- Commit INSERT (and UPDATE if successful)
```

*   **Explanation:** If the `UPDATE` fails, `ROLLBACK TRANSACTION DeptInserted` undoes only the `UPDATE` operation performed *after* the savepoint `DeptInserted` was created. The `INSERT` performed *before* the savepoint remains part of the active transaction. If the `UPDATE` succeeded, the `COMMIT` makes both the `INSERT` and `UPDATE` permanent.

**c) `ROLLBACK WORK` (ANSI Standard)**

```sql
BEGIN TRANSACTION;
    DELETE FROM HR.EMP_Details WHERE TerminationDate IS NOT NULL;
    IF @@ROWCOUNT > 100 -- Business rule check
        ROLLBACK WORK; -- ANSI syntax for ROLLBACK TRANSACTION
    ELSE
        COMMIT WORK;
```

*   **Explanation:** Uses the `ROLLBACK WORK` syntax, which is functionally identical to `ROLLBACK TRANSACTION` in SQL Server, to undo the `DELETE` if more than 100 rows were affected.

**d) Nested Transaction `ROLLBACK`**

```sql
BEGIN TRANSACTION MainTran; -- @@TRANCOUNT = 1
    UPDATE HR.Departments ...;
    BEGIN TRANSACTION SubTran; -- @@TRANCOUNT = 2
        UPDATE HR.EMP_Details ...;
        IF @@ERROR <> 0
        BEGIN
            -- Attempt to rollback inner transaction - THIS IS PROBLEMATIC
            ROLLBACK TRANSACTION SubTran; -- Actually rolls back EVERYTHING to MainTran start!
            -- Main transaction continues, but @@TRANCOUNT is now 0
        END
    -- This COMMIT will fail if the inner ROLLBACK occurred because @@TRANCOUNT is 0
    IF @@TRANCOUNT > 0
        COMMIT TRANSACTION MainTran;
```

*   **Explanation:** This example highlights a critical aspect of nested rollbacks. Executing `ROLLBACK TRANSACTION` (even if seemingly targeting an inner transaction like `SubTran`) **always rolls back to the outermost `BEGIN TRANSACTION`** and resets `@@TRANCOUNT` to 0. The subsequent `COMMIT TRANSACTION MainTran` would fail because there's no active transaction (`@@TRANCOUNT` is 0).
*   **Correct Handling:** To handle errors in inner scopes without aborting the whole transaction, you typically use `SAVE TRANSACTION` within the inner scope and `ROLLBACK` to the savepoint if an error occurs there, allowing the outer transaction to potentially continue or decide on a full rollback later.

**e) `ROLLBACK` with Multiple Save Points**

```sql
BEGIN TRANSACTION;
    UPDATE HR.Departments SET DepartmentName = UPPER(DepartmentName);
    SAVE TRANSACTION NameUpdate;
    UPDATE HR.Departments SET Budget = Budget * 1.2;
    SAVE TRANSACTION BudgetUpdate;
    UPDATE HR.EMP_Details SET Salary = Salary * 1.5;

    IF @@ERROR <> 0 -- Error in Salary update?
        ROLLBACK TRANSACTION BudgetUpdate; -- Roll back Salary and Budget updates
    ELSE IF @@ROWCOUNT > 100 -- Too many salary updates?
        ROLLBACK TRANSACTION NameUpdate; -- Roll back Salary, Budget, and Name updates
    ELSE
        COMMIT TRANSACTION; -- Commit everything
```

*   **Explanation:** Demonstrates rolling back to different points based on conditions. If the last `UPDATE` fails, only changes after `BudgetUpdate` are undone. If the last `UPDATE` affects too many rows, changes after `NameUpdate` are undone. Otherwise, all changes are committed.

**f) `ROLLBACK` with Error Handling (`TRY...CATCH` and `XACT_STATE`)**

```sql
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE HR.EMP_Details SET DepartmentID = (... 'NonExistent' ...); -- Causes FK error
    COMMIT TRANSACTION; -- This won't be reached
END TRY
BEGIN CATCH
    -- Check if transaction is active and potentially uncommittable
    IF XACT_STATE() <> 0 -- State is 1 (active) or -1 (uncommittable)
    BEGIN
        ROLLBACK TRANSACTION; -- Rollback is necessary
        INSERT INTO HR.ErrorLog (...); -- Log the error
    END
    -- Optionally re-throw error: THROW;
END CATCH;
```

*   **Explanation:** The robust `TRY...CATCH` pattern. When the `UPDATE` fails (due to FK violation), control jumps to `CATCH`. `XACT_STATE()` is checked. If it's non-zero (meaning a transaction is active, even if doomed/uncommittable), `ROLLBACK TRANSACTION` is executed to properly clean up.

**g) `ROLLBACK` with Distributed Transaction**

```sql
BEGIN DISTRIBUTED TRANSACTION;
    UPDATE HR.EMP_Details ...;
    /* UPDATE RemoteDB.HR.Salaries ...; */
    IF @@ERROR <> 0
        ROLLBACK TRANSACTION; -- Rolls back changes on ALL participating resources
    ELSE
        COMMIT TRANSACTION;
```

*   **Explanation:** In a distributed transaction managed by MSDTC, `ROLLBACK TRANSACTION` signals MSDTC to coordinate the rollback across all participating databases/servers, ensuring atomicity across the distributed unit of work.

**h) Partial `ROLLBACK` with Batch Operations (using Savepoints)**

```sql
BEGIN TRANSACTION;
DECLARE @Counter INT = 1;
WHILE @Counter <= 5 BEGIN
    SAVE TRANSACTION BatchPoint; -- Savepoint before each batch 'attempt'
    INSERT INTO HR.AuditLog (...) VALUES ('Batch ' + CAST(@Counter AS VARCHAR), ...);
    IF @@ERROR <> 0 BEGIN
        ROLLBACK TRANSACTION BatchPoint; -- Rollback only this failed batch
        SET @Counter = @Counter + 1;
        CONTINUE; -- Skip to next iteration
    END
    SET @Counter = @Counter + 1;
END
COMMIT TRANSACTION; -- Commit all successful batches
```

*   **Explanation:** Uses savepoints within a loop to allow individual "batches" (here, just single inserts for demo) to fail and be rolled back without aborting the entire process. Only the work done *after* `SAVE TRANSACTION BatchPoint` is undone by `ROLLBACK TRANSACTION BatchPoint`. The loop continues, and the final `COMMIT` saves all successfully completed batches.

**i) `ROLLBACK` with Isolation Level**

```sql
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details ...;
    IF @@ROWCOUNT > 50
        ROLLBACK TRANSACTION; -- Rollback work done under SERIALIZABLE level
    ELSE
        COMMIT TRANSACTION;
```

*   **Explanation:** `ROLLBACK` undoes the work performed under the currently active isolation level. The isolation level itself affects concurrency *during* the transaction, while `ROLLBACK` simply reverses the data changes made.

**j) `ROLLBACK` with Performance Monitoring**

```sql
DECLARE @StartTime DATETIME = GETDATE();
BEGIN TRANSACTION;
BEGIN TRY
    UPDATE HR.EMP_Details ...;
    IF @@ROWCOUNT > 1000 THROW 50001, 'Too many rows affected', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION; -- Rollback on error
    -- Log the failure and duration
    INSERT INTO HR.PerformanceLog (...) VALUES ('Failed Update', DATEDIFF(ms, @StartTime, GETDATE()), ERROR_MESSAGE());
END CATCH;
```

*   **Explanation:** Integrates `ROLLBACK` within `TRY...CATCH` and logs performance/error information specifically when a rollback occurs due to an exception.

## 3. Targeted Interview Questions (Based on `13_ROLLBACK.sql`)

**Question 1:** What is the primary difference in effect between `ROLLBACK TRANSACTION;` and `ROLLBACK TRANSACTION savepoint_name;`? Consider `@@TRANCOUNT`.

**Solution 1:**

*   `ROLLBACK TRANSACTION;` (Full Rollback): Undoes *all* work performed since the outermost `BEGIN TRANSACTION`. It terminates the transaction and resets `@@TRANCOUNT` to 0.
*   `ROLLBACK TRANSACTION savepoint_name;` (Partial Rollback): Undoes only the work performed *since* the specified savepoint was created. The transaction remains active, and `@@TRANCOUNT` is **not** changed. Work done before the savepoint is retained within the active transaction.

**Question 2:** In the "Nested Transaction ROLLBACK" example (section 4), the comment mentions `ROLLBACK TRANSACTION SubTran` is problematic. Why? What actually happens when it executes?

**Solution 2:**

*   **Why Problematic:** It's misleading because SQL Server doesn't truly roll back only the inner transaction scope independently when using `ROLLBACK TRANSACTION` without a savepoint name.
*   **What Happens:** Executing `ROLLBACK TRANSACTION` (even with the inner transaction's name, which is ignored for rollback scope) inside a nested transaction **rolls back the entire transaction stack** to the outermost `BEGIN TRANSACTION` and sets `@@TRANCOUNT` to 0. The outer transaction (`MainTran`) is also effectively rolled back at this point, even though the code might attempt to continue.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can you `COMMIT` a transaction *after* a `ROLLBACK` has been issued for it?
    *   **Answer:** No. Once `ROLLBACK TRANSACTION` (a full rollback) is executed, the transaction is terminated (`@@TRANCOUNT` becomes 0). Attempting to `COMMIT` afterward will result in an error because there is no active transaction to commit.
2.  **[Easy]** Does `ROLLBACK TRANSACTION savepoint_name` decrease the value of `@@TRANCOUNT`?
    *   **Answer:** No, rolling back to a savepoint does not change `@@TRANCOUNT`.
3.  **[Medium]** If an error occurs within a `TRY` block that contains a `BEGIN TRANSACTION`, but there is no `ROLLBACK` statement in the `CATCH` block, what happens to the transaction?
    *   **Answer:** The transaction remains active but may be in an uncommittable state (`XACT_STATE() = -1`) depending on the error. If the code exits the `CATCH` block and the session remains active, the transaction will stay open, holding locks until explicitly committed or rolled back, or until the session ends (at which point it will be automatically rolled back). This is why it's crucial to check `@@TRANCOUNT` or `XACT_STATE()` and issue a `ROLLBACK` within the `CATCH` block if a transaction is active.
4.  **[Medium]** Can you use `ROLLBACK` within a trigger? What are the potential consequences?
    *   **Answer:** Yes, you can issue `ROLLBACK TRANSACTION` within a trigger. However, doing so has significant consequences: it rolls back not only the work done within the trigger but also the DML statement (`INSERT`, `UPDATE`, `DELETE`) that *fired* the trigger. Furthermore, it typically aborts the entire batch of T-SQL code that contained the triggering DML statement. This can be unexpected and disruptive, so using `ROLLBACK` inside triggers should be done with extreme caution and usually only for critical validation failures where aborting the entire operation is the desired outcome. Often, raising an error (`THROW`) from the trigger is preferred, allowing outer `TRY...CATCH` blocks to handle the rollback.
5.  **[Medium]** What does `XACT_STATE()` return if called *outside* of any active transaction?
    *   **Answer:** 0.
6.  **[Medium]** Can you `ROLLBACK` DDL statements (like `CREATE TABLE`, `ALTER TABLE`) if they are executed within an explicit transaction?
    *   **Answer:** Yes, most DDL statements in SQL Server are transactional. If you execute `CREATE TABLE`, `ALTER TABLE`, `DROP INDEX`, etc., within a `BEGIN TRANSACTION ... ROLLBACK TRANSACTION` block, the DDL changes will be undone by the `ROLLBACK`. (Some older or specific DDL operations might have different behavior, but common ones are transactional).
7.  **[Hard]** What happens if you try to `ROLLBACK TRANSACTION savepoint_name` where `savepoint_name` was defined in an *outer* transaction scope relative to the current *inner* transaction scope?
    *   **Answer:** This will typically raise an error. You can only roll back to a savepoint that was defined within the current transaction nesting level or an outer level *relative to where the `ROLLBACK TO SAVEPOINT` command is issued*. You cannot reference a savepoint defined "outside" the scope from which you are trying to roll back in this manner. The savepoint must be "visible" from the point of the rollback command.
8.  **[Hard]** How does `ROLLBACK` affect temporary tables (`#temp`) created within the transaction? Are they dropped? Is their data removed?
    *   **Answer:** `ROLLBACK` does *not* drop temporary tables created within the transaction. The table structure (`#temp`) persists for the duration of the session (or procedure scope). However, any data modifications (`INSERT`, `UPDATE`, `DELETE`) performed on the temporary table *within the transaction being rolled back* **are undone**. The temporary table will revert to the state it was in at the beginning of the transaction (or the relevant savepoint).
9.  **[Hard]** If a transaction is marked as uncommittable (`XACT_STATE() = -1`), can you still execute `SELECT` statements within that transaction before rolling it back?
    *   **Answer:** Generally, yes. An uncommittable transaction typically still allows read operations (`SELECT`). However, it prevents any further operations that would need to write to the transaction log (like `INSERT`, `UPDATE`, `DELETE`, `COMMIT`, or even `SAVE TRANSACTION`). The only valid action to end the transaction is `ROLLBACK`.
10. **[Hard/Tricky]** Consider a scenario with `SET XACT_ABORT ON`. You have `BEGIN TRAN`, followed by Statement A (succeeds), then Statement B (fails with a constraint violation). Does execution continue to Statement C after Statement B, or does it jump directly to a `CATCH` block (if present)? What is the state of the transaction when the `CATCH` block is entered?
    *   **Answer:** With `SET XACT_ABORT ON`, when Statement B fails with the run-time error (constraint violation), SQL Server **immediately terminates the execution of the current batch** and **automatically initiates a rollback** of the entire transaction. Execution does *not* continue to Statement C. If a `TRY...CATCH` block is present, control jumps directly to the `CATCH` block. When the `CATCH` block is entered, the transaction is already being rolled back (or is fully rolled back), and `@@TRANCOUNT` will likely be 0 (or potentially 1 if nested within another transaction that remains). `XACT_STATE()` would likely be 0 or reflect the state of any outer transaction. The key effect of `XACT_ABORT ON` is the immediate termination and automatic rollback upon most run-time errors.
