# SQL Deep Dive: `CROSS APPLY` and `OUTER APPLY`

## 1. Introduction: What are `APPLY` Operators?

The `APPLY` operator, introduced in SQL Server 2005, allows you to invoke a table-valued function (TVF) or evaluate a table-valued expression (like a subquery) for **each row** returned by an outer table expression. It's a powerful tool for performing row-by-row correlations or calculations that are difficult or inefficient to express using standard `JOIN` syntax.

There are two forms of `APPLY`:

*   **`CROSS APPLY`:** Behaves like an `INNER JOIN`. It returns only those rows from the outer table where the table-valued expression on the right side returns **at least one row**. If the right side returns no rows for a given outer row, that outer row is excluded from the final result.
*   **`OUTER APPLY`:** Behaves like a `LEFT OUTER JOIN`. It returns **all rows** from the outer table. If the table-valued expression on the right side returns rows for a given outer row, those rows are joined. If the right side returns *no rows* for a given outer row, the outer row is still included in the result, but with `NULL` values for the columns originating from the right-side expression.

**Why use `APPLY`?**

*   **Row-Level Correlation:** Evaluate a function or subquery for each row of an outer table, passing values from the outer row into the inner expression (parameterized correlation).
*   **Table-Valued Functions (TVFs):** The primary use case is often calling parameterized TVFs where parameters come from the outer table.
*   **Top-N per Group:** Efficiently retrieve the top N related rows for each row in an outer table (e.g., latest 3 orders for each customer).
*   **Unpivoting (Alternative):** Can sometimes be used as an alternative to the `UNPIVOT` operator, especially with `VALUES`.
*   **Complex Joins:** Handle scenarios where the join condition involves complex logic or function calls evaluated per row.

**Syntax:**

```sql
SELECT ...
FROM OuterTableExpression AS OuterAlias
{CROSS | OUTER} APPLY TableValuedExpression(OuterAlias.Column1, ...) AS ApplyAlias
[WHERE ...]
```

## 2. `APPLY` in Action: Analysis of `102_CROSS_OUTER_APPLY.sql`

This script demonstrates practical uses of both `CROSS APPLY` and `OUTER APPLY`.

**Part 1: Basic `CROSS APPLY` Usage**

*   **1. Employee Skills Matrix (Top 3):**
    ```sql
    SELECT e.FirstName, ..., s.SkillName, s.ProficiencyLevel
    FROM HR.Employees e
    CROSS APPLY ( -- For each employee 'e'...
        SELECT TOP 3 SkillName, ProficiencyLevel -- ...get their top 3 skills...
        FROM HR.EmployeeSkills
        WHERE EmployeeID = e.EmployeeID -- ...correlated by EmployeeID...
        ORDER BY ProficiencyLevel DESC -- ...ordered by proficiency.
    ) s; -- Alias for the result of the APPLY
    ```
    *   **Explanation:** For every employee (`e`), the subquery inside `CROSS APPLY` finds their top 3 skills ordered by proficiency. Because it's `CROSS APPLY`, only employees who have at least one skill record in `HR.EmployeeSkills` will appear in the final result (inner join behavior).
*   **2. Latest Performance Reviews:**
    ```sql
    SELECT e.FirstName, ..., r.ReviewDate, r.Rating, ...
    FROM HR.Employees e
    CROSS APPLY ( -- For each employee 'e'...
        SELECT TOP 1 ReviewDate, Rating, Comments -- ...get their single latest review...
        FROM HR.PerformanceReviews
        WHERE EmployeeID = e.EmployeeID -- ...correlated by EmployeeID...
        ORDER BY ReviewDate DESC -- ...ordered by date.
    ) r;
    ```
    *   **Explanation:** Retrieves each employee along with the details of their single most recent performance review. Again, only employees with at least one review will be returned.

**Part 2: `OUTER APPLY` Usage**

*   **1. Employee Sales Performance (Including Non-Performers):**
    ```sql
    SELECT e.FirstName, ..., ISNULL(s.TotalSales, 0) as TotalSales, ...
    FROM HR.Employees e
    OUTER APPLY ( -- For each employee 'e'...
        SELECT COUNT(*) as SalesCount, SUM(Amount) as TotalSales -- ...calculate sales aggregates...
        FROM HR.Sales
        WHERE EmployeeID = e.EmployeeID AND YEAR(SaleDate) = YEAR(GETDATE()) -- ...for the current year.
    ) s;
    ```
    *   **Explanation:** Calculates total sales and sales count for each employee for the current year. Because it's `OUTER APPLY`, *all* employees from `HR.Employees` are returned. If an employee has no sales records for the year, the subquery returns no rows, and `OUTER APPLY` results in `NULL` values for `s.TotalSales` and `s.SalesCount` for that employee (which are then converted to 0 by `ISNULL`).
