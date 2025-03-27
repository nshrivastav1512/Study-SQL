/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\107_STRING_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server String Functions with real-life examples
    using the HRSystem database schemas and tables.

    String Functions covered:
    1. LEN() - Returns the length of a string
    2. SUBSTRING() - Extracts a substring from a string
    3. UPPER() - Converts a string to uppercase
    4. LOWER() - Converts a string to lowercase
    5. TRIM() - Removes leading and trailing spaces
    6. LTRIM() - Removes leading spaces
    7. RTRIM() - Removes trailing spaces
    8. REPLACE() - Replaces all occurrences of a substring
    9. LEFT() - Gets the leftmost characters
    10. RIGHT() - Gets the rightmost characters
    11. CHARINDEX() - Finds the position of a substring
    12. PATINDEX() - Returns the starting position of a pattern
    13. CONCAT() - Combines strings
    14. CONCAT_WS() - Combines strings with a separator
    15. FORMAT() - Formats a value with specified format
    16. REPLICATE() - Repeats a string value
    17. STRING_SPLIT() - Splits a string into rows
    18. QUOTENAME() - Returns a Unicode string with delimiters
    19. UNICODE() - Returns the Unicode value
    20. NCHAR() - Converts an integer to a Unicode character
    21. CHAR() - Converts an integer to a character
    22. DIFFERENCE() - Compares the SOUNDEX values
    23. SOUNDEX() - Returns a four-character code
    24. TRANSLATE() - Replaces characters
    25. REVERSE() - Reverses a string
*/

USE HRSystem;
GO

