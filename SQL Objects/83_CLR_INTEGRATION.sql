-- =============================================
-- SQL Server CLR INTEGRATION Guide
-- =============================================

/*
This guide demonstrates the use of CLR Integration in SQL Server for HR scenarios:
- Complex HR calculations and data processing
- Custom string manipulations for employee data
- Advanced HR analytics with custom aggregates
- File system operations for HR document management
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: ENABLING CLR INTEGRATION
-- =============================================

-- 1. Enable CLR Integration
sp_configure 'show advanced options', 1;
GO
RECONFIGURE;
GO
sp_configure 'clr enabled', 1;
GO
RECONFIGURE;
GO

-- 2. Set Trustworthy Property (for development only)
ALTER DATABASE HRSystem SET TRUSTWORTHY ON;
GO

-- =============================================
-- PART 2: CREATING CLR ASSEMBLIES
-- =============================================

-- Note: The following examples assume you have compiled .NET assemblies
-- with the corresponding classes and methods

-- 1. Create Assembly for HR Functions
/*
CREATE ASSEMBLY HRFunctions
FROM 'C:\Assemblies\HRFunctions.dll'
WITH PERMISSION_SET = SAFE;
GO
*/

-- =============================================
-- PART 3: CREATING CLR FUNCTIONS
-- =============================================

-- 1. Create CLR Function for Leave Calculation
/*
CREATE FUNCTION HR.CalculateLeaveBalance
(
    @startDate DATETIME,
    @endDate DATETIME,
    @leaveType NVARCHAR(50),
    @employeeType NVARCHAR(50)
)
RETURNS DECIMAL(5,2)
AS EXTERNAL NAME HRFunctions.LeaveFunctions.CalculateLeaveBalance;
GO
*/

-- 2. Create CLR Function for Salary Calculation
/*
CREATE FUNCTION HR.CalculateNetSalary
(
    @baseSalary DECIMAL(12,2),
    @allowances DECIMAL(12,2),
    @deductions DECIMAL(12,2),
    @taxBracket INT
)
RETURNS DECIMAL(12,2)
AS EXTERNAL NAME HRFunctions.SalaryFunctions.CalculateNetSalary;
GO
*/

-- =============================================
-- PART 4: CREATING CLR STORED PROCEDURES
-- =============================================

-- 1. Create CLR Procedure for Employee Document Processing
/*
CREATE PROCEDURE HR.ProcessEmployeeDocuments
    @employeeId INT,
    @documentType NVARCHAR(50),
    @documentPath NVARCHAR(255)
AS EXTERNAL NAME HRFunctions.DocumentProcessor.ProcessDocuments;
GO
*/

-- 2. Create CLR Procedure for Performance Analytics
/*
CREATE PROCEDURE HR.AnalyzePerformanceMetrics
    @departmentId INT,
    @startDate DATETIME,
    @endDate DATETIME
AS EXTERNAL NAME HRFunctions.PerformanceAnalytics.AnalyzeMetrics;
GO
*/

-- =============================================
-- PART 5: CREATING CLR AGGREGATES
-- =============================================

-- 1. Create CLR Aggregate for Custom HR Metrics
/*
CREATE AGGREGATE HR.WeightedPerformanceScore
(
    @score DECIMAL(5,2),
    @weight DECIMAL(5,2)
)
RETURNS DECIMAL(5,2)
EXTERNAL NAME HRFunctions.CustomAggregates.WeightedScore;
GO
*/

-- =============================================
-- PART 6: EXAMPLE USAGE
-- =============================================

-- 1. Example: Calculate Leave Balance
/*
SELECT HR.CalculateLeaveBalance(
    StartDate,
    GETDATE(),
    LeaveType,
    EmployeeType
) AS AvailableLeave
FROM HR.Employees
WHERE EmployeeID = 1;
*/

-- 2. Example: Process Employee Documents
/*
EXEC HR.ProcessEmployeeDocuments
    @employeeId = 1,
    @documentType = 'Contract',
    @documentPath = 'D:\HR\Documents\Contracts';
*/

-- 3. Example: Calculate Department Performance
/*
SELECT 
    DepartmentID,
    HR.WeightedPerformanceScore(PerformanceScore, Weight)
    AS DepartmentScore
FROM HR.EmployeePerformance
GROUP BY DepartmentID;
*/

-- =============================================
-- PART 7: SECURITY CONSIDERATIONS
-- =============================================

-- 1. Grant Execute Permissions
/*
GRANT EXECUTE ON HR.CalculateLeaveBalance TO HRAnalysts;
GRANT EXECUTE ON HR.ProcessEmployeeDocuments TO HRManagers;
GRANT EXECUTE ON HR.AnalyzePerformanceMetrics TO HRAnalysts;
*/

-- 2. Revoke Assembly Permissions (when needed)
/*
REVOKE ALL ON ASSEMBLY::HRFunctions TO PUBLIC;
*/

-- =============================================
-- PART 8: BEST PRACTICES AND MAINTENANCE
-- =============================================

-- 1. Monitor CLR Resource Usage
SELECT * FROM sys.dm_clr_tasks;
SELECT * FROM sys.dm_clr_appdomains;

-- 2. View Registered Assemblies
SELECT * FROM sys.assemblies;

-- 3. Check Assembly Dependencies
SELECT * FROM sys.assembly_files;

-- Note: Remember to properly sign assemblies in production
-- and follow the principle of least privilege when
-- setting PERMISSION_SET for assemblies