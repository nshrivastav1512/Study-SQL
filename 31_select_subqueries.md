# SQL Deep Dive: Subqueries and Common Table Expressions (CTEs)

## 1. Introduction: Queries within Queries

Subqueries (also called inner queries or nested queries) are `SELECT` statements embedded within another SQL statement (`SELECT`, `INSERT`, `UPDATE`, `DELETE`). They allow you to perform multi-step queries where the result of one query is used as input or a condition for another.

Common Table Expressions (CTEs), introduced with the `WITH` clause, provide a way to define named, temporary result sets that can be referenced within a single statement. They often make complex queries involving subqueries more readable and maintainable.

**Why use Subqueries/CTEs?**

*   **Complex Filtering:** Filter data based on results calculated from other tables or aggregations (e.g., find employees earning more than the company average).
*   **Derived Data:** Use aggregated or transformed data in joins or calculations (e.g., join employees to department average salaries).
*   **Existence Checks:** Determine if related data exists (`EXISTS`, `IN`).
*   **Readability (CTEs):** Break down complex logic into named, logical steps, improving understanding and maintenance.
*   **Recursion (CTEs):** Enable querying hierarchical data structures.

## 2. Subqueries and CTEs in Action: Analysis of `31_select_subqueries.sql`

This script demonstrates different types of subqueries and CTE usage.

**Types of Subqueries:**

**a) Scalar Subquery**

```sql
SELECT EmployeeID, ..., Salary,
    (SELECT AVG(Salary) FROM HR.EMP_Details) AS AvgCompanySalary, -- Subquery returns one value
    Salary - (SELECT AVG(Salary) FROM HR.EMP_Details) AS DiffFromAvg
FROM HR.EMP_Details;
```

*   **Explanation:** Returns a single value (one row, one column). Can be used anywhere a single literal value is expected (e.g., in the `SELECT` list, `WHERE` clause comparisons, `SET` clause). The subquery here calculates the overall average salary once.

<details>
<summary>Click to see Example Visualization (Scalar Subquery)</summary>

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
*   **Subquery Result (Conceptual):** `(SELECT AVG(Salary) FROM HR.EMP_Details)` might return `70000.00`.
*   **Example Query:**
    ```sql
    SELECT EmployeeID, Salary,
        (SELECT AVG(Salary) FROM HR.EMP_Details) AS AvgCompanySalary,
        Salary - (SELECT AVG(Salary) FROM HR.EMP_Details) AS DiffFromAvg
    FROM HR.EMP_Details;
    ```
*   **Output Result Set:** The single average salary value is shown for every row, allowing comparison.
    ```
    +------------+--------+------------------+-------------+
    | EmployeeID | Salary | AvgCompanySalary | DiffFromAvg |
    +------------+--------+------------------+-------------+
    | 1000       | 60000  | 70000.00         | -10000.00   |
    | 1001       | 75000  | 70000.00         | 5000.00     |
    | 1002       | 90000  | 70000.00         | 20000.00    |
    | 1003       | 55000  | 70000.00         | -15000.00   |
    +------------+--------+------------------+-------------+
    ```
*   **Key Takeaway:** A scalar subquery produces a single value that can be used like a constant within the outer query's `SELECT` or `WHERE` clause.

</details>

**b) Column Subquery**

```sql
WHERE DepartmentID IN (SELECT DepartmentID FROM HR.Departments WHERE ...);
```

*   **Explanation:** Returns a single column containing multiple rows. Typically used with operators like `IN`, `ANY`, `ALL` in the `WHERE` or `HAVING` clause.

<details>
<summary>Click to see Example Visualization (Column Subquery)</summary>

*   **Input Tables (Conceptual Snippets):**
    *   `HR.EMP_Details` (e):
        ```
        +------------+--------------+
        | EmployeeID | DepartmentID |
        +------------+--------------+
        | 1000       | 2            | <- Match
        | 1001       | 2            | <- Match
        | 1002       | 3            |
        | 1003       | 2            | <- Match
        | 1004       | 1            | <- Match
        +------------+--------------+
        ```
    *   `HR.Departments` (d): (Assume LocationID 20 is 'London')
        ```
        +--------------+------------+
        | DepartmentID | LocationID |
        +--------------+------------+
        | 1            | 20         |
        | 2            | 20         |
        | 3            | 30         |
        +--------------+------------+
        ```
