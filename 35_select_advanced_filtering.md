# SQL Deep Dive: Advanced Filtering Techniques

## 1. Introduction: Beyond Simple Comparisons

While basic `WHERE` clause operators (`=`, `>`, `LIKE`, `IN`, `BETWEEN`, `AND`, `OR`) cover many filtering needs, SQL Server offers more advanced techniques for complex scenarios. These include handling optional parameters, searching text semantically, querying based on location or time, filtering hierarchical or semi-structured data (JSON), and applying conditional logic within aggregations.

## 2. Advanced Filtering in Action: Analysis of `35_select_advanced_filtering.sql`

This script demonstrates a variety of sophisticated filtering methods.

**a) Dynamic Search Conditions (Handling Optional Parameters)**

```sql
DECLARE @DepartmentID INT = NULL, @MinSalary DECIMAL(10,2) = 50000, @JobTitle VARCHAR(50) = NULL;
SELECT ... FROM HR.EMP_Details
WHERE (DepartmentID = @DepartmentID OR @DepartmentID IS NULL) -- Apply if @DepartmentID is not NULL
  AND (Salary >= @MinSalary OR @MinSalary IS NULL)       -- Apply if @MinSalary is not NULL
  AND (JobTitle = @JobTitle OR @JobTitle IS NULL);        -- Apply if @JobTitle is not NULL
```

*   **Explanation:** A common pattern for building dynamic search queries where parameters might be optional. The `(Column = @Parameter OR @Parameter IS NULL)` logic ensures that the condition on `Column` is only applied if the corresponding `@Parameter` has a non-NULL value. If the parameter is `NULL`, the `OR @Parameter IS NULL` part becomes true, effectively bypassing that specific filter condition. This allows a single query to handle various combinations of search criteria. *Note: While convenient, this pattern can sometimes lead to suboptimal query plans compared to building dynamic SQL or using `IF` statements, especially with many optional parameters.*

**b) Fuzzy Matching (`SOUNDEX`)**

```sql
WHERE SOUNDEX(LastName) = SOUNDEX('Smith');
```

*   **Explanation:** Finds rows where a column value *sounds like* a given string. `SOUNDEX` converts a string into a four-character code based on its English pronunciation. Comparing `SOUNDEX` codes allows finding names with slight spelling variations (e.g., Smith, Smyth). It's a basic phonetic matching algorithm. `DIFFERENCE` is another related function.

**c) Full-Text Search (`CONTAINS`)**

```sql
-- Requires Full-Text Index on DocumentContent
WHERE CONTAINS(DocumentContent, 'project AND (plan OR proposal)');
```

*   **Explanation:** Performs linguistic searches for words and phrases within text data stored in columns configured with Full-Text Indexing. `CONTAINS` is much more powerful than `LIKE` for searching natural language text. It supports:
    *   Boolean logic (`AND`, `OR`, `NOT`).
    *   Proximity searches (`NEAR`).
    *   Inflectional forms (searching for "run" finds "ran", "running").
    *   Thesaurus lookups.
    *   Ranking based on relevance.

**d) Temporal Queries (Date/Time Filtering)**

```sql
WHERE HireDate BETWEEN DATEADD(YEAR, -5, GETDATE()) AND DATEADD(YEAR, -2, GETDATE()) -- Hired 2-5 years ago
  AND DATEPART(MONTH, HireDate) IN (1, 2, 3); -- Hired in Q1
```

*   **Explanation:** Uses date functions (`DATEADD`, `GETDATE`, `DATEPART`, `DATEDIFF`, `YEAR`, `MONTH`, etc.) to filter based on specific time periods, date parts, or durations.

**e) Spatial Data Filtering (`STDistance`)**

```sql
-- Requires LocationGeo column of geography type and spatial index
WHERE Geography::Point(47.6062, -122.3321, 4326).STDistance(LocationGeo) <= 80467; -- Within 50 miles (approx)
```

