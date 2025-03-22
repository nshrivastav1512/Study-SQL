-- =============================================
-- SQL Server USER-DEFINED FUNCTIONS Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating a Scalar Function (returns a single value)
CREATE FUNCTION fn_CalculateProjectDuration
(
    @StartDate DATE,
    @EndDate DATE
)
RETURNS INT
AS
BEGIN
    DECLARE @Duration INT;
    
    -- Calculate the duration in days
    SET @Duration = DATEDIFF(DAY, @StartDate, @EndDate);
    
    -- Return the result
    RETURN @Duration;
END;
GO

-- 2. Creating an Inline Table-Valued Function (returns a table)
CREATE FUNCTION fn_GetProjectsByStatus
(
    @Status VARCHAR(20)
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        ProjectID,
        ProjectName,
        StartDate,
        EndDate,
        Budget,
        Status,
        Description
    FROM Projects
    WHERE Status = @Status
);
GO

-- 3. Creating a Multi-Statement Table-Valued Function
CREATE FUNCTION fn_GetProjectPerformanceMetrics
(
    @ProjectID INT
)
RETURNS @Results TABLE
(
    MetricName VARCHAR(50),
    MetricValue DECIMAL(18,2),
    MetricUnit VARCHAR(20),
    EvaluationDate DATETIME
)
AS
BEGIN
    -- Budget metrics
    DECLARE @Budget DECIMAL(15,2);
    DECLARE @ActualCost DECIMAL(15,2);
    DECLARE @BudgetVariance DECIMAL(15,2);
    DECLARE @BudgetUtilization DECIMAL(5,2);
    
    -- Time metrics
    DECLARE @PlannedDuration INT;
    DECLARE @ElapsedDays INT;
    DECLARE @RemainingDays INT;
    DECLARE @TimeProgress DECIMAL(5,2);
    
    -- Get project data
    SELECT 
        @Budget = Budget,
        @PlannedDuration = DATEDIFF(DAY, StartDate, EndDate),
        @ElapsedDays = DATEDIFF(DAY, StartDate, GETDATE())
    FROM Projects
    WHERE ProjectID = @ProjectID;
    
    -- Get actual costs
    SELECT @ActualCost = ISNULL(SUM(ActualCost), 0)
    FROM ProjectBudgetItems
    WHERE ProjectID = @ProjectID;
    
    -- Calculate derived metrics
    SET @BudgetVariance = @Budget - @ActualCost;
    SET @BudgetUtilization = CASE WHEN @Budget = 0 THEN 0 ELSE (@ActualCost / @Budget) * 100 END;
    SET @RemainingDays = @PlannedDuration - @ElapsedDays;
    SET @TimeProgress = CASE WHEN @PlannedDuration = 0 THEN 0 ELSE (@ElapsedDays / CAST(@PlannedDuration AS DECIMAL(10,2))) * 100 END;
    
    -- Insert metrics into result table
    INSERT INTO @Results (MetricName, MetricValue, MetricUnit, EvaluationDate)
    VALUES 
        ('Budget', @Budget, 'Currency', GETDATE()),
        ('Actual Cost', @ActualCost, 'Currency', GETDATE()),
        ('Budget Variance', @BudgetVariance, 'Currency', GETDATE()),
        ('Budget Utilization', @BudgetUtilization, 'Percentage', GETDATE()),
        ('Planned Duration', @PlannedDuration, 'Days', GETDATE()),
        ('Elapsed Days', @ElapsedDays, 'Days', GETDATE()),
        ('Remaining Days', @RemainingDays, 'Days', GETDATE()),
        ('Time Progress', @TimeProgress, 'Percentage', GETDATE());
    
    -- Get milestone completion
    DECLARE @MilestoneCompletion DECIMAL(5,2);
    
    SELECT @MilestoneCompletion = AVG(CompletionPercentage)
    FROM ProjectMilestones
    WHERE ProjectID = @ProjectID;
    
    INSERT INTO @Results (MetricName, MetricValue, MetricUnit, EvaluationDate)
    VALUES ('Milestone Completion', ISNULL(@MilestoneCompletion, 0), 'Percentage', GETDATE());
    
    RETURN;
END;
GO

