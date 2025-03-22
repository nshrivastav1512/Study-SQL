-- =============================================
-- SQL Server FULL-TEXT INDEXES Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating a Full-Text Catalog
-- A full-text catalog is a container for full-text indexes
CREATE FULLTEXT CATALOG DocumentCatalog
WITH ACCENT_SENSITIVITY = OFF
AS DEFAULT;
GO

-- Create another catalog with different settings
CREATE FULLTEXT CATALOG ResumeCatalog
WITH ACCENT_SENSITIVITY = ON;
GO

-- 2. Creating Tables with Columns for Full-Text Search
-- Create a table to store employee documents
CREATE TABLE HR.EmployeeDocuments
(
    DocumentID INT PRIMARY KEY IDENTITY(1,1),
    EmployeeID INT NOT NULL,
    DocumentTitle NVARCHAR(100) NOT NULL,
    DocumentType NVARCHAR(50) NOT NULL,
    DocumentContent NVARCHAR(MAX) NOT NULL,
    DocumentSummary NVARCHAR(500) NULL,
    UploadDate DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_EmployeeDocuments_Employees FOREIGN KEY (EmployeeID) 
        REFERENCES HR.Employees(EmployeeID)
);
GO

-- Create a table to store employee resumes
CREATE TABLE HR.EmployeeResumes
(
    ResumeID INT PRIMARY KEY IDENTITY(1,1),
    EmployeeID INT NOT NULL,
    ResumeTitle NVARCHAR(100) NOT NULL,
    ResumeContent NVARCHAR(MAX) NOT NULL,
    Skills NVARCHAR(MAX) NULL,
    Education NVARCHAR(MAX) NULL,
    Experience NVARCHAR(MAX) NULL,
    LastUpdated DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_EmployeeResumes_Employees FOREIGN KEY (EmployeeID) 
        REFERENCES HR.Employees(EmployeeID)
);
GO

-- 3. Creating a Full-Text Index
-- Create a unique index (required for full-text indexing)
CREATE UNIQUE INDEX UI_EmployeeDocuments_DocumentID 
    ON HR.EmployeeDocuments(DocumentID);
GO

-- Create a full-text index on the EmployeeDocuments table
CREATE FULLTEXT INDEX ON HR.EmployeeDocuments
(
    DocumentTitle LANGUAGE 1033,                  -- English (United States)
    DocumentContent LANGUAGE 1033,
    DocumentSummary LANGUAGE 1033
)
KEY INDEX UI_EmployeeDocuments_DocumentID
ON DocumentCatalog
WITH CHANGE_TRACKING AUTO;
GO

-- Create a unique index for the resumes table
CREATE UNIQUE INDEX UI_EmployeeResumes_ResumeID 
    ON HR.EmployeeResumes(ResumeID);
GO

-- Create a full-text index on the EmployeeResumes table
CREATE FULLTEXT INDEX ON HR.EmployeeResumes
(
    ResumeTitle LANGUAGE 1033,
    ResumeContent LANGUAGE 1033,
    Skills LANGUAGE 1033,
    Education LANGUAGE 1033,
    Experience LANGUAGE 1033
)
KEY INDEX UI_EmployeeResumes_ResumeID
ON ResumeCatalog
WITH CHANGE_TRACKING AUTO;
GO

-- 4. Inserting Sample Data
-- Insert sample documents
INSERT INTO HR.EmployeeDocuments (EmployeeID, DocumentTitle, DocumentType, DocumentContent, DocumentSummary)
VALUES
(1001, 'Performance Review 2022', 'Review', 
 'John Doe has consistently demonstrated excellent technical skills and teamwork. His project management abilities have improved significantly over the past year. He successfully led the database migration project, completing it ahead of schedule and under budget. Areas for improvement include delegation and work-life balance.',
 'Annual performance review highlighting strengths in technical skills and project management, with recommendations for improvement in delegation.'),
 
(1002, 'Training Certificate', 'Certificate', 
 'This certificate confirms that Jane Smith has successfully completed the Advanced SQL Server Administration course, covering performance tuning, high availability, disaster recovery, and security best practices.',
 'SQL Server Administration training completion certificate'),
 
(1003, 'Project Proposal', 'Proposal', 
 'Proposal for implementing a new HR analytics dashboard using Power BI. The project aims to provide real-time insights into employee performance, attendance patterns, and skill gap analysis. Estimated timeline is 3 months with a budget of $45,000.',
 'Proposal for HR analytics dashboard implementation project');
