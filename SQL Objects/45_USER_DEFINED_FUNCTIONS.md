# SQL Deep Dive: User-Defined Functions (UDFs)

## 1. Introduction: What are User-Defined Functions?

User-Defined Functions (UDFs) in SQL Server are routines that accept parameters, perform an action (like a complex calculation or data retrieval), and return the result of that action. Unlike stored procedures (which can perform DML/DDL and return multiple result sets or output parameters), functions are primarily designed to encapsulate calculations or queries and return either a single value (scalar) or a table (table-valued).

**Why use Functions?**

*   **Encapsulation & Reusability:** Encapsulate complex calculations or frequently used logic into a reusable unit.
*   **Modularity:** Break down complex queries into smaller, more manageable functions.
*   **Maintainability:** Update logic in one place (the function definition).
*   **Usage in Queries:** Can be used directly within `SELECT` lists, `WHERE` clauses, `JOIN` conditions, `CHECK` constraints, or computed column definitions (with restrictions).

**Types of UDFs:**

1.  **Scalar Functions:** Return a single data value of a defined type (e.g., `INT`, `VARCHAR`, `DECIMAL`, `DATE`).
2.  **Table-Valued Functions (TVFs):** Return a table result set.
    *   **Inline TVFs (ITVFs):** Defined with a single `RETURN (SELECT ...)` statement. Often perform better as they can be expanded ("inlined") into the calling query plan like a view.
    *   **Multi-Statement TVFs (MSTVFs):** Defined with `BEGIN...END` block, allowing multiple T-SQL statements to build the result table (declared using `RETURNS @ResultTable TABLE (...)`). Generally less performant than ITVFs as the optimizer treats them more like a black box and often estimates only 1 or 100 rows.

**Restrictions (General):**

*   Standard T-SQL UDFs **cannot** perform actions that modify the database state (no `INSERT`, `UPDATE`, `DELETE` on permanent tables). They are primarily for reading data or performing calculations.
*   Cannot use dynamic SQL (usually).
*   Cannot use non-deterministic built-in functions (like `GETDATE()`) unless the function has `WITH SCHEMABINDING`.
*   Performance can be an issue, especially with scalar UDFs used in `WHERE` clauses (often executed row-by-row) or MSTVFs (poor cardinality estimates).

## 2. Functions in Action: Analysis of `45_USER_DEFINED_FUNCTIONS.sql`

This script demonstrates creating and using different types of UDFs.

**a) Scalar Function (`RETURNS scalar_type`)**

```sql
CREATE FUNCTION fn_CalculateProjectDuration (@StartDate DATE, @EndDate DATE)
RETURNS INT
AS
BEGIN
    DECLARE @Duration INT = DATEDIFF(DAY, @StartDate, @EndDate);
    RETURN @Duration;
END;
GO
-- Usage: SELECT dbo.fn_CalculateProjectDuration(StartDate, EndDate) FROM Projects;
```

*   **Explanation:** Takes start and end dates, calculates the difference in days, and returns a single `INT` value.

**b) Inline Table-Valued Function (ITVF) (`RETURNS TABLE AS RETURN (SELECT...)`)**

```sql
CREATE FUNCTION fn_GetProjectsByStatus (@Status VARCHAR(20))
RETURNS TABLE -- No table definition needed here
AS
RETURN ( -- Single SELECT statement defines the returned table
    SELECT ProjectID, ProjectName, ... FROM Projects WHERE Status = @Status
);
GO
-- Usage: SELECT * FROM dbo.fn_GetProjectsByStatus('In Progress');
-- Usage: SELECT p.*, f.* FROM Projects p CROSS APPLY dbo.fn_GetProjectsByStatus(p.Status) f WHERE ...;
```

*   **Explanation:** Returns a table result set defined by a single `SELECT` statement. Often performant because the optimizer can inline the function's logic into the calling query's plan.

**c) Multi-Statement Table-Valued Function (MSTVF) (`RETURNS @table TABLE (...) BEGIN...END`)**

```sql
CREATE FUNCTION fn_GetProjectPerformanceMetrics (@ProjectID INT)
RETURNS @Results TABLE ( -- Define return table structure
    MetricName VARCHAR(50), MetricValue DECIMAL(18,2), ...
)
AS
BEGIN -- Multiple statements allowed
    -- Declare variables, perform calculations, SELECT data...
    DECLARE @Budget DECIMAL(15,2); SELECT @Budget = Budget FROM Projects WHERE ...;
    -- Insert calculated rows into the return table variable
    INSERT INTO @Results (MetricName, MetricValue, ...) VALUES ('Budget', @Budget, ...);
    INSERT INTO @Results (MetricName, MetricValue, ...) VALUES ('Actual Cost', @ActualCost, ...);
    -- Must end with RETURN (no value specified for MSTVF)
    RETURN;
END;
GO
-- Usage: SELECT * FROM dbo.fn_GetProjectPerformanceMetrics(123);
```

