# SQL Deep Dive: Sequence Objects

## 1. Introduction: What are Sequences?

A **Sequence** is a user-defined, schema-bound object in SQL Server (introduced in SQL Server 2012) that generates a sequence of numeric values according to a specified specification. Unlike `IDENTITY` columns (which are tied to a specific table column), sequences are independent objects that can be used to generate values for multiple tables or for other purposes.

**Why use Sequences?**

*   **Shared Number Generation:** Generate unique identifiers across multiple tables (e.g., a global ID for different entity types like Employees and Contractors).
*   **Pre-fetching IDs:** Obtain the next sequence value *before* inserting a row (using `NEXT VALUE FOR`), which is not possible with `IDENTITY`. This can be useful in certain application scenarios or when needing the ID before the `INSERT`.
*   **Cycling/Restarting:** Sequences offer more control over behavior, including the ability to cycle back to the start value after reaching a maximum or minimum, and explicit restarting.
*   **Flexibility:** Can define start value, increment, min/max values, caching behavior, and data type (`TINYINT`, `SMALLINT`, `INT`, `BIGINT`, `DECIMAL`, `NUMERIC`).

**Key Characteristics:**

*   Defined using `CREATE SEQUENCE sequence_name AS data_type ...`.
*   Independent of tables.
*   Generates values using `NEXT VALUE FOR sequence_name`.
*   Values are generated outside the scope of the current transaction (gaps can occur if a transaction rolls back after getting a value).
*   Supports caching for performance.

**Sequence vs. `IDENTITY`:**

| Feature         | `SEQUENCE`                                  | `IDENTITY` Column                           |
| :-------------- | :------------------------------------------ | :------------------------------------------ |
| **Scope**       | Database Object (Independent)               | Table Column Property                       |
| **Usage**       | Multiple Tables, Pre-fetch ID               | Single Table Column                         |
| **Get Next ID** | `NEXT VALUE FOR SeqName` (before/during DML) | Automatic during `INSERT` (`SCOPE_IDENTITY`) |
| **Cycling**     | Yes (`CYCLE` option)                        | No                                          |
| **Restart**     | Yes (`ALTER SEQUENCE ... RESTART`)          | Yes (`DBCC CHECKIDENT` with RESEED)         |
| **Caching**     | Yes (`CACHE` option)                        | No (Internal mechanism)                     |
| **Data Type**   | Various numeric types                       | `INT`, `BIGINT`, `SMALLINT`, `TINYINT`, `DECIMAL`, `NUMERIC` |
| **Gaps**        | Can occur (Rollback, Cache, Restart)        | Can occur (Rollback, `DELETE`, Failed `INSERT`) |

## 2. Sequences in Action: Analysis of `51_SEQUENCES.sql`

This script demonstrates creating, using, and managing sequence objects.

**a) Creating Basic Sequences (`CREATE SEQUENCE`)**

```sql
CREATE SEQUENCE BasicSequence AS INT START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE HR.EmployeeIDSequence AS INT START WITH 2000 INCREMENT BY 1;
CREATE SEQUENCE Finance.InvoiceNumberSequence AS INT MINVALUE 10000 MAXVALUE 99999 CYCLE;
CREATE SEQUENCE dbo.EvenNumberSequence AS INT START WITH 2 INCREMENT BY 2;
CREATE SEQUENCE dbo.CountdownSequence AS INT START WITH 100 INCREMENT BY -1 NO CYCLE;
```

*   **Explanation:** Shows creating sequences with different starting points (`START WITH`), increments (`INCREMENT BY`), data types (`AS INT`), optional boundaries (`MINVALUE`, `MAXVALUE`), and cycling behavior (`CYCLE` / `NO CYCLE`). Sequences can belong to specific schemas.

**b) Using Sequences (`NEXT VALUE FOR`)**

