# SQL Deep Dive: Window Functions

## 1. Introduction: Calculations Across Row Sets

Window functions perform calculations across a set of table rows that are somehow related to the current row. Unlike aggregate functions used with `GROUP BY` (which collapse rows into a single output row per group), window functions **do not collapse rows**. They return a value for *each row* based on the "window" of rows defined by the function's `OVER()` clause.

**Why use Window Functions?**

*   **Contextual Calculations:** Calculate values (like ranks, running totals, moving averages, percentages) based on a related set of rows without losing the detail of the individual rows.
*   **Ranking and Partitioning:** Easily rank rows within groups (e.g., top N per category) or assign sequential numbers.
*   **Accessing Adjacent Rows:** Retrieve values from preceding or succeeding rows (`LAG`, `LEAD`).
*   **Complex Analysis:** Enable sophisticated analytical queries directly within SQL.

**Key Components:**

*   **Window Function:** The function itself (e.g., `ROW_NUMBER()`, `RANK()`, `SUM()`, `AVG()`, `LAG()`).
*   **`OVER()` Clause:** This is mandatory for window functions and defines the window (set of rows) the function operates on. It has optional sub-clauses:
    *   **`PARTITION BY partition_column(s)`:** Divides the rows into partitions (groups). The window function is applied independently to each partition. If omitted, the entire result set is treated as a single partition.
    *   **`ORDER BY order_column(s)`:** Specifies the logical order of rows *within* each partition. Required by ranking functions and influences order-dependent functions like `LAG`, `LEAD`, and running totals/averages.
    *   **`ROWS` / `RANGE` / `GROUPS` Frame Clause:** (Optional, used with `ORDER BY`) Defines the specific subset of rows within the partition relative to the current row (the window frame) for aggregate window functions (e.g., `ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING` for a moving average).

## 2. Window Functions in Action: Analysis of `32_select_window_functions.sql`

This script demonstrates various types and uses of window functions.

**a) Basic Window Aggregates (`OVER()`)**

```sql
SELECT EmployeeID, ..., Salary,
    AVG(Salary) OVER() AS CompanyAvgSalary, -- Avg over all rows
    MAX(Salary) OVER() AS CompanyMaxSalary  -- Max over all rows
FROM HR.EMP_Details;
```

*   **Explanation:** When `OVER()` is empty, the window is the entire result set. `AVG(Salary) OVER()` calculates the average salary across all employees and displays that same average value on every employee row, alongside their individual salary.

<details>
<summary>Click to see Example Visualization (Basic Window Aggregates)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------+
    | EmployeeID | Salary |
    +------------+--------+
    | 1000       | 60000  |
    | 1001       | 75000  |
    | 1002       | 90000  |
    | 1003       | 55000  |
    +------------+--------+
    ```
*   **Conceptual Calculation:** Overall Average Salary = (60k+75k+90k+55k)/4 = 70000
*   **Example Query:**
    ```sql
    SELECT EmployeeID, Salary,
        AVG(Salary) OVER() AS CompanyAvgSalary
    FROM HR.EMP_Details;
    ```
*   **Output Result Set:** The overall average (70000) is displayed on each row.
    ```
    +------------+--------+------------------+
    | EmployeeID | Salary | CompanyAvgSalary |
    +------------+--------+------------------+
    | 1000       | 60000  | 70000.00         |
    | 1001       | 75000  | 70000.00         |
    | 1002       | 90000  | 70000.00         |
    | 1003       | 55000  | 70000.00         |
    +------------+--------+------------------+
    ```
*   **Key Takeaway:** An empty `OVER()` clause makes the window function operate over the entire result set, providing global aggregates alongside detail rows.

</details>

**b) Partitioning (`PARTITION BY`)**

```sql
SELECT EmployeeID, ..., DepartmentID, Salary,
    AVG(Salary) OVER(PARTITION BY DepartmentID) AS DeptAvgSalary -- Avg within this row's Dept