*   **2. Department Budget Analysis:**
    ```sql
    SELECT d.DepartmentName, ISNULL(b.TotalBudget, 0) as AllocatedBudget, ...
    FROM HR.Departments d
    OUTER APPLY ( -- For each department 'd'...
        SELECT SUM(Amount) as TotalBudget, SUM(CASE WHEN IsSpent = 1 ...) as UsedBudget -- ...calculate budget aggregates...
        FROM HR.DepartmentBudgets
        WHERE DepartmentID = d.DepartmentID AND FiscalYear = YEAR(GETDATE()) -- ...for the current year.
    ) b;
    ```
    *   **Explanation:** Shows budget details for *all* departments. If a department has no budget record for the current fiscal year in `HR.DepartmentBudgets`, it still appears in the output, but with 0 for the budget figures due to `OUTER APPLY` and `ISNULL`.

**Part 3: Complex Scenarios**

*   **1. Employee Career Progression:** Uses `CROSS APPLY` with a subquery containing a window function (`LAG`) to find the current position, years in position, and the immediately preceding position for each employee (assuming the subquery returns the current position based on `EndDate IS NULL`).
*   **2. Training Completion Status:** Uses `OUTER APPLY` to calculate the required trainings, completed trainings, and completion rate for each employee based on records in `HR.EmployeeTraining` for the current year. `OUTER APPLY` ensures all employees are listed, even those with no training records for the year.

**Part 4: Performance Best Practices**

*   Choose `CROSS APPLY` (inner join behavior) vs `OUTER APPLY` (left join behavior) based on whether you need to include outer rows that have no match from the right-side expression. `CROSS APPLY` can sometimes be slightly more performant if an inner join is sufficient.
*   Ensure appropriate indexes exist on columns used in the correlation predicate (e.g., `WHERE EmployeeID = e.EmployeeID`).
*   Limit rows returned by the right-side expression using `TOP` or `WHERE` clauses whenever possible.
*   Consider materializing complex subquery results into temp tables/table variables if they are reused multiple times or if performance is poor.

## 3. Targeted Interview Questions (Based on `102_CROSS_OUTER_APPLY.sql`)

**Question 1:** What is the fundamental difference between `CROSS APPLY` and `OUTER APPLY`?

**Solution 1:**
*   `CROSS APPLY`: Returns rows from the outer table only if the table-valued expression on the right side returns at least one row for that outer row (similar to an `INNER JOIN`).
*   `OUTER APPLY`: Returns *all* rows from the outer table, regardless of whether the table-valued expression on the right side returns any rows. If the right side returns no rows, columns from the right side will have `NULL` values (similar to a `LEFT OUTER JOIN`).

**Question 2:** In section 1.1 ("Employee Skills Matrix"), why is `CROSS APPLY` used with `TOP 3`? What would the result look like?

**Solution 2:** `CROSS APPLY` is used to execute the subquery (finding the top 3 skills) *for each employee* from the outer table (`HR.Employees`). The `TOP 3` within the subquery limits the results from `HR.EmployeeSkills` to only the three most proficient skills for that specific employee (based on `ORDER BY ProficiencyLevel DESC`). The final result would list each employee who has skills, potentially multiple times (up to three rows per employee), showing one of their top 3 skills on each row alongside their name. Employees with no skills recorded would be excluded because `CROSS APPLY` acts like an inner join.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can you use `APPLY` operators with scalar functions?
    *   **Answer:** No. `APPLY` operators are specifically designed to work with **table-valued** expressions (subqueries, inline TVFs, multi-statement TVFs). Scalar functions return a single value and are used directly in `SELECT` lists or `WHERE` clauses.
2.  **[Easy]** Which `APPLY` operator behaves like a `LEFT OUTER JOIN`?
    *   **Answer:** `OUTER APPLY`.