-- Create a sample Employee table if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[Employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.Employees (
        EmployeeID INT PRIMARY KEY IDENTITY(1,1),
        FirstName NVARCHAR(50),
        LastName NVARCHAR(50),
        Email NVARCHAR(100),
        Phone NVARCHAR(20),
        Address NVARCHAR(200),
        Notes NVARCHAR(MAX)
    );

    -- Insert sample data
    INSERT INTO HR.Employees (FirstName, LastName, Email, Phone, Address, Notes) VALUES
    ('John', 'Doe', 'john.doe@email.com', '   123-456-7890   ', '123 Main St, City', 'Senior Developer'),
    ('Jane', 'Smith', 'jane.smith@email.com', '987-654-3210', '456 Oak Ave, Town', 'Project Manager'),
    ('Bob', 'Johnson', 'bob.johnson@email.com', '555-0123-4567', '789 Pine Rd, Village', 'Business Analyst'),
    ('Alice', 'Brown', 'alice.brown@email.com', '(555) 987-6543', '321 Elm St, County', 'Data Scientist');
END

-- 1. LEN() - Get the length of names
SELECT 
    FirstName,
    LEN(FirstName) AS NameLength,
    LastName,
    LEN(LastName) AS LastNameLength
FROM HR.Employees;
/* Output example:
FirstName   NameLength   LastName    LastNameLength
John        4           Doe         3
Jane        4           Smith       5
*/

-- 2. SUBSTRING() - Extract part of email domain
SELECT 
    Email,
    SUBSTRING(Email, CHARINDEX('@', Email) + 1, LEN(Email)) AS EmailDomain
FROM HR.Employees;
/* Output example:
Email                   EmailDomain
john.doe@email.com     email.com
jane.smith@email.com   email.com
*/

-- 3. UPPER() and 4. LOWER() - Name formatting
SELECT 
    FirstName,
    UPPER(FirstName) AS UpperName,
    LOWER(Email) AS LowerEmail
FROM HR.Employees;
/* Output example:
FirstName   UpperName   LowerEmail
John        JOHN        john.doe@email.com
Jane        JANE        jane.smith@email.com
*/

-- 5. TRIM(), 6. LTRIM(), 7. RTRIM() - Clean phone numbers
SELECT 
    Phone AS OriginalPhone,
    TRIM(Phone) AS TrimmedPhone,
    LTRIM(Phone) AS LeftTrimmed,
    RTRIM(Phone) AS RightTrimmed
FROM HR.Employees;
/* Output example:
OriginalPhone        TrimmedPhone    LeftTrimmed     RightTrimmed
   123-456-7890      123-456-7890    123-456-7890    123-456-7890   
*/

-- 8. REPLACE() - Format phone numbers
SELECT 
    Phone,
    REPLACE(REPLACE(REPLACE(Phone, '-', ''), '(', ''), ')', '') AS CleanPhone
FROM HR.Employees;
/* Output example:
Phone           CleanPhone
123-456-7890    1234567890
(555) 987-6543  5559876543
*/

-- 9. LEFT() and 10. RIGHT() - Extract phone area codes and last 4 digits
SELECT 
    Phone,
    LEFT(REPLACE(REPLACE(Phone, '(', ''), ')', ''), 3) AS AreaCode,
    RIGHT(REPLACE(Phone, '-', ''), 4) AS LastFourDigits
FROM HR.Employees;
/* Output example:
Phone           AreaCode    LastFourDigits
123-456-7890    123         7890
*/

-- 11. CHARINDEX() - Find position of '.' in email
SELECT 
    Email,
    CHARINDEX('.', Email) AS DotPosition,
    CHARINDEX('@', Email) AS AtPosition
FROM HR.Employees;
/* Output example:
Email                   DotPosition  AtPosition
john.doe@email.com     5            8
*/

-- 12. PATINDEX() - Find email pattern
SELECT 
    Email,
    PATINDEX('%@%.%', Email) AS EmailPatternPosition
FROM HR.Employees;
/* Output example:
Email                   EmailPatternPosition
john.doe@email.com     9
*/

-- 13. CONCAT() - Combine names
SELECT 
    FirstName,
    LastName,
    CONCAT(FirstName, ' ', LastName) AS FullName
FROM HR.Employees;
/* Output example:
FirstName   LastName    FullName
John        Doe         John Doe
*/

-- 14. CONCAT_WS() - Combine address parts
SELECT 
    Address,
    CONCAT_WS(', ', FirstName, LastName, Address) AS FullAddress
FROM HR.Employees;
/* Output example:
Address              FullAddress
123 Main St, City    John, Doe, 123 Main St, City
*/

-- 15. FORMAT() - Format phone numbers
SELECT 
    Phone,
    FORMAT(CAST(REPLACE(REPLACE(REPLACE(Phone, '-', ''), '(', ''), ')', '') AS BIGINT), '###-###-####') AS FormattedPhone
FROM HR.Employees;
/* Output example:
Phone           FormattedPhone
123-456-7890    123-456-7890
*/

-- 16. REPLICATE() - Create reference numbers
SELECT 
    FirstName,
    CONCAT('EMP', REPLICATE('0', 5-LEN(EmployeeID)), EmployeeID) AS EmployeeReference
FROM HR.Employees;
/* Output example:
FirstName   EmployeeReference
John        EMP00001
*/

-- 17. STRING_SPLIT() - Split address into parts
SELECT 
    value AS AddressPart
FROM HR.Employees
CROSS APPLY STRING_SPLIT(Address, ',');
/* Output example:
AddressPart
123 Main St
City
*/

-- 18. QUOTENAME() - Escape names for dynamic SQL
SELECT 
    FirstName,
    QUOTENAME(FirstName) AS EscapedName
FROM HR.Employees;
/* Output example:
FirstName   EscapedName
John        [John]
*/

-- 19. UNICODE() and 20. NCHAR() - Work with Unicode characters
SELECT 
    FirstName,
    UNICODE(FirstName) AS FirstCharCode,
    NCHAR(UNICODE(FirstName)) AS FirstCharacter
FROM HR.Employees;
/* Output example:
FirstName   FirstCharCode   FirstCharacter
John        74              J
*/

-- 21. CHAR() - ASCII character demonstration
SELECT 
    EmployeeID,
    CHAR(65 + (EmployeeID % 26)) AS DepartmentCode
FROM HR.Employees;
/* Output example:
EmployeeID  DepartmentCode
1           A
2           B
*/

-- 22. DIFFERENCE() and 23. SOUNDEX() - Compare similar sounding names
SELECT 
    FirstName,
    LastName,
    SOUNDEX(FirstName) AS FirstNameSoundex,
    DIFFERENCE(FirstName, 'Jon') AS NameSimilarity
FROM HR.Employees;
/* Output example:
FirstName   LastName    FirstNameSoundex   NameSimilarity
John        Doe         J500               4
*/

-- 24. TRANSLATE() - Replace multiple characters
SELECT 
    Phone,
    TRANSLATE(Phone, '0123456789', 'ABCDEFGHIJ') AS EncodedPhone
FROM HR.Employees;
/* Output example:
Phone           EncodedPhone
123-456-7890    ABC-DEF-GHIJ
*/

-- 25. REVERSE() - Reverse string values
SELECT 
    FirstName,
    REVERSE(FirstName) AS ReversedName
FROM HR.Employees;
/* Output example:
FirstName   ReversedName
John        nhoJ
*/

-- Complex example combining multiple string functions
SELECT 
    CONCAT_WS(' ', UPPER(LEFT(FirstName, 1)), LOWER(SUBSTRING(FirstName, 2, LEN(FirstName)))) AS FormattedFirstName,
    CONCAT_WS(' ', UPPER(LEFT(LastName, 1)), LOWER(SUBSTRING(LastName, 2, LEN(LastName)))) AS FormattedLastName,
    CASE 
        WHEN PATINDEX('%[^0-9-()]%', Phone) > 0 THEN 'Invalid Phone'
        ELSE FORMAT(CAST(REPLACE(REPLACE(REPLACE(TRIM(Phone), '-', ''), '(', ''), ')', '') AS BIGINT), '###-###-####')
    END AS FormattedPhone,
    LOWER(SUBSTRING(Email, 1, CHARINDEX('@', Email) - 1)) AS EmailUsername,
    LOWER(SUBSTRING(Email, CHARINDEX('@', Email) + 1, LEN(Email))) AS EmailDomain,
    STRING_AGG(value, ' > ') WITHIN GROUP (ORDER BY value) AS FormattedAddress
FROM HR.Employees
CROSS APPLY STRING_SPLIT(Address, ',')
GROUP BY 
    EmployeeID, FirstName, LastName, Phone, Email;
/* Output example:
FormattedFirstName  FormattedLastName  FormattedPhone  EmailUsername  EmailDomain  FormattedAddress
John                Doe                123-456-7890     john.doe       email.com    123 Main St > City
*/