FROM HR.EMP_Details;
```

*   **Explanation:** `PARTITION BY DepartmentID` divides the data into separate windows, one for each department. The `AVG(Salary)` is calculated independently within each department's window. Each employee row shows their salary and the average salary *for their specific department*.

<details>
<summary>Click to see Example Visualization (Partitioning)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1004       | 1            | 62000  |
    | 1005       | 1            | 48000  |
    | 1000       | 2            | 60000  |
    | 1001       | 2            | 75000  |
    | 1002       | 3            | 90000  |
    +------------+--------------+--------+
    ```
*   **Conceptual Averages:** Dept 1 Avg = 55000, Dept 2 Avg = 67500, Dept 3 Avg = 90000
*   **Example Query:**
    ```sql
    SELECT EmployeeID, DepartmentID, Salary,
        AVG(Salary) OVER(PARTITION BY DepartmentID) AS DeptAvgSalary
    FROM HR.EMP_Details;
    ```
*   **Output Result Set:** Each row shows the average salary calculated only within its own department partition.
    ```
    +------------+--------------+--------+---------------+
    | EmployeeID | DepartmentID | Salary | DeptAvgSalary |
    +------------+--------------+--------+---------------+
    | 1004       | 1            | 62000  | 55000.00      |
    | 1005       | 1            | 48000  | 55000.00      |
    | 1000       | 2            | 60000  | 67500.00      |
    | 1001       | 2            | 75000  | 67500.00      |
    | 1002       | 3            | 90000  | 90000.00      |
    +------------+--------------+--------+---------------+
    ```
*   **Key Takeaway:** `PARTITION BY` divides the data, and the window function restarts its calculation for each partition.

</details>

**c) Ordering within Partitions (`ORDER BY` in `OVER`)**

```sql
SELECT EmployeeID, ..., DepartmentID, Salary,
    SUM(Salary) OVER(PARTITION BY DepartmentID ORDER BY Salary) AS RunningDeptTotal
FROM HR.EMP_Details;
```

*   **Explanation:** `ORDER BY Salary` within the `OVER` clause defines the order for order-dependent calculations like running totals. Here, `SUM(Salary)` calculates the cumulative sum of salaries within each department, ordered from lowest to highest salary. The default frame (`RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`) is used.

<details>
<summary>Click to see Example Visualization (Ordering within Partitions)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1005       | 1            | 48000  |
    | 1004       | 1            | 62000  |
    | 1003       | 2            | 55000  |
    | 1000       | 2            | 60000  |
    | 1001       | 2            | 75000  |
    | 1002       | 3            | 90000  |
    +------------+--------------+--------+
    ```
*   **Example Query:**
    ```sql
    SELECT EmployeeID, DepartmentID, Salary,
        SUM(Salary) OVER(PARTITION BY DepartmentID ORDER BY Salary ASC) AS RunningDeptTotal
    FROM HR.EMP_Details;
    ```
*   **Output Result Set:** Shows the running total of salary within each department, ordered by salary ascending.
    ```
    +------------+--------------+--------+------------------+
    | EmployeeID | DepartmentID | Salary | RunningDeptTotal |
    +------------+--------------+--------+------------------+
    | 1005       | 1            | 48000  | 48000            | <- Dept 1: 48k
    | 1004       | 1            | 62000  | 110000           | <- Dept 1: 48k + 62k
    | 1003       | 2            | 55000  | 55000            | <- Dept 2: 55k
    | 1000       | 2            | 60000  | 115000           | <- Dept 2: 55k + 60k
    | 1001       | 2            | 75000  | 190000           | <- Dept 2: 55k + 60k + 75k
    | 1002       | 3            | 90000  | 90000            | <- Dept 3: 90k
    +------------+--------------+--------+------------------+
    ```
*   **Key Takeaway:** `ORDER BY` within `OVER()` is crucial for functions like running totals, defining the sequence in which rows are processed for the cumulative calculation within each partition.

</details>

**d) Ranking Functions (`ROW_NUMBER`, `RANK`, `DENSE_RANK`)**

```sql
SELECT EmployeeID, ..., DepartmentID, Salary,
    ROW_NUMBER() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS DepartmentRank,
    RANK()       OVER(ORDER BY Salary DESC) AS SalaryRank, -- Rank with gaps
    DENSE_RANK() OVER(ORDER BY Salary DESC) AS DenseSalaryRank -- Rank without gaps