3.  **[Medium]** Can the table-valued expression on the right side of `APPLY` reference columns from the outer table on the left side?
    *   **Answer:** Yes, absolutely. This is a primary use case for `APPLY`. It allows correlation, where the inner expression is evaluated based on values from the current outer row (e.g., `WHERE InnerTable.ID = OuterTable.ID`). Standard `JOIN`s cannot typically do this with subqueries in the `FROM` clause.
4.  **[Medium]** Is it possible to rewrite any `INNER JOIN` using `CROSS APPLY`? Is it possible to rewrite any `LEFT OUTER JOIN` using `OUTER APPLY`?
    *   **Answer:** Yes, generally. An `INNER JOIN B ON A.ID = B.ID` can often be rewritten as `FROM A CROSS APPLY (SELECT * FROM B WHERE B.ID = A.ID) AS B_Alias`. Similarly, a `LEFT JOIN` can often be rewritten using `OUTER APPLY`. However, `APPLY` is more powerful as the right side can be a complex expression or function call correlated with the outer table row, which isn't possible with standard `JOIN` syntax. `APPLY` is typically used when standard joins are insufficient or less clear.
5.  **[Medium]** When using `APPLY` with a subquery containing `TOP 1` and `ORDER BY` (like in the "Latest Performance Reviews" example), what is crucial for getting consistent results?
    *   **Answer:** The `ORDER BY` clause within the subquery must uniquely determine the desired row. If there could be multiple reviews on the exact same latest `ReviewDate`, the `TOP 1` might return an arbitrary one among the ties unless a secondary, unique sorting column (like `ReviewID`) is added to the `ORDER BY`.
6.  **[Medium]** Can you use `APPLY` to call a multi-statement table-valued function (MSTVF) for each row of an outer table?
    *   **Answer:** Yes, this is a very common use case for `APPLY`. Standard `JOIN`s cannot directly invoke a function row-by-row like this.
7.  **[Hard]** How might the performance of `CROSS APPLY (SELECT TOP 1 ...)` compare to using a correlated subquery in the `SELECT` list (e.g., `SELECT Outer.Col, (SELECT TOP 1 Inner.Val FROM Inner WHERE Inner.ID = Outer.ID ORDER BY ...) FROM Outer`)?
    *   **Answer:** Often, `CROSS APPLY` performs better. While both achieve a similar result, the query optimizer generally handles `APPLY` more efficiently for row-by-row correlated lookups, especially if the inner query can use indexes effectively. Correlated subqueries in the `SELECT` list can sometimes lead to less efficient plans (e.g., executing the subquery literally for every single outer row without optimal reuse or indexing). However, the actual performance depends heavily on indexing, data distribution, and the specific query plan generated.
8.  **[Hard]** Can you nest `APPLY` operators (e.g., `FROM TableA CROSS APPLY (...) AS B CROSS APPLY (...) AS C`)?
    *   **Answer:** Yes, you can nest `APPLY` operators. The inner `APPLY` can reference columns from both the original table (`TableA`) and the result of the first `APPLY` (`B`).
9.  **[Hard]** If the table-valued expression used in `APPLY` is a complex query, could this lead to performance issues? How might you mitigate this?
    *   **Answer:** Yes. If the expression executed by `APPLY` for each outer row is itself resource-intensive, the overall query performance can suffer significantly. Mitigation strategies include:
        *   Ensuring the inner query is well-indexed based on the correlation columns.
        *   Simplifying the inner query logic if possible.
        *   If the inner query is non-parameterized and returns the same result repeatedly, consider calculating it once and joining normally.
        *   For very complex inner logic, consider pre-calculating results into a temporary table or indexed view and joining/applying to that instead.
10. **[Hard/Tricky]** Can you use `OUTER APPLY` to simulate a `FULL OUTER JOIN`?
    *   **Answer:** Not directly with a single `OUTER APPLY`. `OUTER APPLY` simulates a `LEFT OUTER JOIN`. To simulate a `FULL OUTER JOIN` using `APPLY`, you would typically need a more complex approach involving combining results, perhaps using `UNION ALL` between a `CROSS APPLY` (for inner matches) and `OUTER APPLY` results filtered for non-matches from both sides, or using two separate `OUTER APPLY` operations unioned together and carefully handling duplicates/NULLs. It's usually much simpler to just use the standard `FULL OUTER JOIN` operator if that's the required logic.
