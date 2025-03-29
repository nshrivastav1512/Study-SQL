# SQL Deep Dive: Advanced Filtering with `WHERE`

## 1. Introduction: The Power of `WHERE`

The `WHERE` clause is fundamental to retrieving specific data from your tables. While the basic `SELECT` retrieves columns, `WHERE` filters the **rows**, allowing you to specify precise criteria that rows must meet to be included in the result set. Mastering filtering techniques is essential for effective data querying.

**Why is Filtering Important?**

*   **Targeted Data:** Retrieves only the relevant information needed, reducing noise and improving clarity.
*   **Performance:** Filtering data at the source (database) is usually much more efficient than retrieving large amounts of data and filtering it in the application layer. Indexes can often be used to speed up `WHERE` clause processing.
*   **Analysis & Reporting:** Allows focusing on specific subsets of data for analysis or report generation.

## 2. Filtering Techniques in Action: Analysis of `27_select_filtering.sql`

This script explores various operators and methods used within the `WHERE` clause.

**a) Comparison Operators**

```sql
WHERE Salary = 50000;   -- Equal
WHERE Salary != 50000;  -- Not Equal (also <>)
WHERE Salary > 50000;   -- Greater Than
WHERE Salary < 50000;   -- Less Than
WHERE Salary >= 50000;  -- Greater Than or Equal
WHERE Salary <= 50000;  -- Less Than or Equal
```

*   **Explanation:** These are the standard operators for comparing numeric, date, or string values. They form the basis of most filtering conditions.

<details>
<summary>Click to see Example Visualization (Comparison)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------+
    | EmployeeID | Salary |
    +------------+--------+
    | 1000       | 60000  |
    | 1001       | 75000  |
    | 1002       | 90000  |
    | 1003       | 55000  |
    | 1004       | 62000  |
    +------------+--------+
    ```
*   **Example Query:** `SELECT EmployeeID, Salary FROM HR.EMP_Details WHERE Salary > 60000;`
*   **Output Result Set:**
    ```
    +------------+--------+
    | EmployeeID | Salary |
    +------------+--------+
    | 1001       | 75000  |
    | 1002       | 90000  |
    | 1004       | 62000  |
    +------------+--------+
    ```
*   **Key Takeaway:** Comparison operators filter rows based on whether a column's value meets the specified condition (e.g., greater than, equal to, less than).

</details>

**b) Logical Operators (`AND`, `OR`, `NOT`)**

```sql
WHERE DepartmentID = 1 AND Salary > 50000; -- Both conditions must be true
WHERE DepartmentID = 1 OR DepartmentID = 2;  -- At least one condition must be true
WHERE NOT DepartmentID = 3;                -- Negates the condition (same as <>)
```

*   **Explanation:** Used to combine multiple comparison conditions. `AND` narrows results, `OR` broadens results. `NOT` reverses the truth value of a condition. Parentheses `()` should be used to control the order of evaluation in complex expressions involving both `AND` and `OR`.

<details>
<summary>Click to see Example Visualization (Logical)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1000       | 2            | 60000  | <- Dept=2, Salary>50k (AND Match)
    | 1001       | 2            | 75000  | <- Dept=2, Salary>50k (AND Match)
    | 1002       | 3            | 90000  | <- Dept=3 (OR Match)
    | 1003       | 2            | 55000  | <- Dept=2, Salary>50k (AND Match)
    | 1004       | 1            | 62000  | <- Dept=1 (OR Match)
    | 1005       | 1            | 48000  | <- Dept=1 (OR Match)
    +------------+--------------+--------+
    ```
*   **Example Query (AND):** `SELECT EmployeeID FROM HR.EMP_Details WHERE DepartmentID = 2 AND Salary > 50000;`
*   **Output (AND):**
    ```
    +------------+
    | EmployeeID |
    +------------+
    | 1000       |
    | 1001       |
    | 1003       |
    +------------+
    ```
*   **Example Query (OR):** `SELECT EmployeeID FROM HR.EMP_Details WHERE DepartmentID = 1 OR DepartmentID = 3;`
*   **Output (OR):**
    ```
    +------------+
    | EmployeeID |
    +------------+
    | 1002       |
    | 1004       |
    | 1005       |
    +------------+
    ```
*   **Key Takeaway:** `AND` requires all conditions to be true; `OR` requires at least one condition to be true.

</details>

**c) `BETWEEN` Operator**

```sql
WHERE Salary BETWEEN 40000 AND 60000; -- Inclusive range (>= 40k AND <= 60k)
WHERE HireDate BETWEEN '2020-01-01' AND '2020-12-31'; -- Inclusive date range
```

*   **Explanation:** A shorthand way to check if a value falls within an *inclusive* range (including the start and end values). Equivalent to `value >= lower_bound AND value <= upper_bound`. Works for numbers, dates, and sometimes strings (based on alphabetical order).

