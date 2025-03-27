/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\112_RANKING_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Ranking Functions with real-life examples
    using the HRSystem database schemas and tables.

    Ranking Functions covered:
    1. ROW_NUMBER() - Assigns unique sequential integers
    2. RANK() - Assigns rank with gaps for ties
    3. DENSE_RANK() - Assigns rank without gaps for ties
    4. NTILE() - Distributes rows into specified number of groups
*/

USE HRSystem;
GO

-- Create sample tables if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[EmployeePerformance]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.EmployeePerformance (
        PerformanceID INT PRIMARY KEY IDENTITY(1,1),
        EmployeeID INT,
        Year INT,
        Quarter INT,
        SalesAmount DECIMAL(12,2),
        ProjectsCompleted INT,
        CustomerSatisfaction DECIMAL(3,2),
        DepartmentID INT
    );

    -- Insert sample performance data
    INSERT INTO HR.EmployeePerformance 
    (EmployeeID, Year, Quarter, SalesAmount, ProjectsCompleted, CustomerSatisfaction, DepartmentID) VALUES
    (1, 2023, 1, 150000.00, 5, 4.8, 1),
    (2, 2023, 1, 175000.00, 4, 4.9, 1),
    (3, 2023, 1, 125000.00, 6, 4.7, 2),
    (4, 2023, 1, 175000.00, 3, 4.9, 2),
    (1, 2023, 2, 165000.00, 4, 4.7, 1),
    (2, 2023, 2, 180000.00, 5, 4.8, 1),
    (3, 2023, 2, 145000.00, 5, 4.8, 2),
    (4, 2023, 2, 175000.00, 4, 4.9, 2);

    -- Create table for employee rankings
    CREATE TABLE HR.EmployeeRankings (
        RankingID INT PRIMARY KEY IDENTITY(1,1),
        EmployeeID INT,
        SkillCategory VARCHAR(50),
        SkillLevel INT,
        CertificationScore DECIMAL(5,2),
        YearsExperience INT
    );

    -- Insert sample ranking data
    INSERT INTO HR.EmployeeRankings 
    (EmployeeID, SkillCategory, SkillLevel, CertificationScore, YearsExperience) VALUES
    (1, 'Technical', 4, 85.5, 5),
    (2, 'Technical', 5, 92.0, 7),
    (3, 'Technical', 3, 78.5, 3),
    (4, 'Technical', 5, 92.0, 6),
    (1, 'Management', 3, 88.0, 2),
    (2, 'Management', 4, 90.5, 4),
    (3, 'Management', 2, 75.0, 1),
    (4, 'Management', 4, 90.5, 3);
END

-- 1. ROW_NUMBER() - Assign sequential numbers to sales performance
SELECT 
    EmployeeID,
    Year,
    Quarter,
    SalesAmount,
    ROW_NUMBER() OVER(ORDER BY SalesAmount DESC) AS SalesRank,
    ROW_NUMBER() OVER(PARTITION BY Quarter ORDER BY SalesAmount DESC) AS QuarterlySalesRank
FROM HR.EmployeePerformance
WHERE Year = 2023;
/* Output example:
EmployeeID  Year  Quarter  SalesAmount  SalesRank  QuarterlySalesRank
2          2023  2        180000.00    1          1
4          2023  1        175000.00    2          1
2          2023  1        175000.00    3          2
4          2023  2        175000.00    4          2
*/

-- 2. RANK() - Rank employees by certification score with ties
SELECT 
    EmployeeID,
    SkillCategory,
    CertificationScore,
    RANK() OVER(PARTITION BY SkillCategory ORDER BY CertificationScore DESC) AS SkillRank,
    'Shows gaps in ranking for ties' AS Description
FROM HR.EmployeeRankings;
/* Output example:
EmployeeID  SkillCategory  CertificationScore  SkillRank  Description
2          Technical      92.0               1          Shows gaps in ranking for ties
4          Technical      92.0               1          Shows gaps in ranking for ties
1          Technical      85.5               3          Shows gaps in ranking for ties
*/

-- 3. DENSE_RANK() - Rank employees by projects completed without gaps
SELECT 
    EmployeeID,
    Year,
    Quarter,
    ProjectsCompleted,
    DENSE_RANK() OVER(ORDER BY ProjectsCompleted DESC) AS ProjectRank,
    'No gaps in ranking for ties' AS Description
FROM HR.EmployeePerformance
WHERE Year = 2023;
/* Output example:
EmployeeID  Year  Quarter  ProjectsCompleted  ProjectRank  Description
3          2023  1        6                 1           No gaps in ranking for ties
2          2023  2        5                 2           No gaps in ranking for ties
1          2023  1        5                 2           No gaps in ranking for ties
*/

