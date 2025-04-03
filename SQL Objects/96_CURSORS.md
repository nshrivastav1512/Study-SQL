# SQL Deep Dive: Cursors

## 1. Introduction: What are Cursors?

In SQL, operations are typically **set-based**, meaning a single statement (like `UPDATE`, `DELETE`, `SELECT`) operates on a set of rows that meet the specified criteria. However, there are scenarios where you might need to process data **row by row** (or row-at-a-time). This is where **Cursors** come in.

A cursor is a database object that allows you to traverse the rows returned by a query one at a time and perform actions on each individual row. Think of it like iterating through a list in a procedural programming language.

**Why Use Cursors? (Use with Caution!)**

*   **Row-by-Row Logic:** Necessary for complex procedural logic that cannot be easily expressed in a single set-based SQL statement (e.g., calling a stored procedure for each row with different parameters based on the row's data, performing complex sequential calculations).
*   **Legacy Code:** Sometimes encountered in older codebases written before modern set-based alternatives (like window functions) were widely available or understood.
*   **Specific Administrative Tasks:** Occasionally used for certain administrative tasks involving iterating through database objects or metadata.

**Why Avoid Cursors? (Performance Impact)**

*   **Performance Overhead:** Cursors are generally **much slower** and more resource-intensive than equivalent set-based operations. Processing row by row incurs significant overhead (fetching, locking, procedure calls per row).
*   **Increased Locking/Blocking:** Depending on the cursor type and operations performed within the loop, cursors can hold locks longer, increasing blocking and reducing concurrency.
*   **Complexity:** Cursor logic (DECLARE, OPEN, FETCH, CLOSE, DEALLOCATE) can make code more verbose and harder to read and maintain compared to concise set-based queries.
*   **Alternatives Often Exist:** In most modern SQL Server versions, many problems previously solved with cursors can now be handled more efficiently using set-based approaches like window functions (`LAG`, `LEAD`, `ROW_NUMBER`), recursive CTEs, `MERGE` statements, or `APPLY` operators. **Always look for a set-based alternative first!**

**Cursor Lifecycle:**

1.  **`DECLARE`:** Define the cursor name and the `SELECT` statement that determines the rows the cursor will iterate over. Specify cursor options (type, scope, etc.).
2.  **`OPEN`:** Execute the `SELECT` statement and populate the cursor with the result set.
3.  **`FETCH NEXT FROM ... INTO ...`:** Retrieve the next row from the cursor and load its column values into specified variables.
4.  **Process Row:** Perform actions based on the values in the variables (often within a `WHILE @@FETCH_STATUS = 0` loop).
5.  **`CLOSE`:** Release the current result set and locks held by the cursor. The cursor definition still exists.
6.  **`DEALLOCATE`:** Remove the cursor definition entirely, freeing up resources.

## 2. Cursors in Action: Analysis of `96_CURSORS.sql`

This script demonstrates various aspects of cursor usage.

**a) Basic Cursor Example**

```sql
DECLARE @EmployeeID INT, @FirstName NVARCHAR(50), @Salary DECIMAL(10,2);
-- 1. DECLARE cursor for specific employees
DECLARE employee_cursor CURSOR FOR
    SELECT EmployeeID, FirstName, Salary FROM HR.Employees WHERE DepartmentID = 10;
-- 2. OPEN the cursor
OPEN employee_cursor;
-- 3. FETCH the first row
FETCH NEXT FROM employee_cursor INTO @EmployeeID, @FirstName, @Salary;
-- 4. Loop while fetch is successful
WHILE @@FETCH_STATUS = 0 BEGIN
    PRINT 'Processing employee: ' + @FirstName;
    -- Perform row-by-row operation (e.g., UPDATE)
    UPDATE HR.Employees SET Salary = Salary * 1.05 WHERE EmployeeID = @EmployeeID;
    -- Fetch the next row
    FETCH NEXT FROM employee_cursor INTO @EmployeeID, @FirstName, @Salary;
END
-- 5. CLOSE the cursor
CLOSE employee_cursor;
-- 6. DEALLOCATE the cursor
DEALLOCATE employee_cursor;
```

*   **Explanation:** A classic example of iterating through employees in Department 10 and applying a 5% salary increase one by one. `@@FETCH_STATUS = 0` indicates a successful fetch. The loop continues until `FETCH NEXT` fails to retrieve a row. **Note:** This specific update could easily be done with a single, much more efficient set-based `UPDATE` statement (shown in Part 9).

**b) Different Cursor Types**

