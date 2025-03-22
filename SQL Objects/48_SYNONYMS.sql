-- =============================================
-- SQL Server SYNONYMS Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating a Basic Synonym for a Table
-- First, let's create a synonym for the Projects table
CREATE SYNONYM ProjectList FOR Projects;
GO

-- Now we can query the table using the synonym
SELECT ProjectID, ProjectName, Budget FROM ProjectList;
GO

-- 2. Creating a Synonym for a Table in Another Schema
CREATE SYNONYM EmployeeList FOR HR.Employees;
GO

-- Query using the synonym
SELECT EmployeeID, FirstName, LastName FROM EmployeeList;
GO

-- 3. Creating a Synonym for a View
-- First, create a view
CREATE VIEW HR.EmployeeDetails AS
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    e.Email,
    e.Phone,
    d.DepartmentName,
    j.JobTitle
FROM HR.Employees e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
JOIN HR.JobPositions j ON e.JobPositionID = j.JobPositionID;
GO

-- Create a synonym for the view
CREATE SYNONYM StaffDirectory FOR HR.EmployeeDetails;
GO

-- Query using the synonym
SELECT EmployeeID, FirstName, LastName, DepartmentName FROM StaffDirectory;
GO

-- 4. Creating a Synonym for a Stored Procedure
CREATE SYNONYM GetProjects FOR sp_GetAllProjects;
GO

-- Execute the stored procedure using the synonym
EXEC GetProjects;
GO

-- 5. Creating a Synonym for a User-Defined Function
CREATE SYNONYM CalcDuration FOR dbo.fn_CalculateProjectDuration;
GO

-- Use the function through the synonym
SELECT 
    ProjectName,
    StartDate,
    EndDate,
    CalcDuration(StartDate, EndDate) AS DurationInDays
FROM Projects;
GO

-- 6. Creating a Synonym for an Object in Another Database
-- Note: The target database must exist
-- This example assumes there's a database called 'ArchiveDB' with a table called 'ArchivedProjects'
CREATE SYNONYM OldProjects FOR ArchiveDB.dbo.ArchivedProjects;
GO

-- 7. Creating a Synonym for a Table in a Linked Server
-- Note: The linked server must be configured
-- This example assumes there's a linked server called 'REMOTESERVER'
CREATE SYNONYM RemoteEmployees FOR REMOTESERVER.HRSystem.HR.Employees;
GO

-- 8. Creating a Synonym with a Different Schema
CREATE SCHEMA Reporting;
GO

CREATE SYNONYM Reporting.ProjectStatus FOR dbo.ProjectStatus;
GO

-- Query using the synonym with schema
SELECT * FROM Reporting.ProjectStatus;
GO

-- 9. Dropping a Synonym
DROP SYNONYM IF EXISTS ProjectList;
GO

-- 10. Altering a Synonym
-- SQL Server doesn't support ALTER SYNONYM directly
-- You need to drop and recreate the synonym
DROP SYNONYM IF EXISTS StaffDirectory;
GO

CREATE SYNONYM StaffDirectory FOR HR.EmployeeDetails;
GO

-- 11. Using Synonyms for Database Abstraction
-- Create synonyms for tables in a specific schema
CREATE SYNONYM Employees FOR HR.Employees;
CREATE SYNONYM Departments FOR HR.Departments;
CREATE SYNONYM JobPositions FOR HR.JobPositions;
GO

-- Now queries can be written without schema prefixes
SELECT 
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS EmployeeName,
    d.DepartmentName,
    j.JobTitle
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN JobPositions j ON e.JobPositionID = j.JobPositionID;
GO

-- 12. Using Synonyms for Version Control
-- Create a versioned table
CREATE TABLE ProjectsV2 (
    ProjectID INT PRIMARY KEY IDENTITY(1,1),
    ProjectName VARCHAR(100) NOT NULL,
    StartDate DATE,
    EndDate DATE,
    Budget DECIMAL(15,2),
    Status VARCHAR(20) DEFAULT 'Not Started',
    Description VARCHAR(500),
    CreatedDate DATETIME DEFAULT GETDATE(),
    ProjectManager VARCHAR(100),
    Priority INT DEFAULT 3,  -- New column in V2
    Category VARCHAR(50)     -- New column in V2
);
GO

-- Create a synonym that points to the current version
CREATE SYNONYM CurrentProjects FOR ProjectsV2;
GO

-- Applications can use the synonym without knowing which version is current
SELECT * FROM CurrentProjects;
GO

-- 13. Using Synonyms for Table Partitioning
-- Create partitioned tables by year
CREATE TABLE ProjectActivities2023 (
    ActivityID INT PRIMARY KEY IDENTITY(1,1),
    ProjectID INT,
    ActivityDate DATE,
    ActivityDescription VARCHAR(500),
    LoggedBy VARCHAR(100),
    CONSTRAINT CHK_2023_Date CHECK (ActivityDate >= '2023-01-01' AND ActivityDate < '2024-01-01'),
    CONSTRAINT FK_2023_Project FOREIGN KEY (ProjectID) REFERENCES Projects(ProjectID)
);
GO

CREATE TABLE ProjectActivities2024 (
    ActivityID INT PRIMARY KEY IDENTITY(1,1),
    ProjectID INT,
    ActivityDate DATE,
    ActivityDescription VARCHAR(500),
    LoggedBy VARCHAR(100),
    CONSTRAINT CHK_2024_Date CHECK (ActivityDate >= '2024-01-01' AND ActivityDate < '2025-01-01'),
    CONSTRAINT FK_2024_Project FOREIGN KEY (ProjectID) REFERENCES Projects(ProjectID)
);
GO