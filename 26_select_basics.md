# SQL Deep Dive: `SELECT` Statement Basics

## 1. Introduction: What is `SELECT`?

The `SELECT` statement is the cornerstone of **Data Query Language (DQL)** in SQL. Its primary purpose is to **retrieve data** from one or more tables (or views, functions, etc.) in a database. It allows you to specify which columns you want, which rows you need, how the results should be ordered, and perform calculations or transformations on the data being retrieved.

**Why is `SELECT` Important?**

*   **Data Retrieval:** The fundamental way to view and extract information stored in the database.
*   **Reporting & Analysis:** Forms the basis for generating reports, performing data analysis, and feeding data into applications.
*   **Foundation for Other Operations:** The results of `SELECT` statements are often used as input for `INSERT`, `UPDATE`, `DELETE`, or `MERGE` statements.

**Basic Structure:**

```sql
SELECT column1, column2, ... -- Specify columns (or *)
FROM table_name             -- Specify the source table
[WHERE condition]            -- Filter rows (optional)
[ORDER BY column_to_sort]    -- Sort results (optional)
;
```

## 2. `SELECT` Basics in Action: Analysis of `26_select_basics.sql`

This script demonstrates the essential components of the `SELECT` statement.

**a) Basic `SELECT *`**

```sql
SELECT * FROM HR.EMP_Details;
```

*   **Explanation:** Retrieves **all columns** (`*`) and **all rows** from the specified table (`HR.EMP_Details`).
*   **Caution:** While convenient for exploration, `SELECT *` is generally discouraged in production code. It can retrieve unnecessary data, impacting performance (network traffic, memory usage), and can break if the table structure changes (e.g., columns added/removed).

**Example Visualization:**

Let's assume `HR.EMP_Details` contains the following sample data (showing relevant columns):

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+-----------+----------+--------------------+------------+--------------+--------+-----------+
    | EmployeeID | FirstName | LastName | Email              | HireDate   | DepartmentID | Salary | ManagerID |
    +------------+-----------+----------+--------------------+------------+--------------+--------+-----------+
    | 1000       | Alice     | Smith    | alice.s@corp.com   | 2022-01-15 | 2            | 60000  | 1002      |
    | 1001       | Bob       | Jones    | bob.j@corp.com     | 2021-03-10 | 2            | 75000  | 1002      |
    | 1002       | Charlie   | Brown    | charlie.b@corp.com | 2020-05-20 | 3            | 90000  | NULL      |
    | 1003       | Diana     | Green    | diana.g@corp.com   | 2023-07-01 | 2            | 55000  | 1002      |
    | 1004       | Ethan     | White    | ethan.w@corp.com   | 2022-11-30 | 1            | 62000  | 1000      |
    +------------+-----------+----------+--------------------+------------+--------------+--------+-----------+
    (Note: Other columns like CreatedDate, ModifiedDate also exist but are omitted for brevity)
    ```

*   **Output Result Set:** The query returns a result set containing *all* columns and *all* rows from the table.
    ```
    +------------+-----------+----------+--------------------+------------+--------------+--------+-----------+... (all other columns)
    | EmployeeID | FirstName | LastName | Email              | HireDate   | DepartmentID | Salary | ManagerID |...
    +------------+-----------+----------+--------------------+------------+--------------+--------+-----------+...
    | 1000       | Alice     | Smith    | alice.s@corp.com   | 2022-01-15 | 2            | 60000  | 1002      |...
    | 1001       | Bob       | Jones    | bob.j@corp.com     | 2021-03-10 | 2            | 75000  | 1002      |...
    | 1002       | Charlie   | Brown    | charlie.b@corp.com | 2020-05-20 | 3            | 90000  | NULL      |...
    | 1003       | Diana     | Green    | diana.g@corp.com   | 2023-07-01 | 2            | 55000  | 1002      |...
    | 1004       | Ethan     | White    | ethan.w@corp.com   | 2022-11-30 | 1            | 62000  | 1000      |...
    +------------+-----------+----------+--------------------+------------+--------------+--------+-----------+...
    ```
*   **Key Takeaway:** `SELECT *` gives you everything, mirroring the source table's structure and content at that moment.

**b) Selecting Specific Columns**

```sql
SELECT EmployeeID, FirstName, LastName, Email FROM HR.EMP_Details;
```

*   **Explanation:** Retrieves only the listed columns (`EmployeeID`, `FirstName`, `LastName`, `Email`). This is the preferred approach as it's more efficient and explicit. The columns appear in the result set in the order specified.

**Example Visualization:**

Using the same sample data as above.

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+-----------+----------+--------------------+------------+--------------+--------+-----------+
    | EmployeeID | FirstName | LastName | Email              | HireDate   | DepartmentID | Salary | ManagerID |
    +------------+-----------+----------+--------------------+------------+--------------+--------+-----------+
    | 1000       | Alice     | Smith    | alice.s@corp.com   | ...        | ...          | ...    | ...       |
    | 1001       | Bob       | Jones    | bob.j@corp.com     | ...        | ...          | ...    | ...       |
    | 1002       | Charlie   | Brown    | charlie.b@corp.com | ...        | ...          | ...    | ...       |
    | 1003       | Diana     | Green    | diana.g@corp.com   | ...        | ...          | ...    | ...       |
    | 1004       | Ethan     | White    | ethan.w@corp.com   | ...        | ...          | ...    | ...       |
    +------------+-----------+----------+--------------------+------------+--------------+--------+-----------+
    ```

