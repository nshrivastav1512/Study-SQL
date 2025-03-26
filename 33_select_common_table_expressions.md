# SQL Deep Dive: Common Table Expressions (CTEs)

## 1. Introduction: What are CTEs?

A Common Table Expression (CTE) is a temporary, named result set that you can reference within a single SQL statement (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `MERGE`). Defined using the `WITH` clause, CTEs help break down complex queries into simpler, logical building blocks, improving readability and maintainability compared to deeply nested subqueries or derived tables.

**Why use CTEs?**

*   **Readability:** Makes complex queries easier to understand by giving meaningful names to intermediate steps or sub-results.
*   **Maintainability:** Easier to modify or debug individual logical steps defined within separate CTEs.
*   **Recursion:** CTEs are the standard way to write recursive queries in SQL Server, essential for querying hierarchical data (like organizational charts or bill-of-materials).
*   **Replacing Subqueries/Views:** Can often replace derived tables (subqueries in the `FROM` clause) or simple views for single-statement use.
*   **Referencing Multiple Times:** A CTE can be referenced multiple times within the single statement that follows it.

**Key Characteristics:**

*   Introduced by the `WITH` keyword.
*   Must be followed immediately by the statement that uses it (`SELECT`, `INSERT`, etc.).
*   Scope is limited to the single statement immediately following the CTE definition(s).
*   Can define multiple CTEs in one `WITH` clause, separated by commas. Later CTEs can reference earlier ones.
*   Generally not materialized (expanded into the main query plan by the optimizer).

**Basic Syntax:**

```sql
WITH cte_name [(column_alias1, ...)] AS (
    -- CTE query definition (SELECT statement)
    SELECT column1, column2, ... FROM source_table WHERE ...
)
-- Main query referencing the CTE
SELECT * FROM cte_name WHERE ...;

-- Multiple CTEs
WITH cte1 AS (
    SELECT ...
), -- Comma separator
cte2 AS (
    SELECT ... FROM cte1 WHERE ... -- Can reference previous CTEs
)
SELECT * FROM cte2 WHERE ...;
```

## 2. CTEs in Action: Analysis of `33_select_common_table_expressions.sql`

This script demonstrates various ways to define and use CTEs.

**a) Basic CTE (Replacing Derived Table)**

```sql
WITH EmployeeSalaryStats AS ( -- Define CTE
    SELECT DepartmentID, AVG(Salary) AS AvgSalary, ...
    FROM HR.EMP_Details GROUP BY DepartmentID
)
-- Use CTE in main query
SELECT d.DepartmentName, ess.AvgSalary, ...
FROM EmployeeSalaryStats ess JOIN HR.Departments d ON ess.DepartmentID = d.DepartmentID;
```

*   **Explanation:** Defines `EmployeeSalaryStats` to hold departmental salary aggregates. The main query then joins the `Departments` table to this CTE, making the logic clearer than embedding the aggregation subquery directly in the `FROM` clause.

**b) Multiple CTEs**

```sql
WITH DepartmentCounts AS (
    SELECT DepartmentID, COUNT(*) AS EmployeeCount FROM ... GROUP BY DepartmentID
), -- Comma separates CTEs
HighSalaryEmployees AS (
    SELECT DepartmentID, COUNT(*) AS HighPaidCount FROM ... WHERE Salary > 70000 GROUP BY DepartmentID
)
-- Main query uses both CTEs
SELECT d.DepartmentName, dc.EmployeeCount, hse.HighPaidCount, ...
FROM DepartmentCounts dc JOIN HighSalaryEmployees hse ON ... JOIN HR.Departments d ON ...;
```

*   **Explanation:** Defines two CTEs: one for total counts per department, another for high-paid counts. The main query then joins these two CTEs (and the base `Departments` table) to calculate the percentage of high-paid employees.

**c) CTE with Window Functions**

```sql
WITH RankedEmployees AS (
    SELECT EmployeeID, ..., RANK() OVER(...) AS SalaryRank
    FROM HR.EMP_Details
)
SELECT re.EmployeeID, ...
FROM RankedEmployees re JOIN HR.Departments d ON ...
WHERE re.SalaryRank <= 3;
```

*   **Explanation:** Uses a CTE to encapsulate the window function logic (calculating salary rank within departments). The main query then simply filters the results from the CTE based on the calculated rank, making the filtering logic cleaner.

**d) Recursive CTE (Hierarchical Data)**

```sql
WITH EmployeeHierarchy AS (
    -- Anchor Member (Base Case)
    SELECT EmployeeID, ..., ManagerID, 0 AS Level, CAST(...) AS HierarchyPath
    FROM HR.EMP_Details WHERE ManagerID IS NULL
    UNION ALL -- Required for recursion
    -- Recursive Member (Joins back to CTE)
    SELECT e.EmployeeID, ..., e.ManagerID, eh.Level + 1, CAST(...)
    FROM HR.EMP_Details e INNER JOIN EmployeeHierarchy eh ON e.ManagerID = eh.EmployeeID
)
-- Select from the fully populated CTE
SELECT * FROM EmployeeHierarchy ORDER BY Level;
```