*   **Explanation:** Filters based on geographic location using SQL Server's spatial data types (`geometry`, `geography`). This example uses the `geography` type and the `STDistance()` method to find locations within a certain distance (in meters, 4326 is the SRID for WGS84 standard) from a specified point (Seattle coordinates). Requires spatial indexes for good performance.

**f) JSON Data Filtering (`JSON_VALUE`, `ISJSON`)**

```sql
-- Requires AdditionalInfo column containing JSON
WHERE ISJSON(AdditionalInfo) = 1 -- Ensure valid JSON
  AND JSON_VALUE(AdditionalInfo, '$.YearsExperience') > 5 -- Filter by value in JSON path
  AND JSON_VALUE(AdditionalInfo, '$.Department.Name') = 'IT';
```

*   **Explanation:** Queries data stored within JSON formatted text columns (SQL Server 2016+).
    *   `ISJSON()`: Validates if the string contains valid JSON.
    *   `JSON_VALUE(Column, 'json_path')`: Extracts a scalar value (string, number, boolean) from the JSON using a specified path expression (e.g., `$.Skills[0]` for the first skill, `$.Department.Name` for the department name).
    *   `JSON_QUERY(Column, 'json_path')`: Extracts an object or array from the JSON.
    *   These functions can be used in `WHERE` clauses to filter rows based on the content of the JSON data.

**g) Hierarchical Data Filtering (Recursive CTE)**

```sql
WITH ManagerHierarchy AS (
    SELECT EmployeeID, ... FROM HR.EMP_Details WHERE EmployeeID = 101 -- Anchor
    UNION ALL
    SELECT e.EmployeeID, ... FROM HR.EMP_Details e JOIN ManagerHierarchy mh ON e.ManagerID = mh.EmployeeID -- Recursive
)
SELECT * FROM ManagerHierarchy WHERE Level > 0; -- Filter results from CTE
```

*   **Explanation:** Uses a recursive CTE (as explored previously) to traverse a hierarchy (like manager-subordinate). The `WHERE` clause in the *final* `SELECT` statement can then filter the results based on the hierarchy level or other data gathered during the recursion (e.g., finding all direct/indirect reports *excluding* the starting manager).

**h) Bitwise Filtering (`&`)**

```sql
-- Assumes Permissions is an INT column storing bit flags (1=Read, 2=Write, 4=Execute, 8=Admin)
WHERE (Permissions & 12) = 12; -- Check if Execute (4) AND Admin (8) bits are set (4 + 8 = 12)
-- WHERE (Permissions & 1) = 1; -- Check if Read bit is set
```

*   **Explanation:** Uses the bitwise AND operator (`&`) to check if specific bits are set within an integer column often used as a bitmask to store multiple boolean flags efficiently. `(Column & FlagValue) = FlagValue` checks if a specific flag is set. `(Column & CombinedFlags) = CombinedFlags` checks if *all* specified flags are set.

**i) Filtered Aggregates (`COUNT/SUM/AVG(CASE...)`)**

```sql
SELECT DepartmentID,
    COUNT(CASE WHEN Salary > 70000 THEN 1 END) AS HighPaidCount, -- Count only high paid
    AVG(CASE WHEN Gender = 'F' THEN Salary END) AS AvgFemaleSalary -- Avg salary only for females
FROM HR.EMP_Details
GROUP BY DepartmentID;
```

*   **Explanation:** Applies filtering logic *inside* aggregate functions using `CASE`. `COUNT(CASE WHEN condition THEN 1 END)` counts rows meeting the condition. `AVG(CASE WHEN condition THEN Value END)` averages `Value` only for rows meeting the condition (other rows contribute `NULL`, which `AVG` ignores). Allows calculating multiple conditional aggregates within a single `GROUP BY` query.

**j) String Splitting and Filtering (`STRING_SPLIT`, `CROSS APPLY`)**

