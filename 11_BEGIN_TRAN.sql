-- =============================================
-- BEGIN TRANSACTION Operations Guide
-- =============================================

USE HRSystem;
GO

-- 1. Basic Transaction
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE HR.EMP_Details
        SET Salary = Salary * 1.1
        WHERE DepartmentID = 1;

        INSERT INTO HR.AuditLog (Action, TableName)
        VALUES ('Salary Update', 'HR.EMP_Details');
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;
END CATCH;

-- 2. Named Transaction
BEGIN TRANSACTION SalaryUpdate
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.05
    WHERE EmployeeID = 1000;

    IF @@ERROR = 0
        COMMIT TRANSACTION SalaryUpdate
    ELSE
        ROLLBACK TRANSACTION SalaryUpdate;

-- 3. Nested Transactions
BEGIN TRANSACTION OuterTran;
    INSERT INTO HR.Departments (DepartmentName, LocationID)
    VALUES ('New Department', 1);

    BEGIN TRANSACTION InnerTran;
        INSERT INTO HR.EMP_Details 
            (FirstName, LastName, Email, DepartmentID)
        VALUES 
            ('John', 'Doe', 'john@hr.com', SCOPE_IDENTITY());

        IF @@TRANCOUNT > 0
            COMMIT TRANSACTION InnerTran;
    
    IF @@ERROR = 0
        COMMIT TRANSACTION OuterTran
    ELSE
        ROLLBACK TRANSACTION OuterTran;

-- 4. Transaction with Save Points
BEGIN TRANSACTION;
    INSERT INTO HR.Departments (DepartmentName, LocationID)
    VALUES ('IT Support', 1);
    
    SAVE TRANSACTION DeptCreated;

    INSERT INTO HR.EMP_Details 
        (FirstName, LastName, Email, DepartmentID)
    VALUES 
        ('Jane', 'Smith', 'jane@hr.com', SCOPE_IDENTITY());

    IF @@ERROR <> 0
        ROLLBACK TRANSACTION DeptCreated;
    ELSE
        COMMIT TRANSACTION;

-- 5. Marked Transaction
BEGIN TRANSACTION ProcessPayroll WITH MARK 'Monthly Payroll Update';
    UPDATE HR.EMP_Details
    SET LastPaymentDate = GETDATE()
    WHERE LastPaymentDate IS NULL;

    IF @@ROWCOUNT > 100
        ROLLBACK TRANSACTION ProcessPayroll
    ELSE
        COMMIT TRANSACTION ProcessPayroll;

-- 6. Transaction with Isolation Level
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
    UPDATE HR.EMP_Details
    SET Salary = Salary * 1.1
    WHERE DepartmentID IN (
        SELECT DepartmentID 
        FROM HR.Departments 
        WHERE DepartmentName = 'IT'
    );
COMMIT TRANSACTION;

-- 7. Distributed Transaction
BEGIN DISTRIBUTED TRANSACTION;
    -- First database operation
    INSERT INTO HR.AuditLog (Action, TableName)
    VALUES ('Start Distributed', 'Multiple');

    -- Second database operation (commented as example)
    /*
    INSERT INTO RemoteDB.HR.AuditLog (Action, TableName)
    VALUES ('Remote Update', 'Remote.Table');
    */
COMMIT TRANSACTION;

-- 8. Transaction with Error Handling and State Check
BEGIN TRY
    BEGIN TRANSACTION;
        INSERT INTO HR.Departments (DepartmentName, LocationID)
        VALUES ('Test Dept', 1);

        -- Intentional error for demonstration
        UPDATE HR.EMP_Details
        SET DepartmentID = 999; -- Non-existent department

        IF XACT_STATE() = -1
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 51000, 'Transaction failed', 1;
        END
        ELSE IF XACT_STATE() = 1
            COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    
    INSERT INTO HR.ErrorLog (ErrorMessage)
    VALUES (ERROR_MESSAGE());
END CATCH;