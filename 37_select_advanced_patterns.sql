-- =============================================
-- DQL Advanced Query Patterns
-- =============================================

USE HRSystem;
GO

-- 1. Paging with OFFSET-FETCH
-- Modern approach to pagination
DECLARE @PageNumber INT = 2;
DECLARE @RowsPerPage INT = 10;

SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Email,
    Salary
FROM HR.EMP_Details
ORDER BY LastName, FirstName
OFFSET (@PageNumber - 1) * @RowsPerPage ROWS
FETCH NEXT @RowsPerPage ROWS ONLY;
-- OFFSET skips specified number of rows
-- FETCH NEXT limits how many rows to return
-- More readable than older ROW_NUMBER() approach

-- 2. Handling Gaps and Islands
-- Finding consecutive ranges in data
WITH NumberedDates AS (
    SELECT 
        EmployeeID,
        AttendanceDate,
        DATEADD(DAY, -ROW_NUMBER() OVER(PARTITION BY EmployeeID ORDER BY AttendanceDate), AttendanceDate) AS GroupingDate
    FROM HR.Attendance
),
GroupedDates AS (
    SELECT 
        EmployeeID,
        GroupingDate,
        MIN(AttendanceDate) AS StartDate,
        MAX(AttendanceDate) AS EndDate,
        DATEDIFF(DAY, MIN(AttendanceDate), MAX(AttendanceDate)) + 1 AS ConsecutiveDays
    FROM NumberedDates
    GROUP BY EmployeeID, GroupingDate
)
SELECT 
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS EmployeeName,
    gd.StartDate,
    gd.EndDate,
    gd.ConsecutiveDays
FROM GroupedDates gd
JOIN HR.EMP_Details e ON gd.EmployeeID = e.EmployeeID
WHERE gd.ConsecutiveDays > 5
ORDER BY e.EmployeeID, gd.StartDate;
-- Identifies consecutive date ranges (islands) and gaps
-- First CTE assigns group identifier to consecutive dates
-- Second CTE aggregates by group to find ranges
-- Final query shows employees with attendance streaks > 5 days

-- 3. Cumulative Distribution
-- Calculating percentiles and distributions
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Salary,
    PERCENT_RANK() OVER(ORDER BY Salary) AS PercentRank,
    CUME_DIST() OVER(ORDER BY Salary) AS CumulativeDistribution,
    NTILE(4) OVER(ORDER BY Salary) AS Quartile,
    CASE 
        WHEN PERCENT_RANK() OVER(ORDER BY Salary) < 0.25 THEN 'Bottom 25%'
        WHEN PERCENT_RANK() OVER(ORDER BY Salary) < 0.5 THEN 'Lower Middle 25%'
        WHEN PERCENT_RANK() OVER(ORDER BY Salary) < 0.75 THEN 'Upper Middle 25%'
        ELSE 'Top 25%'
    END AS SalaryBracket
FROM HR.EMP_Details;
-- PERCENT_RANK: Relative rank from 0 to 1
-- CUME_DIST: Cumulative distribution from 0 to 1
-- NTILE: Divides into equal-sized buckets (quartiles here)
-- Useful for statistical analysis and reporting

-- 4. Conditional Aggregation with PIVOT
-- Transforms rows to columns with aggregation
SELECT 
    JobTitle,
    [1] AS HR_Dept,
    [2] AS IT_Dept,
    [3] AS Finance_Dept,
    [4] AS Marketing_Dept,
    [1] + [2] + [3] + [4] AS TotalSalary
FROM (
    SELECT 
        JobTitle,
        DepartmentID,
        Salary
    FROM HR.EMP_Details
) AS SourceData
PIVOT (
    SUM(Salary)
    FOR DepartmentID IN ([1], [2], [3], [4])
) AS PivotTable
ORDER BY JobTitle;
-- Transforms department IDs into columns
-- Aggregates salary by job title and department
-- Adds calculated column for row totals
-- Creates a cross-tabulation report

-- 5. Dynamic Search with CASE
-- Implements flexible search logic
DECLARE @SearchType VARCHAR(20) = 'Department'; -- Options: 'Name', 'Department', 'Salary'
DECLARE @SearchValue VARCHAR(50) = '2';
DECLARE @MinSalary DECIMAL(10,2) = 50000;
DECLARE @MaxSalary DECIMAL(10,2) = 80000;

SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID,
    Salary
FROM HR.EMP_Details
WHERE 
    CASE 
        WHEN @SearchType = 'Name' THEN 
            (FirstName LIKE '%' + @SearchValue + '%' OR LastName LIKE '%' + @SearchValue + '%')
        WHEN @SearchType = 'Department' THEN 
            CAST(DepartmentID AS VARCHAR) = @SearchValue
        WHEN @SearchType = 'Salary' THEN 
            (Salary BETWEEN @MinSalary AND @MaxSalary)
        ELSE 1 -- Default to true if invalid search type
    END = 1;
