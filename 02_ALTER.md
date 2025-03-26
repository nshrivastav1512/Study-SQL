# SQL Deep Dive: The `ALTER` Statement

## 1. Introduction: What is `ALTER`?

The `ALTER` statement is another crucial **Data Definition Language (DDL)** command in SQL. While `CREATE` builds new objects and `DROP` removes them, `ALTER` is used to **modify the structure or properties of existing database objects**. Think of it as the renovation tool for your database.

**Why is it important?**

*   **Evolution:** Database requirements change over time. `ALTER` allows you to adapt your database structure without having to drop and recreate objects (which would lose data).
*   **Maintenance:** Used for tasks like rebuilding indexes for performance or modifying constraints.
*   **Refinement:** Allows adding columns, changing data types, modifying views, procedures, functions, and more as application logic evolves.

**General Syntax:**

The syntax varies significantly depending on the object type being altered and the specific modification being made. A common pattern is:

```sql
ALTER [OBJECT_TYPE] [object_name]
[Action_Keyword] [Modification_Details]; -- e.g., ADD COLUMN, ALTER COLUMN, MODIFY NAME, REBUILD, etc.
```

Where `[OBJECT_TYPE]` could be `DATABASE`, `SCHEMA`, `TABLE`, `INDEX`, `VIEW`, `PROCEDURE`, `FUNCTION`, `TRIGGER`, `ROLE`, etc.

## 2. `ALTER` in Action: Analysis of `02_ALTER.sql`

This script demonstrates the wide-ranging capabilities of the `ALTER` command (and related concepts like `GRANT`/`REVOKE` for permissions) in SQL Server.

**a) `ALTER DATABASE`**

```sql
ALTER DATABASE HRSystem
MODIFY NAME = HRSystemPro;
GO
-- Reverting for consistency
ALTER DATABASE HRSystemPro
MODIFY NAME = HRSystem;
GO
```

*   **Explanation:** Used here to rename an existing database. Note that renaming a database in use can have significant implications for connection strings and dependent applications. The script thoughtfully renames it back.

**b) `ALTER SCHEMA` / `ALTER AUTHORIZATION`**

```sql
CREATE SCHEMA EXEC; -- Create first
GO
ALTER AUTHORIZATION ON SCHEMA::EXEC TO dbo;
GO
```

*   **Explanation:** While `CREATE SCHEMA` makes the schema, `ALTER AUTHORIZATION ON SCHEMA::[SchemaName] TO [Principal]` is used to change the *owner* of an existing schema. Here, ownership of the `EXEC` schema is transferred to the `dbo` (database owner) principal.

**c) `ALTER TABLE`**

This is one of the most frequent uses of `ALTER`. The script shows several common table modifications:

*   **Adding Columns:**
    ```sql
    ALTER TABLE HR.Departments
    ADD Description VARCHAR(200),
        IsActive BIT DEFAULT 1;
    ```
    *   Adds two new columns (`Description`, `IsActive`) to the `HR.Departments` table. `IsActive` is given a `DEFAULT` constraint.

*   **Modifying Columns:**
    ```sql
    ALTER TABLE HR.Locations
    ALTER COLUMN City VARCHAR(100);
    ```
    *   Changes the data type (or size, nullability, etc.) of an existing column. Here, the `City` column's maximum length is increased to 100 characters. *Caution:* Modifying data types can fail if existing data is incompatible with the new type or size.

*   **Adding Constraints:**
    ```sql
    ALTER TABLE HR.Departments
    ADD CONSTRAINT FK_Departments_Locations -- Add Foreign Key
    FOREIGN KEY (LocationID) REFERENCES HR.Locations(LocationID);

    ALTER TABLE HR.EMP_Details
    ADD CONSTRAINT CHK_Salary_Range CHECK (Salary BETWEEN 1000 AND 500000); -- Add Check
    ```
    *   Adds new constraints (`FOREIGN KEY`, `CHECK`) to enforce data integrity rules after the table has been created. Naming constraints (`FK_...`, `CHK_...`) is crucial for managing them later.

*   **Dropping Constraints:**
    ```sql
    ALTER TABLE HR.EMP_Details
    DROP CONSTRAINT CHK_Salary;
    ```
    *   Removes an existing constraint from a table, identified by its name.

