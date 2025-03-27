# SQL Deep Dive: Synonyms

## 1. Introduction: What are Synonyms?

A **Synonym** in SQL Server is essentially an **alias** or an alternative name for another database object. It provides a layer of abstraction, allowing you to refer to an object using the synonym name instead of its fully qualified base object name.

**Objects Synonyms Can Reference:**

*   Tables (local or remote)
*   Views (local or remote)
*   Stored Procedures (local or remote)
*   User-Defined Functions (scalar, inline table-valued, multi-statement table-valued)
*   Assemblies (CLR Stored Procedures, Functions, Triggers, UDTs, Aggregates)
*   Other Synonyms

**Why use Synonyms?**

*   **Abstraction/Location Transparency:** Hide the actual name and location (schema, database, linked server) of the base object. If the base object moves or is renamed, you only need to update the synonym definition, not all the code referencing it.
*   **Simplified Naming:** Provide shorter, simpler, or more consistent names for objects, especially those with long or complex multi-part names (e.g., referencing objects on linked servers).
*   **Backward Compatibility:** Maintain compatibility with older code if an object is renamed or moved. Create a synonym with the old name pointing to the new object location/name.
*   **Development/Testing:** Easily switch between development/test and production versions of objects by simply changing the synonym definition in different environments.

**Key Characteristics:**

*   Defined using `CREATE SYNONYM synonym_name FOR base_object_name;`.
*   `base_object_name` can be 1, 2, 3, or 4 parts (e.g., `MyTable`, `dbo.MyTable`, `OtherDB.dbo.MyTable`, `LinkedServer.OtherDB.dbo.MyTable`).
*   Synonyms exist within a specific schema (defaulting to `dbo` if not specified).
*   Permissions are checked on the *base object* when the synonym is used, not on the synonym itself (though `CONTROL` permission is needed on the synonym to drop it).
*   Cannot be referenced in DDL statements (e.g., `ALTER TABLE MySynonym ...` is invalid).
*   Cannot be the base object for another synonym (no chaining of synonyms directly, though a synonym can point to an object that another synonym points to).

## 2. Synonyms in Action: Analysis of `48_SYNONYMS.sql`

This script demonstrates creating and using synonyms for various object types.

**a) Basic Synonym for a Table**

```sql
CREATE SYNONYM ProjectList FOR Projects; -- Assumes Projects table in default schema (dbo)
GO
SELECT * FROM ProjectList; -- Query using the synonym
GO
```

*   **Explanation:** Creates an alias `ProjectList` for the `Projects` table. Queries can now use `ProjectList` instead of `Projects`.

**b) Synonym for Table in Another Schema**

```sql
CREATE SYNONYM EmployeeList FOR HR.Employees;
GO
SELECT * FROM EmployeeList;
GO
```

*   **Explanation:** Creates `EmployeeList` (in the default `dbo` schema) as an alias for the table `Employees` located in the `HR` schema.

**c) Synonym for a View**

```sql
CREATE VIEW HR.EmployeeDetails AS SELECT ...;
GO
CREATE SYNONYM StaffDirectory FOR HR.EmployeeDetails;
GO
SELECT * FROM StaffDirectory;
GO
```

*   **Explanation:** Creates `StaffDirectory` as an alias for the view `HR.EmployeeDetails`.

**d) Synonym for a Stored Procedure**

```sql
CREATE SYNONYM GetProjects FOR sp_GetAllProjects;
GO
EXEC GetProjects; -- Execute procedure using synonym
GO
```

*   **Explanation:** Creates `GetProjects` as an alias for the stored procedure `sp_GetAllProjects`.

**e) Synonym for a User-Defined Function**

```sql
CREATE SYNONYM CalcDuration FOR dbo.fn_CalculateProjectDuration;
GO
SELECT ..., CalcDuration(StartDate, EndDate) AS DurationInDays FROM Projects;
GO
```

*   **Explanation:** Creates `CalcDuration` as an alias for the scalar function `dbo.fn_CalculateProjectDuration`.

**f) Synonym for Object in Another Database**

