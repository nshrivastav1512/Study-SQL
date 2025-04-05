# SQL Deep Dive: Control-of-Flow Statements

## 1. Introduction: What are Control-of-Flow Statements?

Control-of-flow statements in Transact-SQL (T-SQL) allow you to direct the execution path of your code based on specific conditions, implement looping logic, handle errors, and introduce delays. They bring procedural programming capabilities into the set-based world of SQL, enabling more complex logic within stored procedures, functions, triggers, and scripts.

**Key Control-of-Flow Statements:**

*   **`BEGIN...END`:** Defines a block of T-SQL statements that are executed together. Required for `IF`, `ELSE`, and `WHILE` when they contain more than one statement.
*   **`IF...ELSE`:** Executes a block of statements conditionally based on whether a Boolean expression evaluates to TRUE.
*   **`CASE`:** Evaluates a list of conditions and returns one of multiple possible result expressions. Used within other statements (like `SELECT`, `UPDATE`, `ORDER BY`) or as a standalone control statement (less common).
*   **`WHILE`:** Repeats a block of statements as long as a specified condition is TRUE.
*   **`BREAK`:** Exits the innermost `WHILE` loop immediately.
*   **`CONTINUE`:** Skips the remaining statements in the current `WHILE` loop iteration and proceeds to the next iteration.
*   **`TRY...CATCH`:** Implements error handling. Executes statements in the `TRY` block; if an error occurs, control jumps to the `CATCH` block.
*   **`WAITFOR`:** Pauses execution until a specified time (`WAITFOR TIME`) or after a specified duration (`WAITFOR DELAY`).
*   **`GOTO label`:** Unconditionally transfers execution to a specific label within the batch or procedure (generally discouraged as it leads to unstructured code).
*   **`RETURN`:** Exits unconditionally from a query, stored procedure, or batch. Can return an integer status value from procedures.
*   **`THROW`:** Raises an exception (error) that can be caught by a `CATCH` block. Preferred over `RAISERROR` in modern SQL Server versions.

## 2. Control Statements in Action: Analysis of `105_CONTROL_STATEMENTS.sql`

This script demonstrates several key control-of-flow statements.

**Part 1: `IF...ELSE` Statements**

*   **Basic Structure:** Shows the simple `IF (condition) BEGIN ... END ELSE BEGIN ... END` syntax for conditional execution.
*   **Nested `IF...ELSE`:** Demonstrates complex, multi-level conditional logic within a stored procedure (`HR.UpdateOnboardingStatus`) to determine an employee's onboarding status based on the completion of several prerequisite steps.
*   **`IF EXISTS`:** A common pattern to check for the existence of an object (like a table) before attempting to create or modify it, preventing errors.
*   **Complex Conditions:** Uses `IF...ELSE IF...ELSE` within a procedure (`HR.ApproveSalaryAdjustment`) to implement business rules with multiple thresholds (e.g., different approval levels based on percentage salary increase).

**Part 2: `CASE` Statements**

*   **Simple `CASE`:** Used in a `SELECT` statement to translate `PerformanceRating` numeric codes into meaningful descriptions ('Outstanding', 'Exceeds Expectations', etc.). Compares one expression against multiple values.
*   **Searched `CASE`:** Used in an `UPDATE` statement (`HR.CalculatePerformanceBonuses`) to assign different `BonusPercentage` values based on various conditions (`WHEN PerformanceRating = 5 THEN ... WHEN PerformanceRating = 4 THEN ...`). Evaluates multiple Boolean conditions.
*   **`CASE` in `ORDER BY`:** Demonstrates using `CASE` to implement custom sorting logic (e.g., ensuring 'Human Resources' department always appears first, then sorting others by average rating).
*   **Nested `CASE`:** Shows nesting `CASE` expressions to handle complex categorization based on multiple criteria (e.g., categorizing employee performance based on both salary level and performance rating).

**Part 3: `WHILE` Loops**

