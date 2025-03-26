# SQL Deep Dive: Transaction Savepoints (`SAVE TRANSACTION`)

## 1. Introduction: What are Savepoints?

While `BEGIN`, `COMMIT`, and `ROLLBACK` manage the entire scope of a transaction, SQL Server also provides **savepoints** using the `SAVE TRANSACTION savepoint_name` (or `SAVE TRAN savepoint_name`) command. A savepoint acts like a bookmark or an intermediate marker *within* an explicit transaction.

**Why use Savepoints?**

*   **Partial Rollback:** Their primary purpose is to allow you to roll back only a *portion* of a transaction – specifically, the work done *since* the savepoint was created – without aborting the entire transaction.
*   **Conditional Logic:** Useful in complex transactions where certain steps might fail or need to be undone based on conditions discovered later in the transaction, while still wanting to commit the work done before the savepoint.
*   **Error Handling in Batches:** Can be used within loops processing batches of data, allowing a single failed batch to be rolled back without discarding previously successful batches within the same overall transaction.

**Key Characteristics:**

*   Creates a named marker within an active transaction.
*   `ROLLBACK TRANSACTION savepoint_name` undoes changes made *after* the savepoint.
*   Rolling back to a savepoint does **not** end the transaction.
*   Rolling back to a savepoint does **not** decrement `@@TRANCOUNT`.
*   Locks acquired after the savepoint are typically released upon rollback to the savepoint, but locks acquired *before* the savepoint are retained.
*   Savepoint names should ideally be unique within a transaction, though reusing a name moves the savepoint marker.

**Syntax:**

```sql
BEGIN TRANSACTION;
    -- Operations A
    SAVE TRANSACTION MySavepoint1;
    -- Operations B
    SAVE TRANSACTION MySavepoint2;
    -- Operations C

    IF [Error in C] THEN
        ROLLBACK TRANSACTION MySavepoint2; -- Undoes C, keeps A & B
    ELSE IF [Error in B] THEN
        ROLLBACK TRANSACTION MySavepoint1; -- Undoes B & C, keeps A
    ELSE
        COMMIT TRANSACTION; -- Commits A, B, C
```

## 2. Savepoints in Action: Analysis of `14_SAVEPOINT.sql`

This script demonstrates practical applications of savepoints.

**a) Basic Savepoint**

```sql
BEGIN TRANSACTION;
    INSERT INTO HR.Departments (...);
    SAVE TRANSACTION DeptCreated; -- Set marker after INSERT
    UPDATE HR.EMP_Details SET DepartmentID = SCOPE_IDENTITY() WHERE ...;

    IF @@ERROR <> 0 -- Check if UPDATE failed
        ROLLBACK TRANSACTION DeptCreated; -- Undo ONLY the UPDATE
    ELSE
        COMMIT TRANSACTION; -- Commit INSERT (and UPDATE if successful)
```

*   **Explanation:** If the `UPDATE` fails, only the `UPDATE` is rolled back. The `INSERT` remains part of the active transaction, which is then committed (committing only the `INSERT` in this error path). If the `UPDATE` succeeds, both `INSERT` and `UPDATE` are committed.

**b) Multiple Savepoints**

```sql
BEGIN TRANSACTION;
    UPDATE HR.Departments SET Budget = Budget + 50000;
    SAVE TRANSACTION BudgetUpdate;
    UPDATE HR.EMP_Details SET Salary = Salary * 1.1;
    SAVE TRANSACTION SalaryUpdate;
    INSERT INTO HR.AuditLog (...);

    IF @@ERROR <> 0 -- Error in AuditLog INSERT?
        ROLLBACK TRANSACTION SalaryUpdate; -- Undo AuditLog INSERT and Salary UPDATE
    ELSE
        COMMIT TRANSACTION; -- Commit all three operations
```

*   **Explanation:** Creates two savepoints. If the final `INSERT` fails, the `ROLLBACK` undoes everything after `SalaryUpdate` (the `INSERT` and the salary `UPDATE`). The initial budget `UPDATE` (before `BudgetUpdate`) would still be committed by the final `COMMIT`.

**c) Nested Savepoints (within Nested Transactions)**

