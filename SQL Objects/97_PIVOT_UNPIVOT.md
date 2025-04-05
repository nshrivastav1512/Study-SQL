# SQL Deep Dive: `PIVOT` and `UNPIVOT` Operators

## 1. Introduction: What are `PIVOT` and `UNPIVOT`?

`PIVOT` and `UNPIVOT` are relational operators in SQL Server used to transform table data, changing the orientation between rows and columns. They are particularly useful for reporting and data analysis tasks where you need to reshape data.

*   **`PIVOT`:** Rotates a table-valued expression by turning unique values from one column (the *spreading column*) into multiple columns in the output. It typically involves aggregating values from another column (the *aggregation column*) for the new column headers created from the spreading column values. Think of it as transforming rows into columns.
*   **`UNPIVOT`:** Performs the opposite operation of `PIVOT`. It rotates columns from the input table expression into row values. It essentially transforms columns back into rows.

**Why use `PIVOT`/`UNPIVOT`?**

*   **Reporting:** Create cross-tabulation reports or summaries where categories become column headers (e.g., sales per quarter shown as columns Q1, Q2, Q3, Q4).
*   **Data Reshaping:** Transform data stored in a normalized (row-oriented) format into a denormalized (column-oriented) format for specific analysis or presentation needs, and vice-versa.
*   **Analysis:** Facilitate comparisons across different categories by placing them side-by-side as columns.

**Basic Syntax:**

```sql
-- PIVOT Syntax
SELECT <non-pivoted column>, [pivot_value1], [pivot_value2], ...
FROM (
    -- Source query selecting grouping columns,
    -- the spreading column, and the aggregation column
    SELECT <grouping_column>, <spreading_column>, <aggregation_column>
    FROM SourceTable
) AS SourceQueryAlias
PIVOT (
    AggregationFunction(<aggregation_column>) -- e.g., SUM(), AVG(), COUNT()
    FOR <spreading_column> IN ([pivot_value1], [pivot_value2], ...) -- Values from spreading column become new column headers
) AS PivotTableAlias;

-- UNPIVOT Syntax
SELECT <grouping_column(s)>, <new_value_column_name>, <new_category_column_name>
FROM SourcePivotTable
UNPIVOT (
    <new_value_column_name> -- Name for the column that will hold the values from the original pivoted columns
    FOR <new_category_column_name> IN ([original_col1], [original_col2], ...) -- List of original pivoted columns whose values will be unpivoted
) AS UnpivotTableAlias;
```

## 2. `PIVOT`/`UNPIVOT` in Action: Analysis of `97_PIVOT_UNPIVOT.sql`

This script demonstrates various uses of `PIVOT` and `UNPIVOT`.

**Part 1: Basic `PIVOT` Operations**

*   **1. Employee Count by Department and Year:**
    ```sql
    SELECT * FROM (
        SELECT DepartmentName, YEAR(HireDate) AS HireYear, EmployeeID
        FROM HR.Employees e JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    ) AS SourceData
    PIVOT (
        COUNT(EmployeeID) -- Aggregate function
        FOR HireYear IN ([2020], [2021], [2022], [2023]) -- Spreading column values become new columns
    ) AS PivotTable;
    ```
    *   **Explanation:** Takes employee data, extracts `DepartmentName`, `HireYear`, and `EmployeeID`. It then pivots this data: `DepartmentName` remains a row identifier, `HireYear` values (`[2020]`, `[2021]`, etc.) become column headers, and the values in these columns are the `COUNT(EmployeeID)` for that department and year combination.
*   **2. Average Salary by Department and Quarter:**
    ```sql
    SELECT * FROM (
        SELECT DepartmentName, 'Q' + CAST(DATEPART(QUARTER, HireDate) AS VARCHAR) AS Quarter, Salary
        FROM HR.Employees e JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    ) AS SourceData
    PIVOT (
        AVG(Salary) -- Aggregate function
        FOR Quarter IN ([Q1], [Q2], [Q3], [Q4]) -- Spreading column values
    ) AS PivotTable;
    ```
    *   **Explanation:** Similar structure, but calculates the `AVG(Salary)` for each department, pivoted by the hiring `Quarter`.

**Part 2: Advanced `PIVOT` Scenarios**

*   **1. Dynamic `PIVOT`:**
    *   **Problem:** The basic `PIVOT` requires hardcoding the spreading column values (`IN ([2020], [2021], ...)`). What if the years change?
    *   **Solution:** Uses dynamic SQL.
        1.  Queries the distinct `HireYear` values from the source data.
        2.  Uses `STRING_AGG` (SQL Server 2017+) to build a comma-separated list of these years, properly quoted (e.g., `[2020],[2021],[2022],[2023]`).
        3.  Constructs the entire `PIVOT` query as a string (`@SQL`), injecting the dynamic column list (`@Columns`) into the `IN (...)` clause.
        4.  Executes the dynamically built query using `sp_executesql`.
    *   **Benefit:** Creates a flexible pivot table that adapts to the actual years present in the data.
