-- =============================================
-- SQL Server OUTPUT Clause Guide
-- Demonstrates practical usage of OUTPUT clause
-- in HR scenarios with best practices
-- =============================================

USE HRSystem;
GO

-- =============================================
-- PART 1: Basic OUTPUT Usage with INSERT
-- =============================================

-- 1. Tracking New Employees
DECLARE @NewEmployees TABLE (
    EmployeeID INT,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    InsertedTime DATETIME
);

INSERT INTO HR.Employees (FirstName, LastName, DepartmentID, Salary)
OUTPUT 
    INSERTED.EmployeeID,
    INSERTED.FirstName,
    INSERTED.LastName,
    GETDATE()
INTO @NewEmployees
VALUES ('John', 'Smith', 1, 50000);

-- 2. Capturing Multiple Insertions
INSERT INTO HR.EmployeeSkills (EmployeeID, SkillName, ProficiencyLevel)
OUTPUT 
    INSERTED.EmployeeID,
    INSERTED.SkillName,
    INSERTED.ProficiencyLevel
SELECT EmployeeID, 'SQL Server', 'Intermediate'
FROM HR.Employees
WHERE DepartmentID = 1;

-- =============================================
-- PART 2: OUTPUT with UPDATE Operations
-- =============================================

-- 1. Salary Change Tracking
DECLARE @SalaryChanges TABLE (
    EmployeeID INT,
    OldSalary DECIMAL(10,2),
    NewSalary DECIMAL(10,2),
    ChangeDate DATETIME
);

UPDATE HR.Employees
SET Salary = Salary * 1.10
OUTPUT 
    INSERTED.EmployeeID,
    DELETED.Salary,
    INSERTED.Salary,
    GETDATE()
INTO @SalaryChanges
WHERE DepartmentID = 2;

-- 2. Position Changes Log
UPDATE HR.EmployeePositions
SET EndDate = GETDATE()
OUTPUT 
    DELETED.EmployeeID,
    DELETED.Position,
    DELETED.StartDate,
    INSERTED.EndDate
WHERE EndDate IS NULL
AND EmployeeID IN (SELECT EmployeeID FROM HR.Employees WHERE DepartmentID = 3);

-- =============================================
-- PART 3: OUTPUT with DELETE Operations
-- =============================================

-- 1. Archiving Deleted Records
DECLARE @DeletedEmployees TABLE (
    EmployeeID INT,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    DeletionDate DATETIME
);

DELETE FROM HR.Employees
OUTPUT 
    DELETED.EmployeeID,
    DELETED.FirstName,
    DELETED.LastName,
    GETDATE()
INTO @DeletedEmployees
WHERE Status = 'Terminated';

-- 2. Tracking Removed Skills
DELETE FROM HR.EmployeeSkills
OUTPUT 
    DELETED.EmployeeID,
    DELETED.SkillName,
    DELETED.ProficiencyLevel,
    'Skill Removed' AS Action,
    GETDATE() AS RemovalDate
WHERE ProficiencyLevel = 'Beginner';

-- =============================================
-- PART 4: OUTPUT with MERGE Operations
-- =============================================

-- 1. Employee Status Updates
DECLARE @StatusChanges TABLE (
    EmployeeID INT,
    OldStatus VARCHAR(20),
    NewStatus VARCHAR(20),
    Action VARCHAR(10),
    ChangeDate DATETIME
);

MERGE HR.Employees AS TARGET
USING (SELECT EmployeeID, 'Active' AS Status 
       FROM HR.EmployeePerformance 
       WHERE Rating >= 4) AS SOURCE
ON (TARGET.EmployeeID = SOURCE.EmployeeID)
WHEN MATCHED THEN
    UPDATE SET Status = SOURCE.Status
WHEN NOT MATCHED THEN
    INSERT (EmployeeID, Status)
    VALUES (SOURCE.EmployeeID, SOURCE.Status)
OUTPUT 
    INSERTED.EmployeeID,
    DELETED.Status,
    INSERTED.Status,
    $action,
    GETDATE()
INTO @StatusChanges;

-- =============================================
-- PART 5: Best Practices and Tips
-- =============================================

/*
1. Performance Considerations:
   - Use appropriate indexes on target tables
   - Consider table variable vs temp table for output
   - Avoid large transactions with OUTPUT

2. Common Use Cases:
   - Audit trailing
   - Data synchronization
   - Change tracking
   - Debugging and validation

3. Limitations:
   - Cannot use with READPAST hint
   - Cannot reference OUTPUT table in nested DML
   - Maximum 1000 columns in OUTPUT clause
*/

-- Example of optimized OUTPUT usage
DECLARE @Changes TABLE (
    ID INT IDENTITY(1,1),
    EmployeeID INT,
    ChangeType VARCHAR(50),
    ChangeDetails VARCHAR(MAX),
    ChangeDate DATETIME
);

UPDATE e
SET Salary = Salary * 1.05
OUTPUT
    INSERTED.EmployeeID,
    'Salary Increase',
    CONCAT('Old: ', DELETED.Salary, ' New: ', INSERTED.Salary),
    GETDATE()
INTO @Changes
FROM HR.Employees e
JOIN HR.PerformanceReviews pr ON e.EmployeeID = pr.EmployeeID
WHERE pr.Rating >= 4;
GO