/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\108_DATE_TIME_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Date and Time Functions with real-life examples
    using the HRSystem database schemas and tables.

    Date and Time Functions covered:
    1. GETDATE() - Returns current date and time
    2. GETUTCDATE() - Returns current UTC date and time
    3. SYSDATETIME() - Returns date and time with higher precision
    4. SYSUTCDATETIME() - Returns UTC date and time with higher precision
    5. SYSDATETIMEOFFSET() - Returns date, time, and timezone offset
    6. CURRENT_TIMESTAMP - Returns current date and time (ANSI SQL standard)
    7. DATEADD() - Adds interval to date
    8. DATEDIFF() - Difference between dates
    9. DATEDIFF_BIG() - Difference between dates (bigint)
    10. DATEPART() - Gets specific part of date
    11. DATENAME() - Gets name of date part
    12. YEAR() - Gets year from date
    13. MONTH() - Gets month from date
    14. DAY() - Gets day from date
    15. EOMONTH() - Gets end of month
    16. SWITCHOFFSET() - Changes timezone offset
    17. TODATETIMEOFFSET() - Converts to datetimeoffset
    18. ISDATE() - Validates date
    19. DATETIME2FROMPARTS() - Creates datetime2 from parts
    20. DATETIMEOFFSETFROMPARTS() - Creates datetimeoffset from parts
    21. DATEFROMPARTS() - Creates date from parts
    22. TIMEFROMPARTS() - Creates time from parts
    23. SMALLDATETIMEFROMPARTS() - Creates smalldatetime from parts
*/

USE HRSystem;
GO

-- Create sample tables if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[TimeRecords]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.TimeRecords (
        RecordID INT PRIMARY KEY IDENTITY(1,1),
        EmployeeID INT,
        CheckInTime DATETIME2,
        CheckOutTime DATETIME2,
        ShiftDate DATE,
        TimeZone VARCHAR(50)
    );

    -- Insert sample data
    INSERT INTO HR.TimeRecords (EmployeeID, CheckInTime, CheckOutTime, ShiftDate, TimeZone) VALUES
    (1, '2023-08-01 09:00:00', '2023-08-01 17:00:00', '2023-08-01', 'Eastern'),
    (2, '2023-08-01 08:30:00', '2023-08-01 16:30:00', '2023-08-01', 'Pacific'),
    (3, '2023-08-01 10:00:00', '2023-08-01 18:00:00', '2023-08-01', 'Central');

    -- Create table for leave management
    CREATE TABLE HR.LeaveRequests (
        RequestID INT PRIMARY KEY IDENTITY(1,1),
        EmployeeID INT,
        StartDate DATE,
        EndDate DATE,
        RequestDate DATETIME2,
        ApprovalDate DATETIME2,
        LeaveType VARCHAR(50)
    );

    -- Insert sample leave requests
    INSERT INTO HR.LeaveRequests (EmployeeID, StartDate, EndDate, RequestDate, ApprovalDate, LeaveType) VALUES
    (1, '2023-08-15', '2023-08-20', '2023-08-01 10:30:00', '2023-08-02 14:15:00', 'Vacation'),
    (2, '2023-09-01', '2023-09-05', '2023-08-15 09:45:00', '2023-08-16 11:20:00', 'Personal'),
    (3, '2023-08-10', '2023-08-12', '2023-08-05 16:20:00', '2023-08-06 10:00:00', 'Sick');
END

-- 1. GETDATE() - Current system date and time
SELECT 
    GETDATE() AS CurrentDateTime,
    'System timestamp' AS Description;
/* Output example:
CurrentDateTime           Description
2023-08-20 14:30:45.123  System timestamp
*/

-- 2. GETUTCDATE() - Current UTC date and time
SELECT 
    GETDATE() AS LocalDateTime,
    GETUTCDATE() AS UTCDateTime,
    DATEDIFF(HOUR, GETUTCDATE(), GETDATE()) AS TimeZoneOffset;
/* Output example:
LocalDateTime            UTCDateTime             TimeZoneOffset
2023-08-20 14:30:45.123  2023-08-20 18:30:45.123 -4
*/

-- 3. SYSDATETIME() - High-precision system date and time
SELECT 
    GETDATE() AS StandardPrecision,
    SYSDATETIME() AS HighPrecision;