*   **Output Result Set:** The query returns only the specified columns for all rows.
    ```
    +------------+-----------+----------+--------------------+
    | EmployeeID | FirstName | LastName | Email              |
    +------------+-----------+----------+--------------------+
    | 1000       | Alice     | Smith    | alice.s@corp.com   |
    | 1001       | Bob       | Jones    | bob.j@corp.com     |
    | 1002       | Charlie   | Brown    | charlie.b@corp.com |
    | 1003       | Diana     | Green    | diana.g@corp.com   |
    | 1004       | Ethan     | White    | ethan.w@corp.com   |
    +------------+-----------+----------+--------------------+
    ```
*   **Key Takeaway:** You select only the columns you need, making the query more efficient and the result set more focused.

**c) Column Aliases (`AS`)**

```sql
SELECT
    EmployeeID AS ID,
    FirstName AS [First Name], -- Use [] or "" for aliases with spaces/special chars
    Email AS [Contact Email]
FROM HR.EMP_Details;
```

*   **Explanation:** Uses the `AS` keyword to assign temporary, more readable names (aliases) to columns in the result set. Aliases do not change the actual column names in the table.

**Example Visualization:**

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+-----------+----------+--------------------+ ...
    | EmployeeID | FirstName | LastName | Email              | ...
    +------------+-----------+----------+--------------------+ ...
    | 1000       | Alice     | Smith    | alice.s@corp.com   | ...
    | 1001       | Bob       | Jones    | bob.j@corp.com     | ...
    | ...        | ...       | ...      | ...                | ...
    +------------+-----------+----------+--------------------+ ...
    ```

*   **Output Result Set:** The column headers in the output are renamed according to the aliases.
    ```
    +------+------------+-----------+----------------+
    | ID   | First Name | Last Name | Contact Email  |
    +------+------------+-----------+----------------+
    | 1000 | Alice      | Smith     | alice.s@corp.com |
    | 1001 | Bob        | Jones     | bob.j@corp.com   |
    | 1002 | Charlie    | Brown     | charlie.b@corp.com |
    | 1003 | Diana      | Green     | diana.g@corp.com |
    | 1004 | Ethan      | White     | ethan.w@corp.com |
    +------+------------+-----------+----------------+
    ```
*   **Key Takeaway:** Aliases (`AS`) improve the readability of your query results without affecting the underlying table structure. Use square brackets `[]` or double quotes `""` if your alias contains spaces or special characters.

**d) Literal Values**

```sql
SELECT
    EmployeeID, FirstName,
    'Active' AS Status,        -- Includes the text 'Active' in every row
    GETDATE() AS [Report Date] -- Includes the current timestamp in every row
FROM HR.EMP_Details;
```

*   **Explanation:** Allows including constant values (literals like text, numbers) or the results of functions (`GETDATE()`) directly in the result set along with table data.

**Example Visualization:**

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+-----------+----------+ ...
    | EmployeeID | FirstName | LastName | ...
    +------------+-----------+----------+ ...
    | 1000       | Alice     | Smith    | ...
    | 1001       | Bob       | Jones    | ...
    | ...        | ...       | ...      | ...
    +------------+-----------+----------+ ...
    ```

