# SQL Deep Dive: Combining Data with `JOIN`

## 1. Introduction: Why Use `JOIN`?

Relational databases store data in multiple related tables to reduce redundancy and improve data integrity (normalization). However, to get meaningful information, you often need to combine data from these related tables. The `JOIN` clause in a `SELECT` statement is the primary mechanism for achieving this. It allows you to link rows from two or more tables based on related columns.

**Key Concepts:**

*   **Join Condition:** The rule (specified in the `ON` clause) used to match rows between tables, typically based on equality between a primary key in one table and a foreign key in another (e.g., `Employees.DepartmentID = Departments.DepartmentID`).
*   **Join Types:** Different types of joins (`INNER`, `LEFT`, `RIGHT`, `FULL`, `CROSS`) determine which rows are included in the final result set based on whether matches are found according to the join condition.

## 2. `JOIN` Types in Action: Analysis of `29_select_joins.sql`

This script demonstrates the most common types of joins.

**a) `INNER JOIN`**

```sql
SELECT e.EmployeeID, ..., d.DepartmentName
FROM HR.EMP_Details e
INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID;
```

*   **Explanation:** Returns only rows where there is a match in **both** tables based on the `ON` condition. If an employee's `DepartmentID` doesn't exist in the `Departments` table, or if a department has no employees, those rows are excluded from the result. This is the most common join type.

<details>
<summary>Click to see Example Visualization (INNER JOIN)</summary>

*   **Input Tables (Conceptual Snippets):**
    *   `HR.EMP_Details` (e):
        ```
        +------------+--------------+-----------+
        | EmployeeID | DepartmentID | FirstName |
        +------------+--------------+-----------+
        | 1000       | 2            | Alice     |
        | 1001       | 2            | Bob       |
        | 1002       | 3            | Charlie   |
        | 1003       | 2            | Diana     |
        | 1004       | 1            | Ethan     |
        | 1006       | NULL         | Grace     | <- No DeptID match
        +------------+--------------+-----------+
        ```
    *   `HR.Departments` (d):
        ```
        +--------------+----------------+
        | DepartmentID | DepartmentName |
        +--------------+----------------+
        | 1            | HR             |
        | 2            | IT             |
        | 3            | Finance        |
        | 4            | Marketing      | <- No Employee match
        +--------------+----------------+
        ```
*   **Example Query:**
    ```sql
    SELECT e.EmployeeID, e.FirstName, d.DepartmentName
    FROM HR.EMP_Details e
    INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID;
    ```
*   **Output Result Set:** Only rows with matching `DepartmentID` in both tables are returned. Grace (NULL DeptID) and Marketing (no employees) are excluded.
    ```
    +------------+-----------+----------------+
    | EmployeeID | FirstName | DepartmentName |
    +------------+-----------+----------------+
    | 1004       | Ethan     | HR             |
    | 1000       | Alice     | IT             |
    | 1001       | Bob       | IT             |
    | 1003       | Diana     | IT             |
    | 1002       | Charlie   | Finance        |
    +------------+-----------+----------------+
    ```
*   **Key Takeaway:** `INNER JOIN` requires a match in both tables based on the `ON` condition.

</details>

**b) `LEFT JOIN` (or `LEFT OUTER JOIN`)**

```sql
SELECT e.EmployeeID, ..., d.DepartmentName
FROM HR.EMP_Details e -- Left Table
LEFT JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID; -- Right Table
```

*   **Explanation:** Returns **all rows** from the **left** table (`HR.EMP_Details`) and the matching rows from the **right** table (`HR.Departments`). If there is no match in the right table for a row from the left table (e.g., an employee with no assigned department), the columns selected from the right table (`d.DepartmentName`) will contain `NULL` for that row.

<details>
<summary>Click to see Example Visualization (LEFT JOIN)</summary>

*   **Input Tables (Conceptual Snippets):** (Same as INNER JOIN example)
    *   `HR.EMP_Details` (e - Left Table): (Includes Grace with NULL DeptID)
    *   `HR.Departments` (d - Right Table): (Includes Marketing with no employees)

*   **Example Query:**
    ```sql
    SELECT e.EmployeeID, e.FirstName, d.DepartmentName
    FROM HR.EMP_Details e -- Left Table
    LEFT JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID; -- Right Table
    ```
*   **Output Result Set:** All employees (left table) are included. Grace, who has no matching department, has `NULL` for `DepartmentName`. The Marketing department is still excluded as it has no corresponding employee row to start from on the left.
    ```
    +------------+-----------+----------------+
    | EmployeeID | FirstName | DepartmentName |
    +------------+-----------+----------------+
    | 1004       | Ethan     | HR             |
    | 1000       | Alice     | IT             |
    | 1001       | Bob       | IT             |
    | 1003       | Diana     | IT             |
    | 1002       | Charlie   | Finance        |
    | 1006       | Grace     | NULL           | <- Grace included, Dept is NULL
    +------------+-----------+----------------+
    ```