```sql
-- Requires Skills column like 'SQL,Java,C#'
SELECT e.EmployeeID, ...
FROM HR.EMP_Details e
CROSS APPLY STRING_SPLIT(Skills, ',') AS s -- Split Skills into rows
WHERE s.value = 'SQL'; -- Filter employees having the 'SQL' skill
```

*   **Explanation:** Uses `STRING_SPLIT` (SQL Server 2016+) to break a delimited string (like comma-separated skills) into multiple rows, each containing one value. `CROSS APPLY` effectively joins each employee row with the rows generated by splitting their `Skills` string. The `WHERE` clause then filters based on the individual skill values (`s.value`).

**k) Parameterized `IN` Lists (using `STRING_SPLIT`)**

```sql
DECLARE @DepartmentList VARCHAR(100) = '1,3,5,7';
SELECT ... FROM HR.EMP_Details
WHERE DepartmentID IN (SELECT value FROM STRING_SPLIT(@DepartmentList, ','));
```

*   **Explanation:** A common technique to handle dynamic `IN` lists passed as a single string parameter. `STRING_SPLIT` converts the comma-separated string variable into a table of values, which can then be used directly in the `IN` clause, avoiding the need for complex dynamic SQL for this specific scenario.

**l) Filtering with `APPLY`**

```sql
SELECT d.DepartmentID, ..., e.HighestPaid
FROM HR.Departments d
CROSS APPLY ( -- Use CROSS APPLY if you only want departments where the subquery returns results
    SELECT TOP 1 FirstName + ' ' + LastName AS HighestPaid
    FROM HR.EMP_Details WHERE DepartmentID = d.DepartmentID ORDER BY Salary DESC
) e;
```

*   **Explanation:** Uses `APPLY` (here `CROSS APPLY`) to execute a correlated subquery for each row of the outer table (`Departments`). The subquery finds the highest-paid employee *for that specific department*. This allows filtering or retrieving related data based on complex row-by-row logic that might be difficult with standard joins (like `TOP N` per group).

**m) Filtering with Dynamic Pivoting**

```sql
-- Build dynamic SQL for PIVOT based on filtered source data
SET @SQL = N'SELECT JobTitle, ' + @Columns + ' FROM (...) AS SourceData PIVOT (...) ...';
EXEC sp_executesql @SQL;
```

*   **Explanation:** Combines dynamic SQL generation (to create `PIVOT` columns based on current data) with filtering. The source data query *within* the dynamic SQL can include a `WHERE` clause to filter the data *before* it gets pivoted.

**n) Temporal Table Filtering (`FOR SYSTEM_TIME AS OF`)**

```sql
-- Requires EMP_Details to be a system-versioned temporal table
SELECT ... FROM HR.EMP_Details FOR SYSTEM_TIME AS OF '2023-01-01';
```

*   **Explanation:** Queries the state of the data in a temporal table as it existed at a specific point in the past. SQL Server automatically retrieves the relevant historical data from the associated history table.

**o) Semantic Search (`semantickeyphrasetable`, `semanticsimilaritytable`)**

```sql
-- Requires Semantic Search enabled and configured
SELECT ... FROM HR.Documents d1 JOIN semanticsimilaritytable(...) ssd ON ... WHERE ...;
```

*   **Explanation:** Uses specialized functions for semantic analysis. `semanticsimilaritytable` finds documents whose content is statistically similar in meaning to a source document, going beyond simple keyword matching. Requires specific setup.

## 3. Targeted Interview Questions (Based on `35_select_advanced_filtering.sql`)

**Question 1:** Explain the purpose of the `(Column = @Parameter OR @Parameter IS NULL)` pattern used for dynamic search conditions. What is a potential performance drawback?

**Solution 1:**