*   **Output Result Set:** Two new columns, `Status` and `Report Date`, are added to the output. `Status` contains the literal string 'Active' for every row, and `Report Date` contains the date and time the query was executed (e.g., '2025-03-29 03:55:00').
    ```
    +------------+-----------+----------+--------+-------------------------+
    | EmployeeID | FirstName | LastName | Status | Report Date             |
    +------------+-----------+----------+--------+-------------------------+
    | 1000       | Alice     | Smith    | Active | 2025-03-29 03:55:00.123 |
    | 1001       | Bob       | Jones    | Active | 2025-03-29 03:55:00.123 |
    | 1002       | Charlie   | Brown    | Active | 2025-03-29 03:55:00.123 |
    | 1003       | Diana     | Green    | Active | 2025-03-29 03:55:00.123 |
    | 1004       | Ethan     | White    | Active | 2025-03-29 03:55:00.123 |
    +------------+-----------+----------+--------+-------------------------+
    ```
*   **Key Takeaway:** You can inject constant values or function results directly into your `SELECT` list, which is useful for adding context like status flags or timestamps to your results.

**e) Arithmetic Operations**

```sql
SELECT
    EmployeeID, Salary,
    Salary * 1.1 AS [Salary After 10% Raise], -- Calculation based on column value
    Salary * 12 AS [Annual Salary]
FROM HR.EMP_Details;
```

*   **Explanation:** Performs calculations directly within the `SELECT` list using column values. The results are calculated for each row but do not modify the underlying table data.

**Example Visualization:**

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------+ ...
    | EmployeeID | Salary | ...
    +------------+--------+ ...
    | 1000       | 60000  | ...
    | 1001       | 75000  | ...
    | 1002       | 90000  | ...
    | 1003       | 55000  | ...
    | 1004       | 62000  | ...
    +------------+--------+ ...
    ```

*   **Output Result Set:** Includes the original `Salary` and two new calculated columns showing the salary after a hypothetical 10% raise and the annual salary.
    ```
    +------------+---------+--------------------------+----------------+
    | EmployeeID | Salary  | Salary After 10% Raise | Annual Salary  |
    +------------+---------+--------------------------+----------------+
    | 1000       | 60000.00| 66000.00                 | 720000.00      |
    | 1001       | 75000.00| 82500.00                 | 900000.00      |
    | 1002       | 90000.00| 99000.00                 | 1080000.00     |
    | 1003       | 55000.00| 60500.00                 | 660000.00      |
    | 1004       | 62000.00| 68200.00                 | 744000.00      |
    +------------+---------+--------------------------+----------------+
    ```
*   **Key Takeaway:** You can perform calculations on column data directly in the `SELECT` statement. These calculations are done "on the fly" for the result set and don't change the stored data.

**f) `DISTINCT` Keyword**

```sql
SELECT DISTINCT DepartmentID FROM HR.EMP_Details;
```

*   **Explanation:** Removes duplicate rows from the result set based on the columns specified in the `SELECT` list. If multiple rows have the exact same combination of values for all selected columns, only one instance is returned.

**Example Visualization:**

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+ ...
    | EmployeeID | DepartmentID | ...
    +------------+--------------+ ...
    | 1000       | 2            | ...
    | 1001       | 2            | ...
    | 1002       | 3            | ...
    | 1003       | 2            | ...
    | 1004       | 1            | ...
    +------------+--------------+ ...
    ```

*   **Output Result Set:** Only the unique `DepartmentID` values present in the table are returned. Even though DepartmentID `2` appears multiple times in the input, it appears only once in the output.
    ```
    +--------------+
    | DepartmentID |
    +--------------+
    | 1            |
    | 2            |
    | 3            |
    +--------------+
    ```
*   **Key Takeaway:** `DISTINCT` is used to get a list of unique values for the selected column(s).

**g) `TOP` Clause**

```sql
SELECT TOP 10 * FROM HR.EMP_Details ORDER BY Salary DESC;
```

*   **Explanation:** Limits the result set to the specified number of rows (`TOP 10`). **Crucially, `TOP` without `ORDER BY` returns an arbitrary set of rows.** Using `ORDER BY` (as shown) makes `TOP` meaningful, retrieving the first N rows according to the sort order (e.g., the 10 highest salaries).

**Example Visualization:** (Using `TOP 2` for brevity)

