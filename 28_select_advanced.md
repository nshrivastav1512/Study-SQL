# SQL Deep Dive: Advanced `SELECT` Techniques

## 1. Introduction: Beyond Basic Retrieval

While basic `SELECT`, `FROM`, `WHERE`, and `ORDER BY` are essential, SQL offers powerful features for more complex data retrieval, analysis, and presentation directly within your queries. These advanced techniques allow for sophisticated sorting, calculations across sets of rows (window functions), reshaping data (pivot/unpivot), and handling hierarchical structures (recursive CTEs).

## 2. Advanced Techniques in Action: Analysis of `28_select_advanced.sql`

This script demonstrates several powerful features beyond basic selection and filtering.

**a) Complex Sorting (using `CASE` in `ORDER BY`)**

```sql
SELECT EmployeeID, ..., Salary,
    CASE WHEN Salary = 50000 THEN 0 ELSE 1 END AS SortOrder -- Create sorting key
FROM HR.EMP_Details
ORDER BY SortOrder, Salary ASC; -- Sort by key, then salary
```

*   **Explanation:** Achieves a custom sort order. Here, employees with a salary of exactly $50,000 are listed first (because their `SortOrder` is 0), and all others are listed afterward, sorted by their salary (`SortOrder` = 1, then `Salary ASC`). Using `CASE` (or other functions) in the `ORDER BY` clause allows for flexible, non-standard sorting logic.

**b) Dynamic `TOP` with Variables**

```sql
DECLARE @TopCount INT = 5;
SELECT TOP (@TopCount) * FROM HR.EMP_Details ORDER BY Salary DESC;
```

*   **Explanation:** Allows the number of rows returned by `TOP` to be determined by a variable (`@TopCount`). This makes queries more flexible for reporting or application use where the desired number of results might change.

**c) Conditional Aggregation (using `CASE` within Aggregate Functions)**

```sql
SELECT
    DepartmentID,
    COUNT(*) AS TotalEmployees,
    SUM(CASE WHEN Salary < 50000 THEN 1 ELSE 0 END) AS LowSalary, -- Count if condition met
    SUM(CASE WHEN Salary BETWEEN 50000 AND 80000 THEN 1 ELSE 0 END) AS MidSalary,
    SUM(CASE WHEN Salary > 80000 THEN 1 ELSE 0 END) AS HighSalary
FROM HR.EMP_Details
GROUP BY DepartmentID;
```

*   **Explanation:** Performs aggregation (`SUM`, `COUNT`, `AVG`, etc.) conditionally. The `CASE` expression inside the aggregate function determines whether a row contributes to the calculation (e.g., adds 1 to the `SUM` if the salary is low, 0 otherwise). This allows creating pivot-like summaries within a standard `GROUP BY` query.