<details>
<summary>Click to see Example Visualization (BETWEEN)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------+------------+
    | EmployeeID | Salary | HireDate   |
    +------------+--------+------------+
    | 1000       | 60000  | 2022-01-15 | <- Salary Match
    | 1001       | 75000  | 2021-03-10 |
    | 1002       | 90000  | 2020-05-20 | <- HireDate Match
    | 1003       | 55000  | 2023-07-01 | <- Salary Match
    | 1004       | 62000  | 2022-11-30 |
    | 1005       | 48000  | 2023-02-20 | <- Salary Match
    +------------+--------+------------+
    ```
*   **Example Query (Salary):** `SELECT EmployeeID, Salary FROM HR.EMP_Details WHERE Salary BETWEEN 40000 AND 60000;`
*   **Output (Salary):**
    ```
    +------------+--------+
    | EmployeeID | Salary |
    +------------+--------+
    | 1000       | 60000  |
    | 1003       | 55000  |
    | 1005       | 48000  |
    +------------+--------+
    ```
*   **Example Query (HireDate):** `SELECT EmployeeID, HireDate FROM HR.EMP_Details WHERE HireDate BETWEEN '2020-01-01' AND '2020-12-31';`
*   **Output (HireDate):**
    ```
    +------------+------------+
    | EmployeeID | HireDate   |
    +------------+------------+
    | 1002       | 2020-05-20 |
    +------------+------------+
    ```
*   **Key Takeaway:** `BETWEEN` provides a concise way to filter for values within an inclusive range.

</details>

**d) `IN` Operator**

```sql
WHERE DepartmentID IN (1, 3, 5); -- Check if value matches any in the list
WHERE LastName IN ('Smith', 'Johnson', 'Williams');
```

*   **Explanation:** A shorthand way to check if a value matches any value within a specified list. Equivalent to multiple `OR` conditions (`value = val1 OR value = val2 OR ...`). Often more readable and sometimes more performant than multiple `OR`s.

<details>
<summary>Click to see Example Visualization (IN)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+----------+
    | EmployeeID | DepartmentID | LastName |
    +------------+--------------+----------+
    | 1000       | 2            | Smith    | <- LastName Match
    | 1001       | 2            | Jones    |
    | 1002       | 3            | Brown    | <- Dept Match
    | 1003       | 2            | Green    |
    | 1004       | 1            | White    | <- Dept Match
    | 1005       | 1            | Black    | <- Dept Match
    +------------+--------------+----------+
    ```
*   **Example Query (Dept):** `SELECT EmployeeID, DepartmentID FROM HR.EMP_Details WHERE DepartmentID IN (1, 3);`
*   **Output (Dept):**
    ```
    +------------+--------------+
    | EmployeeID | DepartmentID |
    +------------+--------------+
    | 1002       | 3            |
    | 1004       | 1            |
    | 1005       | 1            |
    +------------+--------------+
    ```
*   **Example Query (Name):** `SELECT EmployeeID, LastName FROM HR.EMP_Details WHERE LastName IN ('Smith', 'Brown');`
*   **Output (Name):**
    ```
    +------------+----------+
    | EmployeeID | LastName |
    +------------+----------+
    | 1000       | Smith    |
    | 1002       | Brown    |
    +------------+----------+
    ```
*   **Key Takeaway:** `IN` simplifies checking if a column's value matches any item in a provided list.

</details>

**e) `LIKE` Operator with Wildcards**

```sql
WHERE LastName LIKE 'S%';       -- Starts with 'S' (% = any sequence of 0+ chars)
WHERE Email LIKE '%@gmail.com'; -- Ends with '@gmail.com'
WHERE FirstName LIKE '_a%';     -- Second character is 'a' (_ = exactly one char)
WHERE Phone LIKE '[0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'; -- Specific pattern ([range])
```

*   **Explanation:** Used for pattern matching in string data.
    *   `%`: Matches zero or more characters.
    *   `_`: Matches exactly one character.
    *   `[]`: Matches any single character within the brackets (e.g., `[abc]`, `[a-f]`, `[0-9]`).
    *   `[^]`: Matches any single character *not* within the brackets (e.g., `[^abc]`).
    *   `ESCAPE`: Used to search for literal wildcard characters (e.g., `WHERE Code LIKE 'AB!_%' ESCAPE '!'`).

