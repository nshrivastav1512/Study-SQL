# SQL Deep Dive: Common Table Expressions (CTEs) (Comprehensive)

## 1. Introduction: What are CTEs?

A **Common Table Expression (CTE)** is a temporary, named result set, defined using the `WITH` keyword, that you can reference within the scope of a single `SELECT`, `INSERT`, `UPDATE`, `DELETE`, or `MERGE` statement. Think of it as defining a temporary view just for the duration of one statement.

**Why use CTEs?**

*   **Readability & Maintainability:** Break down complex queries into smaller, logical, named blocks. This makes the query structure easier to follow and maintain compared to deeply nested subqueries or multiple temporary tables.
*   **Recursion:** Provide the standard SQL mechanism for writing recursive queries, essential for querying hierarchical data (like organizational charts or bill-of-materials).
*   **Modularity:** Encourage a modular approach by defining intermediate result sets that can be referenced (potentially multiple times, though often expanded inline by the optimizer) in the subsequent query.
*   **Window Function Filtering:** Allow filtering based on the results of window functions (like `ROW_NUMBER`, `RANK`, `LAG`, `LEAD`), which cannot be done directly in a `WHERE` clause.

**Basic Syntax:**

```sql
-- Preceding statement must end with a semicolon if WITH is not the first keyword
;WITH CTE_Name [(ColumnAlias1, ColumnAlias2, ...)] -- Optional column aliases
AS
(
    -- CTE query definition (a SELECT statement)
    SELECT Column1, Column2, ...
    FROM SourceTable
    WHERE Condition
)
-- Single statement referencing the CTE
SELECT CTE_Column1, CTE_Column2
FROM CTE_Name
WHERE CTE_Column1 > SomeValue;
```

*   Starts with `WITH`. If not the first statement in the batch, the preceding statement needs a semicolon (`;`).
*   Followed by the CTE name and an optional list of column aliases.
*   `AS (...)` encloses the `SELECT` statement defining the CTE.
*   Must be immediately followed by *one* statement (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `MERGE`) that references the CTE.
*   The CTE's scope is limited to that single referencing statement.

## 2. CTEs in Action: Analysis of `76_COMMON_TABLE_EXPRESSIONS.sql`

This script demonstrates various CTE applications.

**Part 1: Fundamentals**

*   Explains the concept, benefits (readability, recursion, modularity), and basic syntax.

**Part 2: Basic CTE Examples**

*   **1. Simple CTE:** Calculates average salary per department and then joins back to the departments table.
    ```sql
    WITH DepartmentAvgSalary AS (SELECT DepartmentID, AVG(Salary) AS AvgSalary FROM HR.Employees ... GROUP BY DepartmentID)
    SELECT d.DepartmentName, das.AvgSalary FROM DepartmentAvgSalary das JOIN HR.Departments d ON ...;
    ```
*   **2. CTE with Window Functions:** Uses `AVG(...) OVER (...)` within the CTE to calculate the department average salary alongside each employee's salary, then the outer query filters for employees above the average.
    ```sql
    WITH EmployeeSalaryComparison AS (SELECT ..., AVG(Salary) OVER (PARTITION BY DepartmentID) AS DeptAvgSalary FROM HR.Employees ...)
    SELECT ... FROM EmployeeSalaryComparison WHERE Salary > DeptAvgSalary;
    ```
*   **3. CTE with Joins:** Joins multiple tables (`Employees`, `ProjectAssignments`, `Projects`) inside the CTE to create a combined dataset, which is then aggregated in the outer query.
    ```sql
    WITH EmployeeProjects AS (SELECT ... FROM HR.Employees e JOIN ProjectAssignments pa ON ... JOIN Projects p ON ...)
    SELECT ..., COUNT(DISTINCT ep.ProjectID), SUM(ep.HoursAllocated) FROM EmployeeProjects ep JOIN HR.Departments d ON ... GROUP BY ...;
    ```

**Part 3: Multiple CTEs**

*   **Syntax:** Define multiple CTEs sequentially within a single `WITH` clause, separated by commas. Each subsequent CTE can reference preceding CTEs.
    ```sql
    WITH
    CTE1 AS (...),
    CTE2 AS (SELECT ... FROM CTE1 ...) -- CTE2 can reference CTE1
    SELECT ... FROM CTE1 JOIN CTE2 ON ...; -- Main query references both
    ```
*   **Example:** Calculates department stats (`DepartmentStats`) and company-wide stats (`CompanyStats`) in separate CTEs, then joins them in the final `SELECT` to compare department metrics against company averages.

**Part 4: Recursive CTEs**

