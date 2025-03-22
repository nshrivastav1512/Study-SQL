-- =============================================
-- SQL Server JSON SUPPORT Guide
-- =============================================

/*
This guide demonstrates SQL Server's JSON support features using HR scenarios:
- Storing employee skills and certifications
- Managing performance reviews
- Handling flexible document structures
- JSON querying and modification
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: JSON DATA STORAGE
-- =============================================

-- 1. Create tables with JSON columns
IF OBJECT_ID('HR.EmployeeSkills', 'U') IS NOT NULL
    DROP TABLE HR.EmployeeSkills;

CREATE TABLE HR.EmployeeSkills (
    EmployeeID INT PRIMARY KEY,
    Skills NVARCHAR(MAX) CHECK (ISJSON(Skills) = 1),
    LastUpdated DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_EmployeeSkills_Employees 
        FOREIGN KEY (EmployeeID) REFERENCES HR.Employees(EmployeeID)
);

-- Sample JSON data for employee skills
INSERT INTO HR.EmployeeSkills (EmployeeID, Skills)
VALUES 
(1, '{
    "technicalSkills": [
        {
            "category": "Programming",
            "skills": ["Python", "SQL", "Java"],
            "proficiencyLevel": "Expert"
        },
        {
            "category": "Database",
            "skills": ["SQL Server", "MongoDB"],
            "proficiencyLevel": "Advanced"
        }
    ],
    "softSkills": ["Leadership", "Communication", "Problem Solving"],
    "certifications": [
        {
            "name": "Microsoft Certified: Azure Developer Associate",
            "issueDate": "2023-01-15",
            "expiryDate": "2025-01-15",
            "credentialNumber": "MS-123456"
        }
    ]
}');

-- =============================================
-- PART 2: QUERYING JSON DATA
-- =============================================

-- 1. Basic JSON property access
SELECT 
    e.FirstName + ' ' + e.LastName AS EmployeeName,
    JSON_VALUE(es.Skills, '$.technicalSkills[0].category') AS PrimarySkillCategory,
    JSON_VALUE(es.Skills, '$.technicalSkills[0].proficiencyLevel') AS ProficiencyLevel
FROM HR.Employees e
JOIN HR.EmployeeSkills es ON e.EmployeeID = es.EmployeeID;

-- 2. Working with JSON arrays
SELECT 
    e.FirstName + ' ' + e.LastName AS EmployeeName,
    s.value AS SoftSkill
FROM HR.Employees e
JOIN HR.EmployeeSkills es ON e.EmployeeID = es.EmployeeID
CROSS APPLY OPENJSON(es.Skills, '$.softSkills') s;

-- 3. Complex JSON querying
SELECT 
    e.FirstName + ' ' + e.LastName AS EmployeeName,
    c.*
FROM HR.Employees e
JOIN HR.EmployeeSkills es ON e.EmployeeID = es.EmployeeID
CROSS APPLY OPENJSON(es.Skills, '$.certifications')
WITH (
    CertificationName NVARCHAR(200) '$.name',
    IssueDate DATE '$.issueDate',
    ExpiryDate DATE '$.expiryDate',
    CredentialNumber NVARCHAR(50) '$.credentialNumber'
) c;

-- =============================================
-- PART 3: MODIFYING JSON DATA
-- =============================================

-- 1. Adding new skills
CREATE OR ALTER PROCEDURE HR.AddEmployeeSkill
    @EmployeeID INT,
    @SkillCategory NVARCHAR(50),
    @SkillName NVARCHAR(100),
    @ProficiencyLevel NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentSkills NVARCHAR(MAX);
    DECLARE @NewSkill NVARCHAR(MAX);
    
    -- Get current skills
    SELECT @CurrentSkills = Skills
    FROM HR.EmployeeSkills
    WHERE EmployeeID = @EmployeeID;
    
    -- Create new skill JSON
    SET @NewSkill = JSON_MODIFY(@CurrentSkills,
        'append $.technicalSkills',
        JSON_QUERY('{
            "category": "' + @SkillCategory + '",
            "skills": ["' + @SkillName + '"],
            "proficiencyLevel": "' + @ProficiencyLevel + '"
        }'));
    
    -- Update skills
    UPDATE HR.EmployeeSkills
    SET Skills = @NewSkill,
        LastUpdated = GETDATE()
    WHERE EmployeeID = @EmployeeID;
END;

-- 2. Updating certification status
CREATE OR ALTER PROCEDURE HR.UpdateCertificationStatus
    @EmployeeID INT,
    @CertificationName NVARCHAR(200),
    @NewExpiryDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentSkills NVARCHAR(MAX);
    DECLARE @CertIndex INT;
    
    -- Get current skills
    SELECT @CurrentSkills = Skills
    FROM HR.EmployeeSkills
    WHERE EmployeeID = @EmployeeID;
    
    -- Find certification index
    SELECT @CertIndex = [key]
    FROM OPENJSON(@CurrentSkills, '$.certifications')
    WHERE JSON_VALUE([value], '$.name') = @CertificationName;
    
    -- Update expiry date
    IF @CertIndex IS NOT NULL
    BEGIN
        SET @CurrentSkills = JSON_MODIFY(@CurrentSkills,
            '$.certifications[' + CAST(@CertIndex AS VARCHAR) + '].expiryDate',
            CONVERT(VARCHAR, @NewExpiryDate, 23));
        
        UPDATE HR.EmployeeSkills
        SET Skills = @CurrentSkills,
            LastUpdated = GETDATE()
        WHERE EmployeeID = @EmployeeID;
    END;
END;

-- =============================================
-- PART 4: JSON PERFORMANCE OPTIMIZATION
-- =============================================

-- 1. Create computed columns for frequently accessed JSON properties
ALTER TABLE HR.EmployeeSkills
ADD 
    PrimarySkillCategory AS JSON_VALUE(Skills, '$.technicalSkills[0].category') PERSISTED,
    CertificationCount AS (
        SELECT COUNT(*)
        FROM OPENJSON(Skills, '$.certifications')
    ) PERSISTED;

-- Create index on computed columns
CREATE INDEX IX_EmployeeSkills_PrimaryCategory 
    ON HR.EmployeeSkills(PrimarySkillCategory);

CREATE INDEX IX_EmployeeSkills_CertCount 
    ON HR.EmployeeSkills(CertificationCount);

-- 2. Optimize JSON queries
CREATE OR ALTER PROCEDURE HR.GetEmployeesBySkill
    @SkillName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Use EXISTS for better performance
    SELECT 
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        d.DepartmentName,
        JSON_VALUE(es.Skills, '$.technicalSkills[0].proficiencyLevel') AS ProficiencyLevel
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    JOIN HR.EmployeeSkills es ON e.EmployeeID = es.EmployeeID
    WHERE EXISTS (
        SELECT 1
        FROM OPENJSON(es.Skills, '$.technicalSkills')
        WITH (Skills NVARCHAR(MAX) '$.skills' AS JSON)
        WHERE EXISTS (
            SELECT 1
            FROM OPENJSON(Skills)
            WHERE [value] = @SkillName
        )
    );
END;

-- =============================================
-- PART 5: REPORTING AND ANALYTICS
-- =============================================

-- 1. Skill gap analysis
CREATE OR ALTER PROCEDURE HR.AnalyzeSkillGaps
    @DepartmentID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    WITH RequiredSkills AS (
        SELECT DISTINCT
            s.[value] AS SkillName
        FROM HR.DepartmentRequirements dr
        CROSS APPLY OPENJSON(dr.RequiredSkills, '$.skills') s
        WHERE @DepartmentID IS NULL OR dr.DepartmentID = @DepartmentID
    ),
    EmployeeSkills AS (
        SELECT 
            e.DepartmentID,
            d.DepartmentName,
            s.[value] AS SkillName,
            COUNT(*) AS EmployeeCount
        FROM HR.Employees e
        JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
        JOIN HR.EmployeeSkills es ON e.EmployeeID = es.EmployeeID
        CROSS APPLY OPENJSON(es.Skills, '$.technicalSkills')
        WITH (Skills NVARCHAR(MAX) '$.skills' AS JSON) ts
        CROSS APPLY OPENJSON(ts.Skills) s
        WHERE @DepartmentID IS NULL OR e.DepartmentID = @DepartmentID
        GROUP BY e.DepartmentID, d.DepartmentName, s.[value]
    )
    SELECT 
        d.DepartmentName,
        rs.SkillName AS RequiredSkill,
        ISNULL(es.EmployeeCount, 0) AS EmployeesWithSkill,
        CASE 
            WHEN es.EmployeeCount IS NULL THEN 'Critical Gap'
            WHEN es.EmployeeCount < 2 THEN 'Potential Risk'
            ELSE 'Adequate Coverage'
        END AS GapStatus
    FROM RequiredSkills rs
    CROSS JOIN HR.Departments d
    LEFT JOIN EmployeeSkills es 
        ON d.DepartmentID = es.DepartmentID 
        AND rs.SkillName = es.SkillName
    WHERE @DepartmentID IS NULL OR d.DepartmentID = @DepartmentID
    ORDER BY 
        d.DepartmentName,
        CASE 
            WHEN es.EmployeeCount IS NULL THEN 1
            WHEN es.EmployeeCount < 2 THEN 2
            ELSE 3
        END;
END;

-- 2. Certification expiry monitoring
CREATE OR ALTER PROCEDURE HR.MonitorCertificationExpiry
    @DaysToExpiry INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        d.DepartmentName,
        c.CertificationName,
        c.ExpiryDate,
        DATEDIFF(DAY, GETDATE(), c.ExpiryDate) AS DaysUntilExpiry,
        CASE 
            WHEN c.ExpiryDate <= GETDATE() THEN 'Expired'
            WHEN DATEDIFF(DAY, GETDATE(), c.ExpiryDate) <= 30 THEN 'Critical'
            WHEN DATEDIFF(DAY, GETDATE(), c.ExpiryDate) <= 60 THEN 'Warning'
            ELSE 'OK'
        END AS Status
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    JOIN HR.EmployeeSkills es ON e.EmployeeID = es.EmployeeID
    CROSS APPLY OPENJSON(es.Skills, '$.certifications')
    WITH (
        CertificationName NVARCHAR(200) '$.name',
        ExpiryDate DATE '$.expiryDate'
    ) c
    WHERE 
        c.ExpiryDate IS NOT NULL
        AND DATEDIFF(DAY, GETDATE(), c.ExpiryDate) <= @DaysToExpiry
    ORDER BY 
        c.ExpiryDate,
        d.DepartmentName,
        e.LastName,
        e.FirstName;
END;