*   **Basic `WHILE` Loop:** Implements batch payroll processing (`HR.ProcessPayrollBatch`). The loop continues as long as there are pending employees (`WHILE @ProcessedCount < @EmployeeCount`). Inside the loop, one employee is processed at a time. *Note: This example uses a cursor-like approach within the loop (`SELECT TOP 1 ... WHERE ProcessingStatus = 'Pending'`). While demonstrating `WHILE`, this specific task might be better handled with set-based operations if possible, but it illustrates the looping concept.*
*   **`WHILE` with `BREAK`:** Audits employee salaries (`HR.AuditEmployeeSalaries`) using a cursor within a `WHILE` loop. If a maximum number of discrepancies (`@MaxDiscrepancies`) is found, `BREAK` is used to exit the loop prematurely.
*   **`WHILE` with `CONTINUE`:** Processes leave accrual (`HR.ProcessAnnualLeaveAccrual`). Inside the loop, if an employee is on probation (`DATEDIFF(...) < 6`), `CONTINUE` is used to skip the rest of the current iteration (accrual calculation and update) and proceed directly to the next employee.

**Part 4: `TRY...CATCH` Error Handling**

*   **Basic `TRY...CATCH`:** Wraps an `UPDATE` and `INSERT` within a transaction inside a `TRY` block (`HR.UpdateEmployeeSalary`). If any statement in the `TRY` block fails (e.g., due to validation `THROW` or constraint violation), control jumps to the `CATCH` block, which rolls back the transaction, logs/prints error details (using `ERROR_MESSAGE()`, `ERROR_SEVERITY()`, etc.), and re-throws the error.
*   **Nested `TRY...CATCH`:** Demonstrates nesting `TRY...CATCH` blocks (`HR.TransferEmployee`), allowing for more granular error handling within different stages of a complex operation, potentially handling specific errors differently in the inner `CATCH` before potentially re-throwing to the outer `CATCH`.

**Part 5: `WAITFOR` Statement**

*   **`WAITFOR DELAY`:** Pauses execution for a specific duration (e.g., `WAITFOR DELAY '00:00:02';` pauses for 2 seconds). Used in the script to simulate processing time.
*   **`WAITFOR TIME`:** Pauses execution *until* a specific time of day is reached (e.g., `WAITFOR TIME '22:00:00';`). Used conceptually in `HR.ScheduleDailyReports` (though SQL Agent is the proper tool for scheduling).

**Part 6: Best Practices**

*   Emphasizes using `BEGIN...END` for clarity, proper error handling (`TRY...CATCH`), transaction management, avoiding infinite loops, modularity, documentation, and considering performance implications.

## 3. Targeted Interview Questions (Based on `105_CONTROL_STATEMENTS.sql`)

**Question 1:** What is the difference between a simple `CASE` expression and a searched `CASE` expression? Provide a brief example syntax for each.

**Solution 1:**
*   **Simple `CASE`:** Compares a single input expression against a set of specific values.
    ```sql
    CASE InputExpression
        WHEN Value1 THEN Result1
        WHEN Value2 THEN Result2
        ELSE DefaultResult
    END
    ```
*   **Searched `CASE`:** Evaluates a series of independent Boolean conditions. The result corresponding to the *first* condition that evaluates to TRUE is returned.
    ```sql
    CASE
        WHEN BooleanCondition1 THEN Result1
        WHEN BooleanCondition2 THEN Result2
        ELSE DefaultResult
    END
    ```

**Question 2:** Explain the purpose of `BREAK` and `CONTINUE` within a `WHILE` loop.

**Solution 2:**
*   **`BREAK`:** Immediately terminates the innermost `WHILE` loop in which it is placed. Execution continues with the statement immediately following the `END` of the loop.
*   **`CONTINUE`:** Skips the remaining statements in the *current iteration* of the innermost `WHILE` loop and jumps directly to the beginning of the next iteration, re-evaluating the loop's condition.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which statement block is executed if the condition in an `IF` statement is FALSE?
    *   **Answer:** The `ELSE` block (if present).
