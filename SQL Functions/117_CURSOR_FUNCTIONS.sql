/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\117_CURSOR_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Cursor Functions
    using the HRSystem database. These functions help in managing and
    monitoring cursor operations for row-by-row processing.

    Cursor Functions covered:
    1. @@CURSOR_ROWS - Returns number of rows in the last cursor
    2. CURSOR_STATUS() - Returns cursor status
    3. FETCH_STATUS() - Returns status of last fetch operation
*/

USE HRSystem;
GO

-- Create a sample employee performance table if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[EmployeePerformance]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.EmployeePerformance (
        EmployeeID INT PRIMARY KEY,
        LastReviewDate DATE,
        Performance NVARCHAR(20),
        Rating DECIMAL(3,2),
        Comments NVARCHAR(MAX)
    );

    -- Insert sample data
    INSERT INTO HR.EmployeePerformance (EmployeeID, LastReviewDate, Performance, Rating)
    VALUES
    (1, '2023-01-15', 'Excellent', 4.5),
    (2, '2023-02-20', 'Good', 3.8),
    (3, '2023-03-10', 'Average', 3.0),
    (4, '2023-04-05', 'Excellent', 4.7),
    (5, '2023-05-12', 'Below Average', 2.5);
END

-- Create a cursor log table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[CursorLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.CursorLog (
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        CursorName NVARCHAR(100),
        RowCount INT,
        CursorStatus INT,
        FetchStatus INT,
        LogTime DATETIME2 DEFAULT SYSDATETIME(),
        Operation NVARCHAR(50)
    );
END

-- Example 1: Using @@CURSOR_ROWS
DECLARE @CursorName NVARCHAR(100) = 'PerformanceReviewCursor';

-- Declare and open a cursor
DECLARE PerformanceReviewCursor CURSOR FOR
SELECT EmployeeID, Performance, Rating
FROM HR.EmployeePerformance
WHERE Rating >= 4.0;

OPEN PerformanceReviewCursor;

-- Log cursor information using @@CURSOR_ROWS
INSERT INTO HR.CursorLog (CursorName, RowCount, Operation)
VALUES (@CursorName, @@CURSOR_ROWS, 'Initial Count');

-- Example 2: Using CURSOR_STATUS()
DECLARE 
    @CursorStatus INT,
    @GlobalStatus INT,
    @VariableStatus INT;

-- Check different cursor status types
SET @GlobalStatus = CURSOR_STATUS('global', 'PerformanceReviewCursor');
SET @VariableStatus = CURSOR_STATUS('variable', 'PerformanceReviewCursor');

-- Log cursor status information
INSERT INTO HR.CursorLog (CursorName, CursorStatus, Operation)
VALUES 
    (@CursorName, @GlobalStatus, 'Global Status Check'),
    (@CursorName, @VariableStatus, 'Variable Status Check');

-- Example 3: Using FETCH_STATUS()
DECLARE 
    @EmployeeID INT,
    @Performance NVARCHAR(20),
    @Rating DECIMAL(3,2);

-- Fetch and process rows
WHILE 1 = 1
BEGIN
    FETCH NEXT FROM PerformanceReviewCursor 
    INTO @EmployeeID, @Performance, @Rating;

    -- Check FETCH_STATUS()
    IF FETCH_STATUS() <> 0
        BREAK;

    -- Log fetch operation
    INSERT INTO HR.CursorLog (CursorName, FetchStatus, Operation)
    VALUES (@CursorName, FETCH_STATUS(), 'Row Fetch');

    -- Process the fetched row (example operation)
    UPDATE HR.EmployeePerformance
    SET Comments = 'High performer - Reviewed by cursor operation'
    WHERE EmployeeID = @EmployeeID;
END

-- Clean up
CLOSE PerformanceReviewCursor;
DEALLOCATE PerformanceReviewCursor;

-- Final status check
INSERT INTO HR.CursorLog (CursorName, CursorStatus, Operation)
VALUES (
    @CursorName, 
    CURSOR_STATUS('global', 'PerformanceReviewCursor'),
    'Final Status'
);

-- View cursor operation log
SELECT 
    LogID,
    CursorName,
    RowCount,
    CursorStatus,
    FetchStatus,
    Operation,
    LogTime
FROM HR.CursorLog
ORDER BY LogID;

-- Example output interpretation
SELECT
    'Cursor Status Values' AS Description,
    'Cursor does not exist' AS Status_Neg1,
    'Cursor is closed' AS Status_0,
    'Cursor is open' AS Status_1,
    'Fetch Status Values' AS FetchStatus_Description,
    'Fetch succeeded' AS FetchStatus_0,
    'Fetch failed' AS FetchStatus_Neg1,
    'Fetch is beyond end of cursor' AS FetchStatus_Neg2;

-- View updated employee performance data
SELECT 
    EmployeeID,
    Performance,
    Rating,
    Comments,
    LastReviewDate
FROM HR.EmployeePerformance
WHERE Rating >= 4.0
ORDER BY Rating DESC;