*   **Key Takeaway:** `LEFT JOIN` keeps all rows from the left table, filling in `NULL`s for columns from the right table where no match is found.

</details>

**c) `RIGHT JOIN` (or `RIGHT OUTER JOIN`)**

```sql
SELECT e.EmployeeID, ..., d.DepartmentName
FROM HR.EMP_Details e -- Left Table
RIGHT JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID; -- Right Table
```

*   **Explanation:** Returns **all rows** from the **right** table (`HR.Departments`) and the matching rows from the **left** table (`HR.EMP_Details`). If there is no match in the left table for a row from the right table (e.g., a department with no employees), the columns selected from the left table (`e.EmployeeID`, etc.) will contain `NULL` for that row.

<details>
<summary>Click to see Example Visualization (RIGHT JOIN)</summary>

*   **Input Tables (Conceptual Snippets):** (Same as INNER JOIN example)
    *   `HR.EMP_Details` (e - Left Table): (Includes Grace with NULL DeptID)
    *   `HR.Departments` (d - Right Table): (Includes Marketing with no employees)

*   **Example Query:**
    ```sql
    SELECT e.EmployeeID, e.FirstName, d.DepartmentName
    FROM HR.EMP_Details e -- Left Table
    RIGHT JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID; -- Right Table
    ```
*   **Output Result Set:** All departments (right table) are included. Marketing, which has no matching employees, has `NULL` for `EmployeeID` and `FirstName`. Grace (NULL DeptID) is excluded as she doesn't match any department on the right.
    ```
    +------------+-----------+----------------+
    | EmployeeID | FirstName | DepartmentName |
    +------------+-----------+----------------+
    | 1004       | Ethan     | HR             |
    | 1000       | Alice     | IT             |
    | 1001       | Bob       | IT             |
    | 1003       | Diana     | IT             |
    | 1002       | Charlie   | Finance        |
    | NULL       | NULL      | Marketing      | <- Marketing included, Emp is NULL
    +------------+-----------+----------------+
    ```
*   **Key Takeaway:** `RIGHT JOIN` keeps all rows from the right table, filling in `NULL`s for columns from the left table where no match is found.

</details>

**d) `FULL JOIN` (or `FULL OUTER JOIN`)**

```sql
SELECT e.EmployeeID, ..., d.DepartmentName
FROM HR.EMP_Details e
FULL JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID;
```

*   **Explanation:** Returns **all rows** from **both** the left and right tables.
    *   If a match exists, columns from both tables are populated.
    *   If a row from the left table has no match in the right, columns from the right table are `NULL`.
    *   If a row from the right table has no match in the left, columns from the left table are `NULL`.

<details>
<summary>Click to see Example Visualization (FULL JOIN)</summary>

*   **Input Tables (Conceptual Snippets):** (Same as INNER JOIN example)
    *   `HR.EMP_Details` (e): (Includes Grace with NULL DeptID)
    *   `HR.Departments` (d): (Includes Marketing with no employees)

*   **Example Query:**
    ```sql
    SELECT e.EmployeeID, e.FirstName, d.DepartmentName
    FROM HR.EMP_Details e
    FULL JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID;
    ```
*   **Output Result Set:** Includes all employees AND all departments. Grace (no matching dept) has NULL `DepartmentName`. Marketing (no matching emp) has NULL `EmployeeID`/`FirstName`.
    ```
    +------------+-----------+----------------+
    | EmployeeID | FirstName | DepartmentName |
    +------------+-----------+----------------+
    | 1004       | Ethan     | HR             |
    | 1000       | Alice     | IT             |
    | 1001       | Bob       | IT             |
    | 1003       | Diana     | IT             |
    | 1002       | Charlie   | Finance        |
    | 1006       | Grace     | NULL           | <- Grace included
    | NULL       | NULL      | Marketing      | <- Marketing included
    +------------+-----------+----------------+
    ```
*   **Key Takeaway:** `FULL JOIN` combines the results of a `LEFT JOIN` and a `RIGHT JOIN`, ensuring all rows from both tables appear, with `NULL`s where matches don't exist.

</details>

**e) `CROSS JOIN`**

```sql
SELECT e.FirstName, ..., s.SkillName
FROM HR.EMP_Details e
CROSS JOIN HR.Skills s; -- No ON clause
```

