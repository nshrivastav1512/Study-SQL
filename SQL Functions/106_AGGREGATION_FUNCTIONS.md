# SQL Aggregate Functions

## Introduction

**Definition:** SQL Aggregate Functions perform a calculation on a set of rows and return a single, summary value. They are essential for summarizing data, calculating totals, averages, counts, and finding minimum or maximum values within groups of data.

**Explanation:** Aggregate functions typically operate in conjunction with the `GROUP BY` clause to calculate a summary value for each group defined by the `GROUP BY` columns. If `GROUP BY` is omitted, the aggregate function treats the entire table (or the result set filtered by the `WHERE` clause) as a single group.

## Functions Covered in this Section

This document covers the following SQL Server Aggregate Functions, demonstrated with examples using a hypothetical `HRSystem` database:

1.  `SUM()`: Calculates the total of numeric values.
2.  `AVG()`: Calculates the average of numeric values.
3.  `COUNT()`: Counts the number of rows or non-null values.
4.  `MIN()`: Returns the minimum value in a set.
5.  `MAX()`: Returns the maximum value in a set.
6.  `STRING_AGG()`: Concatenates string values from multiple rows into a single string with a specified separator.
7.  `GROUPING()`: Used with `ROLLUP`, `CUBE`, or `GROUPING SETS` to indicate whether a specified column expression in a `GROUP BY` list is aggregated (returns 1 if aggregated, 0 if not). Useful for identifying subtotal rows.
8.  `STDEV()`: Calculates the statistical standard deviation for a sample population.
9.  `GROUPING_ID()`: Computes the level of grouping. Returns an integer bitmask indicating which columns are grouped in the output row. Useful for distinguishing different grouping levels in complex `ROLLUP`, `CUBE`, or `GROUPING SETS` queries.
10. `VAR()` / `VARP()`: Calculate the statistical variance for a sample (`VAR`) or population (`VARP`).
11. `STDEVP()`: Calculates the statistical standard deviation for an entire population.
12. `COUNT_BIG()`: Similar to `COUNT()`, but returns a `bigint` data type. Useful for counting rows in very large tables (potentially exceeding the range of `int`).
13. `CHECKSUM_AGG()`: Calculates a checksum value based on the values in a group. Useful for detecting changes in data.

*(Note: The SQL script includes sample `INSERT` statements for `HR.Departments` and `HR.EMP_Details` and creates/populates `HR.EmployeeProjects` for demonstration purposes.)*

---

## Examples

### 1. SUM()

**Goal:** Calculate the total salary budget for each department.

```sql
SELECT
    d.DepartmentName,
    SUM(e.Salary) AS TotalDepartmentBudget
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName;
```

**Explanation:**
*   This query joins `EMP_Details` (`e`) and `Departments` (`d`) tables on `DepartmentID`.
*   `SUM(e.Salary)` calculates the sum of salaries for all employees within each group.
*   `GROUP BY d.DepartmentName` groups the rows by department name, so `SUM()` calculates the total salary for each unique department.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Actual output depends on the data in the tables. Based on the sample data in the SQL file:
</p>
<pre><code>
DepartmentName    TotalDepartmentBudget
----------------- ---------------------
IT                160000.00
HR                65000.00
Finance           95000.00
</code></pre>
</details>

### 2. AVG()

**Goal:** Calculate the average salary and count employees for each department.

```sql
SELECT
    d.DepartmentName,
    AVG(e.Salary) AS AverageSalary,
    COUNT(*) AS EmployeeCount
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName;
```

**Explanation:**
*   Similar to the `SUM()` example, this joins the tables and groups by department.
*   `AVG(e.Salary)` calculates the average salary within each department group.
*   `COUNT(*)` counts the total number of employees in each department group.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Actual output depends on the data in the tables. Based on the sample data:
</p>
<pre><code>
DepartmentName    AverageSalary    EmployeeCount
----------------- ---------------- -------------
IT                80000.00         2
HR                65000.00         1
Finance           95000.00         1
</code></pre>
</details>

### 3. COUNT() Variations

**Goal:** Demonstrate different uses of `COUNT()` to get total employees, employees with a phone number (assuming a `Phone` column exists), and the number of unique departments represented.

```sql
SELECT
    COUNT(*) AS TotalEmployees,              -- Counts all rows
    COUNT(Phone) AS EmployeesWithPhone,      -- Counts non-null phone numbers
    COUNT(DISTINCT DepartmentID) AS UniqueDepartments
FROM HR.EMP_Details;
```