<details>
<summary>Click to see Example Visualization (LIKE)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+-----------+----------+--------------------+
    | EmployeeID | FirstName | LastName | Email              |
    +------------+-----------+----------+--------------------+
    | 1000       | Alice     | Smith    | alice.s@corp.com   | <- LastName starts 'S'
    | 1001       | Bob       | Jones    | bob.j@corp.com     |
    | 1002       | Charlie   | Brown    | charlie.b@corp.com |
    | 1003       | Diana     | Green    | diana.g@corp.com   | <- FirstName 2nd char 'i'
    | 1004       | Ethan     | White    | ethan.w@corp.com   |
    | 1005       | Fiona     | Black    | fiona.b@corp.com   |
    +------------+-----------+----------+--------------------+
    ```
*   **Example Query (Starts With):** `SELECT EmployeeID, LastName FROM HR.EMP_Details WHERE LastName LIKE 'S%';`
*   **Output (Starts With):**
    ```
    +------------+----------+
    | EmployeeID | LastName |
    +------------+----------+
    | 1000       | Smith    |
    +------------+----------+
    ```
*   **Example Query (Ends With):** `SELECT EmployeeID, Email FROM HR.EMP_Details WHERE Email LIKE '%@corp.com';`
*   **Output (Ends With):** (All rows match in this sample)
    ```
    +------------+--------------------+
    | EmployeeID | Email              |
    +------------+--------------------+
    | 1000       | alice.s@corp.com   |
    | 1001       | bob.j@corp.com     |
    | 1002       | charlie.b@corp.com |
    | 1003       | diana.g@corp.com   |
    | 1004       | ethan.w@corp.com   |
    | 1005       | fiona.b@corp.com   |
    +------------+--------------------+
    ```
*   **Example Query (Specific Position):** `SELECT EmployeeID, FirstName FROM HR.EMP_Details WHERE FirstName LIKE '_i%';`
*   **Output (Specific Position):**
    ```
    +------------+-----------+
    | EmployeeID | FirstName |
    +------------+-----------+
    | 1003       | Diana     |
    | 1005       | Fiona     |
    +------------+-----------+
    ```
*   **Key Takeaway:** `LIKE` combined with wildcards (`%`, `_`, `[]`) allows flexible pattern matching within strings.

</details>

**f) `NULL` Handling (`IS NULL`, `IS NOT NULL`)**

```sql
WHERE ManagerID IS NULL;     -- Find rows where ManagerID has no value
WHERE MiddleName IS NOT NULL; -- Find rows where MiddleName has a value
```

*   **Explanation:** `NULL` requires special handling. Use `IS NULL` and `IS NOT NULL` to check for the presence or absence of a value. Standard comparison operators (`= NULL`, `<> NULL`) do not work reliably.

<details>
<summary>Click to see Example Visualization (NULL)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+-----------+
    | EmployeeID | ManagerID |
    +------------+-----------+
    | 1000       | 1002      |
    | 1001       | 1002      |
    | 1002       | NULL      | <- IS NULL Match
    | 1003       | 1002      |
    | 1004       | 1000      |
    | 1005       | 1000      |
    +------------+-----------+
    ```
*   **Example Query (IS NULL):** `SELECT EmployeeID FROM HR.EMP_Details WHERE ManagerID IS NULL;`
*   **Output (IS NULL):**
    ```
    +------------+
    | EmployeeID |
    +------------+
    | 1002       |
    +------------+
    ```
*   **Example Query (IS NOT NULL):** `SELECT EmployeeID FROM HR.EMP_Details WHERE ManagerID IS NOT NULL;`
*   **Output (IS NOT NULL):**
    ```
    +------------+
    | EmployeeID |
    +------------+
    | 1000       |
    | 1001       |
    | 1003       |
    | 1004       |
    | 1005       |
    +------------+
    ```
*   **Key Takeaway:** Use `IS NULL` or `IS NOT NULL` for reliable checks against `NULL` values.

</details>

**g) Compound Conditions (Parentheses)**

```sql
WHERE (DepartmentID = 1 OR DepartmentID = 2) AND Salary > 50000;
```

*   **Explanation:** Parentheses `()` are crucial to control the order in which `AND` and `OR` operators are evaluated, ensuring the intended logic is applied. Here, the `OR` is evaluated first.

