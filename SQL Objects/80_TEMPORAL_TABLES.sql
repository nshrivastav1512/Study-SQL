-- =============================================
-- SQL Server TEMPORAL TABLES Guide
-- =============================================

/*
This guide demonstrates the use of Temporal Tables in SQL Server for HR scenarios:
- Tracking employee history (position changes, salary adjustments)
- Auditing department transfers and reorganizations
- Analyzing historical trends and changes
- Point-in-time data analysis
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: CREATING TEMPORAL TABLES
-- =============================================

-- 1. Create Employee History Table
IF OBJECT_ID('HR.EmployeesHistory', 'U') IS NOT NULL
    DROP TABLE HR.EmployeesHistory;

IF OBJECT_ID('HR.Employees', 'U') IS NOT NULL
    DROP TABLE HR.Employees;

CREATE TABLE HR.Employees (
    EmployeeID INT PRIMARY KEY CLUSTERED,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    DepartmentID INT,
    Position NVARCHAR(100),
    Salary DECIMAL(12,2),
    ManagerID INT,
    Status NVARCHAR(20),
    ValidFrom DATETIME2(7) GENERATED ALWAYS AS ROW START,
    ValidTo DATETIME2(7) GENERATED ALWAYS AS ROW END,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = HR.EmployeesHistory));

-- 2. Create Department History Table
IF OBJECT_ID('HR.DepartmentsHistory', 'U') IS NOT NULL
    DROP TABLE HR.DepartmentsHistory;

IF OBJECT_ID('HR.Departments', 'U') IS NOT NULL
    DROP TABLE HR.Departments;

CREATE TABLE HR.Departments (
    DepartmentID INT PRIMARY KEY CLUSTERED,
    DepartmentName NVARCHAR(100),
    ManagerID INT,
    Budget DECIMAL(15,2),
    Location NVARCHAR(100),
    ValidFrom DATETIME2(7) GENERATED ALWAYS AS ROW START,
    ValidTo DATETIME2(7) GENERATED ALWAYS AS ROW END,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = HR.DepartmentsHistory));

-- =============================================
-- PART 2: INSERTING AND MODIFYING DATA
-- =============================================

-- 1. Insert initial employee data
INSERT INTO HR.Employees (
    EmployeeID, FirstName, LastName, DepartmentID, 
    Position, Salary, ManagerID, Status
)
VALUES
    (1, 'John', 'Smith', 1, 'CEO', 150000.00, NULL, 'Active'),
    (2, 'Jane', 'Doe', 2, 'HR Director', 95000.00, 1, 'Active'),
    (3, 'Bob', 'Johnson', 3, 'IT Manager', 85000.00, 1, 'Active'),
    (4, 'Alice', 'Brown', 3, 'Senior Developer', 75000.00, 3, 'Active');

-- 2. Insert initial department data
INSERT INTO HR.Departments (
    DepartmentID, DepartmentName, ManagerID, Budget, Location
)
VALUES
    (1, 'Executive', 1, 500000.00, 'HQ Floor 10'),
    (2, 'Human Resources', 2, 350000.00, 'HQ Floor 8'),
    (3, 'Information Technology', 3, 750000.00, 'HQ Floor 5');

-- 3. Make some changes to demonstrate history tracking
-- Salary adjustment
UPDATE HR.Employees
SET Salary = 80000.00
WHERE EmployeeID = 4;

-- Department transfer
UPDATE HR.Employees
SET 
    DepartmentID = 2,
    Position = 'HR Specialist',
    Salary = 65000.00
WHERE EmployeeID = 4;

-- Budget adjustment
UPDATE HR.Departments
SET Budget = 400000.00
WHERE DepartmentID = 2;

-- =============================================
-- PART 3: QUERYING TEMPORAL DATA
-- =============================================

-- 1. View employee history
CREATE OR ALTER PROCEDURE HR.GetEmployeeHistory
    @EmployeeID INT
AS
BEGIN
    SELECT 
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        d.DepartmentName,
        e.Position,
        e.Salary,
        e.ValidFrom AS ChangeDate,
        LEAD(e.ValidFrom) OVER (ORDER BY e.ValidFrom) AS ValidUntil,
        CASE 
            WHEN LEAD(e.ValidFrom) OVER (ORDER BY e.ValidFrom) IS NULL 
            THEN 'Current'
            ELSE 'Historical'
        END AS RecordStatus
    FROM HR.Employees FOR SYSTEM_TIME ALL e
    JOIN HR.Departments FOR SYSTEM_TIME ALL d 
        ON e.DepartmentID = d.DepartmentID
        AND d.ValidFrom <= e.ValidFrom
        AND (d.ValidTo > e.ValidFrom OR d.ValidTo = '9999-12-31 23:59:59.9999999')
    WHERE e.EmployeeID = @EmployeeID
    ORDER BY e.ValidFrom;
END;

-- 2. Point-in-time department structure
CREATE OR ALTER PROCEDURE HR.GetDepartmentStructure
    @AsOfDate DATETIME2
AS
BEGIN
    SELECT 
        d.DepartmentID,
        d.DepartmentName,
        d.Location,
        FORMAT(d.Budget, 'C') AS Budget,
        m.FirstName + ' ' + m.LastName AS Manager,
        COUNT(e.EmployeeID) AS EmployeeCount,
        FORMAT(SUM(e.Salary), 'C') AS TotalSalaries
    FROM HR.Departments FOR SYSTEM_TIME AS OF @AsOfDate d
    LEFT JOIN HR.Employees FOR SYSTEM_TIME AS OF @AsOfDate m 
        ON d.ManagerID = m.EmployeeID
    LEFT JOIN HR.Employees FOR SYSTEM_TIME AS OF @AsOfDate e
        ON d.DepartmentID = e.DepartmentID
    GROUP BY 
        d.DepartmentID,
        d.DepartmentName,
        d.Location,
        d.Budget,
        m.FirstName + ' ' + m.LastName
    ORDER BY d.DepartmentName;
END;

-- 3. Analyze salary changes
CREATE OR ALTER PROCEDURE HR.AnalyzeSalaryChanges
    @StartDate DATETIME2,
    @EndDate DATETIME2
AS
BEGIN
    WITH SalaryChanges AS (
        SELECT 
            e.EmployeeID,
            e.FirstName + ' ' + e.LastName AS EmployeeName,
            d.DepartmentName,
            e.Position,
            e.Salary AS NewSalary,
            LAG(e.Salary) OVER (PARTITION BY e.EmployeeID ORDER BY e.ValidFrom) AS PreviousSalary,
            e.ValidFrom AS ChangeDate
        FROM HR.Employees FOR SYSTEM_TIME FROM @StartDate TO @EndDate e
        JOIN HR.Departments FOR SYSTEM_TIME CONTAINED IN (@StartDate, @EndDate) d
            ON e.DepartmentID = d.DepartmentID
    )
    SELECT 
        EmployeeID,
        EmployeeName,
        DepartmentName,
        Position,
        FORMAT(PreviousSalary, 'C') AS PreviousSalary,
        FORMAT(NewSalary, 'C') AS NewSalary,
        FORMAT((NewSalary - PreviousSalary), 'C') AS SalaryChange,
        FORMAT((NewSalary - PreviousSalary) / PreviousSalary * 100, 'N2') + '%' AS PercentageChange,
        ChangeDate
    FROM SalaryChanges
    WHERE PreviousSalary IS NOT NULL
    ORDER BY 
        ABS(NewSalary - PreviousSalary) DESC,
        ChangeDate;
END;

-- =============================================
-- PART 4: ANALYZING HISTORICAL TRENDS
-- =============================================

-- 1. Department budget history analysis
CREATE OR ALTER PROCEDURE HR.AnalyzeBudgetHistory
    @DepartmentID INT = NULL
AS
BEGIN
    WITH BudgetChanges AS (
        SELECT 
            d.DepartmentID,
            d.DepartmentName,
            d.Budget AS NewBudget,
            LAG(d.Budget) OVER (PARTITION BY d.DepartmentID ORDER BY d.ValidFrom) AS PreviousBudget,
            d.ValidFrom AS ChangeDate,
            LEAD(d.ValidFrom) OVER (PARTITION BY d.DepartmentID ORDER BY d.ValidFrom) AS NextChangeDate
        FROM HR.Departments FOR SYSTEM_TIME ALL d
        WHERE @DepartmentID IS NULL OR d.DepartmentID = @DepartmentID
    )
    SELECT 
        DepartmentID,
        DepartmentName,
        FORMAT(PreviousBudget, 'C') AS PreviousBudget,
        FORMAT(NewBudget, 'C') AS NewBudget,
        FORMAT((NewBudget - PreviousBudget), 'C') AS BudgetChange,
        FORMAT((NewBudget - PreviousBudget) / PreviousBudget * 100, 'N2') + '%' AS PercentageChange,
        ChangeDate,
        COALESCE(NextChangeDate, CURRENT_TIMESTAMP) AS ValidUntil,
        CASE 
            WHEN NextChangeDate IS NULL THEN 'Current'
            ELSE 'Historical'
        END AS Status
    FROM BudgetChanges
    WHERE PreviousBudget IS NOT NULL
    ORDER BY 
        DepartmentName,
        ChangeDate;
END;

-- 2. Employee turnover analysis
CREATE OR ALTER PROCEDURE HR.AnalyzeEmployeeTurnover
    @StartDate DATETIME2,
    @EndDate DATETIME2
AS
BEGIN
    WITH StatusChanges AS (
        SELECT 
            e.DepartmentID,
            d.DepartmentName,
            e.Status AS NewStatus,
            LAG(e.Status) OVER (PARTITION BY e.EmployeeID ORDER BY e.ValidFrom) AS PreviousStatus,
            e.ValidFrom AS ChangeDate
        FROM HR.Employees FOR SYSTEM_TIME FROM @StartDate TO @EndDate e
        JOIN HR.Departments FOR SYSTEM_TIME CONTAINED IN (@StartDate, @EndDate) d
            ON e.DepartmentID = d.DepartmentID
        WHERE e.Status <> LAG(e.Status) OVER (PARTITION BY e.EmployeeID ORDER BY e.ValidFrom)
            OR LAG(e.Status) OVER (PARTITION BY e.EmployeeID ORDER BY e.ValidFrom) IS NULL
    )
    SELECT 
        DepartmentName,
        COUNT(CASE WHEN PreviousStatus = 'Active' AND NewStatus = 'Inactive' THEN 1 END) AS Departures,
        COUNT(CASE WHEN PreviousStatus IS NULL AND NewStatus = 'Active' THEN 1 END) AS NewHires,
        COUNT(CASE WHEN PreviousStatus = 'Inactive' AND NewStatus = 'Active' THEN 1 END) AS Rehires,
        FORMAT(
            CAST(COUNT(CASE WHEN PreviousStatus = 'Active' AND NewStatus = 'Inactive' THEN 1 END) AS FLOAT) /
            NULLIF(COUNT(CASE WHEN PreviousStatus IS NULL AND NewStatus = 'Active' THEN 1 END), 0) * 100,
            'N2'
        ) + '%' AS TurnoverRate
    FROM StatusChanges
    GROUP BY DepartmentName
    ORDER BY Departures DESC;
END;

-- =============================================
-- PART 5: MAINTAINING TEMPORAL TABLES
-- =============================================

-- 1. Cleanup historical data
CREATE OR ALTER PROCEDURE HR.CleanupHistoricalData
    @RetentionMonths INT = 84 -- 7 years by default
AS
BEGIN
    DECLARE @RetentionDate DATETIME2 = DATEADD(MONTH, -@RetentionMonths, GETDATE());
    
    -- Cleanup Employee history
    ALTER TABLE HR.Employees SET (SYSTEM_VERSIONING = OFF);
    DELETE FROM HR.EmployeesHistory
    WHERE ValidTo < @RetentionDate;
    ALTER TABLE HR.Employees
    SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = HR.EmployeesHistory));
    
    -- Cleanup Department history
    ALTER TABLE HR.Departments SET (SYSTEM_VERSIONING = OFF);
    DELETE FROM HR.DepartmentsHistory
    WHERE ValidTo < @RetentionDate;
    ALTER TABLE HR.Departments
    SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = HR.DepartmentsHistory));
END;

-- 2. Optimize temporal table performance
CREATE NONCLUSTERED INDEX IX_EmployeesHistory_ValidFrom
ON HR.EmployeesHistory(ValidFrom);

CREATE NONCLUSTERED INDEX IX_DepartmentsHistory_ValidFrom
ON HR.DepartmentsHistory(ValidFrom);