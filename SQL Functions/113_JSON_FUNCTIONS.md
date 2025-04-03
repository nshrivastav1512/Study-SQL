# SQL JSON Functions

## Introduction

**Definition:** SQL JSON Functions are a set of built-in functions in SQL Server designed to parse, query, validate, and modify data stored in JavaScript Object Notation (JSON) format within standard SQL data types (typically `NVARCHAR`).

**Explanation:** As JSON has become a ubiquitous format for data interchange and storage (especially in NoSQL databases and web APIs), SQL Server introduced these functions to allow developers to work with JSON data directly within the relational database. This enables storing semi-structured JSON data alongside traditional relational data and querying or manipulating it using T-SQL, bridging the gap between relational and document-style data handling.

**JSON Path Expressions:** Most JSON functions rely on JSON path expressions (similar to XPath for XML) to navigate the JSON structure. Key elements include:
*   `$` : Represents the root of the JSON document.
*   `.` : Member accessor (e.g., `$.name`).
*   `[]`: Array accessor (e.g., `$.array[0]` for the first element).
*   `lax` vs `strict` mode (default is `lax`): `lax` mode returns NULL if the path doesn't exist; `strict` mode raises an error.

## Functions Covered in this Section

This document covers the core SQL Server JSON Functions, demonstrated using hypothetical `HR.EmployeeSkills` and `HR.EmployeePreferences` tables storing JSON data:

1.  `JSON_VALUE(expression, path)`: Extracts a *scalar* value (string, number, boolean, null) from a JSON string at the specified path.
2.  `JSON_QUERY(expression [, path])`: Extracts an *object* or an *array* from a JSON string at the specified path. Returns NULL if the path points to a scalar value. If `path` is omitted, returns the entire JSON expression if valid.
3.  `ISJSON(expression [, json_type_constraint])`: Tests if a string contains valid JSON. Returns 1 (true), 0 (false), or NULL (if input is NULL). Optionally checks against `VALUE`, `ARRAY`, `OBJECT`, or `SCALAR` constraints (SQL Server 2022+).
4.  `JSON_MODIFY(expression, path, newValue)`: Updates the value of a property in a JSON string and returns the updated JSON string. Can be used to insert, update, delete, or append values.
5.  `OPENJSON(jsonExpression [, path]) [WITH (colName type 'path' [AS JSON], ...)]`: Parses JSON text and returns objects and properties as rows and columns. It can return a default schema (key, value, type) or an explicitly defined schema using the `WITH` clause.

