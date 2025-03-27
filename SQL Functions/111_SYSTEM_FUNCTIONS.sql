/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\111_SYSTEM_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server System Functions with real-life examples
    using the HRSystem database schemas and tables.

    System Functions covered:
    1. USER_NAME() - Returns database user name
    2. @@VERSION - Returns SQL Server version info
    3. NEWID() - Generates a new UUID
    4. COALESCE() - Returns first non-null value
    5. ISNULL() - Replaces NULL with specified value
    6. SESSION_USER - Returns current session user
    7. SYSTEM_USER - Returns current system user
    8. CURRENT_USER - Returns current user context
    9. APP_NAME() - Returns application name
    10. HOST_NAME() - Returns client workstation name
    11. DB_NAME() - Returns current database name
    12. ERROR_NUMBER() - Returns error number
    13. ERROR_MESSAGE() - Returns error message
    14. ERROR_PROCEDURE() - Returns error procedure name
    15. ERROR_SEVERITY() - Returns error severity
    16. ERROR_STATE() - Returns error state
    17. FORMATMESSAGE() - Returns formatted error message
    18. SCOPE_IDENTITY() - Returns last identity value
    19. IDENTITY() - Returns identity value
    20. @@TRANCOUNT - Returns transaction count
    21. @@SPID - Returns process ID
    22. @@ERROR - Returns error number
    23. @@IDENTITY - Returns last identity value
    24. @@NESTLEVEL - Returns nesting level
    25. @@PROCID - Returns procedure ID
    26. SESSIONPROPERTY() - Returns session settings
    27. @@ROWCOUNT - Returns number of rows affected
*/

USE HRSystem;
GO

