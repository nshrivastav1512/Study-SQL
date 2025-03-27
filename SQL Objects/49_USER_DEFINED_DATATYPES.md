# SQL Deep Dive: User-Defined Data Types (UDTs)

## 1. Introduction: What are User-Defined Data Types?

User-Defined Data Types (UDTs) allow you to create custom data types based on existing SQL Server system data types. They provide a way to enforce consistency and encapsulate data domain rules across your database schema.

**Types of UDTs:**

1.  **Alias Data Types:** The most common type. They are essentially aliases for standard system data types (`INT`, `VARCHAR`, `DECIMAL`, etc.). You can optionally bind rules and defaults to them to enforce specific constraints or provide default values whenever the type is used.
2.  **User-Defined Table Types (UDTTs):** Define the structure of a table variable. Primarily used for declaring Table-Valued Parameters (TVPs) to pass multiple rows of data into stored procedures or functions. (Covered in section 9).
3.  **CLR UDTs:** Based on assemblies created in a .NET Framework language (like C#). Allow for complex, custom data structures and behaviors beyond standard SQL types. (Not covered in detail in this script).

**Why use Alias Data Types?**

*   **Consistency:** Ensure that columns representing the same kind of data (e.g., phone numbers, email addresses, status codes, monetary values) always use the exact same underlying data type, nullability, and potentially validation rules throughout the database.
*   **Maintainability:** If the definition needs to change (e.g., increase the length of all email columns), you only need to modify the UDT definition (though this requires handling dependencies), rather than altering every individual table column.
*   **Clarity/Domain Definition:** Give meaningful names to data types (e.g., `PhoneNumberType` instead of just `VARCHAR(20)`), improving schema readability and understanding.
*   **Encapsulating Rules/Defaults:** Bind `RULE` objects (for validation) and `DEFAULT` objects to the type, ensuring these constraints are applied automatically wherever the type is used. *Note: `RULE` and `DEFAULT` objects are older features; `CHECK` and `DEFAULT` constraints defined directly on table columns are generally preferred now.*

**Key Commands:**

*   `CREATE TYPE TypeName FROM BaseType [NULL | NOT NULL]`
*   `DROP TYPE TypeName`
*   `CREATE RULE RuleName AS condition`
*   `DROP RULE RuleName`
*   `EXEC sp_bindrule 'RuleName', 'TypeName'`
*   `EXEC sp_unbindrule 'TypeName'`
*   `CREATE DEFAULT DefaultName AS constant_expression`
*   `DROP DEFAULT DefaultName`
*   `EXEC sp_bindefault 'DefaultName', 'TypeName'`
*   `EXEC sp_unbindefault 'TypeName'`

## 2. UDTs in Action: Analysis of `49_USER_DEFINED_DATATYPES.sql`

This script demonstrates creating and managing alias UDTs and Table Types.

**a) Creating Alias UDTs (`CREATE TYPE ... FROM ...`)**

```sql
CREATE TYPE PhoneNumberType FROM VARCHAR(20) NOT NULL;
CREATE TYPE EmailType FROM VARCHAR(100) NULL;
CREATE TYPE StatusType FROM VARCHAR(20) NOT NULL;
CREATE TYPE HR.EmployeeIDType FROM INT NOT NULL; -- In a specific schema
```

*   **Explanation:** Creates aliases for system types. `PhoneNumberType` is based on `VARCHAR(20)` and cannot be null. `EmailType` allows nulls. `HR.EmployeeIDType` is created within the `HR` schema.

**b) Creating and Binding Rules (`CREATE RULE`, `sp_bindrule`)**

```sql
CREATE RULE EmailRule AS @value LIKE '%_@_%.__%'; -- Validation logic
GO
EXEC sp_bindrule 'EmailRule', 'EmailType'; -- Apply rule to the type
GO
CREATE RULE StatusRule AS @value IN ('Active', 'Inactive', ...);
GO
EXEC sp_bindrule 'StatusRule', 'StatusType';
GO
```

