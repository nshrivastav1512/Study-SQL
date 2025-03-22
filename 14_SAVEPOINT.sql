-- =============================================
-- SAVEPOINT Operations Guide
-- =============================================
 /*
-- SAVEPOINT Complete Guide
-- SAVEPOINT in SQL Server creates intermediate points within a transaction that enable partial rollback capabilities. It provides granular control over transaction management by allowing specific portions of a transaction to be rolled back while maintaining the integrity of other operations.

Facts and Notes:
- Creates named restoration points within transactions
- Supports multiple savepoints in a single transaction
- Persists until transaction ends or explicit rollback
- Does not affect transaction nesting level
- Compatible with distributed transactions
- No limit on number of savepoints
- Savepoints are local to current transaction
- Memory usage increases with savepoint count

Important Considerations:
- Rolling back to a savepoint keeps the transaction active
- Savepoints are released after transaction completion
- Cannot access savepoints from other transactions
- Savepoint names must be unique within transaction
- Resource locks maintained after savepoint rollback
- Nested transactions can affect savepoint behavior
- Performance impact with excessive savepoints
- Transaction log records all savepoint operations

1. Basic SAVEPOINT: This section demonstrates fundamental usage of savepoints for basic transaction control and partial rollback capabilities.
2. Multiple SAVEPOINTS: This section shows managing multiple savepoints within a single transaction for different operation stages.
3. Nested SAVEPOINTS: This section covers implementing savepoints within nested transaction scenarios and proper management.
4. SAVEPOINT with Conditional Logic: This section illustrates using savepoints with business logic conditions for selective rollbacks.
5. SAVEPOINT with Error Recovery: This section demonstrates comprehensive error handling strategies using savepoints and transaction state management.
6. SAVEPOINT with Batch Processing: This section shows implementing savepoints in batch operations for granular error handling and recovery.
7. SAVEPOINT with Data Validation: This section covers using savepoints for data validation scenarios and maintaining data integrity.
8. SAVEPOINT with Multiple Recovery Points: This section illustrates managing multiple recovery points for complex transaction scenarios.
9. SAVEPOINT with Dynamic SQL: This section demonstrates using savepoints with dynamic SQL operations and proper error handling.
10. SAVEPOINT with Hierarchical Updates: This section shows managing parent-child relationship updates using savepoints for consistency.

Author: Nikhil Shrivastav
Date: February 2025
*/

USE HRSystem;
GO

-- 1. Basic SAVEPOINT
BEGIN TRANSACTION;
    INSERT INTO HR.Departments (DepartmentName, LocationID)
    VALUES ('Digital Marketing', 1);
    
    SAVE TRANSACTION DeptCreated;
    
    UPDATE HR.EMP_Details
    SET DepartmentID = SCOPE_IDENTITY()
    WHERE EmployeeID IN (1001, 1002);
    
    IF @@ERROR <> 0
        ROLLBACK TRANSACTION DeptCreated
    ELSE
        COMMIT TRANSACTION;

-- 2. Multiple SAVEPOINTS
BEGIN TRANSACTION;
    -- First Operation
    UPDATE HR.Departments
    SET Budget = Budget + 50000;
    SAVE TRANSACTION BudgetUpdate;
    
    -- Second Operation
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1;
    SAVE TRANSACTION SalaryUpdate;
    
    -- Third Operation
    INSERT INTO HR.AuditLog (Action, TableName)
    VALUES ('Mass Update', 'Multiple');
    
    IF @@ERROR <> 0
        ROLLBACK TRANSACTION SalaryUpdate
    ELSE
        COMMIT TRANSACTION;

-- 3. Nested SAVEPOINTS
BEGIN TRANSACTION MainTran;
    INSERT INTO HR.Departments (DepartmentName, LocationID)
    VALUES ('Operations', 1);
    
    SAVE TRANSACTION Level1Save;
    
    BEGIN TRANSACTION SubTran;
        UPDATE HR.EMP_Details
        SET DepartmentID = SCOPE_IDENTITY();
        
        SAVE TRANSACTION Level2Save;
        
        INSERT INTO HR.AuditLog (Action, TableName)
        VALUES ('Department Transfer', 'Multiple');
        
        IF @@ERROR <> 0
            ROLLBACK TRANSACTION Level2Save;
    
        IF  @@TRANCOUNT > 1
             COMMIT TRANSACTION SubTran;
        
    IF @@ERROR <> 0
        ROLLBACK TRANSACTION Level1Save
    ELSE
        COMMIT TRANSACTION MainTran;

