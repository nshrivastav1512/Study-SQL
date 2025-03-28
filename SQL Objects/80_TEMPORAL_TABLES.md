# SQL Deep Dive: Temporal Tables (System-Versioned)

## 1. Introduction: What are Temporal Tables?

**Temporal Tables**, also known as **System-Versioned Temporal Tables**, are a feature introduced in SQL Server 2016 that automatically tracks the full history of data changes within a table. When you enable system-versioning on a table, SQL Server automatically creates and manages a corresponding **history table**.

**How it Works:**

1.  **Current Table:** The main table you interact with (e.g., `HR.Employees`). Contains the *current* state of the data.
2.  **History Table:** A hidden or explicitly named table (e.g., `HR.EmployeesHistory`) that stores *previous versions* of rows from the current table.
3.  **System Time Period Columns:** Two `datetime2` columns are added to the current table, typically named `ValidFrom` and `ValidTo` (or similar, defined by `PERIOD FOR SYSTEM_TIME`).
    *   `ValidFrom`: Stores the time when the row version became current (e.g., when it was inserted or last updated). Managed by SQL Server (`GENERATED ALWAYS AS ROW START`).
    *   `ValidTo`: Stores the time when the row version ceased to be current (i.e., when it was updated or deleted). For currently active rows, this is set to a maximum `datetime2` value (e.g., '9999-12-31...'). Managed by SQL Server (`GENERATED ALWAYS AS ROW END`).
4.  **Automatic History Tracking:** When a row in the current table is `UPDATE`d or `DELETE`d:
    *   SQL Server automatically sets the `ValidTo` timestamp of the *old* row version in the current table to the current transaction time.
    *   SQL Server then inserts a copy of this *old* row version (with its original `ValidFrom` and the newly set `ValidTo`) into the associated **history table**.
    *   If it was an `UPDATE`, the *new* row version is updated in the current table with `ValidFrom` set to the current transaction time and `ValidTo` set to the maximum value.
    *   If it was a `DELETE`, the row is simply removed from the current table after its old version is moved to history.

**Why use Temporal Tables?**

*   **Auditing/History Tracking:** Automatically maintain a full history of data changes without complex triggers or application logic. Easily see how data looked at any point in the past.
*   **Point-in-Time Analysis:** Query the state of the data as it existed at any specific time using the `FOR SYSTEM_TIME AS OF` clause.
*   **Trend Analysis:** Analyze how data has changed over specific periods using `FOR SYSTEM_TIME FROM ... TO ...` or `BETWEEN ... AND ...`.
*   **Data Recovery:** Potentially recover accidentally deleted or modified data by querying the history table.
*   **Compliance:** Meet regulatory requirements that mandate tracking data history.

## 2. Temporal Tables in Action: Analysis of `80_TEMPORAL_TABLES.sql`

This script demonstrates creating, modifying, and querying temporal tables.

**Part 1: Creating Temporal Tables**

```sql
-- Drop existing history/current tables if they exist
IF OBJECT_ID('HR.EmployeesHistory', 'U') IS NOT NULL DROP TABLE HR.EmployeesHistory;
IF OBJECT_ID('HR.Employees', 'U') IS NOT NULL DROP TABLE HR.Employees;

CREATE TABLE HR.Employees (
    EmployeeID INT PRIMARY KEY CLUSTERED,
    ...,
    -- System Period Columns
    ValidFrom DATETIME2(7) GENERATED ALWAYS AS ROW START,
    ValidTo DATETIME2(7) GENERATED ALWAYS AS ROW END,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo) -- Define the period
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = HR.EmployeesHistory)); -- Enable versioning
```

*   **Explanation:**
    1.  Defines the main table (`HR.Employees`).
    2.  Includes two `DATETIME2` columns (`ValidFrom`, `ValidTo`) marked `GENERATED ALWAYS AS ROW START/END`. These will be managed by the system.
    3.  Defines the `PERIOD FOR SYSTEM_TIME` using these two columns.
    4.  Uses `WITH (SYSTEM_VERSIONING = ON (...))` to enable temporal tracking.
    5.  Specifies the name of the history table (`HISTORY_TABLE = HR.EmployeesHistory`). If omitted, SQL Server generates a default name. SQL Server automatically creates the history table with a matching schema plus the period columns.

**Part 2: Inserting and Modifying Data**

```sql
-- Standard INSERT affects only the current table
INSERT INTO HR.Employees (EmployeeID, FirstName, ...) VALUES (1, 'John', ...);

-- Standard UPDATE modifies the current table AND inserts old version into history
UPDATE HR.Employees SET Salary = 80000.00 WHERE EmployeeID = 4;

-- Standard DELETE removes from current table AND inserts old version into history
-- DELETE FROM HR.Employees WHERE EmployeeID = 3; (Conceptual)
```