*   **Explanation:** Returns the **Cartesian product** of the two tables – every row from the first table is combined with every row from the second table. No `ON` clause is used. If table A has M rows and table B has N rows, the result has M * N rows. Use with caution, as it can produce very large result sets. Useful for generating all possible combinations.

<details>
<summary>Click to see Example Visualization (CROSS JOIN)</summary>

*   **Input Tables (Conceptual Snippets):**
    *   `HR.EMP_Details` (e): (2 rows for simplicity)
        ```
        +-----------+
        | FirstName |
        +-----------+
        | Alice     |
        | Bob       |
        +-----------+
        ```
    *   `HR.Skills` (s): (3 rows for simplicity)
        ```
        +-----------+
        | SkillName |
        +-----------+
        | SQL       |
        | Python    |
        | Java      |
        +-----------+
        ```
*   **Example Query:**
    ```sql
    SELECT e.FirstName, s.SkillName
    FROM HR.EMP_Details e
    CROSS JOIN HR.Skills s;
    ```
*   **Output Result Set:** Every employee is paired with every skill (2 employees * 3 skills = 6 rows).
    ```
    +-----------+-----------+
    | FirstName | SkillName |
    +-----------+-----------+
    | Alice     | SQL       |
    | Alice     | Python    |
    | Alice     | Java      |
    | Bob       | SQL       |
    | Bob       | Python    |
    | Bob       | Java      |
    +-----------+-----------+
    ```
*   **Key Takeaway:** `CROSS JOIN` generates all possible combinations of rows from the joined tables. Be very careful as results can grow extremely large.

</details>

**f) Self Join**

```sql
SELECT e.EmployeeID, ..., m.FirstName + ' ' + m.LastName AS Manager
FROM HR.EMP_Details e -- Alias for employee
LEFT JOIN HR.EMP_Details m ON e.ManagerID = m.EmployeeID; -- Alias for manager (same table)
```

*   **Explanation:** Joins a table to itself by using different aliases (`e` for employee, `m` for manager). This is common for querying hierarchical data stored within a single table (like an employee-manager relationship where `ManagerID` refers back to `EmployeeID`). A `LEFT JOIN` is often used to include rows that have no match (e.g., the CEO who has no manager).

<details>
<summary>Click to see Example Visualization (Self Join)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+-----------+-----------+
    | EmployeeID | FirstName | ManagerID |
    +------------+-----------+-----------+
    | 1000       | Alice     | 1002      |
    | 1001       | Bob       | 1002      |
    | 1002       | Charlie   | NULL      | <- Top level
    | 1003       | Diana     | 1001      |
    +------------+-----------+-----------+
    ```
*   **Example Query:**
    ```sql
    SELECT e.FirstName AS EmployeeName, m.FirstName AS ManagerName
    FROM HR.EMP_Details e -- Alias for employee
    LEFT JOIN HR.EMP_Details m ON e.ManagerID = m.EmployeeID; -- Alias for manager
    ```
*   **Output Result Set:** Shows each employee and their manager's name by joining the table to itself. Charlie (no manager) has NULL for ManagerName due to the `LEFT JOIN`.
    ```
    +--------------+-------------+
    | EmployeeName | ManagerName |
    +--------------+-------------+
    | Alice        | Charlie     |
    | Bob          | Charlie     |
    | Charlie      | NULL        |
    | Diana        | Bob         |
    +--------------+-------------+
    ```
*   **Key Takeaway:** A self join uses different aliases for the same table to relate rows within that table based on a relationship column (like `ManagerID` referencing `EmployeeID`).

</details>

**g) Multi-Table Joins**

```sql
SELECT e.EmployeeID, ..., d.DepartmentName, l.LocationName, p.ProjectName
FROM HR.EMP_Details e
INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID -- Join 1
INNER JOIN HR.Locations l ON d.LocationID = l.LocationID     -- Join 2
LEFT JOIN HR.EmployeeProjects ep ON e.EmployeeID = ep.EmployeeID -- Join 3 (Optional)
LEFT JOIN HR.Projects p ON ep.ProjectID = p.ProjectID;        -- Join 4 (Optional)
```

*   **Explanation:** You can chain multiple `JOIN` clauses together to combine data from three or more tables. The type of join (`INNER`, `LEFT`, etc.) can be chosen independently for each link in the chain based on whether the relationship is required or optional.

<details>
<summary>Click to see Example Visualization (Multi-Table Joins)</summary>

*   **Input Tables (Conceptual Snippets):**
    *   `HR.EMP_Details` (e): `(1000, 'Alice', 2)`
    *   `HR.Departments` (d): `(2, 'IT', 20)`
    *   `HR.Locations` (l): `(20, 'London')`
    *   `HR.EmployeeProjects` (ep): `(1000, 50)`
    *   `HR.Projects` (p): `(50, 'Migration')`
*   **Example Query (Simplified):**
    ```sql
    SELECT e.FirstName, d.DepartmentName, l.City, p.ProjectName
    FROM HR.EMP_Details e
    INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    INNER JOIN HR.Locations l ON d.LocationID = l.LocationID
    LEFT JOIN HR.EmployeeProjects ep ON e.EmployeeID = ep.EmployeeID
    LEFT JOIN HR.Projects p ON ep.ProjectID = p.ProjectID
    WHERE e.EmployeeID = 1000;
    ```
*   **Output Result Set:** Combines data across multiple tables based on the chained join conditions.
    ```
    +-----------+----------------+--------+-------------+
    | FirstName | DepartmentName | City   | ProjectName |
    +-----------+----------------+--------+-------------+
    | Alice     | IT             | London | Migration   |
    +-----------+----------------+--------+-------------+
    ```
*   **Key Takeaway:** Chain `JOIN` clauses sequentially, linking each new table to one already included in the `FROM` or preceding `JOIN`s using an appropriate `ON` condition.

</details>

**h) Non-Equi Joins**

```sql
SELECT e1.EmployeeID, ..., e2.EmployeeID AS HigherPaidID, ...
FROM HR.EMP_Details e1
INNER JOIN HR.EMP_Details e2 ON e1.Salary < e2.Salary -- Join condition uses '<'
                           AND e1.DepartmentID = e2.DepartmentID; -- Additional condition
