/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\120_FULL_TEXT_SEARCH_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Full-Text Search Functions
    using the HRSystem database. These functions enable powerful text search
    capabilities across document content and text data.

    Full-Text Search Functions covered:
    1. CONTAINS() - Searches for precise or fuzzy matches
    2. FREETEXT() - Searches using meaning rather than exact matches
    3. CONTAINSTABLE() - Returns relevance ranking
    4. FREETEXTTABLE() - Returns relevance ranking for meaning-based searches
    5. RANK() - Gets relevance ranking score
    6. PROXIMITY_TERM() - Searches for terms in proximity
*/

USE HRSystem;
GO

-- Create a catalog for full-text search if not exists
IF NOT EXISTS (SELECT * FROM sys.fulltext_catalogs WHERE name = 'HRSystemCatalog')
BEGIN
    CREATE FULLTEXT CATALOG HRSystemCatalog AS DEFAULT;
END

-- Create tables for storing documents and policies
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[Documents]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.Documents (
        DocumentID INT PRIMARY KEY IDENTITY(1,1),
        Title NVARCHAR(100),
        Content NVARCHAR(MAX),
        DocumentType NVARCHAR(50),
        CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
        LastModified DATETIME2,
        Keywords NVARCHAR(MAX)
    );

    -- Create full-text index
    CREATE FULLTEXT INDEX ON HR.Documents
    (
        Content,
        Keywords Language 1033 -- English
    )
    KEY INDEX PK__Document__CC03BBBB
    ON HRSystemCatalog
    WITH CHANGE_TRACKING AUTO;

    -- Insert sample documents
    INSERT INTO HR.Documents (Title, Content, DocumentType, Keywords)
    VALUES
    ('Employee Handbook', 
     'This comprehensive guide outlines company policies, benefits, and procedures. Employees must follow all safety guidelines and professional conduct standards.',
     'Policy',
     'policies, procedures, conduct, safety, benefits'),
    ('Safety Protocol',
     'Workplace safety procedures include emergency protocols, equipment handling, and hazard reporting. All incidents must be reported immediately.',
     'Protocol',
     'safety, emergency, hazard, incident, reporting'),
    ('Benefits Guide',
     'Employee benefits include health insurance, retirement plans, and paid time off. Contact HR for enrollment procedures.',
     'Guide',
     'benefits, insurance, retirement, PTO'),
    ('Training Manual',
     'New employee training covers company software, security protocols, and department procedures. Regular training updates are mandatory.',
     'Manual',
     'training, software, security, procedures'),
    ('HR Policies',
     'Human Resources policies cover recruitment, performance reviews, compensation, and workplace conduct. Updates are communicated via email.',
     'Policy',
     'HR, recruitment, performance, compensation');
END

-- Create a search log table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[SearchLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.SearchLog (
        LogID INT PRIMARY KEY IDENTITY(1,1),
        SearchType NVARCHAR(50),
        SearchTerm NVARCHAR(MAX),
        ResultCount INT,
        SearchDate DATETIME2 DEFAULT SYSDATETIME(),
        SearchedBy NVARCHAR(100)
    );
END

-- 1. CONTAINS - Search for specific terms
DECLARE @SearchTerm1 NVARCHAR(100) = 'safety AND protocols';

SELECT 
    DocumentID,
    Title,
    DocumentType,
    CreatedDate
FROM HR.Documents
WHERE CONTAINS(Content, @SearchTerm1);

-- Log the search
INSERT INTO HR.SearchLog (SearchType, SearchTerm, ResultCount, SearchedBy)
SELECT 
    'CONTAINS',
    @SearchTerm1,
    COUNT(*),
    SYSTEM_USER
FROM HR.Documents
WHERE CONTAINS(Content, @SearchTerm1);

-- 2. FREETEXT - Search using meaning
DECLARE @SearchTerm2 NVARCHAR(100) = 'employee benefits and insurance';

SELECT 
    DocumentID,
    Title,
    DocumentType
FROM HR.Documents
WHERE FREETEXT(Content, @SearchTerm2);

-- Log the search
INSERT INTO HR.SearchLog (SearchType, SearchTerm, ResultCount, SearchedBy)
SELECT 
    'FREETEXT',
    @SearchTerm2,
    COUNT(*),
    SYSTEM_USER
FROM HR.Documents
WHERE FREETEXT(Content, @SearchTerm2);

-- 3. CONTAINSTABLE - Get relevance ranking
SELECT 
    d.DocumentID,
    d.Title,
    d.DocumentType,
    KEY_TBL.RANK
FROM HR.Documents d
INNER JOIN CONTAINSTABLE(HR.Documents, Content, 'safety AND "emergency protocols"') AS KEY_TBL
ON d.DocumentID = KEY_TBL.[KEY]
ORDER BY KEY_TBL.RANK DESC;

-- 4. FREETEXTTABLE - Get relevance ranking for meaning-based search
SELECT 
    d.DocumentID,
    d.Title,
    d.DocumentType,
    KEY_TBL.RANK
FROM HR.Documents d
INNER JOIN FREETEXTTABLE(HR.Documents, Content, 'workplace policies and procedures') AS KEY_TBL
ON d.DocumentID = KEY_TBL.[KEY]
ORDER BY KEY_TBL.RANK DESC;

-- 5. Using RANK with multiple terms
SELECT 
    d.DocumentID,
    d.Title,
    KEY_TBL.RANK as SearchRelevance
FROM HR.Documents d
INNER JOIN CONTAINSTABLE(HR.Documents, (Content, Keywords), 
    'FORMSOF(INFLECTIONAL, training) OR 
     FORMSOF(INFLECTIONAL, safety) OR
     "company policies"'
) AS KEY_TBL
ON d.DocumentID = KEY_TBL.[KEY]
WHERE KEY_TBL.RANK > 5
ORDER BY KEY_TBL.RANK DESC;

-- 6. Proximity search using NEAR operator
SELECT 
    d.DocumentID,
    d.Title,
    d.Content,
    KEY_TBL.RANK
FROM HR.Documents d
INNER JOIN CONTAINSTABLE(HR.Documents, Content, 
    'NEAR((safety, emergency), 10)'
) AS KEY_TBL
ON d.DocumentID = KEY_TBL.[KEY]
ORDER BY KEY_TBL.RANK DESC;

-- Create a view for search analytics
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[HR].[SearchAnalytics]'))
BEGIN
    EXECUTE sp_executesql N'
    CREATE VIEW HR.SearchAnalytics
    AS
    SELECT 
        SearchType,
        SearchTerm,
        COUNT(*) as SearchCount,
        AVG(ResultCount) as AvgResults,
        MAX(SearchDate) as LastSearched,
        SearchedBy
    FROM HR.SearchLog
    GROUP BY SearchType, SearchTerm, SearchedBy;
    ';
END

-- Example of analyzing search patterns
SELECT 
    SearchType,
    SearchTerm,
    SearchCount,
    AvgResults,
    LastSearched,
    SearchedBy
FROM HR.SearchAnalytics
ORDER BY SearchCount DESC, AvgResults DESC;

-- Cleanup (optional)
-- DROP FULLTEXT INDEX ON HR.Documents;
-- DROP FULLTEXT CATALOG HRSystemCatalog;