<details>
<summary>Click to see Example Visualization (Parentheses)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1000       | 2            | 60000  | <- Dept=2, Salary>50k (Match)
    | 1001       | 2            | 75000  | <- Dept=2, Salary>50k (Match)
    | 1002       | 3            | 90000  | <- Dept=3, Salary>50k (No Match)
    | 1003       | 2            | 55000  | <- Dept=2, Salary>50k (Match)
    | 1004       | 1            | 62000  | <- Dept=1, Salary>50k (Match)
    | 1005       | 1            | 48000  | <- Dept=1, Salary<=50k (No Match)
    +------------+--------------+--------+
    ```
*   **Example Query:** `SELECT EmployeeID FROM HR.EMP_Details WHERE (DepartmentID = 1 OR DepartmentID = 2) AND Salary > 50000;`
*   **Output Result Set:** Finds employees in Dept 1 OR Dept 2, *and* whose salary is > 50000.
    ```
    +------------+
    | EmployeeID |
    +------------+
    | 1000       |
    | 1001       |
    | 1003       |
    | 1004       |
    +------------+
    ```
*   **Key Takeaway:** Parentheses dictate the order of operations, ensuring logical conditions are grouped and evaluated as intended. Without them, `AND` usually takes precedence over `OR`.

</details>

**h) `EXISTS` Operator**

```sql
WHERE EXISTS (SELECT 1 FROM HR.EMP_Details e WHERE e.DepartmentID = d.DepartmentID AND e.Salary > 70000);
```

*   **Explanation:** Checks for the *existence* of rows returned by a subquery. It returns `TRUE` if the subquery returns one or more rows, `FALSE` otherwise. Often used with *correlated subqueries* (where the subquery references columns from the outer query, like `d.DepartmentID`). `EXISTS` is generally efficient as it can stop processing the subquery as soon as the first matching row is found.

<details>
<summary>Click to see Example Visualization (EXISTS)</summary>

*   **Input Tables (`HR.Departments` d, `HR.EMP_Details` e - Conceptual):**
    *   `HR.Departments`:
        ```
        +--------------+----------------+
        | DepartmentID | DepartmentName |
        +--------------+----------------+
        | 1            | HR             |
        | 2            | IT             |
        | 3            | Finance        |
        | 4            | Marketing      | <- No employees in sample
        +--------------+----------------+
        ```
    *   `HR.EMP_Details`: (Relevant columns)
        ```
        +------------+--------------+--------+
        | EmployeeID | DepartmentID | Salary |
        +------------+--------------+--------+
        | 1000       | 2            | 60000  |
        | 1001       | 2            | 75000  | <- High earner in Dept 2
        | 1002       | 3            | 90000  | <- High earner in Dept 3
        | 1003       | 2            | 55000  |
        | 1004       | 1            | 62000  |
        | 1005       | 1            | 48000  |
        +------------+--------------+--------+
        ```
*   **Example Query:** Find departments that have at least one employee earning over 70000.
    ```sql
    SELECT d.DepartmentName
    FROM HR.Departments d
    WHERE EXISTS (SELECT 1
                  FROM HR.EMP_Details e
                  WHERE e.DepartmentID = d.DepartmentID AND e.Salary > 70000);
    ```
*   **Output Result Set:** Returns 'IT' and 'Finance' because the subquery finds matching employees (1001 for IT, 1002 for Finance).
    ```
    +----------------+
    | DepartmentName |
    +----------------+
    | IT             |
    | Finance        |
    +----------------+
    ```
*   **Key Takeaway:** `EXISTS` checks if the subquery finds *any* matching rows based on the correlation (here, `e.DepartmentID = d.DepartmentID`). It's efficient for "is there at least one?" checks.

</details>

**i) `NOT EXISTS` Operator**

```sql
WHERE NOT EXISTS (SELECT 1 FROM HR.EMP_Details e WHERE e.DepartmentID = d.DepartmentID);
```

*   **Explanation:** The opposite of `EXISTS`. Returns `TRUE` if the subquery returns *no* rows, `FALSE` otherwise. Useful for finding rows that do *not* have corresponding related rows (e.g., departments with no employees).

<details>
<summary>Click to see Example Visualization (NOT EXISTS)</summary>

*   **Input Tables (`HR.Departments` d, `HR.EMP_Details` e - Conceptual):** (Same as EXISTS example)
    *   `HR.Departments`: (Includes Dept 4 'Marketing' with no employees)
    *   `HR.EMP_Details`: (No employees in Dept 4)

*   **Example Query:** Find departments that have *no* employees listed in `HR.EMP_Details`.
    ```sql
    SELECT d.DepartmentName
    FROM HR.Departments d
    WHERE NOT EXISTS (SELECT 1
                      FROM HR.EMP_Details e
                      WHERE e.DepartmentID = d.DepartmentID);
    ```
*   **Output Result Set:** Returns 'Marketing' because the subquery finds no employees with `DepartmentID = 4`.
    ```
    +----------------+
    | DepartmentName |
    +----------------+
    | Marketing      |
    +----------------+
    ```
*   **Key Takeaway:** `NOT EXISTS` is useful for finding records in one table that lack corresponding records in another related table.

</details>

**j) `ALL` Operator**

```sql
WHERE Salary > ALL (SELECT AVG(Salary) FROM HR.EMP_Details GROUP BY DepartmentID);
```

*   **Explanation:** Compares a value to *all* values returned by a subquery. Returns `TRUE` if the comparison is true for *every* value returned by the subquery (or if the subquery returns no rows). Here, it finds employees whose salary is greater than the average salary of *every single* department.

<details>
<summary>Click to see Example Visualization (ALL)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1000       | 2            | 60000  |
    | 1001       | 2            | 75000  |
    | 1002       | 3            | 90000  | <- Highest Salary
    | 1003       | 2            | 55000  |
    | 1004       | 1            | 62000  |
    | 1005       | 1            | 48000  |
    +------------+--------------+--------+
    ```
*   **Subquery Calculation (Conceptual):**
    *   Avg(Salary) Dept 1: (62000 + 48000) / 2 = 55000
    *   Avg(Salary) Dept 2: (60000 + 75000 + 55000) / 3 = 63333.33
    *   Avg(Salary) Dept 3: 90000 / 1 = 90000
    *   Subquery returns: (55000, 63333.33, 90000)
