/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\110_CONVERSION_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Conversion Functions with real-life examples
    using the HRSystem database schemas and tables.

    Conversion Functions covered:
    1. CAST() - Converts a value to a specified data type
    2. CONVERT() - Converts a value to a specified data type with style options
    3. TRY_CAST() - Safely converts a value, returns NULL on failure
    4. TRY_CONVERT() - Safely converts a value with style options, returns NULL on failure
    5. PARSE() - Converts string to date/time/number using specified culture
    6. TRY_PARSE() - Safely parses string, returns NULL on failure
*/

USE HRSystem;
GO

-- Create sample tables if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[DataConversions]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.DataConversions (
        ConversionID INT PRIMARY KEY IDENTITY(1,1),
        StringNumber VARCHAR(20),
        StringDate VARCHAR(30),
        StringTime VARCHAR(20),
        StringDecimal VARCHAR(20),
        StringBoolean VARCHAR(10),
        RawValue VARBINARY(50),
        LocaleDate VARCHAR(30),
        NumberFormat VARCHAR(30)
    );

    -- Insert sample data
    INSERT INTO HR.DataConversions 
    (StringNumber, StringDate, StringTime, StringDecimal, StringBoolean, RawValue, LocaleDate, NumberFormat) VALUES
    ('12345', '2023-08-20', '14:30:00', '1234.56', 'true', 0x48656C6C6F, '20/08/2023', '1,234.56'),
    ('ABC123', '20230820', '2:30 PM', '1,234.56', 'yes', 0x576F726C64, '08/20/2023', '1.234,56'),
    ('9999.99', 'Aug 20, 2023', '14:30', '1234,56', '1', 0x53514C, '20.08.2023', '1234,56'),
    ('-123.45', '20-AUG-2023', '02:30:00 PM', '$1,234.56', 'false', 0x44617461, '20-8-2023', '$1,234.56');

    -- Create table for employee payroll data
    CREATE TABLE HR.PayrollData (
        PayrollID INT PRIMARY KEY IDENTITY(1,1),
        EmployeeID INT,
        SalaryString VARCHAR(20),
        BonusString VARCHAR(20),
        JoinDateString VARCHAR(30),
        LastPayDateString VARCHAR(30),
        WorkHoursString VARCHAR(20),
        TaxRateString VARCHAR(10)
    );

    -- Insert sample payroll data
    INSERT INTO HR.PayrollData 
    (EmployeeID, SalaryString, BonusString, JoinDateString, LastPayDateString, WorkHoursString, TaxRateString) VALUES
    (1, '$75,000.00', '5000', '2023-01-15', '2023-08-01', '160.5', '22.5%'),
    (2, '85000', '$7,500.00', '15/01/2023', '01/08/2023', '175.0', '24%'),
    (3, '$65,000', '4500.50', '2023.01.15', '2023.08.01', '155', '21.5%'),
    (4, '95000.00', '$8,000', 'Jan 15, 2023', 'Aug 1, 2023', '180.75', '25.0%');
END

-- 1. CAST() - Basic type conversions
SELECT 
    ConversionID,
    StringNumber,
    -- Convert string to integer
    TRY_CAST(StringNumber AS INT) AS NumberAsInteger,
    -- Convert string to decimal
    CAST(StringDecimal AS DECIMAL(10,2)) AS NumberAsDecimal,
    -- Convert string to datetime
    CAST(StringDate AS DATETIME) AS DateAsDateTime,
    -- Convert string to time
    CAST(StringTime AS TIME) AS TimeAsTime,
    -- Convert string to bit
    CAST(CASE 
        WHEN StringBoolean IN ('true', 'yes', '1') THEN 1
        ELSE 0
    END AS BIT) AS BooleanAsBit
FROM HR.DataConversions
WHERE TRY_CAST(StringNumber AS INT) IS NOT NULL;
/* Output example:
ConversionID  StringNumber  NumberAsInteger  NumberAsDecimal  DateAsDateTime        TimeAsTime   BooleanAsBit
1             12345         12345            1234.56          2023-08-20 00:00:00   14:30:00     1
*/