*   **Explanation:** Defines the structure of the table variable (`@Results`) to be returned. Allows multiple T-SQL statements within the `BEGIN...END` block to populate this table variable. Less performant than ITVFs generally, as the optimizer has limited visibility into the logic and often makes poor row count estimates.

**d) Function with Table-Valued Parameter (TVP)**

```sql
-- Requires CREATE TYPE ProjectBudgetItemsTableType AS TABLE (...);
CREATE FUNCTION fn_CalculateTotalCost (@Items ProjectBudgetItemsTableType READONLY)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @TotalCost DECIMAL(18,2);
    SELECT @TotalCost = SUM(EstimatedCost) FROM @Items; -- Use TVP like a table
    RETURN ISNULL(@TotalCost, 0);
END;
GO
```

*   **Explanation:** A scalar function that accepts a TVP (`@Items`) as input. It can query the TVP like a regular table to perform calculations (here, summing costs).

**e) Function with `CASE` Statement**

```sql
CREATE FUNCTION fn_GetProjectStatusCategory (@Status VARCHAR(20))
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @Category VARCHAR(20);
    SELECT @Category = CASE WHEN @Status = '...' THEN '...' ELSE '...' END;
    RETURN @Category;
END;
GO
```

*   **Explanation:** Demonstrates using `CASE` logic within a scalar function to return a derived value based on input.

**f) Function with Error Handling (Returning Status Code)**

```sql
CREATE FUNCTION fn_GetProjectBudgetUtilization (@ProjectID INT)
RETURNS DECIMAL(5,2)
AS
BEGIN ...
    IF @Budget IS NULL RETURN -1; -- Return error code if project not found
    IF @Budget = 0 SET @Utilization = 0; ELSE SET @Utilization = (...);
    RETURN @Utilization;
END;
GO
```

*   **Explanation:** Shows basic error handling in a scalar function by returning a specific value (like -1) to indicate an error condition (e.g., project not found). *Note: Functions cannot use `THROW` or `RAISERROR` directly to signal errors like procedures can.*

**g) Recursive Function (Use with Caution)**

```sql
CREATE FUNCTION fn_CalculateFactorial (@Number INT) RETURNS BIGINT AS
BEGIN
    IF @Number <= 1 RETURN 1;
    RETURN @Number * dbo.fn_CalculateFactorial(@Number - 1); -- Calls itself
END;
GO
```

*   **Explanation:** Demonstrates a scalar function calling itself recursively. Requires a base case (`IF @Number <= 1`) to terminate. Subject to a maximum nesting level (default 32), similar to procedures. Recursive functions can be complex and potentially inefficient. Recursive CTEs are often preferred for hierarchical data queries.

**h) Function with Dynamic SQL (Not Recommended/Limited)**

```sql
CREATE FUNCTION fn_GetTableRowCount (@TableName NVARCHAR(128)) RETURNS INT AS
BEGIN ...
    SET @SQL = N'SELECT @RowCountOUT = COUNT(*) FROM ' + QUOTENAME(@TableName);
    -- EXEC sp_executesql @SQL, N'@RowCountOUT INT OUTPUT', @RowCountOUT = @RowCount OUTPUT; -- THIS IS PROBLEMATIC
    -- Standard UDFs cannot execute dynamic SQL that performs data access or certain system procedures.
    RETURN @RowCount; -- This implementation likely won't work as intended in standard UDFs.
END;
GO
```

*   **Explanation:** The script attempts to show dynamic SQL, but standard T-SQL UDFs have significant restrictions and **cannot execute dynamic SQL (`sp_executesql` or `EXEC()`) that accesses user tables or modifies data**. They also cannot call procedures that modify state. This example is unlikely to work as written in a standard function due to these limitations. CLR functions offer more flexibility here but come with their own complexities.

**i/j) Functions with JSON/XML Operations**

```sql
CREATE FUNCTION fn_ParseProjectTags (@JSONTags NVARCHAR(MAX)) RETURNS TABLE AS RETURN (SELECT ... FROM OPENJSON(@JSONTags));
GO
CREATE FUNCTION fn_ExtractProjectXMLData (@XMLData XML) RETURNS TABLE AS RETURN (SELECT ... FROM @XMLData.nodes('...') AS T(N));
GO
```