```sql
SELECT TOP 2 * FROM HR.EMP_Details ORDER BY Salary DESC;
```

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet, ordered by Salary DESC):**
    ```
    +------------+-----------+----------+--------+ ...
    | EmployeeID | FirstName | LastName | Salary | ...
    +------------+-----------+----------+--------+ ...
    | 1002       | Charlie   | Brown    | 90000  | ...  <- Highest Salary
    | 1001       | Bob       | Jones    | 75000  | ...  <- 2nd Highest
    | 1004       | Ethan     | White    | 62000  | ...
    | 1000       | Alice     | Smith    | 60000  | ...
    | 1003       | Diana     | Green    | 55000  | ...
    +------------+-----------+----------+--------+ ...
    ```

*   **Output Result Set:** Returns only the top 2 rows based on the `ORDER BY Salary DESC` clause.
    ```
    +------------+-----------+----------+--------+ ... (all columns)
    | EmployeeID | FirstName | LastName | Salary | ...
    +------------+-----------+----------+--------+ ...
    | 1002       | Charlie   | Brown    | 90000  | ...
    | 1001       | Bob       | Jones    | 75000  | ...
    +------------+-----------+----------+--------+ ...
    ```
*   **Key Takeaway:** `TOP N` combined with `ORDER BY` is essential for retrieving a specific number of highest or lowest records based on some criteria. Without `ORDER BY`, `TOP` gives unpredictable results.

**h) `TOP` with `PERCENT`**

```sql
SELECT TOP 5 PERCENT * FROM HR.EMP_Details ORDER BY HireDate DESC;
```

*   **Explanation:** Limits the result set to a specified percentage of the total rows matching the query criteria (e.g., 5% of employees, ordered by hire date).

**Example Visualization:** (Using `TOP 40 PERCENT` with 5 total rows = Top 2 rows)

```sql
SELECT TOP 40 PERCENT * FROM HR.EMP_Details ORDER BY HireDate DESC;
```

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet, ordered by HireDate DESC):**
    ```
    +------------+-----------+----------+------------+ ...
    | EmployeeID | FirstName | LastName | HireDate   | ...
    +------------+-----------+----------+------------+ ...
    | 1003       | Diana     | Green    | 2023-07-01 | ... <- Most Recent Hire
    | 1004       | Ethan     | White    | 2022-11-30 | ... <- 2nd Most Recent
    | 1000       | Alice     | Smith    | 2022-01-15 | ...
    | 1001       | Bob       | Jones    | 2021-03-10 | ...
    | 1002       | Charlie   | Brown    | 2020-05-20 | ...
    +------------+-----------+----------+------------+ ...
    ```

*   **Output Result Set:** Returns the top 40% of rows (which is 2 rows in this 5-row example) based on the `ORDER BY HireDate DESC` clause.
    ```
    +------------+-----------+----------+------------+ ... (all columns)
    | EmployeeID | FirstName | LastName | HireDate   | ...
    +------------+-----------+----------+------------+ ...
    | 1003       | Diana     | Green    | 2023-07-01 | ...
    | 1004       | Ethan     | White    | 2022-11-30 | ...
    +------------+-----------+----------+------------+ ...
    ```
*   **Key Takeaway:** `TOP N PERCENT` selects a proportion of rows, useful when the exact number isn't fixed but a relative amount is needed. Requires `ORDER BY` for meaningful results.

**i) `TOP` with `TIES`**

```sql
SELECT TOP 5 WITH TIES * FROM HR.EMP_Details ORDER BY Salary DESC;
```

*   **Explanation:** Retrieves the top N rows based on the `ORDER BY` clause, *plus* any additional rows that have the same value in the `ORDER BY` column(s) as the Nth row. If the 5th and 6th highest salaries are identical, `TOP 5 WITH TIES` will return both (and potentially more if others also share that salary).

**Example Visualization:** (Using `TOP 3 WITH TIES` and adding a tied salary)

Let's modify the sample data slightly to have a tie for the 3rd highest salary:

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet with Tie):**
    ```
    +------------+-----------+----------+--------+ ...
    | EmployeeID | FirstName | LastName | Salary | ...
    +------------+-----------+----------+--------+ ...
    | 1002       | Charlie   | Brown    | 90000  | ...  <- 1st
    | 1001       | Bob       | Jones    | 75000  | ...  <- 2nd
    | 1004       | Ethan     | White    | 62000  | ...  <- 3rd (Tie)
    | 1005       | Fiona     | Black    | 62000  | ...  <- 3rd (Tie)
    | 1000       | Alice     | Smith    | 60000  | ...
    | 1003       | Diana     | Green    | 55000  | ...
    +------------+-----------+----------+--------+ ...
    ```