*   **Explanation:** The standard structure for querying hierarchies.
    1.  **Anchor Member:** Selects the root(s) of the hierarchy (employees with no manager, `Level` 0).
    2.  **`UNION ALL`:** Combines anchor results with recursive results.
    3.  **Recursive Member:** Joins `HR.EMP_Details` (`e`) back to the CTE itself (`eh`) on the manager relationship (`e.ManagerID = eh.EmployeeID`). Selects the direct reports (`e`) of the employees found in the previous step (`eh`), incrementing the `Level`.
    4.  This repeats until the recursive member finds no more matching rows.
    5.  The final `SELECT` retrieves all rows accumulated in the CTE.

**e) Recursive CTE with `MAXRECURSION` Option**

```sql
WITH NumberSequence AS (
    SELECT 1 AS Number
    UNION ALL
    SELECT Number + 1 FROM NumberSequence WHERE Number < 100
)
SELECT Number FROM NumberSequence
OPTION (MAXRECURSION 100); -- Specify recursion limit
```

*   **Explanation:** Demonstrates generating a sequence of numbers using recursion. The `OPTION (MAXRECURSION 100)` hint explicitly sets the recursion limit (the default is also 100). Setting it to 0 removes the limit (use with caution).

**f) CTE for Data Generation (e.g., Date Sequence)**

```sql
WITH DateSequence AS (
    SELECT CAST('2023-01-01' AS DATE) AS SequenceDate
    UNION ALL
    SELECT DATEADD(DAY, 1, SequenceDate) FROM DateSequence WHERE SequenceDate < '2023-12-31'
)
SELECT SequenceDate, ... FROM DateSequence OPTION (MAXRECURSION 366);
```

*   **Explanation:** Uses a recursive CTE to generate a series of dates within a specified range. Useful for creating calendar tables or ensuring all dates are present in reports.

**g) CTE for Running Totals (Alternative to Window Functions)**

```sql
-- Example using CTEs for running totals (less common now due to window functions)
WITH MonthlySales AS (... GROUP BY Year, Month),
RunningTotals AS (
    SELECT m1.OrderYear, m1.OrderMonth, SUM(m2.MonthlySalesAmount) AS YearToDateSales
    FROM MonthlySales m1 JOIN MonthlySales m2 ON m1.OrderYear = m2.OrderYear AND m2.OrderMonth <= m1.OrderMonth
    GROUP BY m1.OrderYear, m1.OrderMonth
) ...
```

*   **Explanation:** Shows how CTEs *could* be used with self-joins and aggregation to calculate running totals before window functions became widely available. Window functions (`SUM(...) OVER (ORDER BY ...)` are now the standard, more efficient way to do this.

**h) CTE for Pivoting Data**

```sql
WITH DepartmentSalaries AS (
    SELECT JobTitle, DepartmentID, SUM(Salary) AS TotalSalary FROM ... GROUP BY ...
)
SELECT JobTitle, [1] AS HR_Dept, ...
FROM DepartmentSalaries
PIVOT (SUM(TotalSalary) FOR DepartmentID IN ([1],[2],[3],[4])) AS PivotTable;
```

*   **Explanation:** Uses a CTE (`DepartmentSalaries`) to prepare the aggregated data in the required format before applying the `PIVOT` operator in the main query.

**i) CTE for Data Cleaning**

```sql
WITH CleanedEmployeeData AS (
    SELECT EmployeeID, TRIM(FirstName) AS FirstName, ...,
           CASE WHEN Email LIKE '%@%.%' THEN Email ELSE NULL END AS CleanEmail, ...
    FROM HR.EMP_Details
)
SELECT ced.EmployeeID, ...
FROM CleanedEmployeeData ced JOIN ...
WHERE ced.CleanEmail IS NOT NULL ...;
```

*   **Explanation:** Uses a CTE to perform data cleansing operations (like `TRIM`, `CASE` for validation) on the raw data. The main query then selects from the cleaned data in the CTE.

**j) CTE for Pagination**

```sql
DECLARE @PageNumber INT = 2, @RowsPerPage INT = 10;
WITH PagedEmployees AS (
    SELECT ..., ROW_NUMBER() OVER(ORDER BY LastName, FirstName) AS RowNum
    FROM HR.EMP_Details
)
SELECT ... FROM PagedEmployees
WHERE RowNum BETWEEN (@PageNumber - 1) * @RowsPerPage + 1 AND @PageNumber * @RowsPerPage
ORDER BY RowNum;
```

*   **Explanation:** A standard pattern for server-side pagination.
    1.  The CTE assigns a unique row number to each record based on a specified order (`ROW_NUMBER() OVER(...)`).
    2.  The outer query filters the CTE results based on `RowNum` to select only the rows corresponding to the desired page (`@PageNumber`) and page size (`@RowsPerPage`).