*   `STATIC`: Creates a temporary copy (snapshot) of the data in `tempdb`. Doesn't reflect changes made to base tables after the cursor is opened. Supports scrolling.
*   `DYNAMIC`: Reflects all changes (inserts, updates, deletes) made to the base tables while the cursor is open. Most resource-intensive. Supports scrolling.
*   `FORWARD_ONLY`: (Default if not specified) Can only move forward (`FETCH NEXT`). Cannot scroll backward. Can be `STATIC`, `KEYSET`, or `DYNAMIC` implicitly.
*   `FAST_FORWARD`: An optimized `FORWARD_ONLY`, `READ_ONLY` cursor. Generally offers the best performance when only forward iteration is needed.
*   `KEYSET`: The set of keys identifying the rows is fixed when the cursor is opened. Reflects updates to non-key values in base tables but not new inserts. Deletes of rows in the keyset become visible. Supports scrolling.
*   `SCROLL`: Allows fetching rows in any order (`FIRST`, `LAST`, `PRIOR`, `RELATIVE`, `ABSOLUTE`). Can be `STATIC`, `KEYSET`, or `DYNAMIC`.

**c) Cursor Variables**

```sql
DECLARE @MyCursor CURSOR;
SET @MyCursor = CURSOR FAST_FORWARD FOR SELECT EmployeeID FROM HR.Employees;
-- Can now OPEN, FETCH, CLOSE, DEALLOCATE @MyCursor
```

*   **Explanation:** Allows assigning a cursor to a variable, useful for passing cursors as parameters to stored procedures or functions.

**d) Nested Cursors**

*   Demonstrates opening one cursor (`dept_cursor`) and, inside its loop, opening another cursor (`emp_cursor`) to process related data for each outer row.
*   **Caution:** Nested cursors significantly increase complexity and performance overhead. They should be avoided if possible, often replaceable by joins or other set-based techniques.

**e) Cursor Attributes/Options**

```sql
DECLARE custom_cursor CURSOR
    LOCAL | GLOBAL          -- Scope: Batch/Proc vs Connection
    FORWARD_ONLY | SCROLL   -- Scrollability
    STATIC | KEYSET | DYNAMIC | FAST_FORWARD -- Type (sensitivity to changes)
    READ_ONLY | SCROLL_LOCKS | OPTIMISTIC -- Locking/Concurrency
    TYPE_WARNING            -- Warn if type implicitly converted
FOR SELECT ...;
```

*   **Explanation:** Shows various options specified during `DECLARE CURSOR` to control its behavior regarding scope, scrolling, sensitivity to underlying data changes, and locking. `FAST_FORWARD` is often the best choice for simple iteration (`FORWARD_ONLY`, `READ_ONLY`).

**f) Performance Best Practices**

*   Use `SET NOCOUNT ON` (reduces network traffic by suppressing "rows affected" messages).
*   Use `FAST_FORWARD` cursors whenever possible.
*   Avoid cursors entirely if a set-based alternative exists.
*   If using cursors, minimize work done inside the loop.
*   Fetch only necessary columns into variables.

**g) Error Handling with Cursors**

*   Demonstrates using `TRY...CATCH` blocks both *inside* the cursor loop (to handle errors processing a single row and potentially continue) and *outside* the loop (to handle errors opening/fetching from the cursor itself). Includes checking `CURSOR_STATUS` before attempting `CLOSE`/`DEALLOCATE` in the outer `CATCH`.

**h) Common Cursor Operations (`FETCH`)**

*   Shows various `FETCH` options available for `SCROLL` cursors (`FIRST`, `LAST`, `PRIOR`, `ABSOLUTE n`, `RELATIVE n`).

**i) Alternatives to Cursors**

*   **Set-Based DML:** Shows the simple `UPDATE` equivalent to the basic cursor example.
*   **Window Functions:** Demonstrates `LAG()` and `LEAD()` to access previous/next row values without a cursor.
*   **Recursive CTEs:** Shows using a recursive Common Table Expression to traverse hierarchical data (like an org chart), often replacing recursive cursor logic.

## 3. Targeted Interview Questions (Based on `96_CURSORS.sql`)

**Question 1:** What is the primary drawback of using cursors compared to set-based operations in SQL?

**Solution 1:** The primary drawback is **performance**. Cursors process data row by row, which incurs significant overhead for each row (fetching, locking, potential procedure calls) and is generally much slower and more resource-intensive than set-based operations (`SELECT`, `UPDATE`, `INSERT`, `DELETE`, `MERGE`) that operate on multiple rows simultaneously.

**Question 2:** The script shows `CLOSE employee_cursor;` and `DEALLOCATE employee_cursor;`. What is the difference between these two commands?

**Solution 2:**
*   `CLOSE`: Releases the current result set and any locks held by the cursor. The cursor definition still exists, and it can potentially be reopened (`OPEN`) later within the same scope.
*   `DEALLOCATE`: Removes the cursor reference and its definition entirely, freeing up all associated resources. The cursor cannot be reopened after being deallocated. It's essential to deallocate cursors when finished to avoid resource leaks.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What system function checks the status of the last `FETCH` operation from a cursor? What value indicates success?
    *   **Answer:** `@@FETCH_STATUS`. A value of `0` indicates success.
2.  **[Easy]** Which cursor type generally offers the best performance for simple forward iteration without needing to see data changes?
    *   **Answer:** `FAST_FORWARD` (which is implicitly `FORWARD_ONLY` and `READ_ONLY`).