*   **Subquery Result (Conceptual):** `(SELECT DepartmentID FROM HR.Departments WHERE LocationID = 20)` returns `(1, 2)`.
*   **Example Query:** Find employees in London departments.
    ```sql
    SELECT EmployeeID, DepartmentID
    FROM HR.EMP_Details
    WHERE DepartmentID IN (SELECT DepartmentID FROM HR.Departments WHERE LocationID = 20);
    ```
*   **Output Result Set:** Only employees whose `DepartmentID` is in the list (1, 2) returned by the subquery.
    ```
    +------------+--------------+
    | EmployeeID | DepartmentID |
    +------------+--------------+
    | 1000       | 2            |
    | 1001       | 2            |
    | 1003       | 2            |
    | 1004       | 1            |
    +------------+--------------+
    ```
*   **Key Takeaway:** A column subquery returns a list of values, often used with `IN`, `ANY`, or `ALL` to filter the outer query.

</details>

**c) Row Subquery**

```sql
WHERE (Salary, DepartmentID) = (SELECT MAX(Salary), 1 FROM ... WHERE DepartmentID = 1);
```

*   **Explanation:** Returns a single row containing multiple columns. Can be used for multi-column comparisons (syntax might vary slightly across database systems, but SQL Server supports this tuple comparison).

<details>
<summary>Click to see Example Visualization (Row Subquery)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1000       | 2            | 60000  |
    | 1001       | 1            | 75000  | <- Match
    | 1002       | 3            | 90000  |
    | 1004       | 1            | 62000  |
    +------------+--------------+--------+
    ```
*   **Subquery Result (Conceptual):** `(SELECT MAX(Salary), DepartmentID FROM HR.EMP_Details WHERE DepartmentID = 1)` returns `(75000, 1)`.
*   **Example Query:** Find the employee(s) with the maximum salary in Department 1.
    ```sql
    SELECT EmployeeID, DepartmentID, Salary
    FROM HR.EMP_Details
    WHERE (Salary, DepartmentID) = (SELECT MAX(Salary), DepartmentID
                                     FROM HR.EMP_Details
                                     WHERE DepartmentID = 1
                                     GROUP BY DepartmentID); -- Ensure single row if MAX is unique per dept
    ```
*   **Output Result Set:** Returns the row matching both the Salary and DepartmentID from the subquery result.
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1001       | 1            | 75000  |
    +------------+--------------+--------+
    ```
*   **Key Takeaway:** A row subquery returns multiple columns for a single row, allowing tuple-based comparisons in the `WHERE` clause (syntax support varies).

</details>

**d) Table Subquery (Derived Table)**

```sql
FROM HR.Departments d
JOIN ( -- Subquery used in FROM clause
    SELECT DepartmentID, COUNT(*) AS EmployeeCount, AVG(Salary) AS AvgSalary
    FROM HR.EMP_Details GROUP BY DepartmentID
) e ON d.DepartmentID = e.DepartmentID; -- Alias 'e' is required
```

*   **Explanation:** Returns multiple rows and multiple columns. When used in the `FROM` clause, it acts like a temporary table (a derived table) that can be joined to other tables. It *must* be given an alias (like `e` here).

<details>
<summary>Click to see Example Visualization (Table Subquery / Derived Table)</summary>

*   **Input Tables (Conceptual Snippets):**
    *   `HR.EMP_Details` (used inside subquery):
        ```
        +--------------+--------+
        | DepartmentID | Salary |
        +--------------+--------+
        | 1            | 62000  |
        | 1            | 48000  |
        | 2            | 60000  |
        | 2            | 75000  |
        | 3            | 90000  |
        +--------------+--------+
        ```
    *   `HR.Departments` (d - outer query):
        ```
        +--------------+----------------+
        | DepartmentID | DepartmentName |
        +--------------+----------------+
        | 1            | HR             |
        | 2            | IT             |
        | 3            | Finance        |
        +--------------+----------------+
        ```
*   **Subquery Result (Conceptual - `e`):**
    ```
    +--------------+---------------+-----------+
    | DepartmentID | EmployeeCount | AvgSalary |
    +--------------+---------------+-----------+
    | 1            | 2             | 55000.00  |
    | 2            | 2             | 67500.00  |
    | 3            | 1             | 90000.00  |
    +--------------+---------------+-----------+
    ```