*   **Purpose:** Querying hierarchical or graph-like structures.
*   **Structure:**
    1.  **Anchor Member:** A `SELECT` statement that defines the starting point(s) or base case(s) of the recursion (e.g., top-level managers, root nodes).
    2.  `UNION ALL`: Connects the anchor and recursive members.
    3.  **Recursive Member:** A `SELECT` statement that references the **CTE itself**, joining back to the source table to find the next level in the hierarchy (e.g., employees whose `ManagerID` matches an `EmployeeID` already in the CTE).
    4.  **Termination Condition:** Implicitly occurs when the recursive member returns no more rows.
*   **Examples:**
    *   **Employee Hierarchy:** Builds an org chart path and level by starting with employees having `ManagerID IS NULL` (anchor) and recursively joining employees to their managers found in the previous level.
    *   **Department Budget Rollup:** Calculates total budget including sub-departments. Starts with leaf-node departments (anchor), then recursively joins parent departments to their already-processed children, summing budgets (`GROUP BY` in recursive member).
    *   **Project Task Dependencies:** Calculates earliest start/finish times. Starts with tasks having no predecessors (anchor), then recursively calculates start/finish times for dependent tasks based on the finish time of their predecessors. Includes logic to identify the critical path.
*   **`MAXRECURSION` Option:** Limits the number of recursion levels allowed (default 100) to prevent infinite loops in case of faulty data or logic. `OPTION (MAXRECURSION n)` or `OPTION (MAXRECURSION 0)` for unlimited.

**Part 5: Using CTEs in DML Operations**

*   CTEs can precede `INSERT`, `UPDATE`, `DELETE`, and `MERGE` statements, allowing the DML operation to reference the CTE's result set.
*   **`INSERT`:** Uses a CTE (`NextYearBudget`) to calculate values before inserting them into `HR.DepartmentBudgetPlan`.
*   **`UPDATE`:** Uses a CTE (`SalaryAdjustmentCTE`) with window functions to identify employees below department average and then updates the CTE (which translates to updating the underlying base table `HR.Employees`). *Note: Updating a CTE updates its base table(s) directly.* Includes `OUTPUT` clause referencing `deleted` and `inserted` (referring to the base table changes).
*   **`DELETE`:** Uses a CTE (`CompletedTasksCTE`) to identify rows to be deleted from the base table (`HR.ProjectTasks`). `DELETE FROM CTE_Name` deletes the corresponding rows from the underlying base table.
*   **`MERGE`:** Uses a CTE (`ProjectAssignmentsCTE`) as the `source` for the `MERGE` statement to synchronize data.

**Part 6: CTEs vs. Subqueries vs. Temporary Tables**

*   **CTE vs. Subquery:** CTEs often improve readability for complex logic compared to nested subqueries. A CTE defined once can be referenced multiple times in the subsequent query (though the optimizer might still expand it inline each time). Subqueries are defined inline where they are used.
*   **CTE vs. Temporary Table (`#temp`):**
    *   **Scope:** CTEs exist only for the *single* statement that follows them. Temp tables persist for the *session* (or procedure scope).
    *   **Materialization:** CTEs are generally *not* materialized (they are expanded like macros or views, though complex ones might spool to `tempdb`). Temp tables *are* materialized in `tempdb`.
    *   **Indexing/Stats:** Temp tables can have indexes and statistics created on them, which can be beneficial if the intermediate result set is large and queried multiple times within a batch/procedure. CTEs cannot be indexed directly.
    *   **Use Case:** Use CTEs for improving readability within a single statement or for recursion. Use temp tables when you need to reuse an intermediate result set across multiple statements, need indexes/stats on it, or when materialization might benefit performance for very complex intermediate results.

**Part 7: Performance Considerations**

*   **Not Materialized:** Understand that CTEs are usually expanded inline; they don't automatically provide the performance benefit of materialization like a temp table might (unless the optimizer chooses to spool).
*   **Recursion:** Recursive CTEs can be resource-intensive. Ensure proper termination conditions and consider `MAXRECURSION`. Indexing the join columns used in the anchor and recursive members is critical.
*   **Indexing:** Performance relies heavily on good indexing on the *underlying tables* accessed within the CTE definition.
*   **Complexity:** Overly complex or deeply nested CTEs can still be hard to read and potentially perform poorly.

**Part 8: Best Practices**

*   Use clear names, format for readability, add comments.
*   Keep CTEs focused; break down complexity.
*   Consider views for reusable CTE logic.
*   Index underlying tables appropriately.
*   Test recursive CTEs carefully, use `MAXRECURSION`.

**Part 9: Real-World HR Scenarios**