3.  **[Medium]** What is the difference between a `STATIC` and a `DYNAMIC` cursor regarding visibility of data changes made by other transactions?
    *   **Answer:**
        *   `STATIC`: Works on a snapshot of the data taken when the cursor is opened (stored in `tempdb`). It does *not* see any changes (inserts, updates, deletes) made to the base tables by other transactions after it was opened.
        *   `DYNAMIC`: Fully reflects all committed changes made to the base tables while the cursor is open. Fetching the same row again might show different data if updated, and new rows inserted might appear (or disappear if deleted) depending on fetch order. It's the most resource-intensive type.
4.  **[Medium]** Can you perform `UPDATE` or `DELETE` operations directly through a cursor? If so, what clause is used?
    *   **Answer:** Yes, if the cursor is updateable (not `READ_ONLY`, and based on a query that supports updates). You use the `WHERE CURRENT OF cursor_name` clause in your `UPDATE` or `DELETE` statement to target the single row most recently fetched by the specified cursor. Example: `UPDATE MyTable SET ColumnA = 'NewValue' WHERE CURRENT OF MyCursor;`.
5.  **[Medium]** What does `CURSOR_STATUS('global', 'cursor_name')` or `CURSOR_STATUS('local', 'cursor_name')` return?
    *   **Answer:** It returns an integer indicating the status of the specified cursor: >= 1 (cursor exists and is open, value indicates number of rows), 0 (cursor exists but is closed), -1 (cursor exists but has no rows or is closed), -2 (cursor variable assigned but no cursor allocated), -3 (cursor does not exist). Useful for checking if `CLOSE`/`DEALLOCATE` is needed, especially in error handlers.
6.  **[Medium]** Why is using `SET NOCOUNT ON` recommended when working with cursors (and often in general)?
    *   **Answer:** `SET NOCOUNT ON` prevents SQL Server from sending the "N rows affected" message back to the client after each DML statement (`INSERT`, `UPDATE`, `DELETE`). Inside a cursor loop where DML might execute for every row, suppressing these messages significantly reduces network traffic and can improve performance, especially when processing many rows.
7.  **[Hard]** What is a `KEYSET` cursor, and how does its visibility of changes differ from `STATIC` and `DYNAMIC`?
    *   **Answer:** A `KEYSET` cursor fixes the set of rows (identified by their unique keys) that belong to the cursor when it's opened. The keys are stored in `tempdb`.
        *   **Visibility:** It *does* reflect updates to non-key column values in the base tables for rows within the keyset. It *does* reflect deletions of rows within the keyset (attempting to fetch a deleted row returns `@@FETCH_STATUS = -2`). It does *not* see new rows inserted into the base tables after the cursor was opened, even if they match the cursor's `SELECT` criteria.
8.  **[Hard]** Can you use window functions like `ROW_NUMBER()` as a viable alternative to cursors for tasks requiring row-by-row context (like finding previous/next values or calculating running totals)?
    *   **Answer:** Yes, absolutely. Window functions (`ROW_NUMBER`, `RANK`, `DENSE_RANK`, `LAG`, `LEAD`, `SUM() OVER (...)`, etc.) are powerful set-based alternatives that can solve many problems previously requiring cursors, usually with much better performance. They allow calculations across a set of table rows that are somehow related to the current row, without the overhead of row-by-row iteration.
9.  **[Hard]** What potential locking issues can arise from using cursors, especially updateable ones (`SCROLL_LOCKS` or `OPTIMISTIC`)?
    *   **Answer:** Updateable cursors need to lock the row they are positioned on to allow `UPDATE ... WHERE CURRENT OF` operations.
        *   `SCROLL_LOCKS`: Acquires update locks on rows as they are fetched, holding them until the next fetch or transaction end. This provides high consistency but can cause significant blocking for other users trying to access the fetched rows.
        *   `OPTIMISTIC`: Does not take locks when rows are fetched. Instead, when an `UPDATE/DELETE WHERE CURRENT OF` is attempted, it checks if the row has been modified by another transaction since it was fetched (using timestamp or checksum comparison). If modified, the update/delete fails. This increases concurrency but requires handling potential update failures.
        *   Even `READ_ONLY` cursors under higher isolation levels (`REPEATABLE READ`, `SERIALIZABLE`) can hold shared locks longer than set-based queries, potentially increasing blocking.
10. **[Hard/Tricky]** Is it possible for `@@FETCH_STATUS` to return a value other than 0 (success), -1 (failure/beyond end), or -2 (row missing in keyset)?
    *   **Answer:** Yes. While 0, -1, and -2 are the most common, `@@FETCH_STATUS` can also return -9, indicating that the cursor option `CURSOR_ON_COMMIT` is set to `OFF` (the default) and an `UPDATE` or `DELETE WHERE CURRENT OF` operation failed because the cursor was closed due to a `COMMIT` or `ROLLBACK` occurring after the row was fetched but before the modification attempt. This is a less common scenario related to specific cursor options and transaction handling.
