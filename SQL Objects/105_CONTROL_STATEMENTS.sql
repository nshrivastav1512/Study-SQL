-- =============================================
-- SQL Server Control Statements Guide
-- =============================================

USE HRSystem;
GO

-- =============================================
-- 1. IF-ELSE Statements
-- =============================================

-- Basic IF-ELSE structure
IF (SELECT COUNT(*) FROM HR.Employees) > 100
BEGIN
    PRINT 'Large company with more than 100 employees';
END
ELSE
BEGIN
    PRINT 'Small to medium company with 100 or fewer employees';
END;
GO

-- Creating a table for employee onboarding examples
CREATE TABLE HR.EmployeeOnboarding (
    OnboardingID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    HireDate DATE NOT NULL,
    IsDocumentationComplete BIT DEFAULT 0,
    IsEquipmentAssigned BIT DEFAULT 0,
    IsTrainingComplete BIT DEFAULT 0,
    OnboardingStatus VARCHAR(20) DEFAULT 'Pending',
    CompletionDate DATE NULL,
    CONSTRAINT FK_Onboarding_Employee FOREIGN KEY (EmployeeID) REFERENCES HR.Employees(EmployeeID)
);
GO

-- Nested IF-ELSE for complex onboarding status update
CREATE OR ALTER PROCEDURE HR.UpdateOnboardingStatus
    @OnboardingID INT
AS
BEGIN
    DECLARE @IsDocumentationComplete BIT, @IsEquipmentAssigned BIT, @IsTrainingComplete BIT;
    
    -- Get current status
    SELECT 
        @IsDocumentationComplete = IsDocumentationComplete,
        @IsEquipmentAssigned = IsEquipmentAssigned,
        @IsTrainingComplete = IsTrainingComplete
    FROM HR.EmployeeOnboarding
    WHERE OnboardingID = @OnboardingID;
    
    -- Update status based on completion criteria
    IF @IsDocumentationComplete = 1
    BEGIN
        IF @IsEquipmentAssigned = 1
        BEGIN
            IF @IsTrainingComplete = 1
            BEGIN
                -- All steps complete
                UPDATE HR.EmployeeOnboarding
                SET OnboardingStatus = 'Completed',
                    CompletionDate = GETDATE()
                WHERE OnboardingID = @OnboardingID;
                
                PRINT 'Onboarding process completed successfully.';
            END
            ELSE
            BEGIN
                -- Training pending
                UPDATE HR.EmployeeOnboarding
                SET OnboardingStatus = 'Training Pending'
                WHERE OnboardingID = @OnboardingID;
                
                PRINT 'Employee needs to complete training.';
            END
        END
        ELSE
        BEGIN
            -- Equipment pending
            UPDATE HR.EmployeeOnboarding
            SET OnboardingStatus = 'Equipment Pending'
            WHERE OnboardingID = @OnboardingID;
            
            PRINT 'Equipment needs to be assigned to employee.';
        END
    END
    ELSE
    BEGIN
        -- Documentation pending
        UPDATE HR.EmployeeOnboarding
        SET OnboardingStatus = 'Documentation Pending'
        WHERE OnboardingID = @OnboardingID;
        
        PRINT 'Employee documentation is incomplete.';
    END
    
    -- Return the updated status
    SELECT OnboardingStatus FROM HR.EmployeeOnboarding WHERE OnboardingID = @OnboardingID;
END;
GO

-- Using IF EXISTS for conditional execution
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'SalaryAdjustments' AND schema_id = SCHEMA_ID('HR'))
BEGIN
    PRINT 'Salary Adjustments table already exists';
END
ELSE
BEGIN
    CREATE TABLE HR.SalaryAdjustments (
        AdjustmentID INT IDENTITY(1,1) PRIMARY KEY,
        EmployeeID INT NOT NULL,
        AdjustmentDate DATE NOT NULL DEFAULT GETDATE(),
        PreviousSalary DECIMAL(15,2) NOT NULL,
        NewSalary DECIMAL(15,2) NOT NULL,
        AdjustmentReason VARCHAR(100) NOT NULL,
        ApprovedBy INT NOT NULL,
        CONSTRAINT FK_SalaryAdj_Employee FOREIGN KEY (EmployeeID) REFERENCES HR.Employees(EmployeeID),
        CONSTRAINT FK_SalaryAdj_Approver FOREIGN KEY (ApprovedBy) REFERENCES HR.Employees(EmployeeID)
    );
    
    PRINT 'Salary Adjustments table created successfully';
