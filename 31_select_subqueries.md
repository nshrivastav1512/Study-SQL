# SQL Deep Dive: Subqueries and Common Table Expressions (CTEs)

## 1. Introduction: Queries within Queries

Subqueries (also called inner queries or nested queries) are `SELECT` statements embedded within another SQL statement (`SELECT`, `INSERT`, `UPDATE`, `DELETE`). They allow you to perform multi-step queries where the result of one query is used as input or a condition for another.

Common Table Expressions (CTEs), introduced with the `WITH` clause, provide a way to define named, temporary result sets that can be referenced within a single statement. They often make complex queries involving subqueries more readable and maintainable.

**Why use Subqueries/CTEs?**

*   **Complex Filtering:** Filter data based on results calculated from other tables or aggregations (e.g., find employees earning more than the company average).
*   **Derived Data:** Use aggregated or transformed data in joins or calculations (e.g., join employees to department average salaries).
*   **Existence Checks:** Determine if related data exists (`EXISTS`, `IN`).
*   **Readability (CTEs):** Break down complex logic into named, logical steps, improving understanding and maintenance.
*   **Recursion (CTEs):** Enable querying hierarchical data structures.

## 2. Subqueries and CTEs in Action: Analysis of `31_select_subqueries.sql`

This script demonstrates different types of subqueries and CTE usage.

**Types of Subqueries:**

**a) Scalar Subquery**

```sql
SELECT EmployeeID, ..., Salary,
    (SELECT AVG(Salary) FROM HR.EMP_Details) AS AvgCompanySalary, -- Subquery returns one value
    Salary - (SELECT AVG(Salary) FROM HR.EMP_Details) AS DiffFromAvg
FROM HR.EMP_Details;
```

*   **Explanation:** Returns a single value (one row, one column). Can be used anywhere a single literal value is expected (e.g., in the `SELECT` list, `WHERE` clause comparisons, `SET` clause). The subquery here calculates the overall average salary once.

**b) Column Subquery**

```sql
WHERE DepartmentID IN (SELECT DepartmentID FROM HR.Departments WHERE ...);
```

*   **Explanation:** Returns a single column containing multiple rows. Typically used with operators like `IN`, `ANY`, `ALL` in the `WHERE` or `HAVING` clause.

**c) Row Subquery**

```sql
WHERE (Salary, DepartmentID) = (SELECT MAX(Salary), 1 FROM ... WHERE DepartmentID = 1);
```

*   **Explanation:** Returns a single row containing multiple columns. Can be used for multi-column comparisons (syntax might vary slightly across database systems, but SQL Server supports this tuple comparison).

**d) Table Subquery (Derived Table)**

```sql
FROM HR.Departments d
JOIN ( -- Subquery used in FROM clause
    SELECT DepartmentID, COUNT(*) AS EmployeeCount, AVG(Salary) AS AvgSalary
    FROM HR.EMP_Details GROUP BY DepartmentID
) e ON d.DepartmentID = e.DepartmentID; -- Alias 'e' is required
```

*   **Explanation:** Returns multiple rows and multiple columns. When used in the `FROM` clause, it acts like a temporary table (a derived table) that can be joined to other tables. It *must* be given an alias (like `e` here).

**Correlated vs. Uncorrelated Subqueries:**

*   **Uncorrelated:** Can be executed independently of the outer query. Its result doesn't change based on the row being processed by the outer query (e.g., the scalar subquery calculating `AVG(Salary)` for the whole company). Usually executed once.
*   **Correlated:** References columns from the outer query. It *cannot* be executed independently and must be re-evaluated for *each row* processed by the outer query (e.g., calculating average salary *for the current row's department*). Can impact performance if not optimized well.

**e) Correlated Subquery Example**

```sql
SELECT e.EmployeeID, ...,
    (SELECT AVG(Salary) FROM HR.EMP_Details WHERE DepartmentID = e.DepartmentID) AS AvgDeptSalary
FROM HR.EMP_Details e; -- Subquery references outer 'e.DepartmentID'
```

*   **Explanation:** Calculates the average salary specifically for the department of the employee (`e`) in the current row being processed by the outer query.

**Subqueries with Specific Operators:**

**f) `EXISTS` Subquery**

```sql
WHERE EXISTS (SELECT 1 FROM HR.EMP_Details e WHERE e.DepartmentID = d.DepartmentID AND ...);
```

*   **Explanation:** Checks if the subquery returns *any* rows. Efficient for existence checks. Often correlated.

**g) `NOT EXISTS` Subquery**

```sql
WHERE NOT EXISTS (SELECT 1 FROM HR.EMP_Details e WHERE e.DepartmentID = d.DepartmentID);
```

*   **Explanation:** Checks if the subquery returns *no* rows. Useful for finding rows without corresponding matches.

**h) Subquery with `ANY`/`SOME`**