*   **Explanation:** You interact with the *current* table using standard `INSERT`, `UPDATE`, `DELETE` statements. SQL Server automatically handles populating the history table whenever rows are updated or deleted from the current table. You do *not* directly modify the history table or the `ValidFrom`/`ValidTo` columns.

**Part 3: Querying Temporal Data (`FOR SYSTEM_TIME`)**

*   **New `FOR SYSTEM_TIME` Clause:** Added to `SELECT` statements to query historical data.
    *   **`AS OF 'datetime'`:** Returns rows that were valid (current) at the specified point in time. Queries both current and history tables.
        ```sql
        SELECT * FROM HR.Departments FOR SYSTEM_TIME AS OF '2023-03-01T10:00:00';
        ```
    *   **`FROM 'start_datetime' TO 'end_datetime'`:** Returns all row versions that were active *at any point* between the start time (inclusive) and end time (exclusive). Queries the history table.
    *   **`BETWEEN 'start_datetime' AND 'end_datetime'`:** Returns all row versions that were active *at any point* between the start time (inclusive) and end time (inclusive). Queries the history table.
    *   **`CONTAINED IN ('start_datetime', 'end_datetime')`:** Returns row versions that were *created and ended* entirely within the specified time range (exclusive start, inclusive end). Queries the history table.
    *   **`ALL`:** Returns the union of all rows from *both* the current table and the history table.
        ```sql
        SELECT ..., ValidFrom, ValidTo FROM HR.Employees FOR SYSTEM_TIME ALL WHERE EmployeeID = 4;
        ```
*   **Examples:**
    *   `HR.GetEmployeeHistory`: Uses `FOR SYSTEM_TIME ALL` and `LEAD()` window function to reconstruct the timeline of changes for a specific employee.
    *   `HR.GetDepartmentStructure`: Uses `FOR SYSTEM_TIME AS OF @AsOfDate` to show the organizational structure and budget as it existed at a specific past date.
    *   `HR.AnalyzeSalaryChanges`: Uses `FOR SYSTEM_TIME FROM @StartDate TO @EndDate` and `LAG()` to find salary changes within a specified period.

**Part 4: Analyzing Historical Trends**

*   Provides more complex examples using temporal queries (`FOR SYSTEM_TIME ALL` or `FROM...TO`) combined with window functions (`LAG`) or aggregation (`COUNT`, `AVG`) to analyze budget history or employee turnover rates over time.

**Part 5: Maintaining Temporal Tables**

*   **1. Cleanup:** History tables can grow very large. The script shows a procedure (`HR.CleanupHistoricalData`) to periodically remove old history. This requires temporarily turning system versioning OFF, deleting from the history table, and then turning versioning back ON.
    ```sql
    ALTER TABLE HR.Employees SET (SYSTEM_VERSIONING = OFF);
    DELETE FROM HR.EmployeesHistory WHERE ValidTo < @RetentionDate;
    ALTER TABLE HR.Employees SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = HR.EmployeesHistory));
    ```
*   **2. Optimization:** Recommends creating indexes (especially clustered, often on `ValidTo`, `ValidFrom` or the original PK) on the *history table* to improve the performance of temporal queries that access historical data.
    ```sql
    CREATE NONCLUSTERED INDEX IX_EmployeesHistory_ValidFrom ON HR.EmployeesHistory(ValidFrom);
    ```

## 3. Targeted Interview Questions (Based on `80_TEMPORAL_TABLES.sql`)

**Question 1:** What is the purpose of the `ValidFrom` and `ValidTo` columns in a system-versioned temporal table? Who manages these columns?

**Solution 1:**
*   **Purpose:** These two `datetime2` columns define the period of time for which a specific row version was the "current" version in the main table. `ValidFrom` indicates when the row version became current, and `ValidTo` indicates when it ceased to be current (due to an update or delete). For currently active rows, `ValidTo` holds a maximum sentinel value ('9999-12-31...').
*   **Managed By:** These columns are managed entirely by **SQL Server** when `SYSTEM_VERSIONING` is `ON`. They must be defined using `GENERATED ALWAYS AS ROW START` and `GENERATED ALWAYS AS ROW END`, and users cannot directly insert or update values into them.

**Question 2:** How would you query the `HR.Employees` table to see exactly what an employee's record looked like at noon on March 15th, 2023?

**Solution 2:** You would use the `FOR SYSTEM_TIME AS OF` clause in your `SELECT` statement:
```sql
SELECT *
FROM HR.Employees FOR SYSTEM_TIME AS OF '2023-03-15T12:00:00';
-- Optionally add a WHERE clause for the specific employee
-- WHERE EmployeeID = @SpecificEmployeeID;
```

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What clause is added to `CREATE TABLE` to enable system versioning?
    *   **Answer:** `WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = Schema.HistoryTableName))`