END;
GO

-- IF with comparison operators for salary adjustment approval
CREATE OR ALTER PROCEDURE HR.ApproveSalaryAdjustment
    @EmployeeID INT,
    @ProposedSalary DECIMAL(15,2),
    @ManagerID INT,
    @Reason VARCHAR(100)
AS
BEGIN
    DECLARE @CurrentSalary DECIMAL(15,2);
    DECLARE @ManagerLevel INT;
    DECLARE @PercentIncrease DECIMAL(5,2);
    
    -- Get current salary
    SELECT @CurrentSalary = Salary FROM HR.Employees WHERE EmployeeID = @EmployeeID;
    
    -- Get manager level (assuming 1=supervisor, 2=manager, 3=director, 4=executive)
    SELECT @ManagerLevel = JobLevel FROM HR.Employees WHERE EmployeeID = @ManagerID;
    
    -- Calculate percent increase
    SET @PercentIncrease = (@ProposedSalary - @CurrentSalary) * 100.0 / @CurrentSalary;
    
    -- Apply business rules for approval
    IF @PercentIncrease <= 5.0
    BEGIN
        -- Supervisors can approve up to 5%
        IF @ManagerLevel >= 1
        BEGIN
            EXEC HR.ProcessSalaryAdjustment @EmployeeID, @ProposedSalary, @ManagerID, @Reason;
            PRINT 'Salary adjustment approved by supervisor';
        END
        ELSE
        BEGIN
            PRINT 'Approver does not have sufficient privileges';
        END
    END
    ELSE IF @PercentIncrease <= 10.0
    BEGIN
        -- Managers can approve up to 10%
        IF @ManagerLevel >= 2
        BEGIN
            EXEC HR.ProcessSalaryAdjustment @EmployeeID, @ProposedSalary, @ManagerID, @Reason;
            PRINT 'Salary adjustment approved by manager';
        END
        ELSE
        BEGIN
            PRINT 'Approval requires manager level or higher';
        END
    END
    ELSE IF @PercentIncrease <= 20.0
    BEGIN
        -- Directors can approve up to 20%
        IF @ManagerLevel >= 3
        BEGIN
            EXEC HR.ProcessSalaryAdjustment @EmployeeID, @ProposedSalary, @ManagerID, @Reason;
            PRINT 'Salary adjustment approved by director';
        END
        ELSE
        BEGIN
            PRINT 'Approval requires director level or higher';
        END
    END
    ELSE
    BEGIN
        -- Executives can approve any amount over 20%
        IF @ManagerLevel >= 4
        BEGIN
            EXEC HR.ProcessSalaryAdjustment @EmployeeID, @ProposedSalary, @ManagerID, @Reason;
            PRINT 'Salary adjustment approved by executive';
        END
        ELSE
        BEGIN
            PRINT 'Approval requires executive level';
        END
    END
END;
GO

-- Helper procedure for salary adjustment
CREATE OR ALTER PROCEDURE HR.ProcessSalaryAdjustment
    @EmployeeID INT,
    @NewSalary DECIMAL(15,2),
    @ApprovedBy INT,
    @Reason VARCHAR(100)
AS
BEGIN
    DECLARE @CurrentSalary DECIMAL(15,2);
    
    -- Get current salary
    SELECT @CurrentSalary = Salary FROM HR.Employees WHERE EmployeeID = @EmployeeID;
    
    -- Insert adjustment record
    INSERT INTO HR.SalaryAdjustments (EmployeeID, PreviousSalary, NewSalary, AdjustmentReason, ApprovedBy)
    VALUES (@EmployeeID, @CurrentSalary, @NewSalary, @Reason, @ApprovedBy);
    
    -- Update employee salary
    UPDATE HR.Employees
    SET Salary = @NewSalary
    WHERE EmployeeID = @EmployeeID;
    
    PRINT 'Salary adjustment processed successfully';
END;
GO

-- =============================================
-- 2. CASE Statements
-- =============================================

