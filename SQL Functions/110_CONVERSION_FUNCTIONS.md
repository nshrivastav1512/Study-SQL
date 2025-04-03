# SQL Conversion Functions

## Introduction

**Definition:** SQL Conversion Functions are used to convert an expression of one data type to another. This is essential when dealing with data from various sources, performing calculations involving different types, or formatting data for presentation.

**Explanation:** Data often exists in formats (like strings) that aren't suitable for direct calculation or comparison. Conversion functions allow you to explicitly change the data type (e.g., string to integer, string to date, number to string). SQL Server provides several functions for this, differing in syntax, error handling, and formatting capabilities.

## Functions Covered in this Section

This document covers key SQL Server Conversion Functions, demonstrated using hypothetical `HR.DataConversions` and `HR.PayrollData` tables:

1.  `CAST(expression AS data_type [(length)])`: Converts an expression to a specified data type. ANSI SQL standard. Raises an error if conversion fails.
2.  `CONVERT(data_type [(length)], expression [, style])`: Converts an expression to a specified data type. SQL Server specific. Offers optional `style` codes for formatting, especially for date/time and numeric-to-string conversions. Raises an error if conversion fails.
3.  `TRY_CAST(expression AS data_type [(length)])`: Attempts to convert an expression to a specified data type. Returns the converted value if successful, otherwise returns `NULL`. Does not raise an error on failure.
4.  `TRY_CONVERT(data_type [(length)], expression [, style])`: Attempts to convert an expression using optional style codes. Returns the converted value if successful, otherwise returns `NULL`. Does not raise an error on failure.
5.  `PARSE(string_value AS data_type [USING culture])`: Converts a string value to the specified data type (primarily date/time or numeric). Requires a target data type and optionally accepts a culture code (e.g., 'en-US', 'de-DE') to interpret locale-specific formats. Relies on .NET CLR and can be less performant. Raises an error on failure.
6.  `TRY_PARSE(string_value AS data_type [USING culture])`: Attempts to parse a string value using optional culture information. Returns the converted value if successful, otherwise returns `NULL`. Does not raise an error on failure.

