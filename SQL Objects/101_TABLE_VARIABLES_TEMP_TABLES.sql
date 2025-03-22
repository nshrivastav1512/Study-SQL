-- =============================================
-- SQL Server Table Variables vs Temp Tables Guide
-- Demonstrates differences, use cases, and
-- performance considerations for both approaches
-- =============================================

USE HRSystem;
GO

-- =============================================
-- PART 1: Basic Table Variable Usage
-- =============================================

-- Declare and populate table variable
DECLARE @EmployeeUpdates TABLE (
    EmployeeID INT,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Salary DECIMAL(10,2)
);

-- Insert single row
INSERT INTO @EmployeeUpdates
VALUES (1, 'John', 'Smith', 75000.00);

-- Insert multiple rows
INSERT INTO @EmployeeUpdates
SELECT EmployeeID, FirstName, LastName, Salary
FROM HR.Employees
WHERE DepartmentID = 1;

-- =============================================
-- PART 2: Temporary Table Usage
-- =============================================

-- Create and populate temp table
CREATE TABLE #EmployeeTemp (
    EmployeeID INT,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Salary DECIMAL(10,2),
    INDEX IX_EmployeeID (EmployeeID)
);

-- Bulk insert into temp table
INSERT INTO #EmployeeTemp
SELECT EmployeeID, FirstName, LastName, Salary
FROM HR.Employees
WHERE Salary > 50000;

-- =============================================
-- PART 3: Scope and Visibility
-- =============================================

-- Table Variable Scope Example
CREATE PROCEDURE HR.DemoTableVariableScope
AS
BEGIN
    DECLARE @DeptEmployees TABLE (
        DeptID INT,
        EmployeeCount INT
    );

    INSERT INTO @DeptEmployees
    SELECT DepartmentID, COUNT(*)
    FROM HR.Employees
    GROUP BY DepartmentID;

    -- Table variable only visible within procedure
    SELECT * FROM @DeptEmployees;
END;
GO

-- Temp Table Scope Example
CREATE PROCEDURE HR.DemoTempTableScope
AS
BEGIN
    -- Temp table visible to all procedures in session
    CREATE TABLE #DeptSummary (
        DeptID INT,
        EmployeeCount INT,
        AvgSalary DECIMAL(10,2)
    );

    INSERT INTO #DeptSummary
    SELECT 
        DepartmentID,
        COUNT(*),
        AVG(Salary)
    FROM HR.Employees
    GROUP BY DepartmentID;

    EXEC HR.ProcessDeptSummary; -- Can access #DeptSummary

    DROP TABLE #DeptSummary;
END;
GO

-- =============================================
-- PART 4: Performance Considerations
-- =============================================

-- Table Variable (Better for small datasets)
DECLARE @SmallDataset TABLE (
    ID INT,
    Value VARCHAR(50)
);

INSERT INTO @SmallDataset
VALUES (1, 'Test1'), (2, 'Test2'), (3, 'Test3');

-- Temp Table (Better for large datasets)
CREATE TABLE #LargeDataset (
    ID INT,
    Value VARCHAR(50),
    INDEX IX_ID (ID)
);

INSERT INTO #LargeDataset
SELECT 
    ROW_NUMBER() OVER (ORDER BY e1.EmployeeID),
    'Value' + CAST(e1.EmployeeID AS VARCHAR)
FROM HR.Employees e1
CROSS JOIN HR.Employees e2;

-- =============================================
-- PART 5: Common Use Cases
-- =============================================

-- Table Variable: Parameter Lists
DECLARE @SelectedDepts TABLE (DeptID INT);
INSERT INTO @SelectedDepts VALUES (1), (2), (3);

SELECT e.*
FROM HR.Employees e
JOIN @SelectedDepts d ON e.DepartmentID = d.DeptID;

-- Temp Table: Staging Data
CREATE TABLE #StagingEmployees (
    EmployeeID INT,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Salary DECIMAL(10,2),
    DepartmentID INT,
    ValidRecord BIT DEFAULT 1
);

-- Insert and validate data
INSERT INTO #StagingEmployees (EmployeeID, FirstName, LastName, Salary, DepartmentID)
SELECT EmployeeID, FirstName, LastName, Salary, DepartmentID
FROM HR.Employees;

-- Mark invalid records
UPDATE #StagingEmployees
SET ValidRecord = 0
WHERE Salary < 0 OR DepartmentID NOT IN (SELECT DepartmentID FROM HR.Departments);

-- =============================================
-- PART 6: Best Practices and Tips
-- =============================================

/*
1. Table Variables:
   - Use for small datasets (< 1000 rows)
   - When you need table-valued parameters
   - For simple temporary storage
   - When transaction logging is important

2. Temp Tables:
   - Use for large datasets
   - When you need indexes
   - For complex processing
   - When statistics are important

3. General Guidelines:
   - Consider data volume
   - Check execution plans
   - Monitor memory usage
   - Clean up temp tables
*/

-- Cleanup
DROP TABLE IF EXISTS #EmployeeTemp;
DROP TABLE IF EXISTS #LargeDataset;
DROP TABLE IF EXISTS #StagingEmployees;
GO

-- Drop test procedures
DROP PROCEDURE IF EXISTS HR.DemoTableVariableScope;
DROP PROCEDURE IF EXISTS HR.DemoTempTableScope;
GO