```

*   **Explanation:** The join condition in the `ON` clause doesn't have to be based solely on equality (`=`). You can use other comparison operators (`<`, `>`, `<=`, `>=`, `!=`) or even more complex expressions. This example finds pairs of employees within the same department where one earns less than the other.

<details>
<summary>Click to see Example Visualization (Non-Equi Joins)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1000       | 2            | 60000  |
    | 1001       | 2            | 75000  |
    | 1003       | 2            | 55000  |
    | 1004       | 1            | 62000  |
    | 1005       | 1            | 48000  |
    +------------+--------------+--------+
    ```
*   **Example Query:** Find pairs where e1 earns less than e2 in the same department.
    ```sql
    SELECT e1.EmployeeID AS LowerPaidID, e1.Salary AS LowerSalary,
           e2.EmployeeID AS HigherPaidID, e2.Salary AS HigherSalary
    FROM HR.EMP_Details e1
    INNER JOIN HR.EMP_Details e2 ON e1.DepartmentID = e2.DepartmentID -- Same Dept
                                AND e1.Salary < e2.Salary; -- e1 earns less
    ```
*   **Output Result Set:** Shows pairs of employees satisfying the non-equi join condition.
    ```
    +-------------+-------------+--------------+--------------+
    | LowerPaidID | LowerSalary | HigherPaidID | HigherSalary |
    +-------------+-------------+--------------+--------------+
    | 1005        | 48000       | 1004         | 62000        | -- Dept 1 pair
    | 1000        | 60000       | 1001         | 75000        | -- Dept 2 pair
    | 1003        | 55000       | 1000         | 60000        | -- Dept 2 pair
    | 1003        | 55000       | 1001         | 75000        | -- Dept 2 pair
    +-------------+-------------+--------------+--------------+
    ```
*   **Key Takeaway:** The `ON` clause can use operators other than `=`, allowing joins based on ranges or other inequality conditions.

</details>

**i) Joining with Subqueries (Derived Tables)**

```sql
SELECT e.EmployeeID, ..., d.AvgSalary, e.Salary - d.AvgSalary AS Difference
FROM HR.EMP_Details e
INNER JOIN ( -- Subquery treated as a temporary table
    SELECT DepartmentID, AVG(Salary) AS AvgSalary
    FROM HR.EMP_Details GROUP BY DepartmentID
) d ON e.DepartmentID = d.DepartmentID; -- Join main table to subquery result
```

*   **Explanation:** You can join a table to the result set of a subquery (often called a derived table). The subquery must be given an alias (`d` in this case). This is useful for joining against aggregated data or pre-filtered/transformed data.

<details>
<summary>Click to see Example Visualization (Joining Derived Tables)</summary>