*   **Enabling/Disabling Constraints:**
    ```sql
    ALTER TABLE HR.EMP_Details
    NOCHECK CONSTRAINT CHK_Salary_Range; -- Disable check during bulk load, maybe?

    ALTER TABLE HR.EMP_Details
    CHECK CONSTRAINT CHK_Salary_Range; -- Re-enable check
    ```
    *   Temporarily disables (`NOCHECK`) or re-enables (`CHECK`) a constraint. This is sometimes done during large data loads to improve performance, but requires careful validation afterward to ensure data integrity wasn't violated while the constraint was disabled.

**d) `ALTER INDEX`**

Used for index maintenance:

*   **Disabling:**
    ```sql
    ALTER INDEX IX_EMP_Details_Email ON HR.EMP_Details DISABLE;
    ```
    *   Keeps the index definition but makes it unusable by the query optimizer and stops maintaining it. Can be useful before large data modifications on the table.

*   **Rebuilding:**
    ```sql
    ALTER INDEX IX_EMP_Details_Email ON HR.EMP_Details REBUILD;
    ```
    *   Drops and recreates the index. This removes fragmentation, reclaims disk space, and recomputes statistics. Can be done online (Enterprise Edition) or offline.

*   **Reorganizing:**
    ```sql
    ALTER INDEX IX_EMP_Details_DepartmentID ON HR.EMP_Details REORGANIZE;
    ```
    *   Defragments the leaf level of the index *in place*. It's less resource-intensive than `REBUILD` and is always an online operation, but may not be as effective for heavily fragmented indexes.

**e) `ALTER VIEW`**

```sql
ALTER VIEW HR.vw_EmployeeDetails
AS
-- Modified SELECT statement...
SELECT
    ...,
    d.Description AS DepartmentDescription, -- Added column from altered table
    l.State, -- Added column
    HR.fn_GetEmployeeYearsOfService(e.EmployeeID) AS YearsOfService -- Used altered function
FROM ... ;
GO
```

*   **Explanation:** Modifies the definition of an existing view. Here, the underlying `SELECT` statement is changed to include new columns (`DepartmentDescription`, `State`) and utilize the altered function `fn_GetEmployeeYearsOfService`.

**f) `ALTER PROCEDURE`**

```sql
ALTER PROCEDURE HR.sp_UpdateEmployeeSalary
    @EmployeeID INT,
    @NewSalary DECIMAL(12,2),
    @EffectiveDate DATE = NULL -- Added optional parameter with default
AS
BEGIN
    -- Added validation logic
    IF @NewSalary < 1000 OR @NewSalary > 500000
    BEGIN
        THROW ...; RETURN;
    END

    -- Improved TRY/CATCH and transaction handling
    -- Added success/error message output
    ...
END;
GO
```

*   **Explanation:** Modifies the definition and logic of an existing stored procedure. This example adds an optional parameter (`@EffectiveDate`), incorporates salary range validation using the new `CHECK` constraint logic, improves error handling, and provides feedback via `SELECT`.

**g) `ALTER FUNCTION`**

```sql
ALTER FUNCTION HR.fn_GetEmployeeYearsOfService
(
    @EmployeeID INT
)
RETURNS DECIMAL(5,2) -- Changed return type
AS
BEGIN
    -- Changed calculation logic for more precision
    SELECT @YearsOfService = DATEDIFF(DAY, HireDate, GETDATE()) / 365.25
    ...
    RETURN ROUND(@YearsOfService, 2); -- Added rounding
END;
GO
```

*   **Explanation:** Modifies an existing function. Here, the return type is changed from `INT` to `DECIMAL(5,2)` and the calculation logic is updated to provide a more precise fractional number of years of service.

**h) `ALTER TRIGGER` (via `DROP` and `CREATE`)**

```sql
DROP TRIGGER IF EXISTS HR.trg_UpdateModifiedDate; -- Drop old one
GO
CREATE TRIGGER HR.trg_AuditEmployeeChanges -- Create new one
ON HR.EMP_Details
AFTER UPDATE
AS
BEGIN
    -- Still updates ModifiedDate
    -- Dynamically creates Audit table (if needed)
    -- Inserts detailed audit records for specific field changes (Salary, DepartmentID)
    ...
END;
GO
```

*   **Explanation:** While there isn't a direct `ALTER TRIGGER` syntax in the same way as for procedures or views in SQL Server, the common pattern is to `DROP` the existing trigger and `CREATE` a new one with the modified logic. This script replaces the simple `trg_UpdateModifiedDate` with a more sophisticated `trg_AuditEmployeeChanges` that not only updates `ModifiedDate` but also logs specific changes to an audit table.