```sql
SELECT TOP 3 WITH TIES * FROM HR.EMP_Details ORDER BY Salary DESC;
```
*   **Output Result Set:** Returns the top 3 rows (Charlie, Bob, Ethan), *plus* Fiona because her salary (62000) is the same as the 3rd person's (Ethan).
    ```
    +------------+-----------+----------+--------+ ... (all columns)
    | EmployeeID | FirstName | LastName | Salary | ...
    +------------+-----------+----------+--------+ ...
    | 1002       | Charlie   | Brown    | 90000  | ...
    | 1001       | Bob       | Jones    | 75000  | ...
    | 1004       | Ethan     | White    | 62000  | ...
    | 1005       | Fiona     | Black    | 62000  | ...
    +------------+-----------+----------+--------+ ...
    ```
*   **Key Takeaway:** `WITH TIES` ensures you don't arbitrarily cut off records that share the same ranking value as the last record included by the `TOP N` clause. The number of rows returned can be greater than N.

**j) Simple `WHERE` Clause**

```sql
SELECT * FROM HR.EMP_Details WHERE DepartmentID = 3;
```

*   **Explanation:** Filters the rows returned. Only rows where the condition (`DepartmentID = 3`) evaluates to true are included in the result set.

**Example Visualization:**

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+-----------+----------+--------------+ ...
    | EmployeeID | FirstName | LastName | DepartmentID | ...
    +------------+-----------+----------+--------------+ ...
    | 1000       | Alice     | Smith    | 2            | ...
    | 1001       | Bob       | Jones    | 2            | ...
    | 1002       | Charlie   | Brown    | 3            | ... <- Match
    | 1003       | Diana     | Green    | 2            | ...
    | 1004       | Ethan     | White    | 1            | ...
    +------------+-----------+----------+--------------+ ...
    ```

*   **Output Result Set:** Only the row(s) where `DepartmentID` is exactly 3 are returned.
    ```
    +------------+-----------+----------+--------------+ ... (all columns)
    | EmployeeID | FirstName | LastName | DepartmentID | ...
    +------------+-----------+----------+--------------+ ...
    | 1002       | Charlie   | Brown    | 3            | ...
    +------------+-----------+----------+--------------+ ...
    ```
*   **Key Takeaway:** The `WHERE` clause acts as a filter, selecting only the rows that meet the specified criteria.

**k) Multiple `WHERE` Conditions (`AND`/`OR`)**

```sql
SELECT * FROM HR.EMP_Details WHERE Salary > 50000 AND DepartmentID = 2;
```

*   **Explanation:** Combines multiple conditions using logical operators (`AND`, `OR`, `NOT`). `AND` requires both conditions to be true; `OR` requires at least one to be true. Parentheses `()` can be used to control the order of evaluation.

**Example Visualization:**

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+-----------+----------+--------------+--------+ ...
    | EmployeeID | FirstName | LastName | DepartmentID | Salary | ...
    +------------+-----------+----------+--------------+--------+ ...
    | 1000       | Alice     | Smith    | 2            | 60000  | ... <- Dept=2, Salary>50k (Match)
    | 1001       | Bob       | Jones    | 2            | 75000  | ... <- Dept=2, Salary>50k (Match)
    | 1002       | Charlie   | Brown    | 3            | 90000  | ... <- Salary>50k, but Dept!=2
    | 1003       | Diana     | Green    | 2            | 55000  | ... <- Dept=2, Salary>50k (Match)
    | 1004       | Ethan     | White    | 1            | 62000  | ... <- Salary>50k, but Dept!=2
    +------------+-----------+----------+--------------+--------+ ...
    ```

*   **Output Result Set:** Only rows where *both* `Salary` is greater than 50000 *and* `DepartmentID` is 2 are returned.
    ```
    +------------+-----------+----------+--------------+--------+ ... (all columns)
    | EmployeeID | FirstName | LastName | DepartmentID | Salary | ...
    +------------+-----------+----------+--------------+--------+ ...
    | 1000       | Alice     | Smith    | 2            | 60000  | ...
    | 1001       | Bob       | Jones    | 2            | 75000  | ...
    | 1003       | Diana     | Green    | 2            | 55000  | ...
    +------------+-----------+----------+--------------+--------+ ...
    ```
*   **Key Takeaway:** `AND` requires all conditions to be true for a row to be included. `OR` requires at least one condition to be true. Use parentheses `()` to group conditions if mixing `AND` and `OR`.

**l) `ORDER BY` Clause**