```sql
-- Get next value
SELECT NEXT VALUE FOR BasicSequence AS NextValue;
-- Use in INSERT
INSERT INTO HR.Departments_Seq (DepartmentID, ...) VALUES (NEXT VALUE FOR HR.EmployeeIDSequence, ...);
-- Use as DEFAULT constraint
CREATE TABLE Finance.Invoices_Seq (InvoiceID INT PRIMARY KEY DEFAULT (NEXT VALUE FOR Finance.InvoiceNumberSequence), ...);
INSERT INTO Finance.Invoices_Seq (CustomerID, Amount) VALUES (101, 1250.75); -- ID generated automatically
```

*   **Explanation:** The `NEXT VALUE FOR sequence_name` expression retrieves the next available value from the sequence according to its definition (start, increment, cycle). It can be used in `SELECT` lists, `VALUES` clauses of `INSERT`, or as a `DEFAULT` constraint for a column. Each call to `NEXT VALUE FOR` increments the sequence value, even within the same statement.

**c) Modifying Sequences (`ALTER SEQUENCE`)**

```sql
ALTER SEQUENCE dbo.EvenNumberSequence INCREMENT BY 4;
ALTER SEQUENCE Finance.InvoiceNumberSequence MAXVALUE 999999;
ALTER SEQUENCE HR.EmployeeIDSequence RESTART WITH 3000;
ALTER SEQUENCE dbo.CountdownSequence CYCLE;
```

*   **Explanation:** Modifies properties of an existing sequence, such as the increment value, min/max boundaries, cycling behavior, or cache size. `RESTART [WITH value]` resets the sequence to its defined start value or a specified value.

**d) Restarting Sequences (`ALTER SEQUENCE ... RESTART`)**

```sql
ALTER SEQUENCE BasicSequence RESTART; -- Reset to original START WITH value
```

*   **Explanation:** Explicitly resets the sequence counter back to its initial `START WITH` value. The next call to `NEXT VALUE FOR` will return the start value.

**e) Dropping Sequences (`DROP SEQUENCE`)**

```sql
DROP SEQUENCE IF EXISTS TempSequence;
```

*   **Explanation:** Removes the sequence object from the database. `IF EXISTS` prevents errors if the sequence doesn't exist.

**f) Querying Sequence Information (`sys.sequences`)**

```sql
SELECT s.name, SCHEMA_NAME(s.schema_id), TYPE_NAME(s.user_type_id), s.start_value, s.increment, ..., s.current_value
FROM sys.sequences s ORDER BY ...;
-- Get current value without incrementing
SELECT current_value FROM sys.sequences WHERE name = '...';
```

*   **Explanation:** Uses the `sys.sequences` system catalog view to retrieve metadata about defined sequences, including their properties (start, increment, min/max, cycle, cache) and the *last value generated* (`current_value`). Note that `current_value` shows the last value *dispensed*, not necessarily the next value to be generated.

**g) Sequence Performance and Caching (`CACHE`, `NO CACHE`)**

```sql
CREATE SEQUENCE HR.PerformanceSequence AS BIGINT CACHE 100; -- Cache 100 values
CREATE SEQUENCE HR.NoCache_Sequence AS INT NO CACHE; -- No caching
```

*   **Explanation:** The `CACHE [size]` option allows SQL Server to pre-allocate a specified number of sequence values in memory for faster retrieval. This reduces the I/O associated with updating the sequence metadata on disk for every `NEXT VALUE FOR` call, improving performance for high-frequency usage. The default cache size depends on the data type. `NO CACHE` forces a disk write for every value generated.
*   **Trade-off:** Caching increases the likelihood of larger gaps in the sequence if the server restarts unexpectedly, as the unused cached values are lost.

**h) Sequence vs. Identity Comparison**

*   **Explanation:** The script contrasts creating a table using a standard `IDENTITY` column versus using a `SEQUENCE` object with a `DEFAULT` constraint to populate the primary key. Both achieve auto-generated keys, but sequences offer more flexibility (shared across tables, pre-fetchable).

**i) Using Sequences for Multi-Table IDs**

