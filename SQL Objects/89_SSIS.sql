-- =============================================
-- SQL Server Integration Services (SSIS) for HR Data Integration
-- =============================================

/*
This script demonstrates SSIS package development for HR data integration:
- Understanding SSIS architecture and components
- Creating data integration workflows
- Implementing ETL best practices
- Error handling and logging
- Performance optimization
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: SSIS PACKAGE CONFIGURATION
-- =============================================

/*
SSIS Package Structure:
1. Control Flow: Defines the workflow and execution sequence
2. Data Flow: Handles data movement and transformation
3. Event Handlers: Manages errors and events
4. Package Variables: Stores runtime values
5. Connection Managers: Manages data source connections

Key Components:
- Tasks: Individual units of work (Execute SQL, File System, etc.)
- Containers: Group and organize tasks
- Precedence Constraints: Control task execution order
- Transformations: Modify data during transfer
*/

-- Example: Create Source Table for Employee Data
CREATE TABLE HR_Source_Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Department NVARCHAR(50),
    Salary DECIMAL(10,2)
);

-- Example: Create Staging Table for Data Processing
CREATE TABLE HR_Staging_Employees (
    EmployeeID INT,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Department NVARCHAR(50),
    Salary DECIMAL(10,2),
    LoadDate DATETIME DEFAULT GETDATE(),
    Status NVARCHAR(20)
);

-- =============================================
-- PART 2: DATA FLOW TASK COMPONENTS
-- =============================================

/*
Common Data Flow Transformations:
1. Derived Column:
   - Add calculated fields
   - Format data
   - Apply business logic

2. Lookup:
   - Validate reference data
   - Match employee records
   - Check department codes

3. Conditional Split:
   - Route records based on conditions
   - Handle different employee types
   - Separate valid/invalid data

4. Aggregate:
   - Calculate department totals
   - Summarize salary data
   - Group employee counts
*/

-- Example: Create Lookup Table for Departments
CREATE TABLE HR_Departments (
    DepartmentID INT PRIMARY KEY,
    DepartmentName NVARCHAR(50),
    Location NVARCHAR(50)
);

-- =============================================
-- PART 3: ERROR HANDLING AND LOGGING
-- =============================================

/*
Error Handling Strategies:
1. Row-level Error Handling:
   - Redirect failed rows
   - Log error details
   - Continue processing valid records

2. Package-level Error Handling:
   - Event handlers
   - Failure notifications
   - Rollback mechanisms
*/

-- Create Error Logging Table
CREATE TABLE SSIS_ErrorLog (
    ErrorID INT IDENTITY(1,1) PRIMARY KEY,
    PackageName NVARCHAR(100),
    TaskName NVARCHAR(100),
    ErrorDescription NVARCHAR(MAX),
    ErrorTime DATETIME DEFAULT GETDATE()
);

-- =============================================
-- PART 4: PERFORMANCE OPTIMIZATION
-- =============================================

/*
Performance Best Practices:
1. Buffer Size Configuration:
   - Optimize memory usage
   - Balance throughput
   - Monitor resource utilization

2. Parallel Processing:
   - Configure max concurrent executables
   - Use multiple data flows
   - Balance system resources

3. Batch Processing:
   - Set batch size
   - Implement checkpoints
   - Handle transaction boundaries
*/

-- Example: Create Performance Monitoring Table
CREATE TABLE SSIS_Performance_Log (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    PackageName NVARCHAR(100),
    StartTime DATETIME,
    EndTime DATETIME,
    RowsProcessed INT,
    ExecutionStatus NVARCHAR(20)
);

-- =============================================
-- PART 5: INCREMENTAL LOAD PATTERN
-- =============================================

/*
Incremental Load Strategy:
1. Track Changes:
   - Use change tracking
   - Implement timestamps
   - Maintain watermarks

2. Delta Detection:
   - Compare source and target
   - Identify new/modified records
   - Handle deletions
*/

-- Create Change Tracking Table
CREATE TABLE HR_Change_Tracking (
    TableName NVARCHAR(100),
    LastLoadTime DATETIME,
    Status NVARCHAR(20)
);

-- =============================================
-- PART 6: SECURITY AND AUDITING
-- =============================================

/*
Security Considerations:
1. Package Protection:
   - Encryption level
   - Password protection
   - Digital signatures

2. Data Access:
   - Connection security
   - Credential management
   - Role-based access
*/

-- Create Audit Table
CREATE TABLE SSIS_Audit_Log (
    AuditID INT IDENTITY(1,1) PRIMARY KEY,
    PackageName NVARCHAR(100),
    UserName NVARCHAR(50),
    ActionType NVARCHAR(50),
    ActionTime DATETIME DEFAULT GETDATE()
);

-- =============================================
-- PART 7: DEPLOYMENT AND MAINTENANCE
-- =============================================

/*
Deployment Best Practices:
1. Environment Configuration:
   - Project parameters
   - Environment variables
   - Configuration files

2. Package Maintenance:
   - Version control
   - Documentation
   - Testing procedures
*/

-- Example: Create Configuration Table
CREATE TABLE SSIS_Configuration (
    ConfigID INT IDENTITY(1,1) PRIMARY KEY,
    ConfigName NVARCHAR(100),
    ConfigValue NVARCHAR(MAX),
    Description NVARCHAR(500)
);