*   **Explanation:** Demonstrates using built-in JSON (`OPENJSON`) and XML (`.nodes()`, `.value()`) functions within UDFs (specifically ITVFs here) to parse and return structured data from semi-structured inputs.

**k/l) Functions with Date/Time or String Operations**

```sql
CREATE FUNCTION fn_GetWorkingDays (@StartDate DATE, @EndDate DATE) RETURNS INT AS BEGIN ... END;
GO
CREATE FUNCTION fn_FormatProjectCode (@ProjectName VARCHAR(100), @ProjectID INT) RETURNS VARCHAR(20) AS BEGIN ... END;
GO
```

*   **Explanation:** Common use cases for scalar functions: encapsulating complex date calculations (like finding business days) or string formatting logic.

**m) Altering a Function (`ALTER FUNCTION`)**

```sql
ALTER FUNCTION fn_CalculateProjectDuration (...) RETURNS INT AS BEGIN ... END;
GO
```

*   **Explanation:** Modifies the definition of an existing function. Preserves permissions.

**n) Dropping a Function (`DROP FUNCTION`)**

```sql
DROP FUNCTION fn_CalculateFactorial;
GO
```

*   **Explanation:** Removes the function definition from the database.

**o) Using Functions in Queries**

```sql
-- Scalar in SELECT list
SELECT ..., dbo.fn_CalculateProjectDuration(StartDate, EndDate) AS Duration FROM Projects;
-- Scalar in WHERE clause (potential performance issue)
SELECT ... FROM Projects WHERE dbo.fn_GetProjectBudgetUtilization(ProjectID) > 75;
-- ITVF in FROM clause (like a table)
SELECT * FROM dbo.fn_GetProjectsByStatus('In Progress');
-- ITVF/MSTVF with APPLY
SELECT p.*, m.* FROM Projects p CROSS APPLY dbo.fn_GetProjectPerformanceMetrics(p.ProjectID) m;
```

*   **Explanation:** Shows how scalar functions are called using `dbo.FunctionName(params)` and TVFs are referenced in the `FROM` clause (often with `APPLY` for correlated parameters).

**p) Function Performance (`WITH SCHEMABINDING`)**

```sql
CREATE FUNCTION fn_GetProjectBudgetWithSchemabinding (@ProjectID INT)
RETURNS DECIMAL(15,2) WITH SCHEMABINDING -- Schema binding
AS BEGIN ... END;
GO
```

*   **Explanation:** Using `WITH SCHEMABINDING` binds the function to the schema of underlying objects. This prevents schema changes that would break the function and allows the optimizer to potentially generate more efficient plans, as it knows the underlying objects won't change unexpectedly. It's required for functions used in indexed views or computed columns.

**q) CLR Function (Conceptual)**

*   **Explanation:** Mentions Common Language Runtime (CLR) functions, which are written in .NET languages (like C#), compiled into an assembly, and registered within SQL Server. They can perform operations not possible or efficient in T-SQL (e.g., complex string manipulation via regex, accessing external resources - though requires higher permission sets).

**r) Function for Data Validation**

```sql
CREATE FUNCTION fn_IsValidEmail (@Email VARCHAR(255)) RETURNS BIT AS BEGIN ... END;
-- Could be used in a CHECK constraint: ALTER TABLE ... ADD CONSTRAINT CHK_Email CHECK (dbo.fn_IsValidEmail(Email) = 1);
```

*   **Explanation:** Encapsulates validation logic (here, a simple email format check) in a function. This function can then be reused, for example, within a `CHECK` constraint to enforce the validation rule during `INSERT`s and `UPDATE`s.

## 3. Targeted Interview Questions (Based on `45_USER_DEFINED_FUNCTIONS.sql`)

**Question 1:** What are the three main types of User-Defined Functions in SQL Server, and what does each return?

**Solution 1:**
1.  **Scalar Function:** Returns a single data value (e.g., `INT`, `VARCHAR`, `DECIMAL`).
2.  **Inline Table-Valued Function (ITVF):** Returns a `TABLE` result set, defined by a single `SELECT` statement within the `RETURN (...)` clause.
3.  **Multi-Statement Table-Valued Function (MSTVF):** Returns a `TABLE` result set, defined by declaring a table variable (`RETURNS @TableName TABLE (...)`) and populating it using multiple T-SQL statements within a `BEGIN...END` block.