GO

-- Insert sample resumes
INSERT INTO HR.EmployeeResumes (EmployeeID, ResumeTitle, ResumeContent, Skills, Education, Experience)
VALUES
(1001, 'Senior Database Developer', 
 'Experienced database developer with 8 years of experience in designing, implementing, and optimizing database solutions. Proven track record of improving database performance and implementing data security measures.',
 'SQL Server, T-SQL, Performance Tuning, Database Design, ETL, SSIS, SSRS, Azure SQL, High Availability, Disaster Recovery',
 'Master of Science in Computer Science, University of Technology, 2015\nBachelor of Science in Information Systems, State University, 2013',
 'Senior Database Developer, HRSystem, 2020-Present\nDatabase Developer, Tech Solutions Inc., 2017-2020\nJunior Database Administrator, DataCorp, 2015-2017'),
 
(1002, 'Data Analyst Resume', 
 'Detail-oriented data analyst with strong analytical skills and experience in transforming complex datasets into actionable business insights. Proficient in SQL, Power BI, and statistical analysis.',
 'SQL, Data Analysis, Power BI, Excel, Statistical Analysis, Python, R, Data Visualization, Machine Learning Basics',
 'Bachelor of Science in Statistics, Analytics University, 2018',
 'Data Analyst, HRSystem, 2021-Present\nJunior Data Analyst, Insight Analytics, 2018-2021');
GO

-- 5. Basic Full-Text Search Queries
-- Simple CONTAINS search
SELECT 
    DocumentID,
    EmployeeID,
    DocumentTitle,
    DocumentType
FROM HR.EmployeeDocuments
WHERE CONTAINS(DocumentContent, 'project');
GO

-- Using FREETEXT for more natural language search
SELECT 
    DocumentID,
    EmployeeID,
    DocumentTitle,
    DocumentType
FROM HR.EmployeeDocuments
WHERE FREETEXT(DocumentContent, 'technical skills improvement');
GO

-- 6. Advanced Full-Text Search Techniques
-- Using Boolean operators
SELECT 
    ResumeID,
    EmployeeID,
    ResumeTitle
FROM HR.EmployeeResumes
WHERE CONTAINS(Skills, 'SQL AND (Python OR R)');
GO

-- Using proximity search
SELECT 
    DocumentID,
    EmployeeID,
    DocumentTitle
FROM HR.EmployeeDocuments
WHERE CONTAINS(DocumentContent, 'NEAR((performance, improvement), 10)');
GO

-- Using wildcards
SELECT 
    ResumeID,
    EmployeeID,
    ResumeTitle
FROM HR.EmployeeResumes
WHERE CONTAINS(ResumeContent, '"data*"');
GO

-- 7. Searching Multiple Columns
-- Search across multiple columns
SELECT 
    ResumeID,
    EmployeeID,
    ResumeTitle
FROM HR.EmployeeResumes
WHERE CONTAINS((ResumeContent, Skills, Experience), 'SQL Server');
GO

-- 8. Ranking Search Results
-- Use CONTAINSTABLE to get rank
SELECT 
    d.DocumentID,
    d.EmployeeID,
    d.DocumentTitle,
    d.DocumentType,
    ft.RANK
FROM HR.EmployeeDocuments d
INNER JOIN CONTAINSTABLE(HR.EmployeeDocuments, DocumentContent, 'project AND management') AS ft
    ON d.DocumentID = ft.[KEY]
ORDER BY ft.RANK DESC;
GO

-- Use FREETEXTTABLE for natural language search with ranking
SELECT 
    r.ResumeID,
    r.EmployeeID,
    r.ResumeTitle,
    ft.RANK
FROM HR.EmployeeResumes r
INNER JOIN FREETEXTTABLE(HR.EmployeeResumes, (ResumeContent, Skills), 'database experience') AS ft
    ON r.ResumeID = ft.[KEY]
ORDER BY ft.RANK DESC;
GO

-- 9. Altering Full-Text Indexes
-- Add a column to an existing full-text index
ALTER FULLTEXT INDEX ON HR.EmployeeDocuments
ADD (DocumentType LANGUAGE 1033);
GO

-- Remove a column from a full-text index
ALTER FULLTEXT INDEX ON HR.EmployeeDocuments
DROP (DocumentSummary);
GO

-- Change the catalog for a full-text index
ALTER FULLTEXT INDEX ON HR.EmployeeResumes
SET CATALOG DocumentCatalog;
GO