```sql
CREATE SEQUENCE dbo.GlobalIDSequence AS BIGINT CACHE 1000;
CREATE TABLE HR.Employees_Global (EntityID BIGINT PRIMARY KEY DEFAULT (NEXT VALUE FOR dbo.GlobalIDSequence), ...);
CREATE TABLE HR.Contractors_Global (EntityID BIGINT PRIMARY KEY DEFAULT (NEXT VALUE FOR dbo.GlobalIDSequence), ...);
```

*   **Explanation:** Demonstrates a key use case: using a single `GlobalIDSequence` to generate unique primary keys across multiple related tables (`Employees_Global`, `Contractors_Global`), ensuring no ID collisions between different entity types stored separately.

**j) Generating Formatted Codes with Sequences**

```sql
CREATE SEQUENCE Finance.InvoiceCodeSequence AS INT;
CREATE FUNCTION Finance.GenerateInvoiceNumber() RETURNS VARCHAR(20) AS BEGIN
    DECLARE @NextVal INT = NEXT VALUE FOR Finance.InvoiceCodeSequence;
    RETURN 'INV-' + FORMAT(@NextVal, '000000'); -- Format the number
END;
CREATE TABLE Finance.InvoiceHeaders (InvoiceNumber VARCHAR(20) PRIMARY KEY DEFAULT (Finance.GenerateInvoiceNumber()), ...);
```

*   **Explanation:** Uses a sequence (`InvoiceCodeSequence`) to generate the numeric part of a formatted code (`InvoiceNumber`). A scalar function (`GenerateInvoiceNumber`) retrieves the next sequence value, formats it (adding prefix 'INV-' and zero-padding), and returns the complete code string. This function is then used as the `DEFAULT` for the table column.

**k) Sequence Gaps**

*   **Explanation:** The script notes that gaps in the sequence values are expected and normal. They can occur if:
    *   A transaction requests a value (`NEXT VALUE FOR`) but then rolls back. The fetched value is *not* returned to the sequence.
    *   The server restarts unexpectedly, losing any values cached in memory (`CACHE` option).
    *   The sequence cycles.
*   Applications should not rely on sequence values being strictly contiguous.

## 3. Targeted Interview Questions (Based on `51_SEQUENCES.sql`)

**Question 1:** What is the main difference between using an `IDENTITY` property on a column and using a `SEQUENCE` object with a `DEFAULT` constraint for generating primary key values?

**Solution 1:** The main difference is scope and independence.
*   `IDENTITY` is a property *of a specific table column*. Its values are tied directly to that column and table.
*   `SEQUENCE` is an *independent database object*. Its values can be requested using `NEXT VALUE FOR` and used as defaults or inserted into columns across *multiple* tables, or used outside of table inserts altogether. Sequences also offer more control options like `CYCLE`, `CACHE`, `MINVALUE`, `MAXVALUE`.

**Question 2:** What does the `CACHE` option do when creating a sequence, and what is the potential trade-off?

**Solution 2:**

*   **Purpose:** The `CACHE [size]` option improves performance by allowing SQL Server to pre-allocate a block of sequence values (e.g., 100 values) in memory. Subsequent calls to `NEXT VALUE FOR` retrieve values from this memory cache quickly, reducing the disk I/O needed to update the sequence's persistent state for every single value generated.
*   **Trade-off:** If the SQL Server instance shuts down unexpectedly (crash, power loss), any unused sequence values held in the memory cache are **lost**. This results in larger potential **gaps** in the sequence numbers when the server restarts and allocates a new cache block. `NO CACHE` avoids this risk but incurs more I/O overhead per generated value.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What function/expression is used to get the next value from a sequence named `MySeq`?
    *   **Answer:** `NEXT VALUE FOR MySeq`.
2.  **[Easy]** Can a sequence generate descending values?
    *   **Answer:** Yes, by specifying a negative `INCREMENT BY` value (e.g., `INCREMENT BY -1`).
3.  **[Medium]** Can you use `SCOPE_IDENTITY()` or `@@IDENTITY` to retrieve the last value generated by a `SEQUENCE` used in a `DEFAULT` constraint during an `INSERT`?
    *   **Answer:** No. `SCOPE_IDENTITY()` and `@@IDENTITY` specifically return values generated by `IDENTITY` columns, not by `SEQUENCE` objects used in defaults or inserts. To get the value inserted via a sequence default, you would typically use the `OUTPUT` clause in the `INSERT` statement.