**d) Window Functions with Partitioning (`OVER(PARTITION BY ...)`**

```sql
SELECT EmployeeID, ..., DepartmentID, Salary,
    AVG(Salary) OVER(PARTITION BY DepartmentID) AS AvgDeptSalary, -- Avg salary for *this* row's dept
    MAX(Salary) OVER(PARTITION BY DepartmentID) AS MaxDeptSalary,
    Salary - AVG(Salary) OVER(PARTITION BY DepartmentID) AS DiffFromAvg
FROM HR.EMP_Details;
```

*   **Explanation:** Window functions perform calculations across a set of table rows (a "window") that are somehow related to the current row, *without collapsing the rows* like `GROUP BY`.
    *   `OVER(PARTITION BY DepartmentID)`: Defines the window. Here, the window for each employee row consists of all employees in the *same department*.
    *   `AVG(Salary) OVER(...)`: Calculates the average salary within that window (the employee's department).
    *   The result is that each employee row now also shows the average, max, min salary *for their specific department*.

**e) Row Numbering and Ranking Functions (`OVER(PARTITION BY ... ORDER BY ...)`**

```sql
SELECT EmployeeID, ..., DepartmentID, Salary,
    ROW_NUMBER() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS RowNum, -- Unique rank 1,2,3..
    RANK()       OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS SalaryRank, -- Rank with gaps for ties (1,1,3..)
    DENSE_RANK() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS DenseRank, -- Rank without gaps (1,1,2..)
    NTILE(4)     OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS Quartile -- Group into N buckets (4 here)
FROM HR.EMP_Details;
```

*   **Explanation:** These are specific types of window functions used for ranking.
    *   `PARTITION BY DepartmentID`: Ranking is done independently *within* each department.
    *   `ORDER BY Salary DESC`: Ranking is based on salary (highest first).
    *   `ROW_NUMBER()`: Assigns a unique sequential integer to each row within the partition based on the order.
    *   `RANK()`: Assigns rank based on order. Rows with the same value get the same rank. The next rank skips values (e.g., if two rows are rank 1, the next is rank 3).
    *   `DENSE_RANK()`: Similar to `RANK`, but does not skip ranks after ties (e.g., if two rows are rank 1, the next is rank 2).
    *   `NTILE(N)`: Divides the rows within each partition into `N` roughly equal groups (buckets) based on the order and assigns a group number (1 to N).

**f) Running Totals and Moving Averages (`OVER(ORDER BY ... ROWS BETWEEN ...)`**

```sql
SELECT EmployeeID, ..., HireDate, Salary,
    SUM(Salary) OVER(ORDER BY HireDate) AS RunningTotal, -- Sum of salaries up to this row's HireDate
    AVG(Salary) OVER(ORDER BY HireDate ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS MovingAvg -- Avg of previous, current, next row
FROM HR.EMP_Details;
```

*   **Explanation:** More window function examples.
    *   `OVER(ORDER BY HireDate)`: Defines a window based on ordering. For `SUM`, without `ROWS BETWEEN`, it defaults to all rows from the beginning of the partition up to the current row (running total).
    *   `ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING`: Explicitly defines the window frame relative to the current row (the row before, the current row, the row after, based on `HireDate` order) for the `AVG` calculation (moving average).

**g) Finding Nth Highest Value (using CTE and Ranking)**

```sql
WITH RankedSalaries AS (
    SELECT DepartmentID, Salary,
           DENSE_RANK() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS SalaryRank
    FROM HR.EMP_Details
)
SELECT DepartmentID, Salary AS ThirdHighestSalary
FROM RankedSalaries
WHERE SalaryRank = 3;
```

*   **Explanation:** A common pattern using ranking functions within a Common Table Expression (CTE).
    1.  The `RankedSalaries` CTE calculates the dense rank of salaries within each department.
    2.  The outer query selects from the CTE, filtering for rows where the rank is 3, effectively finding the 3rd highest distinct salary in each department.

**h) `PIVOT` Operator**

```sql
SELECT JobTitle, [1] AS HR_Dept, [2] AS IT_Dept, ... -- Pivoted columns
FROM (SELECT JobTitle, DepartmentID, Salary FROM HR.EMP_Details) AS SourceData
PIVOT (
    SUM(Salary) -- Aggregate function
    FOR DepartmentID -- Column whose values become new column headers
    IN ([1], [2], [3], [4]) -- List of values to pivot
) AS PivotTable;
```

*   **Explanation:** Transforms data from a row-oriented format to a columnar (cross-tab) format.
    *   `SUM(Salary)`: The value to aggregate for the new column cells.
    *   `FOR DepartmentID`: The column containing the values that will become the new column headers.
    *   `IN ([1], [2], ...)`: The specific values from the `FOR` column that you want to turn into columns.
    *   The result shows `JobTitle` on rows and Departments (1, 2, 3, 4) as columns, with the sum of salaries at the intersections.

**i) `UNPIVOT` Operator**

```sql
SELECT JobTitle, Department, Salary
FROM (SELECT JobTitle, HR_Dept, IT_Dept, ... FROM PivotedSalaries) AS SourceTable
UNPIVOT (
    Salary -- Name for the column that will hold the values from the source columns
    FOR Department -- Name for the column that will hold the names of the source columns
    IN (HR_Dept, IT_Dept, Finance_Dept, Marketing_Dept) -- List of source columns to unpivot
) AS UnpivotTable;
```