**Explanation:**
*   `COUNT(*)`: Counts every row in the `HR.EMP_Details` table.
*   `COUNT(Phone)`: Counts rows where the `Phone` column is NOT NULL.
*   `COUNT(DISTINCT DepartmentID)`: Counts the number of unique, non-null `DepartmentID` values present in the table.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Output depends on data and the existence/population of a 'Phone' column. Assuming 4 employees as per sample data, maybe 2 have phones, and there are 3 unique departments:
</p>
<pre><code>
TotalEmployees    EmployeesWithPhone    UniqueDepartments
----------------- --------------------- -------------------
4                 2                     3
</code></pre>
</details>

### 4. MIN() and MAX()

**Goal:** Find the lowest, highest, and range of salaries within each department.

```sql
SELECT
    d.DepartmentName,
    MIN(e.Salary) AS LowestSalary,
    MAX(e.Salary) AS HighestSalary,
    MAX(e.Salary) - MIN(e.Salary) AS SalaryRange
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName;
```

**Explanation:**
*   Groups employees by department.
*   `MIN(e.Salary)` finds the minimum salary in each group.
*   `MAX(e.Salary)` finds the maximum salary in each group.
*   The difference between `MAX` and `MIN` gives the salary range for that department.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Based on sample data:
</p>
<pre><code>
DepartmentName    LowestSalary    HighestSalary    SalaryRange
----------------- --------------- ---------------- -------------
IT                75000.00        85000.00         10000.00
HR                65000.00        65000.00         0.00
Finance           95000.00        95000.00         0.00
</code></pre>
</details>

### 5. STRING_AGG()

**Goal:** Create a comma-separated list of employee names for each department.

```sql
SELECT
    d.DepartmentName,
    STRING_AGG(CONCAT(e.FirstName, ' ', e.LastName), ', ') AS EmployeeList
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName;
```

**Explanation:**
*   `CONCAT(e.FirstName, ' ', e.LastName)` creates the full name string for each employee.
*   `STRING_AGG(..., ', ')` concatenates these full names within each department group, separated by a comma and space.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Based on sample data:
</p>
<pre><code>
DepartmentName    EmployeeList
----------------- --------------------
IT                John Doe, Jane Smith
HR                Bob Johnson
Finance           Alice Brown
</code></pre>
</details>

### 6. GROUPING()

**Goal:** Show employee count and total salary per department, with a summary row for all departments using `ROLLUP`.

```sql
SELECT
    CASE
        WHEN GROUPING(d.DepartmentName) = 1 THEN 'All Departments'
        ELSE d.DepartmentName
    END AS Department,
    COUNT(*) AS EmployeeCount,
    SUM(e.Salary) AS TotalSalary
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY ROLLUP(d.DepartmentName);
```

**Explanation:**
*   `GROUP BY ROLLUP(d.DepartmentName)` groups by department name and also adds a super-aggregate (summary) row where `d.DepartmentName` is effectively NULL.
*   `GROUPING(d.DepartmentName)` returns `1` for the summary row (where `DepartmentName` is aggregated across all departments) and `0` for the individual department rows.
*   The `CASE` statement uses this `GROUPING()` result to display 'All Departments' for the summary row and the actual department name otherwise.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Based on sample data:
</p>
<pre><code>
Department        EmployeeCount    TotalSalary
----------------- ---------------- -------------
Finance           1                95000.00
HR                1                65000.00
IT                2                160000.00
All Departments   4                320000.00
</code></pre>
</details>

### 7. STDEV()

**Goal:** Calculate the average salary and standard deviation of salaries within departments having more than one employee.

```sql
SELECT
    d.DepartmentName,
    AVG(e.Salary) AS AverageSalary,
    STDEV(e.Salary) AS SalaryStandardDeviation,
    COUNT(*) AS EmployeeCount
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName
HAVING COUNT(*) > 1; -- Only show departments with more than one employee
```

**Explanation:**
*   Calculates `AVG`, `STDEV` (sample standard deviation), and `COUNT` per department.
*   `STDEV(e.Salary)` measures the dispersion or spread of salaries around the average salary for that department. A higher value indicates more variation.
*   `HAVING COUNT(*) > 1` filters the grouped results to include only those departments with more than one employee, as standard deviation is typically meaningful for groups larger than one.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Based on sample data, only the IT department has more than one employee.
</p>
<pre><code>
DepartmentName    AverageSalary    SalaryStandardDeviation    EmployeeCount
----------------- ---------------- -------------------------- -------------
IT                80000.00         7071.067811865475          2
</code></pre>
</details>