-- 4. Creating a Function with Table Parameter
CREATE FUNCTION fn_CalculateTotalCost
(
    @Items ProjectBudgetItemsTableType READONLY
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @TotalCost DECIMAL(18,2);
    
    SELECT @TotalCost = SUM(EstimatedCost)
    FROM @Items;
    
    RETURN ISNULL(@TotalCost, 0);
END;
GO

-- 5. Creating a Function with CASE Statement
CREATE FUNCTION fn_GetProjectStatusCategory
(
    @Status VARCHAR(20)
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @Category VARCHAR(20);
    
    SELECT @Category = CASE 
        WHEN @Status = 'Not Started' THEN 'Future'
        WHEN @Status = 'Planning' THEN 'Preparation'
        WHEN @Status = 'In Progress' THEN 'Active'
        WHEN @Status IN ('Completed', 'Cancelled') THEN 'Finished'
        ELSE 'Unknown'
    END;
    
    RETURN @Category;
END;
GO

-- 6. Creating a Function with Error Handling
CREATE FUNCTION fn_GetProjectBudgetUtilization
(
    @ProjectID INT
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @Budget DECIMAL(15,2);
    DECLARE @ActualCost DECIMAL(15,2);
    DECLARE @Utilization DECIMAL(5,2);
    
    -- Get project budget
    SELECT @Budget = Budget
    FROM Projects
    WHERE ProjectID = @ProjectID;
    
    -- Check if project exists
    IF @Budget IS NULL
        RETURN -1; -- Error: Project not found
    
    -- Get actual costs
    SELECT @ActualCost = ISNULL(SUM(ActualCost), 0)
    FROM ProjectBudgetItems
    WHERE ProjectID = @ProjectID;
    
    -- Calculate utilization percentage
    IF @Budget = 0
        SET @Utilization = 0; -- Avoid division by zero
    ELSE
        SET @Utilization = (@ActualCost / @Budget) * 100;
    
    RETURN @Utilization;
END;
GO

-- 7. Creating a Recursive Function
CREATE FUNCTION fn_CalculateFactorial
(
    @Number INT
)
RETURNS BIGINT
AS
BEGIN
    -- Base case
    IF @Number <= 1
        RETURN 1;
    
    -- Recursive case
    RETURN @Number * dbo.fn_CalculateFactorial(@Number - 1);
END;
GO

-- 8. Creating a Function with Dynamic SQL (using sp_executesql)
CREATE FUNCTION fn_GetTableRowCount
(
    @TableName NVARCHAR(128)
)
RETURNS INT
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @RowCount INT;
    
    -- Build dynamic SQL
    SET @SQL = N'SELECT @RowCountOUT = COUNT(*) FROM ' + QUOTENAME(@TableName);
    
    -- Execute dynamic SQL
    EXEC sp_executesql 
        @SQL, 
        N'@RowCountOUT INT OUTPUT', 
        @RowCountOUT = @RowCount OUTPUT;
    
    RETURN @RowCount;
END;
GO

-- 9. Creating a Function with JSON Operations
CREATE FUNCTION fn_ParseProjectTags
(
    @JSONTags NVARCHAR(MAX)
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        [key] AS TagID,
        [value] AS TagName
    FROM OPENJSON(@JSONTags)
);
GO

-- 10. Creating a Function with XML Operations
CREATE FUNCTION fn_ExtractProjectXMLData
(
    @XMLData XML
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        T.N.value('@id', 'INT') AS MilestoneID,
        T.N.value('@name', 'VARCHAR(100)') AS MilestoneName,
        T.N.value('@date', 'DATE') AS MilestoneDate,
        T.N.value('@completion', 'DECIMAL(5,2)') AS CompletionPercentage
    FROM @XMLData.nodes('/project/milestones/milestone') AS T(N)
);
GO

-- 11. Creating a Function with Date/Time Operations
CREATE FUNCTION fn_GetWorkingDays
(
    @StartDate DATE,
    @EndDate DATE
)
RETURNS INT
AS
BEGIN
    DECLARE @WorkDays INT = 0;
    DECLARE @CurrentDate DATE = @StartDate;
    
    WHILE @CurrentDate <= @EndDate
    BEGIN
        -- Check if current date is a weekday (not Saturday or Sunday)
        IF DATEPART(WEEKDAY, @CurrentDate) NOT IN (1, 7) -- Sunday=1, Saturday=7
            SET @WorkDays = @WorkDays + 1;
        
        SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
    END;
    
    RETURN @WorkDays;
END;
GO

-- 12. Creating a Function with String Operations
CREATE FUNCTION fn_FormatProjectCode
(
    @ProjectName VARCHAR(100),
    @ProjectID INT
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @ProjectCode VARCHAR(20);
    
    -- Extract first 3 characters of project name (uppercase)
    DECLARE @Prefix VARCHAR(3) = UPPER(LEFT(@ProjectName, 3));
    
    -- Format project code as PRJ-XXX-YYYY (XXX=project ID, YYYY=current year)
    SET @ProjectCode = @Prefix + '-' + RIGHT('000' + CAST(@ProjectID AS VARCHAR(3)), 3) + '-' + 
                      CAST(YEAR(GETDATE()) AS VARCHAR(4));
    
    RETURN @ProjectCode;
END;
GO

-- 13. Altering a Function
ALTER FUNCTION fn_CalculateProjectDuration
(
    @StartDate DATE,
    @EndDate DATE,
    @ExcludeWeekends BIT = 0 -- New parameter
)
RETURNS INT
AS
BEGIN
    DECLARE @Duration INT;
    
    IF @ExcludeWeekends = 1
    BEGIN
        -- Calculate working days only
        SET @Duration = dbo.fn_GetWorkingDays(@StartDate, @EndDate);
    END
    ELSE
    BEGIN
        -- Calculate all days
        SET @Duration = DATEDIFF(DAY, @StartDate, @EndDate);
    END
    
    RETURN @Duration;
END;
GO

-- 14. Dropping a Function
DROP FUNCTION fn_CalculateFactorial;
GO

-- 15. Using Functions in Queries
-- Using scalar function
SELECT 
    ProjectID,
    ProjectName,
    StartDate,
    EndDate,
    dbo.fn_CalculateProjectDuration(StartDate, EndDate) AS DurationDays,
    dbo.fn_CalculateProjectDuration(StartDate, EndDate, 1) AS WorkingDays,
    dbo.fn_GetProjectStatusCategory(Status) AS StatusCategory
FROM Projects;
GO

-- Using table-valued function
SELECT * FROM dbo.fn_GetProjectsByStatus('In Progress');
GO

-- Using function in WHERE clause
SELECT 
    ProjectID,
    ProjectName,
    Budget,
    dbo.fn_GetProjectBudgetUtilization(ProjectID) AS BudgetUtilization
FROM Projects
WHERE dbo.fn_GetProjectBudgetUtilization(ProjectID) > 75;
GO

-- Using function with JOIN
SELECT 
    p.ProjectID,
    p.ProjectName,
    m.MetricName,
    m.MetricValue,
    m.MetricUnit
FROM Projects p
CROSS APPLY dbo.fn_GetProjectPerformanceMetrics(p.ProjectID) m
WHERE p.Status = 'In Progress';
GO

-- 16. Function Performance Considerations
-- Example of a function with SCHEMABINDING (better performance)
CREATE FUNCTION fn_GetProjectBudgetWithSchemabinding
(
    @ProjectID INT
)
RETURNS DECIMAL(15,2) WITH SCHEMABINDING
AS
BEGIN
    DECLARE @Budget DECIMAL(15,2);
    
    SELECT @Budget = Budget
    FROM dbo.Projects
    WHERE ProjectID = @ProjectID;
    
    RETURN ISNULL(@Budget, 0);
END;
GO

-- 17. Creating a CLR Function (requires CLR integration)
-- Note: This is just an example and requires additional setup
/*
CREATE ASSEMBLY RegexFunctions
FROM 'C:\RegexFunctions.dll'
WITH PERMISSION_SET = SAFE;
GO

CREATE FUNCTION fn_RegexMatch
(
    @Input NVARCHAR(MAX),
    @Pattern NVARCHAR(MAX)
)
RETURNS BIT
EXTERNAL NAME RegexFunctions.RegexUtilities.RegexMatch;
GO
*/

-- 18. Creating a Function for Data Validation
CREATE FUNCTION fn_IsValidEmail
(
    @Email VARCHAR(255)
)
RETURNS BIT
AS
BEGIN
    DECLARE @IsValid BIT = 0;
    
    -- Simple email validation using LIKE
    IF @Email LIKE '%_@_%._%' AND
       @Email NOT LIKE '%@%@%' AND