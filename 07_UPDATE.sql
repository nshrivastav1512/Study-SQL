-- =============================================
-- UPDATE Operations Complete Guide
-- =============================================
/*
-- UPDATE Keyword Complete Guide
-- The UPDATE statement is a DML (Data Manipulation Language) command used to modify existing records in a database table. It allows for single-table updates, multi-table updates through JOINs, and updating data based on subqueries. The UPDATE statement can modify one or multiple columns in a single operation, with the ability to filter which rows are affected using WHERE clause and can be combined with FROM clause for more complex data modifications.

1. Basic UPDATE Operations: This section demonstrates the fundamental usage of UPDATE statement for single and multiple column updates, including handling column modifications and maintaining data integrity with proper WHERE clauses.
2. UPDATE with Computed Values: This section shows how to update data using calculations and subqueries, demonstrating arithmetic operations and filtering based on subquery results.
3. UPDATE with JOIN: This section illustrates updating data using JOIN operations, showing how to modify records based on conditions from multiple related tables while maintaining data consistency.
4. UPDATE with OUTPUT: This section demonstrates using the OUTPUT clause to capture both old and new values during updates, useful for auditing and verification purposes.
5. UPDATE with OUTPUT into Table: This section covers storing UPDATE operation results into temporary tables or table variables for further processing or audit trailing.
6. UPDATE with TOP: This section explains how to limit the number of rows affected by an UPDATE operation using the TOP clause, useful for batch processing and controlled updates.
7. UPDATE with CASE: This section shows how to implement conditional updates using CASE expressions, allowing different update logic based on various conditions.
8. UPDATE with Correlated Subquery: This section demonstrates using correlated subqueries in UPDATE statements to modify data based on related records within the same or different tables.
9. UPDATE with Transaction and Error Handling: This section covers implementing proper transaction management and error handling for UPDATE operations, including rollback scenarios.
10. UPDATE with Dynamic SQL: This section illustrates constructing and executing dynamic UPDATE statements safely, including proper parameter handling and SQL injection prevention.
11. UPDATE with TABLOCKX: This section explains using table hints for controlling locking behavior during UPDATE operations, including performance implications.
12. UPDATE with Partition: This section demonstrates updating data in partitioned tables, including partition-aware updates and optimizing performance.
13. UPDATE with FROM and Multiple Joins: This section covers complex UPDATE operations involving multiple table joins, showing how to update based on conditions from multiple related tables.
14. UPDATE with EXISTS: This section shows how to use EXISTS clause in UPDATE statements to modify data based on the existence of related records.

Author: Nikhil Shrivastav
Date: February 2025
*/

USE HRSystem;
GO

-- 1. Basic UPDATE Operations
-- 1.1 Single Column Update
UPDATE HR.EMP_Details
SET Salary = 55000
WHERE EmployeeID = 1000;

-- 1.2 Multiple Column Update
UPDATE HR.Departments
SET 
    DepartmentName = 'R&D',
    ModifiedDate = GETDATE()
WHERE DepartmentID = 1;

-- 2. UPDATE with Computed Values
UPDATE HR.EMP_Details
SET Salary = Salary * 1.1
WHERE DepartmentID IN (
    SELECT DepartmentID 
    FROM HR.Departments 
    WHERE DepartmentName = 'IT'
);

-- 3. UPDATE with JOIN
UPDATE e
SET 
    e.Salary = e.Salary * 1.15,
    e.ModifiedDate = GETDATE()
FROM HR.EMP_Details e
INNER JOIN HR.Performance_Reviews pr 
    ON e.EmployeeID = pr.EmployeeID
WHERE pr.Rating = 5;

-- 4. UPDATE with OUTPUT
UPDATE HR.EMP_Details
SET Salary = Salary * 1.05
OUTPUT 
    inserted.EmployeeID,
    deleted.Salary AS OldSalary,
    inserted.Salary AS NewSalary
WHERE DepartmentID = 2;

-- 5. UPDATE with OUTPUT into Table
DECLARE @SalaryChanges TABLE (
    EmployeeID INT,
    OldSalary DECIMAL(12,2),
    NewSalary DECIMAL(12,2),
    ModifiedDate DATETIME
);

UPDATE HR.EMP_Details
SET Salary = Salary * 1.03
OUTPUT 
    inserted.EmployeeID,
    deleted.Salary,
    inserted.Salary,
    GETDATE()
INTO @SalaryChanges
WHERE Salary < 50000;

-- 6. UPDATE with TOP
UPDATE TOP (5) HR.EMP_Details
SET ModifiedDate = GETDATE()
WHERE ModifiedDate IS NULL;

-- 7. UPDATE with CASE
UPDATE HR.EMP_Details
SET Salary = 
    CASE 
        WHEN Salary < 50000 THEN Salary * 1.1
        WHEN Salary BETWEEN 50000 AND 75000 THEN Salary * 1.07
        ELSE Salary * 1.05
    END;

-- 8. UPDATE with Correlated Subquery
UPDATE HR.Departments
SET ManagerID = (
    SELECT TOP 1 EmployeeID
    FROM HR.EMP_Details e
    WHERE e.DepartmentID = HR.Departments.DepartmentID
    ORDER BY HireDate ASC
);

-- 9. UPDATE with Transaction and Error Handling
BEGIN TRY
    BEGIN TRANSACTION;
        
        UPDATE HR.EMP_Details
        SET DepartmentID = 3
        WHERE DepartmentID = 2;

        -- Validate the update
        IF @@ROWCOUNT > 100  -- Business rule: Cannot move more than 100 employees
        BEGIN
            THROW 50001, 'Too many employees being moved', 1;
        END

        UPDATE HR.Departments
        SET ModifiedDate = GETDATE()
        WHERE DepartmentID IN (2, 3);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    INSERT INTO HR.AuditLog (Action, TableName, UserName)
    VALUES ('Failed Update', 'HR.EMP_Details', SYSTEM_USER);
    
    THROW;
END CATCH;

-- 10. UPDATE with Dynamic SQL
DECLARE @TableName NVARCHAR(100) = 'HR.EMP_Details';
DECLARE @SQL NVARCHAR(MAX);

SET @SQL = N'UPDATE ' + @TableName + 
          N' SET ModifiedDate = GETDATE()' +
          N' WHERE EmployeeID = @EmpID';

EXECUTE sp_executesql @SQL, 
    N'@EmpID INT',
    @EmpID = 1000;

-- 11. UPDATE with TABLOCKX (Table Lock)
UPDATE HR.Locations WITH (TABLOCKX)
SET ModifiedDate = GETDATE()
WHERE Country = 'USA';

-- 12. UPDATE with Partition
UPDATE HR.PartitionedEmployees
SET Department = 'Sales'
WHERE EmployeeID BETWEEN 1500 AND 2000;

-- 13. UPDATE with FROM and Multiple Joins
UPDATE pr
SET 
    pr.ReviewedBy = d.ManagerID,
    pr.ModifiedDate = GETDATE()
FROM HR.Performance_Reviews pr
INNER JOIN HR.EMP_Details e ON pr.EmployeeID = e.EmployeeID
INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE pr.ReviewedBy IS NULL;

-- 14. UPDATE with EXISTS
UPDATE HR.EMP_Details
SET Salary = Salary * 1.02
WHERE EXISTS (
    SELECT 1 
    FROM HR.Performance_Reviews 
    WHERE EmployeeID = HR.EMP_Details.EmployeeID 
    AND Rating > 4
);