*   **Example Query:**
    ```sql
    SELECT d.DepartmentName, e.EmployeeCount, e.AvgSalary
    FROM HR.Departments d
    JOIN ( -- Subquery acts like a table
        SELECT DepartmentID, COUNT(*) AS EmployeeCount, AVG(Salary) AS AvgSalary
        FROM HR.EMP_Details GROUP BY DepartmentID
    ) e ON d.DepartmentID = e.DepartmentID; -- Join outer table to subquery result
    ```
*   **Output Result Set:** Joins department names to the aggregated results from the subquery.
    ```
    +----------------+---------------+-----------+
    | DepartmentName | EmployeeCount | AvgSalary |
    +----------------+---------------+-----------+
    | HR             | 2             | 55000.00  |
    | IT             | 2             | 67500.00  |
    | Finance        | 1             | 90000.00  |
    +----------------+---------------+-----------+
    ```
*   **Key Takeaway:** A subquery in the `FROM` clause (derived table) creates an intermediate result set that can be joined like a regular table. It must have an alias.

</details>

**Correlated vs. Uncorrelated Subqueries:**

*   **Uncorrelated:** Can be executed independently of the outer query. Its result doesn't change based on the row being processed by the outer query (e.g., the scalar subquery calculating `AVG(Salary)` for the whole company). Usually executed once.
*   **Correlated:** References columns from the outer query. It *cannot* be executed independently and must be re-evaluated for *each row* processed by the outer query (e.g., calculating average salary *for the current row's department*). Can impact performance if not optimized well.

**e) Correlated Subquery Example**

```sql
SELECT e.EmployeeID, ...,
    (SELECT AVG(Salary) FROM HR.EMP_Details WHERE DepartmentID = e.DepartmentID) AS AvgDeptSalary
FROM HR.EMP_Details e; -- Subquery references outer 'e.DepartmentID'
```

*   **Explanation:** Calculates the average salary specifically for the department of the employee (`e`) in the current row being processed by the outer query.

<details>
<summary>Click to see Example Visualization (Correlated Subquery)</summary>

*   **Input Table (`HR.EMP_Details` e - Conceptual Snippet):**
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
*   **Conceptual Subquery Execution:**
    *   For Emp 1004 (Dept 1): Subquery calculates AVG for Dept 1 -> 55000.00
    *   For Emp 1005 (Dept 1): Subquery calculates AVG for Dept 1 -> 55000.00
    *   For Emp 1000 (Dept 2): Subquery calculates AVG for Dept 2 -> 67500.00
    *   For Emp 1001 (Dept 2): Subquery calculates AVG for Dept 2 -> 67500.00
    *   For Emp 1002 (Dept 3): Subquery calculates AVG for Dept 3 -> 90000.00
*   **Example Query:**
    ```sql
    SELECT e.EmployeeID, e.Salary,
        (SELECT AVG(Salary) FROM HR.EMP_Details sub WHERE sub.DepartmentID = e.DepartmentID) AS AvgDeptSalary
    FROM HR.EMP_Details e;
    ```
*   **Output Result Set:** Each row shows the employee's salary and the average calculated *specifically for their department* via the correlated subquery.
    ```
    +------------+--------+---------------+
    | EmployeeID | Salary | AvgDeptSalary |
    +------------+--------+---------------+
    | 1004       | 62000  | 55000.00      |
    | 1005       | 48000  | 55000.00      |
    | 1000       | 60000  | 67500.00      |
    | 1001       | 75000  | 67500.00      |
    | 1002       | 90000  | 90000.00      |
    +------------+--------+---------------+
    ```
*   **Key Takeaway:** Correlated subqueries reference the outer query (e.g., `e.DepartmentID`) and are re-evaluated for each outer row, allowing row-specific calculations. (Note: Window functions often provide a more efficient alternative for this specific example).

</details>

**Subqueries with Specific Operators:**

**f) `EXISTS` Subquery**

```sql
WHERE EXISTS (SELECT 1 FROM HR.EMP_Details e WHERE e.DepartmentID = d.DepartmentID AND ...);
```