-- Creating a table for performance evaluations
CREATE TABLE HR.PerformanceEvaluations (
    EvaluationID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    EvaluationYear INT NOT NULL,
    EvaluationQuarter TINYINT NOT NULL,
    PerformanceRating TINYINT NOT NULL, -- 1-5 scale
    Comments VARCHAR(1000) NULL,
    EvaluatedBy INT NOT NULL,
    EvaluationDate DATE NOT NULL DEFAULT GETDATE(),
    BonusPercentage DECIMAL(5,2) NULL,
    CONSTRAINT FK_Evaluation_Employee FOREIGN KEY (EmployeeID) REFERENCES HR.Employees(EmployeeID),
    CONSTRAINT FK_Evaluation_Evaluator FOREIGN KEY (EvaluatedBy) REFERENCES HR.Employees(EmployeeID),
    CONSTRAINT CK_PerformanceRating CHECK (PerformanceRating BETWEEN 1 AND 5)
);
GO

-- Simple CASE expression for performance rating descriptions
SELECT 
    EmployeeID,
    PerformanceRating,
    CASE PerformanceRating
        WHEN 1 THEN 'Needs Improvement'
        WHEN 2 THEN 'Meets Some Expectations'
        WHEN 3 THEN 'Meets Expectations'
        WHEN 4 THEN 'Exceeds Expectations'
        WHEN 5 THEN 'Outstanding'
        ELSE 'Not Rated'
    END AS RatingDescription
FROM HR.PerformanceEvaluations
WHERE EvaluationYear = 2023;
GO

-- Searched CASE expression for bonus calculation
CREATE OR ALTER PROCEDURE HR.CalculatePerformanceBonuses
    @EvaluationYear INT,
    @EvaluationQuarter TINYINT
AS
BEGIN
    -- Update bonus percentages based on performance ratings
    UPDATE HR.PerformanceEvaluations
    SET BonusPercentage = 
        CASE 
            WHEN PerformanceRating = 5 THEN 10.00 -- Outstanding: 10% bonus
            WHEN PerformanceRating = 4 THEN 7.50  -- Exceeds Expectations: 7.5% bonus
            WHEN PerformanceRating = 3 THEN 5.00  -- Meets Expectations: 5% bonus
            WHEN PerformanceRating = 2 THEN 2.50  -- Meets Some Expectations: 2.5% bonus
            WHEN PerformanceRating = 1 THEN 0.00  -- Needs Improvement: No bonus
            ELSE 0.00
        END
    WHERE EvaluationYear = @EvaluationYear
    AND EvaluationQuarter = @EvaluationQuarter;
    
    -- Return the updated bonus information
    SELECT 
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        pe.PerformanceRating,
        CASE pe.PerformanceRating
            WHEN 1 THEN 'Needs Improvement'
            WHEN 2 THEN 'Meets Some Expectations'
            WHEN 3 THEN 'Meets Expectations'
            WHEN 4 THEN 'Exceeds Expectations'
            WHEN 5 THEN 'Outstanding'
            ELSE 'Not Rated'
        END AS RatingDescription,
        pe.BonusPercentage,
        e.Salary * (pe.BonusPercentage / 100) AS BonusAmount
    FROM HR.PerformanceEvaluations pe
    JOIN HR.Employees e ON pe.EmployeeID = e.EmployeeID
    WHERE pe.EvaluationYear = @EvaluationYear
    AND pe.EvaluationQuarter = @EvaluationQuarter
    ORDER BY pe.PerformanceRating DESC, e.LastName, e.FirstName;
    
    PRINT 'Performance bonuses calculated for ' + 
          CAST(@EvaluationYear AS VARCHAR) + ' Q' + 
          CAST(@EvaluationQuarter AS VARCHAR);
END;
GO

-- CASE in ORDER BY clause for custom sorting
SELECT 
    d.DepartmentName,
    COUNT(e.EmployeeID) AS EmployeeCount,
    AVG(pe.PerformanceRating) AS AvgPerformanceRating
FROM HR.Departments d
JOIN HR.Employees e ON d.DepartmentID = e.DepartmentID
JOIN HR.PerformanceEvaluations pe ON e.EmployeeID = pe.EmployeeID
WHERE pe.EvaluationYear = 2023
GROUP BY d.DepartmentName
ORDER BY 
    -- Custom sort: HR first, then by average performance (descending)
    CASE 
        WHEN d.DepartmentName = 'Human Resources' THEN 0
        ELSE 1
    END,
    AVG(pe.PerformanceRating) DESC;
