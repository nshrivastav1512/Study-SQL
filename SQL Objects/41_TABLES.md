# SQL Deep Dive: Tables - Structure and Operations

## 1. Introduction: The Foundation - Tables

Tables are the fundamental objects in a relational database used to store data in a structured format of rows and columns. Each table represents an entity (like Projects, Employees, Departments), each row represents an instance of that entity (a specific project or employee), and each column represents an attribute or property of that entity (Project Name, Employee Salary, Department Location).

Designing and creating tables correctly, including defining appropriate data types and constraints, is crucial for data integrity, performance, and overall database usability.

## 2. Table Operations in Action: Analysis of `41_TABLES.sql`

This script demonstrates various aspects of creating, modifying, and interacting with tables.

**a) Creating Tables (`CREATE TABLE`)**

*   **Basic Structure:**
    ```sql
    CREATE TABLE TableName (
        Column1 DataType [Constraints],
        Column2 DataType [Constraints],
        ...
        [Table-Level Constraints]
    );
    ```
*   **Key Components Demonstrated:**
    *   **Column Definitions:** Assigning a name and data type (`INT`, `VARCHAR`, `DATE`, `DECIMAL`, `DATETIME`, `BIT`, etc.) to each column.
    *   **`IDENTITY(seed, increment)`:** Creates an auto-incrementing integer column, often used for primary keys (e.g., `ProjectID INT PRIMARY KEY IDENTITY(1,1)`).
    *   **`NOT NULL` / `NULL`:** Specifies whether a column must have a value or can accept `NULL`.
    *   **`DEFAULT` Constraint:** Provides a default value if none is specified during `INSERT` (e.g., `Status VARCHAR(20) DEFAULT 'Not Started'`, `CreatedDate DATETIME DEFAULT GETDATE()`).
    *   **`PRIMARY KEY` Constraint:** Uniquely identifies each row in the table. Can be defined inline for a single column or at the table level for composite keys. Enforces entity integrity.
    *   **`FOREIGN KEY` Constraint:** Enforces referential integrity by ensuring values in a column (or columns) match values in the primary key column(s) of another table (e.g., `CONSTRAINT FK_... FOREIGN KEY (ProjectID) REFERENCES Projects(ProjectID)`).
    *   **`CHECK` Constraint:** Enforces a specific business rule or condition on the data in one or more columns (e.g., `CONSTRAINT CHK_... CHECK (CompletionPercentage BETWEEN 0 AND 100)`).
    *   **`UNIQUE` Constraint:** Ensures that all values in a column (or combination of columns) are unique across the table (allows one `NULL` unless part of PK).
    *   **Computed Column:** A column whose value is calculated based on an expression involving other columns in the same table (e.g., `Variance AS (ActualCost - EstimatedCost)`). Can optionally be `PERSISTED` to store the calculated value physically.
    *   **Temporal Tables (System-Versioning):** (SQL Server 2016+) Automatically track historical changes to rows in a separate history table (e.g., `WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = ...))`). Requires `PERIOD FOR SYSTEM_TIME` columns.
    *   **`SPARSE` Columns:** (SQL Server 2008+) Optimize storage for columns that frequently contain `NULL` values. Reduces space usage for `NULL`s but adds slight overhead for non-`NULL` values.
    *   **`FILESTREAM` Columns:** (SQL Server 2008+) Store large binary object (BLOB) data (`VARBINARY(MAX)`) directly in the NTFS file system, managed by SQL Server. Useful for very large files (images, videos, documents). Requires server and database configuration.
    *   **Partitioned Tables:** Physically divide large tables into smaller chunks (partitions) based on a column value (e.g., date range). Requires partition functions and schemes. Improves manageability and potentially query performance (partition elimination).
    *   **Memory-Optimized Tables:** (SQL Server 2014+) Store tables primarily in memory using lock-free structures for high-performance OLTP. Requires specific configuration and index types (HASH, NONCLUSTERED).

**b) Modifying Tables (`ALTER TABLE`)**

```sql
-- Add Column
ALTER TABLE Projects ADD ProjectManager VARCHAR(100);
-- Modify Column Data Type/Size
ALTER TABLE Projects ALTER COLUMN Description VARCHAR(1000);
-- Add Constraint
ALTER TABLE Projects ADD CONSTRAINT CHK_ProjectDates CHECK (...);
-- Drop Column
ALTER TABLE ProjectRisks DROP COLUMN MitigationPlan;
```

*   **Explanation:** Used to change the structure of an existing table, such as adding/dropping columns or constraints, or modifying column properties.

