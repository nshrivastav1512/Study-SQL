-- =============================================
-- DQL Advanced Filtering Techniques
-- =============================================

USE HRSystem;
GO

-- 1. Dynamic Search Conditions
-- Handles optional search parameters
DECLARE @DepartmentID INT = NULL;
DECLARE @MinSalary DECIMAL(10,2) = 50000;
DECLARE @JobTitle VARCHAR(50) = NULL;

SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID,
    Salary,
    JobTitle
FROM HR.EMP_Details
WHERE (DepartmentID = @DepartmentID OR @DepartmentID IS NULL)
  AND (Salary >= @MinSalary OR @MinSalary IS NULL)
  AND (JobTitle = @JobTitle OR @JobTitle IS NULL);
-- Only applies filters for non-NULL parameters
-- If parameter is NULL, that condition is effectively ignored
-- Allows one query to handle many search combinations

-- 2. Fuzzy Matching with SOUNDEX
-- Finds names that sound similar
SELECT 
    EmployeeID,
    FirstName,
    LastName
FROM HR.EMP_Details
WHERE SOUNDEX(LastName) = SOUNDEX('Smith');
-- Finds "Smith", "Smyth", "Smithe", etc.
-- SOUNDEX converts names to phonetic codes
-- Useful for finding records despite spelling variations

-- 3. Full-Text Search
-- Searches for words or phrases in text
-- Requires Full-Text Search to be enabled
SELECT 
    DocumentID,
    Title,
    DocumentContent
FROM HR.Documents
WHERE CONTAINS(DocumentContent, 'project AND (plan OR proposal)');
-- Finds documents containing "project" AND either "plan" OR "proposal"
-- More powerful than LIKE for text searching
-- Supports word proximity, inflectional forms, thesaurus, etc.

-- 4. Temporal Queries
-- Filtering based on time periods
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DATEDIFF(YEAR, HireDate, GETDATE()) AS YearsOfService,
    Salary
FROM HR.EMP_Details
WHERE 
    HireDate BETWEEN DATEADD(YEAR, -5, GETDATE()) AND DATEADD(YEAR, -2, GETDATE())
    AND DATEPART(MONTH, HireDate) IN (1, 2, 3);
-- Finds employees hired 2-5 years ago in Q1 (Jan-Mar)
-- DATEDIFF calculates tenure
-- DATEPART extracts specific parts of dates

-- 5. Spatial Data Filtering
-- Queries based on geographic location
-- Requires spatial data types
SELECT 
    LocationID,
    LocationName,
    City,
    State
FROM HR.Locations
WHERE 
    Geography::Point(47.6062, -122.3321, 4326).STDistance(LocationGeo) <= 80467;
-- Finds locations within 50 miles (80467 meters) of Seattle
-- Uses SQL Server's geography data type
-- STDistance calculates distance between points

-- 6. JSON Data Filtering
-- Extracts and filters JSON data
-- SQL Server 2016+ feature
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    JSON_VALUE(AdditionalInfo, '$.Skills[0]') AS PrimarySkill,
    JSON_QUERY(AdditionalInfo, '$.Projects') AS Projects
FROM HR.EMP_Details
WHERE 
    ISJSON(AdditionalInfo) = 1
    AND JSON_VALUE(AdditionalInfo, '$.YearsExperience') > 5
    AND JSON_VALUE(AdditionalInfo, '$.Department.Name') = 'IT';
-- Extracts and filters data stored in JSON format
-- JSON_VALUE gets scalar values, JSON_QUERY gets objects/arrays
-- Condition checks for IT department with >5 years experience

