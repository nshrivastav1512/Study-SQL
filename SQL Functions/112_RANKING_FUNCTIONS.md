# SQL Ranking Functions

## Introduction

**Definition:** SQL Ranking Functions are a type of window function that assigns a rank or sequential number to each row within a partition of a result set, based on a specified ordering. Unlike aggregate functions which collapse rows into a single output row, window functions perform calculations across a set of table rows that are somehow related to the current row, returning a value for *each* row based on that "window" of rows.

**Explanation:** Ranking functions are essential for producing reports that involve ordering or ranking data, such as finding the top N performers, assigning sequential numbers, ranking items within categories, or dividing data into quantiles (like quartiles or percentiles). They all require an `OVER` clause, which defines how the rows are partitioned (grouped) and ordered for the ranking calculation.

**Key Components of the `OVER` Clause for Ranking:**

*   **`PARTITION BY partition_expression,...`**: (Optional) Divides the rows of the result set into partitions (groups). The ranking function is applied independently to each partition. If omitted, the entire result set is treated as a single partition.
*   **`ORDER BY order_by_expression [ASC|DESC],...`**: (Required for Ranking Functions) Specifies the logical order of the rows within each partition upon which the ranking function is based.

## Functions Covered in this Section

This document covers the primary SQL Server Ranking Functions, demonstrated using hypothetical `HR.EmployeePerformance` and `HR.EmployeeRankings` tables:

1.  `ROW_NUMBER() OVER ( [PARTITION BY ...] ORDER BY ... )`: Assigns a unique sequential integer (1, 2, 3, ...) to each row within its partition, based on the specified order. Ties are broken arbitrarily but consistently within a single query execution.
2.  `RANK() OVER ( [PARTITION BY ...] ORDER BY ... )`: Assigns a rank to each row within its partition based on the order. Rows with equal values in the `ORDER BY` clause receive the same rank. The next rank assigned will skip numbers, creating gaps (e.g., 1, 1, 3, 4, 4, 6).
3.  `DENSE_RANK() OVER ( [PARTITION BY ...] ORDER BY ... )`: Similar to `RANK()`, assigns a rank based on the order, with equal values receiving the same rank. However, `DENSE_RANK` does *not* create gaps in the ranking sequence (e.g., 1, 1, 2, 3, 3, 4).
4.  `NTILE(integer_expression) OVER ( [PARTITION BY ...] ORDER BY ... )`: Distributes the rows in an ordered partition into a specified number of groups (`integer_expression`). Each group is assigned a number from 1 up to `integer_expression`. Useful for creating quartiles (`NTILE(4)`), deciles (`NTILE(10)`), etc.

