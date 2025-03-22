-- =============================================
-- SQL Server FULL-TEXT SEARCH Guide
-- =============================================

/*
This guide demonstrates the use of Full-Text Search in SQL Server for HR scenarios:
- Searching employee resumes and documents
- Finding specific skills and qualifications
- Document classification and categorization
- Semantic search capabilities
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: SETTING UP FULL-TEXT SEARCH
-- =============================================

-- 1. Create a Full-Text Catalog
IF NOT EXISTS (SELECT 1 FROM sys.fulltext_catalogs WHERE name = 'HRDocumentsCatalog')
BEGIN
    CREATE FULLTEXT CATALOG HRDocumentsCatalog
    WITH ACCENT_SENSITIVITY = ON
    AS DEFAULT;
END

-- 2. Create tables for storing documents
IF OBJECT_ID('HR.EmployeeResumes', 'U') IS NOT NULL
    DROP TABLE HR.EmployeeResumes;

CREATE TABLE HR.EmployeeResumes (
    ResumeID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    ResumeContent NVARCHAR(MAX),
    SkillsSummary NVARCHAR(MAX),
    Education NVARCHAR(MAX),
    WorkExperience NVARCHAR(MAX),
    LastUpdated DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_EmployeeResumes_Employees
        FOREIGN KEY (EmployeeID) REFERENCES HR.Employees(EmployeeID)
);

-- 3. Create Full-Text Index
CREATE FULLTEXT INDEX ON HR.EmployeeResumes
(
    ResumeContent,
    SkillsSummary,
    Education,
    WorkExperience
)
KEY INDEX PK__Employee__EE2E4F7A9F8D4A57
ON HRDocumentsCatalog
WITH CHANGE_TRACKING AUTO;

-- =============================================
-- PART 2: BASIC FULL-TEXT SEARCH
-- =============================================

-- 1. Simple Contains Search
CREATE OR ALTER PROCEDURE HR.SearchResumes
    @SearchTerm NVARCHAR(100)
AS
BEGIN
    SELECT 
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        er.ResumeContent,
        er.SkillsSummary,
        er.LastUpdated
    FROM HR.EmployeeResumes er
    JOIN HR.Employees e ON er.EmployeeID = e.EmployeeID
    WHERE CONTAINS(er.ResumeContent, @SearchTerm)
        OR CONTAINS(er.SkillsSummary, @SearchTerm);
END;

-- 2. Using CONTAINSTABLE for Relevance Ranking
CREATE OR ALTER PROCEDURE HR.SearchResumesRanked
    @SearchTerm NVARCHAR(100)
AS
BEGIN
    SELECT 
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        er.ResumeContent,
        er.SkillsSummary,
        KEY_TBL.RANK AS SearchRelevance
    FROM HR.EmployeeResumes er
    JOIN HR.Employees e ON er.EmployeeID = e.EmployeeID
    INNER JOIN CONTAINSTABLE(HR.EmployeeResumes, 
        (ResumeContent, SkillsSummary), 
        @SearchTerm
    ) AS KEY_TBL
    ON er.ResumeID = KEY_TBL.[KEY]
    ORDER BY KEY_TBL.RANK DESC;
END;

-- =============================================
-- PART 3: ADVANCED SEARCH TECHNIQUES
-- =============================================

-- 1. Proximity Search
CREATE OR ALTER PROCEDURE HR.SearchResumesByProximity
    @Term1 NVARCHAR(50),
    @Term2 NVARCHAR(50),
    @MaxDistance INT = 10
AS
BEGIN
    SELECT 
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        er.ResumeContent,
        er.SkillsSummary
    FROM HR.EmployeeResumes er
    JOIN HR.Employees e ON er.EmployeeID = e.EmployeeID
    WHERE CONTAINS(er.ResumeContent, 
        'NEAR(("' + @Term1 + '", "' + @Term2 + '"), ' + 
        CAST(@MaxDistance AS VARCHAR(10)) + ')');
END;

-- 2. Thesaurus-Based Search
CREATE OR ALTER PROCEDURE HR.SearchResumesBySkillCategory
    @SkillCategory NVARCHAR(50)
AS
BEGIN
    -- Using thesaurus for skill variations
    -- Example: 'programming' matches 'coding', 'development', 'software engineering'
    SELECT 
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        er.SkillsSummary,
        KEY_TBL.RANK AS Relevance
    FROM HR.EmployeeResumes er
    JOIN HR.Employees e ON er.EmployeeID = e.EmployeeID
    INNER JOIN CONTAINSTABLE(HR.EmployeeResumes, 
        SkillsSummary, 
        @SkillCategory,
        LANGUAGE 1033 -- Using English thesaurus
    ) AS KEY_TBL
    ON er.ResumeID = KEY_TBL.[KEY]
    ORDER BY KEY_TBL.RANK DESC;
END;

-- =============================================
-- PART 4: SEMANTIC SEARCH
-- =============================================

-- 1. Find Similar Resumes
CREATE OR ALTER PROCEDURE HR.FindSimilarResumes
    @ResumeID INT
AS
BEGIN
    SELECT 
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        er.SkillsSummary,
        KEY_TBL.RANK AS SimilarityScore
    FROM HR.EmployeeResumes er
    JOIN HR.Employees e ON er.EmployeeID = e.EmployeeID
    INNER JOIN SEMANTICSIMILARITYTABLE(
        HR.EmployeeResumes,
        ResumeContent,
        (SELECT ResumeContent 
         FROM HR.EmployeeResumes 
         WHERE ResumeID = @ResumeID)
    ) AS KEY_TBL
    ON er.ResumeID = KEY_TBL.[KEY]
    WHERE er.ResumeID <> @ResumeID
    ORDER BY KEY_TBL.RANK DESC;
END;

-- 2. Extract Key Phrases
CREATE OR ALTER PROCEDURE HR.ExtractKeyPhrases
    @ResumeID INT
AS
BEGIN
    SELECT 
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        KEY_TBL.KeyPhrase,
        KEY_TBL.Score AS Relevance
    FROM HR.EmployeeResumes er
    JOIN HR.Employees e ON er.EmployeeID = e.EmployeeID
    CROSS APPLY SEMANTICKEYPHRASETABLE(
        HR.EmployeeResumes,
        ResumeContent,
        er.ResumeID
    ) AS KEY_TBL
    WHERE er.ResumeID = @ResumeID
    ORDER BY KEY_TBL.Score DESC;
END;

-- =============================================
-- PART 5: MAINTENANCE AND OPTIMIZATION
-- =============================================

-- 1. Rebuild Full-Text Index
CREATE OR ALTER PROCEDURE HR.RebuildFullTextIndex
AS
BEGIN
    ALTER FULLTEXT INDEX ON HR.EmployeeResumes
    START FULL POPULATION;
END;

-- 2. Monitor Full-Text Search Performance
CREATE OR ALTER PROCEDURE HR.MonitorFullTextPerformance
AS
BEGIN
    SELECT 
        c.name AS CatalogName,
        OBJECT_SCHEMA_NAME(i.object_id) + '.' + 
        OBJECT_NAME(i.object_id) AS TableName,
        i.is_enabled,
        i.change_tracking_state_desc,
        i.crawl_type_desc,
        i.crawl_start_date,
        i.crawl_end_date,
        i.incremental_timestamp,
        i.item_count
    FROM sys.fulltext_indexes i
    JOIN sys.fulltext_catalogs c 
        ON i.fulltext_catalog_id = c.fulltext_catalog_id
    WHERE OBJECT_NAME(i.object_id) = 'EmployeeResumes';
END;

-- =============================================
-- PART 6: SAMPLE DATA AND TESTING
-- =============================================

-- 1. Insert Sample Resume Data
INSERT INTO HR.EmployeeResumes (
    EmployeeID,
    ResumeContent,
    SkillsSummary,
    Education,
    WorkExperience
)
VALUES
(1, '
Senior Software Engineer with 10+ years of experience in developing enterprise applications.
Expertise in SQL Server, .NET, and Azure cloud services.
Strong background in database design and optimization.
',
'SQL Server, T-SQL, .NET Framework, C#, Azure, Database Design, Performance Tuning',
'Master of Computer Science, Stanford University
Bachelor of Engineering, MIT',
'Senior Software Engineer, Microsoft (2018-Present)
Database Developer, Oracle (2013-2018)
Junior Developer, IBM (2010-2013)'
);

-- 2. Test Full-Text Search Features
EXEC HR.SearchResumes 'SQL Server';
EXEC HR.SearchResumesRanked 'database AND optimization';
EXEC HR.SearchResumesByProximity 'database', 'optimization', 5;
EXEC HR.SearchResumesBySkillCategory 'programming';
EXEC HR.FindSimilarResumes 1;
EXEC HR.ExtractKeyPhrases 1;