**i) `ALTER TABLE` (Adding Constraint to Existing Table)**

```sql
-- Table created earlier in the script
CREATE TABLE HR.Performance_Reviews (...);
GO
-- Now alter it
ALTER TABLE HR.Performance_Reviews
ADD CONSTRAINT FK_Performance_Reviews_Reviewer
FOREIGN KEY (ReviewedBy) REFERENCES HR.EMP_Details(EmployeeID);
GO
```

*   **Explanation:** Demonstrates adding a `FOREIGN KEY` constraint to a table (`Performance_Reviews`) sometime *after* its initial creation, linking the `ReviewedBy` column back to the `EMP_Details` table.

**j) Altering Database Security (`ALTER ROLE`, `GRANT`, `REVOKE`)**

```sql
CREATE USER HRManager WITHOUT LOGIN; -- Create user first
GO
ALTER ROLE db_datareader ADD MEMBER HRManager; -- Add user to existing role
GO
GRANT EXECUTE ON HR.sp_UpdateEmployeeSalary TO HRManager; -- Grant permission
GO
REVOKE SELECT ON HR.EMP_Details TO HRManager; -- Revoke specific permission
GRANT SELECT ON HR.vw_EmployeeDetails TO HRManager; -- Grant different permission
GO
```

*   **Explanation:** These commands modify the security configuration:
    *   `ALTER ROLE ... ADD MEMBER ...`: Adds an existing user or role to another role.
    *   `GRANT`: Gives specific permissions (like `EXECUTE` on a procedure, `SELECT` on a view) to a user or role.
    *   `REVOKE`: Removes previously granted permissions.
    *   These demonstrate how to adjust access rights after initial setup.

## 3. Targeted Interview Questions (Based on `02_ALTER.sql`)

**Question 1:** The `HR.EMP_Details` table has an `Email` column. Write the `ALTER TABLE` statement to add a `UNIQUE` constraint to this column, assuming one doesn't already exist from the `CREATE` statement. Name the constraint `UQ_EMP_Details_Email`. What potential issue might occur when running this statement on a table with existing data?

**Solution 1:**

```sql
ALTER TABLE HR.EMP_Details
ADD CONSTRAINT UQ_EMP_Details_Email UNIQUE (Email);
```