*   **Purpose:** This pattern allows a single query to handle optional search parameters. If the parameter variable (`@Parameter`) is given a value, the `Column = @Parameter` part filters the results. If the parameter variable is `NULL`, the `@Parameter IS NULL` part becomes true, making the entire `OR` condition true for all rows, effectively bypassing that specific filter.
*   **Drawback:** This pattern can sometimes lead to suboptimal query execution plans. Because the plan must be generated to work whether the parameter is `NULL` or not, the optimizer might choose a less efficient plan (like an index scan instead of a seek) that works for both cases, rather than the optimal plan for when a specific value *is* provided. Using `OPTION (RECOMPILE)` or dynamic SQL might yield better performance in some complex scenarios with many optional parameters.

**Question 2:** What is the difference between using `LIKE '%keyword%'` and `CONTAINS(Column, 'keyword')` for searching text? When would you use `CONTAINS`?

**Solution 2:**

*   **`LIKE '%keyword%'`:** Performs simple string pattern matching. It finds rows where the exact sequence of characters 'keyword' appears anywhere within the column. It doesn't understand word boundaries, plurals, or meaning. It often leads to index scans (inefficient).
*   **`CONTAINS(Column, 'keyword')`:** Performs a **Full-Text Search**. It finds rows where the *word* 'keyword' (or related forms) appears. It understands word boundaries, handles noise words (like 'a', 'the'), and can search for inflectional forms (run/ran/running), synonyms (via thesaurus), and proximity. It requires a Full-Text Index on the column and is generally much more efficient and effective for searching natural language text.
*   **When to use `CONTAINS`:** Use `CONTAINS` when searching for words or phrases within large blocks of text (articles, descriptions, documents) where linguistic relevance, word forms, and performance are important. Use `LIKE` for simple pattern matching on shorter strings or when wildcards are needed at the beginning of the pattern (though this is often inefficient).

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which operator is used for phonetic matching based on how words sound?
    *   **Answer:** `SOUNDEX`.
2.  **[Easy]** Which function extracts a scalar value from a JSON string based on a path?
    *   **Answer:** `JSON_VALUE`.
3.  **[Medium]** Can you use `WHERE JSON_VALUE(JsonColumn, '$.Tags') = 'SQL'` if the `Tags` element is a JSON array (e.g., `["SQL", "Azure"]`)?
    *   **Answer:** No. `JSON_VALUE` is designed to extract *scalar* values (string, number, boolean, null). If `$.Tags` points to a JSON array or object, `JSON_VALUE` typically returns `NULL` (in default path mode). To check if an array contains a specific value, you would usually need to use `OPENJSON` to shred the array into rows or use `JSON_QUERY` combined with other checks if applicable.
4.  **[Medium]** What does the bitwise expression `(Permissions & 4) = 4` check for, assuming 4 represents 'Execute' permission?
    *   **Answer:** It checks if the 'Execute' bit (represented by the value 4, which is binary `100`) is **set** (is 1) within the `Permissions` integer column. The bitwise AND (`&`) operation isolates that specific bit.
5.  **[Medium]** When using `STRING_SPLIT` in a `CROSS APPLY`, what happens if the column being split is `NULL` or an empty string?
    *   **Answer:** `STRING_SPLIT` returns an empty table (no rows) if the input string is `NULL` or empty. In a `CROSS APPLY`, this means the outer row (from which the `NULL`/empty string came) will **not** appear in the final result set, similar to an `INNER JOIN` where no match is found. If you wanted to keep the outer row even if the split produces no results, you would use `OUTER APPLY`.
6.  **[Medium]** What is required on a table column before you can use `CONTAINS` or other full-text predicates on it?
    *   **Answer:** A **Full-Text Index** must be created on the column(s) you want to search, and the Full-Text Search feature must be installed and enabled for the SQL Server instance and database.
