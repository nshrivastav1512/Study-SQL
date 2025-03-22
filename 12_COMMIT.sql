-- =============================================
-- COMMIT Operations Guide
-- =============================================

USE HRSystem;
GO

-- 1. Basic COMMIT
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID = 1;
COMMIT;

-- 2. COMMIT with Multiple Operations
BEGIN TRANSACTION;
    -- First Operation
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID = 1;

    -- Second Operation
    INSERT INTO HR.AuditLog (Action, TableName)
    VALUES ('Salary Update', 'HR.EMP_Details');

    -- Third Operation
    UPDATE HR.Departments
    SET LastModifiedDate = GETDATE()
    WHERE DepartmentID = 1;
COMMIT TRANSACTION;

-- 3. COMMIT WORK (ANSI SQL Standard)
BEGIN TRANSACTION;
    INSERT INTO HR.Departments 
        (DepartmentName, LocationID)
    VALUES 
        ('Quality Assurance', 1);
COMMIT WORK;

-- 4. Conditional COMMIT
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.15
    WHERE Performance_Rating = 5;

    IF @@ROWCOUNT <= 10
        COMMIT TRANSACTION
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, 'Too many employees affected', 1;
    END;

-- 5. COMMIT with @@TRANCOUNT Check
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Email = LOWER(Email);

    BEGIN TRANSACTION;
        UPDATE HR.Departments
        SET DepartmentName = UPPER(DepartmentName);

        WHILE @@TRANCOUNT > 0
            COMMIT TRANSACTION;

-- 6. COMMIT with Delayed Durability
BEGIN TRANSACTION;
    INSERT INTO HR.AuditLog 
        (Action, TableName, ModifiedDate)
    VALUES 
        ('Batch Update', 'Multiple', GETDATE());
COMMIT TRANSACTION WITH (DELAYED_DURABILITY = ON);

-- 7. COMMIT with TRY-CATCH
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE HR.EMP_Details
        SET DepartmentID = 2
        WHERE DepartmentID = 1;

        UPDATE HR.Departments
        SET EmployeeCount = (
            SELECT COUNT(*) 
            FROM HR.EMP_Details 
            WHERE DepartmentID = 2
        )
        WHERE DepartmentID = 2;

        IF @@ERROR = 0
            COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    INSERT INTO HR.ErrorLog 
        (ErrorMessage, ErrorDate)
    VALUES 
        (ERROR_MESSAGE(), GETDATE());
END CATCH;

-- 8. COMMIT with Performance Monitoring
DECLARE @StartTime DATETIME = GETDATE();

BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET LastReviewDate = GETDATE()
    WHERE YEAR(LastReviewDate) < YEAR(GETDATE());

    INSERT INTO HR.PerformanceLog 
        (Operation, Duration, RowsAffected)
    VALUES 
        ('Review Date Update', 
         DATEDIFF(ms, @StartTime, GETDATE()),
         @@ROWCOUNT);
COMMIT;

-- 9. COMMIT with Explicit Transaction Mode
SET IMPLICIT_TRANSACTIONS OFF;
BEGIN TRANSACTION;
    MERGE HR.EMP_Details AS Target
    USING HR.TempEmployees AS Source
    ON Target.EmployeeID = Source.EmployeeID
    WHEN MATCHED THEN
        UPDATE SET Target.Salary = Source.Salary;

    IF XACT_STATE() = 1
        COMMIT TRANSACTION;

-- 10. COMMIT with Isolation Level
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;
    UPDATE HR.Departments
    SET Budget = Budget * 1.1
    WHERE YEAR(LastBudgetUpdate) < YEAR(GETDATE());
    
    IF @@ERROR = 0
        COMMIT TRANSACTION
    ELSE
        ROLLBACK TRANSACTION;