*   **Input Table (`HR.EMP_Details` e - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1000       | 2            | 60000  |
    | 1001       | 2            | 75000  |
    | 1002       | 3            | 90000  |
    | 1003       | 2            | 55000  |
    | 1004       | 1            | 62000  |
    | 1005       | 1            | 48000  |
    +------------+--------------+--------+
    ```
*   **Subquery Result (Conceptual - `d`):**
    ```
    +--------------+-----------+
    | DepartmentID | AvgSalary |
    +--------------+-----------+
    | 1            | 55000.00  |
    | 2            | 63333.33  |
    | 3            | 90000.00  |
    +--------------+-----------+
    ```
*   **Example Query:**
    ```sql
    SELECT e.EmployeeID, e.Salary, d.AvgSalary, e.Salary - d.AvgSalary AS Difference
    FROM HR.EMP_Details e
    INNER JOIN (
        SELECT DepartmentID, AVG(Salary) AS AvgSalary
        FROM HR.EMP_Details GROUP BY DepartmentID
    ) d ON e.DepartmentID = d.DepartmentID;
    ```
*   **Output Result Set:** Joins each employee to the average salary calculated for their department via the subquery.
    ```
    +------------+--------+-----------+------------+
    | EmployeeID | Salary | AvgSalary | Difference |
    +------------+--------+-----------+------------+
    | 1004       | 62000  | 55000.00  | 7000.00    |
    | 1005       | 48000  | 55000.00  | -7000.00   |
    | 1000       | 60000  | 63333.33  | -3333.33   |
    | 1001       | 75000  | 63333.33  | 11666.67   |
    | 1003       | 55000  | 63333.33  | -8333.33   |
    | 1002       | 90000  | 90000.00  | 0.00       |
    +------------+--------+-----------+------------+
    ```
*   **Key Takeaway:** Joining to a subquery (derived table) allows you to combine detail rows with aggregated or pre-processed data calculated in the subquery.

</details>

**j) Filtered Joins (`WHERE` after `JOIN`)**

```sql
SELECT e.EmployeeID, ..., d.DepartmentName
FROM HR.EMP_Details e
INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.Salary > 50000 AND d.DepartmentName LIKE 'F%'; -- Filter applied AFTER join
```

*   **Explanation:** The `WHERE` clause is applied *after* the join operation has combined the rows. It filters the rows from the combined result set based on conditions involving columns from any of the joined tables.

<details>
<summary>Click to see Example Visualization (Filtered Joins)</summary>

*   **Input Tables (Conceptual Snippets):**
    *   `HR.EMP_Details` (e):
        ```
        +------------+--------------+--------+
        | EmployeeID | DepartmentID | Salary |
        +------------+--------------+--------+
        | 1000       | 2            | 60000  | <- Salary > 50k
        | 1001       | 2            | 75000  | <- Salary > 50k
        | 1002       | 3            | 90000  | <- Salary > 50k
        | 1003       | 2            | 45000  | <- Salary <= 50k
        | 1004       | 1            | 62000  | <- Salary > 50k
        +------------+--------------+--------+
        ```
    *   `HR.Departments` (d):
        ```
        +--------------+----------------+
        | DepartmentID | DepartmentName |
        +--------------+----------------+
        | 1            | HR             |
        | 2            | IT             |
        | 3            | Finance        | <- Name starts 'F'
        +--------------+----------------+
        ```
*   **Conceptual Joined Result (Before WHERE):**
    ```
    +------------+--------+----------------+
    | EmployeeID | Salary | DepartmentName |
    +------------+--------+----------------+
    | 1004       | 62000  | HR             |
    | 1000       | 60000  | IT             |
    | 1001       | 75000  | IT             |
    | 1003       | 45000  | IT             |
    | 1002       | 90000  | Finance        |
    +------------+--------+----------------+
    ```
*   **Example Query:**
    ```sql
    SELECT e.EmployeeID, e.Salary, d.DepartmentName
    FROM HR.EMP_Details e
    INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    WHERE e.Salary > 50000 AND d.DepartmentName LIKE 'F%';
    ```
*   **Output Result Set:** Filters the joined result, keeping only rows where Salary > 50k AND DepartmentName starts with 'F'.
    ```
    +------------+--------+----------------+
    | EmployeeID | Salary | DepartmentName |
    +------------+--------+----------------+
    | 1002       | 90000  | Finance        |
    +------------+--------+----------------+
    ```
*   **Key Takeaway:** `WHERE` clauses filter the results *after* the `JOIN` operations are logically completed.

</details>

**k) Finding Unmatched Records (using `LEFT JOIN`/`IS NULL`)**

```sql
SELECT d.DepartmentID, d.DepartmentName
FROM HR.Departments d
LEFT JOIN HR.EMP_Details e ON d.DepartmentID = e.DepartmentID
WHERE e.EmployeeID IS NULL; -- Filter for rows where the RIGHT table had no match
```

*   **Explanation:** A common pattern to find rows in one table that do *not* have a corresponding match in another table. Perform a `LEFT JOIN` from the table where you want to find unmatched rows (e.g., `Departments`) to the other table (`EMP_Details`). Then, use `WHERE` to filter for rows where a non-nullable column (often the primary key) from the *right* table (`e.EmployeeID`) `IS NULL`. This indicates no match was found during the join.

<details>
<summary>Click to see Example Visualization (Finding Unmatched - LEFT JOIN/IS NULL)</summary>

*   **Input Tables (Conceptual Snippets):** (Same as INNER JOIN example)
    *   `HR.Departments` (d - Left Table): (Includes Marketing with no employees)
    *   `HR.EMP_Details` (e - Right Table): (No employees in Dept 4)

*   **Conceptual LEFT JOIN Result (Before WHERE):**
    ```
    +--------------+----------------+------------+
    | DepartmentID | DepartmentName | EmployeeID |
    +--------------+----------------+------------+
    | 1            | HR             | 1004       |
    | 2            | IT             | 1000       |
    | 2            | IT             | 1001       |
    | 2            | IT             | 1003       |
    | 3            | Finance        | 1002       |
    | 4            | Marketing      | NULL       | <- No match in EMP_Details
    +--------------+----------------+------------+
    ```
*   **Example Query:** Find departments with no employees.
    ```sql
    SELECT d.DepartmentID, d.DepartmentName
    FROM HR.Departments d
    LEFT JOIN HR.EMP_Details e ON d.DepartmentID = e.DepartmentID
    WHERE e.EmployeeID IS NULL; -- Filter where the right side was NULL
    ```
*   **Output Result Set:** Only the 'Marketing' department remains after filtering for `e.EmployeeID IS NULL`.
    ```
    +--------------+----------------+
    | DepartmentID | DepartmentName |
    +--------------+----------------+
    | 4            | Marketing      |
    +--------------+----------------+
    ```
*   **Key Takeaway:** The `LEFT JOIN` + `WHERE right_table.column IS NULL` pattern is standard for finding rows in the left table without matches in the right table.

</details>

**l) `APPLY` Operator (`CROSS APPLY`, `OUTER APPLY`)**

```sql
-- CROSS APPLY: Like INNER JOIN for table-valued functions/subqueries
SELECT d.DepartmentID, ..., e.EmployeeID, ...
FROM HR.Departments d
CROSS APPLY (SELECT TOP 3 * FROM HR.EMP_Details WHERE DepartmentID = d.DepartmentID ORDER BY Salary DESC) e;

-- OUTER APPLY: Like LEFT JOIN for table-valued functions/subqueries
SELECT d.DepartmentID, ..., e.EmployeeID, ...
FROM HR.Departments d
OUTER APPLY (SELECT TOP 3 * FROM HR.EMP_Details WHERE DepartmentID = d.DepartmentID ORDER BY Salary DESC) e;
```

*   **Explanation:** `APPLY` is used to invoke a table-valued function or execute a correlated subquery for *each row* from the outer table reference.
    *   `CROSS APPLY`: Returns only rows from the outer table where the right-side table expression (function/subquery) returns *at least one row*. Similar in effect to an `INNER JOIN`.
    *   `OUTER APPLY`: Returns **all rows** from the outer table. If the right-side table expression returns rows, they are joined. If it returns *no rows* for a given outer row, columns from the right side will be `NULL` (similar to `LEFT JOIN`).
*   `APPLY` is particularly useful when the right side depends on values from the outer table row (correlation), which is harder or impossible to express with standard `JOIN` syntax, especially with functions or `TOP N` per group scenarios.

<details>
<summary>Click to see Example Visualization (APPLY)</summary>

*   **Input Tables (Conceptual Snippets):**
    *   `HR.Departments` (d):
        ```
        +--------------+----------------+
        | DepartmentID | DepartmentName |
        +--------------+----------------+
        | 1            | HR             |
        | 2            | IT             |
        | 3            | Finance        |
        | 4            | Marketing      | <- No employees
        +--------------+----------------+
        ```
    *   `HR.EMP_Details` (e): (Relevant columns, assume salaries allow ranking)
        ```
        +------------+--------------+--------+
        | EmployeeID | DepartmentID | Salary |
        +------------+--------------+--------+
        | 1004       | 1            | 62000  |
        | 1005       | 1            | 48000  |
        | 1000       | 2            | 60000  |
        | 1001       | 2            | 75000  |
        | 1003       | 2            | 55000  |
        | 1002       | 3            | 90000  |
        | 1007       | 3            | 85000  |
        | 1008       | 3            | 80000  |
        | 1009       | 3            | 70000  |
        +------------+--------------+--------+
        ```
*   **Example Query (CROSS APPLY - Top 2 per Dept):**
    ```sql
    SELECT d.DepartmentName, e.EmployeeID, e.Salary
    FROM HR.Departments d
    CROSS APPLY (SELECT TOP 2 EmployeeID, Salary
                 FROM HR.EMP_Details
                 WHERE DepartmentID = d.DepartmentID -- Correlated
                 ORDER BY Salary DESC) e;
    ```
*   **Output (CROSS APPLY):** Shows top 2 earners for departments that *have* employees. Marketing (Dept 4) is excluded.
    ```
    +----------------+------------+--------+
    | DepartmentName | EmployeeID | Salary |
    +----------------+------------+--------+
    | HR             | 1004       | 62000  |
    | HR             | 1005       | 48000  |
    | IT             | 1001       | 75000  |
    | IT             | 1000       | 60000  |
    | Finance        | 1002       | 90000  |
    | Finance        | 1007       | 85000  |
    +----------------+------------+--------+
    ```
*   **Example Query (OUTER APPLY - Top 2 per Dept):**
    ```sql
    SELECT d.DepartmentName, e.EmployeeID, e.Salary
    FROM HR.Departments d
    OUTER APPLY (SELECT TOP 2 EmployeeID, Salary
                 FROM HR.EMP_Details
                 WHERE DepartmentID = d.DepartmentID -- Correlated
                 ORDER BY Salary DESC) e;
    ```
*   **Output (OUTER APPLY):** Shows top 2 earners, but also includes Marketing with NULLs for employee details because `OUTER APPLY` keeps all rows from the left side (Departments).
    ```
    +----------------+------------+--------+
    | DepartmentName | EmployeeID | Salary |
    +----------------+------------+--------+
    | HR             | 1004       | 62000  |
    | HR             | 1005       | 48000  |
    | IT             | 1001       | 75000  |
    | IT             | 1000       | 60000  |
    | Finance        | 1002       | 90000  |
    | Finance        | 1007       | 85000  |
    | Marketing      | NULL       | NULL   | <- Marketing included
    +----------------+------------+--------+
    ```
*   **Key Takeaway:** `APPLY` allows joining with the results of a function or correlated subquery executed for each outer row. `CROSS APPLY` acts like `INNER JOIN`, `OUTER APPLY` acts like `LEFT JOIN`. Essential for "Top N per group" scenarios.

</details>

## 3. Targeted Interview Questions (Based on `29_select_joins.sql`)

**Question 1:** What is the fundamental difference between an `INNER JOIN` and a `LEFT JOIN`?

**Solution 1:** An `INNER JOIN` returns only rows where the join condition is met in *both* tables being joined. A `LEFT JOIN` returns *all* rows from the *left* table, and only the matching rows from the *right* table; if no match is found in the right table, columns from the right table will have `NULL` values for that row.

**Question 2:** Look at the "Self Join" example (section 6). Why is a `LEFT JOIN` used instead of an `INNER JOIN` to find the manager's name? What would happen if `INNER JOIN` was used?

**Solution 2:** A `LEFT JOIN` is used to ensure that *all* employees are included in the result set, even those who do not have a manager (`ManagerID IS NULL`). For these top-level employees, the join condition `e.ManagerID = m.EmployeeID` will not find a match in the `m` alias, and the `Manager` column will correctly show `NULL`. If an `INNER JOIN` were used, only employees who *do* have a valid `ManagerID` that matches another `EmployeeID` would be returned; employees without a manager would be excluded from the result.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What clause specifies the condition used to link tables in a `JOIN`?
    *   **Answer:** The `ON` clause.
2.  **[Easy]** Which join type returns all possible combinations of rows between two tables?
    *   **Answer:** `CROSS JOIN`.
3.  **[Medium]** Is `LEFT JOIN` the same as `LEFT OUTER JOIN`?
    *   **Answer:** Yes, the `OUTER` keyword is optional for `LEFT`, `RIGHT`, and `FULL` joins. `LEFT JOIN` and `LEFT OUTER JOIN` are functionally identical (and similarly for `RIGHT` and `FULL`).
4.  **[Medium]** If you `LEFT JOIN` TableA to TableB on `A.ID = B.AID`, and then add `WHERE B.SomeColumn = 'Value'`, how does this potentially change the behavior compared to a simple `LEFT JOIN`?
    *   **Answer:** Adding a `WHERE` clause that filters on columns from the *right* table (`TableB`) of a `LEFT JOIN` effectively converts the join into an `INNER JOIN`. This is because the `WHERE` clause is applied *after* the join, and it filters out rows where `B.SomeColumn` is `NULL` (which includes all the rows from TableA that didn't have a match in TableB). To filter the right table *before* the join while preserving all left table rows, the condition should be placed in the `ON` clause (e.g., `ON A.ID = B.AID AND B.SomeColumn = 'Value'`).
5.  **[Medium]** Can you join a table to a view? Can you join a view to another view?
    *   **Answer:** Yes to both. Views can generally be used in `JOIN` clauses just like tables, as they represent a logical set of rows and columns. You can join tables to views, views to tables, or views to other views, provided you have appropriate permissions and can define a valid join condition.
6.  **[Medium]** What is the difference between putting a filter condition in the `ON` clause versus the `WHERE` clause for an `INNER JOIN`?
    *   **Answer:** For an `INNER JOIN`, placing a filter condition in the `ON` clause (e.g., `ON A.ID = B.ID AND A.Status = 'Active'`) or the `WHERE` clause (e.g., `ON A.ID = B.ID WHERE A.Status = 'Active'`) usually produces the **same result set**. The query optimizer is often smart enough to apply the filter effectively in either case. However, for `OUTER JOIN`s (`LEFT`, `RIGHT`, `FULL`), placing the condition in the `ON` clause filters the rows from one table *before* the join determines matches, while placing it in the `WHERE` clause filters the *combined result set* after the join, which can lead to different results (as discussed in Q4).
7.  **[Hard]** When might you choose to use `CROSS APPLY` or `OUTER APPLY` instead of a standard `JOIN`?
    *   **Answer:** `APPLY` is typically used when the right side of the operation needs to be evaluated *for each row* of the left side, especially when the right side is a table-valued function (TVF) that takes parameters from the left side, or a correlated subquery that cannot be easily expressed as a standard join. For example, calling a function `dbo.GetTopNOrders(CustomerID)` for each customer, or selecting the `TOP 3` related records per outer row (as shown in the script). Standard joins typically compare static sets, while `APPLY` allows for row-by-row invocation of the right-side logic.
8.  **[Hard]** Can you join tables based on columns with different data types (e.g., `VARCHAR` and `INT`)? What are the implications?
    *   **Answer:** Yes, you can, but it's generally **not recommended** due to performance and potential errors. SQL Server will attempt implicit data type conversion based on data type precedence rules (e.g., it might try to convert the `VARCHAR` to `INT`).
        *   **Implications:**
            *   **Performance:** Implicit conversions in the `ON` clause often make the predicate non-SARGable, preventing efficient index usage and leading to scans instead of seeks.
            *   **Errors:** If a value cannot be converted (e.g., trying to convert the `VARCHAR` 'ABC' to `INT`), the query will fail with a conversion error.
        *   **Best Practice:** Ensure join columns have compatible data types. If necessary, use explicit `CAST` or `CONVERT` in the `ON` clause, but be aware this usually harms SARGability. Fixing the data types at the table design level is the best solution.
9.  **[Hard]** What is a "Hash Join", a "Merge Join", and a "Nested Loops Join"? How does the query optimizer choose between them?
    *   **Answer:** These are three common physical join algorithms used by the SQL Server query optimizer:
        *   **Nested Loops Join:** Iterates through each row of the outer input table and, for each row, scans the inner input table to find matches. Efficient for small outer inputs and when the inner input has a useful index on the join column.
        *   **Merge Join:** Requires both inputs to be sorted on the join columns. It then reads both sorted inputs concurrently and "merges" them, matching rows with equal join keys. Efficient if inputs are already sorted (e.g., from index seeks/scans) or if sorting is relatively cheap compared to other methods. Requires equality (`=`) join predicates.
        *   **Hash Join:** Builds an in-memory hash table based on the join column(s) from one input (the "build" input, usually the smaller one). It then reads the second input (the "probe" input) and uses the hash table to quickly find matching rows. Efficient for large, unsorted inputs where other methods would be too slow. Requires memory and uses equality (`=`) join predicates.
        *   **Choice:** The optimizer chooses the algorithm based on estimated costs, considering factors like table sizes, availability and type of indexes, data distribution statistics, required sorting, available memory, and the specific join type and conditions.
10. **[Hard/Tricky]** Can an `INNER JOIN` produce more rows than exist in the largest of the two tables being joined? If so, how?
    *   **Answer:** Yes. This can happen if the join condition results in a **many-to-many** relationship based on the join keys. If multiple rows in Table A have the same join key value, and multiple rows in Table B also have that same join key value, the `INNER JOIN` will produce a Cartesian product *for that specific key value*. For example, if 3 rows in A have `DeptID = 10` and 4 rows in B have `DeptID = 10`, the join will produce 3 * 4 = 12 rows just for `DeptID = 10`. If this happens for multiple key values, the total number of rows in the result can exceed the number of rows in either original table.