```sql
WHERE Salary > ANY (SELECT AVG(Salary) FROM ... GROUP BY DepartmentID);
```

*   **Explanation:** Compares a value against the list returned by the subquery. `> ANY` means "greater than at least one value" (i.e., greater than the minimum).

**i) Subquery with `ALL`**

```sql
WHERE Salary > ALL (SELECT AVG(Salary) FROM ... GROUP BY DepartmentID);
```

*   **Explanation:** Compares a value against the list returned by the subquery. `> ALL` means "greater than every value" (i.e., greater than the maximum).

**j) Nested Subqueries**

```sql
WHERE DepartmentID IN (SELECT DepartmentID FROM ... WHERE LocationID IN (SELECT LocationID FROM ...));
```

*   **Explanation:** A subquery can contain another subquery. Execution typically proceeds from the innermost query outward. Can become difficult to read and potentially inefficient.

**Common Table Expressions (CTEs):**

CTEs provide an alternative, often more readable way to structure complex queries involving subqueries or derived tables.

**k) Basic CTE**

```sql
WITH EmployeeStats AS ( -- Define the CTE name and its query
    SELECT DepartmentID, COUNT(*) AS EmployeeCount, AVG(Salary) AS AvgSalary
    FROM HR.EMP_Details GROUP BY DepartmentID
) -- End CTE definition
-- Main query referencing the CTE
SELECT d.DepartmentName, es.EmployeeCount, es.AvgSalary
FROM HR.Departments d JOIN EmployeeStats es ON d.DepartmentID = es.DepartmentID;
```

*   **Explanation:** Defines a temporary, named result set (`EmployeeStats`) using the `WITH` clause. The main query following the CTE definition can then reference `EmployeeStats` as if it were a table or view. The CTE exists only for the duration of the single statement.

**l) Multiple CTEs**

```sql
WITH DepartmentStats AS (
    SELECT DepartmentID, ..., AVG(Salary) AS AvgSalary FROM ... GROUP BY DepartmentID
), -- Comma separates multiple CTEs
HighPaidDepts AS (
    SELECT DepartmentID FROM DepartmentStats WHERE AvgSalary > 70000 -- Can reference previous CTEs
)
-- Main query using the CTEs
SELECT e.EmployeeID, ...
FROM HR.EMP_Details e JOIN HR.Departments d ON ...
WHERE e.DepartmentID IN (SELECT DepartmentID FROM HighPaidDepts);
```

*   **Explanation:** You can define multiple CTEs sequentially, separated by commas. Each subsequent CTE can reference CTEs defined before it within the same `WITH` clause. This allows breaking down complex logic into manageable, named steps.

## 3. Targeted Interview Questions (Based on `31_select_subqueries.sql`)

**Question 1:** What is the difference between a scalar subquery and a table subquery (derived table)? Where is each typically used?

**Solution 1:**

*   **Scalar Subquery:** Returns exactly one column and one row (a single value). It's typically used in the `SELECT` list or in a `WHERE` clause for comparison against a single value (e.g., `WHERE ColumnA = (SELECT MAX(Value) FROM...)`).
*   **Table Subquery (Derived Table):** Returns potentially multiple rows and multiple columns. It's used in the `FROM` clause, treated like a temporary table, and must be given an alias. It's often used to join against aggregated or pre-processed data.

**Question 2:** Explain the difference between a correlated subquery and an uncorrelated subquery. Which type is generally executed only once, and which type is executed repeatedly?

**Solution 2:**

*   **Uncorrelated Subquery:** Can be executed independently of the outer query; its result does not depend on the current row being processed by the outer query. It is generally executed **once** for the entire statement. Example: `(SELECT AVG(Salary) FROM HR.EMP_Details)` used in section 1.
*   **Correlated Subquery:** Contains a reference to columns from the outer query. It cannot be executed independently and must be logically re-evaluated **for each row** processed by the outer query. Example: `(SELECT AVG(Salary) FROM ... WHERE DepartmentID = e.DepartmentID)` used in section 5. Correlated subqueries can sometimes be less performant due to this row-by-row execution pattern, although the optimizer can often find efficient ways (like transforming them into joins).

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can a subquery used with the `IN` operator return more than one column?
    *   **Answer:** No. A subquery used with `IN` must return only a single column.
2.  **[Easy]** What keyword introduces a Common Table Expression (CTE)?
    *   **Answer:** `WITH`.
3.  **[Medium]** Can a CTE be referenced multiple times within the same main query that follows it?
    *   **Answer:** Yes. A CTE defined in a `WITH` clause can be referenced multiple times in the subsequent `SELECT`, `INSERT`, `UPDATE`, `DELETE`, or `MERGE` statement, often simplifying queries that need to reuse the same intermediate result set.