*   **Explanation:** Performs the reverse operation of `PIVOT`, transforming data from a columnar format back into a row-oriented format. It takes values spread across multiple columns (`HR_Dept`, `IT_Dept`, etc.) and turns them into distinct rows.

**j) Recursive Common Table Expressions (CTEs)**

```sql
WITH EmployeeHierarchy AS (
    -- Anchor Member: Selects the starting point(s) - e.g., top-level managers
    SELECT EmployeeID, ..., ManagerID, 0 AS Level
    FROM HR.EMP_Details WHERE ManagerID IS NULL

    UNION ALL -- MUST be UNION ALL

    -- Recursive Member: Joins back to the CTE itself to find the next level
    SELECT e.EmployeeID, ..., e.ManagerID, h.Level + 1
    FROM HR.EMP_Details e
    INNER JOIN EmployeeHierarchy h ON e.ManagerID = h.EmployeeID -- Join employee to their manager found in previous step
)
SELECT ..., REPLICATE('    ', Level) + ... AS HierarchyDisplay -- Use Level for display
FROM EmployeeHierarchy ORDER BY Level;
```

*   **Explanation:** Used to query hierarchical data (like organizational charts, parts explosions).
    *   **Anchor Member:** A `SELECT` statement that retrieves the base/starting rows of the hierarchy (e.g., employees with no manager).
    *   **`UNION ALL`:** Connects the anchor and recursive members.
    *   **Recursive Member:** A `SELECT` statement that references the CTE itself (`EmployeeHierarchy h`) to find the next level of the hierarchy (e.g., employees whose `ManagerID` matches an `EmployeeID` already found in the CTE).
    *   The recursion continues until the recursive member returns no more rows.

## 3. Targeted Interview Questions (Based on `28_select_advanced.sql`)

**Question 1:** Explain the difference between `RANK()` and `DENSE_RANK()` as used in section 5. If the top 3 salaries in a department are 100k, 90k, 90k, 80k, what ranks would each salary get using `RANK()` vs `DENSE_RANK()`?

**Solution 1:**

*   **Difference:** Both assign the same rank to rows with equal values in the `ORDER BY` clause. However, `RANK()` skips the next rank(s) after a tie, while `DENSE_RANK()` does not skip ranks.
*   **Example:**
    *   Salary 100k: `RANK()`=1, `DENSE_RANK()`=1
    *   Salary 90k: `RANK()`=2, `DENSE_RANK()`=2
    *   Salary 90k: `RANK()`=2, `DENSE_RANK()`=2
    *   Salary 80k: `RANK()`=**4**, `DENSE_RANK()`=**3**

**Question 2:** In the recursive CTE example (section 10), what does the "Anchor Member" represent, and what does the "Recursive Member" do?

**Solution 2:**

*   **Anchor Member:** Represents the starting point or the base case for the recursion. In this hierarchy example, it selects the employees who are at the top level (those with `ManagerID IS NULL`). This query runs only once.
*   **Recursive Member:** Represents the iterative step. It joins the source table (`HR.EMP_Details e`) back to the CTE itself (`EmployeeHierarchy h`) based on the hierarchical relationship (`e.ManagerID = h.EmployeeID`). This finds the employees (`e`) who report directly to the managers (`h`) found in the previous iteration. It runs repeatedly, adding successive levels to the hierarchy until no more subordinates are found.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** In a window function like `AVG(Salary) OVER(PARTITION BY DepartmentID)`, does the calculation affect the number of rows returned by the query?
    *   **Answer:** No. Window functions perform calculations across a set of rows but return a value for *each* row based on its window; they do not collapse rows like `GROUP BY` aggregate functions do.
2.  **[Easy]** What clause is essential when using `PIVOT` to specify which column's values will become the new column headers?
    *   **Answer:** The `FOR` clause (e.g., `FOR DepartmentID IN (...)`).