-- Change the change tracking option
ALTER FULLTEXT INDEX ON HR.EmployeeDocuments
SET CHANGE_TRACKING MANUAL;
GO

-- 10. Managing Full-Text Catalogs and Indexes
-- Start a full population
ALTER FULLTEXT INDEX ON HR.EmployeeDocuments
START FULL POPULATION;
GO

-- Start an incremental population
ALTER FULLTEXT INDEX ON HR.EmployeeResumes
START INCREMENTAL POPULATION;
GO

-- Stop a population
ALTER FULLTEXT INDEX ON HR.EmployeeDocuments
STOP POPULATION;
GO

-- Rebuild a catalog
ALTER FULLTEXT CATALOG DocumentCatalog
REBUILD;
GO

-- 11. Dropping Full-Text Objects
-- Drop a full-text index
DROP FULLTEXT INDEX ON HR.EmployeeDocuments;
GO

-- Drop a full-text catalog
DROP FULLTEXT CATALOG ResumeCatalog;
GO

-- 12. Querying Full-Text Metadata
-- List all full-text catalogs
SELECT 
    name AS CatalogName,
    fulltext_catalog_id,
    principal_id,
    is_default,
    is_accent_sensitivity_on,
    path
FROM sys.fulltext_catalogs;
GO

-- List all full-text indexes
SELECT 
    OBJECT_SCHEMA_NAME(object_id) + '.' + OBJECT_NAME(object_id) AS TableName,
    fulltext_catalog_id,
    is_enabled,
    change_tracking_state_desc,
    has_crawl_completed,
    crawl_type_desc,
    crawl_start_date,
    crawl_end_date
FROM sys.fulltext_indexes;
GO

-- List indexed columns
SELECT 
    OBJECT_SCHEMA_NAME(c.object_id) + '.' + OBJECT_NAME(c.object_id) AS TableName,
    COL_NAME(c.object_id, c.column_id) AS ColumnName,
    language_id,
    statistical_semantics
FROM sys.fulltext_index_columns c
JOIN sys.fulltext_indexes i ON c.object_id = i.object_id
ORDER BY TableName, ColumnName;
GO

-- 13. Full-Text Search with Thesaurus
-- The thesaurus allows you to define synonyms for search terms
-- Note: Thesaurus files are XML files stored on the server
-- Example of a thesaurus entry (for illustration only):
/*
<XML>
  <thesaurus xmlns="http://schemas.microsoft.com/ts/2008/thesaurus">
    <diacritics_sensitive>false</diacritics_sensitive>
    <expansion>
      <sub>database</sub>
      <sub>DB</sub>
      <sub>RDBMS</sub>
    </expansion>
    <expansion>
      <sub>developer</sub>
      <sub>programmer</sub>
      <sub>coder</sub>
    </expansion>
  </thesaurus>
</XML>
*/

-- After configuring the thesaurus, you can search using synonyms
-- For example, searching for 'database' would also find 'DB' and 'RDBMS'

-- 14. Full-Text Search with Stopwords
-- Stopwords are common words that are ignored during indexing
-- SQL Server has default stopword lists, but you can create custom ones

-- Create a custom stopword list
CREATE FULLTEXT STOPLIST CustomStoplist;
GO

-- Add words to the stoplist
ALTER FULLTEXT STOPLIST CustomStoplist ADD 'the' LANGUAGE 1033;
ALTER FULLTEXT STOPLIST CustomStoplist ADD 'and' LANGUAGE 1033;
ALTER FULLTEXT STOPLIST CustomStoplist ADD 'or' LANGUAGE 1033;
GO

-- Apply the stoplist to a full-text index
CREATE FULLTEXT INDEX ON HR.EmployeeDocuments
(
    DocumentTitle LANGUAGE 1033,
    DocumentContent LANGUAGE 1033,
    DocumentType LANGUAGE 1033
)
KEY INDEX UI_EmployeeDocuments_DocumentID
ON DocumentCatalog
WITH STOPLIST = CustomStoplist,
     CHANGE_TRACKING AUTO;
GO

-- 15. Cleanup
-- Drop all objects created in this script
DROP TABLE IF EXISTS HR.EmployeeDocuments;
DROP TABLE IF EXISTS HR.EmployeeResumes;
DROP FULLTEXT STOPLIST IF EXISTS CustomStoplist;
DROP FULLTEXT CATALOG IF EXISTS DocumentCatalog;
DROP FULLTEXT CATALOG IF EXISTS ResumeCatalog;
GO