-- 2. CONVERT() - Conversions with style options
SELECT 
    ConversionID,
    StringDate,
    -- Convert date with different styles
    CONVERT(VARCHAR(20), CAST(StringDate AS DATETIME), 101) AS USDateFormat,      -- mm/dd/yyyy
    CONVERT(VARCHAR(20), CAST(StringDate AS DATETIME), 103) AS BritishDateFormat, -- dd/mm/yyyy
    CONVERT(VARCHAR(20), CAST(StringDate AS DATETIME), 104) AS GermanDateFormat,  -- dd.mm.yyyy
    CONVERT(VARCHAR(20), CAST(StringDate AS DATETIME), 120) AS ISO8601Format,     -- yyyy-mm-dd hh:mi:ss
    -- Convert number with different styles
    CONVERT(VARCHAR(20), CAST(StringDecimal AS MONEY), 1) AS MoneyFormat
FROM HR.DataConversions
WHERE TRY_CAST(StringDate AS DATETIME) IS NOT NULL;
/* Output example:
ConversionID  StringDate   USDateFormat  BritishDateFormat  GermanDateFormat  ISO8601Format        MoneyFormat
1             2023-08-20   08/20/2023    20/08/2023         20.08.2023        2023-08-20 00:00:00  1,234.56
*/

-- 3. TRY_CAST() - Safe conversion with error handling
SELECT 
    ConversionID,
    StringNumber,
    StringDecimal,
    -- Safe conversion of potentially invalid numbers
    TRY_CAST(StringNumber AS INT) AS SafeInteger,
    TRY_CAST(StringDecimal AS DECIMAL(10,2)) AS SafeDecimal,
    -- Check for conversion success
    CASE 
        WHEN TRY_CAST(StringNumber AS INT) IS NULL THEN 'Invalid Integer'
        ELSE 'Valid Integer'
    END AS ConversionStatus
FROM HR.DataConversions;
/* Output example:
ConversionID  StringNumber  StringDecimal  SafeInteger  SafeDecimal  ConversionStatus
1             12345         1234.56        12345        1234.56      Valid Integer
2             ABC123        1,234.56       NULL         1234.56      Invalid Integer
*/

-- 4. TRY_CONVERT() - Safe conversion with style options
SELECT 
    ConversionID,
    LocaleDate,
    -- Try different date formats
    TRY_CONVERT(DATE, LocaleDate, 103) AS BritishDate,     -- dd/mm/yyyy
    TRY_CONVERT(DATE, LocaleDate, 104) AS GermanDate,      -- dd.mm.yyyy
    TRY_CONVERT(DATE, LocaleDate, 110) AS USADate,         -- mm-dd-yyyy
    -- Check conversion success
    CASE 
        WHEN TRY_CONVERT(DATE, LocaleDate, 103) IS NOT NULL THEN 'British format'
        WHEN TRY_CONVERT(DATE, LocaleDate, 104) IS NOT NULL THEN 'German format'
        WHEN TRY_CONVERT(DATE, LocaleDate, 110) IS NOT NULL THEN 'USA format'
        ELSE 'Unknown format'
    END AS DateFormat
FROM HR.DataConversions;
/* Output example:
ConversionID  LocaleDate   BritishDate  GermanDate   USADate      DateFormat
1             20/08/2023   2023-08-20   NULL         NULL         British format
2             08/20/2023   NULL         NULL         2023-08-20   USA format
*/

-- 5. PARSE() - Culture-aware parsing
SELECT 
    ConversionID,
    NumberFormat,
    -- Parse numbers in different cultures
    PARSE(NumberFormat AS DECIMAL(10,2) USING 'en-US') AS USNumber,    -- Uses period as decimal
    PARSE(NumberFormat AS DECIMAL(10,2) USING 'de-DE') AS GermanNumber, -- Uses comma as decimal
    -- Parse dates in different cultures
    PARSE(LocaleDate AS DATE USING 'en-US') AS USDate,
    PARSE(LocaleDate AS DATE USING 'de-DE') AS GermanDate