*(Note: The SQL script includes logic to create and populate sample `HR.DataConversions` and `HR.PayrollData` tables if they don't exist.)*

---

## Examples

### 1. CAST()

**Goal:** Perform basic conversions of string data to numeric, date, time, and bit types.

```sql
SELECT
    ConversionID,
    StringNumber,
    -- Convert string to integer (using TRY_CAST for safety in WHERE)
    CAST(StringNumber AS INT) AS NumberAsInteger,
    -- Convert string to decimal
    CAST(StringDecimal AS DECIMAL(10,2)) AS NumberAsDecimal,
    -- Convert string to datetime
    CAST(StringDate AS DATETIME) AS DateAsDateTime,
    -- Convert string to time
    CAST(StringTime AS TIME) AS TimeAsTime,
    -- Convert string to bit (requires CASE logic)
    CAST(CASE
        WHEN LOWER(StringBoolean) IN ('true', 'yes', '1') THEN 1
        ELSE 0
    END AS BIT) AS BooleanAsBit
FROM HR.DataConversions
WHERE TRY_CAST(StringNumber AS INT) IS NOT NULL -- Filter for rows where StringNumber is convertible to INT
  AND TRY_CAST(StringDecimal AS DECIMAL(10,2)) IS NOT NULL
  AND TRY_CAST(StringDate AS DATETIME) IS NOT NULL
  AND TRY_CAST(StringTime AS TIME) IS NOT NULL;
```

**Explanation:**
*   `CAST(expression AS target_type)` attempts the conversion. If the `expression` cannot be converted to `target_type`, `CAST` raises an error.
*   The example uses `TRY_CAST` in the `WHERE` clause to pre-filter rows where direct `CAST` would fail, preventing query errors.
*   Converting boolean-like strings ('true', 'yes', '1') to `BIT` often requires a `CASE` statement as there's no direct cast.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data row 1:</p>
<pre><code>
ConversionID  StringNumber  NumberAsInteger  NumberAsDecimal  DateAsDateTime            TimeAsTime        BooleanAsBit
------------- ------------- ---------------- ---------------- ------------------------- ----------------- ------------
1             12345         12345            1234.56          2023-08-20 00:00:00.000   14:30:00.0000000   1
</code></pre>
</details>

### 2. CONVERT()

**Goal:** Convert dates and numbers to strings using specific format styles.

```sql
SELECT
    ConversionID,
    StringDate,
    StringDecimal,
    -- Convert date to string with different styles
    CONVERT(VARCHAR(20), CAST(StringDate AS DATETIME), 101) AS USDateFormat,      -- mm/dd/yyyy
    CONVERT(VARCHAR(20), CAST(StringDate AS DATETIME), 103) AS BritishDateFormat, -- dd/mm/yyyy
    CONVERT(VARCHAR(20), CAST(StringDate AS DATETIME), 104) AS GermanDateFormat,  -- dd.mm.yyyy
    CONVERT(VARCHAR(20), CAST(StringDate AS DATETIME), 120) AS ISO8601Format,     -- yyyy-mm-dd hh:mi:ss
    -- Convert number to string (money format)
    CONVERT(VARCHAR(20), CAST(StringDecimal AS MONEY), 1) AS MoneyFormat -- Style 1 adds commas and 2 decimal places
FROM HR.DataConversions
WHERE TRY_CAST(StringDate AS DATETIME) IS NOT NULL
  AND TRY_CAST(StringDecimal AS DECIMAL(10,2)) IS NOT NULL;
```

**Explanation:**
*   `CONVERT(target_type, expression, [style])` provides formatting options via the `style` code, especially useful for date/time and numeric types.
*   Style `101` = `mm/dd/yyyy`, `103` = `dd/mm/yyyy`, `104` = `dd.mm.yyyy`, `120` = ODBC canonical (`yyyy-mm-dd hh:mi:ss`).
*   Style `1` for `MONEY` conversion includes commas and two decimal places.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data row 1:</p>
<pre><code>
ConversionID  StringDate    StringDecimal  USDateFormat  BritishDateFormat  GermanDateFormat  ISO8601Format         MoneyFormat
------------- ------------- -------------- ------------- ------------------- ---------------- --------------------- -----------
1             2023-08-20    1234.56        08/20/2023    20/08/2023          20.08.2023       2023-08-20 00:00:00   1,234.56
</code></pre>
</details>

### 3. TRY_CAST()

**Goal:** Attempt to convert strings to numbers safely, returning NULL if the conversion fails instead of an error.

```sql
SELECT
    ConversionID,
    StringNumber,
    StringDecimal,
    -- Safe conversion attempts
    TRY_CAST(StringNumber AS INT) AS SafeInteger,
    TRY_CAST(StringDecimal AS DECIMAL(10,2)) AS SafeDecimal,
    -- Check conversion success
    CASE
        WHEN TRY_CAST(StringNumber AS INT) IS NULL THEN 'Invalid Integer String'
        ELSE 'Valid Integer String'
    END AS IntegerConversionStatus,
    CASE
        WHEN TRY_CAST(StringDecimal AS DECIMAL(10,2)) IS NULL THEN 'Invalid Decimal String'
        ELSE 'Valid Decimal String'
    END AS DecimalConversionStatus
FROM HR.DataConversions;
```

**Explanation:**
*   `TRY_CAST(expression AS target_type)` works like `CAST` but returns `NULL` if the conversion is not possible (e.g., casting 'ABC' to INT).
*   This allows checking for conversion success using `IS NULL` or `IS NOT NULL`.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
ConversionID  StringNumber  StringDecimal  SafeInteger  SafeDecimal  IntegerConversionStatus  DecimalConversionStatus
------------- ------------- -------------- ------------ ------------ ------------------------ ------------------------
1             12345         1234.56        12345        1234.56      Valid Integer String     Valid Decimal String
2             ABC123        1,234.56       NULL         1234.56      Invalid Integer String   Valid Decimal String
3             9999.99       1234,56        9999         NULL         Valid Integer String     Invalid Decimal String
4             -123.45       $1,234.56      -123         NULL         Valid Integer String     Invalid Decimal String
</code></pre>
<p><i>Note: `TRY_CAST` to DECIMAL often fails with currency symbols or locale-specific separators like commas. `TRY_PARSE` is better for those.</i></p>
</details>

### 4. TRY_CONVERT()

**Goal:** Attempt to convert strings to dates using specific style codes safely, returning NULL on failure.

```sql
SELECT
    ConversionID,
    LocaleDate,
    -- Try converting using different expected formats (styles)
    TRY_CONVERT(DATE, LocaleDate, 103) AS BritishDateAttempt,     -- Expects dd/mm/yyyy
    TRY_CONVERT(DATE, LocaleDate, 104) AS GermanDateAttempt,      -- Expects dd.mm.yyyy
    TRY_CONVERT(DATE, LocaleDate, 101) AS USADateAttempt,         -- Expects mm/dd/yyyy
    -- Identify which format worked (if any)
    CASE
        WHEN TRY_CONVERT(DATE, LocaleDate, 103) IS NOT NULL THEN 'dd/mm/yyyy (Style 103)'
        WHEN TRY_CONVERT(DATE, LocaleDate, 104) IS NOT NULL THEN 'dd.mm.yyyy (Style 104)'
        WHEN TRY_CONVERT(DATE, LocaleDate, 101) IS NOT NULL THEN 'mm/dd/yyyy (Style 101)'
        ELSE 'Format Not Recognized by Styles 101, 103, 104'
    END AS RecognizedFormat
FROM HR.DataConversions;
```

**Explanation:**
*   `TRY_CONVERT(target_type, expression, [style])` works like `CONVERT` but returns `NULL` on failure.
*   This is useful when trying to parse data that might arrive in one of several known formats.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
ConversionID  LocaleDate    BritishDateAttempt  GermanDateAttempt  USADateAttempt  RecognizedFormat
------------- ------------- ------------------- ------------------ --------------- ---------------------------------------------
1             20/08/2023    2023-08-20          NULL               NULL            dd/mm/yyyy (Style 103)
2             08/20/2023    NULL                NULL               2023-08-20      mm/dd/yyyy (Style 101)
3             20.08.2023    NULL                2023-08-20         NULL            dd.mm.yyyy (Style 104)
4             20-8-2023     NULL                NULL               NULL            Format Not Recognized by Styles 101, 103, 104
</code></pre>
</details>

### 5. PARSE()

**Goal:** Convert string representations of numbers and dates using specific cultural formatting rules (e.g., decimal separators).

```sql
SELECT
    ConversionID,
    NumberFormat,
    LocaleDate,
    -- Parse numbers using US ('.') and German (',') decimal separators
    PARSE(NumberFormat AS DECIMAL(10,2) USING 'en-US') AS USParsedNumber,
    PARSE(NumberFormat AS DECIMAL(10,2) USING 'de-DE') AS GermanParsedNumber,
    -- Parse dates using US and German culture expectations
    PARSE(LocaleDate AS DATE USING 'en-US') AS USParsedDate,
    PARSE(LocaleDate AS DATE USING 'de-DE') AS GermanParsedDate
FROM HR.DataConversions
WHERE ConversionID IN (1, 3); -- Select rows with different formats
```

**Explanation:**
*   `PARSE(string AS target_type USING culture)` converts a string based on the formatting rules of the specified `culture`.
*   `'en-US'` expects `.` as decimal separator, `,` as thousands separator, `mm/dd/yyyy` date format.
*   `'de-DE'` expects `,` as decimal separator, `.` as thousands separator, `dd.mm.yyyy` date format.
*   `PARSE` raises an error if parsing fails.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
ConversionID  NumberFormat  LocaleDate    USParsedNumber  GermanParsedNumber  USParsedDate  GermanParsedDate
------------- ------------- ------------- --------------- ------------------ ------------ ----------------
1             1,234.56      20/08/2023    1234.56         1234.56            2023-08-20   2023-08-20
3             1234,56       20.08.2023    NULL            1234.56            2023-08-20   2023-08-20
</code></pre>
<p><i>Note: PARSE might fail depending on exact input and culture rules. The output assumes successful parsing where applicable, NULL otherwise (though PARSE would error). Using TRY_PARSE is safer.</i></p>
</details>

### 6. TRY_PARSE()

**Goal:** Safely parse potentially messy payroll strings (currency, percentages, different date formats) into appropriate data types using a specific culture.

```sql
SELECT
    PayrollID,
    SalaryString,
    BonusString,
    JoinDateString,
    TaxRateString,
    -- Safely parse currency (remove symbols first)
    TRY_PARSE(REPLACE(REPLACE(SalaryString, '$', ''), ',', '') AS DECIMAL(10,2) USING 'en-US') AS ParsedSalary,
    TRY_PARSE(REPLACE(REPLACE(BonusString, '$', ''), ',', '') AS DECIMAL(10,2) USING 'en-US') AS ParsedBonus,
    -- Safely parse dates (assuming US format primarily)
    TRY_PARSE(JoinDateString AS DATE USING 'en-US') AS ParsedJoinDate,
    -- Safely parse percentages (remove '%' first)
    TRY_PARSE(REPLACE(TaxRateString, '%', '') AS DECIMAL(5,2) USING 'en-US') AS ParsedTaxRatePercent
FROM HR.PayrollData;
```

**Explanation:**
*   `TRY_PARSE(string AS target_type USING culture)` works like `PARSE` but returns `NULL` on failure instead of raising an error.
*   It's often combined with `REPLACE` to remove non-numeric characters (like `$`, `,`, `%`) before attempting the parse.
*   Specifying the `culture` helps interpret formats correctly (e.g., date order, decimal separators).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
PayrollID  SalaryString  BonusString  JoinDateString  TaxRateString  ParsedSalary  ParsedBonus  ParsedJoinDate  ParsedTaxRatePercent
---------  ------------  -----------  --------------  -------------  ------------  -----------  --------------  --------------------
1          $75,000.00    5000         2023-01-15      22.5%          75000.00      5000.00      2023-01-15      22.50
2          85000         $7,500.00    15/01/2023      24%            85000.00      7500.00      2023-01-15      24.00
3          $65,000       4500.50      2023.01.15      21.5%          65000.00      4500.50      NULL            21.50
4          95000.00      $8,000       Jan 15, 2023    25.0%          95000.00      8000.00      2023-01-15      25.00
</code></pre>
<p><i>Note: `TRY_PARSE` for JoinDateString row 3 returns NULL because '2023.01.15' is not a standard 'en-US' format.</i></p>
</details>

---

## Interview Question

**Question:** You have a `VARCHAR` column `ImportedValue` that sometimes contains integer numbers and sometimes contains non-numeric text. Write a query that selects the `ImportedValue` and a new column `NumericValue` which contains the integer value if the conversion is possible, and `0` otherwise. Avoid generating errors.

### Solution Script

```sql
SELECT
    ImportedValue,
    ISNULL(TRY_CAST(ImportedValue AS INT), 0) AS NumericValue
FROM YourTable; -- Replace YourTable with the actual table name
```

### Explanation

1.  **`TRY_CAST(ImportedValue AS INT)`**: This attempts to convert the `ImportedValue` string to an integer.
    *   If `ImportedValue` contains a valid integer representation (e.g., '123', '-45'), `TRY_CAST` returns that integer value.
    *   If `ImportedValue` cannot be converted to an integer (e.g., 'ABC', '12.3'), `TRY_CAST` returns `NULL`. Crucially, it does *not* raise an error.
2.  **`ISNULL(..., 0)`**: This function checks the result of `TRY_CAST`.
    *   If `TRY_CAST` returned an integer (meaning the conversion was successful), `ISNULL` returns that integer.
    *   If `TRY_CAST` returned `NULL` (meaning the conversion failed), `ISNULL` replaces the `NULL` with the specified default value, which is `0` in this case.
3.  **`SELECT ImportedValue, ... AS NumericValue FROM YourTable`**: Selects the original string and the calculated `NumericValue` (either the converted integer or 0) for each row in the table.

---

## Tricky Interview Questions (Easy to Hard)

1.  **Easy:** What is the main difference between `CAST` and `TRY_CAST` in terms of error handling?
    *   *(Answer Hint: `CAST` errors on failure, `TRY_CAST` returns NULL)*
2.  **Easy:** When converting a date to a string using `CONVERT`, what is the purpose of the optional third 'style' argument?
    *   *(Answer Hint: To specify the output format of the date/time string)*
3.  **Medium:** Why might `CAST('1,234.56' AS DECIMAL(10,2))` fail, while `PARSE('1,234.56' AS DECIMAL(10,2) USING 'en-US')` might succeed?
    *   *(Answer Hint: `CAST` doesn't handle culture-specific formatting like thousand separators; `PARSE` does)*
4.  **Medium:** Can `TRY_CONVERT(INT, '123.45')` successfully convert the string to an integer? What would it return?
    *   *(Answer Hint: No, it would return NULL because '123.45' is not a valid integer representation)*
5.  **Medium:** What are the potential performance implications of using `PARSE` or `TRY_PARSE` compared to `CAST` or `CONVERT`?
    *   *(Answer Hint: `PARSE`/`TRY_PARSE` rely on the .NET CLR and can be slower than the native `CAST`/`CONVERT` functions)*
6.  **Medium/Hard:** If you need to convert a `VARCHAR` containing 'dd/mm/yyyy' formatted dates, which function and style code would you use with `CONVERT` or `TRY_CONVERT`?
    *   *(Answer Hint: `CONVERT(DATE, YourColumn, 103)` or `TRY_CONVERT(DATE, YourColumn, 103)`)*
7.  **Hard:** How would you safely convert a `VARCHAR` column `HexValue` containing hexadecimal strings (e.g., '0x4A') to an `INT`?
    *   *(Answer Hint: Use `CONVERT(INT, YourColumn, 1)` for implicit hex conversion if the string starts with '0x', or `CONVERT(INT, CONVERT(VARBINARY, '0x' + YourColumn, 1))` if '0x' prefix is missing. Use `TRY_CONVERT` for safety)*
8.  **Hard:** You need to convert various string formats ('true', 'T', 'yes', 'Y', '1', 'false', 'F', 'no', 'N', '0') into a `BIT` column reliably. Write the `CASE` expression logic needed within a `CAST` or `TRY_CAST`.
    *   *(Answer Hint: `CASE WHEN LOWER(YourColumn) IN ('true', 't', 'yes', 'y', '1') THEN 1 WHEN LOWER(YourColumn) IN ('false', 'f', 'no', 'n', '0') THEN 0 ELSE NULL END` combined with `CAST` or `TRY_CAST`)*
9.  **Hard:** When might `TRY_CAST` return `NULL` even if the input string *looks* like a valid number (e.g., '9999999999999')?
    *   *(Answer Hint: Data type overflow - the number is too large for the target data type, e.g., `INT`)*
10. **Hard:** Compare and contrast `TRY_CONVERT` and `TRY_PARSE`. When would you choose one over the other for converting strings to dates or numbers?
    *   *(Answer Hint: `TRY_CONVERT` uses style codes for specific, known formats. `TRY_PARSE` uses culture rules for more flexible, locale-aware parsing but can be slower. Choose `TRY_CONVERT` for fixed formats, `TRY_PARSE` for locale-dependent formats or when needing culture rules.)*