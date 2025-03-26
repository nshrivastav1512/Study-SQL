# SQL Deep Dive: Set Operations (`UNION`, `INTERSECT`, `EXCEPT`)

## 1. Introduction: Combining Result Sets

While `JOIN` combines columns from different tables based on related rows, **set operators** combine rows from two or more `SELECT` statements (queries) into a single result set. They operate vertically, stacking results from compatible queries on top of each other or finding common/different rows between them.

**Why use Set Operations?**

*   **Combining Similar Data:** Merge lists from different tables or queries that represent similar entities (e.g., current employees and former employees, active customers and prospective customers).
*   **Finding Commonality:** Identify rows that exist in multiple datasets (`INTERSECT`).
*   **Finding Differences:** Identify rows that exist in one dataset but not another (`EXCEPT`).
*   **Report Generation:** Combine detail rows with summary rows in a single report.

**Key Requirements:**

1.  **Number of Columns:** All `SELECT` statements combined by a set operator must have the **same number of columns** in their select lists.
2.  **Data Type Compatibility:** The data types of corresponding columns in each `SELECT` statement must be **compatible** (either the same or implicitly convertible).
3.  **Ordering:** `ORDER BY` can only be applied once at the very end of the combined statement to sort the final result set. Column names used in `ORDER BY` refer to the column names/aliases from the *first* `SELECT` statement.

**Set Operators:**

*   `UNION`: Combines results and **removes duplicate rows**.
*   `UNION ALL`: Combines results and **keeps all duplicate rows**. Generally faster than `UNION`.
*   `INTERSECT`: Returns only rows that appear in **both** result sets. Removes duplicates.
*   `EXCEPT`: Returns distinct rows from the **first** result set that do **not** appear in the **second** result set. Removes duplicates.

## 2. Set Operations in Action: Analysis of `34_select_set_operations.sql`

This script demonstrates the usage of the four main set operators.

**a) `UNION`**

```sql
SELECT EmployeeID, FirstName, LastName, 'Current' AS Status FROM HR.EMP_Details
UNION
SELECT EmployeeID, FirstName, LastName, 'Former' AS Status FROM HR.FormerEmployees;
```

*   **Explanation:** Combines the list of current employees with the list of former employees. If any employee somehow exists in both source tables with identical selected columns, they will appear only **once** in the final result because `UNION` removes duplicates.

**b) `UNION ALL`**

```sql
SELECT DepartmentID, 'Has Employees' AS Status FROM HR.EMP_Details
UNION ALL
SELECT DepartmentID, 'Has Budget' AS Status FROM HR.DepartmentBudgets;
```

*   **Explanation:** Combines lists of department IDs. If a department ID exists in both source queries (meaning it has employees AND a budget), it will appear **twice** in the result set because `UNION ALL` retains all rows, including duplicates. It's faster than `UNION` as it skips the duplicate removal step.

**c) `INTERSECT`**

```sql
SELECT DepartmentID FROM HR.EMP_Details
INTERSECT
SELECT DepartmentID FROM HR.DepartmentBudgets;
```

*   **Explanation:** Returns only those `DepartmentID` values that are present in *both* the `HR.EMP_Details` table *and* the `HR.DepartmentBudgets` table. Effectively finds departments that have both employees and budgets. Duplicates within the final result are removed.

**d) `EXCEPT`**

```sql
SELECT DepartmentID FROM HR.Departments -- Query 1
EXCEPT
SELECT DepartmentID FROM HR.EMP_Details; -- Query 2
```

*   **Explanation:** Returns distinct `DepartmentID` values that exist in the result of the *first* query (`HR.Departments`) but *not* in the result of the *second* query (`HR.EMP_Details`). This finds departments that exist but currently have no employees listed in the details table.

**e) Combining Multiple Set Operations**

```sql
SELECT DepartmentID, 'Has Employees' AS Status FROM HR.EMP_Details
UNION ALL
SELECT DepartmentID, 'Has Budget' AS Status FROM HR.DepartmentBudgets
EXCEPT -- Applied to the result of the UNION ALL
SELECT DepartmentID, 'Has Budget' AS Status FROM HR.InactiveDepartments;
```

*   **Explanation:** Demonstrates combining operators. SQL Server typically evaluates them from top to bottom unless parentheses `()` are used to enforce a different order. Here, `UNION ALL` runs first, then `EXCEPT` removes rows from the combined result that match the `InactiveDepartments` query.

**f) Set Operations with `ORDER BY`**

```sql
(SELECT EmployeeID, ... FROM HR.EMP_Details WHERE DepartmentID = 1)
UNION
(SELECT EmployeeID, ... FROM HR.EMP_Details WHERE DepartmentID = 2)
ORDER BY HireDate DESC; -- Applied to the final combined result
```

*   **Explanation:** `ORDER BY` is placed at the very end of the entire statement involving set operators. It sorts the final, combined result set. Parentheses around the individual `SELECT` statements are often used for clarity but aren't always strictly required before the `UNION`/`INTERSECT`/`EXCEPT`.