-- Single query handles multiple search types
-- CASE expression evaluates to 1 (true) or 0 (false)
-- Allows dynamic search without dynamic SQL
-- Useful for search forms with multiple criteria

-- 6. Unpivoting Data
-- Transforms columns to rows (reverse of PIVOT)
SELECT 
    JobTitle,
    'Department ' + CAST(DepartmentName AS VARCHAR) AS DepartmentName,
    SalaryTotal
FROM (
    SELECT 
        JobTitle, 
        [HR] AS HR,
        [IT] AS IT,
        [Finance] AS Finance,
        [Marketing] AS Marketing
    FROM PivotedSalaries
) AS SourceTable
UNPIVOT (
    SalaryTotal FOR DepartmentName IN (
        [HR], [IT], [Finance], [Marketing]
    )
) AS UnpivotTable;
-- Converts column-oriented data back to row-oriented
-- Column names become values in the DepartmentName column
-- Column values become values in the SalaryTotal column
-- Useful for normalizing denormalized data

-- 7. Handling Hierarchical Data with Recursive CTE
-- Traversing and manipulating tree structures
WITH OrgHierarchy AS (
    -- Anchor: Start with top-level managers
    SELECT 
        EmployeeID,
        FirstName,
        LastName,
        ManagerID,
        0 AS Level,
        CAST(FirstName + ' ' + LastName AS VARCHAR(1000)) AS HierarchyPath,
        CAST(EmployeeID AS VARCHAR(1000)) AS EmployeePath
    FROM HR.EMP_Details
    WHERE ManagerID IS NULL
    
    UNION ALL
    
    -- Recursive: Add employees who report to previously found managers
    SELECT 
        e.EmployeeID,
        e.FirstName,
        e.LastName,
        e.ManagerID,
        oh.Level + 1,
        CAST(oh.HierarchyPath + ' > ' + e.FirstName + ' ' + e.LastName AS VARCHAR(1000)),
        CAST(oh.EmployeePath + '.' + CAST(e.EmployeeID AS VARCHAR) AS VARCHAR(1000))
    FROM HR.EMP_Details e
    INNER JOIN OrgHierarchy oh ON e.ManagerID = oh.EmployeeID
)
SELECT 
    EmployeeID,
    REPLICATE('    ', Level) + FirstName + ' ' + LastName AS Employee,
    Level AS HierarchyLevel,
    HierarchyPath,
    EmployeePath
FROM OrgHierarchy
ORDER BY EmployeePath;
-- Builds complete organizational hierarchy
-- Level indicates depth in the hierarchy
-- HierarchyPath shows the reporting chain as names
-- EmployeePath creates a sortable path (like 1.4.12)
-- REPLICATE creates indentation for visual hierarchy