-- 4. NTILE() - Group employees into performance quartiles
SELECT 
    EmployeeID,
    SalesAmount,
    CustomerSatisfaction,
    NTILE(4) OVER(ORDER BY SalesAmount DESC) AS SalesQuartile,
    NTILE(4) OVER(ORDER BY CustomerSatisfaction DESC) AS SatisfactionQuartile
FROM HR.EmployeePerformance
WHERE Year = 2023;
/* Output example:
EmployeeID  SalesAmount  CustomerSatisfaction  SalesQuartile  SatisfactionQuartile
2          180000.00    4.8                  1              2
4          175000.00    4.9                  1              1
2          175000.00    4.9                  2              1
*/

-- Complex example combining multiple ranking functions
SELECT 
    e.EmployeeID,
    d.DepartmentName,
    e.SalesAmount,
    e.ProjectsCompleted,
    e.CustomerSatisfaction,
    -- Different ranking methods for sales performance
    ROW_NUMBER() OVER(PARTITION BY e.DepartmentID ORDER BY e.SalesAmount DESC) AS DeptSalesPosition,
    RANK() OVER(ORDER BY e.SalesAmount DESC) AS OverallSalesRank,
    DENSE_RANK() OVER(ORDER BY e.SalesAmount DESC) AS OverallSalesDenseRank,
    -- Performance quartiles
    NTILE(4) OVER(ORDER BY e.SalesAmount DESC) AS SalesQuartile,
    -- Project completion rankings
    ROW_NUMBER() OVER(PARTITION BY e.Quarter ORDER BY e.ProjectsCompleted DESC) AS QuarterlyProjectRank,
    -- Customer satisfaction rankings
    DENSE_RANK() OVER(ORDER BY e.CustomerSatisfaction DESC) AS SatisfactionRank
FROM HR.EmployeePerformance e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE e.Year = 2023
ORDER BY e.DepartmentID, e.SalesAmount DESC;
/* Output example:
EmployeeID  DepartmentName  SalesAmount  ProjectsCompleted  CustomerSatisfaction  DeptSalesPosition  OverallSalesRank  OverallSalesDenseRank  SalesQuartile  QuarterlyProjectRank  SatisfactionRank
2          IT              180000.00    5                 4.8                  1                 1                1                    1             2                    2
2          IT              175000.00    4                 4.9                  2                 2                2                    1             3                    1
1          IT              165000.00    4                 4.7                  3                 3                3                    2             3                    3
*/

-- Example showing the difference between RANK and DENSE_RANK
SELECT 
    EmployeeID,
    SkillCategory,
    CertificationScore,
    -- Compare different ranking methods
    ROW_NUMBER() OVER(ORDER BY CertificationScore DESC) AS UniqueRank,
    RANK() OVER(ORDER BY CertificationScore DESC) AS RankWithGaps,
    DENSE_RANK() OVER(ORDER BY CertificationScore DESC) AS RankWithoutGaps,
    -- Add quartile grouping
    NTILE(4) OVER(ORDER BY CertificationScore DESC) AS Quartile
FROM HR.EmployeeRankings
WHERE SkillCategory = 'Technical'
ORDER BY CertificationScore DESC;
/* Output example:
EmployeeID  SkillCategory  CertificationScore  UniqueRank  RankWithGaps  RankWithoutGaps  Quartile
2          Technical      92.0               1          1             1                1
4          Technical      92.0               2          1             1                1
1          Technical      85.5               3          3             2                2
3          Technical      78.5               4          4             3                2
*/

-- Example of ranking within groups and overall
SELECT 
    r.EmployeeID,
    r.SkillCategory,
    r.SkillLevel,
    r.CertificationScore,
    r.YearsExperience,
    -- Rank within skill category
    ROW_NUMBER() OVER(PARTITION BY r.SkillCategory ORDER BY r.CertificationScore DESC) AS CategoryRank,
    -- Overall ranking across all categories
    ROW_NUMBER() OVER(ORDER BY r.CertificationScore DESC) AS OverallRank,
    -- Quartile within category
    NTILE(2) OVER(PARTITION BY r.SkillCategory ORDER BY r.CertificationScore DESC) AS CategoryQuartile,
    -- Overall quartile
    NTILE(4) OVER(ORDER BY r.CertificationScore DESC) AS OverallQuartile
FROM HR.EmployeeRankings r
ORDER BY r.SkillCategory, r.CertificationScore DESC;
/* Output example:
EmployeeID  SkillCategory  SkillLevel  CertificationScore  YearsExperience  CategoryRank  OverallRank  CategoryQuartile  OverallQuartile
2          Management     4           90.5               4                1            3            1                1
4          Management     4           90.5               3                2            4            1                1
1          Management     3           88.0               2                3            5            2                2
3          Management     2           75.0               1                4            8            2                4
*/