*   **Explanation:** Creates `RULE` objects containing validation logic (`@value` represents the data being checked). `sp_bindrule` associates the rule with the UDT. Any column using `EmailType` or `StatusType` will now automatically enforce these rules during `INSERT` and `UPDATE`. *Note: `CHECK` constraints on tables are generally preferred over `RULE` objects today.*

**c) Creating and Binding Defaults (`CREATE DEFAULT`, `sp_bindefault`)**

```sql
CREATE DEFAULT StatusDefault AS 'Active'; -- Default value
GO
EXEC sp_bindefault 'StatusDefault', 'StatusType'; -- Apply default to the type
GO
```

*   **Explanation:** Creates a `DEFAULT` object specifying a constant value. `sp_bindefault` associates it with the UDT. Columns defined with `StatusType` will automatically use 'Active' if no value is provided during `INSERT`. *Note: `DEFAULT` constraints on tables are generally preferred over `DEFAULT` objects today.*

**d) Using UDTs in Tables**

```sql
CREATE TABLE HR.ContactInfo (
    ContactID INT PRIMARY KEY IDENTITY(1,1),
    EmployeeID HR.EmployeeIDType, -- Using UDT
    Phone PhoneNumberType,       -- Using UDT
    Email EmailType,             -- Using UDT (with rule)
    Status StatusType,          -- Using UDT (with rule and default)
    ...
);
GO
INSERT INTO HR.ContactInfo (EmployeeID, Phone, Email) -- Status gets default
VALUES (1001, '555-123-4567', 'john.doe@example.com');
-- INSERT INTO HR.ContactInfo (..., Email) VALUES (..., 'bad-email'); -- Would fail EmailRule
```

*   **Explanation:** Demonstrates declaring table columns using the previously created UDTs. The constraints (rules, defaults, nullability) defined or bound to the UDT are automatically applied to these columns.

**e) Modifying Alias UDTs**

*   **Explanation:** The script correctly notes that you **cannot directly `ALTER` an alias UDT's** base type or nullability (`ALTER TYPE` is for CLR UDTs or Table Types). To change an alias UDT, you must:
    1.  Identify all dependent objects (tables, procedures, functions using the type).
    2.  Modify the dependent objects to temporarily use the base type or another type, or drop them.
    3.  `DROP TYPE OldTypeName;`
    4.  `CREATE TYPE OldTypeName FROM NewBaseType ...;` (Recreate with the new definition).
    5.  Recreate or alter the dependent objects back to use the UDT.
    6.  Rebind any rules or defaults if necessary.
*   This dependency management makes changing widely used UDTs complex.

**f) Unbinding Rules and Defaults (`sp_unbindrule`, `sp_unbindefault`)**

```sql
EXEC sp_unbindrule 'DemoType';
EXEC sp_unbindefault 'DemoType';
```

*   **Explanation:** Removes the association between a `RULE` or `DEFAULT` object and a UDT (or a specific table column).

**g) Dropping UDTs (`DROP TYPE`)**

```sql
-- Drop dependencies first (e.g., tables using the type)
DROP TABLE TempTable;
GO
DROP TYPE TempType;
GO
```

*   **Explanation:** Removes the UDT definition. Fails if any objects still depend on the type. Rules/Defaults bound only to the type being dropped are usually dropped automatically, but it's good practice to unbind/drop them explicitly first if shared.

**h) Querying UDT Information (`sys.types`, `sys.objects`)**

```sql
-- List UDTs
SELECT t.name, SCHEMA_NAME(t.schema_id), st.name AS BaseType, ...
FROM sys.types t JOIN sys.types st ON t.system_type_id = st.user_type_id
WHERE t.is_user_defined = 1 AND t.is_table_type = 0;
-- Find bound rules/defaults
SELECT t.name AS TypeName, o.name AS RuleName FROM sys.types t JOIN sys.objects o ON t.rule_object_id = o.object_id WHERE ...;
SELECT t.name AS TypeName, o.name AS DefaultName FROM sys.types t JOIN sys.objects o ON t.default_object_id = o.object_id WHERE ...;
```