*   **Explanation:** Checks if the subquery returns *any* rows. Efficient for existence checks. Often correlated.

<details>
<summary>Click to see Example Visualization (EXISTS Subquery)</summary>

*   **Input Tables (Conceptual Snippets):**
    *   `HR.Departments` (d):
        ```
        +--------------+----------------+
        | DepartmentID | DepartmentName |
        +--------------+----------------+
        | 1            | HR             |
        | 2            | IT             |
        | 3            | Finance        |
        | 4            | Marketing      | <- No high earners
        +--------------+----------------+
        ```
    *   `HR.EMP_Details` (e):
        ```
        +------------+--------------+--------+
        | EmployeeID | DepartmentID | Salary |
        +------------+--------------+--------+
        | 1001       | 2            | 75000  | <- High earner in Dept 2
        | 1002       | 3            | 90000  | <- High earner in Dept 3
        | 1004       | 1            | 62000  |
        +------------+--------------+--------+
        ```
*   **Example Query:** Find departments with at least one employee earning > 70000.
    ```sql
    SELECT d.DepartmentName
    FROM HR.Departments d
    WHERE EXISTS (SELECT 1 FROM HR.EMP_Details e
                  WHERE e.DepartmentID = d.DepartmentID AND e.Salary > 70000);
    ```
*   **Output Result Set:** Returns 'IT' and 'Finance' because the subquery finds matching high earners for these departments.
    ```
    +----------------+
    | DepartmentName |
    +----------------+
    | IT             |
    | Finance        |
    +----------------+
    ```
*   **Key Takeaway:** `EXISTS` returns true for outer rows where the correlated subquery finds at least one matching row.

</details>

**g) `NOT EXISTS` Subquery**

```sql
WHERE NOT EXISTS (SELECT 1 FROM HR.EMP_Details e WHERE e.DepartmentID = d.DepartmentID);
```

*   **Explanation:** Checks if the subquery returns *no* rows. Useful for finding rows without corresponding matches.

<details>
<summary>Click to see Example Visualization (NOT EXISTS Subquery)</summary>

*   **Input Tables (Conceptual Snippets):** (Same as EXISTS example)
    *   `HR.Departments` (d): (Includes HR and Marketing with no high earners)
    *   `HR.EMP_Details` (e): (No high earners in Dept 1 or 4)

*   **Example Query:** Find departments with *no* employees earning > 70000.
    ```sql
    SELECT d.DepartmentName
    FROM HR.Departments d
    WHERE NOT EXISTS (SELECT 1 FROM HR.EMP_Details e
                      WHERE e.DepartmentID = d.DepartmentID AND e.Salary > 70000);
    ```
*   **Output Result Set:** Returns 'HR' and 'Marketing' because the subquery finds no high earners for these departments.
    ```
    +----------------+
    | DepartmentName |
    +----------------+
    | HR             |
    | Marketing      |
    +----------------+
    ```
*   **Key Takeaway:** `NOT EXISTS` returns true for outer rows where the correlated subquery finds zero matching rows.

</details>

**h) Subquery with `ANY`/`SOME`**

```sql
WHERE Salary > ANY (SELECT AVG(Salary) FROM ... GROUP BY DepartmentID);
```

*   **Explanation:** Compares a value against the list returned by the subquery. `> ANY` means "greater than at least one value" (i.e., greater than the minimum).