*   Provides more complex examples using CTEs with window functions (`ROW_NUMBER`, `AVG OVER`, `DENSE_RANK`) for practical analysis like comparing current vs. previous performance reviews, tracking certifications, and identifying succession planning candidates based on multiple criteria.

## 3. Targeted Interview Questions (Based on `76_COMMON_TABLE_EXPRESSIONS.sql`)

**Question 1:** What is the main advantage of using a CTE over a complex, nested subquery for improving code quality?

**Solution 1:** The main advantage is **readability and maintainability**. CTEs allow you to break down a complex query into logical, named steps. Each CTE defines a clear intermediate result set, making the overall query structure easier to understand, debug, and modify compared to trying to decipher multiple levels of nested subqueries.

**Question 2:** What unique capability do CTEs offer that cannot be achieved with simple subqueries or derived tables?

**Solution 2:** CTEs provide the ability to perform **recursion**. A recursive CTE includes an anchor member (base case) and a recursive member that references the CTE itself, allowing traversal of hierarchical data structures (like org charts, bill-of-materials) level by level until a termination condition is met.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What keyword introduces a CTE definition?
    *   **Answer:** `WITH`.
2.  **[Easy]** How many DML/SELECT statements can immediately follow a CTE definition (or a set of CTE definitions)?
    *   **Answer:** Exactly one.
3.  **[Medium]** Can a CTE reference itself? If so, what is this type of CTE called?
    *   **Answer:** Yes. This is called a **recursive CTE**.
4.  **[Medium]** Are CTEs generally materialized (like temporary tables) or expanded inline (like views)?
    *   **Answer:** They are generally expanded inline by the query optimizer, similar to views or derived tables. They are not typically materialized into temporary storage unless the optimizer determines it's beneficial for a particularly complex CTE referenced multiple times (which might involve spooling).
5.  **[Medium]** Can you define multiple CTEs before a single `SELECT` statement? If so, how?
    *   **Answer:** Yes. You use a single `WITH` keyword, followed by the CTE definitions separated by commas (e.g., `WITH CTE1 AS (...), CTE2 AS (...) SELECT ...`).
6.  **[Medium]** Can `CTE2` reference `CTE1` if they are defined in the same `WITH` clause like `WITH CTE1 AS (...), CTE2 AS (SELECT * FROM CTE1)`?
    *   **Answer:** Yes. A CTE defined later in the `WITH` clause can reference CTEs defined earlier within the same `WITH` clause.
7.  **[Hard]** What is the purpose of the `UNION ALL` in a recursive CTE?
    *   **Answer:** `UNION ALL` combines the results of the **anchor member** (the starting point/base case) with the results of the **recursive member** (which finds the next level of the hierarchy). The recursive member executes repeatedly, adding its results via `UNION ALL`, until it returns no more rows.
8.  **[Hard]** Can you use aggregate functions (like `SUM`, `COUNT`, `AVG`) directly within the *recursive* member of a recursive CTE?
    *   **Answer:** No, aggregate functions are generally **not allowed** directly in the recursive member's `SELECT` list or `WHERE` clause if they reference the recursive CTE itself. Aggregation typically needs to happen *after* the recursion is complete (in the final outer query) or carefully structured within the recursive definition (like the budget rollup example which aggregates results *from* the previous level before joining back).
9.  **[Hard]** If you reference the same non-recursive CTE multiple times in the final query (e.g., `SELECT ... FROM MyCTE JOIN AnotherTable ON ... WHERE MyCTE.ID IN (SELECT ID FROM MyCTE WHERE ...)`), does SQL Server calculate the CTE's result set only once?
    *   **Answer:** Not necessarily. Because CTEs are typically expanded inline like macros or views, the optimizer often expands the CTE definition *each time* it is referenced in the query. It might then find common subexpressions to optimize, but it doesn't automatically guarantee single execution/materialization unless the optimizer specifically chooses a plan involving a spool operator for that CTE. If you need guaranteed single execution for reuse, a temporary table (`#temp`) is often a better choice.
10. **[Hard/Tricky]** Can you perform an `UPDATE` or `DELETE` directly on a CTE? If so, what actually gets modified?
    *   **Answer:** Yes, you can issue an `UPDATE` or `DELETE` statement where the target is a CTE name (`UPDATE MyCTE SET ...`, `DELETE FROM MyCTE WHERE ...`). However, the modification actually applies to the **underlying base table(s)** that the CTE is built upon. The CTE must be "updateable," meaning it generally references only one base table in its definition, doesn't use aggregation, `DISTINCT`, `GROUP BY`, `UNION` (unless on the recursive part), etc. The `UPDATE`/`DELETE` affects the rows in the base table that correspond to the rows identified by the CTE and its `WHERE` clause.