## 3. Targeted Interview Questions (Based on `33_select_common_table_expressions.sql`)

**Question 1:** What is the primary benefit of using a CTE like `EmployeeSalaryStats` in section 1 compared to putting the aggregation logic directly into a derived table in the `FROM` clause?

**Solution 1:** The primary benefit is **readability and maintainability**. By defining the aggregation logic in a named CTE (`EmployeeSalaryStats`), the main query becomes simpler and easier to understand (`FROM EmployeeSalaryStats ess JOIN ...`). It separates the logical step of calculating statistics from the final step of joining and selecting results. If the aggregation logic needed to be reused elsewhere in the main query, the CTE could be referenced again, whereas a derived table definition would need to be repeated.

**Question 2:** In the recursive CTE `EmployeeHierarchy` (section 4), what prevents the query from running forever?

**Solution 2:** The recursion stops naturally because of the join condition in the recursive member: `INNER JOIN EmployeeHierarchy eh ON e.ManagerID = eh.EmployeeID`. Eventually, the query reaches employees (`e`) at the bottom of the hierarchy who do not manage anyone. When the recursive member runs for these bottom-level employees, the `INNER JOIN` condition will find no matching `EmployeeID` in the `EmployeeHierarchy` CTE (`eh`) for the next level down (because `e.ManagerID` for the next level doesn't exist in `eh.EmployeeID`), and the recursive member will return no rows, thus terminating the recursion. Additionally, SQL Server has a default `MAXRECURSION` limit (100) that would stop it if the hierarchy was unexpectedly deep or circular.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What keyword introduces a Common Table Expression (CTE)?
    *   **Answer:** `WITH`.
2.  **[Easy]** Can a CTE definition be followed by an `INSERT`, `UPDATE`, or `DELETE` statement instead of a `SELECT`?
    *   **Answer:** Yes. The statement immediately following the CTE definition(s) can be `SELECT`, `INSERT`, `UPDATE`, `DELETE`, or `MERGE`.
3.  **[Medium]** How do you define multiple CTEs to be used in a single subsequent statement?
    *   **Answer:** You list them sequentially within a single `WITH` clause, separated by commas (e.g., `WITH cte1 AS (...), cte2 AS (...) SELECT ...`).
4.  **[Medium]** Can a CTE defined later in a `WITH` clause reference a CTE defined earlier in the same `WITH` clause?
    *   **Answer:** Yes. CTEs defined within the same `WITH` clause can reference preceding CTEs in that clause.
5.  **[Medium]** What is the scope of a CTE? Can you define a CTE and then reference it in multiple separate SQL statements later in the script?
    *   **Answer:** The scope of a CTE is limited to the **single statement** immediately following the CTE definition. You cannot reference it in subsequent, separate statements without redefining it.
6.  **[Medium]** What are the two essential parts of a recursive CTE definition?
    *   **Answer:** The **anchor member** (base case query) and the **recursive member** (query that references the CTE itself), combined using `UNION ALL`.
7.  **[Hard]** Are CTEs always more performant than equivalent derived tables or temporary tables?
    *   **Answer:** Not necessarily. CTEs are primarily a logical construct for readability. The optimizer typically expands the CTE logic into the main query plan. While this often results in efficient plans, there are cases (especially if a complex CTE is referenced multiple times) where the optimizer might re-evaluate the CTE logic repeatedly. In such scenarios, manually materializing the intermediate results into an indexed temporary table (`#temp`) might yield better performance, as the intermediate data is calculated only once and potentially indexed for faster access. Performance depends heavily on the specific query, data volume, and statistics.
8.  **[Hard]** Can you use `ORDER BY` within the CTE definition itself (inside the parentheses)?
    *   **Answer:** Generally no, not unless you also include a `TOP` or `OFFSET`/`FETCH` clause within the CTE definition. CTEs, like derived tables and views, represent relational sets which conceptually have no inherent order. Ordering is typically applied to the *final* result set in the outer query's `ORDER BY` clause. Using `ORDER BY` within the CTE is mainly useful when combined with `TOP`/`OFFSET`/`FETCH` to select specific rows *before* they are used in the outer query.
9.  **[Hard]** Can a recursive CTE contain aggregate functions (like `SUM`, `COUNT`) or `GROUP BY` in the *recursive* member?
    *   **Answer:** No. The recursive member of a CTE has several restrictions, including prohibitions against using aggregate functions, `GROUP BY`, `HAVING`, `TOP`, `DISTINCT`, and outer joins (unless the CTE itself is on the preserved side of a left outer join). These operations are generally incompatible with the iterative nature of recursion. Aggregations are typically performed in the *outer* query after the recursion is complete.
10. **[Hard/Tricky]** If you define a CTE, and the main query following it does *not* reference the CTE at all, will SQL Server still execute the query defined within the CTE?
    *   **Answer:** No. If the CTE is not referenced by the main statement that follows it, the query optimizer is usually smart enough to recognize this and will **not** execute the underlying query defined within the unreferenced CTE. It effectively optimizes it away.