```sql
-- Assumes ArchiveDB database exists
CREATE SYNONYM OldProjects FOR ArchiveDB.dbo.ArchivedProjects;
GO
-- SELECT * FROM OldProjects; -- Query would access table in ArchiveDB
```

*   **Explanation:** Creates `OldProjects` in the current database (`HRSystem`) as an alias for a table in a different database (`ArchiveDB`). Requires the user querying the synonym to have permissions in *both* databases.

**g) Synonym for Table on a Linked Server**

```sql
-- Assumes REMOTESERVER linked server exists
CREATE SYNONYM RemoteEmployees FOR REMOTESERVER.HRSystem.HR.Employees;
GO
-- SELECT * FROM RemoteEmployees; -- Query would access table on linked server
```

*   **Explanation:** Creates `RemoteEmployees` as an alias for a table located on a linked server, simplifying the four-part name.

**h) Synonym with a Different Schema**

```sql
CREATE SCHEMA Reporting;
GO
CREATE SYNONYM Reporting.ProjectStatus FOR dbo.ProjectStatus; -- Synonym in Reporting schema
GO
SELECT * FROM Reporting.ProjectStatus; -- Query using schema-qualified synonym
GO
```

*   **Explanation:** Demonstrates creating a synonym (`ProjectStatus`) within a specific schema (`Reporting`).

**i) Dropping a Synonym (`DROP SYNONYM`)**

```sql
DROP SYNONYM IF EXISTS ProjectList;
GO
```

*   **Explanation:** Removes the synonym definition. Does not affect the base object. `IF EXISTS` prevents errors if the synonym doesn't exist.

**j) Altering a Synonym**

```sql
-- No ALTER SYNONYM command exists
DROP SYNONYM IF EXISTS StaffDirectory;
GO
CREATE SYNONYM StaffDirectory FOR HR.EmployeeDetails; -- Recreate with potentially new definition
GO
```

*   **Explanation:** SQL Server does not have an `ALTER SYNONYM` command. To change what a synonym points to, you must `DROP` the existing synonym and then `CREATE` it again pointing to the new base object reference.

**k) Synonyms for Database Abstraction**

```sql
CREATE SYNONYM Employees FOR HR.Employees;
CREATE SYNONYM Departments FOR HR.Departments;
GO
-- Query without schema prefixes
SELECT ... FROM Employees e JOIN Departments d ON ...;
GO
```

*   **Explanation:** By creating synonyms in the default `dbo` schema for objects residing in other schemas (like `HR`), queries can be written without schema prefixes, potentially simplifying code or aiding migration if schemas change later (only the synonyms need updating).

**l) Synonyms for Version Control**

```sql
CREATE TABLE ProjectsV2 (...); -- New version of table
GO
DROP SYNONYM IF EXISTS CurrentProjects;
CREATE SYNONYM CurrentProjects FOR ProjectsV2; -- Point synonym to new version
GO
SELECT * FROM CurrentProjects; -- Application uses synonym, now gets data from V2
GO
```

*   **Explanation:** Use a synonym (e.g., `CurrentProjects`) to represent the currently active version of a table or procedure. Applications code against the synonym. When a new version (`ProjectsV2`) is deployed, you simply update the synonym to point to the new version, allowing applications to switch seamlessly without code changes.

**m) Synonyms and Table Partitioning (Conceptual)**

*   **Explanation:** While the script creates partitioned tables, it doesn't directly show synonyms used *with* partitioning in a typical way. Synonyms point to a single base object name. While that base object *could* be a partitioned table or a view built over partitioned tables (like a partitioned view), the synonym itself doesn't directly interact with the partitioning mechanism. It simply provides an alias for the object name.

## 3. Targeted Interview Questions (Based on `48_SYNONYMS.sql`)

**Question 1:** What is the primary purpose of creating a synonym in SQL Server? Give an example use case.

**Solution 1:** The primary purpose is to provide an **alias** or alternative name for another database object, creating a layer of **abstraction**.
*   **Example Use Case:** To hide the complexity of a four-part linked server name. Instead of writing `SELECT * FROM MyLinkedServer.TargetDB.dbo.CustomerTable;`, you could create `CREATE SYNONYM RemoteCustomers FOR MyLinkedServer.TargetDB.dbo.CustomerTable;` and then simply write `SELECT * FROM RemoteCustomers;`. If the linked server or database name changes, only the synonym needs updating.