```sql
BEGIN TRANSACTION MainTran;
    INSERT INTO HR.Departments (...);
    SAVE TRANSACTION Level1Save; -- Savepoint in outer transaction
    BEGIN TRANSACTION SubTran; -- Nested transaction
        UPDATE HR.EMP_Details ...;
        SAVE TRANSACTION Level2Save; -- Savepoint in inner transaction
        INSERT INTO HR.AuditLog (...);
        IF @@ERROR <> 0
            ROLLBACK TRANSACTION Level2Save; -- Rolls back AuditLog INSERT (within SubTran)
    IF @@TRANCOUNT > 1 COMMIT TRANSACTION SubTran; -- 'Commits' inner tran (decrements @@TRANCOUNT)
    IF @@ERROR <> 0 -- Check error from SubTran or earlier
        ROLLBACK TRANSACTION Level1Save; -- Rolls back SubTran work and Dept INSERT
    ELSE
        COMMIT TRANSACTION MainTran; -- Commits everything successfully completed
```

*   **Explanation:** Shows savepoints can exist within nested transactions. `ROLLBACK TRANSACTION Level2Save` only affects work done within `SubTran` *after* `Level2Save`. `ROLLBACK TRANSACTION Level1Save` would undo everything done after `Level1Save`, including all work within `SubTran` (even if `SubTran` was 'committed'). Remember, only the outermost `COMMIT` is final.

**d) Savepoint with Conditional Logic**

```sql
BEGIN TRANSACTION;
    UPDATE HR.Departments SET Budget = Budget * 1.2;
    SAVE TRANSACTION BudgetIncrease;
    SELECT @CurrentBudget = SUM(Budget) FROM HR.Departments;
    IF @CurrentBudget > 5000000 BEGIN
        ROLLBACK TRANSACTION BudgetIncrease; -- Undo the 1.2 increase
        UPDATE HR.Departments SET Budget = Budget * 1.1; -- Apply smaller increase instead
    END
COMMIT TRANSACTION; -- Commit either the 1.2 increase or the 1.1 increase
```

*   **Explanation:** Applies a budget increase, saves the state. Then checks a condition. If the budget is too high, it rolls back the initial increase and applies a smaller one instead, before finally committing the valid state.

**e) Savepoint with Error Recovery (`TRY...CATCH`)**

```sql
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE HR.EMP_Details ...; -- Operation 1
        SAVE TRANSACTION SalaryUpdate;
        UPDATE HR.Departments ...; -- Operation 2 (depends on Op 1)
        IF @@ERROR <> 0 -- Check error specifically for Op 2
            ROLLBACK TRANSACTION SalaryUpdate; -- Undo Op 2 if it failed
    COMMIT TRANSACTION; -- Commit Op 1 (and Op 2 if successful)
END TRY
BEGIN CATCH
    -- If *any* error occurred (including potential commit failure or errors before savepoint)
    IF XACT_STATE() <> 0 -- Check if transaction is active/uncommittable
        ROLLBACK TRANSACTION; -- Full rollback if necessary
    INSERT INTO HR.ErrorLog (...);
END CATCH;
```

*   **Explanation:** Combines savepoints for partial internal rollback with a main `TRY...CATCH` for overall transaction integrity. If the second `UPDATE` fails, it's rolled back to the savepoint, and the `COMMIT` attempts to save the first `UPDATE`. If any other error occurs (e.g., the first `UPDATE` fails, or the `COMMIT` itself fails), the `CATCH` block ensures a full rollback.

**f) Savepoint with Batch Processing**

```sql
BEGIN TRANSACTION;
DECLARE @DeptID INT = 1;
WHILE @DeptID <= 5 BEGIN
    SAVE TRANSACTION DeptPoint; -- Savepoint before processing each department
    UPDATE HR.EMP_Details SET Salary = Salary * 1.1 WHERE DepartmentID = @DeptID;
    IF @@ERROR <> 0 BEGIN
        ROLLBACK TRANSACTION DeptPoint; -- Rollback only the failed department update
        INSERT INTO HR.ErrorLog (... 'Failed for Department: ' + ...);
    END
    SET @DeptID = @DeptID + 1;
END
COMMIT TRANSACTION; -- Commit updates for all successful departments
```

*   **Explanation:** Processes updates department by department within a single transaction. If an update for one department fails, only that department's update is rolled back using the savepoint, and the error is logged. The loop continues to the next department. The final `COMMIT` saves the updates for all departments that processed successfully.

