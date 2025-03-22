-- =============================================
-- SQL Server MERGE Operations Guide
-- Demonstrates comprehensive MERGE scenarios for
-- employee data management including:
-- - Basic operations
-- - Conditional merges
-- - Historical tracking
-- - Error handling
-- - Best practices
-- =============================================

USE HRSystem;
GO

-- =============================================
-- PART 1: Basic MERGE Operation
-- =============================================

-- Create a source table for new/updated employee data
DECLARE @SourceEmployees TABLE (
    EmployeeID INT,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Salary DECIMAL(10,2),
    DepartmentID INT
);

-- Insert sample source data
INSERT INTO @SourceEmployees VALUES
    (1, 'John', 'Smith', 75000.00, 1),    -- Existing employee, updated salary
    (2, 'Mary', 'Johnson', 85000.00, 2),  -- Existing employee, no change
    (4, 'David', 'Wilson', 65000.00, 1);   -- New employee

-- Basic MERGE operation
MERGE HR.Employees AS TARGET
USING @SourceEmployees AS SOURCE
ON (TARGET.EmployeeID = SOURCE.EmployeeID)
WHEN MATCHED THEN
    UPDATE SET
        TARGET.Salary = SOURCE.Salary,
        TARGET.FirstName = SOURCE.FirstName,
        TARGET.LastName = SOURCE.LastName,
        TARGET.DepartmentID = SOURCE.DepartmentID
WHEN NOT MATCHED BY TARGET THEN
    INSERT (EmployeeID, FirstName, LastName, Salary, DepartmentID)
    VALUES (SOURCE.EmployeeID, SOURCE.FirstName, SOURCE.LastName, SOURCE.Salary, SOURCE.DepartmentID);

-- =============================================
-- PART 2: Advanced MERGE with OUTPUT
-- =============================================

-- Create a table to track changes
CREATE TABLE #MergeLog (
    Action VARCHAR(10),
    EmployeeID INT,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    OldSalary DECIMAL(10,2),
    NewSalary DECIMAL(10,2),
    ModifiedDate DATETIME
);

-- MERGE with OUTPUT clause
MERGE HR.Employees AS TARGET
USING @SourceEmployees AS SOURCE
ON (TARGET.EmployeeID = SOURCE.EmployeeID)
WHEN MATCHED THEN
    UPDATE SET
        TARGET.Salary = SOURCE.Salary,
        TARGET.FirstName = SOURCE.FirstName,
        TARGET.LastName = SOURCE.LastName,
        TARGET.DepartmentID = SOURCE.DepartmentID
WHEN NOT MATCHED BY TARGET THEN
    INSERT (EmployeeID, FirstName, LastName, Salary, DepartmentID)
    VALUES (SOURCE.EmployeeID, SOURCE.FirstName, SOURCE.LastName, SOURCE.Salary, SOURCE.DepartmentID)
OUTPUT
    $action AS Action,
    INSERTED.EmployeeID,
    INSERTED.FirstName,
    INSERTED.LastName,
    DELETED.Salary AS OldSalary,
    INSERTED.Salary AS NewSalary,
    GETDATE() AS ModifiedDate
INTO #MergeLog;

-- =============================================
-- PART 3: Conditional MERGE Operations
-- =============================================

-- MERGE with conditional updates
MERGE HR.Employees AS TARGET
USING @SourceEmployees AS SOURCE
ON (TARGET.EmployeeID = SOURCE.EmployeeID)
WHEN MATCHED AND TARGET.Salary <> SOURCE.Salary THEN
    UPDATE SET
        TARGET.Salary = SOURCE.Salary,
        TARGET.ModifiedDate = GETDATE()
WHEN NOT MATCHED BY TARGET AND SOURCE.Salary > 50000 THEN
    INSERT (EmployeeID, FirstName, LastName, Salary, DepartmentID)
    VALUES (SOURCE.EmployeeID, SOURCE.FirstName, SOURCE.LastName, SOURCE.Salary, SOURCE.DepartmentID)
WHEN NOT MATCHED BY SOURCE THEN
    UPDATE SET TARGET.IsActive = 0;

-- =============================================
-- PART 4: MERGE for Historical Data
-- =============================================

-- Create employee history table
IF OBJECT_ID('HR.EmployeeHistory') IS NOT NULL
    DROP TABLE HR.EmployeeHistory;

CREATE TABLE HR.EmployeeHistory (
    EmployeeHistoryID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Salary DECIMAL(10,2),
    DepartmentID INT,
    ModifiedDate DATETIME,
    Action VARCHAR(10)
);

-- MERGE with history tracking
MERGE HR.Employees AS TARGET
USING @SourceEmployees AS SOURCE
ON (TARGET.EmployeeID = SOURCE.EmployeeID)
WHEN MATCHED THEN
    UPDATE SET
        TARGET.Salary = SOURCE.Salary,
        TARGET.FirstName = SOURCE.FirstName,
        TARGET.LastName = SOURCE.LastName,
        TARGET.DepartmentID = SOURCE.DepartmentID
WHEN NOT MATCHED BY TARGET THEN
    INSERT (EmployeeID, FirstName, LastName, Salary, DepartmentID)
    VALUES (SOURCE.EmployeeID, SOURCE.FirstName, SOURCE.LastName, SOURCE.Salary, SOURCE.DepartmentID)
OUTPUT
    INSERTED.EmployeeID,
    INSERTED.FirstName,
    INSERTED.LastName,
    INSERTED.Salary,
    INSERTED.DepartmentID,
    GETDATE(),
    $action
INTO HR.EmployeeHistory;

-- =============================================
-- PART 5: Best Practices and Tips
-- =============================================

/*
1. Performance Considerations:
   - Include only necessary columns in MERGE
   - Use appropriate indexes on joining columns
   - Consider batch size for large operations

2. Error Handling:
   - Use TRY-CATCH blocks
   - Handle potential constraint violations
   - Log errors appropriately

3. Concurrency:
   - Use appropriate isolation levels
   - Consider using HOLDLOCK hint for consistency
   - Handle potential deadlocks

4. Maintenance:
   - Regular cleanup of history tables
   - Archive old data when necessary
   - Monitor performance metrics
*/

-- Example with error handling
BEGIN TRY
    BEGIN TRANSACTION;

    MERGE HR.Employees WITH (HOLDLOCK) AS TARGET
    USING @SourceEmployees AS SOURCE
    ON (TARGET.EmployeeID = SOURCE.EmployeeID)
    WHEN MATCHED THEN
        UPDATE SET
            TARGET.Salary = SOURCE.Salary,
            TARGET.ModifiedDate = GETDATE()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (EmployeeID, FirstName, LastName, Salary, DepartmentID)
        VALUES (SOURCE.EmployeeID, SOURCE.FirstName, SOURCE.LastName, SOURCE.Salary, SOURCE.DepartmentID);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    INSERT INTO HR.ErrorLog (ErrorNumber, ErrorMessage, ErrorLine, ErrorTime)
    VALUES (
        ERROR_NUMBER(),
        ERROR_MESSAGE(),
        ERROR_LINE(),
        GETDATE()
    );

    THROW;
END CATCH;

-- Cleanup
DROP TABLE #MergeLog;
GO