```sql
SELECT EmployeeID, FirstName, LastName, Salary
FROM HR.EMP_Details
ORDER BY Salary DESC, LastName ASC;
```

*   **Explanation:** Sorts the rows in the final result set.
    *   `ASC`: Ascending order (A-Z, lowest to highest) - default if not specified.
    *   `DESC`: Descending order (Z-A, highest to lowest).
    *   Multiple columns can be specified for secondary, tertiary sorting (applied when values in preceding sort columns are equal).

**Example Visualization:**

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet, adding a salary tie):**
    ```
    +------------+-----------+----------+--------+ ...
    | EmployeeID | FirstName | LastName | Salary | ...
    +------------+-----------+----------+--------+ ...
    | 1000       | Alice     | Smith    | 60000  | ...
    | 1001       | Bob       | Jones    | 75000  | ...
    | 1002       | Charlie   | Brown    | 90000  | ...
    | 1003       | Diana     | Green    | 55000  | ...
    | 1004       | Ethan     | White    | 60000  | ... <- Tie with Alice
    +------------+-----------+----------+--------+ ...
    ```

*   **Output Result Set:** Rows are sorted primarily by `Salary` in descending order (highest first). For rows with the same salary (Alice and Ethan), they are secondarily sorted by `LastName` in ascending order (A-Z).
    ```
    +------------+-----------+----------+--------+
    | EmployeeID | FirstName | LastName | Salary |
    +------------+-----------+----------+--------+
    | 1002       | Charlie   | Brown    | 90000  | <- Highest Salary
    | 1001       | Bob       | Jones    | 75000  |
    | 1000       | Alice     | Smith    | 60000  | <- Smith comes before White alphabetically
    | 1004       | Ethan     | White    | 60000  |
    | 1003       | Diana     | Green    | 55000  | <- Lowest Salary
    +------------+-----------+----------+--------+
    ```
*   **Key Takeaway:** `ORDER BY` controls the presentation order of the final result set. You can specify multiple columns for multi-level sorting, and choose ascending (`ASC`, default) or descending (`DESC`) order for each.

**m) Handling `NULL` Values**

```sql
SELECT * FROM HR.EMP_Details WHERE ManagerID IS NULL;
```

*   **Explanation:** `NULL` represents an unknown or missing value. Standard comparison operators (`=`, `<>`, `>`) don't work as expected with `NULL`. Use `IS NULL` to find rows where a column has no value, and `IS NOT NULL` to find rows where a column *does* have a value. (Note: The `ManagerID` column was added conceptually to our sample data for this example).

**Example Visualization:**

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+-----------+----------+-----------+ ...
    | EmployeeID | FirstName | LastName | ManagerID | ...
    +------------+-----------+----------+-----------+ ...
    | 1000       | Alice     | Smith    | 1002      | ...
    | 1001       | Bob       | Jones    | 1002      | ...
    | 1002       | Charlie   | Brown    | NULL      | ... <- Match
    | 1003       | Diana     | Green    | 1002      | ...
    | 1004       | Ethan     | White    | 1000      | ...
    +------------+-----------+----------+-----------+ ...
    ```

*   **Output Result Set:** Only the row(s) where `ManagerID` is `NULL` are returned.
    ```
    +------------+-----------+----------+-----------+ ... (all columns)
    | EmployeeID | FirstName | LastName | ManagerID | ...
    +------------+-----------+----------+-----------+ ...
    | 1002       | Charlie   | Brown    | NULL      | ...
    +------------+-----------+----------+-----------+ ...
    ```
*   **Key Takeaway:** Always use `IS NULL` or `IS NOT NULL` to check for the presence or absence of a value in nullable columns. Standard comparisons like `= NULL` or `<> NULL` do not work as expected.

**n) `OFFSET`-`FETCH` Clause (Pagination)**

```sql
SELECT * FROM HR.EMP_Details
ORDER BY EmployeeID -- ORDER BY is REQUIRED for OFFSET-FETCH
OFFSET 10 ROWS          -- Skip N rows
FETCH NEXT 2 ROWS ONLY; -- Return the next M rows (Using 2 for brevity)
```

*   **Explanation:** A standard SQL way (SQL Server 2012+) to implement pagination. `OFFSET` specifies how many rows to skip from the beginning of the ordered result set. `FETCH NEXT` (or `FETCH FIRST`) specifies how many rows to return after the offset. Requires an `ORDER BY` clause to ensure consistent ordering for pagination.

**Example Visualization:** (Using `OFFSET 2 ROWS FETCH NEXT 2 ROWS ONLY`)

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet, ordered by EmployeeID):**
    ```
    +------------+-----------+----------+ ...
    | EmployeeID | FirstName | LastName | ...
    +------------+-----------+----------+ ...
    | 1000       | Alice     | Smith    | ... <- Row 1
    | 1001       | Bob       | Jones    | ... <- Row 2
    | 1002       | Charlie   | Brown    | ... <- Row 3
    | 1003       | Diana     | Green    | ... <- Row 4
    | 1004       | Ethan     | White    | ... <- Row 5
    +------------+-----------+----------+ ...
    ```

*   **Output Result Set:** The query skips the first 2 rows (`OFFSET 2`) and then returns the next 2 rows (`FETCH NEXT 2`). This effectively retrieves rows 3 and 4.
    ```
    +------------+-----------+----------+ ... (all columns)
    | EmployeeID | FirstName | LastName | ...
    +------------+-----------+----------+ ...
    | 1002       | Charlie   | Brown    | ...
    | 1003       | Diana     | Green    | ...
    +------------+-----------+----------+ ...
    ```
*   **Key Takeaway:** `OFFSET`-`FETCH` provides a standard way to retrieve specific "pages" of data. `ORDER BY` is mandatory to ensure the pages are consistent. `OFFSET` defines the starting point (how many rows to skip), and `FETCH` defines the page size (how many rows to return).

**o) Simple `CASE` Expression**

```sql
SELECT EmployeeID, FirstName, LastName,
    CASE DepartmentID
        WHEN 1 THEN 'HR'
        WHEN 2 THEN 'IT'
        ELSE 'Other'
    END AS Department -- Alias for the calculated column