**g) Set Operations with Different Column Names**

```sql
SELECT EmployeeID, ..., Salary AS Compensation FROM HR.EMP_Details -- Alias used
UNION
SELECT EmployeeID, ..., ContractAmount FROM HR.Contractors;
```

*   **Explanation:** The column names (or aliases) used in the final result set are determined by the **first** `SELECT` statement. The `ContractAmount` from the second query will appear under the `Compensation` column heading. The data types must still be compatible.

**h) Set Operations with Expressions**

```sql
SELECT EmployeeID, FirstName + ' ' + LastName AS FullName, 'Employee' AS Type FROM HR.EMP_Details
UNION
SELECT VendorID, VendorName, 'Vendor' AS Type FROM HR.Vendors;
```

*   **Explanation:** Shows that expressions and literal values can be used in the select lists, as long as the number of columns and their resulting data types are compatible across all combined queries.

**i) `INTERSECT` with Multiple Conditions (via multiple INTERSECTs)**

```sql
SELECT EmployeeID FROM HR.EMP_Details WHERE Salary > 70000
INTERSECT
SELECT EmployeeID FROM HR.EMP_Details WHERE DepartmentID = 2
INTERSECT
SELECT EmployeeID FROM HR.PerformanceReviews WHERE Rating > 4;
```

*   **Explanation:** Finds `EmployeeID`s that satisfy *all three* conditions by intersecting the results of three separate queries, each applying one condition.

**j) `EXCEPT` with Subqueries (Illustrative)**

```sql
-- Find departments that DO have employees
SELECT DepartmentID, DepartmentName FROM HR.Departments
WHERE DepartmentID NOT IN ( -- Exclude departments that DON'T have employees
    SELECT DepartmentID FROM HR.Departments -- All departments
    EXCEPT
    SELECT DepartmentID FROM HR.EMP_Details -- Departments that DO have employees
    -- Inner EXCEPT returns departments WITHOUT employees
);
```

*   **Explanation:** A slightly complex way to find departments *with* employees. The inner `EXCEPT` finds departments *without* employees. The outer query then selects departments whose ID is *not in* the list of departments without employees. A simple `INNER JOIN` or `EXISTS` would usually be clearer for this specific goal.

**k) Set Operations for Report Generation**

```sql
SELECT 'Department Total', DepartmentID, NULL, SUM(Salary) FROM HR.EMP_Details GROUP BY DepartmentID
UNION ALL
SELECT 'Employee Detail', DepartmentID, EmployeeID, Salary FROM HR.EMP_Details
ORDER BY DepartmentID, Category DESC, EmployeeID; -- Sort to group details under totals
```

*   **Explanation:** A common technique to create reports showing both summary (total) rows and detail rows in one result set. `UNION ALL` combines the aggregated results with the individual rows. `NULL` placeholders are used in columns that don't apply to the summary rows. `ORDER BY` arranges the output logically.

**l) Set Operations with CTEs**

```sql
WITH CurrentQuarterHires AS (...), HighSalaryEmployees AS (...)
SELECT * FROM CurrentQuarterHires
INTERSECT -- Find employees common to both CTEs
SELECT * FROM HighSalaryEmployees;
```

*   **Explanation:** Demonstrates using set operators to combine the results of Common Table Expressions (CTEs). This allows complex logic to be defined in CTEs first, and then set operations applied to those intermediate results.

## 3. Targeted Interview Questions (Based on `34_select_set_operations.sql`)

**Question 1:** What is the key difference between `UNION` and `UNION ALL`, and when would you typically prefer `UNION ALL`?

**Solution 1:**

*   **Difference:** `UNION` combines the results of two queries and removes duplicate rows from the final result set. `UNION ALL` combines the results but includes *all* rows from both queries, including any duplicates.
*   **Preference for `UNION ALL`:** You typically prefer `UNION ALL` when:
    1.  You know the queries being combined will not produce duplicate rows anyway.
    2.  You explicitly *want* to keep duplicate rows in the result.
    3.  Performance is critical, as `UNION ALL` avoids the overhead of sorting and comparing rows to remove duplicates, making it generally faster than `UNION`.

**Question 2:** If `TableA` contains IDs {1, 2, 3} and `TableB` contains IDs {2, 3, 4}, what would be the result of `SELECT ID FROM TableA EXCEPT SELECT ID FROM TableB;`?

**Solution 2:** The result would be `{1}`. `EXCEPT` returns distinct rows from the first query (`TableA`) that are *not* found in the second query (`TableB`). ID 1 is in TableA but not TableB. IDs 2 and 3 are in both, so they are excluded. ID 4 is only in TableB, so it's irrelevant to the `EXCEPT` operation based on TableA.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which set operator returns only rows common to both query results?
    *   **Answer:** `INTERSECT`.
2.  **[Easy]** Do the columns in the `SELECT` lists being combined by a set operator need to have the same names?
    *   **Answer:** No. The names from the *first* `SELECT` statement are used for the final result set. However, the columns must be in the same order and have compatible data types.