### 8. GROUPING_ID()

**Goal:** Perform multi-level grouping analysis showing counts and totals by Department and Hire Year, with subtotals.

```sql
SELECT
    CASE
        WHEN GROUPING_ID(d.DepartmentName, YEAR(e.HireDate)) = 3 THEN 'Grand Total' -- Both grouped
        WHEN GROUPING_ID(d.DepartmentName, YEAR(e.HireDate)) = 1 THEN d.DepartmentName + ' Total' -- Year grouped
        ELSE d.DepartmentName + ' - ' + CAST(YEAR(e.HireDate) AS VARCHAR) -- Neither grouped
    END AS GroupLevel,
    COUNT(*) AS EmployeeCount,
    SUM(e.Salary) AS TotalSalary
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY ROLLUP(d.DepartmentName, YEAR(e.HireDate));
```

**Explanation:**
*   `GROUP BY ROLLUP(d.DepartmentName, YEAR(e.HireDate))` creates groupings for:
    *   Each `DepartmentName` and `YEAR(HireDate)` combination.
    *   Subtotals for each `DepartmentName` (across all years).
    *   A grand total (across all departments and years).
*   `GROUPING_ID(col1, col2)` returns an integer based on which columns are being aggregated in the `ROLLUP`:
    *   `0`: Neither `col1` nor `col2` is aggregated (most detailed level).
    *   `1`: `col2` is aggregated (subtotal for `col1`).
    *   `3`: Both `col1` and `col2` are aggregated (grand total). (Binary `11`)
*   The `CASE` statement uses `GROUPING_ID` to label each row according to its aggregation level.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Based on sample data:
</p>
<pre><code>
GroupLevel           EmployeeCount    TotalSalary
-------------------- ---------------- -------------
Finance - 2021       1                95000.00
Finance Total        1                95000.00
HR - 2021            1                65000.00
HR Total             1                65000.00
IT - 2020            2                160000.00
IT Total             2                160000.00
Grand Total          4                320000.00
</code></pre>
</details>

### 9. VAR() and VARP()

**Goal:** Calculate the sample variance (`VAR`) and population variance (`VARP`) of salaries for departments with more than one employee.

```sql
SELECT
    d.DepartmentName,
    COUNT(*) AS EmployeeCount,
    AVG(e.Salary) AS AverageSalary,
    VAR(e.Salary) AS SalaryVariance,        -- Sample variance
    VARP(e.Salary) AS SalaryPopVariance     -- Population variance
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName
HAVING COUNT(*) > 1;
```

**Explanation:**
*   Variance measures how far a set of numbers is spread out from their average value.
*   `VAR()` (Sample Variance): Used when your data is a sample of a larger population. It uses `n-1` in the denominator.
*   `VARP()` (Population Variance): Used when your data represents the entire population. It uses `n` in the denominator.
*   The `HAVING` clause ensures variance is calculated only where meaningful (more than one data point).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Based on sample data (only IT dept):
</p>
<pre><code>
DepartmentName    EmployeeCount    AverageSalary    SalaryVariance    SalaryPopVariance
----------------- ---------------- ---------------- ----------------- -------------------
IT                2                80000.00         50000000          25000000
</code></pre>
</details>

### 10. STDEV() and STDEVP()

**Goal:** Calculate the sample standard deviation (`STDEV`) and population standard deviation (`STDEVP`) for departments with more than one employee.

```sql
SELECT
    d.DepartmentName,
    COUNT(*) AS EmployeeCount,
    AVG(e.Salary) AS AverageSalary,
    STDEV(e.Salary) AS SalaryStdDev,        -- Sample standard deviation
    STDEVP(e.Salary) AS SalaryPopStdDev     -- Population standard deviation
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName
HAVING COUNT(*) > 1;
```

**Explanation:**
*   Standard Deviation is the square root of the variance and provides a measure of data dispersion in the original units (e.g., currency).
*   `STDEV()` (Sample): Square root of `VAR()`. Use when data is a sample.
*   `STDEVP()` (Population): Square root of `VARP()`. Use when data is the entire population.
*   Again, `HAVING` filters for groups where the calculation is meaningful.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Based on sample data (only IT dept):
</p>
<pre><code>
DepartmentName    EmployeeCount    AverageSalary    SalaryStdDev         SalaryPopStdDev
----------------- ---------------- ---------------- -------------------- -------------------
IT                2                80000.00         7071.067811865475    5000.00
</code></pre>
</details>