FROM HR.EMP_Details;
```

*   **Explanation:** Allows conditional logic within the `SELECT` list (or `WHERE`, `ORDER BY`). This "simple `CASE`" compares one expression (`DepartmentID`) against multiple specific values (`WHEN ... THEN ...`). The `ELSE` clause handles values not explicitly matched. There's also a "searched `CASE`" (`CASE WHEN condition1 THEN result1 ... END`) for more complex conditions.

**Example Visualization:** (Assuming DepartmentID 1='HR', 2='IT', 3='Finance')

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+-----------+----------+--------------+ ...
    | EmployeeID | FirstName | LastName | DepartmentID | ...
    +------------+-----------+----------+--------------+ ...
    | 1000       | Alice     | Smith    | 2            | ...
    | 1001       | Bob       | Jones    | 2            | ...
    | 1002       | Charlie   | Brown    | 3            | ...
    | 1003       | Diana     | Green    | 2            | ...
    | 1004       | Ethan     | White    | 1            | ...
    | 1006       | Grace     | Hall     | 4            | ... <- No explicit WHEN match
    +------------+-----------+----------+--------------+ ...
    ```

*   **Output Result Set:** A new `Department` column is generated. Its value depends on the `DepartmentID` for each row, based on the `CASE` conditions. DepartmentID 4 falls into the `ELSE 'Other'` category.
    ```
    +------------+-----------+----------+------------+
    | EmployeeID | FirstName | LastName | Department |
    +------------+-----------+----------+------------+
    | 1000       | Alice     | Smith    | IT         |
    | 1001       | Bob       | Jones    | IT         |
    | 1002       | Charlie   | Brown    | Finance    |
    | 1003       | Diana     | Green    | IT         |
    | 1004       | Ethan     | White    | HR         |
    | 1006       | Grace     | Hall     | Other      |
    +------------+-----------+----------+------------+
    ```
*   **Key Takeaway:** `CASE` expressions allow you to implement conditional logic (like IF-THEN-ELSE) directly within your SQL queries, transforming data or creating derived values based on specific conditions.

## 3. Targeted Interview Questions (Based on `26_select_basics.sql`)

**Question 1:** What is the difference between `SELECT TOP 5 * FROM HR.EMP_Details ORDER BY Salary DESC;` and `SELECT TOP 5 WITH TIES * FROM HR.EMP_Details ORDER BY Salary DESC;`?

**Solution 1:**

*   `TOP 5`: Guarantees that *at most* 5 rows will be returned. It selects the 5 rows with the highest salary according to the `ORDER BY` clause.
*   `TOP 5 WITH TIES`: Selects the 5 rows with the highest salary, *plus* any additional rows that have the exact same salary as the 5th row. This means it could return 5, 6, or more rows if multiple employees share the 5th highest salary.

