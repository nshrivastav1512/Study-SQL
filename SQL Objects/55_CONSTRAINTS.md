# SQL Deep Dive: Constraints

## 1. Introduction: What are Constraints?

**Constraints** are rules defined on table columns (or the table itself) to enforce data integrity and ensure the accuracy and reliability of data within the database. They prevent invalid data from being entered or modified, maintaining consistency according to predefined business rules or relational database principles.

**Why use Constraints?**

*   **Data Integrity:** Ensure data accuracy and validity (e.g., salary must be positive, email must be unique, status must be from a predefined list).
*   **Relational Integrity:** Maintain relationships between tables (`PRIMARY KEY`, `FOREIGN KEY`).
*   **Business Rule Enforcement:** Implement specific business logic directly in the database schema (e.g., end date must be after start date).
*   **Data Quality:** Prevent `NULL` values where they are not allowed (`NOT NULL`).
*   **Automation:** Provide default values when none are supplied (`DEFAULT`).

**Types of Constraints:**

1.  **`PRIMARY KEY`:** Uniquely identifies each row in a table. Enforces entity integrity. Does not allow `NULL`s. A table can have only one.
2.  **`FOREIGN KEY`:** Enforces referential integrity between two tables. Ensures values in the foreign key column(s) match values in the referenced primary or unique key column(s) of the parent table.
3.  **`UNIQUE`:** Ensures all values in a column (or combination of columns) are unique. Allows one `NULL` value. A table can have multiple.
4.  **`CHECK`:** Validates data based on a logical expression or condition (e.g., `Salary > 0`, `Status IN ('Active', 'Inactive')`).
5.  **`DEFAULT`:** Specifies a default value to be inserted into a column if no explicit value is provided during an `INSERT`.
6.  **`NOT NULL`:** (Technically a column property, but often discussed with constraints) Ensures a column cannot contain `NULL` values.

## 2. Constraints in Action: Analysis of `55_CONSTRAINTS.sql`

This script demonstrates creating tables with various constraints and managing those constraints.

**a) Creating Tables with Constraints**

*   **`PRIMARY KEY`:**
    ```sql
    CREATE TABLE HR.Departments (DepartmentID INT PRIMARY KEY, ...);
    -- Or table-level for composite keys:
    -- CREATE TABLE Table (ColA INT, ColB INT, ..., PRIMARY KEY (ColA, ColB));
    ```
*   **`FOREIGN KEY`:**
    ```sql
    CREATE TABLE HR.Employees (..., DepartmentID INT, ...,
        CONSTRAINT FK_Employees_Departments FOREIGN KEY (DepartmentID) REFERENCES HR.Departments(DepartmentID)
    );
    -- Self-referencing FK (ManagerID references EmployeeID in the same table)
    -- CONSTRAINT FK_Employees_Manager FOREIGN KEY (ManagerID) REFERENCES HR.Employees(EmployeeID)
    ```
*   **`UNIQUE`:**
    ```sql
    CREATE TABLE HR.EmployeeSkills (..., EmployeeID INT, SkillName VARCHAR(50), ...,
        CONSTRAINT UQ_EmployeeSkill UNIQUE (EmployeeID, SkillName) -- Composite unique constraint
    );
    -- Also shown inline on HR.Employees(Email)
    ```
*   **`CHECK`:**
    ```sql
    CREATE TABLE HR.Salaries (..., Amount DECIMAL(12,2) NOT NULL CHECK (Amount > 0), ...);
    -- Or table-level:
    -- CONSTRAINT CHK_Salary_EffectiveDate CHECK (EffectiveDate <= GETDATE()) -- Note: GETDATE() in CHECK is often problematic
    ```
*   **`DEFAULT`:**
    ```sql
    CREATE TABLE HR.TimeOff (..., Status VARCHAR(20) DEFAULT 'Pending', RequestDate DATETIME DEFAULT GETDATE(), ...);
    ```
*   **`NOT NULL`:**
    ```sql
    CREATE TABLE HR.PerformanceReviews (..., ReviewDate DATE NOT NULL, PerformanceRating DECIMAL(3,2) NOT NULL, ...);
    ```

*   **Explanation:** Shows defining constraints inline with column definitions or at the table level using the `CONSTRAINT ConstraintName CONSTRAINT_TYPE (...)` syntax. Naming constraints explicitly (`FK_...`, `UQ_...`, `CHK_...`, `DF_...`, `PK_...`) is a best practice for easier management later.

**b) Adding Constraints to Existing Tables (`ALTER TABLE ... ADD CONSTRAINT`)**