**g) Savepoint with Data Validation**

```sql
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details SET Email = LOWER(Email);
    SAVE TRANSACTION EmailUpdate;
    IF EXISTS (SELECT 1 FROM HR.EMP_Details WHERE Email NOT LIKE '%@%.%') BEGIN
        ROLLBACK TRANSACTION EmailUpdate; -- Undo email update if validation fails
        THROW 50001, 'Invalid email format detected', 1;
    END
COMMIT TRANSACTION;
```

*   **Explanation:** Performs an update, creates a savepoint, then validates the result. If validation fails, the update is rolled back using the savepoint before an error is raised.

**h) Savepoint with Multiple Recovery Points**

```sql
BEGIN TRANSACTION;
    -- Stage 1
    UPDATE HR.Departments SET DepartmentName = UPPER(DepartmentName);
    SAVE TRANSACTION Stage1;
    -- Stage 2
    UPDATE HR.Departments SET Budget = Budget * 1.2;
    SAVE TRANSACTION Stage2;
    -- Stage 3
    UPDATE HR.EMP_Details SET Salary = Salary * 1.1;
    SAVE TRANSACTION Stage3;

    -- Validation checks
    IF (SELECT SUM(Budget) FROM HR.Departments) > 10000000
        ROLLBACK TRANSACTION Stage2; -- Undo Stage 3 and Stage 2
    ELSE IF (SELECT AVG(Salary) FROM HR.EMP_Details) > 100000
        ROLLBACK TRANSACTION Stage3; -- Undo only Stage 3
    ELSE
        COMMIT TRANSACTION; -- Commit Stages 1, 2, 3
```

*   **Explanation:** Creates multiple savepoints after logical stages. Validation checks at the end determine how far back to roll back (if at all) before committing the remaining valid changes.

**i) Savepoint with Dynamic SQL**

```sql
BEGIN TRANSACTION;
    DECLARE @SQL NVARCHAR(MAX) = N'UPDATE HR.EMP_Details SET ModifiedDate = GETDATE()';
    SAVE TRANSACTION BeforeUpdate; -- Savepoint before dynamic execution
    EXEC sp_executesql @SQL;
    IF @@ERROR <> 0
        ROLLBACK TRANSACTION BeforeUpdate; -- Rollback dynamic SQL if it failed
    ELSE
        COMMIT TRANSACTION;
```

*   **Explanation:** Demonstrates using a savepoint before executing dynamic SQL, allowing the dynamic operation to be rolled back if it fails, without affecting prior work in the transaction.

**j) Savepoint with Hierarchical Updates**

```sql
BEGIN TRANSACTION;
    UPDATE HR.Departments SET ManagerID = 1001 WHERE DepartmentID = 1; -- Update Parent
    SAVE TRANSACTION ParentUpdate;
    UPDATE HR.EMP_Details SET ReportsTo = 1001 WHERE DepartmentID = 1; -- Update Children

    IF @@ERROR <> 0 BEGIN
        ROLLBACK TRANSACTION ParentUpdate; -- Undo Children update AND Parent update
    END ELSE
        COMMIT TRANSACTION;
```

*   **Explanation:** Updates a parent record, saves state, then updates child records. If the child update fails, the `ROLLBACK` undoes both the child *and* the parent update (because the savepoint was after the parent update), ensuring consistency.

## 3. Targeted Interview Questions (Based on `14_SAVEPOINT.sql`)

**Question 1:** In section 1 ("Basic SAVEPOINT"), if the `UPDATE HR.EMP_Details` statement fails, is the `INSERT INTO HR.Departments` statement rolled back? Explain why or why not.

**Solution 1:** No, the `INSERT INTO HR.Departments` statement is **not** rolled back in the error path. The `ROLLBACK TRANSACTION DeptCreated` statement only rolls back the work performed *after* the `SAVE TRANSACTION DeptCreated` marker was set. Since the `INSERT` happened *before* the savepoint, it remains part of the active transaction. The subsequent `COMMIT TRANSACTION` (in the `ELSE` block, which is reached after the partial rollback) will commit the `INSERT`.

**Question 2:** Consider section 6 ("SAVEPOINT with Batch Processing"). If the `UPDATE` for `@DeptID = 3` fails, but the updates for `@DeptID = 1, 2, 4, 5` succeed, what is the final state of the data after the `COMMIT TRANSACTION` at the end?