7.  **[Hard]** Explain the difference between `CROSS APPLY` and `OUTER APPLY`. When would you choose `OUTER APPLY`?
    *   **Answer:** Both `CROSS APPLY` and `OUTER APPLY` execute a table-valued expression (like a function call or correlated subquery) for each row of an outer table.
        *   `CROSS APPLY`: Returns rows only if the table-valued expression returns **at least one row** for the corresponding outer row. It acts like an `INNER JOIN`.
        *   `OUTER APPLY`: Returns **all rows** from the outer table. If the table-valued expression returns rows, they are joined. If it returns **no rows** for a specific outer row, columns from the table-valued expression will be `NULL` for that outer row. It acts like a `LEFT OUTER JOIN`.
        *   **Choose `OUTER APPLY` when:** You need to include all rows from the outer table, even those for which the applied function or subquery produces no results (similar to needing a `LEFT JOIN`).
8.  **[Hard]** Why might filtering on a date column using `WHERE MyDate >= @StartDate AND MyDate < DATEADD(day, 1, @EndDate)` be better for performance than `WHERE CAST(MyDate AS DATE) BETWEEN @StartDate AND @EndDate`?
    *   **Answer:** The first condition (`MyDate >= @StartDate AND MyDate < DATEADD(day, 1, @EndDate)`) is generally **SARGable**. It compares the raw `MyDate` column directly against calculated boundary values. If `MyDate` is indexed, the optimizer can use the index efficiently (seek) to find rows within that range. The second condition (`WHERE CAST(MyDate AS DATE) BETWEEN @StartDate AND @EndDate`) applies a function (`CAST`) to the `MyDate` column within the `WHERE` clause. This typically makes the predicate **non-SARGable**, forcing the optimizer to calculate `CAST(MyDate AS DATE)` for every row in the table (or index) before comparing it, preventing an efficient index seek and often resulting in a slower scan.
9.  **[Hard]** Can you use `JSON_VALUE` to filter based on the *existence* of a key within a JSON object, rather than its value? If not, what could you use?
    *   **Answer:** `JSON_VALUE` primarily extracts scalar values. While checking if `JSON_VALUE(col, '$.OptionalKey') IS NOT NULL` *might* work sometimes, it's not the most reliable way to check for key existence (especially if the key could legitimately have a `null` JSON value). A more robust approach is often to use `OPENJSON` to parse the object and then check for the existence of the key in the resulting key-value pairs, or potentially use `JSON_QUERY` to see if querying for the key returns a non-null object/array/value.
10. **[Hard/Tricky]** How could you rewrite the dynamic search condition `WHERE (DepartmentID = @DepartmentID OR @DepartmentID IS NULL)` to potentially achieve better performance using `OPTION (RECOMPILE)` or avoiding the `OR` pattern?
    *   **Answer:**
        1.  **`OPTION (RECOMPILE)`:** Add `OPTION (RECOMPILE)` to the end of the `SELECT` statement. This forces SQL Server to recompile the query plan *every time* it runs, using the *current* values of the parameters (`@DepartmentID`, etc.). This allows the optimizer to create a plan optimized for the specific parameters provided (e.g., using an index seek if `@DepartmentID` has a value, or a scan if it's `NULL`), potentially avoiding the compromise plan generated for the `OR IS NULL` pattern. The trade-off is increased compilation overhead on each execution.
        2.  **Separate `IF` Statements (in Stored Procedure):** If the query is in a stored procedure, use `IF` statements to build slightly different queries based on which parameters are provided. This generates more specific plans but increases code complexity.
            ```sql
            IF @DepartmentID IS NOT NULL AND @MinSalary IS NOT NULL BEGIN
                SELECT ... WHERE DepartmentID = @DepartmentID AND Salary >= @MinSalary;
            END ELSE IF @DepartmentID IS NOT NULL BEGIN
                SELECT ... WHERE DepartmentID = @DepartmentID;
            END ELSE IF @MinSalary IS NOT NULL BEGIN
                SELECT ... WHERE Salary >= @MinSalary;
            END ELSE BEGIN
                SELECT ... ; -- No filters
            END
            ```
        3.  **Dynamic SQL (Carefully Parameterized):** Construct the `WHERE` clause dynamically as a string, only including conditions for non-NULL parameters, and execute using `sp_executesql` with parameters. This generates optimal plans but requires careful handling to prevent SQL injection.