**c) Removing Table Data (`TRUNCATE TABLE`)**

```sql
TRUNCATE TABLE ProjectDocuments;
```

*   **Explanation:** Quickly removes *all* rows from a table but keeps the table structure. Minimally logged and generally faster than `DELETE` for emptying tables. Cannot be used if the table is referenced by foreign keys. Resets identity columns.

**d) Removing Tables (`DROP TABLE`)**

```sql
DROP TABLE ProjectStatus;
DROP TABLE ProjectBudgetItems;
-- ... (Drop dependent tables first)
DROP TABLE Projects;
```

*   **Explanation:** Permanently removes the table definition and all its data. Tables referenced by foreign keys must typically be dropped *after* the referencing tables (or the FK constraints must be dropped first).

**e) Data Manipulation (`INSERT`, `UPDATE`, `DELETE`, `SELECT`)**

```sql
INSERT INTO Projects (...) VALUES (...);
UPDATE Projects SET Status = 'In Progress' WHERE ...;
DELETE FROM Projects WHERE ...;
SELECT * FROM Projects WHERE ... ORDER BY ...;
```

*   **Explanation:** Demonstrates basic DML operations used to interact with the data stored within tables.

**f) Temporary Tables (`#local`, `##global`)**

```sql
CREATE TABLE #TempProjects (...); -- Session-scoped
CREATE TABLE ##GlobalTempProjects (...); -- Instance-scoped
```

*   **Explanation:** Create temporary tables stored in `tempdb`.
    *   Local (`#`): Visible only to the session that created it. Automatically dropped when the session ends (or creating scope exits).
    *   Global (`##`): Visible to all sessions. Dropped when the creating session ends *and* no other sessions are referencing it.

**g) Creating Table from `SELECT` (`SELECT INTO`)**

```sql
SELECT ProjectID, ProjectName, Budget, Status
INTO ProjectsSummary -- Creates NEW table ProjectsSummary
FROM Projects
WHERE Budget > 50000;
```

*   **Explanation:** Creates a *new* table (`ProjectsSummary`) based on the structure and data returned by the `SELECT` statement. The target table must not already exist. Useful for creating copies or subsets of data quickly. Minimal logging often applies under `SIMPLE` or `BULK_LOGGED` recovery models.

## 3. Targeted Interview Questions (Based on `41_TABLES.sql`)

**Question 1:** What is the difference between a `PRIMARY KEY` constraint and a `UNIQUE` constraint?

**Solution 1:**

*   **`PRIMARY KEY`:**
    *   Uniquely identifies each row in the table.
    *   Does **not** allow `NULL` values.
    *   A table can have only **one** primary key (which can consist of one or multiple columns).
    *   Often creates a clustered index by default.
*   **`UNIQUE`:**
    *   Ensures that all values in the column (or combination of columns) are unique across the table.
    *   **Allows one `NULL` value** (multiple `NULL`s might be allowed in some specific older compatibility levels or non-standard implementations, but generally, only one `NULL` is permitted by the constraint itself in standard SQL Server behavior).
    *   A table can have **multiple** unique constraints.
    *   Creates a non-clustered index by default.

**Question 2:** Explain the purpose of the `FOREIGN KEY` constraint used in the `ProjectAssignments` table definition. What does it enforce?

**Solution 2:** The `FOREIGN KEY` constraints (`FK_ProjectAssignments_Projects` and `FK_ProjectAssignments_Employees`) enforce **referential integrity**.
*   `FOREIGN KEY (ProjectID) REFERENCES Projects(ProjectID)` ensures that any `ProjectID` value entered into the `ProjectAssignments` table must already exist as a valid `ProjectID` in the `Projects` table.
*   `FOREIGN KEY (EmployeeID) REFERENCES HR.Employees(EmployeeID)` ensures that any `EmployeeID` entered into `ProjectAssignments` must exist in the `HR.Employees` table.
*   Together, they prevent "orphaned" assignment records – you cannot assign an employee to a non-existent project or assign a non-existent employee to a project. They also typically prevent deleting a project or employee if assignments still exist (unless cascading actions are defined).

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What does `IDENTITY(1,1)` mean when defining a column?
    *   **Answer:** It creates an auto-incrementing integer column. The first value inserted (seed) will be 1, and each subsequent value will increment by 1.
2.  **[Easy]** Can a table have multiple `PRIMARY KEY` constraints?
    *   **Answer:** No, a table can have only one `PRIMARY KEY` constraint (though that key can consist of multiple columns).