2.  **[Easy]** What statement is commonly used to implement robust error handling in T-SQL?
    *   **Answer:** `TRY...CATCH`.
3.  **[Medium]** Is a `BEGIN...END` block required after `IF` or `WHILE` if there is only one statement to execute conditionally or repeatedly?
    *   **Answer:** No. If only a single statement follows `IF`, `ELSE`, or `WHILE`, the `BEGIN...END` block is optional. However, using `BEGIN...END` even for single statements is often recommended for clarity and to prevent errors if more statements are added later.
4.  **[Medium]** What happens if the condition in a `WHILE` loop never becomes FALSE?
    *   **Answer:** An infinite loop occurs. The code block inside the `WHILE` will execute repeatedly, potentially consuming significant server resources, until manually interrupted (e.g., by cancelling the query or killing the session). It's crucial to ensure the loop condition will eventually become FALSE or use `BREAK`.
5.  **[Medium]** Can you use `GOTO` to jump *into* the middle of an `IF` block or `WHILE` loop?
    *   **Answer:** No. `GOTO` can only jump to a defined label within the same batch, procedure, function, or trigger. It cannot jump into nested structures like `IF` or `WHILE` blocks from outside them. (Using `GOTO` is generally discouraged anyway).
6.  **[Medium]** What are the `ERROR_*` functions available within a `CATCH` block (name a few)?
    *   **Answer:** `ERROR_NUMBER()` (error code), `ERROR_MESSAGE()` (error text), `ERROR_SEVERITY()` (severity level), `ERROR_STATE()` (error state), `ERROR_LINE()` (line number where error occurred), `ERROR_PROCEDURE()` (procedure/trigger where error occurred).
7.  **[Hard]** How does transaction handling interact with `TRY...CATCH`? If an error occurs inside a `TRY` block after `BEGIN TRANSACTION`, is the transaction automatically rolled back when control enters the `CATCH` block?
    *   **Answer:** No, the transaction is **not** automatically rolled back just by entering the `CATCH` block. The transaction remains active (though potentially in an uncommittable state, `XACT_STATE() = -1`) depending on the error. It is the responsibility of the code within the `CATCH` block to check the transaction state (using `@@TRANCOUNT > 0` or `XACT_STATE() <> 0`) and explicitly issue a `ROLLBACK TRANSACTION` if necessary. (The exception is if `SET XACT_ABORT ON` is active, which *does* cause automatic rollback upon most errors).
8.  **[Hard]** Can you use `WAITFOR DELAY` to pause execution for fractions of a second?
    *   **Answer:** Yes. The time format for `WAITFOR DELAY` is 'hh:mm:ss.fff' (where fff represents milliseconds). You can specify delays like `'00:00:00.500'` for half a second or `'00:00:00.010'` for 10 milliseconds. However, the actual precision and granularity depend on the operating system scheduler.
9.  **[Hard]** What is the difference between `RETURN` and `THROW` when used inside a stored procedure?
    *   **Answer:**
        *   `RETURN [integer_value]`: Immediately exits the stored procedure (or batch). It can optionally return an integer status code to the caller (default is 0). It does *not* inherently signal an error condition to a calling `TRY...CATCH` block unless the caller explicitly checks the return code.
        *   `THROW [error_number, message, state]`: Raises a run-time error. If executed within a `TRY` block, it transfers control to the corresponding `CATCH` block. If executed outside a `TRY` block or re-thrown from a `CATCH` block, it terminates the batch and returns the error details to the client or calling application. It's the modern and preferred way to signal error conditions.
10. **[Hard/Tricky]** Can you use control-of-flow statements like `IF` or `WHILE` within an inline table-valued function (ITVF)?
    *   **Answer:** No. Inline table-valued functions are restricted to a single `SELECT` statement within the `RETURN` clause. They cannot contain procedural logic like variable assignments, `IF` statements, `WHILE` loops, cursors, temporary tables, etc. For such logic within a function, you must use a multi-statement table-valued function (MSTVF) or a stored procedure.
