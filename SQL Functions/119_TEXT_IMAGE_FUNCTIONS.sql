/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\119_TEXT_IMAGE_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Text and Image Functions
    (Deprecated but still supported) using the HRSystem database.
    These functions are used for handling large text and image data.

    Text and Image Functions covered:
    1. TEXTPTR() - Returns a pointer to a text, ntext, or image column
    2. TEXTVALID() - Validates a text pointer
    3. UPDATETEXT() - Updates text, ntext, or image data
    4. READTEXT() - Reads text, ntext, or image data
    5. WRITETEXT() - Writes text, ntext, or image data
*/

USE HRSystem;
GO

-- Create a sample table for demonstrating text and image functions
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[DocumentArchive]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.DocumentArchive (
        DocumentID INT PRIMARY KEY IDENTITY(1,1),
        Title NVARCHAR(100),
        Content TEXT,
        DocumentImage IMAGE,
        CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
        LastModified DATETIME2,
        ModifiedBy NVARCHAR(50)
    );

    -- Insert sample data
    INSERT INTO HR.DocumentArchive (Title, Content, ModifiedBy)
    VALUES 
    ('Employee Handbook', 'This is the complete employee handbook...', SYSTEM_USER),
    ('Safety Guidelines', 'Workplace safety guidelines and procedures...', SYSTEM_USER),
    ('HR Policies', 'Human Resources policies and procedures...', SYSTEM_USER);
END

-- Create a log table for text operations
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[TextOperationLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.TextOperationLog (
        LogID INT PRIMARY KEY IDENTITY(1,1),
        DocumentID INT,
        OperationType NVARCHAR(20),
        TextPointer VARBINARY(16),
        IsValid BIT,
        OperationTime DATETIME2 DEFAULT SYSDATETIME(),
        OperatedBy NVARCHAR(50)
    );
END

-- Example 1: Using TEXTPTR() to get text pointer
DECLARE @TextPtr VARBINARY(16);
SELECT @TextPtr = TEXTPTR(Content)
FROM HR.DocumentArchive
WHERE DocumentID = 1;

-- Log the text pointer operation
INSERT INTO HR.TextOperationLog 
(DocumentID, OperationType, TextPointer, IsValid, OperatedBy)
VALUES 
(1, 'GET_POINTER', @TextPtr, 1, SYSTEM_USER);

-- Example 2: Using TEXTVALID() to validate text pointer
DECLARE @IsValid BIT;
SELECT @IsValid = TEXTVALID('HR.DocumentArchive.Content', @TextPtr);

-- Log the validation result
INSERT INTO HR.TextOperationLog 
(DocumentID, OperationType, TextPointer, IsValid, OperatedBy)
VALUES 
(1, 'VALIDATE', @TextPtr, @IsValid, SYSTEM_USER);

-- Example 3: Using UPDATETEXT() to modify content
DECLARE @UpdatedText VARCHAR(100) = 'Updated section of the employee handbook...';

UPDATETEXT HR.DocumentArchive.Content @TextPtr 0 0 @UpdatedText;

-- Update last modified information
UPDATE HR.DocumentArchive
SET LastModified = SYSDATETIME(),
    ModifiedBy = SYSTEM_USER
WHERE DocumentID = 1;

-- Log the update operation
INSERT INTO HR.TextOperationLog 
(DocumentID, OperationType, TextPointer, IsValid, OperatedBy)
VALUES 
(1, 'UPDATE', @TextPtr, 1, SYSTEM_USER);

-- Example 4: Using READTEXT() to read content
DECLARE @ReadLength INT = 100; -- Read first 100 characters

READTEXT HR.DocumentArchive.Content @TextPtr 0 @ReadLength;

-- Log the read operation
INSERT INTO HR.TextOperationLog 
(DocumentID, OperationType, TextPointer, IsValid, OperatedBy)
VALUES 
(1, 'READ', @TextPtr, 1, SYSTEM_USER);

-- Example 5: Using WRITETEXT() to write new content
DECLARE @NewContent VARCHAR(200) = 'Completely new version of the employee handbook...';

WRITETEXT HR.DocumentArchive.Content @TextPtr @NewContent;

-- Update last modified information
UPDATE HR.DocumentArchive
SET LastModified = SYSDATETIME(),
    ModifiedBy = SYSTEM_USER
WHERE DocumentID = 1;

-- Log the write operation
INSERT INTO HR.TextOperationLog 
(DocumentID, OperationType, TextPointer, IsValid, OperatedBy)
VALUES 
(1, 'WRITE', @TextPtr, 1, SYSTEM_USER);

-- View the operation log
SELECT 
    l.LogID,
    d.Title AS DocumentTitle,
    l.OperationType,
    CASE 
        WHEN l.IsValid = 1 THEN 'Valid'
        ELSE 'Invalid'
    END AS PointerStatus,
    l.OperationTime,
    l.OperatedBy
FROM HR.TextOperationLog l
JOIN HR.DocumentArchive d ON l.DocumentID = d.DocumentID
ORDER BY l.LogID;

-- Create a view to analyze text operations
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[HR].[TextOperationAnalysis]'))
BEGIN
    EXECUTE sp_executesql N'
    CREATE VIEW HR.TextOperationAnalysis
    AS
    SELECT 
        d.Title,
        COUNT(l.LogID) AS TotalOperations,
        SUM(CASE WHEN l.OperationType = ''READ'' THEN 1 ELSE 0 END) AS ReadOperations,
        SUM(CASE WHEN l.OperationType IN (''UPDATE'', ''WRITE'') THEN 1 ELSE 0 END) AS WriteOperations,
        MAX(l.OperationTime) AS LastOperation,
        d.LastModified,
        d.ModifiedBy
    FROM HR.DocumentArchive d
    LEFT JOIN HR.TextOperationLog l ON d.DocumentID = l.DocumentID
    GROUP BY d.Title, d.LastModified, d.ModifiedBy;
    ';
END

-- Example of analyzing text operations
SELECT 
    Title,
    TotalOperations,
    ReadOperations,
    WriteOperations,
    LastOperation,
    LastModified,
    ModifiedBy
FROM HR.TextOperationAnalysis
ORDER BY TotalOperations DESC;

-- Note: These functions are deprecated
PRINT 'Note: Text and Image data types and their associated functions are deprecated.';
PRINT 'Microsoft recommends using VARCHAR(MAX), NVARCHAR(MAX), and VARBINARY(MAX) instead.';