```sql
ALTER TABLE HR.Projects ADD CONSTRAINT PK_Projects PRIMARY KEY (ProjectID);
ALTER TABLE HR.Projects ADD CONSTRAINT FK_Projects_Manager FOREIGN KEY (ManagerID) REFERENCES HR.Employees(EmployeeID);
ALTER TABLE HR.Projects ADD CONSTRAINT CHK_Project_Dates CHECK (EndDate IS NULL OR EndDate >= StartDate);
ALTER TABLE HR.Projects ADD CONSTRAINT DF_Project_Status DEFAULT 'Not Started' FOR Status;
-- Adding NOT NULL (uses ALTER COLUMN)
ALTER TABLE HR.Projects ALTER COLUMN ProjectName VARCHAR(100) NOT NULL;
```

*   **Explanation:** Demonstrates adding various constraint types to a table after it has been created using `ALTER TABLE`. Note that `NOT NULL` is applied using `ALTER COLUMN`.

**c) Modifying Constraints**

*   **Explanation:** SQL Server generally does **not** allow direct modification of an existing constraint's definition using `ALTER CONSTRAINT`. To change a constraint (e.g., modify a `CHECK` condition, change `FOREIGN KEY` actions), you typically must:
    1.  `ALTER TABLE TableName DROP CONSTRAINT ConstraintName;`
    2.  `ALTER TABLE TableName ADD CONSTRAINT ConstraintName NewDefinition;`
*   The script demonstrates this drop-and-add pattern for `CHECK` and `FOREIGN KEY` constraints (adding `ON DELETE CASCADE` to the FK).

**d) Disabling and Enabling Constraints (`ALTER TABLE ... NOCHECK/CHECK CONSTRAINT`)**

```sql
-- Disable specific FK
ALTER TABLE HR.ProjectAssignments NOCHECK CONSTRAINT FK_ProjectAssignments_Employees;
-- Enable specific FK (checks existing data)
ALTER TABLE HR.ProjectAssignments CHECK CONSTRAINT FK_ProjectAssignments_Employees;
-- Disable ALL constraints on table
ALTER TABLE HR.ProjectAssignments NOCHECK CONSTRAINT ALL;
-- Enable ALL constraints on table
ALTER TABLE HR.ProjectAssignments CHECK CONSTRAINT ALL;
```

*   **Explanation:** Allows temporarily disabling (`NOCHECK`) or re-enabling (`CHECK`) constraints, typically `FOREIGN KEY` or `CHECK` constraints.
    *   `NOCHECK`: Disables the constraint for future DML operations *and* prevents checking existing data when re-enabled later (unless `CHECK CONSTRAINT` is used). Often used during bulk data loads to improve performance, but requires careful data validation afterward.
    *   `CHECK`: Re-enables the constraint and validates it against *all existing data* in the table. If validation fails, the constraint remains disabled.

**e) Dropping Constraints (`ALTER TABLE ... DROP CONSTRAINT`)**

```sql
ALTER TABLE HR.Projects DROP CONSTRAINT CHK_Project_Priority;
ALTER TABLE HR.Projects DROP CONSTRAINT DF_Project_Priority;
ALTER TABLE HR.ProjectAssignments DROP CONSTRAINT UQ_ProjectAssignment;
```

*   **Explanation:** Permanently removes a constraint from a table using its name.

**f) Querying Constraint Information (System Views)**

```sql
-- All constraints
SELECT ..., o.name AS ConstraintName, o.type_desc AS ConstraintType, ... FROM sys.objects o WHERE o.type_desc LIKE '%CONSTRAINT';
-- Foreign Keys
SELECT ..., f.name AS ForeignKeyName, ... FROM sys.foreign_keys f JOIN sys.foreign_key_columns fc ON ...;
-- Check Constraints
SELECT ..., o.name AS CheckConstraintName, c.definition, ... FROM sys.check_constraints c JOIN sys.objects o ON ...;
-- Default Constraints
SELECT ..., o.name AS DefaultConstraintName, d.definition, ... FROM sys.default_constraints d JOIN sys.objects o ON ...;
-- Primary/Unique Keys (via Indexes)
SELECT ..., o.name AS ConstraintName, CASE i.is_primary_key WHEN 1 THEN 'PK' ELSE 'UQ' END, ... FROM sys.indexes i JOIN sys.objects o ON ... WHERE i.is_primary_key = 1 OR i.is_unique_constraint = 1;
```

*   **Explanation:** Uses various system views (`sys.objects`, `sys.foreign_keys`, `sys.check_constraints`, `sys.default_constraints`, `sys.indexes`) to retrieve metadata about constraints defined in the database, including their names, types, associated tables/columns, definitions, and status (e.g., `is_disabled`).

## 3. Targeted Interview Questions (Based on `55_CONSTRAINTS.sql`)

**Question 1:** What are the five main types of constraints commonly used to enforce data integrity in SQL Server tables (excluding `NOT NULL`)? Briefly describe the purpose of each.