<details>
<summary>Click to see Example Visualization (ANY/SOME Subquery)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1000       | 2            | 60000  | <- > 55k (Match)
    | 1001       | 2            | 75000  | <- > 55k (Match)
    | 1002       | 3            | 90000  | <- > 55k (Match)
    | 1003       | 2            | 55000  | <- Not > 55k
    | 1004       | 1            | 62000  | <- > 55k (Match)
    | 1005       | 1            | 48000  | <- Not > 55k
    +------------+--------------+--------+
    ```
*   **Subquery Result (Conceptual):** `(SELECT Salary FROM HR.EMP_Details WHERE DepartmentID = 2)` returns `(60000, 75000, 55000)`. The minimum is 55000.
*   **Example Query:** Find employees earning more than *at least one* person in Dept 2.
    ```sql
    SELECT EmployeeID, Salary
    FROM HR.EMP_Details
    WHERE Salary > ANY (SELECT Salary FROM HR.EMP_Details WHERE DepartmentID = 2);
    -- Equivalent to: WHERE Salary > (SELECT MIN(Salary) FROM HR.EMP_Details WHERE DepartmentID = 2)
    ```
*   **Output Result Set:** Returns employees with Salary > 55000.
    ```
    +------------+--------+
    | EmployeeID | Salary |
    +------------+--------+
    | 1000       | 60000  |
    | 1001       | 75000  |
    | 1002       | 90000  |
    | 1004       | 62000  |
    +------------+--------+
    ```
*   **Key Takeaway:** `> ANY` checks if a value is greater than the minimum value returned by the subquery.

</details>

**i) Subquery with `ALL`**

```sql
WHERE Salary > ALL (SELECT AVG(Salary) FROM ... GROUP BY DepartmentID);
```

*   **Explanation:** Compares a value against the list returned by the subquery. `> ALL` means "greater than every value" (i.e., greater than the maximum).

<details>
<summary>Click to see Example Visualization (ALL Subquery)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):** (Same as ANY example)
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1000       | 2            | 60000  | <- Not > 75k
    | 1001       | 2            | 75000  | <- Not > 75k
    | 1002       | 3            | 90000  | <- > 75k (Match)
    | 1003       | 2            | 55000  | <- Not > 75k
    | 1004       | 1            | 62000  | <- Not > 75k
    | 1005       | 1            | 48000  | <- Not > 75k
    +------------+--------------+--------+
    ```
*   **Subquery Result (Conceptual):** `(SELECT Salary FROM HR.EMP_Details WHERE DepartmentID = 2)` returns `(60000, 75000, 55000)`. The maximum is 75000.
*   **Example Query:** Find employees earning more than *everyone* in Dept 2.
    ```sql
    SELECT EmployeeID, Salary
    FROM HR.EMP_Details
    WHERE Salary > ALL (SELECT Salary FROM HR.EMP_Details WHERE DepartmentID = 2);
    -- Equivalent to: WHERE Salary > (SELECT MAX(Salary) FROM HR.EMP_Details WHERE DepartmentID = 2)
    ```
*   **Output Result Set:** Returns employees with Salary > 75000.
    ```
    +------------+--------+
    | EmployeeID | Salary |
    +------------+--------+
    | 1002       | 90000  |
    +------------+--------+
    ```
*   **Key Takeaway:** `> ALL` checks if a value is greater than the maximum value returned by the subquery.

</details>

**j) Nested Subqueries**

```sql
WHERE DepartmentID IN (SELECT DepartmentID FROM ... WHERE LocationID IN (SELECT LocationID FROM ...));
```

*   **Explanation:** A subquery can contain another subquery. Execution typically proceeds from the innermost query outward. Can become difficult to read and potentially inefficient.

<details>
<summary>Click to see Example Visualization (Nested Subqueries)</summary>

*   **Input Tables (Conceptual Snippets):**
    *   `HR.EMP_Details`: `(1000, DeptID=2), (1001, DeptID=2), (1004, DeptID=1)`
    *   `HR.Departments`: `(DeptID=1, LocID=20), (DeptID=2, LocID=20), (DeptID=3, LocID=30)`
    *   `HR.Locations`: `(LocID=20, City='London'), (LocID=30, City='Paris')`
*   **Innermost Subquery:** `(SELECT LocationID FROM HR.Locations WHERE City = 'London')` returns `(20)`.
*   **Middle Subquery:** `(SELECT DepartmentID FROM HR.Departments WHERE LocationID IN (20))` returns `(1, 2)`.
*   **Example Query:** Find employees in London departments.
    ```sql
    SELECT EmployeeID
    FROM HR.EMP_Details
    WHERE DepartmentID IN (SELECT DepartmentID FROM HR.Departments
                           WHERE LocationID IN (SELECT LocationID FROM HR.Locations
                                                WHERE City = 'London'));
    ```
*   **Output Result Set:** Employees whose DepartmentID is 1 or 2.
    ```
    +------------+
    | EmployeeID |
    +------------+
    | 1000       |
    | 1001       |
    | 1004       |
    +------------+
    ```
*   **Key Takeaway:** Subqueries can be nested, with inner results feeding outer conditions. CTEs often make deeply nested queries more readable.