FROM HR.EMP_Details;
```

*   **Explanation:** Assign ranks based on the `ORDER BY` clause, optionally within partitions.
    *   `ROW_NUMBER()`: Always assigns unique, consecutive numbers (1, 2, 3...).
    *   `RANK()`: Assigns the same rank for ties, skips subsequent ranks (1, 1, 3...).
    *   `DENSE_RANK()`: Assigns the same rank for ties, does not skip ranks (1, 1, 2...).

<details>
<summary>Click to see Example Visualization (Ranking Functions)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet with Ties):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1001       | 2            | 75000  | <- Highest in Dept 2
    | 1000       | 2            | 60000  |
    | 1003       | 2            | 55000  |
    | 1004       | 1            | 62000  | <- Highest in Dept 1 (Tie)
    | 1005       | 1            | 62000  | <- Highest in Dept 1 (Tie)
    | 1006       | 1            | 48000  |
    +------------+--------------+--------+
    ```
*   **Example Query:**
    ```sql
    SELECT EmployeeID, DepartmentID, Salary,
        ROW_NUMBER() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS RowNum,
        RANK()       OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS SalaryRank,
        DENSE_RANK() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS DenseRank
    FROM HR.EMP_Details;
    ```
*   **Output Result Set:** Shows different ranking results within each department based on salary.
    ```
    +------------+--------------+--------+--------+------------+-----------+
    | EmployeeID | DepartmentID | Salary | RowNum | SalaryRank | DenseRank |
    +------------+--------------+--------+--------+------------+-----------+
    | 1004       | 1            | 62000  | 1      | 1          | 1         | <- Dept 1
    | 1005       | 1            | 62000  | 2      | 1          | 1         |
    | 1006       | 1            | 48000  | 3      | 3          | 2         |
    | 1001       | 2            | 75000  | 1      | 1          | 1         | <- Dept 2
    | 1000       | 2            | 60000  | 2      | 2          | 2         |
    | 1003       | 2            | 55000  | 3      | 3          | 3         |
    +------------+--------------+--------+--------+------------+-----------+
    ```
*   **Key Takeaway:** `ROW_NUMBER`, `RANK`, and `DENSE_RANK` provide different ways to rank rows within partitions, differing primarily in how they handle ties.

</details>

**e) `NTILE(N)`**

```sql
SELECT EmployeeID, ..., Salary,
    NTILE(4) OVER(ORDER BY Salary) AS SalaryQuartile -- Divide into 4 groups
FROM HR.EMP_Details;
```

*   **Explanation:** Divides the rows within each partition (or the whole set if no `PARTITION BY`) into `N` roughly equal groups based on the `ORDER BY` clause and assigns a group number (1 to N). Useful for creating percentiles, quartiles, deciles, etc.

<details>
<summary>Click to see Example Visualization (NTILE)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------+
    | EmployeeID | Salary |
    +------------+--------+
    | 1005       | 48000  |
    | 1003       | 55000  |
    | 1000       | 60000  |
    | 1004       | 62000  |
    | 1001       | 75000  |
    | 1002       | 90000  |
    +------------+--------+
    ```
*   **Example Query:** Divide employees into 4 salary quartiles.
    ```sql
    SELECT EmployeeID, Salary,
        NTILE(4) OVER(ORDER BY Salary) AS SalaryQuartile
    FROM HR.EMP_Details;
    ```
*   **Output Result Set:** Assigns each employee to one of 4 groups based on salary order. (6 rows / 4 groups = groups 1 & 2 get 2 rows, groups 3 & 4 get 1 row).
    ```
    +------------+--------+----------------+
    | EmployeeID | Salary | SalaryQuartile |
    +------------+--------+----------------+
    | 1005       | 48000  | 1              |
    | 1003       | 55000  | 1              |
    | 1000       | 60000  | 2              |
    | 1004       | 62000  | 2              |
    | 1001       | 75000  | 3              |
    | 1002       | 90000  | 4              |
    +------------+--------+----------------+
    ```
*   **Key Takeaway:** `NTILE(N)` distributes rows as evenly as possible into N ordered groups (tiles).

</details>

**f) Offset Functions (`LAG`, `LEAD`)**

```sql
SELECT EmployeeID, ..., HireDate, Salary,
    LAG(Salary) OVER(ORDER BY HireDate) AS PreviousEmpSalary, -- Salary of previous hire
    LEAD(Salary) OVER(ORDER BY HireDate) AS NextEmpSalary,    -- Salary of next hire
    Salary - LAG(Salary, 1, 0) OVER(ORDER BY HireDate) AS SalaryGap -- Diff from previous, default 0