*   **Explanation:** Uses system views to find user-defined alias types (`is_user_defined = 1`, `is_table_type = 0`), their base types, and any bound `RULE` (`rule_object_id`) or `DEFAULT` (`default_object_id`) objects.

**i/j) Table-Valued Parameters (TVPs) / Table Types (`CREATE TYPE ... AS TABLE`)**

```sql
CREATE TYPE HR.EmployeeTableType AS TABLE ( -- Define table structure
    EmployeeID INT, FirstName VARCHAR(50), ...
);
GO
CREATE PROCEDURE HR.BulkInsertEmployees @Employees HR.EmployeeTableType READONLY AS ...;
GO
DECLARE @NewEmployees HR.EmployeeTableType; INSERT INTO @NewEmployees VALUES (...);
EXEC HR.BulkInsertEmployees @NewEmployees;
GO
-- Query table type info
SELECT ... FROM sys.table_types tt JOIN sys.columns c ON tt.type_table_object_id = c.object_id WHERE tt.name = '...';
```

*   **Explanation:** Focuses on the *other* kind of UDT: User-Defined Table Types.
    *   `CREATE TYPE TypeName AS TABLE (...)`: Defines the structure (columns, data types, constraints) for a table variable.
    *   Used primarily to declare **Table-Valued Parameters** (`READONLY`) for stored procedures and functions, allowing multiple rows to be passed efficiently as a single parameter.
    *   System views like `sys.table_types` and `sys.columns` provide metadata about them.

**k) Best Practices (Standardization)**

```sql
CREATE TYPE MoneyType FROM DECIMAL(15, 2) NOT NULL;
CREATE TYPE DateType FROM DATE NOT NULL;
CREATE TABLE Finance.Invoices (... Amount MoneyType, InvoiceDate DateType, ...);
```

*   **Explanation:** Suggests creating UDTs for common, standardized data domains (like money, specific ID types, status codes) to enforce consistency across the database schema.

**l/m/n/o) Other Examples**

*   Shows using synonyms with UDTs, migrating away from UDTs (altering columns back to base types), and comparing UDTs+Rules with modern `CHECK` constraints (prefer `CHECK` constraints).

## 3. Targeted Interview Questions (Based on `49_USER_DEFINED_DATATYPES.sql`)

**Question 1:** What are the two main kinds of User-Defined Data Types demonstrated in the script, and what is the primary use case for each?

**Solution 1:**
1.  **Alias Data Types:** Created using `CREATE TYPE TypeName FROM BaseSystemType ...`. They act as aliases for system types, allowing standardization and the binding of (older style) rules and defaults. Primary use case: Enforce consistency and domain integrity across multiple columns representing the same type of data (e.g., all phone numbers use `PhoneNumberType`).
2.  **User-Defined Table Types (UDTTs):** Created using `CREATE TYPE TypeName AS TABLE (...)`. They define the structure for table variables. Primary use case: Serve as the definition for **Table-Valued Parameters (TVPs)**, allowing multiple rows of data to be passed efficiently into stored procedures or functions.

**Question 2:** The script mentions that `RULE` and `DEFAULT` objects (bound using `sp_bindrule`/`sp_bindefault`) are older features. What are the modern preferred alternatives for enforcing validation rules and default values on table columns?

**Solution 2:** The modern preferred alternatives are:
1.  **`CHECK` Constraints:** Defined directly on the table column (`CREATE TABLE ... MyColumn INT CHECK (MyColumn > 0)`) or at the table level (`CONSTRAINT CHK_MyRule CHECK (ColumnA > ColumnB)`). They provide more flexibility and are generally easier to manage than `RULE` objects.
2.  **`DEFAULT` Constraints:** Defined directly on the table column (`CREATE TABLE ... MyColumn VARCHAR(10) DEFAULT 'N/A'`). They are simpler and integrated directly into the table definition compared to separate `DEFAULT` objects.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can you change the base data type of an existing alias UDT using `ALTER TYPE`?
    *   **Answer:** No, not for alias types. You must drop dependencies, drop the type, recreate the type with the new definition, and recreate dependencies. `ALTER TYPE` is primarily for CLR UDTs or adding/dropping columns in Table Types (in newer versions).
