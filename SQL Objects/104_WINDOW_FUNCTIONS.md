# SQL Deep Dive: Window Functions

## 1. Introduction: What are Window Functions?

**Window Functions** in SQL perform calculations across a set of table rows that are somehow related to the current row. Unlike traditional aggregate functions (like `SUM`, `AVG`, `COUNT`) used with `GROUP BY`, window functions **do not collapse** the rows into a single output row. Instead, they return a value for *each row* based on a "window" of related rows defined by the `OVER()` clause.

**Why use Window Functions?**

*   **Advanced Analytics:** Perform complex calculations like running totals, moving averages, rankings, percentiles, and accessing data from preceding or succeeding rows within a partition.
*   **Maintain Row Detail:** Calculate aggregates or rankings while preserving the detail of individual rows in the result set (unlike `GROUP BY`).
*   **Performance:** Often provide a much more efficient set-based alternative to cursors or complex self-joins for tasks requiring row context.
*   **Readability:** Can express complex analytical logic more concisely than older methods.

**Key Concepts & Syntax:**

The core of a window function is the `OVER()` clause, which defines the "window" of rows the function operates on:

```sql
WindowFunction(arguments) OVER (
    [PARTITION BY column_list]  -- Optional: Divides rows into partitions (groups)
    [ORDER BY column_list]      -- Optional: Orders rows within each partition
    [ROWS | RANGE frame_extent] -- Optional: Defines a subset (frame) within the partition
)
```

*   **`WindowFunction`:** The function itself (e.g., `AVG()`, `SUM()`, `ROW_NUMBER()`, `RANK()`, `LAG()`, `LEAD()`).
*   **`PARTITION BY`:** Divides the rows into independent partitions (groups). The window function is applied separately to each partition. If omitted, the entire result set is treated as a single partition.
*   **`ORDER BY`:** Specifies the logical order of rows *within each partition*. Required by ranking and offset functions, and affects how aggregates like running totals are calculated.
*   **`ROWS` / `RANGE` Frame:** (Optional, used with ordered partitions) Defines a specific subset of rows within the ordered partition relative to the current row (e.g., `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` for a 3-row moving average).

## 2. Window Functions in Action: Analysis of `104_WINDOW_FUNCTIONS.sql`

This script provides a progressive guide to using window functions.

**Part 1: Introduction**

*   Compares traditional `GROUP BY` aggregation (collapses rows) with a window function `AVG(...) OVER()` (preserves rows).
    ```sql
    -- Traditional GROUP BY (returns one row per department)
    SELECT DepartmentID, AVG(Salary) as AvgSalary FROM HR.Employees GROUP BY DepartmentID;

    -- Window Function (returns all employees, each with company average)
    SELECT ..., AVG(Salary) OVER() as CompanyAvgSalary FROM HR.Employees;

    -- Window Function with PARTITION BY (returns all employees, each with their department's average)
    SELECT ..., AVG(Salary) OVER(PARTITION BY DepartmentID) as DeptAvgSalary FROM HR.Employees;
    ```
*   **Explanation:** Shows how `OVER()` calculates an aggregate across the entire set, while `OVER(PARTITION BY DepartmentID)` calculates the aggregate separately for each department but still returns a value for every employee row.

**Part 2: Basic Aggregate Window Functions**

```sql
SELECT ...,
    MIN(Salary) OVER(PARTITION BY DepartmentID) as DeptMinSalary,
    MAX(Salary) OVER(PARTITION BY DepartmentID) as DeptMaxSalary,
    COUNT(*) OVER(PARTITION BY DepartmentID) as DeptEmployeeCount
FROM HR.Employees;
```

*   **Explanation:** Demonstrates using common aggregate functions (`MIN`, `MAX`, `COUNT`) as window functions with `PARTITION BY` to show departmental stats alongside individual employee details.

```sql
-- Running Total
SELECT ...,
    SUM(Salary) OVER(PARTITION BY DepartmentID ORDER BY Salary) as RunningTotalSalary
FROM HR.Employees;
```

*   **Explanation:** Introduces `ORDER BY` within the `OVER()` clause. When used with aggregates like `SUM()`, it creates a running calculation. By default (`ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`), `SUM()` calculates the sum from the start of the partition up to the current row, based on the specified order (`ORDER BY Salary`).

**Part 3: Ranking Functions**

```sql
SELECT ...,
    ROW_NUMBER() OVER(ORDER BY Salary DESC) as UniqueRank,
    RANK() OVER(ORDER BY Salary DESC) as StandardRank,
    DENSE_RANK() OVER(ORDER BY Salary DESC) as ConsecutiveRank
FROM HR.Employees;
```