FROM HR.EMP_Details;
```

*   **Explanation:** Access values from preceding (`LAG`) or succeeding (`LEAD`) rows within the partition based on the `ORDER BY` clause.
    *   `LAG(Column, offset, default)`: Gets `Column` value from `offset` rows before the current row. Returns `default` if the offset row doesn't exist. Default offset is 1, default `default` is `NULL`.
    *   `LEAD(...)`: Similar but looks forward.

<details>
<summary>Click to see Example Visualization (LAG/LEAD)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet, ordered by HireDate):**
    ```
    +------------+------------+--------+
    | EmployeeID | HireDate   | Salary |
    +------------+------------+--------+
    | 1002       | 2020-05-20 | 90000  |
    | 1001       | 2021-03-10 | 75000  |
    | 1000       | 2022-01-15 | 60000  |
    | 1004       | 2022-11-30 | 62000  |
    +------------+------------+--------+
    ```
*   **Example Query:**
    ```sql
    SELECT EmployeeID, HireDate, Salary,
        LAG(Salary, 1, 0) OVER(ORDER BY HireDate) AS PreviousSalary, -- Salary of previous hire, default 0
        LEAD(Salary) OVER(ORDER BY HireDate) AS NextSalary       -- Salary of next hire, default NULL
    FROM HR.EMP_Details;
    ```
*   **Output Result Set:** Shows the salary of the employee hired just before and just after the current row's employee.
    ```
    +------------+------------+--------+----------------+------------+
    | EmployeeID | HireDate   | Salary | PreviousSalary | NextSalary |
    +------------+------------+--------+----------------+------------+
    | 1002       | 2020-05-20 | 90000  | 0              | 75000      | <- First row, LAG gets default 0
    | 1001       | 2021-03-10 | 75000  | 90000          | 60000      |
    | 1000       | 2022-01-15 | 60000  | 75000          | 62000      |
    | 1004       | 2022-11-30 | 62000  | 60000          | NULL       | <- Last row, LEAD gets default NULL
    +------------+------------+--------+----------------+------------+
    ```
*   **Key Takeaway:** `LAG` and `LEAD` allow accessing data from adjacent rows based on a specified order, useful for comparing consecutive records.

</details>

**g) Boundary Functions (`FIRST_VALUE`, `LAST_VALUE`)**

```sql
SELECT EmployeeID, ..., DepartmentID, Salary,
    FIRST_VALUE(Salary) OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS HighestDeptSalary,
    LAST_VALUE(Salary) OVER(PARTITION BY DepartmentID ORDER BY Salary DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS LowestDeptSalary
FROM HR.EMP_Details;
```

*   **Explanation:** Retrieve the value of an expression from the first (`FIRST_VALUE`) or last (`LAST_VALUE`) row within the defined window frame.
*   **Important Frame Note:** The default frame for `ORDER BY` often ends at `CURRENT ROW`. To make `LAST_VALUE` correctly find the last value in the *entire partition*, you usually need to explicitly define the frame to cover the whole partition (e.g., `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` or `RANGE ...`).

<details>
<summary>Click to see Example Visualization (FIRST_VALUE/LAST_VALUE)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1005       | 1            | 48000  | <- Lowest in Dept 1
    | 1004       | 1            | 62000  | <- Highest in Dept 1
    | 1003       | 2            | 55000  | <- Lowest in Dept 2
    | 1000       | 2            | 60000  |
    | 1001       | 2            | 75000  | <- Highest in Dept 2
    +------------+--------------+--------+
    ```
*   **Example Query:** Find highest and lowest salary within each department.
    ```sql
    SELECT EmployeeID, DepartmentID, Salary,
        FIRST_VALUE(Salary) OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS HighestInDept,
        LAST_VALUE(Salary) OVER(PARTITION BY DepartmentID ORDER BY Salary DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS LowestInDept -- Need full frame for LAST_VALUE
    FROM HR.EMP_Details;
    ```
*   **Output Result Set:** Shows the highest and lowest salary within the employee's department on each row.
    ```
    +------------+--------------+--------+---------------+--------------+
    | EmployeeID | DepartmentID | Salary | HighestInDept | LowestInDept |
    +------------+--------------+--------+---------------+--------------+
    | 1004       | 1            | 62000  | 62000         | 48000        |
    | 1005       | 1            | 48000  | 62000         | 48000        |
    | 1001       | 2            | 75000  | 75000         | 55000        |
    | 1000       | 2            | 60000  | 75000         | 55000        |
    | 1003       | 2            | 55000  | 75000         | 55000        |
    +------------+--------------+--------+---------------+--------------+
    ```
*   **Key Takeaway:** `FIRST_VALUE` and `LAST_VALUE` retrieve values from the boundaries of the window frame. Remember to specify the full frame for `LAST_VALUE` when using `ORDER BY` if you want the true last value of the partition.

</details>

**h) Window Frame Specification (`ROWS`/`RANGE`/`GROUPS BETWEEN ...`)**

