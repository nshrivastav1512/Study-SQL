-- =============================================
-- ALTER Keyword Complete Guide
-- =============================================

USE HRSystem;
GO

-- 1. Altering Database
ALTER DATABASE HRSystem
MODIFY NAME = HRSystemPro;
GO

-- Reverting for consistency with other scripts
ALTER DATABASE HRSystemPro
MODIFY NAME = HRSystem;
GO

-- 2. Altering Schema
-- Adding a new schema for executives
CREATE SCHEMA EXEC;
GO

-- Transferring ownership of a schema
ALTER AUTHORIZATION ON SCHEMA::EXEC TO dbo;
GO

-- 3. Altering Tables
-- 3.1 Adding columns
ALTER TABLE HR.Departments
ADD Description VARCHAR(200),
    IsActive BIT DEFAULT 1;

-- 3.2 Modifying columns
ALTER TABLE HR.Locations
ALTER COLUMN City VARCHAR(100);

-- 3.3 Adding constraints
ALTER TABLE HR.Departments
ADD CONSTRAINT FK_Departments_Locations
FOREIGN KEY (LocationID) REFERENCES HR.Locations(LocationID);

ALTER TABLE HR.Departments
ADD CONSTRAINT FK_Departments_Manager
FOREIGN KEY (ManagerID) REFERENCES HR.EMP_Details(EmployeeID);

-- 3.4 Dropping constraints
ALTER TABLE HR.EMP_Details
DROP CONSTRAINT CHK_Salary;

-- 3.5 Adding a new check constraint
ALTER TABLE HR.EMP_Details
ADD CONSTRAINT CHK_Salary_Range CHECK (Salary BETWEEN 1000 AND 500000);

-- 3.6 Enabling/Disabling constraints
ALTER TABLE HR.EMP_Details
NOCHECK CONSTRAINT CHK_Salary_Range;

ALTER TABLE HR.EMP_Details
CHECK CONSTRAINT CHK_Salary_Range;

-- 4. Altering Indexes
-- 4.1 Disabling an index
ALTER INDEX IX_EMP_Details_Email
ON HR.EMP_Details DISABLE;

-- 4.2 Rebuilding an index
ALTER INDEX IX_EMP_Details_Email
ON HR.EMP_Details REBUILD;

-- 4.3 Reorganizing an index
ALTER INDEX IX_EMP_Details_DepartmentID
ON HR.EMP_Details REORGANIZE;

-- 5. Altering Views
ALTER VIEW HR.vw_EmployeeDetails
AS
SELECT 
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS FullName,
    e.Email,
    d.DepartmentName,
    d.Description AS DepartmentDescription,
    l.City,
    l.State,
    l.Country,
    e.Salary,
    HR.fn_GetEmployeeYearsOfService(e.EmployeeID) AS YearsOfService
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
JOIN HR.Locations l ON d.LocationID = l.LocationID;
GO

-- 6. Altering Stored Procedures
ALTER PROCEDURE HR.sp_UpdateEmployeeSalary
    @EmployeeID INT,
    @NewSalary DECIMAL(12,2),
    @EffectiveDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Set default effective date if not provided
    IF @EffectiveDate IS NULL
        SET @EffectiveDate = GETDATE();
    
    -- Validate salary range
    IF @NewSalary < 1000 OR @NewSalary > 500000
    BEGIN
        THROW 50000, 'Salary must be between $1,000 and $500,000', 1;
        RETURN;
    END
    
    BEGIN TRY
        BEGIN TRANSACTION;
            -- Store old salary in history
            INSERT INTO PAYROLL.Salary_History (EmployeeID, OldSalary, NewSalary, EffectiveDate)
            SELECT 
                EmployeeID, 
                Salary AS OldSalary, 
                @NewSalary AS NewSalary,
                @EffectiveDate
            FROM HR.EMP_Details 
            WHERE EmployeeID = @EmployeeID;

            -- Update new salary
            UPDATE HR.EMP_Details
            SET Salary = @NewSalary,
                ModifiedDate = GETDATE()
            WHERE EmployeeID = @EmployeeID;

        COMMIT TRANSACTION;
        
        -- Return success message
        SELECT 'Salary updated successfully' AS Result;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        -- Return error information
        SELECT 
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_SEVERITY() AS ErrorSeverity,
            ERROR_STATE() AS ErrorState,
            ERROR_PROCEDURE() AS ErrorProcedure,
            ERROR_LINE() AS ErrorLine,
            ERROR_MESSAGE() AS ErrorMessage;
    END CATCH;
