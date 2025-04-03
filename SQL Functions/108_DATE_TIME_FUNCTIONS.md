# SQL Date and Time Functions

## Introduction

**Definition:** SQL Date and Time functions are specialized functions used to manipulate, query, and format date and time values stored in various data types like `DATE`, `TIME`, `DATETIME`, `DATETIME2`, `SMALLDATETIME`, and `DATETIMEOFFSET`.

**Explanation:** These functions are crucial for applications involving scheduling, logging, tracking events, calculating durations, reporting based on time periods, and handling data across different timezones. They allow developers and analysts to perform complex temporal calculations and comparisons directly within SQL queries.

## Functions Covered in this Section

This document explores numerous SQL Server Date and Time functions, illustrated with examples using hypothetical `HR.TimeRecords` and `HR.LeaveRequests` tables:

1.  `GETDATE()`: Returns the current database server's date and time as a `datetime` value.
2.  `GETUTCDATE()`: Returns the current Coordinated Universal Time (UTC) date and time as a `datetime` value.
3.  `SYSDATETIME()`: Returns the current database server's date and time as a `datetime2(7)` value (higher precision than `GETDATE()`).
4.  `SYSUTCDATETIME()`: Returns the current UTC date and time as a `datetime2(7)` value (higher precision).
5.  `SYSDATETIMEOFFSET()`: Returns the current database server's date and time along with the server's timezone offset as a `datetimeoffset(7)` value.
6.  `CURRENT_TIMESTAMP`: ANSI SQL standard equivalent to `GETDATE()`. Returns a `datetime` value.
7.  `DATEADD(datepart, number, date)`: Adds a specified time interval (`number`) to a specified date part (`datepart`) of an input `date`.
8.  `DATEDIFF(datepart, startdate, enddate)`: Returns the count of specified date part boundaries crossed between the `startdate` and `enddate`. Returns an `int`.
9.  `DATEDIFF_BIG(datepart, startdate, enddate)`: Similar to `DATEDIFF`, but returns a `bigint`, allowing for larger differences.
10. `DATEPART(datepart, date)`: Returns an integer representing the specified `datepart` of the specified `date`.
11. `DATENAME(datepart, date)`: Returns a character string representing the specified `datepart` (e.g., 'August', 'Tuesday') of the specified `date`.
12. `YEAR(date)`: Returns an integer representing the year part of a date. Equivalent to `DATEPART(year, date)`.
13. `MONTH(date)`: Returns an integer representing the month part of a date. Equivalent to `DATEPART(month, date)`.
14. `DAY(date)`: Returns an integer representing the day part of a date. Equivalent to `DATEPART(day, date)`.
15. `EOMONTH(start_date, [months_to_add])`: Returns the last day of the month containing the specified date, with an optional offset in months.
16. `SWITCHOFFSET(datetimeoffset, time_zone)`: Changes the timezone offset of a `datetimeoffset` value while preserving the UTC point in time.
17. `TODATETIMEOFFSET(expression, time_zone)`: Converts a `datetime2` value to a `datetimeoffset` value by adding a specified timezone offset.
18. `ISDATE(expression)`: Returns 1 if the expression is a valid date, time, or datetime value; otherwise, 0. (Note: Has limitations and doesn't validate format strictly).
19. `DATETIME2FROMPARTS(...)`: Constructs a `datetime2` value from individual year, month, day, hour, minute, seconds, and fractions parts.
20. `DATETIMEOFFSETFROMPARTS(...)`: Constructs a `datetimeoffset` value from individual date/time parts plus timezone offset parts.
21. `DATEFROMPARTS(year, month, day)`: Constructs a `date` value from year, month, and day parts.
22. `TIMEFROMPARTS(...)`: Constructs a `time` value from hour, minute, seconds, and fractions parts.
23. `SMALLDATETIMEFROMPARTS(year, month, day, hour, minute)`: Constructs a `smalldatetime` value from date and time parts (seconds are always 00).

*(Note: The SQL script includes logic to create and populate sample `HR.TimeRecords` and `HR.LeaveRequests` tables if they don't exist.)*

---

## Examples

### 1. GETDATE()

**Goal:** Retrieve the current system date and time.

```sql
SELECT
    GETDATE() AS CurrentDateTime,
    'System timestamp' AS Description;
```

**Explanation:**
*   `GETDATE()` returns the date and time from the operating system of the computer on which the instance of SQL Server is running, as a `datetime` data type.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
CurrentDateTime           Description
------------------------- ------------------
2025-04-02 16:15:30.123   System timestamp
</code></pre>
</details>

### 2. GETUTCDATE()

**Goal:** Retrieve the current UTC date and time and compare it with local time.

```sql
SELECT
    GETDATE() AS LocalDateTime,
    GETUTCDATE() AS UTCDateTime,
    DATEDIFF(HOUR, GETUTCDATE(), GETDATE()) AS TimeZoneOffsetHours;
```

**Explanation:**
*   `GETUTCDATE()` returns the current date and time in Coordinated Universal Time (UTC).
*   `DATEDIFF(HOUR, ...)` calculates the difference in hours between UTC and the server's local time.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Assuming server is in India Standard Time (UTC+5:30)</p>
<pre><code>
LocalDateTime             UTCDateTime               TimeZoneOffsetHours
------------------------- ------------------------- -------------------
2025-04-02 16:15:30.123   2025-04-02 10:45:30.123   5
</code></pre>
</details>

### 3. SYSDATETIME()

**Goal:** Retrieve the current system date and time with higher fractional second precision.

```sql
SELECT
    GETDATE() AS StandardPrecision,
    SYSDATETIME() AS HighPrecision;
```

**Explanation:**
*   `SYSDATETIME()` returns a `datetime2(7)` value, offering more precision (up to 100 nanoseconds) compared to `GETDATE()` (`datetime`, ~3.33 milliseconds precision).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
StandardPrecision         HighPrecision
------------------------- ---------------------------
2025-04-02 16:15:30.123   2025-04-02 16:15:30.1234567
</code></pre>
</details>

### 4. SYSUTCDATETIME() and 5. SYSDATETIMEOFFSET()

**Goal:** Retrieve high-precision UTC time and the system time including the timezone offset.

```sql
SELECT
    SYSDATETIMEOFFSET() AS CurrentWithOffset,
    SYSUTCDATETIME() AS UTCHighPrecision;
```

**Explanation:**
*   `SYSUTCDATETIME()` is the high-precision version of `GETUTCDATE()`.
*   `SYSDATETIMEOFFSET()` returns a `datetimeoffset(7)` value, which includes the date, time (high precision), and the server's current timezone offset from UTC.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Assuming server is in India Standard Time (UTC+5:30)</p>
<pre><code>
CurrentWithOffset                   UTCHighPrecision
----------------------------------- ---------------------------
2025-04-02 16:15:30.1234567 +05:30   2025-04-02 10:45:30.1234567
</code></pre>
</details>

### 6. CURRENT_TIMESTAMP

**Goal:** Retrieve the current system timestamp using the ANSI SQL standard function.

```sql
SELECT
    CURRENT_TIMESTAMP AS CurrentTime,
    'ANSI SQL Standard' AS Standard;
```

**Explanation:**
*   `CURRENT_TIMESTAMP` is functionally equivalent to `GETDATE()` in SQL Server, returning a `datetime` value. It's provided for ANSI SQL compatibility.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
CurrentTime               Standard
------------------------- -------------------
2025-04-02 16:15:30.123   ANSI SQL Standard
</code></pre>
</details>

### 7. DATEADD()

**Goal:** Calculate future and past dates based on leave request start dates.

```sql
SELECT
    StartDate,
    DATEADD(DAY, 30, StartDate) AS Plus30Days,
    DATEADD(MONTH, 1, StartDate) AS Plus1Month,
    DATEADD(YEAR, -1, StartDate) AS Minus1Year
FROM HR.LeaveRequests;
```

**Explanation:**
*   `DATEADD(datepart, number, date)` adds the `number` of `datepart` units (e.g., `DAY`, `MONTH`, `YEAR`) to the input `date`. A negative number subtracts the interval.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
StartDate   Plus30Days  Plus1Month  Minus1Year
----------- ----------- ----------- -----------
2023-08-15  2023-09-14  2023-09-15  2022-08-15
2023-09-01  2023-10-01  2023-10-01  2022-09-01
2023-08-10  2023-09-09  2023-09-10  2022-08-10
</code></pre>
</details>

### 8. DATEDIFF()

**Goal:** Calculate the duration of leave requests in days and the approval time in hours.

```sql
SELECT
    RequestID,
    StartDate,
    EndDate,
    DATEDIFF(DAY, StartDate, EndDate) + 1 AS LeaveDurationDays, -- Add 1 for inclusive duration
    DATEDIFF(HOUR, RequestDate, ApprovalDate) AS ApprovalHours
FROM HR.LeaveRequests;
```

**Explanation:**
*   `DATEDIFF(datepart, startdate, enddate)` calculates the number of `datepart` boundaries crossed between the start and end dates.
*   **Important:** `DATEDIFF(DAY, ...)` counts the *number of midnights* crossed, not necessarily 24-hour periods. To get inclusive day duration, often `+ 1` is added.
*   `DATEDIFF(HOUR, ...)` counts the number of hour boundaries crossed.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
RequestID  StartDate   EndDate     LeaveDurationDays ApprovalHours
---------- ----------- ----------- ----------------- -------------
1          2023-08-15  2023-08-20  6                 27 -- (Aug 2 14:15 - Aug 1 10:30)
2          2023-09-01  2023-09-05  5                 25 -- (Aug 16 11:20 - Aug 15 09:45)
3          2023-08-10  2023-08-12  3                 17 -- (Aug 6 10:00 - Aug 5 16:20)
</code></pre>
</details>

### 9. DATEDIFF_BIG()

**Goal:** Calculate a large time difference (e.g., seconds since a specific date) that might exceed the `int` limit.

```sql
SELECT
    DATEDIFF_BIG(SECOND, '2000-01-01 00:00:00', GETDATE()) AS SecondsSince2000;
```

**Explanation:**
*   Identical to `DATEDIFF` but returns a `bigint`, suitable for intervals that might result in a number larger than ~2.14 billion when measured in small units like seconds or milliseconds.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>As of 2025-04-02 16:15:30</p>
<pre><code>
SecondsSince2000
--------------------
795917730
</code></pre>
</details>

### 10. DATEPART()

**Goal:** Extract individual components (year, month, day, hour, minute) from the `CheckInTime`.

```sql
SELECT
    CheckInTime,
    DATEPART(YEAR, CheckInTime) AS Year,
    DATEPART(MONTH, CheckInTime) AS Month,
    DATEPART(DAY, CheckInTime) AS Day,
    DATEPART(HOUR, CheckInTime) AS Hour,
    DATEPART(MINUTE, CheckInTime) AS Minute
FROM HR.TimeRecords;
```

**Explanation:**
*   `DATEPART(datepart, date)` returns an integer representing the specified part (e.g., `YEAR`, `MONTH`, `DAY`, `HOUR`, `MINUTE`, `SECOND`, `WEEKDAY`, `QUARTER`, etc.).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
CheckInTime                 Year  Month  Day  Hour  Minute
--------------------------- ----- ------ ---- ----- ------
2023-08-01 09:00:00.0000000 2023  8      1    9     0
2023-08-01 08:30:00.0000000 2023  8      1    8     30
2023-08-01 10:00:00.0000000 2023  8      1    10    0
</code></pre>
</details>

### 11. DATENAME()

**Goal:** Get the full name of the month and weekday for the `CheckInTime`.

```sql
SELECT
    CheckInTime,
    DATENAME(MONTH, CheckInTime) AS MonthName,
    DATENAME(WEEKDAY, CheckInTime) AS WeekdayName
FROM HR.TimeRecords;
```

**Explanation:**
*   `DATENAME(datepart, date)` returns a character string representing the name of the date part (e.g., 'August', 'Tuesday'). The language depends on server settings.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
CheckInTime                 MonthName   WeekdayName
--------------------------- ----------- -----------
2023-08-01 09:00:00.0000000 August      Tuesday
2023-08-01 08:30:00.0000000 August      Tuesday
2023-08-01 10:00:00.0000000 August      Tuesday
</code></pre>
</details>

### 12. YEAR(), 13. MONTH(), 14. DAY()

**Goal:** Extract year, month, and day from `RequestDate` using shorthand functions.

```sql
SELECT
    RequestDate,
    YEAR(RequestDate) AS YearOnly,
    MONTH(RequestDate) AS MonthOnly,
    DAY(RequestDate) AS DayOnly
FROM HR.LeaveRequests;
```

**Explanation:**
*   These are convenient shortcuts for `DATEPART(YEAR, ...)`, `DATEPART(MONTH, ...)`, and `DATEPART(DAY, ...)`.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
RequestDate                 YearOnly  MonthOnly  DayOnly
--------------------------- --------  ---------  -------
2023-08-01 10:30:00.0000000 2023      8          1
2023-08-15 09:45:00.0000000 2023      8          15
2023-08-05 16:20:00.0000000 2023      8          5
</code></pre>
</details>

### 15. EOMONTH()

**Goal:** Find the last day of the month for the `StartDate` and the last day of the following month.

```sql
SELECT
    StartDate,
    EOMONTH(StartDate) AS EndOfMonth,
    EOMONTH(StartDate, 1) AS EndOfNextMonth -- Add 1 month offset
FROM HR.LeaveRequests;
```

**Explanation:**
*   `EOMONTH(start_date, [months_to_add])` returns the date of the last day of the month containing the `start_date`. The optional second argument adds months before determining the end of the month.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
StartDate   EndOfMonth  EndOfNextMonth
----------- ----------- --------------
2023-08-15  2023-08-31  2023-09-30
2023-09-01  2023-09-30  2023-10-31
2023-08-10  2023-08-31  2023-09-30
</code></pre>
</details>

### 16. SWITCHOFFSET() and 17. TODATETIMEOFFSET()

**Goal:** Convert a local `datetime2` value to a specific timezone offset (`datetimeoffset`) and then switch it to UTC.

```sql
DECLARE @LocalTime DATETIME2 = '2023-08-20 14:30:00';
DECLARE @TimeZoneOffset VARCHAR(6) = '-04:00'; -- Example: Eastern Daylight Time

SELECT
    TODATETIMEOFFSET(@LocalTime, @TimeZoneOffset) AS TimeWithOffset,
    SWITCHOFFSET(TODATETIMEOFFSET(@LocalTime, @TimeZoneOffset), '+00:00') AS UTCTimeEquivalent;
```

**Explanation:**
*   `TODATETIMEOFFSET(datetime_value, timezone_offset)` takes a `datetime2` value and appends the specified offset (e.g., '-04:00', '+05:30') to create a `datetimeoffset`.
*   `SWITCHOFFSET(datetimeoffset_value, new_timezone_offset)` changes the offset part of a `datetimeoffset` value, adjusting the date/time part accordingly to represent the *same point in time* in the new offset. Here, it converts the time to UTC ('+00:00').

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
TimeWithOffset                      UTCTimeEquivalent
----------------------------------- -----------------------------------
2023-08-20 14:30:00.0000000 -04:00   2023-08-20 18:30:00.0000000 +00:00
</code></pre>
</details>

### 18. ISDATE()

**Goal:** Check if given strings represent valid dates recognized by SQL Server.

```sql
SELECT
    '2023-08-20' AS DateString1, ISDATE('2023-08-20') AS IsValid1,
    '2023-13-45' AS DateString2, ISDATE('2023-13-45') AS IsValid2,
    'Not A Date' AS DateString3, ISDATE('Not A Date') AS IsValid3;
```

**Explanation:**
*   `ISDATE(expression)` returns `1` (true) if the input string can be successfully converted to a `date`, `time`, `datetime`, `datetime2`, or `smalldatetime` value based on server language settings; otherwise, it returns `0` (false). It does *not* enforce a specific format.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
DateString1  IsValid1  DateString2  IsValid2  DateString3  IsValid3
-----------  --------  -----------  --------  -----------  --------
2023-08-20   1         2023-13-45   0         Not A Date   0
</code></pre>
</details>

### 19-23. ...FROMPARTS() Functions

**Goal:** Construct various date/time data types from their individual components.

```sql
-- DATETIME2 from parts
SELECT DATETIME2FROMPARTS(2023, 8, 20, 14, 30, 45, 123, 3) AS ConstructedDateTime2;

-- DATETIMEOFFSET from parts
SELECT DATETIMEOFFSETFROMPARTS(2023, 8, 20, 14, 30, 45, 123, -4, 0, 3) AS ConstructedDateTimeOffset;

-- DATE from parts
SELECT DATEFROMPARTS(2023, 8, 20) AS ConstructedDate;

-- TIME from parts
SELECT TIMEFROMPARTS(14, 30, 45, 123, 3) AS ConstructedTime;

-- SMALLDATETIME from parts
SELECT SMALLDATETIMEFROMPARTS(2023, 8, 20, 14, 30) AS ConstructedSmallDateTime;
```

**Explanation:**
*   These functions provide a safe and explicit way to create date/time values from integer parts (year, month, day, hour, minute, second, fractions, offset). They validate the input parts.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
ConstructedDateTime2
---------------------------
2023-08-20 14:30:45.123

ConstructedDateTimeOffset
-----------------------------------
2023-08-20 14:30:45.123 -04:00

ConstructedDate
-----------
2023-08-20

ConstructedTime
--------------
14:30:45.123

ConstructedSmallDateTime
-----------------------
2023-08-20 14:30:00
</code></pre>
</details>

---

## Interview Question

**Question:** Using the `HR.TimeRecords` table which has `CheckInTime` and `CheckOutTime` (both `DATETIME2`), write a query to calculate the total duration worked in minutes for each `EmployeeID` on `ShiftDate` '2023-08-01'.

### Solution Script

```sql
SELECT
    EmployeeID,
    ShiftDate,
    SUM(DATEDIFF(MINUTE, CheckInTime, CheckOutTime)) AS TotalMinutesWorked
FROM HR.TimeRecords
WHERE ShiftDate = '2023-08-01'
GROUP BY EmployeeID, ShiftDate;
```

### Explanation

1.  **`SELECT EmployeeID, ShiftDate, SUM(...)`**: Selects the employee identifier, the shift date, and the sum of the calculated duration.
2.  **`DATEDIFF(MINUTE, CheckInTime, CheckOutTime)`**: Calculates the difference between the check-out and check-in times in minutes for each individual record.
3.  **`SUM(...)`**: Aggregates the minutes calculated by `DATEDIFF` for each group. This handles cases where an employee might have multiple check-in/out records on the same day (though not present in the sample data).
4.  **`FROM HR.TimeRecords`**: Specifies the table to query.
5.  **`WHERE ShiftDate = '2023-08-01'`**: Filters the records to include only those for the specified date *before* grouping.
6.  **`GROUP BY EmployeeID, ShiftDate`**: Groups the results by employee and shift date so `SUM` calculates the total minutes per employee for that specific day.

---

## Tricky Interview Questions (Easy to Hard)

1.  **Easy:** What is the main difference in precision between `GETDATE()` and `SYSDATETIME()`?
    *   *(Answer Hint: `datetime` vs `datetime2(7)` precision)*
2.  **Easy:** If `DATEDIFF(YEAR, '2023-12-31', '2024-01-01')` returns 1, does this mean a full year has passed? Explain why or why not.
    *   *(Answer Hint: `DATEDIFF` counts boundaries crossed, not full durations)*
3.  **Medium:** How would you get the date of the first day of the current month using date functions?
    *   *(Answer Hint: Combine `EOMONTH` (with -1 offset) and `DATEADD(DAY, 1, ...)` or use `DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)`)*
4.  **Medium:** What is the difference between `DATEPART(WEEKDAY, ...)` and `DATEPART(DW, ...)`?
    *   *(Answer Hint: Both return day of the week, but numbering depends on `DATEFIRST` setting. `DW` is often preferred for consistency)*
5.  **Medium:** Explain the purpose of `SYSDATETIMEOFFSET()`. What information does it provide that `SYSDATETIME()` does not?
    *   *(Answer Hint: Includes the server's timezone offset from UTC)*
6.  **Medium/Hard:** Why might `ISDATE('04-02-2025')` return 1 (true) on a server set to US English but 0 (false) on a server set to UK English? What function is generally safer for checking specific date formats?
    *   *(Answer Hint: `ISDATE` is locale-dependent. `TRY_CONVERT` or `TRY_PARSE` with a specific style code are safer)*
7.  **Hard:** How can you calculate the number of *business days* (excluding weekends) between two dates using standard date functions (without loops or calendar tables)?
    *   *(Answer Hint: Complex calculation involving total days, subtracting full weeks * 2, and adjusting for start/end day weekdays. Often simpler with a calendar table)*
8.  **Hard:** Describe a scenario where using `DATEDIFF_BIG` would be essential over `DATEDIFF`.
    *   *(Answer Hint: Calculating differences over very long periods in small units like milliseconds or seconds, potentially exceeding the `int` limit)*
9.  **Hard:** How do `SWITCHOFFSET` and `TODATETIMEOFFSET` differ in their purpose and how they affect the underlying UTC time?
    *   *(Answer Hint: `TODATETIMEOFFSET` *assigns* an offset to a non-offset value. `SWITCHOFFSET` *changes* the offset of an existing offset value, adjusting the local time to preserve the UTC instant)*
10. **Hard:** If you construct a date using `DATEFROMPARTS(2024, 2, 29)`, it works. What happens if you use `DATEFROMPARTS(2023, 2, 29)` and why?
    *   *(Answer Hint: It will raise an error because 2023 is not a leap year and Feb 29, 2023, is not a valid date. `...FROMPARTS` functions validate the resulting date)*