*(Note: The SQL script includes logic to create and populate sample `HR.EmployeePerformance` and `HR.EmployeeRankings` tables if they don't exist.)*

---

## Examples

### 1. ROW_NUMBER()

**Goal:** Assign a unique sequential rank to employee performance records based on `SalesAmount` overall, and also within each `Quarter`.

```sql
SELECT
    EmployeeID,
    Year,
    Quarter,
    SalesAmount,
    ROW_NUMBER() OVER(ORDER BY SalesAmount DESC) AS OverallSalesRank,
    ROW_NUMBER() OVER(PARTITION BY Quarter ORDER BY SalesAmount DESC) AS QuarterlySalesRank
FROM HR.EmployeePerformance
WHERE Year = 2023;
```

**Explanation:**
*   `OverallSalesRank`: `ROW_NUMBER()` assigns ranks 1, 2, 3,... based on `SalesAmount` descending across all rows (no `PARTITION BY`). Even if `SalesAmount` values are tied, `ROW_NUMBER` assigns distinct sequential numbers.
*   `QuarterlySalesRank`: `PARTITION BY Quarter` restarts the numbering for each quarter. Within each quarter, rows are numbered 1, 2, 3,... based on `SalesAmount` descending.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data for Year 2023:</p>
<pre><code>
EmployeeID  Year  Quarter  SalesAmount  OverallSalesRank  QuarterlySalesRank
----------  ----  -------  -----------  ----------------  ------------------
2           2023  2        180000.00    1                 1
4           2023  2        175000.00    2                 2
2           2023  1        175000.00    3                 1
4           2023  1        175000.00    4                 2
1           2023  2        165000.00    5                 3
1           2023  1        150000.00    6                 3
3           2023  2        145000.00    7                 4
3           2023  1        125000.00    8                 4
</code></pre>
</details>

### 2. RANK()

**Goal:** Rank employees within each `SkillCategory` based on their `CertificationScore`, allowing ties to share the same rank but causing gaps in subsequent ranks.

```sql
SELECT
    EmployeeID,
    SkillCategory,
    CertificationScore,
    RANK() OVER(PARTITION BY SkillCategory ORDER BY CertificationScore DESC) AS SkillRank_WithGaps
FROM HR.EmployeeRankings;
```

**Explanation:**
*   `PARTITION BY SkillCategory` applies the ranking independently to 'Technical' and 'Management' skills.
*   `ORDER BY CertificationScore DESC` ranks employees with higher scores better.
*   `RANK()` assigns the same rank to employees with the same score within a category. The next rank number reflects the number of rows preceding it (including ties). For example, if two employees tie for 1st, the next rank is 3.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
EmployeeID  SkillCategory  CertificationScore  SkillRank_WithGaps
----------  -------------  ------------------  ------------------
2           Management     90.50               1
4           Management     90.50               1
1           Management     88.00               3
3           Management     75.00               4
2           Technical      92.00               1
4           Technical      92.00               1
1           Technical      85.50               3
3           Technical      78.50               4
</code></pre>
</details>

### 3. DENSE_RANK()

**Goal:** Rank employees based on the number of `ProjectsCompleted`, ensuring that tied ranks do not create gaps in the sequence.

```sql
SELECT
    EmployeeID,
    Year,
    Quarter,
    ProjectsCompleted,
    DENSE_RANK() OVER(ORDER BY ProjectsCompleted DESC) AS ProjectRank_NoGaps
FROM HR.EmployeePerformance
WHERE Year = 2023;
```

**Explanation:**
*   `ORDER BY ProjectsCompleted DESC` ranks employees who completed more projects higher.
*   `DENSE_RANK()` assigns the same rank to ties, like `RANK()`. However, the next rank assigned is always the immediately following integer. If two employees tie for 1st, the next rank is 2 (not 3 as with `RANK()`).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data for Year 2023:</p>
<pre><code>
EmployeeID  Year  Quarter  ProjectsCompleted  ProjectRank_NoGaps
----------  ----  -------  -----------------  ------------------
3           2023  1        6                  1
1           2023  1        5                  2
2           2023  2        5                  2
3           2023  2        5                  2
2           2023  1        4                  3
1           2023  2        4                  3
4           2023  2        4                  3
4           2023  1        3                  4
</code></pre>
</details>

### 4. NTILE()

**Goal:** Divide employees into 4 performance groups (quartiles) based on `SalesAmount` and `CustomerSatisfaction`.

```sql
SELECT
    EmployeeID,
    SalesAmount,
    CustomerSatisfaction,
    NTILE(4) OVER(ORDER BY SalesAmount DESC) AS SalesQuartile,
    NTILE(4) OVER(ORDER BY CustomerSatisfaction DESC) AS SatisfactionQuartile
FROM HR.EmployeePerformance
WHERE Year = 2023;
```

**Explanation:**
*   `NTILE(4)` attempts to divide the ordered rows into 4 groups (quartiles) of as equal size as possible.
*   `ORDER BY SalesAmount DESC` determines the order for sales quartiles (highest sales in quartile 1).
*   `ORDER BY CustomerSatisfaction DESC` determines the order for satisfaction quartiles (highest satisfaction in quartile 1).
*   If the number of rows is not evenly divisible by the NTILE argument (4 here), the earlier groups will have one extra member.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on 8 sample rows for Year 2023, each quartile will have 8/4 = 2 members.</p>
<pre><code>
EmployeeID  SalesAmount  CustomerSatisfaction  SalesQuartile  SatisfactionQuartile
----------  -----------  --------------------  -------------  --------------------
2           180000.00    4.80                  1              2
4           175000.00    4.90                  1              1
2           175000.00    4.90                  2              1
4           175000.00    4.90                  2              1
1           165000.00    4.70                  3              3
1           150000.00    4.80                  3              2
3           145000.00    4.80                  4              2
3           125000.00    4.70                  4              3
</code></pre>
</details>

---

## Interview Question

**Question:** Using the `HR.EmployeePerformance` table, write a query to find the top 2 employees based on `SalesAmount` within each `DepartmentID` for the `Year` 2023. Display the `DepartmentID`, `EmployeeID`, `SalesAmount`, and their rank within the department.

### Solution Script

```sql
WITH RankedSales AS (
    SELECT
        DepartmentID,
        EmployeeID,
        SalesAmount,
        ROW_NUMBER() OVER(PARTITION BY DepartmentID ORDER BY SalesAmount DESC) AS DeptSalesRank
    FROM HR.EmployeePerformance
    WHERE Year = 2023
)
SELECT
    DepartmentID,
    EmployeeID,
    SalesAmount,
    DeptSalesRank
FROM RankedSales
WHERE DeptSalesRank <= 2;
```

### Explanation

1.  **`WITH RankedSales AS (...)`**: Defines a Common Table Expression (CTE) named `RankedSales` to simplify the query.
2.  **`SELECT DepartmentID, EmployeeID, SalesAmount, ... FROM HR.EmployeePerformance WHERE Year = 2023`**: Selects the necessary columns from the performance table, filtering for the year 2023.
3.  **`ROW_NUMBER() OVER(PARTITION BY DepartmentID ORDER BY SalesAmount DESC) AS DeptSalesRank`**: This is the core ranking logic.
    *   `PARTITION BY DepartmentID`: The ranking is performed independently for each department.
    *   `ORDER BY SalesAmount DESC`: Within each department, employees are ordered by their sales amount in descending order (highest sales first).
    *   `ROW_NUMBER()`: Assigns a unique sequential number (1, 2, 3, ...) to each employee within their department based on the sales order. If there are ties in `SalesAmount`, `ROW_NUMBER` still assigns distinct ranks.
4.  **`SELECT ... FROM RankedSales WHERE DeptSalesRank <= 2`**: Selects the results from the CTE, filtering to include only those rows where the calculated rank (`DeptSalesRank`) is 1 or 2, effectively giving the top 2 performers per department based on sales.

---

## Tricky Interview Questions (Easy to Hard)

1.  **Easy:** What is the fundamental difference between `RANK()` and `DENSE_RANK()` when handling ties in the `ORDER BY` clause?
    *   *(Answer Hint: `RANK` leaves gaps after ties, `DENSE_RANK` does not)*
2.  **Easy:** Does `ROW_NUMBER()` ever assign the same number to two different rows within the same partition?
    *   *(Answer Hint: No, `ROW_NUMBER` always assigns unique sequential numbers within its partition)*
3.  **Medium:** If you want to find the "Top 3" items based on a score, but you want to include *all* items that tie for the 3rd position, which ranking function (`ROW_NUMBER`, `RANK`, `DENSE_RANK`) would be most appropriate in the `WHERE` clause (e.g., `WHERE RankResult <= 3`)?
    *   *(Answer Hint: `DENSE_RANK` or `RANK`. `ROW_NUMBER` might exclude some tied items if more than 3 rows share the top scores)*
4.  **Medium:** What does `NTILE(100) OVER (ORDER BY SalesAmount)` calculate?
    *   *(Answer Hint: Percentile rank - assigns each row to one of 100 groups)*
5.  **Medium:** Is the `PARTITION BY` clause mandatory for ranking functions? What happens if you omit it?
    *   *(Answer Hint: No, it's optional. If omitted, the entire result set is treated as a single partition)*
6.  **Medium/Hard:** If you use `ROW_NUMBER() OVER (ORDER BY NonUniqueColumn)`, are the ranks assigned to rows with the same `NonUniqueColumn` value guaranteed to be consistent between query executions?
    *   *(Answer Hint: Not guaranteed. SQL Server can break ties arbitrarily if the `ORDER BY` isn't unique. Add a unique column (like a PK) to the `ORDER BY` for deterministic results)*
7.  **Hard:** How would you assign ranks based on `SalesAmount` descending, but within each `SalesQuartile` (calculated using `NTILE(4)` based on `SalesAmount`)?
    *   *(Answer Hint: Use a CTE or subquery. First calculate the `NTILE(4)` value, then in an outer query, use `ROW_NUMBER()` or `RANK()` partitioning by the calculated NTILE value)*
8.  **Hard:** Can you use ranking functions directly in the `WHERE` clause of a query? If not, how do you filter based on the result of a ranking function?
    *   *(Answer Hint: No, window functions are evaluated after the `WHERE` clause. Use a CTE or subquery to calculate the rank, then filter in the outer query)*
9.  **Hard:** Explain how `NTILE(N)` distributes rows if the total number of rows in a partition is not evenly divisible by `N`.
    *   *(Answer Hint: The first `(remainder)` groups get one extra row. E.g., 11 rows with `NTILE(4)` results in groups of size 3, 3, 3, 2)*
10. **Hard:** You want to rank employees based on `CertificationScore` descending, but for employees with the same score, you want those with more `YearsExperience` to rank higher. How do you write the `ORDER BY` clause within the `OVER()` clause?
    *   *(Answer Hint: `ORDER BY CertificationScore DESC, YearsExperience DESC`)*