END;
GO

-- 7. Altering Functions
ALTER FUNCTION HR.fn_GetEmployeeYearsOfService
(
    @EmployeeID INT
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @YearsOfService DECIMAL(5,2);
    
    SELECT @YearsOfService = DATEDIFF(DAY, HireDate, GETDATE()) / 365.25
    FROM HR.EMP_Details
    WHERE EmployeeID = @EmployeeID;
    
    RETURN ROUND(@YearsOfService, 2);
END;
GO

-- 8. Altering Triggers
-- First, drop the existing trigger
DROP TRIGGER IF EXISTS HR.trg_UpdateModifiedDate;
GO

-- Then create a new, more comprehensive trigger
CREATE TRIGGER HR.trg_AuditEmployeeChanges
ON HR.EMP_Details
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Update ModifiedDate
    UPDATE HR.EMP_Details
    SET ModifiedDate = GETDATE()
    FROM HR.EMP_Details e
    INNER JOIN inserted i ON e.EmployeeID = i.EmployeeID;
    
    -- Create audit table if it doesn't exist
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'EMP_Details_Audit' AND schema_id = SCHEMA_ID('HR'))
    BEGIN
        CREATE TABLE HR.EMP_Details_Audit (
            AuditID INT PRIMARY KEY IDENTITY(1,1),
            EmployeeID INT,
            FieldModified VARCHAR(50),
            OldValue VARCHAR(MAX),
            NewValue VARCHAR(MAX),
            ModifiedDate DATETIME DEFAULT GETDATE(),
            ModifiedBy VARCHAR(100) DEFAULT SYSTEM_USER
        );
    END
    
    -- Insert audit records for salary changes
    INSERT INTO HR.EMP_Details_Audit (EmployeeID, FieldModified, OldValue, NewValue)
    SELECT 
        i.EmployeeID,
        'Salary',
        CAST(d.Salary AS VARCHAR(50)),
        CAST(i.Salary AS VARCHAR(50))
    FROM deleted d
    INNER JOIN inserted i ON d.EmployeeID = i.EmployeeID
    WHERE d.Salary <> i.Salary;
    
    -- Insert audit records for department changes
    INSERT INTO HR.EMP_Details_Audit (EmployeeID, FieldModified, OldValue, NewValue)
    SELECT 
        i.EmployeeID,
        'DepartmentID',
        CAST(d.DepartmentID AS VARCHAR(50)),
        CAST(i.DepartmentID AS VARCHAR(50))
    FROM deleted d
    INNER JOIN inserted i ON d.EmployeeID = i.EmployeeID
    WHERE d.DepartmentID <> i.DepartmentID OR 
          (d.DepartmentID IS NULL AND i.DepartmentID IS NOT NULL) OR
          (d.DepartmentID IS NOT NULL AND i.DepartmentID IS NULL);
END;
GO

-- 9. Altering Table Structure for New Business Requirements
-- Adding a new table for performance reviews
CREATE TABLE HR.Performance_Reviews (
    ReviewID INT PRIMARY KEY IDENTITY(1,1),
    EmployeeID INT FOREIGN KEY REFERENCES HR.EMP_Details(EmployeeID),
    ReviewDate DATE,
    Rating INT CHECK (Rating BETWEEN 1 AND 5),
    Comments VARCHAR(MAX),
    ReviewedBy INT,
    CreatedDate DATETIME DEFAULT GETDATE()
);
GO

-- Now alter it to add a foreign key for the reviewer
ALTER TABLE HR.Performance_Reviews
ADD CONSTRAINT FK_Performance_Reviews_Reviewer
FOREIGN KEY (ReviewedBy) REFERENCES HR.EMP_Details(EmployeeID);
GO

-- 10. Altering Database Security
-- Create a new user
CREATE USER HRManager WITHOUT LOGIN;
GO

-- Alter user to add to a role
ALTER ROLE db_datareader ADD MEMBER HRManager;
GO

-- Grant specific permissions
GRANT EXECUTE ON HR.sp_UpdateEmployeeSalary TO HRManager;
GO

-- Alter permissions
REVOKE SELECT ON HR.EMP_Details TO HRManager;
GRANT SELECT ON HR.vw_EmployeeDetails TO HRManager;
GO