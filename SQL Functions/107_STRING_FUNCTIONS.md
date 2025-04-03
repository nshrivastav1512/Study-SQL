# SQL String Functions

## Introduction

**Definition:** SQL String Functions are built-in functions designed to perform operations on string (character) data types like `VARCHAR`, `NVARCHAR`, `CHAR`, etc. They allow you to manipulate, format, extract, compare, and transform text data within your SQL queries.

**Explanation:** String functions are fundamental for data cleaning, data transformation, reporting, and extracting meaningful information from text fields. They can be used in `SELECT` lists, `WHERE` clauses, `JOIN` conditions, and other parts of SQL statements to work with string values effectively.

## Functions Covered in this Section

This document covers a comprehensive set of SQL Server String Functions, demonstrated using a hypothetical `HR.Employees` table:

1.  `LEN()`: Returns the number of characters in a string (excluding trailing blanks).
2.  `SUBSTRING()`: Extracts a portion (substring) from a string.
3.  `UPPER()`: Converts a string to all uppercase letters.
4.  `LOWER()`: Converts a string to all lowercase letters.
5.  `TRIM()`: Removes specified leading and/or trailing characters (default is space) from a string.
6.  `LTRIM()`: Removes leading spaces from a string.
7.  `RTRIM()`: Removes trailing spaces from a string.
8.  `REPLACE()`: Replaces all occurrences of a specified substring with another substring.
9.  `LEFT()`: Extracts a specified number of characters from the beginning (left side) of a string.
10. `RIGHT()`: Extracts a specified number of characters from the end (right side) of a string.
11. `CHARINDEX()`: Returns the starting position of the first occurrence of a substring within a string.
12. `PATINDEX()`: Returns the starting position of the first occurrence of a pattern (using wildcard characters) within a string.
13. `CONCAT()`: Joins two or more strings together end-to-end. Treats NULL as an empty string.
14. `CONCAT_WS()`: Joins two or more strings together with a specified separator. Skips NULL arguments.
15. `FORMAT()`: Formats a value (like date, time, or number) as a string according to a specified format pattern (often culture-aware).
16. `REPLICATE()`: Repeats a string a specified number of times.
17. `STRING_SPLIT()`: Splits a string into multiple rows based on a specified separator character. Returns a table.
18. `QUOTENAME()`: Returns a Unicode string with delimiters (like `[]` or `""`) added to make the input string a valid SQL Server delimited identifier.
19. `UNICODE()`: Returns the integer Unicode code point value for the first character of the input expression.
20. `NCHAR()`: Converts an integer Unicode code point value into the corresponding Unicode character.
21. `CHAR()`: Converts an integer ASCII code value into the corresponding character.
22. `DIFFERENCE()`: Returns an integer value (0-4) indicating the similarity between the `SOUNDEX` values of two strings. Higher value means more similarity.
23. `SOUNDEX()`: Returns a four-character code based on how a string sounds in English. Useful for finding similarly sounding names.
24. `TRANSLATE()`: Replaces characters in an input string with corresponding characters from another string (character-by-character replacement).
25. `REVERSE()`: Returns the character expression in reverse order.