FROM HR.DataConversions
WHERE TRY_PARSE(NumberFormat AS DECIMAL(10,2) USING 'en-US') IS NOT NULL
   OR TRY_PARSE(NumberFormat AS DECIMAL(10,2) USING 'de-DE') IS NOT NULL;
/* Output example:
ConversionID  NumberFormat  USNumber  GermanNumber  USDate       GermanDate
1             1,234.56      1234.56   1234.56      2023-08-20   2023-08-20
*/

-- 6. TRY_PARSE() - Safe culture-aware parsing
SELECT 
    PayrollID,
    SalaryString,
    BonusString,
    -- Safe parsing of currency values
    TRY_PARSE(REPLACE(REPLACE(SalaryString, '$', ''), ',', '') AS DECIMAL(10,2)) AS ParsedSalary,
    TRY_PARSE(REPLACE(REPLACE(BonusString, '$', ''), ',', '') AS DECIMAL(10,2)) AS ParsedBonus,
    -- Safe parsing of dates
    TRY_PARSE(JoinDateString AS DATE USING 'en-US') AS ParsedJoinDate,
    -- Safe parsing of percentages
    TRY_PARSE(REPLACE(TaxRateString, '%', '') AS DECIMAL(5,2)) AS ParsedTaxRate
FROM HR.PayrollData;
/* Output example:
PayrollID  SalaryString  BonusString  ParsedSalary  ParsedBonus  ParsedJoinDate  ParsedTaxRate
1          $75,000.00    5000         75000.00      5000.00      2023-01-15      22.50
*/

-- Complex example combining multiple conversion functions
SELECT 
    p.PayrollID,
    p.EmployeeID,
    -- Salary calculations with safe conversions
    TRY_CAST(REPLACE(REPLACE(p.SalaryString, '$', ''), ',', '') AS DECIMAL(10,2)) AS BaseSalary,
    TRY_CONVERT(DECIMAL(10,2), REPLACE(REPLACE(p.BonusString, '$', ''), ',', '')) AS Bonus,
    -- Date conversions
    CONVERT(VARCHAR(10), TRY_PARSE(p.JoinDateString AS DATE USING 'en-US'), 120) AS StandardJoinDate,
    -- Time tracking
    TRY_CAST(p.WorkHoursString AS DECIMAL(5,2)) AS WorkHours,
    -- Tax calculations
    TRY_PARSE(REPLACE(p.TaxRateString, '%', '') AS DECIMAL(5,2)) / 100.0 AS TaxRateDecimal,
    -- Calculate total compensation
    TRY_CAST(REPLACE(REPLACE(p.SalaryString, '$', ''), ',', '') AS DECIMAL(10,2)) +
    TRY_CAST(REPLACE(REPLACE(p.BonusString, '$', ''), ',', '') AS DECIMAL(10,2)) AS TotalCompensation,
    -- Format as currency
    CONVERT(VARCHAR(20), 
        TRY_CAST(REPLACE(REPLACE(p.SalaryString, '$', ''), ',', '') AS DECIMAL(10,2)) +
        TRY_CAST(REPLACE(REPLACE(p.BonusString, '$', ''), ',', '') AS DECIMAL(10,2)),
        1) AS FormattedTotalCompensation
FROM HR.PayrollData p
WHERE 
    -- Only include records with valid conversions
    TRY_CAST(REPLACE(REPLACE(p.SalaryString, '$', ''), ',', '') AS DECIMAL(10,2)) IS NOT NULL
    AND TRY_CAST(REPLACE(REPLACE(p.BonusString, '$', ''), ',', '') AS DECIMAL(10,2)) IS NOT NULL;
/* Output example:
PayrollID  EmployeeID  BaseSalary  Bonus    StandardJoinDate  WorkHours  TaxRateDecimal  TotalCompensation  FormattedTotalCompensation
1          1           75000.00    5000.00  2023-01-15        160.50     0.225           80000.00           80,000.00
*/