**Question 2:** Why is `SELECT *` generally discouraged in production code, even though it's convenient? Give two reasons.

**Solution 2:**
1.  **Performance:** It retrieves all columns, potentially including large or unnecessary ones, increasing network traffic, I/O, and memory usage both on the database server and the client application. Explicitly selecting only needed columns is more efficient.
2.  **Brittleness/Maintainability:** If the underlying table structure changes (columns added, removed, or reordered), `SELECT *` can cause application code relying on a specific column order or set of columns to break unexpectedly. Explicitly listing columns makes the query resilient to such changes (unless a listed column is dropped).

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What clause is used to filter rows based on a condition?
    *   **Answer:** `WHERE`.
2.  **[Easy]** What clause is used to sort the results of a `SELECT` statement?
    *   **Answer:** `ORDER BY`.
3.  **[Medium]** In what order are the `SELECT`, `FROM`, `WHERE`, and `ORDER BY` clauses logically processed by the database engine (even though they are written in a different order)?
    *   **Answer:** The typical logical processing order is: 1. `FROM` (identifying source tables/joins), 2. `WHERE` (filtering rows), 3. `SELECT` (choosing/calculating columns), 4. `ORDER BY` (sorting the final result). (Note: `GROUP BY` and `HAVING` fit between `WHERE` and `SELECT`).
4.  **[Medium]** How do you filter rows where a specific column `CommissionPct` has no value assigned?
    *   **Answer:** Use `WHERE CommissionPct IS NULL;`. You cannot use `WHERE CommissionPct = NULL;`.
5.  **[Medium]** What is the difference between `SELECT DISTINCT DepartmentID, LocationID FROM Employees;` and `SELECT DepartmentID, LocationID FROM Employees;`?
    *   **Answer:** The `DISTINCT` version returns only unique *combinations* of `DepartmentID` and `LocationID`. If multiple employees are in the same department and location, that combination appears only once. The version without `DISTINCT` returns one row for every employee, potentially showing the same department/location combination multiple times.
6.  **[Medium]** Can you use a column alias defined in the `SELECT` list directly within the `WHERE` clause of the same query? Why or why not?
    *   **Answer:** No, you generally cannot. Based on the logical processing order, the `WHERE` clause is evaluated *before* the `SELECT` list where the alias is defined. Therefore, the alias doesn't exist yet when the `WHERE` clause is processed. You need to repeat the expression or use a subquery/CTE.
7.  **[Hard]** What is required before you can use the `OFFSET`/`FETCH` clause for pagination?
    *   **Answer:** An `ORDER BY` clause is mandatory. `OFFSET`/`FETCH` operates on an ordered result set to determine which rows to skip and which to return; without `ORDER BY`, the concept of "first N rows" or "next M rows" is undefined and arbitrary.
8.  **[Hard]** Can you use window functions (like `ROW_NUMBER()`, `RANK()`) directly in the `WHERE` clause to filter rows? If not, how would you typically filter based on the result of a window function?
    *   **Answer:** No, window functions cannot be used directly in the `WHERE` clause. They are evaluated *after* the `WHERE` clause (logically, often during or after the `SELECT` phase). To filter based on a window function's result, you typically need to use a subquery or a Common Table Expression (CTE):
        ```sql
        WITH RankedData AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...) as rn
            FROM YourTable
        )
        SELECT * FROM RankedData WHERE rn = 1; -- Filter in the outer query
        ```
9.  **[Hard]** What is the difference in how `NULL` values are treated by `ORDER BY ColumnA ASC` versus `ORDER BY ColumnA DESC` in SQL Server?
    *   **Answer:** In SQL Server:
        *   `ORDER BY ColumnA ASC`: `NULL` values appear **first**.
        *   `ORDER BY ColumnA DESC`: `NULL` values appear **last**. (Note: This behavior can differ in other database systems).
10. **[Hard/Tricky]** If a table has a `CHECK` constraint defined (e.g., `Salary > 0`), and you execute a `SELECT Salary * -1 AS NegativeSalary FROM Employees;`, will this query violate the `CHECK` constraint?
    *   **Answer:** No. `CHECK` constraints are enforced during data modification operations (`INSERT`, `UPDATE`). `SELECT` statements only retrieve or calculate data; they do not modify the underlying table data and therefore do not trigger `CHECK` constraint validation on the results being selected. The query will execute successfully and return negative salary values in the `NegativeSalary` column.