*(Note: The SQL script includes logic to create and populate a sample `HR.Employees` table if it doesn't exist.)*

---

## Examples

### 1. LEN()

**Goal:** Get the length of employee first and last names.

```sql
SELECT
    FirstName,
    LEN(FirstName) AS NameLength,
    LastName,
    LEN(LastName) AS LastNameLength
FROM HR.Employees;
```

**Explanation:**
*   `LEN(FirstName)` returns the number of characters in the `FirstName` column for each employee. Note that `LEN` typically ignores trailing spaces but counts leading/internal spaces.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
FirstName   NameLength   LastName    LastNameLength
----------- ------------ ----------- --------------
John        4            Doe         3
Jane        4            Smith       5
Bob         3            Johnson     7
Alice       5            Brown       5
</code></pre>
</details>

### 2. SUBSTRING()

**Goal:** Extract the domain name from employee email addresses.

```sql
SELECT
    Email,
    SUBSTRING(Email, CHARINDEX('@', Email) + 1, LEN(Email)) AS EmailDomain
FROM HR.Employees;
```

**Explanation:**
*   `CHARINDEX('@', Email)` finds the position of the '@' symbol.
*   `SUBSTRING(Email, start_position, length)` extracts characters from the `Email` string.
*   `start_position` is set to the character *after* the '@' (`CHARINDEX(...) + 1`).
*   `length` is set to `LEN(Email)` which is usually more than enough characters to get the rest of the string from the start position. A more precise length could be `LEN(Email) - CHARINDEX('@', Email)`.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
Email                   EmailDomain
----------------------- -------------
john.doe@email.com      email.com
jane.smith@email.com    email.com
bob.johnson@email.com   email.com
alice.brown@email.com   email.com
</code></pre>
</details>

### 3. UPPER() and 4. LOWER()

**Goal:** Display first names in uppercase and emails in lowercase.

```sql
SELECT
    FirstName,
    UPPER(FirstName) AS UpperName,
    LOWER(Email) AS LowerEmail
FROM HR.Employees;
```

**Explanation:**
*   `UPPER(FirstName)` converts the `FirstName` to all capital letters.
*   `LOWER(Email)` converts the `Email` to all lowercase letters.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
FirstName   UpperName   LowerEmail
----------- ----------- -----------------------
John        JOHN        john.doe@email.com
Jane        JANE        jane.smith@email.com
Bob         BOB         bob.johnson@email.com
Alice       ALICE       alice.brown@email.com
</code></pre>
</details>

### 5. TRIM(), 6. LTRIM(), 7. RTRIM()

**Goal:** Clean leading/trailing spaces from phone numbers.

```sql
SELECT
    Phone AS OriginalPhone,
    TRIM(Phone) AS TrimmedPhone, -- Removes leading & trailing spaces
    LTRIM(Phone) AS LeftTrimmed,  -- Removes leading spaces
    RTRIM(Phone) AS RightTrimmed  -- Removes trailing spaces
FROM HR.Employees;
```

**Explanation:**
*   These functions remove whitespace. `TRIM` is generally preferred for removing both leading and trailing spaces. `LTRIM` removes only leading, and `RTRIM` removes only trailing spaces.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Note: Based on the sample data where '123-456-7890' has leading/trailing spaces.</p>
<pre><code>
OriginalPhone          TrimmedPhone     LeftTrimmed        RightTrimmed
---------------------- ---------------- ------------------ --------------------
   123-456-7890        123-456-7890     123-456-7890       123-456-7890
987-654-3210           987-654-3210     987-654-3210       987-654-3210
555-0123-4567          555-0123-4567    555-0123-4567      555-0123-4567
(555) 987-6543         (555) 987-6543   (555) 987-6543     (555) 987-6543
</code></pre>
</details>

### 8. REPLACE()

**Goal:** Remove formatting characters ('-', '(', ')') from phone numbers to get only digits.

```sql
SELECT
    Phone,
    REPLACE(REPLACE(REPLACE(TRIM(Phone), '-', ''), '(', ''), ')', '') AS CleanPhone
FROM HR.Employees;
```

**Explanation:**
*   `REPLACE(string, substring_to_find, substring_to_replace_with)` replaces all occurrences.
*   The query nests `REPLACE` calls: first remove '-', then '(', then ')'. `TRIM` is used first to handle potential spaces affecting the replacements.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
Phone                  CleanPhone
---------------------- ------------
   123-456-7890        1234567890
987-654-3210           9876543210
555-0123-4567          55501234567
(555) 987-6543         555 9876543  -- Note: Space remains if not explicitly replaced
</code></pre>
<p><i>Correction: The sample query only removes '-', '(', ')'. To remove the space in the last example, another `REPLACE(..., ' ', '')` would be needed.</i></p>
</details>

### 9. LEFT() and 10. RIGHT()

**Goal:** Extract the first 3 digits (area code) and the last 4 digits from cleaned phone numbers.

```sql
SELECT
    Phone,
    LEFT(REPLACE(REPLACE(REPLACE(TRIM(Phone), '-', ''), '(', ''), ')', ''), 3) AS AreaCode,
    RIGHT(REPLACE(REPLACE(REPLACE(TRIM(Phone), '-', ''), '(', ''), ')', ''), 4) AS LastFourDigits
FROM HR.Employees;
```

**Explanation:**
*   First, the phone number is cleaned using nested `REPLACE` and `TRIM` as before.
*   `LEFT(cleaned_phone, 3)` takes the first 3 characters.
*   `RIGHT(cleaned_phone, 4)` takes the last 4 characters.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
Phone                  AreaCode   LastFourDigits
---------------------- ---------- --------------
   123-456-7890        123        7890
987-654-3210           987        3210
555-0123-4567          555        4567
(555) 987-6543         555        6543 -- Assumes space was also removed
</code></pre>
</details>

### 11. CHARINDEX()

**Goal:** Find the position of the first '.' and '@' characters in email addresses.

```sql
SELECT
    Email,
    CHARINDEX('.', Email) AS DotPosition,
    CHARINDEX('@', Email) AS AtPosition
FROM HR.Employees;
```

**Explanation:**
*   `CHARINDEX(substring_to_find, string_to_search_in)` returns the starting position (1-based index) of the first occurrence of the substring. Returns 0 if not found.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
Email                   DotPosition  AtPosition
----------------------- -----------  ----------
john.doe@email.com      5            9
jane.smith@email.com    5            11
bob.johnson@email.com   4            12
alice.brown@email.com   6            12
</code></pre>
</details>

### 12. PATINDEX()

**Goal:** Find the starting position of a simple email pattern (`%@%.%`) within the email addresses.

```sql
SELECT
    Email,
    PATINDEX('%@%.%', Email) AS EmailPatternPosition
FROM HR.Employees;
```

**Explanation:**
*   `PATINDEX('%pattern%', string_to_search_in)` finds the starting position of the first occurrence of the specified pattern.
*   The pattern uses SQL wildcard characters: `%` (any string of zero or more characters).
*   `%@%.%` looks for any characters, followed by '@', followed by any characters, followed by '.', followed by any characters. It finds the position where the '@' is located if the pattern matches.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
Email                   EmailPatternPosition
----------------------- --------------------
john.doe@email.com      9
jane.smith@email.com    11
bob.johnson@email.com   12
alice.brown@email.com   12
</code></pre>
</details>

### 13. CONCAT()

**Goal:** Combine first and last names into a full name.

```sql
SELECT
    FirstName,
    LastName,
    CONCAT(FirstName, ' ', LastName) AS FullName
FROM HR.Employees;
```

**Explanation:**
*   `CONCAT(string1, string2, ..., stringN)` joins the provided strings together. It automatically converts NULL arguments to empty strings.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
FirstName   LastName    FullName
----------- ----------- -------------
John        Doe         John Doe
Jane        Smith       Jane Smith
Bob         Johnson     Bob Johnson
Alice       Brown       Alice Brown
</code></pre>
</details>

### 14. CONCAT_WS()

**Goal:** Combine first name, last name, and address using a comma-space separator.

```sql
SELECT
    Address,
    CONCAT_WS(', ', FirstName, LastName, Address) AS FullAddressInfo
FROM HR.Employees;
```

**Explanation:**
*   `CONCAT_WS(separator, string1, string2, ..., stringN)` joins strings using the first argument as the separator between them. It conveniently skips any NULL arguments (unlike `CONCAT` which would include the separator next to an empty string).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
Address                 FullAddressInfo
----------------------- ------------------------------------
123 Main St, City       John, Doe, 123 Main St, City
456 Oak Ave, Town       Jane, Smith, 456 Oak Ave, Town
789 Pine Rd, Village    Bob, Johnson, 789 Pine Rd, Village
321 Elm St, County      Alice, Brown, 321 Elm St, County
</code></pre>
</details>

### 15. FORMAT()

**Goal:** Format cleaned phone numbers into a standard `###-###-####` pattern.

```sql
SELECT
    Phone,
    FORMAT(CAST(REPLACE(REPLACE(REPLACE(TRIM(Phone), '-', ''), '(', ''), ')', '') AS BIGINT), '###-###-####') AS FormattedPhone
FROM HR.Employees;
```

**Explanation:**
*   `FORMAT(value, format_pattern, [culture])` converts a value (numeric, date/time) into a formatted string.
*   The phone number is first cleaned into a numeric string and then `CAST` to `BIGINT`.
*   The pattern `###-###-####` specifies the desired output format.
*   `FORMAT` can be less performant than other string functions for simple tasks but is powerful for complex formatting and localization.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
Phone                  FormattedPhone
---------------------- --------------
   123-456-7890        123-456-7890
987-654-3210           987-654-3210
555-0123-4567          555-012-34567 -- Note: Pattern might not fit all numbers perfectly
(555) 987-6543         555-987-6543 -- Assumes space removed
</code></pre>
</details>

### 16. REPLICATE()

**Goal:** Create padded employee reference numbers (e.g., EMP00001).

```sql
SELECT
    FirstName,
    CONCAT('EMP', REPLICATE('0', 5-LEN(EmployeeID)), EmployeeID) AS EmployeeReference
FROM HR.Employees;
```

**Explanation:**
*   `REPLICATE(string_to_repeat, number_of_times)` repeats the first string.
*   `5-LEN(EmployeeID)` calculates how many zeros are needed for padding (assuming a max length of 5 digits for the ID part).
*   `CONCAT` joins 'EMP', the replicated zeros, and the `EmployeeID`.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Assuming EmployeeIDs are 1, 2, 3, 4</p>
<pre><code>
FirstName   EmployeeReference
----------- -----------------
John        EMP00001
Jane        EMP00002
Bob         EMP00003
Alice       EMP00004
</code></pre>
</details>

### 17. STRING_SPLIT()

**Goal:** Split the `Address` column into separate parts based on the comma delimiter.

```sql
SELECT
    e.EmployeeID, -- Added for context
    s.value AS AddressPart
FROM HR.Employees e
CROSS APPLY STRING_SPLIT(e.Address, ',');
```

**Explanation:**
*   `STRING_SPLIT(string, separator)` returns a single-column table named `value` containing the substrings.
*   `CROSS APPLY` is used to apply the `STRING_SPLIT` function to each row of the `HR.Employees` table.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
EmployeeID  AddressPart
----------- ----------------
1           123 Main St
1            City
2           456 Oak Ave
2            Town
3           789 Pine Rd
3            Village
4           321 Elm St
4            County
</code></pre>
</details>

### 18. QUOTENAME()

**Goal:** Add standard SQL delimiters (`[]`) around first names, useful for dynamically generating SQL.

```sql
SELECT
    FirstName,
    QUOTENAME(FirstName) AS EscapedName
FROM HR.Employees;
```

**Explanation:**
*   `QUOTENAME(string, [quote_character])` adds delimiters. Default is `[]`. Useful for handling names that might contain spaces or reserved keywords if used as identifiers in dynamic SQL.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
FirstName   EscapedName
----------- -----------
John        [John]
Jane        [Jane]
Bob         [Bob]
Alice       [Alice]
</code></pre>
</details>

### 19. UNICODE() and 20. NCHAR()

**Goal:** Show the Unicode integer value of the first character of the first name and convert it back to a character.

```sql
SELECT
    FirstName,
    UNICODE(FirstName) AS FirstCharCode,
    NCHAR(UNICODE(FirstName)) AS FirstCharacter
FROM HR.Employees;
```

**Explanation:**
*   `UNICODE(nchar_expression)` returns the code point of the first character.
*   `NCHAR(integer_expression)` returns the Unicode character corresponding to the integer code point. Useful for working with international character sets.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
FirstName   FirstCharCode   FirstCharacter
----------- --------------- --------------
John        74              J
Jane        74              J
Bob         66              B
Alice       65              A
</code></pre>
</details>

### 21. CHAR()

**Goal:** Generate a single character code based on the EmployeeID (simple example).

```sql
SELECT
    EmployeeID,
    CHAR(65 + (EmployeeID % 26)) AS DepartmentCode -- A=65
FROM HR.Employees;
```

**Explanation:**
*   `CHAR(integer_expression)` returns the ASCII character corresponding to the integer code.
*   This example generates 'A', 'B', 'C', etc., based on the `EmployeeID`.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
EmployeeID  DepartmentCode
----------- --------------
1           B  -- (65 + 1 % 26 = 66)
2           C  -- (65 + 2 % 26 = 67)
3           D  -- (65 + 3 % 26 = 68)
4           E  -- (65 + 4 % 26 = 69)
</code></pre>
</details>

### 22. DIFFERENCE() and 23. SOUNDEX()

**Goal:** Compare how similar the first name "John" sounds to "Jon" using `SOUNDEX` codes.

```sql
SELECT
    FirstName,
    LastName,
    SOUNDEX(FirstName) AS FirstNameSoundex,
    DIFFERENCE(FirstName, 'Jon') AS NameSimilarity
FROM HR.Employees
WHERE FirstName = 'John'; -- Filter for example clarity
```

**Explanation:**
*   `SOUNDEX(string)` generates a 4-character code representing the phonetic sound of the string (primarily for English).
*   `DIFFERENCE(string1, string2)` compares the `SOUNDEX` codes of the two strings and returns 0 (no similarity) to 4 (very similar or identical `SOUNDEX`).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
FirstName   LastName    FirstNameSoundex   NameSimilarity
----------- ----------- ------------------ --------------
John        Doe         J500               4
</code></pre>
<p><i>Note: SOUNDEX('John') is J500, SOUNDEX('Jon') is J500. They sound identical, hence DIFFERENCE returns 4.</i></p>
</details>

### 24. TRANSLATE()

**Goal:** Replace digits 0-9 with letters A-J in phone numbers (simple obfuscation example).

```sql
SELECT
    Phone,
    TRANSLATE(Phone, '0123456789', 'ABCDEFGHIJ') AS EncodedPhone
FROM HR.Employees;
```

**Explanation:**
*   `TRANSLATE(inputString, characters_to_find, characters_to_replace_with)` performs single-character substitution. The second and third arguments define the mapping. If a character from `inputString` exists in `characters_to_find`, it's replaced by the character at the *same position* in `characters_to_replace_with`. Non-numeric characters are unaffected here.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
Phone                  EncodedPhone
---------------------- ----------------
   123-456-7890        ABC-DEF-GHIJ
987-654-3210           IHG-FED-CBAJ
555-0123-4567          FFF-ABCDEFGHI
(555) 987-6543         (FFF) IHG-FEDC
</code></pre>
</details>

### 25. REVERSE()

**Goal:** Show the reversed first name for each employee.

```sql
SELECT
    FirstName,
    REVERSE(FirstName) AS ReversedName
FROM HR.Employees;
```

**Explanation:**
*   `REVERSE(string)` simply reverses the order of characters in the input string.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
FirstName   ReversedName
----------- ------------
John        nhoJ
Jane        enaJ
Bob         boB
Alice       ecilA
</code></pre>
</details>

---

## Interview Question

**Question:** Given the `HR.Employees` table with `FirstName` and `LastName` columns, write a query to generate an email alias in the format `firstinitial.lastname@company.com`. For example, 'John Doe' should become 'j.doe@company.com'. Ensure the entire alias is lowercase.

### Solution Script

```sql
SELECT
    FirstName,
    LastName,
    LOWER(CONCAT(LEFT(FirstName, 1), '.', LastName, '@company.com')) AS EmailAlias
FROM HR.Employees;
```

### Explanation

1.  **`LEFT(FirstName, 1)`**: Extracts the first character (initial) from the `FirstName`.
2.  **`CONCAT(..., '.', ..., '@company.com')`**: Concatenates (joins) the first initial, a literal dot (`.`), the `LastName`, and the literal domain string (`@company.com`).
3.  **`LOWER(...)`**: Converts the entire concatenated string to lowercase to meet the requirement.
4.  **`SELECT ... FROM HR.Employees`**: Selects the original names and the generated alias from the table.

---

## Tricky Interview Questions (Easy to Hard)

1.  **Easy:** What is the difference in how `CONCAT()` and `CONCAT_WS()` handle NULL input values?
    *   *(Answer Hint: `CONCAT` treats NULL as empty string, `CONCAT_WS` skips NULLs)*
2.  **Easy:** If `LEN('abc ')` returns 3, what function would you use to get a length of 4?
    *   *(Answer Hint: `DATALENGTH` which counts bytes, including trailing spaces)*
3.  **Medium:** How can you extract the filename from a full path like 'C:\Folder\Subfolder\MyFile.txt'?
    *   *(Answer Hint: Combine `REVERSE`, `CHARINDEX` (for '\'), and `LEFT` or `SUBSTRING`)*
4.  **Medium:** Explain the difference between `CHARINDEX` and `PATINDEX`. When would you specifically need `PATINDEX`?
    *   *(Answer Hint: `PATINDEX` uses wildcard patterns, `CHARINDEX` uses literal strings)*
5.  **Medium:** Why might `FORMAT()` be less performant than functions like `CONVERT` or specific string functions for simple formatting tasks?
    *   *(Answer Hint: `FORMAT` relies on the .NET CLR, potentially adding overhead)*
6.  **Medium/Hard:** How does `STRING_SPLIT` handle empty elements resulting from consecutive delimiters (e.g., 'a,,b')?
    *   *(Answer Hint: SQL Server's `STRING_SPLIT` typically does *not* return empty strings for consecutive delimiters)*
7.  **Hard:** Describe how you could use `TRANSLATE` to sanitize input by removing a specific set of unwanted characters (e.g., punctuation).
    *   *(Answer Hint: `TRANSLATE` replaces characters, it doesn't remove them directly. You might replace unwanted chars with a single character like space, then use `REPLACE` or `TRIM`.)*
8.  **Hard:** What are the potential limitations or pitfalls of using `SOUNDEX` and `DIFFERENCE` for matching names across different languages or cultures?
    *   *(Answer Hint: Primarily designed for English phonetics, may not work well for other languages)*
9.  **Hard:** How can you use string functions to validate if a string represents a valid date in 'YYYY-MM-DD' format without using `TRY_CONVERT` or `ISDATE`?
    *   *(Answer Hint: Check length, use `PATINDEX` for digit/hyphen patterns, `SUBSTRING` to extract parts and check ranges - complex and less robust than built-ins)*
10. **Hard:** If you need to replace the *second* occurrence of a substring within a string, how could you achieve this using standard string functions (without custom functions or loops)?
    *   *(Answer Hint: Use nested `CHARINDEX` to find the first and second positions, then use `STUFF` or `LEFT`/`RIGHT`/`SUBSTRING` with `CONCAT` to reconstruct the string)*