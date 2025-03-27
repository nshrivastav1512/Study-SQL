# SQL Deep Dive: Advanced Query Patterns

## 1. Introduction: Solving Complex Problems

Beyond basic filtering, joining, and aggregation, real-world data analysis often requires more sophisticated query patterns. These patterns combine various SQL features like window functions, CTEs, conditional logic, and specialized functions to solve complex problems such as pagination, handling data gaps, advanced ranking, hierarchical queries, and working with semi-structured data.

## 2. Advanced Patterns in Action: Analysis of `37_select_advanced_patterns.sql`

This script demonstrates a collection of useful advanced query patterns.

**a) Paging with `OFFSET`-`FETCH`**

```sql
DECLARE @PageNumber INT = 2, @RowsPerPage INT = 10;
SELECT ... FROM HR.EMP_Details
ORDER BY LastName, FirstName -- ORDER BY is required
OFFSET (@PageNumber - 1) * @RowsPerPage ROWS
FETCH NEXT @RowsPerPage ROWS ONLY;
```

*   **Pattern:** Efficiently retrieve a specific "page" of data from a larger result set.
*   **Mechanism:** `ORDER BY` ensures consistent ordering. `OFFSET` skips the rows belonging to previous pages. `FETCH NEXT` limits the result to the number of rows per page. This is the standard SQL approach since SQL Server 2012.

**b) Handling Gaps and Islands**

```sql
WITH NumberedDates AS (
    SELECT ..., DATEADD(DAY, -ROW_NUMBER() OVER(PARTITION BY EmployeeID ORDER BY AttendanceDate), AttendanceDate) AS GroupingDate
    FROM HR.Attendance
), GroupedDates AS (
    SELECT EmployeeID, GroupingDate, MIN(AttendanceDate) AS StartDate, MAX(AttendanceDate) AS EndDate, ...
    FROM NumberedDates GROUP BY EmployeeID, GroupingDate
)
SELECT ... FROM GroupedDates WHERE ConsecutiveDays > 5;
```

*   **Pattern:** Identify consecutive sequences (islands) of data (e.g., attendance days, active periods) separated by missing data (gaps).
*   **Mechanism:** Uses `ROW_NUMBER()` partitioned by the entity (EmployeeID) and ordered by the sequence column (AttendanceDate). Subtracting the row number from the date creates a constant `GroupingDate` for consecutive dates within each partition. Grouping by this `GroupingDate` allows finding the start and end of each consecutive sequence (island).

**c) Cumulative Distribution and Percentiles**

```sql
SELECT ...,
    PERCENT_RANK() OVER(ORDER BY Salary) AS PercentRank, -- Relative rank (0-1)
    CUME_DIST() OVER(ORDER BY Salary) AS CumulativeDistribution, -- % of rows <= current
    NTILE(4) OVER(ORDER BY Salary) AS Quartile -- Bucket number (1-4)
FROM HR.EMP_Details;
```

*   **Pattern:** Analyze the distribution of values within a dataset.
*   **Mechanism:** Uses window functions:
    *   `PERCENT_RANK()`: Calculates the relative rank of a row: `(rank - 1) / (total rows - 1)`.
    *   `CUME_DIST()`: Calculates the cumulative distribution: `(number of rows <= current row) / (total rows)`.
    *   `NTILE(N)`: Divides rows into N ordered groups (quantiles).

**d) Conditional Aggregation with `PIVOT`**

```sql
SELECT JobTitle, [1] AS HR_Dept, [2] AS IT_Dept, ...
FROM (SELECT JobTitle, DepartmentID, Salary FROM HR.EMP_Details) AS SourceData
PIVOT (SUM(Salary) FOR DepartmentID IN ([1], [2], [3], [4])) AS PivotTable;
```

*   **Pattern:** Transform row-based data into a cross-tabulation (matrix) format, aggregating values in the process.
*   **Mechanism:** Uses the `PIVOT` operator. Requires a source query, an aggregate function (`SUM`), the column whose values become new column headers (`FOR DepartmentID`), and the specific values to pivot into columns (`IN ([1], [2], ...)`).

**e) Dynamic Search with `CASE` in `WHERE`**

```sql
WHERE CASE WHEN @SearchType = 'Name' THEN (...) WHEN @SearchType = 'Dept' THEN (...) ELSE 1 END = 1;
```

*   **Pattern:** Create a single query that can filter based on different criteria depending on an input parameter (`@SearchType`).
*   **Mechanism:** Uses a `CASE` expression within the `WHERE` clause. The `CASE` evaluates different conditions based on `@SearchType` and should return a value that makes the final comparison (`= 1`) true only when the relevant condition is met. Can sometimes impact performance compared to dynamic SQL or separate queries due to plan caching challenges.

