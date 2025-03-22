-- =============================================
-- SAVEPOINT Operations Guide
-- =============================================

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