### 11. COUNT_BIG()

**Goal:** Count total employees and unique departments using `COUNT_BIG`, which returns a `bigint`.

```sql
SELECT
    COUNT_BIG(*) AS TotalEmployeesBig,
    COUNT_BIG(DISTINCT DepartmentID) AS UniqueDepartmentsBig
FROM HR.EMP_Details;
```

**Explanation:**
*   Functionally identical to `COUNT()`, but returns a `bigint`. This is important only when the count might exceed the maximum value of a regular `int` (approximately 2.14 billion). For most typical tables, `COUNT()` is sufficient.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Based on sample data:
</p>
<pre><code>
TotalEmployeesBig    UniqueDepartmentsBig
-------------------- ----------------------
4                    3
</code></pre>
</details>

### 12. CHECKSUM_AGG()

**Goal:** Calculate an aggregate checksum based on employee salaries within each department.

```sql
SELECT
    d.DepartmentName,
    COUNT(*) AS EmployeeCount,
    CHECKSUM_AGG(CAST(e.Salary AS INT)) AS SalaryChecksum
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName;
```

**Explanation:**
*   `CHECKSUM_AGG()` computes a checksum value for a group. The order of rows does not affect the result.
*   It requires an integer input, hence `CAST(e.Salary AS INT)`.
*   This function is primarily used to detect if data within a group has changed between two points in time. If the checksum changes, the underlying data has likely changed. It's not guaranteed to detect all changes (checksum collisions are possible but rare).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Checksum values depend heavily on the exact input values. This is just illustrative.
</p>
<pre><code>
DepartmentName    EmployeeCount    SalaryChecksum
----------------- ---------------- ----------------
IT                2                [Some Integer Value]
HR                1                [Some Integer Value]
Finance           1                [Some Integer Value]
</code></pre>
</details>

### 13. Complex Grouping with GROUPING_ID

**Goal:** Analyze project costs grouped by Department, Project Start Year, and Quarter, using `GROUPING_ID` for detailed labeling. (Requires the `HR.EmployeeProjects` table created in the SQL script).

```sql
SELECT
    CASE
        WHEN GROUPING_ID(d.DepartmentName, YEAR(p.StartDate), DATEPART(QUARTER, p.StartDate)) = 7 -- All 3 grouped (1+2+4)
            THEN 'All Projects'
        WHEN GROUPING_ID(d.DepartmentName, YEAR(p.StartDate), DATEPART(QUARTER, p.StartDate)) = 3 -- Year & Quarter grouped (1+2)
            THEN d.DepartmentName + ' Total'
        WHEN GROUPING_ID(d.DepartmentName, YEAR(p.StartDate), DATEPART(QUARTER, p.StartDate)) = 1 -- Quarter grouped (1)
            THEN d.DepartmentName + ' - ' + CAST(YEAR(p.StartDate) AS VARCHAR) + ' Total'
        ELSE d.DepartmentName + ' - ' + CAST(YEAR(p.StartDate) AS VARCHAR) + ' Q' + -- None grouped (0)
             CAST(DATEPART(QUARTER, p.StartDate) AS VARCHAR)
    END AS GroupLevel,
    COUNT(*) AS ProjectCount,
    SUM(p.ProjectCost) AS TotalCost
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
JOIN HR.EmployeeProjects p ON e.EmployeeID = p.EmployeeID
GROUP BY ROLLUP(
    d.DepartmentName,
    YEAR(p.StartDate),
    DATEPART(QUARTER, p.StartDate)
);
```

**Explanation:**
*   This query joins employee details, departments, and projects.
*   `GROUP BY ROLLUP` creates hierarchical groupings by Department, then Year, then Quarter.
*   `GROUPING_ID` with three arguments generates a bitmask:
    *   Bit 0 (value 1): Set if Quarter is aggregated.
    *   Bit 1 (value 2): Set if Year is aggregated.
    *   Bit 2 (value 4): Set if DepartmentName is aggregated.