-- 4. SAVEPOINT with Conditional Logic
BEGIN TRANSACTION;
    DECLARE @CurrentBudget DECIMAL(18,2);
    
    UPDATE HR.Departments
    SET Budget = Budget * 1.2;
    SAVE TRANSACTION BudgetIncrease;
    
    SELECT @CurrentBudget = SUM(Budget)
    FROM HR.Departments;
    
    IF @CurrentBudget > 5000000
    BEGIN
        ROLLBACK TRANSACTION BudgetIncrease;
        UPDATE HR.Departments
        SET Budget = Budget * 1.1;
    END
    
    COMMIT TRANSACTION;

-- 5. SAVEPOINT with Error Recovery
BEGIN TRY
    BEGIN TRANSACTION;
        -- First Critical Operation
        UPDATE HR.EMP_Details
        SET Salary = Salary * 1.15
        WHERE Performance_Rating = 5;
        SAVE TRANSACTION SalaryUpdate;
        
        -- Second Critical Operation
        UPDATE HR.Departments
        SET Budget = Budget - (
            SELECT SUM(Salary * 0.15)
            FROM HR.EMP_Details
            WHERE Performance_Rating = 5
        );
        
        IF @@ERROR <> 0
            ROLLBACK TRANSACTION SalaryUpdate;
            
        COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() = -1
        ROLLBACK TRANSACTION;
    ELSE IF XACT_STATE() = 1
        COMMIT TRANSACTION;
        
    INSERT INTO HR.ErrorLog (ErrorMessage)
    VALUES (ERROR_MESSAGE());
END CATCH;

-- 6. SAVEPOINT with Batch Processing
BEGIN TRANSACTION;
    DECLARE @DeptID INT = 1;
    
    WHILE @DeptID <= 5
    BEGIN
        SAVE TRANSACTION DeptPoint;
        
        UPDATE HR.EMP_Details
        SET Salary = Salary * 1.1
        WHERE DepartmentID = @DeptID;
        
        IF @@ERROR <> 0
        BEGIN
            ROLLBACK TRANSACTION DeptPoint;
            INSERT INTO HR.ErrorLog (ErrorMessage)
            VALUES ('Failed for Department: ' + CAST(@DeptID AS VARCHAR));
        END
        
        SET @DeptID = @DeptID + 1;
    END
    
    COMMIT TRANSACTION;

-- 7. SAVEPOINT with Data Validation
BEGIN TRANSACTION;
    -- Update Employee Data
    UPDATE HR.EMP_Details
    SET Email = LOWER(Email);
    SAVE TRANSACTION EmailUpdate;
    
    -- Validate Email Format
    IF EXISTS (
        SELECT 1 
        FROM HR.EMP_Details 
        WHERE Email NOT LIKE '%@%.%'
    )
    BEGIN
        ROLLBACK TRANSACTION EmailUpdate;
        THROW 50001, 'Invalid email format detected', 1;
    END
    
    COMMIT TRANSACTION;

-- 8. SAVEPOINT with Multiple Recovery Points
BEGIN TRANSACTION;
    -- Stage 1: Department Update
    UPDATE HR.Departments
    SET DepartmentName = UPPER(DepartmentName);
    SAVE TRANSACTION Stage1;
    
    -- Stage 2: Budget Update
    UPDATE HR.Departments
    SET Budget = Budget * 1.2;
    SAVE TRANSACTION Stage2;
    
    -- Stage 3: Employee Update
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1;
    SAVE TRANSACTION Stage3;
    
    -- Validation and Rollback Logic
    IF (SELECT SUM(Budget) FROM HR.Departments) > 10000000
        ROLLBACK TRANSACTION Stage2
    ELSE IF (SELECT AVG(Salary) FROM HR.EMP_Details) > 100000
        ROLLBACK TRANSACTION Stage3
    ELSE
        COMMIT TRANSACTION;

-- 9. SAVEPOINT with Dynamic SQL
BEGIN TRANSACTION;
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @TableName NVARCHAR(100) = 'HR.EMP_Details';
    
    SET @SQL = N'UPDATE ' + @TableName + 
               N' SET ModifiedDate = GETDATE()';
    
    SAVE TRANSACTION BeforeUpdate;
    EXEC sp_executesql @SQL;
    
    IF @@ERROR <> 0
        ROLLBACK TRANSACTION BeforeUpdate
    ELSE
        COMMIT TRANSACTION;

-- 10. SAVEPOINT with Hierarchical Updates
BEGIN TRANSACTION;
    -- Update Parent
    UPDATE HR.Departments
    SET ManagerID = 1001
    WHERE DepartmentID = 1;
    SAVE TRANSACTION ParentUpdate;
    
    -- Update Children
    UPDATE HR.EMP_Details
    SET ReportsTo = 1001
    WHERE DepartmentID = 1;
    
    IF @@ERROR <> 0
    BEGIN
        ROLLBACK TRANSACTION ParentUpdate;
        -- Revert to original state
    END
    ELSE
        COMMIT TRANSACTION;