*   **Example Query:** `SELECT EmployeeID, Salary FROM HR.EMP_Details WHERE Salary > ALL (SELECT AVG(Salary) FROM HR.EMP_Details GROUP BY DepartmentID);`
*   **Output Result Set:** Checks which salaries are greater than *all* values (55000, 63333.33, 90000). No salary meets this condition.
    ```
    (No rows returned)
    ```
*   **Modified Example Query (Less Than ALL):** `SELECT EmployeeID, Salary FROM HR.EMP_Details WHERE Salary < ALL (SELECT AVG(Salary) FROM HR.EMP_Details GROUP BY DepartmentID);`
*   **Output (Less Than ALL):** Finds salaries less than the minimum average (55000).
    ```
    +------------+--------+
    | EmployeeID | Salary |
    +------------+--------+
    | 1005       | 48000  |
    +------------+--------+
    ```
*   **Key Takeaway:** `ALL` requires the comparison to hold true against *every* value returned by the subquery. Often used to find values greater than the maximum or less than the minimum of the subquery results.

</details>

**k) `ANY` / `SOME` Operator**

```sql
WHERE Salary > ANY (SELECT Salary FROM HR.EMP_Details WHERE DepartmentID = 1);
-- SOME is identical to ANY
```

*   **Explanation:** Compares a value to *any* value returned by a subquery. Returns `TRUE` if the comparison is true for *at least one* value returned by the subquery. Here, it finds employees whose salary is greater than *at least one* person's salary in department 1 (effectively, greater than the minimum salary in department 1).

<details>
<summary>Click to see Example Visualization (ANY/SOME)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1000       | 2            | 60000  | <- > 48000 (Match)
    | 1001       | 2            | 75000  | <- > 48000 (Match)
    | 1002       | 3            | 90000  | <- > 48000 (Match)
    | 1003       | 2            | 55000  | <- > 48000 (Match)
    | 1004       | 1            | 62000  | <- Dept 1 Salary
    | 1005       | 1            | 48000  | <- Dept 1 Salary (Min)
    +------------+--------------+--------+
    ```
*   **Subquery Calculation:** `SELECT Salary FROM HR.EMP_Details WHERE DepartmentID = 1` returns (62000, 48000).
*   **Example Query:** `SELECT EmployeeID, Salary FROM HR.EMP_Details WHERE Salary > ANY (SELECT Salary FROM HR.EMP_Details WHERE DepartmentID = 1);`
*   **Output Result Set:** Finds employees whose salary is greater than *at least one* of the Dept 1 salaries (i.e., > 48000).
    ```
    +------------+--------+
    | EmployeeID | Salary |
    +------------+--------+
    | 1000       | 60000  |
    | 1001       | 75000  |
    | 1002       | 90000  |
    | 1003       | 55000  |
    | 1004       | 62000  |
    +------------+--------+
    ```
*   **Key Takeaway:** `ANY` (or `SOME`) requires the comparison to hold true against *at least one* value returned by the subquery. `> ANY` is equivalent to `> MIN`, `< ANY` is equivalent to `< MAX`.

</details>

**l) Filtering with Scalar Subqueries**

```sql
WHERE DepartmentID = (SELECT DepartmentID FROM HR.Departments WHERE DepartmentName = 'Finance');
```

*   **Explanation:** Uses a subquery that is guaranteed (or expected) to return exactly one value (a scalar value). This value is then used in the comparison operator (`=`) of the outer query's `WHERE` clause. Fails if the subquery returns more than one row.

<details>
<summary>Click to see Example Visualization (Scalar Subquery)</summary>

*   **Input Tables (`HR.EMP_Details` e, `HR.Departments` d - Conceptual):**
    *   `HR.Departments`:
        ```
        +--------------+----------------+
        | DepartmentID | DepartmentName |
        +--------------+----------------+
        | 1            | HR             |
        | 2            | IT             |
        | 3            | Finance        |
        +--------------+----------------+
        ```
    *   `HR.EMP_Details`: (Relevant columns)
        ```
        +------------+--------------+
        | EmployeeID | DepartmentID |
        +------------+--------------+
        | 1000       | 2            |
        | 1001       | 2            |
        | 1002       | 3            | <- Match
        | 1003       | 2            |
        | 1004       | 1            |
        | 1005       | 1            |
        +------------+--------------+
        ```
*   **Subquery Calculation:** `SELECT DepartmentID FROM HR.Departments WHERE DepartmentName = 'Finance'` returns `3`.
*   **Example Query:** `SELECT EmployeeID FROM HR.EMP_Details WHERE DepartmentID = (SELECT DepartmentID FROM HR.Departments WHERE DepartmentName = 'Finance');`
*   **Output Result Set:** Finds employees where DepartmentID equals the result of the subquery (3).
    ```
    +------------+
    | EmployeeID |
    +------------+
    | 1002       |
    +------------+
    ```
*   **Key Takeaway:** Scalar subqueries allow you to use the single result of one query as part of a comparison in another query's `WHERE` clause. Ensure the subquery returns only one value.

</details>

**m) Filtering with `CASE`**

```sql
WHERE CASE WHEN DepartmentID = 1 THEN Salary > 60000 ... ELSE Salary > 50000 END;
```

*   **Explanation:** Allows applying different filtering logic based on conditions evaluated row by row. The `CASE` expression must evaluate to a boolean result (implicitly, by comparing the result to something, or by having the `THEN`/`ELSE` clauses return boolean-like values, though direct boolean return isn't standard SQL). Often clearer ways exist using `AND`/`OR`.

<details>
<summary>Click to see Example Visualization (CASE in WHERE)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1000       | 2            | 60000  | <- Dept=2, Salary<=60k (No Match)
    | 1001       | 2            | 75000  | <- Dept=2, Salary>60k (Match)
    | 1002       | 3            | 90000  | <- Other Dept, Salary>50k (Match)
    | 1003       | 2            | 55000  | <- Dept=2, Salary<=60k (No Match)
    | 1004       | 1            | 62000  | <- Other Dept, Salary>50k (Match)
    | 1005       | 1            | 48000  | <- Other Dept, Salary<=50k (No Match)
    +------------+--------------+--------+
    ```