```sql
SELECT EmployeeID, ..., HireDate, Salary,
    AVG(Salary) OVER(ORDER BY HireDate ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS MovingAvg3Employees
FROM HR.EMP_Details;
```

*   **Explanation:** Explicitly defines the window frame used by aggregate window functions when `ORDER BY` is present.
    *   `ROWS`: Defines the frame based on a physical number of rows relative to the current row.
    *   `RANGE`: Defines the frame based on a logical range of values relative to the current row's value in the `ORDER BY` column(s) (treats rows with tied values as a single unit). Requires `ORDER BY` on a single numeric/date column.
    *   `GROUPS` (SQL 2022+): Defines the frame based on groups of distinct values in the `ORDER BY` clause.
    *   Common boundaries: `UNBOUNDED PRECEDING`, `N PRECEDING`, `CURRENT ROW`, `N FOLLOWING`, `UNBOUNDED FOLLOWING`.

<details>
<summary>Click to see Example Visualization (Window Frame)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet, ordered by HireDate):**
    ```
    +------------+------------+--------+
    | EmployeeID | HireDate   | Salary |
    +------------+------------+--------+
    | 1002       | 2020-05-20 | 90000  |
    | 1001       | 2021-03-10 | 75000  |
    | 1000       | 2022-01-15 | 60000  |
    | 1004       | 2022-11-30 | 62000  |
    | 1005       | 2023-02-20 | 48000  |
    +------------+------------+--------+
    ```
*   **Example Query:** Calculate 3-employee moving average salary based on hire date.
    ```sql
    SELECT EmployeeID, HireDate, Salary,
        AVG(Salary) OVER(ORDER BY HireDate ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS MovingAvg3Employees
    FROM HR.EMP_Details;
    ```
*   **Output Result Set:** Shows the average salary considering the current row, the previous row, and the next row based on HireDate order.
    ```
    +------------+------------+--------+---------------------+
    | EmployeeID | HireDate   | Salary | MovingAvg3Employees |
    +------------+------------+--------+---------------------+
    | 1002       | 2020-05-20 | 90000  | 82500.00            | -- Avg(90k, 75k)
    | 1001       | 2021-03-10 | 75000  | 75000.00            | -- Avg(90k, 75k, 60k)
    | 1000       | 2022-01-15 | 60000  | 65666.66            | -- Avg(75k, 60k, 62k)
    | 1004       | 2022-11-30 | 62000  | 56666.66            | -- Avg(60k, 62k, 48k)
    | 1005       | 2023-02-20 | 48000  | 55000.00            | -- Avg(62k, 48k)
    +------------+------------+--------+---------------------+
    ```