4.  **[Medium]** What happens if you call `NEXT VALUE FOR` on a sequence defined with `NO CYCLE` after it has reached its `MAXVALUE` (for an ascending sequence)?
    *   **Answer:** An error will be raised indicating that the sequence object has reached its limit.
5.  **[Medium]** Does calling `NEXT VALUE FOR MySeq` within a transaction that later gets rolled back cause the sequence value to be "returned" or reused?
    *   **Answer:** No. Once `NEXT VALUE FOR` is executed, the sequence value is considered consumed, regardless of whether the transaction commits or rolls back. This contributes to potential gaps in the sequence.
6.  **[Medium]** Can you change the `START WITH` value of an existing sequence using `ALTER SEQUENCE`? How do you reset a sequence?
    *   **Answer:** You cannot directly change the original `START WITH` value using `ALTER SEQUENCE`. However, you can effectively reset the sequence to start again from a specific value (including the original start value) using `ALTER SEQUENCE sequence_name RESTART WITH new_start_value;` or simply `ALTER SEQUENCE sequence_name RESTART;` to reset to the original start value.
7.  **[Hard]** Can a single call to `NEXT VALUE FOR` return different values if referenced multiple times within the *same* `SELECT` statement (e.g., `SELECT NEXT VALUE FOR MySeq, NEXT VALUE FOR MySeq FROM MyTable`)?
    *   **Answer:** Yes. According to the SQL Standard (and SQL Server's implementation), `NEXT VALUE FOR` is incremented *once per row* it appears for within the statement. If referenced multiple times in the `SELECT` list for the *same row*, it will return the *same* incremented value for that row across all references in the list. However, it will return a *different* (incremented) value for the *next row* processed by the query. (The script example `SELECT NEXT VALUE FOR BasicSequence AS Value1, NEXT VALUE FOR BasicSequence AS Value2` is slightly misleading if interpreted as running on multiple rows; if run as `SELECT NEXT VALUE FOR BasicSequence, NEXT VALUE FOR BasicSequence;` it returns two *different* values in a single row result). The key is it increments once per outer row reference.
8.  **[Hard]** How does the `CACHE` size affect potential gaps in sequence numbers upon server restart?
    *   **Answer:** When SQL Server restarts unexpectedly, any sequence values pre-allocated in the memory cache are lost. The larger the `CACHE` size, the larger the potential gap in the sequence numbers can be after a restart, because up to `CACHE - 1` values might have been lost from memory. `NO CACHE` minimizes this risk but has higher I/O overhead.
9.  **[Hard]** Can you grant permissions specifically on a `SEQUENCE` object? What permission is needed to use `NEXT VALUE FOR`?
    *   **Answer:** Yes, sequences are securable objects. You can `GRANT`, `DENY`, or `REVOKE` permissions like `UPDATE` (required to call `NEXT VALUE FOR`), `ALTER`, `CONTROL`, and `VIEW DEFINITION` on a sequence object (`GRANT UPDATE ON SEQUENCE::MySchema.MySeq TO UserName;`). To use `NEXT VALUE FOR`, the user needs `UPDATE` permission on the sequence.
10. **[Hard/Tricky]** Is the value returned by `NEXT VALUE FOR` guaranteed to be unique across concurrent sessions if the sequence is defined without `CYCLE`? What about strictly increasing?
    *   **Answer:** Yes, the value is guaranteed to be unique across concurrent sessions (SQL Server manages the generation atomically). However, it is **not** guaranteed to be strictly increasing *relative to the time the value is requested or used* across different sessions due to caching and concurrent access. Session A might get value 100, Session B might get 101 shortly after, but Session A might commit its transaction using 100 *after* Session B commits its transaction using 101. The values generated are unique, but their insertion order into tables isn't necessarily sequential across sessions.