2.  **[Easy]** What keyword makes a Table-Valued Parameter usable inside a procedure but prevents modification?
    *   **Answer:** `READONLY`.
3.  **[Medium]** If you bind a `RULE` to a UDT, and also define a `CHECK` constraint on a table column that uses that UDT, which validation(s) will be applied during an `INSERT`?
    *   **Answer:** Both the `RULE` bound to the type *and* the `CHECK` constraint defined on the column will be applied. The value must satisfy both conditions to be successfully inserted or updated.
4.  **[Medium]** Can you create an index on a column defined with an alias UDT?
    *   **Answer:** Yes. Since the alias UDT is based on a standard system data type that supports indexing (like `INT`, `VARCHAR`, `DATE`, etc.), you can create indexes on table columns defined with that UDT just as you would if the column used the base system type directly.
5.  **[Medium]** What happens if you try to `DROP TYPE MyType;` while a table column is still defined using `MyType`?
    *   **Answer:** The `DROP TYPE` statement will fail with an error indicating that the type is currently being used by an object (the table column). You must alter the table column to use a different type (or drop the table) before you can drop the UDT.
6.  **[Medium]** Can you use a User-Defined Table Type (UDTT) to declare a regular table variable (e.g., `DECLARE @MyVar MyTableType;`)?
    *   **Answer:** Yes. Besides being used for parameters (TVPs), UDTTs can also be used to declare local table variables, providing a reusable structure definition.
7.  **[Hard]** Are `RULE` objects schema-scoped? Can a `RULE` created in the `dbo` schema be bound to a UDT in the `HR` schema?
    *   **Answer:** Yes, `RULE` objects (like `DEFAULT` objects) are created within a specific schema (defaulting to `dbo` if not specified). Yes, a rule created in one schema (e.g., `dbo.MyRule`) can be bound to a type defined in another schema (e.g., `HR.MyType`) using `sp_bindrule 'dbo.MyRule', 'HR.MyType';`.
8.  **[Hard]** If you unbind a rule from a UDT (`sp_unbindrule 'MyType'`), does this affect existing data in columns defined with `MyType` that might have violated the rule?
    *   **Answer:** No. Unbinding a rule only removes the validation check for *future* `INSERT` and `UPDATE` operations. It does not validate or affect any existing data already stored in columns of that type, even if that data violates the rule that was previously bound.
9.  **[Hard]** Can you define constraints (like `PRIMARY KEY`, `UNIQUE`, `CHECK`) *within* the definition of a User-Defined Table Type (`CREATE TYPE ... AS TABLE`)?
    *   **Answer:** Yes. You can define `PRIMARY KEY`, `UNIQUE`, and `CHECK` constraints directly within the `CREATE TYPE ... AS TABLE` definition, just like in a `CREATE TABLE` statement. However, you cannot define `FOREIGN KEY` constraints within a table type definition.
10. **[Hard/Tricky]** If you create `TYPE MyInt FROM INT NOT NULL` and `TYPE MyOtherInt FROM INT NOT NULL`, can you directly compare or assign values between columns defined with `MyInt` and `MyOtherInt` without explicit casting?
    *   **Answer:** Yes. Alias UDTs inherit the behavior and implicit conversion rules of their underlying base system data type. Since both `MyInt` and `MyOtherInt` are based on `INT`, SQL Server treats them as compatible for comparisons and assignments without requiring explicit `CAST` or `CONVERT`. They are essentially just named aliases for `INT NOT NULL` in this context.