**Question 2:** If you grant `SELECT` permission on a synonym `MySynonym` (which points to `dbo.MyTable`), does the user need permissions on `MySynonym` or `dbo.MyTable` to successfully query `MySynonym`?

**Solution 2:** The user needs `SELECT` permission on the **underlying base object** (`dbo.MyTable`). Permissions are checked on the base object when a synonym is used, not on the synonym itself (except for `CONTROL` permission needed to drop the synonym). Granting permission *on* the synonym has no effect on accessing the base object.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What command is used to create a synonym?
    *   **Answer:** `CREATE SYNONYM synonym_name FOR base_object_name;`.
2.  **[Easy]** Can a synonym point to another synonym?
    *   **Answer:** No, direct chaining of synonyms (`CREATE SYNONYM S2 FOR S1;`) is not allowed.
3.  **[Medium]** Can you use `ALTER SYNONYM` to change the base object a synonym points to?
    *   **Answer:** No. You must `DROP` the existing synonym and then `CREATE` it again with the new base object reference.
4.  **[Medium]** If you drop the base object (e.g., `DROP TABLE dbo.MyTable`), what happens to a synonym (`MySynonym`) that points to it? Does the synonym get dropped automatically?
    *   **Answer:** No, the synonym does **not** get dropped automatically. However, the synonym becomes **invalid**. Attempting to use the synonym (`SELECT * FROM MySynonym`) after the base object is dropped will result in an error stating the object does not exist.
5.  **[Medium]** Can a synonym cross database boundaries on the same SQL Server instance?
    *   **Answer:** Yes. You can create a synonym in `DatabaseA` that points to an object in `DatabaseB` using a three-part name (e.g., `CREATE SYNONYM DBaS_Table FOR DatabaseB.dbo.SomeTable;`).
6.  **[Medium]** Can you create an index or a trigger directly on a synonym?
    *   **Answer:** No. Synonyms are just aliases. Indexes and triggers must be created on the actual base object (table or view).
7.  **[Hard]** How do synonyms interact with schema binding (`WITH SCHEMABINDING`)? Can a schema-bound view or function reference a synonym?
    *   **Answer:** No, a schema-bound object (view or function created `WITH SCHEMABINDING`) **cannot** reference a synonym. Schema binding requires direct references to the base objects using two-part names (`SchemaName.ObjectName`) to ensure the underlying schema cannot be changed in a way that breaks the bound object. Synonyms introduce a layer of indirection incompatible with schema binding.
8.  **[Hard]** If a synonym `MySyn` points to `TableA`, and you later drop and recreate `TableA` (perhaps with a slightly different structure), does the synonym `MySyn` automatically work with the new `TableA`?
    *   **Answer:** Yes, the synonym `MySyn` will automatically point to the *new* `TableA` as long as it has the same name and schema. The synonym binds by name, not by object ID. However, if the *structure* of the new `TableA` has changed significantly (e.g., columns referenced by code using the synonym were dropped), the code using the synonym might fail at runtime, even though the synonym itself is still valid.
9.  **[Hard]** Can different users have different synonyms with the same name pointing to different base objects?
    *   **Answer:** Yes, if the synonyms are created in different schemas. Synonyms are schema-scoped objects. `UserA` could have `Sales.MyData` pointing to `Sales.ActualData`, while `UserB` could have `Marketing.MyData` pointing to `Marketing.CampaignData`. If both users have `dbo` as their default schema and try to create `dbo.MyData`, only the first one would succeed.
10. **[Hard/Tricky]** Does using a synonym instead of the fully qualified base object name have any significant performance impact on query execution?
    *   **Answer:** Generally, no. Using a synonym typically has negligible performance impact. SQL Server resolves the synonym name to the base object name during the query compilation phase (specifically, during name resolution). Once resolved, the query optimizer generates a plan based on the actual base object and its statistics. The overhead of the name lookup is minimal and usually occurs only once during compilation, not during execution for each row.