**Solution 2:** The `COMMIT TRANSACTION` at the end will make the successful updates for departments 1, 2, 4, and 5 permanent. The failed update for department 3 was rolled back within the loop using `ROLLBACK TRANSACTION DeptPoint`, so the salaries for employees in department 3 remain unchanged. The transaction successfully commits the work done for the other departments.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What command is used to create a savepoint?
    *   **Answer:** `SAVE TRANSACTION savepoint_name` or `SAVE TRAN savepoint_name`.
2.  **[Easy]** Does rolling back to a savepoint end the transaction?
    *   **Answer:** No, the transaction remains active.
3.  **[Medium]** What happens to `@@TRANCOUNT` when you execute `SAVE TRANSACTION MySavepoint;`? What happens when you execute `ROLLBACK TRANSACTION MySavepoint;`?
    *   **Answer:** Neither `SAVE TRANSACTION` nor `ROLLBACK TRANSACTION savepoint_name` changes the value of `@@TRANCOUNT`.
4.  **[Medium]** Can you `COMMIT` to a savepoint? (e.g., `COMMIT TRANSACTION MySavepoint;`)
    *   **Answer:** No. `COMMIT` always applies to the entire transaction (specifically, the outermost transaction if nested). You cannot commit only up to a savepoint.
5.  **[Medium]** If you define two savepoints, `SP1` then `SP2`, and then execute `ROLLBACK TRANSACTION SP1;`, what happens to the work done between `SP1` and `SP2`, and the work done after `SP2`? Is `SP2` still a valid savepoint?
    *   **Answer:** Executing `ROLLBACK TRANSACTION SP1;` undoes all work performed *after* `SP1` was created. This includes the work done between `SP1` and `SP2`, *and* the work done after `SP2`. The savepoint `SP2` itself is also effectively discarded, as the transaction state has been rolled back to `SP1`; `SP2` is no longer a valid savepoint to roll back to later in the transaction.
6.  **[Medium]** Can savepoint names be variables (e.g., `DECLARE @spName VARCHAR(30) = 'SP1'; SAVE TRANSACTION @spName;`)?
    *   **Answer:** No, savepoint names must be valid identifiers or string literals. You cannot use a variable containing the name directly in the `SAVE TRANSACTION` or `ROLLBACK TRANSACTION savepoint_name` statements.
7.  **[Hard]** How are savepoints treated in relation to nested transactions? Can an inner transaction roll back to a savepoint defined in an outer transaction?
    *   **Answer:** Savepoints are local to the transaction nesting level where they are defined, but are "visible" to inner levels. An inner transaction *can* roll back to a savepoint defined in an outer transaction scope. However, doing so might have implications depending on subsequent commits or rollbacks in the outer scope. Rolling back to an outer savepoint from an inner scope still keeps the outer transaction active. Remember that a full `ROLLBACK` in an inner scope rolls back everything to the outermost `BEGIN TRAN`.
8.  **[Hard]** What happens to locks acquired *after* a savepoint if you roll back to that savepoint?
    *   **Answer:** Locks acquired *after* the savepoint was established are generally released when you roll back to that savepoint. However, locks acquired *before* the savepoint remain held, as the transaction itself is still active.
9.  **[Hard]** Is there a limit to the number of savepoints you can create within a single transaction? Are there performance implications?
    *   **Answer:** There is no predefined limit to the number of savepoints within a transaction imposed by SQL Server itself, other than available memory. However, creating an excessive number of savepoints can consume memory (as SQL Server needs to track them) and potentially add slight overhead to transaction management. While useful, they should be used judiciously where partial rollback logic is genuinely needed, not created unnecessarily.
10. **[Hard/Tricky]** If you `ROLLBACK TRANSACTION MySavepoint;` and then later issue a full `ROLLBACK TRANSACTION;` before committing, what work is ultimately undone?
    *   **Answer:** The full `ROLLBACK TRANSACTION;` undoes *all* work performed since the outermost `BEGIN TRANSACTION`. The earlier rollback to `MySavepoint` undid the work *after* the savepoint at that time, but the final full `ROLLBACK` ensures that even the work done *before* `MySavepoint` is also undone. The net effect is the same as if only the final full `ROLLBACK TRANSACTION;` had been issued.