*   **Example Query:** Find employees in Dept 2 earning > 60000, OR employees in other departments earning > 50000.
    ```sql
    SELECT EmployeeID, DepartmentID, Salary
    FROM HR.EMP_Details
    WHERE 1 = CASE
                  WHEN DepartmentID = 2 AND Salary > 60000 THEN 1 -- Match condition 1
                  WHEN DepartmentID <> 2 AND Salary > 50000 THEN 1 -- Match condition 2
                  ELSE 0 -- No match
              END;
    -- Note: Often clearer as: WHERE (DepartmentID = 2 AND Salary > 60000) OR (DepartmentID <> 2 AND Salary > 50000)
    ```
*   **Output Result Set:**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1001       | 2            | 75000  |
    | 1002       | 3            | 90000  |
    | 1004       | 1            | 62000  |
    +------------+--------------+--------+
    ```
*   **Key Takeaway:** While possible, using `CASE` directly in `WHERE` for complex boolean logic can be less readable than using standard `AND`/`OR` combinations.

</details>

**n) Date Filtering (Functions)**

```sql
WHERE YEAR(HireDate) = 2020;
WHERE DATEDIFF(YEAR, HireDate, GETDATE()) > 5;
```

*   **Explanation:** Uses date functions (`YEAR`, `MONTH`, `DAY`, `DATEDIFF`, `DATEADD`, etc.) within the `WHERE` clause to filter based on parts of dates or date calculations. *Caution:* Applying functions to a column in the `WHERE` clause (like `YEAR(HireDate)`) can often prevent the database from using an index on that column effectively (making it non-SARGable). It's often better to rewrite conditions to compare the raw column value against calculated boundaries (e.g., `WHERE HireDate >= '2020-01-01' AND HireDate < '2021-01-01'`).

<details>
<summary>Click to see Example Visualization (Date Functions)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+------------+
    | EmployeeID | HireDate   |
    +------------+------------+
    | 1000       | 2022-01-15 |
    | 1001       | 2021-03-10 |
    | 1002       | 2020-05-20 | <- YEAR = 2020 (Match)
    | 1003       | 2023-07-01 |
    | 1004       | 2022-11-30 |
    | 1005       | 2023-02-20 |
    +------------+------------+
    ```
*   **Example Query (YEAR):** `SELECT EmployeeID, HireDate FROM HR.EMP_Details WHERE YEAR(HireDate) = 2020;`
*   **Output (YEAR):**
    ```
    +------------+------------+
    | EmployeeID | HireDate   |
    +------------+------------+
    | 1002       | 2020-05-20 |
    +------------+------------+
    ```
*   **Example Query (DATEDIFF - assuming GETDATE() is 2025-03-29):** Find employees hired more than 3 years ago.
    `SELECT EmployeeID, HireDate FROM HR.EMP_Details WHERE DATEDIFF(YEAR, HireDate, GETDATE()) > 3;`
*   **Output (DATEDIFF):**
    ```
    +------------+------------+
    | EmployeeID | HireDate   |
    +------------+------------+
    | 1001       | 2021-03-10 |
    | 1002       | 2020-05-20 |
    +------------+------------+
    ```
*   **Key Takeaway:** Date functions allow filtering based on date components or calculations, but be mindful of potential performance impacts (non-SARGable predicates).

</details>

**o) String Filtering (Functions)**

```sql
WHERE LEN(LastName) > 6;
WHERE SUBSTRING(Email, 1, 1) = 'j';
```