GO

-- Nested CASE expressions for complex categorization
SELECT 
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName AS EmployeeName,
    e.Salary,
    pe.PerformanceRating,
    CASE 
        WHEN e.Salary > 100000 THEN 
            CASE 
                WHEN pe.PerformanceRating >= 4 THEN 'High Performer - Executive'
                WHEN pe.PerformanceRating = 3 THEN 'Solid Performer - Executive'
                ELSE 'Underperforming - Executive'
            END
        WHEN e.Salary BETWEEN 70000 AND 100000 THEN
            CASE 
                WHEN pe.PerformanceRating >= 4 THEN 'High Performer - Manager'
                WHEN pe.PerformanceRating = 3 THEN 'Solid Performer - Manager'
                ELSE 'Underperforming - Manager'
            END
        ELSE
            CASE 
                WHEN pe.PerformanceRating >= 4 THEN 'High Performer - Staff'
                WHEN pe.PerformanceRating = 3 THEN 'Solid Performer - Staff'
                ELSE 'Underperforming - Staff'
            END
    END AS PerformanceCategory
FROM HR.Employees e
JOIN HR.PerformanceEvaluations pe ON e.EmployeeID = pe.EmployeeID
WHERE pe.EvaluationYear = 2023 AND pe.EvaluationQuarter = 4
ORDER BY e.Salary DESC, pe.PerformanceRating DESC;
GO

-- =============================================
-- 3. WHILE Loops
-- =============================================

-- Creating a table for payroll processing
CREATE TABLE HR.PayrollBatch (
    BatchID INT IDENTITY(1,1) PRIMARY KEY,
    BatchDate DATE NOT NULL DEFAULT GETDATE(),
    PayPeriodStart DATE NOT NULL,
    PayPeriodEnd DATE NOT NULL,
    TotalEmployees INT NOT NULL DEFAULT 0,
    TotalAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
    ProcessedBy INT NOT NULL,
    Status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    CONSTRAINT FK_PayrollBatch_Processor FOREIGN KEY (ProcessedBy) REFERENCES HR.Employees(EmployeeID)
);
GO

CREATE TABLE HR.PayrollDetail (
    PayrollDetailID INT IDENTITY(1,1) PRIMARY KEY,
    BatchID INT NOT NULL,
    EmployeeID INT NOT NULL,
    RegularHours DECIMAL(5,2) NOT NULL DEFAULT 0,
    OvertimeHours DECIMAL(5,2) NOT NULL DEFAULT 0,
    GrossPay DECIMAL(15,2) NOT NULL DEFAULT 0,
    Deductions DECIMAL(15,2) NOT NULL DEFAULT 0,
    NetPay DECIMAL(15,2) NOT NULL DEFAULT 0,
    ProcessingStatus VARCHAR(20) NOT NULL DEFAULT 'Pending',
    ProcessedDate DATETIME NULL,
    CONSTRAINT FK_PayrollDetail_Batch FOREIGN KEY (BatchID) REFERENCES HR.PayrollBatch(BatchID),
    CONSTRAINT FK_PayrollDetail_Employee FOREIGN KEY (EmployeeID) REFERENCES HR.Employees(EmployeeID)
);
GO

-- Basic WHILE loop for batch payroll processing
CREATE OR ALTER PROCEDURE HR.ProcessPayrollBatch
    @BatchID INT
