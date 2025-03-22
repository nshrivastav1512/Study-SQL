-- =============================================
-- DELETE Operations Complete Guide
-- =============================================

USE HRSystem;
GO

-- 1. Basic DELETE Operations
-- 1.1 Simple DELETE
DELETE FROM HR.Performance_Reviews
WHERE ReviewDate < DATEADD(YEAR, -3, GETDATE());

-- 1.2 DELETE with Subquery
DELETE FROM HR.EMP_Details
WHERE DepartmentID IN (
    SELECT DepartmentID
    FROM HR.Departments
    WHERE DepartmentName = 'Temporary'
);

-- 2. DELETE with JOIN
DELETE e
FROM HR.EMP_Details e
INNER JOIN HR.Departments d 
    ON e.DepartmentID = d.DepartmentID
WHERE d.IsActive = 0;

-- 3. DELETE with OUTPUT
DELETE FROM HR.Performance_Reviews
OUTPUT 
    deleted.ReviewID,
    deleted.EmployeeID,
    deleted.ReviewDate,
    deleted.Rating
WHERE Rating < 2;

-- 4. DELETE with OUTPUT into Table
DECLARE @DeletedEmployees TABLE (
    EmployeeID INT,
    FullName VARCHAR(100),
    DeletedDate DATETIME
);

DELETE FROM HR.EMP_Details
OUTPUT 
    deleted.EmployeeID,
    deleted.FirstName + ' ' + deleted.LastName,
    GETDATE()
INTO @DeletedEmployees
WHERE Salary < 30000;

-- 5. DELETE with TOP
DELETE TOP (10) 
FROM HR.AuditLog
WHERE LogDate < DATEADD(MONTH, -6, GETDATE());

-- 6. DELETE with Transaction and Error Handling
BEGIN TRY
    BEGIN TRANSACTION;
        
        DELETE FROM HR.Performance_Reviews
        WHERE EmployeeID IN (
            SELECT EmployeeID 
            FROM HR.EMP_Details 
            WHERE DepartmentID = 5
        );

        -- Validate the deletion
        IF @@ROWCOUNT > 50  -- Business rule: Cannot delete more than 50 reviews
        BEGIN
            THROW 50001, 'Too many reviews being deleted', 1;
        END

        DELETE FROM HR.EMP_Details
        WHERE DepartmentID = 5;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    INSERT INTO HR.AuditLog (Action, TableName, UserName)
    VALUES ('Failed Delete', 'HR.Performance_Reviews', SYSTEM_USER);
    
    THROW;
END CATCH;

-- 7. DELETE with Dynamic SQL
DECLARE @TableName NVARCHAR(100) = 'HR.AuditLog';
DECLARE @SQL NVARCHAR(MAX);

SET @SQL = N'DELETE FROM ' + @TableName + 
          N' WHERE LogDate < @OldDate';

EXECUTE sp_executesql @SQL, 
    N'@OldDate DATETIME',
    @OldDate = DATEADD(YEAR, -1, GETDATE());

-- 8. DELETE with Table Lock Hint
DELETE FROM HR.InventoryItems WITH (TABLOCKX)
WHERE Quantity = 0;

-- 9. DELETE with Partitioned Table
DELETE FROM HR.PartitionedEmployees
WHERE EmployeeID BETWEEN 1500 AND 2000;

-- 10. DELETE with EXISTS
DELETE FROM HR.Performance_Reviews
WHERE EXISTS (
    SELECT 1 
    FROM HR.EMP_Details 
    WHERE EmployeeID = Performance_Reviews.EmployeeID 
    AND TerminationDate IS NOT NULL
);

-- 11. DELETE with Multiple Joins
DELETE pr
FROM HR.Performance_Reviews pr
INNER JOIN HR.EMP_Details e ON pr.EmployeeID = e.EmployeeID
INNER JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE d.IsActive = 0 
AND e.TerminationDate IS NOT NULL;

-- 12. DELETE with CASE and Subquery
DELETE FROM HR.AuditLog
WHERE (
    CASE 
        WHEN TableName = 'HR.EMP_Details' THEN 
            CASE WHEN Action = 'UPDATE' THEN 1 
            ELSE 0 END
        WHEN TableName = 'HR.Departments' THEN 1
        ELSE 0
    END
) = 1;

-- 13. Batch DELETE (to prevent log growth)
WHILE 1 = 1
BEGIN
    DELETE TOP (1000)
    FROM HR.AuditLog
    WHERE LogDate < DATEADD(YEAR, -1, GETDATE());

    IF @@ROWCOUNT < 1000 BREAK;
    WAITFOR DELAY '00:00:01';
END;

-- 14. DELETE with Cross-Database Reference
-- Note: Requires appropriate permissions
/*
DELETE FROM HR.EMP_Details
WHERE EmployeeID IN (
    SELECT EmployeeID
    FROM Archive.dbo.TerminatedEmployees
);
*/