*   **Key Takeaway:** The frame clause (`ROWS`/`RANGE`/`GROUPS BETWEEN...`) precisely defines the set of rows within the partition used for aggregate window functions relative to the current row.

</details>

**i) Named Windows (`WINDOW` Clause)**

```sql
SELECT EmployeeID, ..., DepartmentID, Salary,
    AVG(Salary) OVER w AS AvgSalary, -- Use named window 'w'
    MAX(Salary) OVER w AS MaxSalary  -- Use named window 'w'
FROM HR.EMP_Details
WINDOW w AS (PARTITION BY DepartmentID); -- Define window 'w' once
```

*   **Explanation:** Defines a window specification with a name (`w`) using the `WINDOW` clause (placed after `WHERE`/`GROUP BY`/`HAVING`). This named window can then be referenced in the `OVER` clause of multiple window functions, improving readability and maintainability if the same window definition is used repeatedly.

<details>
<summary>Click to see Example Visualization (Named Windows)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1004       | 1            | 62000  |
    | 1005       | 1            | 48000  |
    | 1000       | 2            | 60000  |
    | 1001       | 2            | 75000  |
    | 1002       | 3            | 90000  |
    +------------+--------------+--------+
    ```
*   **Example Query:**
    ```sql
    SELECT EmployeeID, DepartmentID, Salary,
        AVG(Salary) OVER w AS DeptAvgSalary, -- Use named window 'w'
        MAX(Salary) OVER w AS DeptMaxSalary  -- Use named window 'w'
    FROM HR.EMP_Details
    WINDOW w AS (PARTITION BY DepartmentID); -- Define window 'w' once
    ```
*   **Output Result Set:** Both window functions use the same partition definition specified in the `WINDOW` clause.
    ```
    +------------+--------------+--------+---------------+---------------+
    | EmployeeID | DepartmentID | Salary | DeptAvgSalary | DeptMaxSalary |
    +------------+--------------+--------+---------------+---------------+
    | 1004       | 1            | 62000  | 55000.00      | 62000         |
    | 1005       | 1            | 48000  | 55000.00      | 62000         |
    | 1000       | 2            | 60000  | 67500.00      | 75000         |
    | 1001       | 2            | 75000  | 67500.00      | 75000         |
    | 1002       | 3            | 90000  | 90000.00      | 90000         |
    +------------+--------------+--------+---------------+---------------+
    ```
*   **Key Takeaway:** The `WINDOW` clause allows defining reusable window specifications, reducing redundancy when multiple window functions share the same `PARTITION BY`/`ORDER BY`/frame logic.

</details>

**j) Window Functions with Aggregates (Conceptual)**

```sql
-- Example showing window function used AFTER grouping
SELECT DepartmentID, COUNT(*) AS HireCount,
    SUM(COUNT(*)) OVER(PARTITION BY YEAR(HireDate)) AS YearlyTotal -- Window function on aggregate
