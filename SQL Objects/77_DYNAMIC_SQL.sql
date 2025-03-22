-- =============================================
-- SQL Server DYNAMIC SQL Guide
-- =============================================

/*
This guide demonstrates the use of Dynamic SQL in SQL Server with HR system scenarios:
- Dynamic reporting and data analysis
- Flexible search and filtering
- Security considerations and best practices
- Performance optimization techniques
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: DYNAMIC SQL FUNDAMENTALS
-- =============================================

-- 1. Basic Dynamic SQL using EXEC
-- Simple example of dynamic column selection
DECLARE @ColumnList NVARCHAR(MAX);
DECLARE @SQL NVARCHAR(MAX);

SET @ColumnList = 'FirstName, LastName, HireDate';
SET @SQL = 'SELECT ' + @ColumnList + ' FROM HR.Employees WHERE Status = ''Active''';

EXEC(@SQL);

-- 2. Using sp_executesql for parameterized queries
-- More secure approach with proper parameter handling
DECLARE @DepartmentID INT = 1;
DECLARE @SQLParam NVARCHAR(MAX);

SET @SQLParam = N'SELECT FirstName, LastName, Salary 
FROM HR.Employees 
WHERE DepartmentID = @DeptID AND Status = ''Active''';

EXEC sp_executesql 
    @SQLParam,
    N'@DeptID INT',
    @DeptID = @DepartmentID;

-- =============================================
-- PART 2: DYNAMIC REPORTING
-- =============================================

-- 1. Flexible Employee Report Generator
CREATE OR ALTER PROCEDURE HR.GenerateEmployeeReport
    @Columns NVARCHAR(MAX),
    @SortColumn NVARCHAR(100),
    @SortDirection NVARCHAR(4),
    @DepartmentID INT = NULL,
    @Status NVARCHAR(20) = 'Active'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    
    -- Validate input parameters
    IF @SortDirection NOT IN ('ASC', 'DESC')
        SET @SortDirection = 'ASC';
        
    -- Build the base query
    SET @SQL = N'SELECT ' + @Columns + '
FROM HR.Employees e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE 1=1';
    
    -- Add optional filters
    IF @DepartmentID IS NOT NULL
        SET @SQL = @SQL + N'
AND e.DepartmentID = @DeptID';
    
    IF @Status IS NOT NULL
        SET @SQL = @SQL + N'
AND e.Status = @EmpStatus';
    
    -- Add sorting
    SET @SQL = @SQL + N'
ORDER BY ' + @SortColumn + ' ' + @SortDirection;
    
    -- Execute the query
    EXEC sp_executesql 
        @SQL,
        N'@DeptID INT, @EmpStatus NVARCHAR(20)',
        @DeptID = @DepartmentID,
        @EmpStatus = @Status;
END;
GO

-- Example usage of the report generator
EXEC HR.GenerateEmployeeReport
    @Columns = 'e.EmployeeID, e.FirstName, e.LastName, d.DepartmentName, e.Salary',
    @SortColumn = 'e.Salary',
    @SortDirection = 'DESC',
    @DepartmentID = NULL,
    @Status = 'Active';

-- =============================================
-- PART 3: DYNAMIC SEARCH AND FILTERING
-- =============================================

-- 1. Advanced Employee Search
CREATE OR ALTER PROCEDURE HR.SearchEmployees
    @SearchFields NVARCHAR(MAX),
    @SearchValue NVARCHAR(100),
    @FilterCriteria NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @SearchConditions NVARCHAR(MAX) = '';
    
    -- Build search conditions for each field
    SELECT @SearchConditions = @SearchConditions +
        CASE WHEN LEN(@SearchConditions) > 0 THEN ' OR ' ELSE '' END +
        'CAST(' + value + ' AS NVARCHAR(MAX)) LIKE @SearchPattern'
    FROM STRING_SPLIT(@SearchFields, ',');
    
    -- Build the base query
    SET @SQL = N'SELECT e.*, d.DepartmentName
FROM HR.Employees e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
WHERE (' + @SearchConditions + ')';
    
    -- Add additional filters if provided
    IF @FilterCriteria IS NOT NULL
        SET @SQL = @SQL + N' AND ' + @FilterCriteria;
    
    -- Execute the query
    EXEC sp_executesql 
        @SQL,
        N'@SearchPattern NVARCHAR(100)',
        @SearchPattern = '%' + @SearchValue + '%';
END;
GO

-- Example usage of the search procedure
EXEC HR.SearchEmployees
    @SearchFields = 'FirstName,LastName,Position',
    @SearchValue = 'Manager',
    @FilterCriteria = 'Salary > 50000';

-- =============================================
-- PART 4: SECURITY CONSIDERATIONS
-- =============================================

-- 1. SQL Injection Prevention
-- Example of vulnerable code (DO NOT USE):
DECLARE @UserInput NVARCHAR(100) = 'Smith''; DROP TABLE Employees;--';
DECLARE @UnsafeSQL NVARCHAR(MAX) = 
    'SELECT * FROM HR.Employees WHERE LastName = ''' + @UserInput + '''';

-- Safe alternative using sp_executesql
DECLARE @SafeSQL NVARCHAR(MAX) = 
    N'SELECT * FROM HR.Employees WHERE LastName = @LastName';

EXEC sp_executesql
    @SafeSQL,
    N'@LastName NVARCHAR(100)',
    @LastName = @UserInput;

-- 2. Permission Validation
CREATE OR ALTER PROCEDURE HR.ExecuteDynamicQuery
    @SQL NVARCHAR(MAX),
    @RequiredPermission NVARCHAR(100)
AS
BEGIN
    -- Check if user has required permission
    IF NOT EXISTS (
        SELECT 1 
        FROM fn_my_permissions(NULL, 'DATABASE') 
        WHERE permission_name = @RequiredPermission
    )
    BEGIN
        RAISERROR('Insufficient permissions to execute this query.', 16, 1);
        RETURN;
    END
    
    EXEC sp_executesql @SQL;
END;

-- =============================================
-- PART 5: PERFORMANCE OPTIMIZATION
-- =============================================

-- 1. Plan Cache Considerations
CREATE OR ALTER PROCEDURE HR.GetEmployeesByDepartment
    @DepartmentID INT
AS
BEGIN
    -- Bad practice: Different plan for each parameter value
    DECLARE @BadSQL NVARCHAR(MAX) = 
        'SELECT * FROM HR.Employees WHERE DepartmentID = ' + CAST(@DepartmentID AS NVARCHAR(10));
    
    -- Good practice: Reusable plan with parameters
    DECLARE @GoodSQL NVARCHAR(MAX) = 
        N'SELECT * FROM HR.Employees WHERE DepartmentID = @DeptID';
    
    EXEC sp_executesql
        @GoodSQL,
        N'@DeptID INT',
        @DeptID = @DepartmentID;
END;

-- 2. Dynamic Index Hints
CREATE OR ALTER PROCEDURE HR.GetEmployeesWithIndexHint
    @SearchColumn NVARCHAR(100),
    @SearchValue NVARCHAR(100)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @IndexHint NVARCHAR(100);
    
    -- Determine appropriate index based on search column
    SELECT @IndexHint = 
        CASE @SearchColumn
            WHEN 'LastName' THEN 'IX_Employees_LastName'
            WHEN 'DepartmentID' THEN 'IX_Employees_Department'
            WHEN 'Position' THEN 'IX_Employees_Position'
            ELSE ''
        END;
    
    -- Build query with index hint if applicable
    SET @SQL = N'SELECT * FROM HR.Employees' +
        CASE WHEN @IndexHint <> '' 
            THEN ' WITH (INDEX(' + @IndexHint + '))'
            ELSE ''
        END +
        ' WHERE ' + @SearchColumn + ' = @Value';
    
    EXEC sp_executesql
        @SQL,
        N'@Value NVARCHAR(100)',
        @Value = @SearchValue;
END;

-- =============================================
-- PART 6: BEST PRACTICES
-- =============================================

-- 1. Error Handling
CREATE OR ALTER PROCEDURE HR.SafeExecuteDynamicSQL
    @SQL NVARCHAR(MAX),
    @Parameters NVARCHAR(MAX) = NULL,
    @ParameterValues NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Validate input
        IF @SQL IS NULL OR LEN(TRIM(@SQL)) = 0
            THROW 50000, 'SQL statement cannot be null or empty.', 1;
            
        -- Log the execution (in production, use proper logging)
        PRINT 'Executing dynamic SQL: ' + @SQL;
        
        -- Execute the statement
        IF @Parameters IS NULL
            EXEC(@SQL);
        ELSE
            EXEC sp_executesql @SQL, @Parameters, @ParameterValues;
            
        -- Log success
        PRINT 'Dynamic SQL executed successfully.';
    END TRY
    BEGIN CATCH
        -- Handle the error
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        -- Log the error (in production, use proper logging)
        PRINT 'Error executing dynamic SQL: ' + @ErrorMessage;
        
        -- Re-throw the error
        THROW;
    END CATCH;
END;

-- 2. Code Organization and Maintainability
CREATE OR ALTER PROCEDURE HR.GenerateReport
    @ReportType NVARCHAR(50),
    @Parameters NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Store query templates in a configuration table
    DECLARE @QueryTemplate NVARCHAR(MAX);
    
    SELECT @QueryTemplate = QueryTemplate
    FROM HR.ReportTemplates
    WHERE ReportType = @ReportType;
    
    IF @QueryTemplate IS NULL
        THROW 50000, 'Invalid report type specified.', 1;
    
    -- Execute the report
    EXEC HR.SafeExecuteDynamicSQL
        @SQL = @QueryTemplate,
        @Parameters = @Parameters;
END;

-- Example report templates table
IF OBJECT_ID('HR.ReportTemplates', 'U') IS NOT NULL
    DROP TABLE HR.ReportTemplates;

CREATE TABLE HR.ReportTemplates (
    ReportType NVARCHAR(50) PRIMARY KEY,
    QueryTemplate NVARCHAR(MAX),
    Description NVARCHAR(500),
    CreatedDate DATETIME DEFAULT GETDATE(),
    LastModifiedDate DATETIME DEFAULT GETDATE()
);

-- Insert sample report templates
INSERT INTO HR.ReportTemplates (ReportType, QueryTemplate, Description)
VALUES
    ('DepartmentSummary',
     'SELECT d.DepartmentName, 
             COUNT(*) AS EmployeeCount,
             AVG(Salary) AS AvgSalary,
             MIN(HireDate) AS EarliestHire
      FROM HR.Employees e
      JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
      WHERE e.Status = ''Active''
      GROUP BY d.DepartmentName',
     'Summary of department statistics'),
    
    ('SalaryDistribution',
     'SELECT 
          CASE 
              WHEN Salary < 50000 THEN ''Entry Level''
              WHEN Salary < 80000 THEN ''Mid Level''
              ELSE ''Senior Level''
          END AS SalaryBand,
          COUNT(*) AS EmployeeCount,
          AVG(Salary) AS AvgSalary
      FROM HR.Employees
      WHERE Status = ''Active''
      GROUP BY 
          CASE 
              WHEN Salary < 50000 THEN ''Entry Level''
              WHEN Salary < 80000 THEN ''Mid Level''
              ELSE ''Senior Level''
          END',
     'Distribution of employee salaries by band');