AS
BEGIN
    DECLARE @EmployeeCount INT;
    DECLARE @ProcessedCount INT = 0;
    DECLARE @CurrentEmployeeID INT;
    DECLARE @BatchTotal DECIMAL(18,2) = 0;
    
    -- Get total number of employees in batch
    SELECT @EmployeeCount = COUNT(*) 
    FROM HR.PayrollDetail 
    WHERE BatchID = @BatchID AND ProcessingStatus = 'Pending';
    
    -- Update batch status to Processing
    UPDATE HR.PayrollBatch
    SET Status = 'Processing'
    WHERE BatchID = @BatchID;
    
    PRINT 'Starting payroll processing for ' + CAST(@EmployeeCount AS VARCHAR) + ' employees';
    
    -- Process each employee's payroll
    WHILE @ProcessedCount < @EmployeeCount
    BEGIN
        -- Get next employee to process
        SELECT TOP 1 @CurrentEmployeeID = EmployeeID
        FROM HR.PayrollDetail
        WHERE BatchID = @BatchID AND ProcessingStatus = 'Pending'
        ORDER BY EmployeeID;
        
        -- Process this employee's payroll (simplified for example)
        DECLARE @RegularHours DECIMAL(5,2), @OvertimeHours DECIMAL(5,2);
        DECLARE @HourlyRate DECIMAL(10,2), @OvertimeRate DECIMAL(10,2);
        DECLARE @GrossPay DECIMAL(15,2), @Deductions DECIMAL(15,2), @NetPay DECIMAL(15,2);
        
        -- Get employee details
        SELECT 
            @RegularHours = pd.RegularHours,
            @OvertimeHours = pd.OvertimeHours,
            @HourlyRate = e.Salary / 2080 -- Approximate hourly rate based on annual salary
        FROM HR.PayrollDetail pd
        JOIN HR.Employees e ON pd.EmployeeID = e.EmployeeID
        WHERE pd.BatchID = @BatchID AND pd.EmployeeID = @CurrentEmployeeID;
        
        -- Calculate overtime rate (1.5x regular rate)
        SET @OvertimeRate = @HourlyRate * 1.5;
        
        -- Calculate pay
        SET @GrossPay = (@RegularHours * @HourlyRate) + (@OvertimeHours * @OvertimeRate);
        SET @Deductions = @GrossPay * 0.3; -- Simplified: 30% for taxes, benefits, etc.
        SET @NetPay = @GrossPay - @Deductions;
        
        -- Update employee's payroll record
        UPDATE HR.PayrollDetail
        SET GrossPay = @GrossPay,
            Deductions = @Deductions,
            NetPay = @NetPay,
            ProcessingStatus = 'Completed',
            ProcessedDate = GETDATE()
        WHERE BatchID = @BatchID AND EmployeeID = @CurrentEmployeeID;
        
        -- Update batch total
        SET @BatchTotal = @BatchTotal + @NetPay;
        
        -- Increment counter
        SET @ProcessedCount = @ProcessedCount + 1;
        
        -- Progress update every 10 employees
        IF @ProcessedCount % 10 = 0
        BEGIN
            PRINT 'Processed ' + CAST(@ProcessedCount AS VARCHAR) + ' of ' + 
                  CAST(@EmployeeCount AS VARCHAR) + ' employees';
        END
        
        -- Simulate some processing time (would be removed in production)
        WAITFOR DELAY '00:00:00.01';
    END
    
    -- Update batch with final totals
    UPDATE HR.PayrollBatch
    SET TotalEmployees = @EmployeeCount,
        TotalAmount = @BatchTotal,
        Status = 'Completed'
    WHERE BatchID = @BatchID;
    
    PRINT 'Payroll processing completed. Total amount: $' + CAST(@BatchTotal AS VARCHAR);
END;
GO

-- WHILE loop with BREAK for early termination
CREATE OR ALTER PROCEDURE HR.AuditEmployeeSalaries
    @DepartmentID INT,
    @MaxDiscrepancies INT = 5
