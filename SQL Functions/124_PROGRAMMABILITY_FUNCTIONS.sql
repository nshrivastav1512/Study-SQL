/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\124_PROGRAMMABILITY_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Programmability Functions
    using the HRSystem database. These functions enable accessing data from
    various sources and executing dynamic SQL.

    Programmability Functions covered:
    1. OPENDATASOURCE - Access data from remote data sources
    2. OPENQUERY - Execute queries on linked servers
    3. OPENROWSET - Read data from various sources
    4. OPENXML - Process XML data
    5. SP_EXECUTESQL - Execute dynamic SQL
*/

USE HRSystem;
GO

-- Create a table for storing external data processing results
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[ExternalDataLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.ExternalDataLog (
        LogID INT PRIMARY KEY IDENTITY(1,1),
        SourceType NVARCHAR(50),
        QueryType NVARCHAR(50),
        RecordsProcessed INT,
        ProcessDate DATETIME2 DEFAULT SYSDATETIME(),
        ProcessedBy NVARCHAR(100),
        Status NVARCHAR(20),
        ErrorMessage NVARCHAR(MAX)
    );
END

-- Example XML data for processing
DECLARE @XMLData XML = '
<Employees>
    <Employee>
        <ID>1</ID>
        <FirstName>John</FirstName>
        <LastName>Doe</LastName>
        <Department>IT</Department>
        <Salary>75000</Salary>
    </Employee>
    <Employee>
        <ID>2</ID>
        <FirstName>Jane</FirstName>
        <LastName>Smith</LastName>
        <Department>HR</Department>
        <Salary>65000</Salary>
    </Employee>
</Employees>';

-- 1. OPENDATASOURCE example (commented as it requires actual remote source)
/*
SELECT *
FROM OPENDATASOURCE(
    'SQLNCLI',
    'Data Source=RemoteServer;Initial Catalog=RemoteDB;User ID=user;Password=pass'
).RemoteDB.dbo.Employees;
*/

-- Log attempted OPENDATASOURCE operation
INSERT INTO HR.ExternalDataLog 
(SourceType, QueryType, RecordsProcessed, ProcessedBy, Status, ErrorMessage)
VALUES
('OPENDATASOURCE', 'SELECT', 0, SYSTEM_USER, 'Skipped', 'Remote source not configured');

-- 2. OPENQUERY example (commented as it requires linked server)
/*
SELECT *
FROM OPENQUERY(
    LinkedServer,
    'SELECT EmployeeID, FirstName, LastName, Department
     FROM HRDatabase.dbo.Employees
     WHERE Department = ''IT'''
);
*/

-- Log attempted OPENQUERY operation
INSERT INTO HR.ExternalDataLog 
(SourceType, QueryType, RecordsProcessed, ProcessedBy, Status, ErrorMessage)
VALUES
('OPENQUERY', 'SELECT', 0, SYSTEM_USER, 'Skipped', 'Linked server not configured');

-- 3. OPENROWSET example (commented as it requires actual file)
/*
SELECT *
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Data\Employees.xlsx',
    'SELECT * FROM [Sheet1$]'
);
*/

-- Log attempted OPENROWSET operation
INSERT INTO HR.ExternalDataLog 
(SourceType, QueryType, RecordsProcessed, ProcessedBy, Status, ErrorMessage)
VALUES
('OPENROWSET', 'SELECT', 0, SYSTEM_USER, 'Skipped', 'Source file not available');

-- 4. OPENXML - Process XML data
DECLARE @XMLHandle INT;

-- Create an internal representation of the XML document
EXEC sp_xml_preparedocument @XMLHandle OUTPUT, @XMLData;

-- Query the XML data using OPENXML
SELECT *
INTO #TempEmployees
FROM OPENXML(@XMLHandle, '/Employees/Employee', 2)
WITH (
    EmployeeID INT 'ID',
    FirstName NVARCHAR(50) 'FirstName',
    LastName NVARCHAR(50) 'LastName',
    Department NVARCHAR(50) 'Department',
    Salary DECIMAL(10,2) 'Salary'
);

-- Log OPENXML operation
INSERT INTO HR.ExternalDataLog 
(SourceType, QueryType, RecordsProcessed, ProcessedBy, Status)
VALUES
('OPENXML', 'SELECT INTO', @@ROWCOUNT, SYSTEM_USER, 'Success');

-- Remove the XML document from memory
EXEC sp_xml_removedocument @XMLHandle;

-- 5. SP_EXECUTESQL - Execute dynamic SQL
DECLARE 
    @SQL NVARCHAR(MAX),
    @ParamDefinition NVARCHAR(500),
    @DepartmentName NVARCHAR(50) = 'IT',
    @MinSalary DECIMAL(10,2) = 70000;

-- Build dynamic SQL with parameters
SET @SQL = N'
SELECT 
    EmployeeID,
    FirstName + '' '' + LastName AS FullName,
    Department,
    Salary
FROM #TempEmployees
WHERE Department = @Dept
    AND Salary >= @MinSal';

-- Define parameters
SET @ParamDefinition = N'
    @Dept NVARCHAR(50),
    @MinSal DECIMAL(10,2)';

-- Execute the dynamic SQL
EXEC sp_executesql 
    @SQL,
    @ParamDefinition,
    @Dept = @DepartmentName,
    @MinSal = @MinSalary;

-- Log sp_executesql operation
INSERT INTO HR.ExternalDataLog 
(SourceType, QueryType, RecordsProcessed, ProcessedBy, Status)
VALUES
('SP_EXECUTESQL', 'SELECT', @@ROWCOUNT, SYSTEM_USER, 'Success');

-- Create a view to analyze external data operations
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[HR].[ExternalDataAnalysis]'))
BEGIN
    EXECUTE sp_executesql N'
    CREATE VIEW HR.ExternalDataAnalysis
    AS
    SELECT 
        SourceType,
        QueryType,
        COUNT(*) AS TotalOperations,
        SUM(RecordsProcessed) AS TotalRecordsProcessed,
        SUM(CASE WHEN Status = ''Success'' THEN 1 ELSE 0 END) AS SuccessfulOperations,
        SUM(CASE WHEN Status = ''Skipped'' THEN 1 ELSE 0 END) AS SkippedOperations,
        MAX(ProcessDate) AS LastOperation
    FROM HR.ExternalDataLog
    GROUP BY SourceType, QueryType;
    ';
END

-- Example of analyzing external data operations
SELECT 
    SourceType,
    QueryType,
    TotalOperations,
    TotalRecordsProcessed,
    SuccessfulOperations,
    SkippedOperations,
    LastOperation
FROM HR.ExternalDataAnalysis
ORDER BY LastOperation DESC;

-- Cleanup
DROP TABLE IF EXISTS #TempEmployees;