FROM HR.EMP_Details
GROUP BY YEAR(HireDate), DepartmentID;
```

*   **Explanation:** Window functions are processed logically *after* `GROUP BY` aggregates. This allows you to perform window calculations (like `SUM(...) OVER(...)`) on the results of aggregate functions (`COUNT(*)` in this case).

<details>
<summary>Click to see Example Visualization (Window Fn with Aggregates)</summary>

*   **Conceptual Grouped Result (Input to Window Function):**
    ```
    +----------+--------------+-----------+
    | HireYear | DepartmentID | HireCount |
    +----------+--------------+-----------+
    | 2021     | 2            | 1         |
    | 2022     | 1            | 1         |
    | 2022     | 2            | 1         |
    | 2022     | 3            | 1         |
    | 2023     | 1            | 1         |
    | 2023     | 2            | 1         |
    +----------+--------------+-----------+
    ```
*   **Example Query (Simplified):**
    ```sql
    SELECT
        YEAR(HireDate) AS HireYear,
        DepartmentID,
        COUNT(*) AS DeptHireCount,
        SUM(COUNT(*)) OVER(PARTITION BY YEAR(HireDate)) AS YearlyTotalHires -- Window Fn on COUNT(*)
    FROM HR.EMP_Details
    GROUP BY YEAR(HireDate), DepartmentID;
    ```
*   **Output Result Set:** The `YearlyTotalHires` is calculated by the window function operating on the `DeptHireCount` values produced by the `GROUP BY`.
    ```
    +----------+--------------+---------------+------------------+
    | HireYear | DepartmentID | DeptHireCount | YearlyTotalHires |
    +----------+--------------+---------------+------------------+
    | 2021     | 2            | 1             | 1                | -- Total for 2021 = 1
    | 2022     | 1            | 1             | 3                | -- Total for 2022 = 1+1+1
    | 2022     | 2            | 1             | 3                |
    | 2022     | 3            | 1             | 3                |
    | 2023     | 1            | 1             | 2                | -- Total for 2023 = 1+1
    | 2023     | 2            | 1             | 2                |
    +----------+--------------+---------------+------------------+
    ```
*   **Key Takeaway:** Window functions can be applied to the results of standard aggregations, enabling calculations across grouped summary data.

</details>

## 3. Targeted Interview Questions (Based on `32_select_window_functions.sql`)

**Question 1:** What is the key difference between a standard aggregate function (like `AVG(Salary)`) used with `GROUP BY DepartmentID` and a window aggregate function `AVG(Salary) OVER(PARTITION BY DepartmentID)`? Consider the number of rows returned.

**Solution 1:**

*   `AVG(Salary)` with `GROUP BY DepartmentID`: Collapses all rows for each department into a single output row per department, showing only the `DepartmentID` and the calculated average salary for that department.
*   `AVG(Salary) OVER(PARTITION BY DepartmentID)`: Does **not** collapse rows. It returns **all** original employee rows. For each employee row, it calculates the average salary of all employees within that row's partition (department) and displays that departmental average alongside the individual employee's details.

**Question 2:** Explain the difference between `ROW_NUMBER()`, `RANK()`, and `DENSE_RANK()` when dealing with tied values in the `ORDER BY` clause.

**Solution 2:**

*   `ROW_NUMBER()`: Assigns a unique, consecutive integer regardless of ties (e.g., 1, 2, 3, 4...). The ordering between tied rows is arbitrary unless the `ORDER BY` includes a tie-breaker.
*   `RANK()`: Assigns the same rank to tied rows. The next rank after a tie reflects the number of tied rows (e.g., 1, 2, 2, **4**...). It leaves gaps in the ranking sequence.
*   `DENSE_RANK()`: Assigns the same rank to tied rows but does **not** leave gaps in the sequence. The next rank after a tie is simply the next consecutive integer (e.g., 1, 2, 2, **3**...).

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What clause is mandatory when using any window function?
    *   **Answer:** The `OVER()` clause.
2.  **[Easy]** Which window function would you use to find the value from the immediately preceding row based on a specific order?
    *   **Answer:** `LAG()`.
3.  **[Medium]** If you use `SUM(Salary) OVER(ORDER BY HireDate)`, what does this calculate for each row?
    *   **Answer:** It calculates a **running total** of `Salary`, summing the salaries of all employees hired up to and including the current row's `HireDate` (based on the default window frame `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`).
4.  **[Medium]** Can you use `PARTITION BY` and `ORDER BY` within the same `OVER()` clause? What does each part do?
    *   **Answer:** Yes. `PARTITION BY` divides the rows into independent groups (partitions), and the window function operates separately within each partition. `ORDER BY` specifies the logical order of rows *within* each partition, which is necessary for ranking functions and affects order-dependent functions like `LAG`/`LEAD` and running totals/aggregates with specific frames.
5.  **[Medium]** What is the purpose of the `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` frame specification often used with `LAST_VALUE`?
    *   **Answer:** By default, when `ORDER BY` is used, the window frame often ends at the `CURRENT ROW`. This means `LAST_VALUE` would only see values up to the current row. Specifying `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` explicitly defines the frame to include *all* rows in the partition, ensuring `LAST_VALUE` correctly identifies the value from the actual last row in the partition according to the `ORDER BY` clause.
6.  **[Medium]** Can you nest window functions (e.g., `AVG(SUM(Salary) OVER(...)) OVER(...)`)?
    *   **Answer:** No, you cannot directly nest window functions in this way. You would typically need to use a subquery or CTE to calculate the inner window function first, and then apply the outer window function to the results in the outer query.
7.  **[Hard]** What is the difference between using `ROWS` and `RANGE` in the window frame definition (e.g., `ROWS BETWEEN 1 PRECEDING AND CURRENT ROW` vs `RANGE BETWEEN 1 PRECEDING AND CURRENT ROW`)? When might they produce different results?
    *   **Answer:**
        *   `ROWS`: Defines the frame based on a fixed number of physical rows relative to the current row, regardless of their values in the `ORDER BY` column(s).
        *   `RANGE`: Defines the frame based on a range of *values* relative to the current row's value in the `ORDER BY` column(s). All rows with the same value in the `ORDER BY` column(s) as the boundary rows are included. `RANGE` typically requires the `ORDER BY` clause to contain a single column of a numeric or date type.
        *   **Difference:** They produce different results when there are **ties** in the `ORDER BY` values. `ROWS` always includes the specified number of physical rows. `RANGE` includes all rows whose `ORDER BY` value falls within the calculated range, which might include more rows than specified by the offset if there are ties at the boundary. For example, with `RANGE BETWEEN 1 PRECEDING AND CURRENT ROW`, if the preceding row and the current row have the same `ORDER BY` value, the frame includes *all* rows with that value, potentially going back more than one physical row.
8.  **[Hard]** Can window functions be used in the `UPDATE` statement's `SET` clause? Give a potential use case.
    *   **Answer:** Yes. Window functions can be used in the `SET` clause of an `UPDATE` statement (often via a CTE or subquery if updating the same table being referenced in the window function to avoid ambiguity).
        *   **Use Case:** Updating a column based on a comparison with a group average or rank. For example, giving a bonus only to employees whose salary is below the average for their department:
            ```sql
            WITH DeptAvg AS (
                SELECT EmployeeID, AVG(Salary) OVER(PARTITION BY DepartmentID) AS AvgSal
                FROM HR.EMP_Details
            )
            UPDATE e SET e.Bonus = 500
            FROM HR.EMP_Details e JOIN DeptAvg da ON e.EmployeeID = da.EmployeeID
            WHERE e.Salary < da.AvgSal;
            ```
9.  **[Hard]** Are window functions calculated before or after the `WHERE` clause is applied? What are the implications?
    *   **Answer:** Window functions are calculated logically **after** the `WHERE` clause filters the rows. This means the window function only operates on the rows that have *already passed* the `WHERE` clause filtering.
        *   **Implications:** If you filter out rows with `WHERE`, those rows will not be part of any partition or calculation performed by the window functions in the `SELECT` list. This is important to remember when calculating things like ranks or running totals – they only consider the filtered dataset.
10. **[Hard/Tricky]** Can you use an aggregate window function (like `SUM(...) OVER(...)`) and a regular aggregate function (like `SUM(...)` with `GROUP BY`) in the same `SELECT` statement? If so, how does the evaluation work?
    *   **Answer:** Yes, you can, but it requires careful understanding of the logical processing order.
        1.  The `FROM` and `WHERE` clauses execute first.
        2.  The `GROUP BY` clause executes, collapsing rows into groups.
        3.  Regular aggregate functions (`SUM(Salary)`) are calculated for each group.
        4.  *Then*, window functions (`SUM(SomeAggregate) OVER(...)`) are calculated based on the *grouped* results. The window function's `PARTITION BY` and `ORDER BY` would operate on the rows produced by the `GROUP BY` clause.
    *   This allows you to, for example, calculate the sum for each group and then calculate a running total or percentage of total *across those groups*. Example 12 in the script demonstrates this by calculating `COUNT(*)` per group and then using `SUM(COUNT(*)) OVER(...)` to get yearly totals based on the grouped counts.