AS
BEGIN
    DECLARE @DiscrepancyCount INT = 0;
    DECLARE @EmployeeID INT;
    DECLARE @JobTitle VARCHAR(100);
    DECLARE @Salary DECIMAL(15,2);
    DECLARE @AvgSalaryForTitle DECIMAL(15,2);
    DECLARE @Difference DECIMAL(15,2);
    DECLARE @PercentDifference DECIMAL(5,2);
    
    -- Create temporary table for results
    CREATE TABLE #SalaryDiscrepancies (
        EmployeeID INT,
        EmployeeName VARCHAR(100),
        JobTitle VARCHAR(100),
        CurrentSalary DECIMAL(15,2),
        AvgSalaryForTitle DECIMAL(15,2),
        Difference DECIMAL(15,2),
        PercentDifference DECIMAL(5,2)
    );
    
    -- Declare cursor for employees in department
    DECLARE employee_cursor CURSOR FOR
    SELECT e.EmployeeID, e.JobTitle, e.Salary
    FROM HR.Employees e
    WHERE e.DepartmentID = @DepartmentID
    ORDER BY e.JobTitle, e.Salary;
    
    OPEN employee_cursor;
    FETCH NEXT FROM employee_cursor INTO @EmployeeID, @JobTitle, @Salary;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Get average salary for this job title
        SELECT @AvgSalaryForTitle = AVG(Salary)
        FROM HR.Employees
        WHERE JobTitle = @JobTitle AND DepartmentID = @DepartmentID;
        
        -- Calculate difference
        SET @Difference = @Salary - @AvgSalaryForTitle;
        SET @PercentDifference = (@Difference / @AvgSalaryForTitle) * 100;
        
        -- Check if significant discrepancy (more than 15% difference)
        IF ABS(@PercentDifference) > 15.0
        BEGIN
            INSERT INTO #SalaryDiscrepancies
            SELECT 
                @EmployeeID,
                (SELECT FirstName + ' ' + LastName FROM HR.Employees WHERE EmployeeID = @EmployeeID),
                @JobTitle,
                @Salary,
                @AvgSalaryForTitle,
                @Difference,
                @PercentDifference;
                
            SET @DiscrepancyCount = @DiscrepancyCount + 1;
            
            -- Break if we've found enough discrepancies
            IF @DiscrepancyCount >= @MaxDiscrepancies
            BEGIN
                PRINT 'Maximum number of discrepancies found. Stopping audit.';
                BREAK;
            END
        END
        
        FETCH NEXT FROM employee_cursor INTO @EmployeeID, @JobTitle, @Salary;
    END
    
    CLOSE employee_cursor;
    DEALLOCATE employee_cursor;
    
    -- Return results
    SELECT * FROM #SalaryDiscrepancies
    ORDER BY ABS(PercentDifference) DESC;
    
    -- Cleanup
    DROP TABLE #SalaryDiscrepancies;
    
    PRINT 'Salary audit completed. Found ' + CAST(@DiscrepancyCount AS VARCHAR) + ' discrepancies.';
END;
GO

