-- =============================================
-- SQL Server CURSORS Guide
-- =============================================

USE HRSystem;
GO

-- 1. Basic Cursor Example
-- Declare variables for cursor
DECLARE @EmployeeID INT, @FirstName NVARCHAR(50), @Salary DECIMAL(10,2);

-- Declare and define cursor
DECLARE employee_cursor CURSOR FOR
    SELECT EmployeeID, FirstName, Salary
    FROM HR.Employees
    WHERE DepartmentID = 10;

-- Open cursor
OPEN employee_cursor;

-- Fetch first row
FETCH NEXT FROM employee_cursor INTO @EmployeeID, @FirstName, @Salary;

-- Process rows
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Process each employee
    PRINT 'Processing employee: ' + @FirstName;
    
    -- Update salary with 5% increase
    UPDATE HR.Employees
    SET Salary = Salary * 1.05
    WHERE EmployeeID = @EmployeeID;
    
    FETCH NEXT FROM employee_cursor INTO @EmployeeID, @FirstName, @Salary;
END

-- Clean up cursor
CLOSE employee_cursor;
DEALLOCATE employee_cursor;
GO

-- 2. Different Cursor Types
-- Static Cursor (snapshot of data)
DECLARE static_cursor CURSOR STATIC FOR
    SELECT EmployeeID FROM HR.Employees;

-- Dynamic Cursor (sees changes)
DECLARE dynamic_cursor CURSOR DYNAMIC FOR
    SELECT EmployeeID FROM HR.Employees;

-- Fast Forward-Only Cursor (best performance)
DECLARE ff_cursor CURSOR FAST_FORWARD FOR
    SELECT EmployeeID FROM HR.Employees;

-- Scroll Cursor (can move in any direction)
DECLARE scroll_cursor CURSOR SCROLL FOR
    SELECT EmployeeID FROM HR.Employees;

-- 3. Cursor Variables
DECLARE @MyCursor CURSOR;
SET @MyCursor = CURSOR FAST_FORWARD FOR
    SELECT EmployeeID FROM HR.Employees;

-- 4. Nested Cursors Example
DECLARE @DeptID INT, @DeptName NVARCHAR(50);
DECLARE @EmpCount INT;

-- Outer cursor for departments
DECLARE dept_cursor CURSOR FOR
    SELECT DepartmentID, DepartmentName
    FROM HR.Departments;

OPEN dept_cursor;
FETCH NEXT FROM dept_cursor INTO @DeptID, @DeptName;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Inner cursor for employees in each department
    DECLARE emp_cursor CURSOR FOR
        SELECT COUNT(*)
        FROM HR.Employees
        WHERE DepartmentID = @DeptID;
    
    OPEN emp_cursor;
    FETCH NEXT FROM emp_cursor INTO @EmpCount;
    
    PRINT 'Department: ' + @DeptName + ' has ' + CAST(@EmpCount AS NVARCHAR(10)) + ' employees';
    
    CLOSE emp_cursor;
    DEALLOCATE emp_cursor;
    
    FETCH NEXT FROM dept_cursor INTO @DeptID, @DeptName;
END

CLOSE dept_cursor;
DEALLOCATE dept_cursor;
GO

-- 5. Cursor Attributes
DECLARE custom_cursor CURSOR
    LOCAL                   -- Scope limited to batch/procedure/trigger
    FORWARD_ONLY           -- Can only move forward
    STATIC                 -- Data snapshot
    READ_ONLY             -- No updates through cursor
    TYPE_WARNING          -- Warn if cursor is implicitly converted
FOR
    SELECT EmployeeID FROM HR.Employees;

-- 6. Performance Best Practices
-- 1. Use SET NOCOUNT ON to reduce network traffic
SET NOCOUNT ON;

-- 2. Use FAST_FORWARD when possible
DECLARE perf_cursor CURSOR FAST_FORWARD FOR
    SELECT EmployeeID FROM HR.Employees;

-- 3. Process in batches
DECLARE @BatchSize INT = 1000;
DECLARE @ProcessedCount INT = 0;

-- 4. Use appropriate isolation level
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- 7. Error Handling with Cursors
BEGIN TRY
    DECLARE @ID INT;
    
    DECLARE error_cursor CURSOR FOR
        SELECT EmployeeID FROM HR.Employees;
    
    OPEN error_cursor;
    FETCH NEXT FROM error_cursor INTO @ID;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            -- Process each row
            -- Add your processing logic here
            FETCH NEXT FROM error_cursor INTO @ID;
        END TRY
        BEGIN CATCH
            -- Log error and continue with next record
            INSERT INTO ErrorLog (ErrorMessage, ErrorDate)
            VALUES (ERROR_MESSAGE(), GETDATE());
        END CATCH
    END
    
    CLOSE error_cursor;
    DEALLOCATE error_cursor;
END TRY
BEGIN CATCH
    -- Handle cursor-level errors
    IF (SELECT CURSOR_STATUS('global','error_cursor')) >= 0
    BEGIN
        CLOSE error_cursor;
        DEALLOCATE error_cursor;
    END
    
    THROW;
END CATCH;
GO

-- 8. Common Cursor Operations
-- FETCH operations
DECLARE @Value INT;
DECLARE ops_cursor CURSOR SCROLL FOR
    SELECT EmployeeID FROM HR.Employees;

OPEN ops_cursor;

FETCH FIRST FROM ops_cursor INTO @Value;   -- First row
FETCH LAST FROM ops_cursor INTO @Value;    -- Last row
FETCH PRIOR FROM ops_cursor INTO @Value;   -- Previous row
FETCH ABSOLUTE 5 FROM ops_cursor INTO @Value; -- 5th row
FETCH RELATIVE -2 FROM ops_cursor INTO @Value; -- 2 rows back

CLOSE ops_cursor;
DEALLOCATE ops_cursor;

-- 9. Alternative to Cursors (Set-based Operations)
-- Instead of cursor, use set-based operation
UPDATE e
SET Salary = Salary * 1.05
FROM HR.Employees e
WHERE DepartmentID = 10;

-- Using window functions instead of cursors
SELECT 
    EmployeeID,
    FirstName,
    Salary,
    LAG(Salary) OVER (ORDER BY EmployeeID) AS PreviousSalary,
    LEAD(Salary) OVER (ORDER BY EmployeeID) AS NextSalary
FROM HR.Employees;

-- Using recursive CTE instead of cursor
WITH EmployeeHierarchy AS (
    SELECT EmployeeID, ManagerID, FirstName, 1 AS Level
    FROM HR.Employees
    WHERE ManagerID IS NULL
    
    UNION ALL
    
    SELECT e.EmployeeID, e.ManagerID, e.FirstName, eh.Level + 1
    FROM HR.Employees e
    INNER JOIN EmployeeHierarchy eh ON e.ManagerID = eh.EmployeeID
)
SELECT * FROM EmployeeHierarchy;
GO