-- Create sample tables if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[AuditLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.AuditLog (
        LogID INT PRIMARY KEY IDENTITY(1,1),
        EventType VARCHAR(50),
        EventDate DATETIME2 DEFAULT SYSDATETIME(),
        UserName VARCHAR(100),
        ApplicationName VARCHAR(100),
        HostName VARCHAR(100),
        DatabaseName VARCHAR(100),
        SchemaName VARCHAR(100),
        ObjectName VARCHAR(100),
        SessionID INT,
        TransactionCount INT,
        ErrorNumber INT,
        ErrorMessage VARCHAR(MAX),
        AdditionalInfo VARCHAR(MAX)
    );

    -- Create a table for testing identity functions
    CREATE TABLE HR.IdentityTest (
        ID INT PRIMARY KEY IDENTITY(1000,1),
        Description VARCHAR(100),
        CreatedBy VARCHAR(100),
        CreatedDate DATETIME2 DEFAULT SYSDATETIME()
    );

    -- Create a table for error handling demonstration
    CREATE TABLE HR.ErrorLog (
        ErrorID INT PRIMARY KEY IDENTITY(1,1),
        ErrorNumber INT,
        ErrorSeverity INT,
        ErrorState INT,
        ErrorProcedure VARCHAR(100),
        ErrorLine INT,
        ErrorMessage VARCHAR(MAX),
        ErrorDate DATETIME2 DEFAULT SYSDATETIME()
    );
END

-- 1. USER_NAME() - Get current user name
SELECT 
    USER_NAME() AS CurrentUser,
    'Shows current database user' AS Description;
/* Output example:
CurrentUser      Description
dbo             Shows current database user
*/

-- 2. @@VERSION - Get SQL Server version
SELECT 
    @@VERSION AS SQLServerVersion;
/* Output example:
SQLServerVersion
Microsoft SQL Server 2019 (RTM) - 15.0.2000.5 (X64) ... <truncated>
*/

-- 3. NEWID() - Generate unique identifiers
SELECT 
    NEWID() AS UniqueID1,
    NEWID() AS UniqueID2;
/* Output example:
UniqueID1                              UniqueID2
123e4567-e89b-12d3-a456-426614174000  987fcdeb-51a2-43f7-b321-0123456789ab
*/

-- 4. COALESCE() - Handle NULL values
SELECT 
    FirstName,
    MiddleName,
    LastName,
    COALESCE(MiddleName, FirstName + ' ' + LastName) AS DisplayName
FROM HR.EMP_Details;
/* Output example:
FirstName  MiddleName  LastName  DisplayName
John       NULL        Doe       John Doe
Jane       Marie      Smith     Marie
*/

-- 5. ISNULL() - Replace NULL values
SELECT 
    FirstName,
    Phone,
    ISNULL(Phone, 'No Phone Number') AS ContactNumber
FROM HR.EMP_Details;
/* Output example:
FirstName  Phone         ContactNumber
John       555-0123      555-0123
Jane       NULL          No Phone Number
*/

-- 6. SESSION_USER, 7. SYSTEM_USER, 8. CURRENT_USER - User context information
SELECT 
    SESSION_USER AS SessionUser,
    SYSTEM_USER AS SystemUser,
    CURRENT_USER AS CurrentUser;
/* Output example:
SessionUser  SystemUser  CurrentUser
dbo         sa          dbo
*/

-- 9. APP_NAME() and 10. HOST_NAME() - Connection information
SELECT 
    APP_NAME() AS ApplicationName,
    HOST_NAME() AS HostName;
/* Output example:
ApplicationName  HostName
SQLQuery        DESKTOP-ABC123
*/

-- 11. DB_NAME() - Current database
SELECT 
    DB_NAME() AS CurrentDatabase,
    DB_NAME(1) AS DatabaseID1;
/* Output example:
CurrentDatabase  DatabaseID1
HRSystem        master
*/

-- Create a procedure to demonstrate error handling functions
CREATE OR ALTER PROCEDURE HR.DemoErrorHandling
AS
BEGIN
    BEGIN TRY
        -- Deliberately cause an error
        SELECT 1/0;
    END TRY
    BEGIN CATCH
        -- 12-16. Error information functions
        INSERT INTO HR.ErrorLog (
            ErrorNumber,
            ErrorSeverity,
            ErrorState,
            ErrorProcedure,
            ErrorLine,
            ErrorMessage
        )
        VALUES (
            ERROR_NUMBER(),
            ERROR_SEVERITY(),
            ERROR_STATE(),
            ERROR_PROCEDURE(),
            ERROR_LINE(),
            ERROR_MESSAGE()
        );

        -- 17. FORMATMESSAGE() - Format error message
        SELECT 
            FORMATMESSAGE('Error %d occurred at line %d: %s', 
                ERROR_NUMBER(), 
                ERROR_LINE(),
                ERROR_MESSAGE()) AS FormattedError;
    END CATCH
END;
GO

-- Execute the error handling demo
EXEC HR.DemoErrorHandling;
/* Output example:
FormattedError
Error 8134 occurred at line 4: Divide by zero error encountered.
*/

-- 18. SCOPE_IDENTITY() and 19. IDENTITY() - Identity value handling
INSERT INTO HR.IdentityTest (Description, CreatedBy)
VALUES ('Test Record 1', SYSTEM_USER);

SELECT 
    SCOPE_IDENTITY() AS LastIdentityInScope,
    IDENT_CURRENT('HR.IdentityTest') AS CurrentIdentity;
/* Output example:
LastIdentityInScope  CurrentIdentity
1000                1000
*/

-- 20. @@TRANCOUNT - Transaction management
BEGIN TRANSACTION;
    SELECT @@TRANCOUNT AS TransactionLevel1; -- Should be 1
    BEGIN TRANSACTION;
        SELECT @@TRANCOUNT AS TransactionLevel2; -- Should be 2
    COMMIT;
    SELECT @@TRANCOUNT AS TransactionLevelAfterInnerCommit; -- Should be 1
COMMIT;
/* Output example:
TransactionLevel1  TransactionLevel2  TransactionLevelAfterInnerCommit
1                 2                  1
*/

-- 21. @@SPID - Process information
SELECT 
    @@SPID AS CurrentProcessID,
    'Current session ID' AS Description;
/* Output example:
CurrentProcessID  Description
54               Current session ID
*/

-- 22. @@ERROR - Error handling
INSERT INTO HR.IdentityTest (Description, CreatedBy)
VALUES ('Test Record 2', SYSTEM_USER);

SELECT 
    @@ERROR AS ErrorNumber,
    CASE @@ERROR
        WHEN 0 THEN 'Success'
        ELSE 'Error occurred'
    END AS Status;
/* Output example:
ErrorNumber  Status
0            Success
*/

-- 23. @@IDENTITY - Last identity value
INSERT INTO HR.IdentityTest (Description, CreatedBy)
VALUES ('Test Record 3', SYSTEM_USER);

SELECT @@IDENTITY AS LastIdentityValue;
/* Output example:
LastIdentityValue
1002
*/

-- 24. @@NESTLEVEL - Nesting level
CREATE OR ALTER PROCEDURE HR.OuterProc
AS
BEGIN
    SELECT @@NESTLEVEL AS OuterNestLevel;
    EXEC HR.InnerProc;
END;
GO

CREATE OR ALTER PROCEDURE HR.InnerProc
AS
BEGIN
    SELECT @@NESTLEVEL AS InnerNestLevel;
END;
GO

EXEC HR.OuterProc;
/* Output example:
OuterNestLevel  InnerNestLevel
1               2
*/

-- 25. @@PROCID - Procedure ID
SELECT 
    OBJECT_NAME(@@PROCID) AS CurrentProcedure,
    @@PROCID AS ProcedureID;
/* Output example:
CurrentProcedure  ProcedureID
NULL             0
*/

-- 26. SESSIONPROPERTY() - Session settings
SELECT 
    SESSIONPROPERTY('ANSI_NULLS') AS AnsiNulls,
    SESSIONPROPERTY('QUOTED_IDENTIFIER') AS QuotedIdentifier,
    SESSIONPROPERTY('LANGUAGE') AS Language;
/* Output example:
AnsiNulls  QuotedIdentifier  Language
1          1                 us_english
*/

-- 27. @@ROWCOUNT - Affected rows
UPDATE HR.IdentityTest
SET Description = 'Updated Record'
WHERE ID > 1000;

SELECT 
    @@ROWCOUNT AS RowsAffected,
    'Number of rows affected by last statement' AS Description;
/* Output example:
RowsAffected  Description
3            Number of rows affected by last statement
*/

-- Complex example combining multiple system functions
INSERT INTO HR.AuditLog (
    EventType,
    UserName,
    ApplicationName,
    HostName,
    DatabaseName,
    SchemaName,
    ObjectName,
    SessionID,
    TransactionCount,
    AdditionalInfo
)
VALUES (
    'System Check',
    SYSTEM_USER,
    APP_NAME(),
    HOST_NAME(),
    DB_NAME(),
    SCHEMA_NAME(),
    OBJECT_NAME(@@PROCID),
    @@SPID,
    @@TRANCOUNT,
    FORMATMESSAGE('Server Version: %s, Nest Level: %d, Row Count: %d',
        CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(20)),
        @@NESTLEVEL,
        @@ROWCOUNT)
);

SELECT TOP 1 *
FROM HR.AuditLog
ORDER BY LogID DESC;
/* Output example:
LogID  EventType     EventDate               UserName  ApplicationName  HostName       DatabaseName  ...
1      System Check  2023-08-20 15:30:45.123 sa        SQLQuery        DESKTOP-ABC123 HRSystem      ...
*/