3.  **[Medium]** What is the difference between `TRUNCATE TABLE MyTable;` and `DELETE FROM MyTable;` (without a `WHERE` clause)?
    *   **Answer:** Both remove all rows. Key differences:
        *   `TRUNCATE`: DDL operation, minimally logged (faster, less log space), resets identity columns, cannot be used with FK constraints referencing the table, doesn't fire `DELETE` triggers. Requires `ALTER TABLE` permission.
        *   `DELETE`: DML operation, fully logged per row (slower, more log space), does *not* reset identity columns, can be used even with FK constraints (if allowed by data), fires `DELETE` triggers. Requires `DELETE` permission.
4.  **[Medium]** What is a computed column? What does `PERSISTED` mean for a computed column?
    *   **Answer:** A computed column's value is derived from an expression involving other columns in the same table (e.g., `FullName AS (FirstName + ' ' + LastName)`). `PERSISTED` means the calculated value is physically stored in the table like a regular column (and updated when dependencies change), allowing it to be indexed. Non-persisted computed columns are calculated only when queried.
5.  **[Medium]** What is the difference between a local temporary table (`#MyTable`) and a global temporary table (`##MyTable`)?
    *   **Answer:**
        *   Local (`#`): Visible only to the session that created it; automatically dropped when the session ends.
        *   Global (`##`): Visible to all active sessions; dropped only when the session that created it ends *and* no other sessions are still using it.
6.  **[Medium]** Can you add a `NOT NULL` column to an existing table that already contains data without specifying a `DEFAULT` value? What might happen?
    *   **Answer:** Yes, you can try, but it will **fail** if the table has existing rows. Adding a `NOT NULL` column requires *all* rows to have a value for that column. Without a `DEFAULT` constraint to provide a value for existing rows, the `ALTER TABLE` operation cannot satisfy the `NOT NULL` requirement and will raise an error. You must either add the column as `NULL` first, update existing rows, then alter it to `NOT NULL`, or add it as `NOT NULL` *with* a `DEFAULT` constraint.
7.  **[Hard]** What is System-Versioning (Temporal Tables)? What are the two main components created?
    *   **Answer:** System-Versioning (Temporal Tables) is a feature where SQL Server automatically tracks the history of data changes for a table. When a row is updated or deleted, the *previous* version of the row is stored in a separate history table. The two main components are:
        1.  The **Temporal Table:** The main table containing the current data, defined with `SYSTEM_VERSIONING = ON` and two `DATETIME2` columns marking the period of validity (`ValidFrom`, `ValidTo`).
        2.  The **History Table:** A separate table (specified in the `HISTORY_TABLE = ...` clause) with the same schema as the temporal table, which stores the previous versions of rows along with their validity periods.
8.  **[Hard]** What are `SPARSE` columns useful for, and what is a potential trade-off?
    *   **Answer:** `SPARSE` columns are useful for tables where a specific column will contain `NULL` values for a very high percentage of the rows (e.g., many optional attributes). They optimize the storage of `NULL` values, requiring zero space for `NULL`s. The trade-off is that non-`NULL` values in a `SPARSE` column require slightly *more* storage overhead (an extra 4 bytes) than regular columns. They are beneficial only when the percentage of `NULL`s is high enough to offset this extra cost for non-`NULL`s (typically >60-80% NULLs depending on data type).
9.  **[Hard]** Explain the concept of table partitioning. Why might you partition a very large table (e.g., by date)?
    *   **Answer:** Table partitioning involves physically dividing the data of a single large table (and its indexes) into smaller, more manageable chunks called partitions, based on the value of a specific partitioning column (e.g., `OrderDate`, `RegionID`). All partitions reside within the same database but can potentially be placed on different filegroups. Reasons to partition include:
        *   **Manageability:** Easier to load, archive, or delete data by operating on entire partitions (e.g., switching old partitions out, switching new partitions in). Index maintenance can sometimes be done per partition.
        *   **Performance:** Queries that filter on the partitioning key can benefit from **partition elimination**, where the optimizer only scans the relevant partition(s) instead of the entire table, significantly reducing I/O.
10. **[Hard/Tricky]** Can a `FOREIGN KEY` constraint reference a column (or columns) that has a `UNIQUE` constraint but is *not* the `PRIMARY KEY` of the referenced table?
    *   **Answer:** Yes. A `FOREIGN KEY` constraint must reference columns that are guaranteed to be unique in the referenced table. This requirement is met by both `PRIMARY KEY` constraints and `UNIQUE` constraints. Therefore, a foreign key can reference either the primary key or any other column(s) defined with a unique constraint in the parent table.