/* Output example:
StandardPrecision        HighPrecision
2023-08-20 14:30:45.123  2023-08-20 14:30:45.1234567
*/

-- 4. SYSUTCDATETIME() and 5. SYSDATETIMEOFFSET() - Timezone aware functions
SELECT 
    SYSDATETIMEOFFSET() AS CurrentWithOffset,
    SYSUTCDATETIME() AS UTCHighPrecision;
/* Output example:
CurrentWithOffset                    UTCHighPrecision
2023-08-20 14:30:45.1234567 -04:00  2023-08-20 18:30:45.1234567
*/

-- 6. CURRENT_TIMESTAMP - ANSI SQL standard current timestamp
SELECT 
    CURRENT_TIMESTAMP AS CurrentTime,
    'ANSI SQL Standard' AS Standard;
/* Output example:
CurrentTime              Standard
2023-08-20 14:30:45.123  ANSI SQL Standard
*/

-- 7. DATEADD() - Calculate future and past dates
SELECT 
    StartDate,
    DATEADD(DAY, 30, StartDate) AS Plus30Days,
    DATEADD(MONTH, 1, StartDate) AS Plus1Month,
    DATEADD(YEAR, -1, StartDate) AS Minus1Year
FROM HR.LeaveRequests;
/* Output example:
StartDate   Plus30Days  Plus1Month  Minus1Year
2023-08-15  2023-09-14  2023-09-15  2022-08-15
*/

-- 8. DATEDIFF() - Calculate duration between dates
SELECT 
    RequestID,
    StartDate,
    EndDate,
    DATEDIFF(DAY, StartDate, EndDate) AS LeaveDuration,
    DATEDIFF(HOUR, RequestDate, ApprovalDate) AS ApprovalHours
FROM HR.LeaveRequests;
/* Output example:
RequestID  StartDate   EndDate     LeaveDuration  ApprovalHours
1          2023-08-15  2023-08-20  5              28
*/

-- 9. DATEDIFF_BIG() - Large date differences
SELECT 
    DATEDIFF_BIG(SECOND, '2000-01-01', '2023-08-20') AS SecondsSince2000;
/* Output example:
SecondsSince2000
744844800
*/

-- 10. DATEPART() - Extract specific parts of dates
SELECT 
    CheckInTime,
    DATEPART(YEAR, CheckInTime) AS Year,
    DATEPART(MONTH, CheckInTime) AS Month,
    DATEPART(DAY, CheckInTime) AS Day,
    DATEPART(HOUR, CheckInTime) AS Hour,
    DATEPART(MINUTE, CheckInTime) AS Minute
FROM HR.TimeRecords;
/* Output example:
CheckInTime              Year  Month  Day  Hour  Minute
2023-08-01 09:00:00     2023  8      1    9     0
*/

-- 11. DATENAME() - Get name of date parts
SELECT 
    CheckInTime,
    DATENAME(MONTH, CheckInTime) AS MonthName,
    DATENAME(WEEKDAY, CheckInTime) AS WeekdayName
FROM HR.TimeRecords;
/* Output example:
CheckInTime              MonthName  WeekdayName
2023-08-01 09:00:00     August     Tuesday
*/

-- 12. YEAR(), 13. MONTH(), 14. DAY() - Simple date part extraction
SELECT 
    RequestDate,
    YEAR(RequestDate) AS YearOnly,
    MONTH(RequestDate) AS MonthOnly,
    DAY(RequestDate) AS DayOnly
FROM HR.LeaveRequests;
/* Output example:
RequestDate              YearOnly  MonthOnly  DayOnly
2023-08-01 10:30:00     2023      8          1
*/

-- 15. EOMONTH() - Find last day of month
SELECT 
    StartDate,
    EOMONTH(StartDate) AS EndOfMonth,
    EOMONTH(StartDate, 1) AS EndOfNextMonth
FROM HR.LeaveRequests;
/* Output example:
StartDate   EndOfMonth  EndOfNextMonth
2023-08-15  2023-08-31  2023-09-30
*/