4.  **[Medium]** What happens if a scalar subquery (one expected to return a single value) actually returns more than one row?
    *   **Answer:** An error occurs. SQL Server will raise an error stating that the subquery returned more than one value when only one was expected (e.g., Error 512).
5.  **[Medium]** Is `WHERE ColumnA NOT IN (SELECT Value FROM ...)` functionally identical to `WHERE NOT EXISTS (SELECT 1 FROM ... WHERE OtherTable.Value = OuterTable.ColumnA)`? Consider NULLs.
    *   **Answer:** No, they are not identical, primarily due to how `NULL` values are handled.
        *   `NOT IN`: If the subquery result set contains *any* `NULL` values, the `NOT IN` condition will evaluate to `UNKNOWN` (effectively false) for *all* rows in the outer query, potentially returning an empty result set unexpectedly.
        *   `NOT EXISTS`: Correctly handles `NULL`s based on the join condition within the subquery. It simply checks for the non-existence of matching rows according to the correlation predicate.
    *   Therefore, `NOT EXISTS` is generally safer and often preferred over `NOT IN` when dealing with potentially nullable columns or subqueries that might return `NULL`.
6.  **[Medium]** Can you use `ORDER BY` inside a subquery used in the `FROM` clause (a derived table)? What about inside a subquery used with `IN` or `EXISTS`?
    *   **Answer:**
        *   **Derived Table (FROM clause):** You *can* use `ORDER BY` inside a derived table subquery, but only if you also use `TOP` or `OFFSET`/`FETCH`. Without `TOP` or `OFFSET`/`FETCH`, `ORDER BY` inside a derived table is generally disallowed or ignored because tables/derived tables conceptually have no inherent order.
        *   **IN/EXISTS Subquery:** `ORDER BY` inside a subquery used with `IN` or `EXISTS` is syntactically allowed but generally **pointless and ignored** by the optimizer. `IN` and `EXISTS` only care about the *values* or the *existence* of rows, not their order. Adding `ORDER BY` just adds unnecessary overhead.
7.  **[Hard]** Can a CTE reference itself? If so, what is this called and what is required?
    *   **Answer:** Yes, a CTE can reference itself. This is called a **recursive CTE**. It requires:
        1.  An **anchor member**: A `SELECT` statement that does not reference the CTE itself, providing the base case.
        2.  A `UNION ALL` operator.
        3.  A **recursive member**: A `SELECT` statement that *does* reference the CTE name, typically joining back to the source table based on the results from the previous iteration.
        4.  A termination condition (either implicit, when the recursive member returns no rows, or explicit via a `WHERE` clause or `MAXRECURSION` option).
8.  **[Hard]** Are CTEs materialized (like temporary tables), or are they more like macros or views? What are the performance implications?
    *   **Answer:** CTEs are generally **not materialized**. They are more like named subqueries or inline views. The query optimizer typically expands the CTE definition into the main query plan each time the CTE is referenced.
        *   **Performance Implications:**
            *   **Readability:** Major benefit is improved query readability and maintainability.
            *   **No Automatic Materialization:** Unlike indexed views or sometimes temporary tables, the results aren't usually stored separately, meaning the CTE's logic might be executed multiple times if referenced multiple times (though the optimizer can sometimes be smart about this).
            *   **Optimization:** The optimizer optimizes the *entire* statement including the expanded CTE logic. Sometimes this leads to better plans than manually creating temp tables; other times, manually materializing results in a temp table might be faster if an intermediate result is large and reused frequently.
9.  **[Hard]** Can you use `UPDATE` or `DELETE` statements directly referencing a CTE? If so, what is being modified?
    *   **Answer:** Yes, you can use `UPDATE` and `DELETE` statements where the target directly references a CTE, *provided the CTE is "updateable"*. An updateable CTE must unambiguously reference columns from a single underlying base table. When you `UPDATE` or `DELETE` from such a CTE, you are actually modifying the rows in the **underlying base table** that correspond to the rows identified by the CTE and any additional `WHERE` clause on the `UPDATE`/`DELETE` statement. This is often used with ranking functions in a CTE to delete duplicates or update specific ranked rows.
10. **[Hard/Tricky]** What is the difference in scope between a CTE defined with `WITH` and a subquery defined in the `FROM` clause (derived table)?
    *   **Answer:**
        *   **CTE:** A CTE defined using `WITH` has a scope limited to the *single* statement (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `MERGE`) immediately following the CTE definition. It cannot be referenced in subsequent, separate statements within the same batch or script.
        *   **Derived Table (Subquery in `FROM`):** A derived table's scope is limited to the query it is defined within. It's essentially an inline view for that specific query.
    *   The main practical difference is that a CTE can be referenced *multiple times* within the single statement that follows it, whereas a derived table definition would need to be repeated if the same logic was needed multiple times within one query (unless defined as a CTE first).
