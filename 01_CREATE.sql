/*
    FILEPATH: /c:/AI Use and Deveopment/Study SQL/01_CREATE.sql

    This SQL script demonstrates the usage of the CREATE keyword in SQL Server to create a database, schemas, tables, indexes, views, stored procedures, triggers, and functions.

    The script creates a database named HRSystem and defines three schemas: HR, EMP, and PAYROLL. It then creates tables within the HR schema to store department information, employee details, and locations. The EMP schema contains a table for employee login information, and the PAYROLL schema has a table to track salary history.

    Indexes are created on the EMP_Details table to improve query performance. A view named vw_EmployeeDetails is created to retrieve employee information from multiple tables. A stored procedure named sp_UpdateEmployeeSalary is defined to update an employee's salary and store the old salary in the salary history table. A trigger named trg_UpdateModifiedDate is created to update the ModifiedDate column in the EMP_Details table whenever a row is updated. Finally, a function named fn_GetEmployeeYearsOfService is defined to calculate the number of years an employee has been in service.

    This script serves as a comprehensive guide for using the CREATE keyword in SQL Server to create and manage database objects.

    Author: [Your Name]
    Date: [Current Date]
*/
-- =============================================
-- CREATE Keyword Complete Guide
-- =============================================

-- 1. Creating Database
CREATE DATABASE HRSystem;
GO

USE HRSystem;
GO

-- 2. Creating Schemas (Logical grouping of database objects)
CREATE SCHEMA HR;
GO

CREATE SCHEMA EMP;
GO

CREATE SCHEMA PAYROLL;
GO

-- 3. Creating Tables with relationships
-- HR Schema Tables
CREATE TABLE HR.Departments (
    DepartmentID INT PRIMARY KEY IDENTITY(1,1),
    DepartmentName VARCHAR(50) NOT NULL,
    LocationID INT,
    ManagerID INT,
    CreatedDate DATETIME DEFAULT GETDATE(),
    ModifiedDate DATETIME
);

CREATE TABLE HR.Locations (
    LocationID INT PRIMARY KEY IDENTITY(1,1),
    City VARCHAR(50),
    State VARCHAR(50),
    Country VARCHAR(50),
    CreatedDate DATETIME DEFAULT GETDATE()
);

CREATE TABLE HR.EMP_Details (
    EmployeeID INT PRIMARY KEY IDENTITY(1000,1),
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE,
    Phone VARCHAR(15),
    HireDate DATE NOT NULL,
    DepartmentID INT FOREIGN KEY REFERENCES HR.Departments(DepartmentID),
    Salary DECIMAL(12,2),
    CreatedDate DATETIME DEFAULT GETDATE(),
    ModifiedDate DATETIME,
    CONSTRAINT CHK_Salary CHECK (Salary > 0)
);

-- EMP Schema Tables (Employee Portal Related)
CREATE TABLE EMP.Employee_Login (
    LoginID INT PRIMARY KEY IDENTITY(1,1),
    EmployeeID INT FOREIGN KEY REFERENCES HR.EMP_Details(EmployeeID),
    Username VARCHAR(50) UNIQUE NOT NULL,
    PasswordHash VARBINARY(256) NOT NULL,
    LastLoginDate DATETIME,
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME DEFAULT GETDATE()
);

-- PAYROLL Schema Tables
CREATE TABLE PAYROLL.Salary_History (
    SalaryHistoryID INT PRIMARY KEY IDENTITY(1,1),
    EmployeeID INT FOREIGN KEY REFERENCES HR.EMP_Details(EmployeeID),
    OldSalary DECIMAL(12,2),
    NewSalary DECIMAL(12,2),
    EffectiveDate DATE,
    CreatedDate DATETIME DEFAULT GETDATE()
);

-- 4. Creating Indexes
CREATE NONCLUSTERED INDEX IX_EMP_Details_DepartmentID
ON HR.EMP_Details(DepartmentID);

CREATE NONCLUSTERED INDEX IX_EMP_Details_Email
ON HR.EMP_Details(Email);

-- 5. Creating Views
CREATE VIEW HR.vw_EmployeeDetails
AS
SELECT 
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS FullName,
    e.Email,
    d.DepartmentName,
    l.City,
    l.Country,
    e.Salary
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
JOIN HR.Locations l ON d.LocationID = l.LocationID;

-- 6. Creating Stored Procedures
CREATE PROCEDURE HR.sp_UpdateEmployeeSalary
    @EmployeeID INT,
    @NewSalary DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
            -- Store old salary in history
            INSERT INTO PAYROLL.Salary_History (EmployeeID, OldSalary, NewSalary, EffectiveDate)
            SELECT 
                EmployeeID, 
                Salary AS OldSalary, 
                @NewSalary AS NewSalary,
                GETDATE()
            FROM HR.EMP_Details 
            WHERE EmployeeID = @EmployeeID;

            -- Update new salary
            UPDATE HR.EMP_Details
            SET Salary = @NewSalary,
                ModifiedDate = GETDATE()
            WHERE EmployeeID = @EmployeeID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

-- 7. Creating Triggers
CREATE TRIGGER HR.trg_UpdateModifiedDate
ON HR.EMP_Details
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE HR.EMP_Details
    SET ModifiedDate = GETDATE()
    FROM HR.EMP_Details e
    INNER JOIN inserted i ON e.EmployeeID = i.EmployeeID;
END;

-- 8. Creating Functions
CREATE FUNCTION HR.fn_GetEmployeeYearsOfService
(
    @EmployeeID INT
)
RETURNS INT
AS
BEGIN
    DECLARE @YearsOfService INT;
    
    SELECT @YearsOfService = DATEDIFF(YEAR, HireDate, GETDATE())
    FROM HR.EMP_Details
    WHERE EmployeeID = @EmployeeID;
    
    RETURN @YearsOfService;
END;