**f) Unpivoting Data (`UNPIVOT`)**

```sql
SELECT JobTitle, DepartmentName, SalaryTotal
FROM (...) AS SourceTable
UNPIVOT (SalaryTotal FOR DepartmentName IN (HR_Dept, IT_Dept, ...)) AS UnpivotTable;
```

*   **Pattern:** Transform column-based data (e.g., sales per month stored in separate columns) back into a normalized, row-based format.
*   **Mechanism:** Uses the `UNPIVOT` operator. Specifies the value column name (`SalaryTotal`), the category column name (`DepartmentName`), and the list of source columns (`IN (HR_Dept, ...)` ) to be unpivoted.

**g) Handling Hierarchical Data (Recursive CTE)**

```sql
WITH OrgHierarchy AS (
    SELECT ..., 0 AS Level, CAST(...) AS Path FROM ... WHERE ManagerID IS NULL -- Anchor
    UNION ALL
    SELECT ..., oh.Level + 1, CAST(...) FROM ... JOIN OrgHierarchy oh ON ... -- Recursive
) SELECT ... FROM OrgHierarchy ORDER BY Path;
```

*   **Pattern:** Querying data with parent-child relationships (org charts, bill of materials).
*   **Mechanism:** Uses a recursive CTE with an anchor member (starting point) and a recursive member (joining back to the CTE) combined with `UNION ALL`. Often includes tracking the level/depth and constructing a path for sorting or display.

**h) Calculating Moving Averages/Totals**

```sql
SELECT ...,
    AVG(Value) OVER(ORDER BY Date ROWS BETWEEN N PRECEDING AND CURRENT ROW) AS MovingAvg,
    SUM(Value) OVER(ORDER BY Date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotal
FROM ...;
```

*   **Pattern:** Calculate averages or sums over a sliding or cumulative window of rows, typically ordered by date or sequence.
*   **Mechanism:** Uses aggregate window functions (`AVG`, `SUM`) with an `ORDER BY` clause and an explicit window frame (`ROWS BETWEEN ...`) to define the range of rows included in each calculation relative to the current row.

**i) Finding Median Values**

```sql
WITH SalaryRanks AS (
    SELECT ..., ROW_NUMBER() OVER(...) AS RowAsc, ROW_NUMBER() OVER(...) AS RowDesc FROM ...
)
SELECT ..., AVG(Salary) AS MedianSalary FROM SalaryRanks WHERE ABS(RowAsc - RowDesc) <= 1 GROUP BY ...;
```

*   **Pattern:** Calculate the true median (middle value) within groups.
*   **Mechanism:** Uses `ROW_NUMBER()` twice (once ascending, once descending) within partitions. The median row(s) will have `RowAsc` and `RowDesc` values that are very close (difference <= 1). Averaging the values for these middle rows handles both odd and even numbers of rows correctly. *Note: SQL Server 2022+ introduces `PERCENTILE_CONT(0.5)` and `PERCENTILE_DISC(0.5)` which provide simpler ways to calculate median.*

**j) Custom Sorting (`CASE` in `ORDER BY`)**

```sql
ORDER BY CASE WHEN Condition1 THEN 0 WHEN Condition2 THEN 1 ELSE 2 END, SecondaryColumn;
```

*   **Pattern:** Implement complex or business-specific sorting logic that doesn't follow simple ascending/descending order on columns.
*   **Mechanism:** Uses a `CASE` expression within the `ORDER BY` clause to assign a sort key based on conditions. Rows are then sorted by this calculated key, with secondary sort columns used as tie-breakers.

**k) Handling Slowly Changing Dimensions (SCD Type 2 Example)**

```sql
SELECT ..., sh.EffectiveDate, sh.EndDate, CASE WHEN sh.EndDate IS NULL THEN 'Current' ELSE 'Historical' END
FROM HR.EMP_Details e JOIN HR.SalaryHistory sh ON e.EmployeeID = sh.EmployeeID WHERE ... ORDER BY sh.EffectiveDate;
```

*   **Pattern:** Querying tables designed to track historical changes to dimension attributes (like employee salary or department over time). Type 2 SCD typically involves start/end dates (or status flags) for each version of a record.
*   **Mechanism:** Join the current dimension table (`EMP_Details`) with the history table (`SalaryHistory`) and use the date columns (`EffectiveDate`, `EndDate`) to select specific versions or view the entire history, often identifying the current record where `EndDate` is `NULL` or a future date.

**l/m) Querying XML/JSON Data**