2.  **[Easy]** Can you directly `INSERT` data into the history table of a temporal table?
    *   **Answer:** No, not while system versioning is `ON`. The history table is managed automatically by SQL Server.
3.  **[Medium]** What happens to the `ValidTo` column in the *current* table when you `UPDATE` a row in a temporal table? What happens in the *history* table?
    *   **Answer:**
        *   **Current Table:** The `ValidTo` value of the *existing* row version is updated from the maximum date to the current transaction time. The *new* row version resulting from the update gets the current transaction time as its `ValidFrom` and the maximum date as its `ValidTo`.
        *   **History Table:** A copy of the *old* row version (with its original `ValidFrom` and the newly updated `ValidTo` timestamp) is inserted into the history table.
4.  **[Medium]** What is the difference between `FOR SYSTEM_TIME FROM 't1' TO 't2'` and `FOR SYSTEM_TIME BETWEEN 't1' AND 't2'`?
    *   **Answer:** The difference lies in the inclusivity of the end time (`t2`):
        *   `FROM 't1' TO 't2'`: Includes rows active *after or at* `t1` and *before* `t2`. (Inclusive start, Exclusive end).
        *   `BETWEEN 't1' AND 't2'`: Includes rows active *after or at* `t1` and *before or at* `t2`. (Inclusive start, Inclusive end).
5.  **[Medium]** Can the history table have a different schema (e.g., different indexes, constraints) than the current table?
    *   **Answer:** The history table must initially have the exact same columns, names, and data types as the current table (excluding computed columns, identity, etc.). However, after creation, you *can* add specific non-clustered indexes (especially columnstore or rowstore optimized for history queries) to the history table that don't exist on the current table. It's generally recommended to have a clustered index on the history table (often on `(ValidTo, ValidFrom)` or `(PK, ValidTo, ValidFrom)`). You cannot have constraints like `FOREIGN KEY`, `PRIMARY KEY`, or `UNIQUE` on the history table itself (though the data reflects constraints held when it was current).
6.  **[Medium]** What happens if you try to drop a temporal table (`DROP TABLE HR.Employees`) without first disabling system versioning?
    *   **Answer:** The `DROP TABLE` statement will fail. You must first disable system versioning using `ALTER TABLE HR.Employees SET (SYSTEM_VERSIONING = OFF);` before you can drop either the current table or the history table. After disabling, you can drop both tables independently.
7.  **[Hard]** How can you efficiently remove historical data older than, say, 5 years from a temporal table's history?
    *   **Answer:** You need to temporarily disable system versioning, delete the old data directly from the history table, and then re-enable system versioning.
        ```sql
        DECLARE @RetentionDate DATETIME2 = DATEADD(YEAR, -5, GETDATE());
        ALTER TABLE YourTable SET (SYSTEM_VERSIONING = OFF);
        DELETE FROM YourHistoryTable WHERE ValidTo < @RetentionDate;
        ALTER TABLE YourTable SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = YourSchema.YourHistoryTable));
        ```
        For very large history tables, deleting in batches or using partition switching on the history table (if partitioned) might be necessary to manage log growth and performance.
8.  **[Hard]** Can you use `TRUNCATE TABLE` on a temporal table or its history table?
    *   **Answer:** No. `TRUNCATE TABLE` is not supported on system-versioned temporal tables (neither the current nor the history table) while system versioning is `ON`. You must disable versioning first (`ALTER TABLE ... SET (SYSTEM_VERSIONING = OFF)`), after which you could potentially truncate the history table (or the current table if desired), and then re-enable versioning.
9.  **[Hard]** If you query a temporal table `FOR SYSTEM_TIME AS OF 'SomePastTime'`, does the query optimizer use statistics from the current table or the history table (or both)?
    *   **Answer:** The query optimizer uses statistics from the **current table** when generating the execution plan, even when the `FOR SYSTEM_TIME` clause causes it to read data primarily from the **history table**. This can sometimes lead to suboptimal plans if the data distribution in the history table is significantly different from the current table. Keeping statistics updated on the current table is still important, and in some cases, specific query hints or plan guides might be needed for complex historical queries if performance is poor due to inaccurate estimates based on current statistics.
10. **[Hard/Tricky]** Can you add a new column to a temporal table? What happens to the history table?
    *   **Answer:** Yes, you can add a new column to the current temporal table using `ALTER TABLE ... ADD COLUMN ...`. SQL Server automatically adds the same column (with a default value, typically `NULL`) to the associated history table as well. The schema of the current table and the history table are kept synchronized by the system.