*   **Explanation:** Uses string functions (`LEN`, `SUBSTRING`, `LEFT`, `RIGHT`, `CHARINDEX`, `PATINDEX`, etc.) to filter based on string properties or content. Similar SARGability concerns apply as with date functions. `LIKE` is generally preferred for pattern matching as it's often more index-friendly.

<details>
<summary>Click to see Example Visualization (String Functions)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+----------+--------------------+
    | EmployeeID | LastName | Email              |
    +------------+----------+--------------------+
    | 1000       | Smith    | alice.s@corp.com   | <- LEN(LastName)=5
    | 1001       | Jones    | bob.j@corp.com     | <- LEN(LastName)=5
    | 1002       | Brown    | charlie.b@corp.com | <- LEN(LastName)=5
    | 1003       | Green    | diana.g@corp.com   | <- LEN(LastName)=5
    | 1004       | White    | ethan.w@corp.com   | <- LEN(LastName)=5
    | 1005       | Blackwood| fiona.b@corp.com   | <- LEN(LastName)=9 (Match)
    +------------+----------+--------------------+
    ```
*   **Example Query (LEN):** `SELECT EmployeeID, LastName FROM HR.EMP_Details WHERE LEN(LastName) > 5;`
*   **Output (LEN):**
    ```
    +------------+-----------+
    | EmployeeID | LastName  |
    +------------+-----------+
    | 1005       | Blackwood |
    +------------+-----------+
    ```
*   **Example Query (SUBSTRING):** Find emails starting with 'b'.
    `SELECT EmployeeID, Email FROM HR.EMP_Details WHERE SUBSTRING(Email, 1, 1) = 'b';`
*   **Output (SUBSTRING):**
    ```
    +------------+------------------+
    | EmployeeID | Email            |
    +------------+------------------+
    | 1001       | bob.j@corp.com   |
    +------------+------------------+
    ```
*   **Key Takeaway:** String functions enable filtering based on length, parts of strings, etc., but consider performance (SARGability) and whether `LIKE` might be a better alternative for pattern matching.

</details>

## 3. Targeted Interview Questions (Based on `27_select_filtering.sql`)

**Question 1:** What is the difference between `WHERE Salary BETWEEN 40000 AND 60000` and `WHERE Salary >= 40000 AND Salary < 60000`?

**Solution 1:** `BETWEEN` is *inclusive* of both the start and end values. So, `WHERE Salary BETWEEN 40000 AND 60000` includes salaries that are exactly 40000 or exactly 60000. The second condition, `WHERE Salary >= 40000 AND Salary < 60000`, includes 40000 but *excludes* 60000 (it only includes salaries *less than* 60000).

**Question 2:** Explain the difference between the `ANY` (or `SOME`) and `ALL` operators when used with a comparison operator and a subquery (e.g., `> ANY (...)` vs `> ALL (...)`).

**Solution 2:**

*   `> ANY (...)`: Returns `TRUE` if the value is greater than *at least one* value returned by the subquery. This is equivalent to being greater than the *minimum* value returned by the subquery.
*   `> ALL (...)`: Returns `TRUE` if the value is greater than *every single* value returned by the subquery. This is equivalent to being greater than the *maximum* value returned by the subquery.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which wildcard character in `LIKE` matches exactly one character?
    *   **Answer:** Underscore (`_`).
2.  **[Easy]** How do you check if a column `EndDate` does *not* contain a NULL value?
    *   **Answer:** `WHERE EndDate IS NOT NULL;`
3.  **[Medium]** Is `WHERE ColumnA <> NULL` a reliable way to find rows where ColumnA is not NULL? Why or why not?
    *   **Answer:** No, it is not reliable. Comparisons with `NULL` using standard operators (`=`, `<>`) result in `UNKNOWN`, not `TRUE` or `FALSE`. Rows where `ColumnA` is NULL will evaluate to `UNKNOWN`, and rows where `ColumnA` is not NULL will also evaluate to `UNKNOWN`. The correct way is `WHERE ColumnA IS NOT NULL;`.
4.  **[Medium]** What is the difference in meaning between `WHERE DepartmentID IN (1, 2)` and `WHERE DepartmentID BETWEEN 1 AND 2`?
    *   **Answer:** `IN (1, 2)` matches rows where `DepartmentID` is *exactly* 1 or *exactly* 2. `BETWEEN 1 AND 2` matches rows where `DepartmentID` is greater than or equal to 1 AND less than or equal to 2. If `DepartmentID` is an integer, these happen to produce the same result. However, if the values were, say, `IN (1, 3)` vs `BETWEEN 1 AND 3`, the results would differ (`BETWEEN` would include 2, `IN` would not).
5.  **[Medium]** Can the `LIKE` operator be used effectively with indexes? When might it be less effective?
    *   **Answer:** Yes, `LIKE` can use an index effectively, *provided the wildcard character (%) is not at the beginning* of the pattern. For example, `WHERE LastName LIKE 'S%'` can use an index on `LastName` to quickly find matching rows (index seek). However, `WHERE LastName LIKE '%S'` or `WHERE LastName LIKE '%S%'` (wildcard at the beginning) usually forces an index scan or table scan because the starting point for the search is unknown, making it much less effective.
6.  **[Medium]** What is a "SARGable" query or predicate? Why is it important for performance?
    *   **Answer:** A SARGable predicate (Search ARGument-able) is a condition in a `WHERE` clause that allows the SQL Server query optimizer to use an index seek operation to efficiently locate matching rows. Predicates are generally SARGable when the column being filtered is isolated on one side of the operator and is not wrapped in a function. For example, `WHERE Salary > 50000` is SARGable. `WHERE YEAR(HireDate) = 2020` is generally *not* SARGable because the function `YEAR()` is applied to the column. Non-SARGable predicates often force index scans or table scans, which are much slower on large tables.
7.  **[Hard]** When might you prefer using `EXISTS` over `IN` with a subquery for filtering?
    *   **Answer:** `EXISTS` is often preferred over `IN` when:
        *   You only need to check for the *presence* of at least one matching row in the subquery, not the specific values. `EXISTS` can stop as soon as it finds the first match.
        *   The subquery might return a very large number of rows. `IN` might require materializing and searching this large list, while `EXISTS` doesn't.
        *   The subquery is correlated (references the outer query). `EXISTS` is naturally suited for correlated checks.
        *   You want to check for `NULL`s in the subquery's result (though `IN` behavior with `NULL`s can be complex, `EXISTS` simply checks for row existence).
8.  **[Hard]** Can a scalar subquery used in a `WHERE` clause (like `WHERE ColumnA = (SELECT MAX(Value) FROM OtherTable)`) return `NULL`? What happens to the comparison if it does?
    *   **Answer:** Yes, the scalar subquery can return `NULL` (e.g., if `OtherTable` is empty or `MAX(Value)` results in `NULL`). If the subquery returns `NULL`, any standard comparison (`=`, `>`, `<`, `<>`, etc.) against that `NULL` will result in `UNKNOWN`. Rows where the comparison evaluates to `UNKNOWN` are *not* included in the result set (unless specifically handled, which is rare in basic comparisons). So, `WHERE ColumnA = (SELECT ...)` would return no rows if the subquery result is `NULL`.
9.  **[Hard]** How does the database's collation setting potentially affect string comparisons in the `WHERE` clause (e.g., case sensitivity, accent sensitivity)?
    *   **Answer:** Collation defines the rules for sorting and comparing character data. It determines:
        *   **Case Sensitivity:** A case-sensitive collation (e.g., `SQL_Latin1_General_CP1_CS_AS`) treats 'a' and 'A' as different characters. A case-insensitive collation (e.g., `SQL_Latin1_General_CP1_CI_AS` - common default) treats them as the same. `WHERE LastName = 'Smith'` would match 'SMITH' only in a case-insensitive collation.
        *   **Accent Sensitivity:** An accent-sensitive collation (`_AS`) treats 'e' and 'é' as different. An accent-insensitive collation (`_AI`) treats them as the same.
        *   Other properties like Kana sensitivity (Japanese) and Width sensitivity (full-width vs half-width characters) are also controlled by collation. Inconsistent collations between compared columns or between a column and a literal value can cause unexpected comparison results or errors.
10. **[Hard/Tricky]** You have a condition `WHERE IsActive = 1 OR LastModifiedDate > '2023-01-01'`. If the table has a non-clustered index on `IsActive` and another on `LastModifiedDate`, can SQL Server efficiently use *both* indexes to satisfy this `OR` condition? What strategies might it use?
    *   **Answer:** Directly using both indexes efficiently for a simple `OR` condition can be challenging for the optimizer. Common strategies SQL Server *might* employ include:
        1.  **Index Scan/Table Scan:** If one condition is much less selective or if indexes aren't suitable, it might scan one index (or the whole table) and evaluate both conditions.
        2.  **Index Seek on One + Key Lookup:** Seek using the more selective index (e.g., `IsActive = 1` if few rows are active) and then check the second condition (`LastModifiedDate > ...`) for the retrieved rows (potentially via key lookups if needed columns aren't in the index).
        3.  **Index Union (Less Common):** In some cases, the optimizer might perform seeks on *both* indexes independently and then merge (union) the results, removing duplicates. This is often complex and less common than seeks on `AND` predicates.
        4.  **Rewriting the Query:** Sometimes rewriting the query using `UNION ALL` can help the optimizer use separate indexes more effectively, although it adds complexity:
            ```sql
            SELECT ... WHERE IsActive = 1
            UNION ALL
            SELECT ... WHERE LastModifiedDate > '2023-01-01' AND (IsActive <> 1 OR IsActive IS NULL) -- Avoid duplicates
            ```
        The actual plan depends heavily on statistics, index definitions, and optimizer choices.