3.  **[Medium]** If Query1 returns 10 rows (including some duplicates) and Query2 returns 5 rows (also with duplicates), what is the maximum and minimum number of rows that `Query1 UNION Query2` could return? What about `Query1 UNION ALL Query2`?
    *   **Answer:**
        *   `UNION`: Maximum = 15 (if all 15 rows across both queries are unique). Minimum = 10 (if all 5 rows from Query2 are duplicates of rows already in Query1). It returns only distinct rows.
        *   `UNION ALL`: Always returns exactly 15 rows (10 + 5). It keeps all rows, including duplicates.
4.  **[Medium]** Can you use `WHERE` clauses in the individual `SELECT` statements being combined by a set operator? Can you use a `WHERE` clause *after* the set operator?
    *   **Answer:** Yes, you can (and often do) use `WHERE` clauses in the individual `SELECT` statements to filter the rows *before* they are combined by the set operator. No, you cannot use a single `WHERE` clause *after* the set operator to filter the combined result; filtering on the combined result must be done using a subquery or CTE (e.g., `SELECT * FROM (Query1 UNION Query2) AS Combined WHERE Combined.Column = 'Value';`).
5.  **[Medium]** Does `INTERSECT` remove duplicate rows from its final result? Does `EXCEPT`?
    *   **Answer:** Yes, both `INTERSECT` and `EXCEPT` return only distinct rows in their final result set.
6.  **[Medium]** What determines the data type of a column in the result set of a `UNION` or `UNION ALL` operation if the corresponding columns in the source queries have compatible but different data types (e.g., `INT` and `SMALLINT`)?
    *   **Answer:** SQL Server follows data type precedence rules. The resulting column's data type will be the one with the higher precedence (e.g., `INT` has higher precedence than `SMALLINT`, so the result column would be `INT`). Values from the lower precedence type will be implicitly converted.
7.  **[Hard]** How does SQL Server typically evaluate multiple set operators in a single statement if parentheses are not used (e.g., `Q1 UNION Q2 INTERSECT Q3 EXCEPT Q4`)?
    *   **Answer:** SQL Server generally evaluates set operators from **left to right**. However, `INTERSECT` has higher precedence than `UNION`, `UNION ALL`, and `EXCEPT`. So, in the example `Q1 UNION Q2 INTERSECT Q3 EXCEPT Q4`, the `Q2 INTERSECT Q3` would likely be evaluated first, then `Q1 UNION (Result)`, and finally `(Result) EXCEPT Q4`. It's highly recommended to use parentheses `()` to explicitly define the desired order of evaluation for clarity and correctness when mixing different set operators.
8.  **[Hard]** Can you use aggregate functions directly around a set operation, like `SELECT COUNT(*) FROM (Query1 UNION Query2);`?
    *   **Answer:** No, not directly like that. You need to treat the result of the set operation as a derived table or use a CTE:
        ```sql
        -- Using Derived Table
        SELECT COUNT(*) FROM (
            SELECT ColumnA FROM Table1
            UNION
            SELECT ColumnA FROM Table2
        ) AS CombinedResult;

        -- Using CTE
        WITH CombinedResult AS (
            SELECT ColumnA FROM Table1
            UNION
            SELECT ColumnA FROM Table2
        )
        SELECT COUNT(*) FROM CombinedResult;
        ```
9.  **[Hard]** How do `NULL` values affect `UNION`, `INTERSECT`, and `EXCEPT`? Are two `NULL` values considered equal for duplicate removal or comparison?
    *   **Answer:** For the purpose of set operators (`UNION`, `INTERSECT`, `EXCEPT`) and duplicate removal (like `DISTINCT`), two `NULL` values **are considered equal**.
        *   `UNION`: If both queries return rows with `NULL` in the same corresponding column position, `UNION` will treat them as duplicates and return only one such row (assuming other columns also match).
        *   `INTERSECT`: If Query1 has a row with `NULL` and Query2 also has a row with `NULL` (and other columns match), `INTERSECT` will consider them a match and return that row (with `NULL`).
        *   `EXCEPT`: If Query1 has a row with `NULL` and Query2 also has a row with `NULL` (and other columns match), `EXCEPT` will *not* return that row because it exists in the second query.
10. **[Hard/Tricky]** Can you combine queries with different collations using set operators? What might happen?
    *   **Answer:** Combining queries where corresponding character columns have different collations using set operators will typically result in a **collation conflict error**. SQL Server cannot determine which collation's rules to use for comparing strings (for duplicate removal in `UNION`/`INTERSECT`/`EXCEPT` or sorting). To resolve this, you must explicitly use the `COLLATE` clause in one or both `SELECT` statements to convert the columns to a common, compatible collation before the set operator is applied (e.g., `SELECT ColumnA COLLATE DATABASE_DEFAULT FROM Table1 UNION SELECT ColumnB COLLATE DATABASE_DEFAULT FROM Table2`).