**Solution 1:**
1.  **`PRIMARY KEY`:** Uniquely identifies each row in a table. Enforces entity integrity.
2.  **`FOREIGN KEY`:** Enforces relationships between tables, ensuring values in one table match values in another (referential integrity).
3.  **`UNIQUE`:** Ensures all values in a specified column or set of columns are unique (allows one NULL).
4.  **`CHECK`:** Validates that data entered into a column meets a specific logical condition or business rule.
5.  **`DEFAULT`:** Provides a default value for a column when no value is supplied during an `INSERT`.

**Question 2:** Can you directly modify the condition of an existing `CHECK` constraint using `ALTER CONSTRAINT`? If not, how do you change it?

**Solution 2:** No, you cannot directly modify the condition using `ALTER CONSTRAINT`. To change a `CHECK` constraint's definition, you must first **drop** the existing constraint using `ALTER TABLE TableName DROP CONSTRAINT ConstraintName;` and then **add** a new constraint with the same (or different) name but the new definition using `ALTER TABLE TableName ADD CONSTRAINT ConstraintName CHECK (NewCondition);`.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which constraint prevents duplicate rows based on specific column(s) but allows one `NULL` value?
    *   **Answer:** `UNIQUE` constraint.
2.  **[Easy]** Which constraint is used to establish a parent-child relationship between tables?
    *   **Answer:** `FOREIGN KEY` constraint.
3.  **[Medium]** What happens if you try to insert a row that violates a `CHECK` constraint?
    *   **Answer:** The `INSERT` statement will fail, and SQL Server will raise an error indicating the `CHECK` constraint violation. The row will not be inserted.
4.  **[Medium]** What is the difference between disabling a constraint (`NOCHECK`) and dropping it (`DROP`)?
    *   **Answer:** `NOCHECK` temporarily disables the constraint's enforcement for future DML and (by default) doesn't re-validate existing data upon re-enabling. The constraint definition still exists. `DROP` permanently removes the constraint definition from the database.
5.  **[Medium]** Can a `FOREIGN KEY` constraint reference a non-primary key column in the parent table? If so, what is required for that referenced column?
    *   **Answer:** Yes. A `FOREIGN KEY` can reference any column(s) in the parent table that have a `PRIMARY KEY` or a `UNIQUE` constraint defined on them. The referenced columns must guarantee uniqueness.
6.  **[Medium]** Does a `DEFAULT` constraint prevent `NULL` values from being inserted if the column allows `NULL`s?
    *   **Answer:** No. A `DEFAULT` constraint only provides a value if one is *not specified* during the `INSERT`. If the column allows `NULL`s, you can still explicitly insert `NULL` into that column, bypassing the default. To prevent `NULL`s, you need a `NOT NULL` constraint.
7.  **[Hard]** What does `ON DELETE CASCADE` specified on a `FOREIGN KEY` constraint do? What are the risks?
    *   **Answer:** `ON DELETE CASCADE` specifies that if a row in the *parent* (referenced) table is deleted, all corresponding rows in the *child* (referencing) table should also be automatically deleted by SQL Server.
        *   **Risks:** Can lead to unintentional mass deletions if not fully understood. A delete on a top-level parent table could cascade through multiple levels of related tables, potentially wiping out large amounts of data unexpectedly. Use with extreme caution and ensure the cascading behavior aligns with business requirements.
8.  **[Hard]** Can a `CHECK` constraint definition reference a User-Defined Function (UDF)? If so, what are the implications and potential performance concerns?
    *   **Answer:** Yes, a `CHECK` constraint can reference a scalar UDF (e.g., `CHECK (dbo.MyValidationFunction(ColumnA) = 1)`).
        *   **Implications:** Allows encapsulating complex validation logic. The function must be deterministic if used in this context (or created `WITH SCHEMABINDING`).
        *   **Performance Concerns:** The UDF will be executed for every row being inserted or updated (for the relevant column). If the UDF is complex or performs data access itself, this can significantly slow down DML operations on the table.
9.  **[Hard]** If you disable a `FOREIGN KEY` constraint using `ALTER TABLE ... NOCHECK CONSTRAINT ...`, does SQL Server still prevent you from dropping the referenced parent table?
    *   **Answer:** Yes. Disabling the constraint (`NOCHECK`) only stops SQL Server from enforcing the relationship during DML operations. The constraint *metadata* still exists, defining the dependency. You still cannot drop the parent table while the disabled foreign key constraint referencing it exists. You would need to `DROP` the foreign key constraint first.
10. **[Hard/Tricky]** Can a `CHECK` constraint reference another column within the same table? Can it reference a column in a *different* table?
    *   **Answer:**
        *   **Same Table:** Yes, a `CHECK` constraint can reference other columns within the same row of the *same table* (e.g., `CONSTRAINT CHK_Dates CHECK (EndDate >= StartDate)`).
        *   **Different Table:** No, a standard `CHECK` constraint cannot directly reference columns in *other* tables. Its logic must evaluate based only on the values within the row being inserted or updated. To enforce rules based on values in other tables, you typically need to use `FOREIGN KEY` constraints or implement the logic using Triggers.