*   **Potential Issue:** If the `HR.EMP_Details` table already contains rows with duplicate non-NULL values in the `Email` column, the `ALTER TABLE` statement will fail. Before adding the unique constraint, you would need to identify and resolve these duplicates (e.g., update them to unique values or delete the duplicate rows). NULL values are typically allowed by unique constraints (unless it's also a primary key), but only one NULL might be permitted depending on the SQL Server version and settings.

**Question 2:** The script uses both `ALTER INDEX ... REBUILD` and `ALTER INDEX ... REORGANIZE`. Explain the fundamental difference between these two index maintenance operations and when you might choose one over the other.

**Solution 2:**

*   **`REBUILD`:** This operation effectively drops the existing index and creates a new, fresh copy.
    *   **Pros:** Removes all fragmentation (internal and external), potentially reclaims more space, updates statistics (by default). Most effective way to deal with heavy fragmentation.
    *   **Cons:** More resource-intensive (CPU, I/O, Log space). Can cause significant blocking if performed offline (default for Standard Edition). Online rebuild is possible in Enterprise Edition but still resource-intensive.
    *   **When to use:** For heavily fragmented indexes, when you need to change index options (like `FILLFACTOR` or `PAD_INDEX`), or as part of scheduled maintenance for critical indexes.

*   **`REORGANIZE`:** This operation physically reorders the leaf-level pages of the index *in place* to match the logical order, compacting pages and removing some fragmentation.
    *   **Pros:** Less resource-intensive than `REBUILD`. Always an online operation (minimal blocking). Good for light to moderate fragmentation.
    *   **Cons:** Only deals with leaf-level logical fragmentation, doesn't reclaim space as effectively, doesn't update statistics by default. May not be sufficient for heavily fragmented indexes.
    *   **When to use:** For indexes with low to moderate fragmentation, during periods where minimal performance impact is crucial, or more frequently between full rebuilds.

*   **Choice:** Typically, you'd check index fragmentation levels (e.g., using `sys.dm_db_index_physical_stats`). Low fragmentation (<5-10%) might need nothing. Moderate fragmentation (e.g., 10-30%) is often suitable for `REORGANIZE`. High fragmentation (>30%) usually warrants a `REBUILD`.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can you directly `ALTER` the name of a table column using `ALTER TABLE ... ALTER COLUMN`?
    *   **Answer:** No, standard SQL and SQL Server use the system stored procedure `sp_rename` to rename columns (and other objects). Syntax: `EXEC sp_rename 'Schema.Table.OldColumnName', 'NewColumnName', 'COLUMN';`. `ALTER TABLE ... ALTER COLUMN` is used for changing a column's data type, size, or nullability.
2.  **[Easy]** What happens if you try to `ALTER TABLE ... ALTER COLUMN` to change a column's data type to one that is incompatible with the data already stored in that column (e.g., changing a `VARCHAR` column containing 'ABC' to `INT`)?
    *   **Answer:** The `ALTER TABLE` statement will fail with an error, typically indicating a conversion failure. SQL Server will not allow the data type change if existing data cannot be implicitly or explicitly converted to the new type without loss or error.
3.  **[Medium]** You want to modify a view using `ALTER VIEW`. Can you add an `ORDER BY` clause to the view's definition? What is the typical limitation or requirement?
    *   **Answer:** You generally cannot add an `ORDER BY` clause directly to a view definition *unless* you also include a `TOP`, `OFFSET/FETCH`, or `FOR XML` clause. Standard views are meant to represent logical tables, and tables inherently have no guaranteed order. If you need ordered results, apply the `ORDER BY` when you `SELECT` *from* the view. The exception allows ordering for specific scenarios like selecting the top N rows.
4.  **[Medium]** What is a major risk when executing `ALTER TABLE YourTable ADD NewColumn INT NOT NULL` on a very large, actively used table? How can this be mitigated?
    *   **Answer:** Risk: Without a `DEFAULT` clause, adding a `NOT NULL` column requires updating every existing row to add a value for the new column. On large tables, this can be a size-of-data operation, taking a long time, consuming significant transaction log space, and potentially causing extensive blocking or locking, leading to downtime.
        *   **Mitigation (Modern SQL Server):** Add the `NOT NULL` column *with* a `DEFAULT` constraint (`ADD NewColumn INT NOT NULL DEFAULT 0`). In recent versions, this can often be a metadata-only change, making it near-instantaneous, as the default value isn't physically stored for existing rows until they are updated.
        *   **Mitigation (Older versions / complex defaults):** 1. `ALTER TABLE YourTable ADD NewColumn INT NULL;` (Fast, metadata only). 2. Update the `NewColumn` in batches to set desired values. 3. `ALTER TABLE YourTable ALTER COLUMN NewColumn INT NOT NULL;` (Faster now, as values exist).
5.  **[Medium]** What does the `ALTER TABLE ... SWITCH PARTITION` command allow you to do, and what is a key prerequisite for using it?
    *   **Answer:** `ALTER TABLE ... SWITCH PARTITION` allows you to move an entire partition of data almost instantaneously between two tables, or within different partitions of the same table. It's a metadata-only operation, making it extremely fast for moving large amounts of data (e.g., for loading data into a staging table and then switching it into the main partitioned table, or for archiving old data).
        *   **Prerequisite:** Both the source and target tables (or partitions) must exist, share the exact same structure (columns, data types, constraints, indexes - with some nuances), reside in the same filegroup, and the target partition must be empty. Both tables must be partition-aligned if switching between two partitioned tables.
6.  **[Medium]** Can you safely `ALTER` the definition of a stored procedure or function while another session is currently executing it? What is likely to happen?
    *   **Answer:** No, it's generally not safe and often not possible. Attempting to `ALTER` an object (like a procedure or function) while it's actively being executed by another session will typically result in blocking. The `ALTER` statement will wait until the executing session finishes using the object (acquiring a schema modification lock requires waiting for schema stability locks to be released). If the wait times out, the `ALTER` will fail. Concurrent execution might also lead to errors if the execution plan relies on the old definition. Changes should be deployed during maintenance windows or using strategies that minimize contention.
7.  **[Hard]** What is the purpose of the `LOCK_ESCALATION` option that can be set using `ALTER TABLE ... SET (LOCK_ESCALATION = ...)`?
    *   **Answer:** `LOCK_ESCALATION` controls how SQL Server escalates locks. When a single transaction acquires many fine-grained locks (row or page locks) on a table or partition, SQL Server might escalate these to a single, coarser table-level lock to conserve memory resources used for tracking locks. `ALTER TABLE ... SET (LOCK_ESCALATION = TABLE | AUTO | DISABLE)` allows you to influence this behavior. `TABLE` (default) allows escalation to the table level. `AUTO` allows escalation to the partition level for partitioned tables if possible, otherwise to the table. `DISABLE` prevents lock escalation on that specific table (use with extreme caution, as it can lead to excessive memory consumption if transactions acquire millions of locks).
8.  **[Hard]** You need to add a new `NOT NULL` column (`CreatedByUser`) to a massive, multi-terabyte table (`AuditLog`) with minimal downtime. The value should default to `SUSER_SNAME()` (the login name of the user performing the insert), which is not a constant default. How might you approach this using `ALTER` and other commands?
    *   **Answer:** Since `SUSER_SNAME()` isn't a constant, the metadata-only trick for `ADD NOT NULL DEFAULT` doesn't apply directly for existing rows. A phased approach is needed:
        1.  **Add Nullable Column:** `ALTER TABLE AuditLog ADD CreatedByUser NVARCHAR(128) NULL;` (This is fast, metadata only).
        2.  **Add Default Constraint for Future Rows:** `ALTER TABLE AuditLog ADD CONSTRAINT DF_AuditLog_CreatedByUser DEFAULT SUSER_SNAME() FOR CreatedByUser;` (Ensures new rows get the correct value).
        3.  **Backfill Existing Rows (Crucial Step):** Update the `CreatedByUser` column for existing rows where it's `NULL`. This MUST be done in manageable batches to avoid excessive logging and blocking. Use a loop with `UPDATE TOP (N) ... WHERE CreatedByUser IS NULL`. The value for old rows might be set to a placeholder like 'SYSTEM_BACKFILL' or derived if possible, as the original user is unknown.
            ```sql
            DECLARE @BatchSize INT = 10000; -- Adjust size
            WHILE 1 = 1
            BEGIN
                UPDATE TOP (@BatchSize) AuditLog
                SET CreatedByUser = N'SYSTEM_BACKFILL' -- Or appropriate value
                WHERE CreatedByUser IS NULL;

                IF @@ROWCOUNT < @BatchSize BREAK; -- Exit loop if less than batch size updated

                WAITFOR DELAY '00:00:01'; -- Optional small delay
            END
            ```
        4.  **(Optional but Recommended) Make Column NOT NULL:** Once backfilling is complete and verified, *if required by business logic*, make the column non-nullable: `ALTER TABLE AuditLog ALTER COLUMN CreatedByUser NVARCHAR(128) NOT NULL;` (This should be fast now as no rows have NULL).
9.  **[Hard]** Can you use `ALTER TABLE ... REBUILD` to change the data compression setting (e.g., from `NONE` to `PAGE` or `ROW`) for a table or index? What are the potential performance impacts (positive and negative) of enabling data compression?
    *   **Answer:** Yes, you can change data compression settings using `ALTER TABLE ... REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = [NONE | ROW | PAGE])` or `ALTER INDEX ... REBUILD WITH (DATA_COMPRESSION = [NONE | ROW | PAGE])`.
        *   **Potential Positive Impacts:** Reduced storage footprint (disk space savings), improved buffer pool efficiency (more data fits in memory), potentially faster I/O for scans (fewer pages to read).
        *   **Potential Negative Impacts:** Increased CPU usage during DML operations (`INSERT`, `UPDATE`, `DELETE`) as data needs to be compressed/decompressed. Increased CPU usage during queries that access compressed data. The rebuild operation itself is resource-intensive. The effectiveness varies greatly depending on data patterns.
10. **[Hard/Tricky]** If you use `ALTER SCHEMA TargetSchema TRANSFER SourceSchema.MyTable;` to move a table (`MyTable`) from `SourceSchema` to `TargetSchema`, what happens to the permissions (e.g., `SELECT`, `INSERT`) that were previously granted directly on `SourceSchema.MyTable` to specific users or roles?
    *   **Answer:** When an object is transferred between schemas using `ALTER SCHEMA ... TRANSFER`, the permissions explicitly granted *on that specific object* are generally **dropped** as part of the transfer. The security context changes because the object's fully qualified name changes (from `SourceSchema.MyTable` to `TargetSchema.MyTable`). Therefore, after transferring the object, you typically need to **re-apply** (re-`GRANT`) the necessary permissions on the object under its new schema (`TargetSchema.MyTable`) to the relevant users or roles. Permissions granted at a higher level (like database-level or on the schema itself) might still apply indirectly, but object-specific permissions are lost in the transfer.