*(Note: The SQL script includes logic to create and populate sample `HR.EmployeeSkills` and `HR.EmployeePreferences` tables if they don't exist.)*

---

## Examples

### 1. JSON_VALUE()

**Goal:** Extract specific scalar values (like level, role, primary skill) from JSON data stored in columns.

```sql
SELECT
    EmployeeID,
    JSON_VALUE(SkillsData, '$.technical.level') AS TechnicalLevel,
    JSON_VALUE(ProjectHistory, '$.current.role') AS CurrentRole,
    -- Extract first element from an array
    JSON_VALUE(SkillsData, '$.technical.programming[0]') AS PrimaryProgrammingSkill
FROM HR.EmployeeSkills;
```

**Explanation:**
*   `JSON_VALUE(json_column, 'json_path')` navigates the JSON structure using the path expression.
*   `$.technical.level` accesses the `level` property within the nested `technical` object.
*   `$.current.role` accesses the `role` property within the `current` object.
*   `$.technical.programming[0]` accesses the first element (index 0) of the `programming` array within the `technical` object.
*   `JSON_VALUE` returns NULL if the path doesn't exist or points to an object/array (in `lax` mode).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
EmployeeID  TechnicalLevel  CurrentRole  PrimaryProgrammingSkill
----------  --------------  -----------  -----------------------
1           Senior          Lead         SQL
2           Mid             Developer    JavaScript
</code></pre>
</details>

### 2. JSON_QUERY()

**Goal:** Extract entire JSON objects or arrays (like programming skills list, soft skills list, previous projects array) from JSON data.

```sql
SELECT
    EmployeeID,
    JSON_QUERY(SkillsData, '$.technical.programming') AS ProgrammingSkillsArray,
    JSON_QUERY(SkillsData, '$.soft') AS SoftSkillsArray,
    JSON_QUERY(ProjectHistory, '$.previous') AS PreviousProjectsArray
FROM HR.EmployeeSkills;
```

**Explanation:**
*   `JSON_QUERY(json_column, 'json_path')` is used specifically to extract complex types (objects or arrays).
*   `$.technical.programming` path points to the array of programming languages.
*   `$.soft` path points to the array of soft skills.
*   `$.previous` path points to the array of previous project objects.
*   If the path pointed to a scalar value (e.g., `$.technical.level`), `JSON_QUERY` would return NULL.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
EmployeeID  ProgrammingSkillsArray         SoftSkillsArray                   PreviousProjectsArray
----------  ------------------------------ --------------------------------- -------------------------------------------------------------------------------------------------
1           ["SQL","Python","Java"]        ["Leadership","Communication"]    [{"name":"Data Warehouse","role":"Developer"},{"name":"BI Dashboard","role":"Analyst"}]
2           ["JavaScript","C#"]            ["Teamwork","Problem Solving"]    [{"name":"CRM System","role":"Frontend Dev"},{"name":"Mobile App","role":"Full Stack"}]
</code></pre>
</details>

### 3. ISJSON()

**Goal:** Validate whether the content of the `Preferences` column is valid JSON.

```sql
SELECT
    PreferenceID,
    EmployeeID,
    Preferences,
    ISJSON(Preferences) AS IsValidJSONFlag,
    CASE
        WHEN ISJSON(Preferences) = 1 THEN 'Valid JSON Format'
        ELSE 'Invalid JSON Format'
    END AS ValidationResult
FROM HR.EmployeePreferences;
```

**Explanation:**
*   `ISJSON(expression)` returns `1` if the `expression` contains syntactically correct JSON, and `0` otherwise. Returns `NULL` if the input is `NULL`.
*   Useful for data cleaning or validating data before attempting to parse it with other JSON functions.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Assuming the stored data is valid JSON:</p>
<pre><code>
PreferenceID  EmployeeID  Preferences                                                                                                                   IsValidJSONFlag ValidationResult
------------- ----------- ----------------------------------------------------------------------------------------------------------------------------- --------------- -------------------
1             1           {"workSchedule": "Remote", "notifications": {"email": true, "sms": false}, "theme": "Dark", "dashboard": [...]}             1               Valid JSON Format
2             2           {"workSchedule": "Hybrid", "notifications": {"email": true, "sms": true}, "theme": "Light", "dashboard": [...]}            1               Valid JSON Format
</code></pre>
</details>

### 4. JSON_MODIFY()

**Goal:** Demonstrate updating values within a JSON string: changing level, appending to an array, updating a nested value.

```sql
SELECT
    EmployeeID,
    -- Update $.technical.level to 'Principal'
    JSON_MODIFY(SkillsData, '$.technical.level', 'Principal') AS UpdatedLevelJson,
    -- Append 'TypeScript' to the programming array
    JSON_MODIFY(SkillsData, 'append $.technical.programming', 'TypeScript') AS AppendedSkillJson,
    -- Update the current role
    JSON_MODIFY(ProjectHistory, '$.current.role', 'Senior Lead') AS UpdatedRoleJson
FROM HR.EmployeeSkills
WHERE EmployeeID = 1;
```

**Explanation:**
*   `JSON_MODIFY(json_expression, path, new_value)` returns the modified JSON string.
*   The `path` specifies the element to modify.
*   `new_value` is the value to insert or update with.
*   Using `append` before the path adds the `new_value` to the end of the target array.
*   To delete a value, set `new_value` to `NULL`.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Shows the *modified JSON strings* for EmployeeID 1:</p>
<pre><code>
EmployeeID  UpdatedLevelJson                                                                                              UpdatedSkillJson                                                                                                        UpdatedRoleJson