```sql
-- XML
WHERE SkillsXML.exist('/Skills/Skill[contains(., "SQL")]') = 1;
SELECT ..., SkillsXML.value('(/Skills/Skill)[1]', 'VARCHAR(50)') AS PrimarySkill, ...;
-- JSON
WHERE ISJSON(SkillsJSON) = 1 AND JSON_VALUE(SkillsJSON, '$.YearsExperience') > 5;
SELECT ..., JSON_VALUE(SkillsJSON, '$.PrimarySkill') AS PrimarySkill, ...;
```

*   **Pattern:** Extracting and filtering data stored within semi-structured `XML` or `JSON` columns.
*   **Mechanism:** Uses built-in functions and methods:
    *   XML: XQuery methods like `.value()`, `.query()`, `.exist()`.
    *   JSON: Functions like `ISJSON()`, `JSON_VALUE()`, `JSON_QUERY()`, `OPENJSON()`. These allow navigating the structure and extracting/filtering based on specific elements or properties.

**n) Handling Missing Values (`COALESCE`, `ISNULL`, `NULLIF`)**

```sql
SELECT ..., COALESCE(MiddleName, '') AS MiddleName, ISNULL(Phone, 'No Phone') AS Phone, ...;
```

*   **Pattern:** Providing default or alternative values when data might be `NULL`.
*   **Mechanism:**
    *   `COALESCE(val1, val2, ...)`: Returns the first non-NULL expression in the list. Standard SQL.
    *   `ISNULL(check_expression, replacement_value)`: Returns `replacement_value` if `check_expression` is `NULL`, otherwise returns `check_expression`. SQL Server specific.
    *   `NULLIF(expr1, expr2)`: Returns `NULL` if `expr1` equals `expr2`, otherwise returns `expr1`. Useful for preventing division-by-zero or handling specific sentinel values.

**o) Calculating Business Days**

```sql
WITH DateSequence AS (...), BusinessDays AS (SELECT ... FROM DateSequence WHERE ... NOT IN (Weekends, Holidays))
SELECT ..., (SELECT COUNT(*) FROM BusinessDays WHERE CalendarDate BETWEEN e.HireDate AND GETDATE()) AS BizDays
FROM HR.EMP_Details e;
```

*   **Pattern:** Calculating the number of working days between two dates, excluding weekends and specified holidays.
*   **Mechanism:** Often involves generating a sequence of dates (using a recursive CTE or a numbers/tally table), filtering out weekends (`DATEPART(WEEKDAY, ...)`) and known holidays (joining to a holiday table or using `NOT IN`), and then counting the remaining rows within the desired date range.

## 3. Targeted Interview Questions (Based on `37_select_advanced_patterns.sql`)

**Question 1:** What is the difference between `CROSS APPLY` and `OUTER APPLY`? When would you use `OUTER APPLY`? (Referencing example 12 from `29_select_joins.sql` which is similar to example 12 here).

**Solution 1:**

*   **Difference:** Both execute a right-side table-valued expression for each row of a left-side table. `CROSS APPLY` only returns rows where the right-side expression produces *at least one row*. `OUTER APPLY` returns *all* rows from the left-side table; if the right-side expression produces no rows for a given left-side row, columns from the right side are `NULL`.
*   **When to use `OUTER APPLY`:** Use `OUTER APPLY` when you need to include all rows from the left-side table, even if the function or correlated subquery on the right side doesn't produce any results for some of those left-side rows (analogous to a `LEFT OUTER JOIN`).

**Question 2:** Explain the "Gaps and Islands" problem and the general approach used in section 2 to identify consecutive date ranges (islands).

**Solution 2:**

*   **Problem:** The "Gaps and Islands" problem involves finding continuous sequences (islands) of data within a larger dataset that may contain missing values or periods (gaps). For example, finding consecutive days an employee was present, or consecutive months sales targets were met.
*   **Approach:** The common approach demonstrated uses window functions:
    1.  Assign a row number (`ROW_NUMBER()`) ordered by the sequence column (e.g., `AttendanceDate`) within each partition (e.g., `EmployeeID`).
    2.  Create a grouping value by subtracting the row number (converted to the appropriate interval, e.g., days) from the sequence column (`DATEADD(DAY, -ROW_NUMBER() OVER(...), AttendanceDate)`). This value will be constant for all rows within a consecutive sequence (island).
    3.  Group the results by the partition columns and the calculated `GroupingDate`.
    4.  Use aggregate functions like `MIN()`, `MAX()`, and `COUNT()` within each group to find the start date, end date, and length of each island.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which clause is required when using `OFFSET`/`FETCH` for pagination?
    *   **Answer:** `ORDER BY`.