*   **2. Multiple Aggregations (Workaround):**
    *   **Problem:** The standard `PIVOT` operator directly supports only *one* aggregate function.
    *   **Workaround Shown:** The script first calculates *both* aggregates (`COUNT(*)`, `AVG(Salary)`) grouped by the necessary columns (`DepartmentName`, `HireYear`) in a Common Table Expression (CTE) or subquery (`EmployeeStats`). Then, it applies `PIVOT` to *one* of the aggregates (`SUM(EmpCount)` - using SUM here because the CTE already calculated the COUNT per group). To get the average salary pivoted, you would need a *separate* `PIVOT` operation on the same CTE, aggregating `AVG(AvgSalary)`. You would then typically join the results of the two pivot operations if needed in one result set.

**Part 3: `UNPIVOT` Operations**

*   **1. Basic `UNPIVOT`:**
    ```sql
    -- Source table (#EmployeeQuarterlyRatings) has EmployeeID, Q1_Rating, Q2_Rating, ...
    SELECT EmployeeID, Quarter, Rating
    FROM #EmployeeQuarterlyRatings
    UNPIVOT (
        Rating -- Name for the column holding the values (4.5, 4.2, etc.)
        FOR Quarter IN (Q1_Rating, Q2_Rating, Q3_Rating, Q4_Rating) -- List of columns to unpivot
    ) AS UnpivotedRatings;
    ```
    *   **Explanation:** Takes the wide format table (`#EmployeeQuarterlyRatings`) and transforms the quarterly rating columns (`Q1_Rating`, `Q2_Rating`, etc.) into rows. The output has `EmployeeID`, a `Quarter` column (containing the *names* of the original columns like 'Q1_Rating'), and a `Rating` column (containing the corresponding values).
*   **2. Dynamic `UNPIVOT`:**
    *   Similar to dynamic `PIVOT`, this uses dynamic SQL to handle cases where the columns to be unpivoted aren't known beforehand.
    *   It queries `sys.columns` to get the relevant column names (`LIKE '%Rating'`), uses `STRING_AGG` to create the list for the `IN (...)` clause, builds the `UNPIVOT` query string, and executes it.

**Part 4: Practical HR Scenarios**

*   **1. Skills Matrix Analysis:** Creates a temporary table (`#EmployeeSkills`) with skills as columns. Uses `UNPIVOT` (within a `CROSS APPLY` for joining back to employee names) to transform this into a normalized format (EmployeeName, Skill, Rating), making it easier to query or report on individual skill ratings.
*   **2. Salary Distribution Analysis:** Uses `PIVOT` to show the average salary distribution across different experience levels (Junior, Mid, Senior - derived using `CASE`) for each department.

**Part 5: Advanced Techniques**

*   **1. Combining `PIVOT` with Window Functions:** Calculates `AvgDeptSalary` using a window function (`AVG(...) OVER (PARTITION BY ...)`), then pivots the individual salaries by `HireYear`. The `AvgDeptSalary` remains as a separate column in the pivoted output.
*   **2. Conditional Pivoting:** Uses a `CASE` expression in the source query to categorize salaries into bands ('Entry', 'Mid', 'Senior'), then pivots the `COUNT(EmployeeID)` based on these dynamically created `SalaryBand` categories.

**Part 6: Best Practices and Tips**

*   Highlights performance considerations (pre-aggregation, indexing).
*   Warns about sanitizing inputs for dynamic SQL.
*   Suggests using views for common pivot/unpivot operations.
*   Mentions alternatives like `CASE` statements for simpler scenarios.

## 3. Targeted Interview Questions (Based on `97_PIVOT_UNPIVOT.sql`)

**Question 1:** In the first basic PIVOT example (Employee Count by Department and Year), what do the values `[2020]`, `[2021]`, `[2022]`, `[2023]` in the `IN (...)` clause represent, and where do they come from?

**Solution 1:**
*   **Representation:** They represent the desired **column headers** in the final pivoted output table.
*   **Origin:** They are the specific, distinct values found in the `HireYear` column (which was derived using `YEAR(HireDate)`) of the `SourceData` subquery. The `PIVOT` operator transforms these specific values into columns.

**Question 2:** Explain the purpose of the `UNPIVOT` operation shown in section 3.1. What does the source data look like, and what does the result look like?

**Solution 2:**
*   **Purpose:** The `UNPIVOT` operation transforms data from a "wide" format (where different time periods or categories are represented by separate columns) into a "long" or normalized format (where categories and values are represented in separate rows).
*   **Source Data (`#EmployeeQuarterlyRatings`):** Looks like `EmployeeID | Q1_Rating | Q2_Rating | Q3_Rating | Q4_Rating`. Each row represents one employee, with their ratings for each quarter in separate columns.
*   **Result Data:** Looks like `EmployeeID | Quarter | Rating`. Each row represents a single rating for a specific employee in a specific quarter. For example, Employee 1 would have four rows in the output, one for each quarter's rating. The `Quarter` column would contain the original column names ('Q1_Rating', 'Q2_Rating', etc.).

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which operator transforms rows into columns: `PIVOT` or `UNPIVOT`?
    *   **Answer:** `PIVOT`.