-- 8. Calculating Moving Averages
-- Time series analysis with window functions
SELECT 
    DepartmentID,
    CAST(HireMonth AS DATE) AS Month,
    NewHires,
    AVG(NewHires) OVER(
        PARTITION BY DepartmentID 
        ORDER BY HireMonth
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS ThreeMonthMovingAvg,
    SUM(NewHires) OVER(
        PARTITION BY DepartmentID 
        ORDER BY HireMonth
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS CumulativeHires
FROM (
    SELECT 
        DepartmentID,
        DATEFROMPARTS(YEAR(HireDate), MONTH(HireDate), 1) AS HireMonth,
        COUNT(*) AS NewHires
    FROM HR.EMP_Details
    GROUP BY DepartmentID, DATEFROMPARTS(YEAR(HireDate), MONTH(HireDate), 1)
) AS MonthlyHires
ORDER BY DepartmentID, HireMonth;
-- Groups hires by month and department
-- Calculates 3-month moving average of new hires
-- Also shows running total of hires by department
-- Useful for trend analysis and forecasting

-- 9. Finding Median Values
-- Calculating true median (middle value)
WITH SalaryRanks AS (
    SELECT 
        DepartmentID,
        Salary,
        ROW_NUMBER() OVER(PARTITION BY DepartmentID ORDER BY Salary) AS RowAsc,
        ROW_NUMBER() OVER(PARTITION BY DepartmentID ORDER BY Salary DESC) AS RowDesc
    FROM HR.EMP_Details
)
SELECT 
    DepartmentID,
    AVG(Salary) AS MedianSalary
FROM SalaryRanks
WHERE 
    ABS(RowAsc - RowDesc) <= 1  -- Identifies middle value(s)
GROUP BY DepartmentID;
-- Assigns row numbers from both directions
-- Middle value(s) will have approximately equal row numbers
-- AVG handles both odd and even counts (one or two middle values)
-- More accurate than percentile approximations

-- 10. Custom Sorting
-- Complex ordering beyond simple columns
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Salary,
    DepartmentID
FROM HR.EMP_Details
ORDER BY 
    CASE 
        WHEN Salary = 50000 THEN 0  -- Show $50,000 salaries first
        WHEN DepartmentID = 1 THEN 1  -- Then Department 1
        WHEN DepartmentID = 2 THEN 2  -- Then Department 2
        ELSE 3  -- Then everything else
    END,
    LastName,  -- Secondary sort by last name
    FirstName;  -- Tertiary sort by first name
-- Implements business-specific sorting rules
-- CASE expression creates custom sort keys
-- Multiple ORDER BY columns provide tiebreakers

-- 11. Handling Slowly Changing Dimensions
-- Tracking historical changes in data
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    sh.DepartmentID,
    d.DepartmentName,
    sh.Salary,
    sh.EffectiveDate,
    sh.EndDate,
    CASE 
        WHEN sh.EndDate IS NULL THEN 'Current'
        ELSE 'Historical'
    END AS Status
FROM HR.EMP_Details e
JOIN HR.SalaryHistory sh ON e.EmployeeID = sh.EmployeeID
JOIN HR.Departments d ON sh.DepartmentID = d.DepartmentID
WHERE e.EmployeeID = 1001
ORDER BY sh.EffectiveDate;
-- Shows all historical records for an employee
-- Tracks changes in salary and department over time
-- Identifies current vs. historical records
-- Implements Type 2 slowly changing dimension pattern

-- 12. Handling XML Data
-- Querying and extracting XML data
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    SkillsXML.value('(/Skills/Skill)[1]', 'VARCHAR(50)') AS PrimarySkill,
    SkillsXML.value('count(/Skills/Skill)', 'INT') AS SkillCount,
    SkillsXML.query('/Skills/Skill[contains(., "SQL")]') AS SQLSkills
FROM HR.EMP_Details
WHERE SkillsXML.exist('/Skills/Skill[contains(., "SQL")]') = 1;
-- Extracts values from XML column
-- value(): Gets specific values
-- query(): Returns XML fragments
-- exist(): Tests for existence of nodes
-- Useful for working with semi-structured data

-- 13. Handling JSON Data
-- Querying and extracting JSON data
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    JSON_VALUE(SkillsJSON, '$.PrimarySkill') AS PrimarySkill,
    JSON_QUERY(SkillsJSON, '$.Certifications') AS Certifications,
    JSON_VALUE(SkillsJSON, '$.YearsExperience') AS Experience
FROM HR.EMP_Details
WHERE 
    ISJSON(SkillsJSON) = 1 AND
    JSON_VALUE(SkillsJSON, '$.YearsExperience') > 5;
-- JSON_VALUE: Extracts scalar values
-- JSON_QUERY: Extracts objects or arrays
-- ISJSON: Validates JSON format
-- Filters based on JSON properties

-- 14. Handling Missing Values
-- Strategies for dealing with NULL and missing data
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    COALESCE(MiddleName, '') AS MiddleName,
    ISNULL(Phone, 'No Phone') AS Phone,
    CASE 
        WHEN Email IS NULL THEN 'No Email'
        WHEN Email = '' THEN 'Empty Email'
        ELSE Email
    END AS Email,
    NULLIF(DepartmentID, 0) AS DepartmentID,
    Salary
FROM HR.EMP_Details;
-- COALESCE: Returns first non-NULL value
-- ISNULL: Returns substitute if value is NULL
-- CASE: Handles multiple conditions
-- NULLIF: Returns NULL if values match

-- 15. Calculating Business Days
-- Excluding weekends and holidays
WITH DateSequence AS (
    SELECT 
        DATEADD(DAY, number, '2023-01-01') AS CalendarDate
    FROM master.dbo.spt_values
    WHERE 
        type = 'P' AND 
        number BETWEEN 0 AND 365
),
BusinessDays AS (
    SELECT 
        CalendarDate
    FROM DateSequence
    WHERE 
        DATEPART(WEEKDAY, CalendarDate) NOT IN (1, 7) -- Exclude Saturday and Sunday
        AND CalendarDate NOT IN (SELECT HolidayDate FROM HR.Holidays) -- Exclude holidays
)
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    e.HireDate,
    GETDATE() AS CurrentDate,
    (SELECT COUNT(*) FROM BusinessDays 
     WHERE CalendarDate BETWEEN e.HireDate AND GETDATE()) AS BusinessDaysSinceHire
FROM HR.EMP_Details e
WHERE e.HireDate >= '2023-01-01';
-- Generates sequence of all dates in range
-- Filters to business days only (excludes weekends and holidays)
-- Counts business days between hire date and current date
-- Useful for calculating service periods, SLAs, etc.