-- 16. SWITCHOFFSET() and 17. TODATETIMEOFFSET() - Timezone conversions
DECLARE @LocalTime DATETIME2 = '2023-08-20 14:30:00';
SELECT
    TODATETIMEOFFSET(@LocalTime, '-04:00') AS EasternTime,
    SWITCHOFFSET(TODATETIMEOFFSET(@LocalTime, '-04:00'), '+00:00') AS UTCTime;
/* Output example:
EasternTime                         UTCTime
2023-08-20 14:30:00.0000000 -04:00 2023-08-20 18:30:00.0000000 +00:00
*/

-- 18. ISDATE() - Validate date strings
SELECT 
    '2023-08-20' AS DateString1, ISDATE('2023-08-20') AS IsValid1,
    '2023-13-45' AS DateString2, ISDATE('2023-13-45') AS IsValid2;
/* Output example:
DateString1  IsValid1  DateString2  IsValid2
2023-08-20   1         2023-13-45   0
*/

-- 19. DATETIME2FROMPARTS() - Create precise datetime
SELECT DATETIME2FROMPARTS(
    2023, -- year
    8,    -- month
    20,   -- day
    14,   -- hour
    30,   -- minute
    45,   -- second
    123,  -- fraction
    3     -- precision
) AS ConstructedDateTime;
/* Output example:
ConstructedDateTime
2023-08-20 14:30:45.123
*/

-- 20. DATETIMEOFFSETFROMPARTS() - Create timezone-aware datetime
SELECT DATETIMEOFFSETFROMPARTS(
    2023, -- year
    8,    -- month
    20,   -- day
    14,   -- hour
    30,   -- minute
    45,   -- second
    123,  -- fraction
    -4,   -- hour offset
    0,    -- minute offset
    3     -- precision
) AS ConstructedDateTimeOffset;
/* Output example:
ConstructedDateTimeOffset
2023-08-20 14:30:45.123 -04:00
*/

-- 21. DATEFROMPARTS() - Create date only
SELECT DATEFROMPARTS(2023, 8, 20) AS ConstructedDate;
/* Output example:
ConstructedDate
2023-08-20
*/

-- 22. TIMEFROMPARTS() - Create time only
SELECT TIMEFROMPARTS(14, 30, 45, 123, 3) AS ConstructedTime;
/* Output example:
ConstructedTime
14:30:45.123
*/

-- 23. SMALLDATETIMEFROMPARTS() - Create smalldatetime
SELECT SMALLDATETIMEFROMPARTS(2023, 8, 20, 14, 30) AS ConstructedSmallDateTime;
/* Output example:
ConstructedSmallDateTime
2023-08-20 14:30:00
*/

-- Complex example combining multiple date functions
SELECT 
    tr.EmployeeID,
    tr.CheckInTime,
    tr.CheckOutTime,
    DATEDIFF(MINUTE, tr.CheckInTime, tr.CheckOutTime) AS MinutesWorked,
    DATENAME(WEEKDAY, tr.ShiftDate) AS WorkDay,
    CASE 
        WHEN DATEPART(HOUR, tr.CheckInTime) < 9 THEN 'Early Bird'
        WHEN DATEPART(HOUR, tr.CheckInTime) = 9 THEN 'On Time'
        ELSE 'Late'
    END AS ArrivalStatus,
    EOMONTH(tr.ShiftDate) AS MonthEnd,
    ISDATE(tr.ShiftDate) AS ValidDate,
    FORMAT(tr.CheckInTime, 'yyyy-MM-dd hh:mm tt') AS FormattedCheckIn
FROM HR.TimeRecords tr
WHERE tr.ShiftDate >= DATEFROMPARTS(2023, 8, 1)
ORDER BY tr.CheckInTime;
/* Output example:
EmployeeID  CheckInTime   CheckOutTime  MinutesWorked  WorkDay   ArrivalStatus  MonthEnd    ValidDate  FormattedCheckIn
2          2023-08-01    2023-08-01    480           Tuesday   Early Bird     2023-08-31  1          2023-08-01 08:30 AM
1          2023-08-01    2023-08-01    480           Tuesday   On Time       2023-08-31  1          2023-08-01 09:00 AM
3          2023-08-01    2023-08-01    480           Tuesday   Late          2023-08-31  1          2023-08-01 10:00 AM
*/