-- WHILE loop with CONTINUE for skipping iterations
CREATE OR ALTER PROCEDURE HR.ProcessAnnualLeaveAccrual
AS
BEGIN
    DECLARE @EmployeeID INT;
    DECLARE @HireDate DATE;
    DECLARE @YearsOfService INT;
    DECLARE @CurrentLeaveBalance DECIMAL(5,1);
    DECLARE @LeaveAccrualRate DECIMAL(5,2);
    DECLARE @NewLeaveBalance DECIMAL(5,1);
    
    -- Create a temporary table for employees to process
    SELECT 
        EmployeeID,
        HireDate,
        DATEDIFF(YEAR, HireDate, GETDATE()) AS YearsOfService,
        LeaveBalance
    INTO #EmployeesToProcess
    FROM HR.Employees
    WHERE EmploymentStatus = 'Active';
    
    -- Create a temporary table for results
    CREATE TABLE #LeaveAccrualResults (
        EmployeeID INT,
        EmployeeName VARCHAR(100),
        YearsOfService INT,
        PreviousBalance DECIMAL(5,1),
        AccrualAmount DECIMAL(5,1),
        NewBalance DECIMAL(5,1)
    );
    
    -- Process each employee
    WHILE EXISTS (SELECT 1 FROM #EmployeesToProcess)
    BEGIN
        -- Get the next employee
        SELECT TOP 1 
            @EmployeeID = EmployeeID,
            @HireDate = HireDate,
            @YearsOfService = YearsOfService,
            @CurrentLeaveBalance = LeaveBalance
        FROM #EmployeesToProcess;
        
        -- Skip employees on probation (less than 6 months)
        IF DATEDIFF(MONTH, @HireDate, GETDATE()) < 6
        BEGIN
            DELETE FROM #EmployeesToProcess WHERE EmployeeID = @EmployeeID;
            CONTINUE;
        END
        
        -- Determine accrual rate based on years of service
        SET @LeaveAccrualRate = 
            CASE 
                WHEN @YearsOfService < 2 THEN 10.0  -- 10 days per year
                WHEN @YearsOfService < 5 THEN 15.0  -- 15 days per year
                WHEN @YearsOfService < 10 THEN 20.0 -- 20 days per year
                ELSE 25.0                           -- 25 days per year
            END;
        
        -- Calculate new balance (add annual accrual)
        SET @NewLeaveBalance = @CurrentLeaveBalance + @LeaveAccrualRate;
        
        -- Cap leave balance at maximum of 30 days if policy requires it
        IF @NewLeaveBalance > 30.0
        BEGIN
            SET @NewLeaveBalance = 30.0;
        END
        
        -- Update employee record
        UPDATE HR.Employees
        SET LeaveBalance = @NewLeaveBalance
        WHERE EmployeeID = @EmployeeID;
        
        -- Record the result
        INSERT INTO #LeaveAccrualResults
        SELECT 
            @EmployeeID,
            (SELECT FirstName + ' ' + LastName FROM HR.Employees WHERE EmployeeID = @EmployeeID),
            @YearsOfService,
            @CurrentLeaveBalance,
            @LeaveAccrualRate,
            @NewLeaveBalance;
        
        -- Remove processed employee
        DELETE FROM #EmployeesToProcess WHERE EmployeeID = @EmployeeID;
    END
    
    -- Return results
    SELECT * FROM #LeaveAccrualResults
    ORDER BY YearsOfService DESC, EmployeeName;
    
    -- Cleanup
    DROP TABLE #EmployeesToProcess;
    DROP TABLE #LeaveAccrualResults;
    
    PRINT 'Annual leave accrual processing completed.';
END;
GO

-- =============================================
-- 4. TRY-CATCH Error Handling
-- =============================================

-- Basic TRY-CATCH structure
CREATE OR ALTER PROCEDURE HR.UpdateEmployeeSalary
    @EmployeeID INT,
    @NewSalary DECIMAL(15,2)
AS
BEGIN
    BEGIN TRY
        -- Start transaction
        BEGIN TRANSACTION;
        
        -- Validate input
        IF @NewSalary <= 0
            THROW 50000, 'Salary must be greater than zero.', 1;
            
        -- Check if employee exists
        IF NOT EXISTS (SELECT 1 FROM HR.Employees WHERE EmployeeID = @EmployeeID)
            THROW 50001, 'Employee does not exist.', 1;
        
        -- Update salary
        UPDATE HR.Employees
        SET Salary = @NewSalary
        WHERE EmployeeID = @EmployeeID;
        
        -- Log the change
        INSERT INTO HR.SalaryAdjustments (EmployeeID, PreviousSalary, NewSalary, AdjustmentReason, ApprovedBy)
        SELECT 
            @EmployeeID,
            Salary,
            @NewSalary,
            'System Update',
            1 -- Assuming ID 1
        FROM HR.Employees
        WHERE EmployeeID = @EmployeeID;
        
        -- Commit transaction
        COMMIT TRANSACTION;
        
        PRINT 'Salary updated successfully.';
    END TRY
    BEGIN CATCH
        -- Rollback transaction if error occurs
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        -- Get error information
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        -- Log error (in a real system, you'd use proper error logging)
        PRINT 'Error: ' + @ErrorMessage;
        PRINT 'Severity: ' + CAST(@ErrorSeverity AS VARCHAR);
        PRINT 'State: ' + CAST(@ErrorState AS VARCHAR);
        
        -- Re-throw error to caller
        THROW;
    END CATCH;
END;
GO

-- Nested TRY-CATCH with transaction management
CREATE OR ALTER PROCEDURE HR.TransferEmployee
    @EmployeeID INT,
    @NewDepartmentID INT,
    @NewManagerID INT
AS
BEGIN
    DECLARE @OldDepartmentID INT;
    DECLARE @CurrentDate DATE = GETDATE();
    
    BEGIN TRY
        -- Start transaction
        BEGIN TRANSACTION;
        
        -- Get current department
        SELECT @OldDepartmentID = DepartmentID
        FROM HR.Employees
        WHERE EmployeeID = @EmployeeID;
        
        -- Validate input
        IF @OldDepartmentID IS NULL
            THROW 50001, 'Employee not found.', 1;
            
        IF NOT EXISTS (SELECT 1 FROM HR.Departments WHERE DepartmentID = @NewDepartmentID)
            THROW 50002, 'Target department does not exist.', 1;
            
        IF NOT EXISTS (SELECT 1 FROM HR.Employees WHERE EmployeeID = @NewManagerID)
            THROW 50003, 'New manager does not exist.', 1;
        
        BEGIN TRY
            -- Update employee record
            UPDATE HR.Employees
            SET DepartmentID = @NewDepartmentID,
                ManagerID = @NewManagerID,
                LastModifiedDate = @CurrentDate
            WHERE EmployeeID = @EmployeeID;
            
            -- Log the transfer
            INSERT INTO HR.EmployeeTransfers (
                EmployeeID,
                OldDepartmentID,
                NewDepartmentID,
                OldManagerID,
                NewManagerID,
                TransferDate
            )
            VALUES (
                @EmployeeID,
                @OldDepartmentID,
                @NewDepartmentID,
                (SELECT ManagerID FROM HR.Employees WHERE EmployeeID = @EmployeeID),
                @NewManagerID,
                @CurrentDate
            );
            
            -- Commit transaction
            COMMIT TRANSACTION;
            
            PRINT 'Employee transfer completed successfully.';
        END TRY
        BEGIN CATCH
            -- Handle specific errors
            IF ERROR_NUMBER() IN (547, 2627, 2601) -- Foreign key or unique constraint violations
            BEGIN
                THROW 50004, 'Database constraint violation. Transfer cannot be completed.', 1;
            END
            ELSE
                THROW; -- Re-throw other errors
        END CATCH;
    END TRY
    BEGIN CATCH
        -- Rollback transaction if error occurs
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        -- Log error details
        INSERT INTO HR.ErrorLog (
            ErrorNumber,
            ErrorSeverity,
            ErrorState,
            ErrorProcedure,
            ErrorLine,
            ErrorMessage,
            ErrorDate
        )
        VALUES (
            ERROR_NUMBER(),
            ERROR_SEVERITY(),
            ERROR_STATE(),
            ERROR_PROCEDURE(),
            ERROR_LINE(),
            ERROR_MESSAGE(),
            GETDATE()
        );
        
        -- Re-throw error to caller
        THROW;
    END CATCH;
END;
GO

-- =============================================
-- 5. WAITFOR Statement
-- =============================================

-- Example: Simulating payroll processing delays
CREATE OR ALTER PROCEDURE HR.ProcessPayrollWithNotifications
    @PayrollDate DATE
AS
BEGIN
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @EndTime DATETIME;
    DECLARE @ProcessingTime INT;
    
    PRINT 'Starting payroll processing at ' + CONVERT(VARCHAR, @StartTime, 120);
    
    -- Simulate initial processing delay
    WAITFOR DELAY '00:00:02';
    PRINT 'Initial data validation complete...';
    
    -- Simulate main processing
    WAITFOR DELAY '00:00:03';
    PRINT 'Processing employee salaries...';
    
    -- Simulate final calculations
    WAITFOR DELAY '00:00:02';
    
    SET @EndTime = GETDATE();
    SET @ProcessingTime = DATEDIFF(SECOND, @StartTime, @EndTime);
    
    PRINT 'Payroll processing completed at ' + CONVERT(VARCHAR, @EndTime, 120);
    PRINT 'Total processing time: ' + CAST(@ProcessingTime AS VARCHAR) + ' seconds';
END;
GO

-- Example: Scheduled task execution
CREATE OR ALTER PROCEDURE HR.ScheduleDailyReports
    @ExecutionTime TIME
AS
BEGIN
    DECLARE @CurrentTime TIME = CAST(GETDATE() AS TIME);
    DECLARE @WaitMessage VARCHAR(100);
    
    SET @WaitMessage = 'Waiting to generate reports at ' + CAST(@ExecutionTime AS VARCHAR);
    PRINT @WaitMessage;
    
    -- Wait until specified time
    -- Note: In production, you'd typically use SQL Server Agent instead
    WAITFOR TIME @ExecutionTime;
    
    -- Generate reports
    EXEC HR.GenerateEmployeeReport;
    EXEC HR.GenerateAttendanceReport;
    EXEC HR.GeneratePayrollSummary;
    
    PRINT 'Daily reports generated successfully at ' + CAST(GETDATE() AS VARCHAR);
END;
GO

-- =============================================
-- BEST PRACTICES AND GUIDELINES
-- =============================================

-- 1. Use BEGIN-END blocks for multi-statement sections
-- 2. Implement proper error handling with TRY-CATCH
-- 3. Use appropriate transaction management
-- 4. Avoid infinite loops with proper exit conditions
-- 5. Keep code modular and well-documented
-- 6. Use meaningful variable names
-- 7. Consider performance implications of control statements
-- 8. Test edge cases and boundary conditions
-- 9. Maintain consistent error handling patterns
-- 10. Use appropriate logging and monitoring