3.  **[Medium]** What is the difference between the window frame `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` (default for aggregates with `ORDER BY`) and `ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING`?
    *   **Answer:**
        *   `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`: Defines a window including all rows from the start of the partition up to and including the current row (used for running totals/averages).
        *   `ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING`: Defines a window including the row immediately before the current row, the current row itself, and the row immediately after the current row (based on the `ORDER BY` clause). Used for moving averages/calculations over a fixed-size sliding window.
4.  **[Medium]** Can you use aggregate functions (like `SUM`, `AVG`) without a `GROUP BY` clause if you use an `OVER` clause?
    *   **Answer:** Yes. This is the core concept of window aggregate functions. They perform aggregations relative to the current row's window (defined by `PARTITION BY` and `ORDER BY` within the `OVER` clause) without needing a `GROUP BY` clause, thus preserving the detail rows.
5.  **[Medium]** What is the purpose of the `UNION ALL` in a recursive CTE definition? Can you use `UNION` instead?
    *   **Answer:** `UNION ALL` combines the results of the anchor member (run once) with the results of the recursive member (run potentially multiple times). `UNION ALL` is required; you cannot use `UNION` because `UNION` implicitly performs a `DISTINCT` operation, which would incorrectly remove rows needed for the recursion to proceed correctly and could lead to infinite loops if not handled carefully (though SQL Server has recursion limits).
6.  **[Medium]** When using `PIVOT`, what happens if a value appears in the source data's `FOR` column (e.g., `DepartmentID = 5`) but is *not* listed in the `IN` clause (`IN ([1], [2], [3], [4])`)?
    *   **Answer:** Rows with values in the `FOR` column that are not explicitly listed in the `IN` clause are simply **excluded** from the pivoted result set. They are ignored during the pivot operation.
7.  **[Hard]** Can you use window functions in the `WHERE` or `GROUP BY` clauses of a query?
    *   **Answer:** No. Window functions are logically processed *after* the `WHERE` and `GROUP BY` clauses (typically during or after the `SELECT` phase). Therefore, you cannot directly reference the result of a window function in these clauses. To filter or group based on a window function result, you must use a subquery or a Common Table Expression (CTE).
8.  **[Hard]** What is the maximum recursion level for a recursive CTE by default in SQL Server, and how can it be changed?
    *   **Answer:** By default, the maximum recursion level is **100**. If the recursion doesn't terminate before reaching this level, SQL Server stops execution and raises an error. You can change this limit for a specific query by adding the `OPTION (MAXRECURSION N)` hint at the end of the statement, where `N` is the desired maximum level (0 means no limit, but use with extreme caution to avoid infinite loops).
9.  **[Hard]** Besides `SUM`, `AVG`, `COUNT`, `MIN`, `MAX`, `ROW_NUMBER`, `RANK`, `DENSE_RANK`, and `NTILE`, name two other types of window functions available in SQL Server.
    *   **Answer:** Examples include:
        *   **Offset Functions:** `LAG()` (access data from a previous row in the partition), `LEAD()` (access data from a subsequent row).
        *   **Distribution Functions:** `PERCENT_RANK()` (relative rank as a percentage), `CUME_DIST()` (cumulative distribution).
        *   **(SQL 2022+) Statistical Functions:** `PERCENTILE_CONT`, `PERCENTILE_DISC`.
10. **[Hard/Tricky]** Can the `UNPIVOT` operator handle source columns with different data types? What are the implications?
    *   **Answer:** No, not directly in a single `UNPIVOT` operation. All the source columns listed in the `IN` clause of the `UNPIVOT` operator must have the **same data type** (or be implicitly convertible to a compatible data type). The data type of the resulting value column (specified after `UNPIVOT (...)`) will be determined based on this common type. If your source columns have incompatible types (e.g., one `INT`, one `VARCHAR`), you would typically need to `CAST` or `CONVERT` them to a common compatible type (like `VARCHAR`) in a subquery or CTE *before* applying the `UNPIVOT` operator.