*   **Explanation:** Shows the three main ranking functions (require `ORDER BY`):
    *   `ROW_NUMBER()`: Assigns a unique, sequential integer to each row based on the order. No gaps, no ties treated equally.
    *   `RANK()`: Assigns ranks based on order. Rows with equal values receive the same rank. Creates gaps in the sequence after ties (e.g., 1, 2, 2, 4).
    *   `DENSE_RANK()`: Assigns ranks based on order. Rows with equal values receive the same rank. Does *not* create gaps after ties (e.g., 1, 2, 2, 3).

```sql
-- Rank within Department
SELECT ...,
    RANK() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) as DeptSalaryRank
FROM HR.Employees;
```

*   **Explanation:** Combines `PARTITION BY` and `ORDER BY` to rank employees based on salary *within* each department independently.

**Part 4: Offset Functions (`LAG`, `LEAD`)**

```sql
SELECT ...,
    LAG(Salary) OVER(ORDER BY EmployeeID) as PreviousEmployeeSalary, -- Salary of previous employee (by ID)
    LEAD(Salary) OVER(ORDER BY EmployeeID) as NextEmployeeSalary, -- Salary of next employee (by ID)
    Salary - LAG(Salary) OVER(ORDER BY EmployeeID) as SalaryDifference -- Diff vs previous
FROM HR.Employees;
```

*   **Explanation:** Access data from preceding (`LAG`) or succeeding (`LEAD`) rows within the ordered partition. Requires `ORDER BY`. Useful for comparing consecutive rows or calculating differences. Optional arguments allow specifying offset (how many rows back/forward) and default value if no preceding/succeeding row exists.

**Part 5: Advanced Window Functions & Framing**

*   **`FIRST_VALUE`, `LAST_VALUE`:**
    ```sql
    SELECT ...,
        FIRST_VALUE(Salary) OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) as HighestInDept,
        LAST_VALUE(Salary) OVER(PARTITION BY DepartmentID ORDER BY Salary DESC
            RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as LowestInDept
    FROM HR.Employees;
    ```
    *   **Explanation:** Retrieve the value of an expression from the first (`FIRST_VALUE`) or last (`LAST_VALUE`) row within the ordered window frame.
    *   **Important:** `LAST_VALUE` often requires specifying the frame `RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` (or similar `ROWS` frame) to consider the entire partition; otherwise, its default frame (`RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`) means it only sees up to the current row, which is usually not the intended "last" value of the whole partition.
*   **Moving Averages (Frame Clause):**
    ```sql
    SELECT ...,
        AVG(Salary) OVER(ORDER BY HireDate ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as MovingAvg3Months
    FROM HR.Employees;
    ```
    *   **Explanation:** Demonstrates the frame clause (`ROWS BETWEEN...`). `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` defines a window frame consisting of the current row and the two preceding rows (based on `HireDate` order). `AVG(Salary)` is calculated over this moving 3-row frame. Other frame options include `RANGE` (based on value offsets) and different boundary specifications (`UNBOUNDED PRECEDING`, `n FOLLOWING`, `UNBOUNDED FOLLOWING`).

**Part 6: Practical Examples**

*   **Percentiles (`NTILE`, `PERCENT_RANK`):**
    *   `NTILE(4)`: Divides rows within each partition into 4 groups (quartiles) based on salary order.
    *   `PERCENT_RANK()`: Calculates the relative rank of a row within its partition (0 for lowest, 1 for highest).
*   **Year-over-Year Growth:** Uses `LAG()` to get the previous year's sales and calculates the percentage growth.

**Part 7: Best Practices**

*   Understand the syntax order (`OVER (PARTITION BY ... ORDER BY ... FRAME ...)`).
*   Index columns used in `PARTITION BY` and `ORDER BY` for performance.
*   Avoid using window functions directly in `WHERE` clauses (use subqueries/CTEs if needed to filter on results).
*   Recognize common use cases where window functions excel.

## 3. Targeted Interview Questions (Based on `104_WINDOW_FUNCTIONS.sql`)

**Question 1:** What is the key difference between using an aggregate function like `AVG(Salary)` with `GROUP BY DepartmentID` versus using `AVG(Salary) OVER(PARTITION BY DepartmentID)`?

**Solution 1:**
*   `AVG(Salary) GROUP BY DepartmentID`: Collapses all rows for each department into a single output row per department, showing only the `DepartmentID` and the calculated average salary for that department.
*   `AVG(Salary) OVER(PARTITION BY DepartmentID)`: Calculates the average salary for each department but returns this average value alongside *every individual employee row*. It does not collapse the rows, allowing you to see both individual employee details and the departmental average in the same result set.

**Question 2:** Explain the difference between `RANK()` and `DENSE_RANK()`. If three employees have the highest salary, what rank would the fourth highest employee receive using `RANK()` versus `DENSE_RANK()`?