2.  **[Easy]** What part of the `PIVOT` syntax specifies the values that will become the new column headers?
    *   **Answer:** The `IN (...)` clause within the `FOR` clause.
3.  **[Medium]** What happens in a `PIVOT` operation if the source data contains `NULL` values in the column being aggregated (e.g., `AVG(Salary)` where some salaries are `NULL`)?
    *   **Answer:** Aggregate functions like `AVG`, `SUM`, `COUNT(column_name)` generally **ignore `NULL` values** in their calculations. `COUNT(*)` is the exception, counting all rows regardless of `NULL`s. So, `AVG(Salary)` would calculate the average based only on non-NULL salaries within each pivot group.
4.  **[Medium]** What happens in an `UNPIVOT` operation if one of the source columns listed in the `IN (...)` clause contains a `NULL` value?
    *   **Answer:** By default, `UNPIVOT` **does not produce a row** in the output for source columns that contain `NULL` values. If you need to include rows for `NULL` values, you might need to replace `NULL`s with a placeholder value in the source query before the `UNPIVOT` or use alternative methods like `CROSS APPLY` with `VALUES`.
5.  **[Medium]** Can you use `PIVOT` without an aggregate function?
    *   **Answer:** No. The `PIVOT` operator requires an aggregate function (like `SUM`, `COUNT`, `AVG`, `MIN`, `MAX`) to determine the value that goes into the cell at the intersection of the row identifier and the new pivot column. Even if you expect only one value per intersection, you still need to use an aggregate (e.g., `MAX()` or `MIN()`) to satisfy the syntax.
6.  **[Medium]** Why is dynamic SQL often necessary for `PIVOT` operations in real-world scenarios?
    *   **Answer:** Because the standard `PIVOT` syntax requires the values that will become column headers (the spreading column values) to be explicitly listed in the `IN (...)` clause. In many real-world scenarios, these values (e.g., dates, product categories, years) are not fixed and can change over time. Dynamic SQL allows you to query the distinct values from the data first, construct the `IN (...)` list dynamically, and then build and execute the `PIVOT` query string, making the pivot operation adapt to the current data.
7.  **[Hard]** Can you directly `PIVOT` on multiple aggregation columns simultaneously (e.g., get `SUM(Sales)` and `COUNT(Orders)` for each year as columns)?
    *   **Answer:** No, the standard `PIVOT` operator syntax only allows specifying **one** aggregate function and **one** aggregation column. To achieve multiple aggregations pivoted by the same spreading column, you typically need to:
        1.  Calculate all aggregates in a subquery or CTE, grouped by the row identifier and spreading columns.
        2.  Perform separate `PIVOT` operations on the CTE results for each aggregate.
        3.  Join the results of the multiple pivot operations back together based on the row identifier column(s).
8.  **[Hard]** What is a common alternative set-based approach to achieve the same result as `PIVOT` without using the `PIVOT` operator itself?
    *   **Answer:** Using conditional aggregation with `CASE` statements. You group by the non-pivoted columns and then use an aggregate function (like `SUM`, `MAX`, `AVG`) combined with a `CASE` expression for each desired pivot column.
        ```sql
        SELECT
            GroupingColumn,
            SUM(CASE WHEN SpreadingColumn = 'Value1' THEN AggregationColumn ELSE 0 END) AS Value1,
            SUM(CASE WHEN SpreadingColumn = 'Value2' THEN AggregationColumn ELSE 0 END) AS Value2
            -- ... more CASE statements for other values
        FROM SourceTable
        GROUP BY GroupingColumn;
        ```
9.  **[Hard]** How does `UNPIVOT` handle different data types in the source columns being unpivoted (e.g., unpivoting an `INT` column and a `DECIMAL` column into the same target value column)?
    *   **Answer:** All source columns listed in the `IN (...)` clause of `UNPIVOT` must have **compatible data types** that can be implicitly converted to the data type defined (or inferred) for the target value column (`<new_value_column_name>`). If the data types are incompatible (e.g., trying to unpivot a string and an integer into an integer column), the `UNPIVOT` operation will fail. You might need to explicitly `CAST` or `CONVERT` the source columns to a common compatible type (like `SQL_VARIANT` or a character type) in a subquery *before* applying the `UNPIVOT`.
10. **[Hard/Tricky]** Can `PIVOT` or `UNPIVOT` be used directly on a table that uses columnstore indexes? Are there performance implications?
    *   **Answer:** Yes, `PIVOT` and `UNPIVOT` can be used on tables with columnstore indexes. However, the performance implications can vary.
        *   **PIVOT:** Since `PIVOT` often involves aggregation, it might benefit from the batch mode processing capabilities of columnstore indexes if the aggregation can be pushed down efficiently. However, the final pivoting transformation itself might still require significant processing.
        *   **UNPIVOT:** `UNPIVOT` fundamentally transforms column data into rows. This operation might not leverage columnstore optimizations as effectively as typical analytical queries that scan and aggregate columns, as it involves reading multiple column values to produce individual rows. Performance will depend heavily on the specific query, the number of columns being unpivoted, and the overall data volume. It might be less efficient on a columnstore index compared to a traditional rowstore for this specific operation.