*   The `CASE` statement interprets the `GROUPING_ID` value to provide meaningful labels for each level of aggregation (e.g., specific quarter, yearly total, department total, grand total).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>
Note: Output depends heavily on the sample data inserted into `HR.EmployeeProjects`. The structure will show rows for each Dept/Year/Quarter, then subtotals for Dept/Year, then Dept, then a grand total.
</p>
<pre><code>
GroupLevel              ProjectCount    TotalCost
----------------------- --------------- -----------
IT - 2023 Q1            1               50000.00
IT - 2023 Q1 Total      1               50000.00
IT - 2023 Q2            1               75000.00
IT - 2023 Q2 Total      1               75000.00
IT - 2023 Total         2               125000.00
IT Total                2               125000.00
HR - 2023 Q2            1               45000.00
HR - 2023 Q2 Total      1               45000.00
HR - 2023 Total         1               45000.00
HR Total                1               45000.00
All Projects            3               170000.00
</code></pre>
</details>

---

## Interview Question

**Question:** Write a SQL query to find the list of departments where the average employee salary is greater than $70,000. For these departments, display the department name, the number of employees, and the average salary.

### Solution Script

```sql
SELECT
    d.DepartmentName,
    COUNT(e.EmployeeID) AS NumberOfEmployees,
    AVG(e.Salary) AS AverageSalary
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName
HAVING AVG(e.Salary) > 70000;
```

### Explanation

1.  **`SELECT d.DepartmentName, COUNT(e.EmployeeID), AVG(e.Salary)`**: Specifies the columns to be returned: the name of the department, the count of employees in that department, and the calculated average salary for that department.
2.  **`FROM HR.EMP_Details e JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID`**: Joins the employee details table (`e`) with the departments table (`d`) based on the common `DepartmentID` column to link employees to their respective departments.
3.  **`GROUP BY d.DepartmentName`**: Groups the rows based on the department name. This ensures that the aggregate functions (`COUNT` and `AVG`) operate on all employees within each unique department.
4.  **`HAVING AVG(e.Salary) > 70000`**: Filters the results *after* the grouping and aggregation have occurred. It keeps only those groups (departments) where the calculated average salary is greater than $70,000. The `HAVING` clause is used to filter based on the result of an aggregate function, whereas `WHERE` filters rows *before* aggregation.

---

## Tricky Interview Questions (Easy to Hard)

1.  **Easy:** What is the difference between `COUNT(*)` and `COUNT(ColumnName)`? When would `COUNT(ColumnName)` return a different result from `COUNT(*)`?
    *   *(Answer Hint: NULL values)*
2.  **Easy:** Can you use an aggregate function in a `WHERE` clause? Why or why not? What clause should you use instead?
    *   *(Answer Hint: Order of operations, `HAVING` clause)*
3.  **Medium:** Explain the purpose of `GROUPING(ColumnName)` when used with `ROLLUP`. What does a return value of `1` signify?
    *   *(Answer Hint: Identifying super-aggregate/summary rows)*
4.  **Medium:** What is the practical difference between `STDEV()` and `STDEVP()`? When should you choose one over the other?
    *   *(Answer Hint: Sample vs. Population)*
5.  **Medium:** If you use `STRING_AGG()`, what happens to NULL values in the column being aggregated? How can you handle them if you want to include a placeholder?
    *   *(Answer Hint: NULLs are ignored by default, use `ISNULL` or `COALESCE` inside `STRING_AGG`)*
6.  **Medium/Hard:** Describe a scenario where `COUNT_BIG()` would be necessary instead of `COUNT()`.
    *   *(Answer Hint: Extremely large tables exceeding `int` limit)*
7.  **Hard:** Explain how `GROUPING_ID(ColA, ColB, ColC)` calculates its return value when used with `CUBE` or `ROLLUP`. How can you decode this value to understand the aggregation level?
    *   *(Answer Hint: Bitmask based on aggregation status of columns in right-to-left order)*
8.  **Hard:** Can `CHECKSUM_AGG()` guarantee detection of data changes within a group? Explain its limitations.
    *   *(Answer Hint: Checksum collisions are possible, though rare)*
9.  **Hard:** How does the presence of NULL values affect the results of `AVG()`, `SUM()`, `MIN()`, and `MAX()`?
    *   *(Answer Hint: Generally ignored, except `COUNT(*)`)*
10. **Hard:** Consider a query using `ROLLUP(A, B)` that produces rows for (A1, B1), (A1, NULL), (NULL, NULL). How would the `GROUPING(A)`, `GROUPING(B)`, and `GROUPING_ID(A, B)` values differ for each of these output rows?
    *   *(Answer Hint: Apply the definitions of `GROUPING` and `GROUPING_ID` to each row type)*