-- 7. Hierarchical Data Filtering
-- Filters hierarchical data using recursive CTE
WITH ManagerHierarchy AS (
    -- Anchor: Start with specific manager
    SELECT 
        EmployeeID,
        FirstName,
        LastName,
        ManagerID,
        0 AS Level
    FROM HR.EMP_Details
    WHERE EmployeeID = 101  -- Starting manager ID
    
    UNION ALL
    
    -- Recursive: Find all reports (direct and indirect)
    SELECT 
        e.EmployeeID,
        e.FirstName,
        e.LastName,
        e.ManagerID,
        mh.Level + 1
    FROM HR.EMP_Details e
    INNER JOIN ManagerHierarchy mh ON e.ManagerID = mh.EmployeeID
)
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Level
FROM ManagerHierarchy
WHERE Level > 0  -- Exclude the starting manager
ORDER BY Level, LastName;
-- Finds all employees who report to manager #101 (directly or indirectly)
-- Level indicates reporting distance (1 = direct report, 2 = report's report)
-- Useful for organizational hierarchy queries

-- 8. Bitwise Filtering (continued)
-- Filters using bitwise operations on flag columns
-- Permissions example: 1=Read, 2=Write, 4=Execute, 8=Admin
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Permissions,
    CASE
        WHEN (Permissions & 1) = 1 THEN 'Yes' ELSE 'No'
    END AS HasReadAccess,
    CASE
        WHEN (Permissions & 2) = 2 THEN 'Yes' ELSE 'No'
    END AS HasWriteAccess,
    CASE
        WHEN (Permissions & 4) = 4 THEN 'Yes' ELSE 'No'
    END AS HasExecuteAccess,
    CASE
        WHEN (Permissions & 8) = 8 THEN 'Yes' ELSE 'No'
    END AS HasAdminAccess
FROM HR.EMP_Details
WHERE 
    (Permissions & 12) = 12;  -- Has both Execute (4) AND Admin (8) permissions
-- Bitwise operations are efficient for storing and checking multiple flags
-- Can check for specific combinations of permissions

-- 9. Filtered Aggregates
-- Applies different filters within aggregate functions
SELECT 
    DepartmentID,
    COUNT(*) AS TotalEmployees,
    COUNT(CASE WHEN Salary > 70000 THEN 1 END) AS HighPaidCount,
    COUNT(CASE WHEN HireDate >= DATEADD(YEAR, -1, GETDATE()) THEN 1 END) AS NewHires,
    AVG(CASE WHEN Gender = 'F' THEN Salary END) AS AvgFemaleSalary,
    AVG(CASE WHEN Gender = 'M' THEN Salary END) AS AvgMaleSalary
FROM HR.EMP_Details
GROUP BY DepartmentID;
-- Calculates multiple filtered aggregates in a single query
-- Each CASE expression applies a different filter
-- NULL results from CASE are ignored by COUNT and AVG

-- 10. String Splitting and Filtering
-- Filters based on delimited string values
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Skills
FROM HR.EMP_Details
CROSS APPLY STRING_SPLIT(Skills, ',') AS s
WHERE s.value = 'SQL';
-- Assumes Skills column contains comma-separated values
-- STRING_SPLIT (SQL Server 2016+) splits the string into rows
-- CROSS APPLY joins each employee with their split skills
-- WHERE filters to only employees with 'SQL' skill

-- 11. Parameterized IN Lists
-- Handles dynamic IN lists
DECLARE @DepartmentList VARCHAR(100) = '1,3,5,7';

SELECT 
    EmployeeID,
    FirstName,
    LastName,
    DepartmentID
FROM HR.EMP_Details
WHERE DepartmentID IN (
    SELECT value FROM STRING_SPLIT(@DepartmentList, ',')
);
-- Converts comma-separated string to table of values
-- Allows dynamic IN lists without dynamic SQL
-- Useful for multi-select parameters in reports

-- 12. Filtering with APPLY
-- Uses APPLY to filter with complex logic
SELECT 
    d.DepartmentID,
    d.DepartmentName,
    e.HighestPaid
FROM HR.Departments d
CROSS APPLY (
    SELECT TOP 1
        FirstName + ' ' + LastName AS HighestPaid
    FROM HR.EMP_Details
    WHERE DepartmentID = d.DepartmentID
    ORDER BY Salary DESC
) e;
-- For each department, finds the highest-paid employee
-- CROSS APPLY runs the subquery for each department
-- More flexible than joins for row-by-row operations

-- 13. Filtering with Dynamic Pivoting
-- Filters data that needs to be pivoted dynamically
DECLARE @Columns NVARCHAR(MAX) = '';
DECLARE @SQL NVARCHAR(MAX);

-- Build column list dynamically
SELECT @Columns = @Columns + QUOTENAME(DepartmentName) + ',' 
FROM HR.Departments
ORDER BY DepartmentID;

-- Remove trailing comma
SET @Columns = LEFT(@Columns, LEN(@Columns) - 1);

-- Build and execute dynamic pivot query
SET @SQL = N'
SELECT 
    JobTitle, ' + @Columns + '
FROM (
    SELECT 
        d.DepartmentName,
        e.JobTitle,
        e.Salary
    FROM HR.EMP_Details e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    WHERE e.Salary > 50000
) AS SourceData
PIVOT (
    SUM(Salary)
    FOR DepartmentName IN (' + @Columns + ')
) AS PivotTable
ORDER BY JobTitle;';

EXEC sp_executesql @SQL;
-- Dynamically creates pivot columns based on department names
-- Filters to only high-salary employees before pivoting
-- Result shows salary totals by job title and department

-- 14. Temporal Table Filtering
-- Queries data as it existed at a specific point in time
-- Requires SQL Server 2016+ temporal tables
SELECT 
    EmployeeID,
    FirstName,
    LastName,
    Salary,
    DepartmentID
FROM HR.EMP_Details
FOR SYSTEM_TIME AS OF '2023-01-01';
-- Retrieves employee data as it existed on January 1, 2023
-- FOR SYSTEM_TIME clause works with system-versioned temporal tables
-- Allows point-in-time analysis without historical tables

-- 15. Semantic Search
-- Finds semantically similar content
-- Requires Semantic Search to be enabled
SELECT TOP 5
    d1.DocumentID,
    d1.Title,
    d2.DocumentID AS SimilarDocID,
    d2.Title AS SimilarDocTitle,
    ROUND(ssd.score * 100, 2) AS SimilarityScore
FROM HR.Documents d1
INNER JOIN semanticsimilaritytable(HR.Documents, DocumentContent, DocumentID) ssd
    ON d1.DocumentID = ssd.source_key
INNER JOIN HR.Documents d2
    ON ssd.matched_key = d2.DocumentID
WHERE d1.DocumentID = 101
ORDER BY SimilarityScore DESC;
-- Finds documents semantically similar to document #101
-- Uses SQL Server's semantic search capability
-- Returns similarity scores based on content meaning, not just keywords