</details>

**Common Table Expressions (CTEs):**

CTEs provide an alternative, often more readable way to structure complex queries involving subqueries or derived tables.

**k) Basic CTE**

```sql
WITH EmployeeStats AS ( -- Define the CTE name and its query
    SELECT DepartmentID, COUNT(*) AS EmployeeCount, AVG(Salary) AS AvgSalary
    FROM HR.EMP_Details GROUP BY DepartmentID
) -- End CTE definition
-- Main query referencing the CTE
SELECT d.DepartmentName, es.EmployeeCount, es.AvgSalary
FROM HR.Departments d JOIN EmployeeStats es ON d.DepartmentID = es.DepartmentID;
```

*   **Explanation:** Defines a temporary, named result set (`EmployeeStats`) using the `WITH` clause. The main query following the CTE definition can then reference `EmployeeStats` as if it were a table or view. The CTE exists only for the duration of the single statement.

<details>
<summary>Click to see Example Visualization (Basic CTE)</summary>

*   **Input Tables (Conceptual Snippets):** (Same as Derived Table example)
    *   `HR.EMP_Details`
    *   `HR.Departments`
*   **CTE Definition (Conceptual - `EmployeeStats`):** (Same result as the derived table subquery)
    ```
    +--------------+---------------+-----------+
    | DepartmentID | EmployeeCount | AvgSalary |
    +--------------+---------------+-----------+
    | 1            | 2             | 55000.00  |
    | 2            | 2             | 67500.00  |
    | 3            | 1             | 90000.00  |
    +--------------+---------------+-----------+
    ```
*   **Example Query:**
    ```sql
    WITH EmployeeStats AS ( -- Define CTE
        SELECT DepartmentID, COUNT(*) AS EmployeeCount, AVG(Salary) AS AvgSalary
        FROM HR.EMP_Details GROUP BY DepartmentID
    )
    -- Main query uses CTE
    SELECT d.DepartmentName, es.EmployeeCount, es.AvgSalary
    FROM HR.Departments d JOIN EmployeeStats es ON d.DepartmentID = es.DepartmentID;
    ```
*   **Output Result Set:** Same as the derived table example, joining department names to the aggregated results now defined in the CTE.
    ```
    +----------------+---------------+-----------+
    | DepartmentName | EmployeeCount | AvgSalary |
    +----------------+---------------+-----------+
    | HR             | 2             | 55000.00  |
    | IT             | 2             | 67500.00  |
    | Finance        | 1             | 90000.00  |
    +----------------+---------------+-----------+
    ```
*   **Key Takeaway:** CTEs provide a way to name subqueries (like derived tables), making the main query cleaner and often easier to read, especially for complex logic.

</details>

**l) Multiple CTEs**

```sql
WITH DepartmentStats AS (
    SELECT DepartmentID, ..., AVG(Salary) AS AvgSalary FROM ... GROUP BY DepartmentID
), -- Comma separates multiple CTEs
HighPaidDepts AS (
    SELECT DepartmentID FROM DepartmentStats WHERE AvgSalary > 70000 -- Can reference previous CTEs
)
-- Main query using the CTEs
SELECT e.EmployeeID, ...
FROM HR.EMP_Details e JOIN HR.Departments d ON ...
WHERE e.DepartmentID IN (SELECT DepartmentID FROM HighPaidDepts);
```

*   **Explanation:** You can define multiple CTEs sequentially, separated by commas. Each subsequent CTE can reference CTEs defined before it within the same `WITH` clause. This allows breaking down complex logic into manageable, named steps.

<details>
<summary>Click to see Example Visualization (Multiple CTEs)</summary>