**Question 2:** Why are Inline Table-Valued Functions (ITVFs) generally preferred over Multi-Statement Table-Valued Functions (MSTVFs) for performance?

**Solution 2:** ITVFs are generally preferred for performance because the query optimizer can often "inline" the function's single `SELECT` statement directly into the execution plan of the calling query, similar to how it expands a view definition. This allows the optimizer to consider the function's logic and underlying table statistics when optimizing the overall query. MSTVFs, however, are treated more like black boxes; the optimizer typically makes fixed, often inaccurate, row count estimates (like 1 or 100 rows in older versions) for the table variable returned by the MSTVF, which can lead to highly inefficient plans for the calling query, especially if the MSTVF actually returns many rows.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can a standard T-SQL scalar function modify data in a permanent table (e.g., perform an `UPDATE`)?
    *   **Answer:** No. Standard UDFs are not allowed to have side effects that modify the database state.
2.  **[Easy]** How do you call a scalar function in a `SELECT` statement?
    *   **Answer:** Using `dbo.FunctionName(parameters)` in the `SELECT` list or `WHERE` clause (or other expressions).
3.  **[Medium]** How do you call/use a Table-Valued Function (TVF) in a query?
    *   **Answer:** You reference it in the `FROM` clause like a table (e.g., `FROM dbo.FunctionName(parameters)`). Often used with `CROSS APPLY` or `OUTER APPLY` if passing parameters from another table in the query.
4.  **[Medium]** What is the purpose of the `READONLY` keyword when defining a Table-Valued Parameter (TVP) in a function or procedure?
    *   **Answer:** It indicates that the table-valued parameter cannot be modified (no `INSERT`, `UPDATE`, `DELETE`) within the body of the function or procedure. This is mandatory for TVPs passed as parameters.
5.  **[Medium]** Can a function created `WITH SCHEMABINDING` reference tables without using two-part names (e.g., `SELECT * FROM MyTable` instead of `SELECT * FROM dbo.MyTable`)?
    *   **Answer:** No. Schema-bound objects (functions, views) require that all referenced objects (tables, views, other functions) within their definition are specified using two-part names (`SchemaName.ObjectName`).
6.  **[Medium]** Why can using a scalar UDF in the `WHERE` clause of a query often lead to poor performance, especially on large tables?
    *   **Answer:** SQL Server often executes scalar UDFs used in a `WHERE` clause in a row-by-row fashion (iteratively for each row being checked). This prevents set-based processing and often makes the predicate non-SARGable, leading to table/index scans instead of seeks, which is very inefficient on large tables.
7.  **[Hard]** What is the difference in the `RETURNS` clause definition between an Inline TVF and a Multi-Statement TVF?
    *   **Answer:**
        *   **Inline TVF:** `RETURNS TABLE AS RETURN (SELECT ...)` - Simply specifies `RETURNS TABLE` and the body is a single `RETURN (SELECT...)`.
        *   **Multi-Statement TVF:** `RETURNS @ReturnTable TABLE (Column1 DataType, ...)` - Explicitly defines the structure (columns and data types) of the table variable that will be returned. The body uses `BEGIN...END` and populates this table variable before the final `RETURN`.
8.  **[Hard]** Can a UDF call a stored procedure?
    *   **Answer:** No. Standard T-SQL UDFs cannot execute stored procedures (especially those that modify data or have side effects) because functions are expected not to alter database state.
9.  **[Hard]** Can a function be deterministic or non-deterministic? What does `WITH SCHEMABINDING` imply about determinism?
    *   **Answer:** Yes, functions can be deterministic (always return the same result for the same input values) or non-deterministic (can return different results for the same input, e.g., `GETDATE()` or functions querying tables). Functions created `WITH SCHEMABINDING` must be deterministic (or at least treated as such by the engine in certain contexts). Schema binding implies the function's output depends only on its inputs and the schema-bound objects it references, not external state, allowing it to be used in contexts requiring determinism like indexed views or persisted computed columns.
10. **[Hard/Tricky]** If an Inline TVF (ITVF) is generally faster than a Multi-Statement TVF (MSTVF), why would you ever use an MSTVF?
    *   **Answer:** You would use an MSTVF when the logic required to generate the result table cannot be expressed within a single `SELECT` statement. MSTVFs allow for imperative logic, multiple steps, variable assignments, temporary table usage (though limited), conditional logic (`IF`/`ELSE`), and loops (`WHILE`) to build the result set in the table variable before returning it. This flexibility is sometimes necessary despite the potential performance cost compared to an ITVF.