**Solution 2:**
*   **Difference:** Both assign the same rank to rows with equal values in the `ORDER BY` clause. However, `RANK()` creates gaps in the sequence after ties (the next rank is the original row number), while `DENSE_RANK()` assigns consecutive ranks without gaps.
*   **Example:** If three employees tie for 1st place:
    *   `RANK()` would assign ranks: 1, 1, 1, 4 (gap of 2, 3).
    *   `DENSE_RANK()` would assign ranks: 1, 1, 1, 2 (no gap).
    The fourth highest employee would receive rank **4** using `RANK()` and rank **2** using `DENSE_RANK()`.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which clause within `OVER()` is used to divide rows into groups for window function calculations?
    *   **Answer:** `PARTITION BY`.
2.  **[Easy]** Which clause within `OVER()` is required for ranking functions like `ROW_NUMBER()` and offset functions like `LAG()`?
    *   **Answer:** `ORDER BY`.
3.  **[Medium]** What does `LAG(Salary, 2, 0) OVER (ORDER BY HireDate)` return?
    *   **Answer:** It returns the `Salary` from the row **two rows prior** based on `HireDate` order. If there is no row two rows prior (e.g., for the first two rows in the ordered set), it returns the specified default value, which is `0`.
4.  **[Medium]** Can you use window functions in the `WHERE` clause of a query?
    *   **Answer:** No, not directly. Window functions are logically evaluated *after* the `WHERE` clause filters rows. To filter based on the result of a window function, you must use a subquery or a Common Table Expression (CTE).
5.  **[Medium]** What is the default window frame if you specify `ORDER BY` in the `OVER()` clause but omit the `ROWS`/`RANGE` clause (e.g., `SUM(Salary) OVER (ORDER BY HireDate)`)?
    *   **Answer:** The default frame is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. This means aggregates like `SUM` or `AVG` will calculate based on all rows from the start of the partition up to the current row, including peers (rows with the same `ORDER BY` value as the current row).
6.  **[Medium]** What is the difference between the `ROWS` and `RANGE` frame specifications?
    *   **Answer:**
        *   `ROWS`: Defines the frame based on a fixed number of physical rows preceding or following the current row, irrespective of their values.
        *   `RANGE`: Defines the frame based on a range of *values* relative to the current row's value in the `ORDER BY` column. All rows with values within that range (including peers with the same value) are included. `RANGE` often requires the `ORDER BY` column to be numeric or date-based and has limitations (e.g., typically only supports `UNBOUNDED` or `CURRENT ROW` as boundaries, not `n PRECEDING/FOLLOWING` directly in many contexts).
7.  **[Hard]** Why might `LAST_VALUE(Salary) OVER (PARTITION BY DepartmentID ORDER BY HireDate)` not give you the salary of the most recently hired person in the department? What frame specification is usually needed?
    *   **Answer:** Because the default frame when `ORDER BY` is present is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. This means `LAST_VALUE` only looks at rows from the start of the partition up to the *current* row (including peers). To get the actual last value within the entire partition based on the order, you need to explicitly define the frame to include all rows in the partition, typically: `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` (or `RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`).
8.  **[Hard]** Can you partition by the result of another window function within the same `SELECT` statement?
    *   **Answer:** No. You cannot directly nest window functions or use the result of one window function in the `PARTITION BY` or `ORDER BY` clause of another window function within the same `SELECT` list. You would need to use a subquery or CTE to calculate the first window function result and then apply the second window function in the outer query, partitioning by the pre-calculated result.
9.  **[Hard]** How can you calculate a running total that resets whenever a specific condition changes, without using `PARTITION BY` on that condition directly (e.g., running total of sales, resetting each time a new product category appears in the ordered list)?
    *   **Answer:** This often involves a "gaps and islands" type problem. A common technique is to use window functions in multiple steps (via CTEs):
        1.  Identify the start of each new group/condition (e.g., using `LAG` to see if the category changed from the previous row).
        2.  Create a grouping identifier based on these start points (e.g., using a conditional `SUM(...) OVER (ORDER BY ...)` on the start-of-group flag).
        3.  Calculate the running total using `SUM(...) OVER (PARTITION BY NewGroupingIdentifier ORDER BY ...)` in the final step.
10. **[Hard/Tricky]** Do window functions always increase the computational cost of a query compared to a query without them?
    *   **Answer:** Not necessarily. While window functions do perform additional calculations, they often replace much less efficient methods like cursors, complex self-joins, or correlated subqueries. In many scenarios involving ranking, running totals, or accessing adjacent rows, using a window function is significantly *more* performant and efficient than the alternatives, despite the added calculation, because it operates in a set-based manner with optimized internal algorithms. However, complex window functions over large partitions without proper indexing can still be resource-intensive.