*   **Input Table (`HR.EMP_Details` - Conceptual Snippet):**
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1000       | 2            | 60000  |
    | 1001       | 2            | 75000  |
    | 1002       | 3            | 90000  | <- High Paid Dept
    | 1003       | 2            | 55000  |
    | 1004       | 1            | 62000  |
    | 1005       | 1            | 48000  |
    | 1007       | 3            | 85000  | <- High Paid Dept
    +------------+--------------+--------+
    ```
*   **CTE 1 Result (Conceptual - `DepartmentStats`):**
    ```
    +--------------+-----------+
    | DepartmentID | AvgSalary |
    +--------------+-----------+
    | 1            | 55000.00  |
    | 2            | 63333.33  |
    | 3            | 87500.00  | <- Avg > 70k
    +--------------+-----------+
    ```
*   **CTE 2 Result (Conceptual - `HighPaidDepts`):**
    ```
    +--------------+
    | DepartmentID |
    +--------------+
    | 3            |
    +--------------+
    ```
*   **Example Query:**
    ```sql
    WITH DepartmentStats AS (
        SELECT DepartmentID, AVG(Salary) AS AvgSalary FROM HR.EMP_Details GROUP BY DepartmentID
    ),
    HighPaidDepts AS (
        SELECT DepartmentID FROM DepartmentStats WHERE AvgSalary > 70000
    )
    SELECT e.EmployeeID, e.DepartmentID, e.Salary
    FROM HR.EMP_Details e
    WHERE e.DepartmentID IN (SELECT DepartmentID FROM HighPaidDepts);
    ```
*   **Output Result Set:** Only employees from departments identified in the `HighPaidDepts` CTE (Dept 3).
    ```
    +------------+--------------+--------+
    | EmployeeID | DepartmentID | Salary |
    +------------+--------------+--------+
    | 1002       | 3            | 90000  |
    | 1007       | 3            | 85000  |
    +------------+--------------+--------+
    ```
*   **Key Takeaway:** Multiple CTEs allow you to build complex queries step-by-step, with each CTE potentially using results from preceding ones, improving readability.

</details>

## 3. Targeted Interview Questions (Based on `31_select_subqueries.sql`)

**Question 1:** What is the difference between a scalar subquery and a table subquery (derived table)? Where is each typically used?

**Solution 1:**

*   **Scalar Subquery:** Returns exactly one column and one row (a single value). It's typically used in the `SELECT` list or in a `WHERE` clause for comparison against a single value (e.g., `WHERE ColumnA = (SELECT MAX(Value) FROM...)`).
*   **Table Subquery (Derived Table):** Returns potentially multiple rows and multiple columns. It's used in the `FROM` clause, treated like a temporary table, and must be given an alias. It's often used to join against aggregated or pre-processed data.

**Question 2:** Explain the difference between a correlated subquery and an uncorrelated subquery. Which type is generally executed only once, and which type is executed repeatedly?

**Solution 2:**

*   **Uncorrelated Subquery:** Can be executed independently of the outer query; its result does not depend on the current row being processed by the outer query. It is generally executed **once** for the entire statement. Example: `(SELECT AVG(Salary) FROM HR.EMP_Details)` used in section 1.
*   **Correlated Subquery:** Contains a reference to columns from the outer query. It cannot be executed independently and must be logically re-evaluated **for each row** processed by the outer query. Example: `(SELECT AVG(Salary) FROM ... WHERE DepartmentID = e.DepartmentID)` used in section 5. Correlated subqueries can sometimes be less performant due to this row-by-row execution pattern, although the optimizer can often find efficient ways (like transforming them into joins).

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can a subquery used with the `IN` operator return more than one column?
    *   **Answer:** No. A subquery used with `IN` must return only a single column.
2.  **[Easy]** What keyword introduces a Common Table Expression (CTE)?
    *   **Answer:** `WITH`.
3.  **[Medium]** Can a CTE be referenced multiple times within the same main query that follows it?
    *   **Answer:** Yes. A CTE defined in a `WITH` clause can be referenced multiple times in the subsequent `SELECT`, `INSERT`, `UPDATE`, `DELETE`, or `MERGE` statement, often simplifying queries that need to reuse the same intermediate result set.
4.  **[Medium]** What happens if a scalar subquery (one expected to return a single value) actually returns more than one row?
    *   **Answer:** An error occurs. SQL Server will raise an error stating that the subquery returned more than one value when only one was expected (e.g., Error 512).
5.  **[Medium]** Is `WHERE ColumnA NOT IN (SELECT Value FROM ...)` functionally identical to `WHERE NOT EXISTS (SELECT 1 FROM ... WHERE OtherTable.Value = OuterTable.ColumnA)`? Consider NULLs.
    *   **Answer:** No, they are not identical, primarily due to how `NULL` values are handled.
        *   `NOT IN`: If the subquery result set contains *any* `NULL` values, the `NOT IN` condition will evaluate to `UNKNOWN` (effectively false) for *all* rows in the outer query, potentially returning an empty result set unexpectedly.
        *   `NOT EXISTS`: Correctly handles `NULL`s based on the join condition within the subquery. It simply checks for the non-existence of matching rows according to the correlation predicate.
    *   Therefore, `NOT EXISTS` is generally safer and often preferred over `NOT IN` when dealing with potentially nullable columns or subqueries that might return `NULL`.
6.  **[Medium]** Can you use `ORDER BY` inside a subquery used in the `FROM` clause (a derived table)? What about inside a subquery used with `IN` or `EXISTS`?
    *   **Answer:**
        *   **Derived Table (FROM clause):** You *can* use `ORDER BY` inside a derived table subquery, but only if you also use `TOP` or `OFFSET`/`FETCH`. Without `TOP` or `OFFSET`/`FETCH`, `ORDER BY` inside a derived table is generally disallowed or ignored because tables/derived tables conceptually have no inherent order.
        *   **IN/EXISTS Subquery:** `ORDER BY` inside a subquery used with `IN` or `EXISTS` is syntactically allowed but generally **pointless and ignored** by the optimizer. `IN` and `EXISTS` only care about the *values* or the *existence* of rows, not their order. Adding `ORDER BY` just adds unnecessary overhead.
7.  **[Hard]** Can a CTE reference itself? If so, what is this called and what is required?
    *   **Answer:** Yes, a CTE can reference itself. This is called a **recursive CTE**. It requires:
        1.  An **anchor member**: A `SELECT` statement that does not reference the CTE itself, providing the base case.
        2.  A `UNION ALL` operator.
        3.  A **recursive member**: A `SELECT` statement that *does* reference the CTE name, typically joining back to the source table based on the results from the previous iteration.
        4.  A termination condition (either implicit, when the recursive member returns no rows, or explicit via a `WHERE` clause or `MAXRECURSION` option).
8.  **[Hard]** Are CTEs materialized (like temporary tables), or are they more like macros or views? What are the performance implications?
    *   **Answer:** CTEs are generally **not materialized**. They are more like named subqueries or inline views. The query optimizer typically expands the CTE definition into the main query plan each time the CTE is referenced.
        *   **Performance Implications:**
            *   **Readability:** Major benefit is improved query readability and maintainability.
            *   **No Automatic Materialization:** Unlike indexed views or sometimes temporary tables, the results aren't usually stored separately, meaning the CTE's logic might be executed multiple times if referenced multiple times (though the optimizer can sometimes be smart about this).
            *   **Optimization:** The optimizer optimizes the *entire* statement including the expanded CTE logic. Sometimes this leads to better plans than manually creating temp tables; other times, manually materializing results in a temp table might be faster if an intermediate result is large and reused frequently.
9.  **[Hard]** Can you use `UPDATE` or `DELETE` statements directly referencing a CTE? If so, what is being modified?
    *   **Answer:** Yes, you can use `UPDATE` and `DELETE` statements where the target directly references a CTE, *provided the CTE is "updateable"*. An updateable CTE must unambiguously reference columns from a single underlying base table. When you `UPDATE` or `DELETE` from such a CTE, you are actually modifying the rows in the **underlying base table** that correspond to the rows identified by the CTE and any additional `WHERE` clause on the `UPDATE`/`DELETE` statement. This is often used with ranking functions in a CTE to delete duplicates or update specific ranked rows.
10. **[Hard/Tricky]** What is the difference in scope between a CTE defined with `WITH` and a subquery defined in the `FROM` clause (derived table)?
    *   **Answer:**
        *   **CTE:** A CTE defined using `WITH` has a scope limited to the *single* statement (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `MERGE`) immediately following the CTE definition. It cannot be referenced in subsequent, separate statements within the same batch or script.
        *   **Derived Table (Subquery in `FROM`):** A derived table's scope is limited to the query it is defined within. It's essentially an inline view for that specific query.
    *   The main practical difference is that a CTE can be referenced *multiple times* within the single statement that follows it, whereas a derived table definition would need to be repeated if the same logic was needed multiple times within one query (unless defined as a CTE first).