2.  **[Easy]** Which operator transforms rows into columns: `PIVOT` or `UNPIVOT`?
    *   **Answer:** `PIVOT`.
3.  **[Medium]** What is the difference between `PERCENT_RANK()` and `CUME_DIST()`?
    *   **Answer:** `PERCENT_RANK()` calculates the relative rank as `(rank - 1) / (total rows - 1)`, resulting in values from 0 to 1. `CUME_DIST()` calculates the cumulative distribution as `(number of rows <= current row) / (total rows)`, resulting in values from `(1/total rows)` to 1.
4.  **[Medium]** In the dynamic search pattern `(Column = @Parameter OR @Parameter IS NULL)`, why is the `@Parameter IS NULL` check included?
    *   **Answer:** It's included to make the filter condition optional. If the user doesn't provide a value for `@Parameter` (i.e., it's `NULL`), the `@Parameter IS NULL` part becomes true, making the entire `OR` condition true for every row, effectively disabling that specific filter.
5.  **[Medium]** Can you use `PIVOT` if the values you want to turn into column headers are not known in advance (e.g., dynamic list of departments)? If not, how is this typically handled?
    *   **Answer:** No, the standard `PIVOT` operator requires the specific values that will become column headers to be explicitly listed in the `IN (...)` clause. To handle dynamic values, you typically need to construct the entire `PIVOT` query dynamically as a string (determining the column list first by querying the distinct values) and then execute it using `sp_executesql`.
6.  **[Medium]** What does `STRING_SPLIT` return, and why is `APPLY` often used with it?
    *   **Answer:** `STRING_SPLIT` returns a table with a single column (named `value`) containing the substrings generated by splitting the input string based on the specified delimiter. `APPLY` (usually `CROSS APPLY`) is used because `STRING_SPLIT` is a table-valued function, and `APPLY` allows you to invoke such a function for each row of an outer table, effectively joining the outer table row with the multiple rows generated by splitting the string column from that outer row.
7.  **[Hard]** When calculating a moving average using `AVG(...) OVER (ORDER BY Date ROWS BETWEEN N PRECEDING AND M FOLLOWING)`, how are the calculations handled for rows near the beginning or end of a partition where there aren't enough preceding or following rows?
    *   **Answer:** The window frame adjusts automatically. For rows near the beginning, there might be fewer than `N` preceding rows available within the partition; the average is calculated using only the available rows (from the start of the partition up to `M` rows following). Similarly, for rows near the end, there might be fewer than `M` following rows; the average uses only the available rows (from `N` rows preceding up to the end of the partition).
8.  **[Hard]** Besides `ROW_NUMBER`, what other window function could be used in a CTE for pagination? What might be a disadvantage?
    *   **Answer:** You could potentially use `RANK()` or `DENSE_RANK()`. However, if there are ties in the `ORDER BY` columns, these functions will assign the same rank to multiple rows. This could lead to inconsistent page sizes or skipping rows if not handled carefully in the outer query's `WHERE` clause filtering the rank. `ROW_NUMBER()` guarantees a unique, consecutive number, making the `WHERE RowNum BETWEEN ...` logic simpler and more reliable for standard pagination.
9.  **[Hard]** Can you filter data based on JSON properties if the JSON structure varies significantly between rows? How might `OPENJSON` help?
    *   **Answer:** Filtering with `JSON_VALUE` becomes difficult if the path to the desired property varies or doesn't always exist. `OPENJSON` can parse a JSON string into a relational format (key/value pairs or a schema defined with `WITH`). You can then use standard `WHERE` clause conditions on the resulting rows and columns generated by `OPENJSON`, which can be more flexible for handling variable structures or searching within arrays. For example, you could use `OPENJSON` with a default schema to get key/value pairs and then filter `WHERE [key] = 'DesiredProperty' AND [value] = 'SomeValue'`.
10. **[Hard/Tricky]** In the "Gaps and Islands" pattern, why does subtracting `ROW_NUMBER()` (ordered by date) from the date create a constant value for consecutive dates?
    *   **Answer:** Consider consecutive dates: D1, D2 (D1+1), D3 (D1+2). Their row numbers will be N, N+1, N+2.
        *   For D1: `D1 - N`
        *   For D2: `(D1+1) - (N+1) = D1 - N`
        *   For D3: `(D1+2) - (N+2) = D1 - N`
    *   As long as the dates are consecutive, both the date and the row number increment by the same amount (1 day, 1 row number), so their difference remains constant. When there's a gap (e.g., D4 is missing, D5 = D1+4), the date jumps, but the row number only increments by 1, breaking the constant difference: `(D1+4) - (N+3) = D1 - N + 1`. This change in the difference signals the start of a new island.
