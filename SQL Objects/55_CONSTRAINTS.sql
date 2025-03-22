-- =============================================
-- SQL Server CONSTRAINTS Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating Tables with Different Constraint Types
-- Table with PRIMARY KEY constraint
CREATE TABLE HR.Departments (
    DepartmentID INT PRIMARY KEY,
    DepartmentName VARCHAR(50) NOT NULL,
    Location VARCHAR(100),
    ManagerID INT,
    Budget DECIMAL(15,2),
    EstablishedDate DATE
);
GO

-- Table with FOREIGN KEY constraint
CREATE TABLE HR.Employees (
    EmployeeID INT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE,
    Phone VARCHAR(20),
    HireDate DATE NOT NULL,
    Salary DECIMAL(12,2) CHECK (Salary > 0),
    DepartmentID INT,
    ManagerID INT,
    Status VARCHAR(20) DEFAULT 'Active',
    CONSTRAINT FK_Employees_Departments FOREIGN KEY (DepartmentID) 
        REFERENCES HR.Departments(DepartmentID),
    CONSTRAINT FK_Employees_Manager FOREIGN KEY (ManagerID) 
        REFERENCES HR.Employees(EmployeeID)
);
GO

-- Update the Departments table to add the foreign key constraint for ManagerID
ALTER TABLE HR.Departments
ADD CONSTRAINT FK_Departments_Manager FOREIGN KEY (ManagerID) 
    REFERENCES HR.Employees(EmployeeID);
GO

-- Table with UNIQUE constraint
CREATE TABLE HR.EmployeeSkills (
    SkillID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    SkillName VARCHAR(50) NOT NULL,
    ProficiencyLevel VARCHAR(20) CHECK (ProficiencyLevel IN ('Beginner', 'Intermediate', 'Advanced', 'Expert')),
    YearsOfExperience INT,
    Certified BIT DEFAULT 0,
    CONSTRAINT FK_EmployeeSkills_Employees FOREIGN KEY (EmployeeID) 
        REFERENCES HR.Employees(EmployeeID),
    CONSTRAINT UQ_EmployeeSkill UNIQUE (EmployeeID, SkillName)
);
GO

-- Table with CHECK constraints
CREATE TABLE HR.Salaries (
    SalaryID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    EffectiveDate DATE NOT NULL,
    Amount DECIMAL(12,2) NOT NULL,
    PreviousAmount DECIMAL(12,2),
    IncreasePercentage AS (CASE WHEN PreviousAmount > 0 
                            THEN (Amount - PreviousAmount) / PreviousAmount * 100 
                            ELSE NULL END),
    Reason VARCHAR(100),
    CONSTRAINT FK_Salaries_Employees FOREIGN KEY (EmployeeID) 
        REFERENCES HR.Employees(EmployeeID),
    CONSTRAINT CHK_Salary_Amount CHECK (Amount > 0),
    CONSTRAINT CHK_Salary_EffectiveDate CHECK (EffectiveDate <= GETDATE()),
    CONSTRAINT CHK_Salary_PreviousAmount CHECK (PreviousAmount IS NULL OR PreviousAmount > 0)
);
GO

-- Table with DEFAULT constraints
CREATE TABLE HR.TimeOff (
    TimeOffID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    Type VARCHAR(20) NOT NULL,
    Status VARCHAR(20) DEFAULT 'Pending',
    RequestDate DATETIME DEFAULT GETDATE(),
    ApprovedBy INT,
    ApprovalDate DATETIME,
    Paid BIT DEFAULT 1,
    Notes VARCHAR(500),
    CONSTRAINT FK_TimeOff_Employees FOREIGN KEY (EmployeeID) 
        REFERENCES HR.Employees(EmployeeID),
    CONSTRAINT FK_TimeOff_Approver FOREIGN KEY (ApprovedBy) 
        REFERENCES HR.Employees(EmployeeID),
    CONSTRAINT CHK_TimeOff_Dates CHECK (EndDate >= StartDate),
    CONSTRAINT CHK_TimeOff_Type CHECK (Type IN ('Vacation', 'Sick', 'Personal', 'Bereavement', 'Jury Duty', 'Other')),
    CONSTRAINT CHK_TimeOff_Status CHECK (Status IN ('Pending', 'Approved', 'Rejected', 'Cancelled'))
);
GO

-- Table with NOT NULL constraints
CREATE TABLE HR.PerformanceReviews (
    ReviewID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT NOT NULL,
    ReviewerID INT NOT NULL,
    ReviewDate DATE NOT NULL,
    PerformanceRating DECIMAL(3,2) NOT NULL CHECK (PerformanceRating BETWEEN 1.0 AND 5.0),
    Comments VARCHAR(MAX),
    GoalsAchieved VARCHAR(MAX) NOT NULL,
    AreasForImprovement VARCHAR(MAX) NOT NULL,
    NextReviewDate DATE,
    CONSTRAINT FK_PerformanceReviews_Employee FOREIGN KEY (EmployeeID) 
        REFERENCES HR.Employees(EmployeeID),
    CONSTRAINT FK_PerformanceReviews_Reviewer FOREIGN KEY (ReviewerID) 
        REFERENCES HR.Employees(EmployeeID)
);
GO

-- 2. Adding Constraints to Existing Tables
-- Create a table without constraints
CREATE TABLE HR.Projects (
    ProjectID INT,
    ProjectName VARCHAR(100),
    StartDate DATE,
    EndDate DATE,
    Budget DECIMAL(15,2),
    ManagerID INT,
    Status VARCHAR(20),
    Priority VARCHAR(10),
    Description VARCHAR(500)
);
GO

-- Add PRIMARY KEY constraint
ALTER TABLE HR.Projects
ADD CONSTRAINT PK_Projects PRIMARY KEY (ProjectID);
GO

-- Add FOREIGN KEY constraint
ALTER TABLE HR.Projects
ADD CONSTRAINT FK_Projects_Manager FOREIGN KEY (ManagerID) 
    REFERENCES HR.Employees(EmployeeID);
GO

-- Add NOT NULL constraints
ALTER TABLE HR.Projects
ALTER COLUMN ProjectName VARCHAR(100) NOT NULL;
GO

ALTER TABLE HR.Projects
ALTER COLUMN StartDate DATE NOT NULL;
GO

-- Add CHECK constraints
ALTER TABLE HR.Projects
ADD CONSTRAINT CHK_Project_Dates CHECK (EndDate IS NULL OR EndDate >= StartDate);
GO

ALTER TABLE HR.Projects
ADD CONSTRAINT CHK_Project_Budget CHECK (Budget > 0);
GO

ALTER TABLE HR.Projects
ADD CONSTRAINT CHK_Project_Status CHECK (Status IN ('Not Started', 'In Progress', 'On Hold', 'Completed', 'Cancelled'));
GO

ALTER TABLE HR.Projects
ADD CONSTRAINT CHK_Project_Priority CHECK (Priority IN ('Low', 'Medium', 'High', 'Critical'));
GO

-- Add DEFAULT constraints
ALTER TABLE HR.Projects
ADD CONSTRAINT DF_Project_Status DEFAULT 'Not Started' FOR Status;
GO

ALTER TABLE HR.Projects
ADD CONSTRAINT DF_Project_Priority DEFAULT 'Medium' FOR Priority;
GO

-- 3. Modifying Constraints
-- Create a table for project assignments
CREATE TABLE HR.ProjectAssignments (
    AssignmentID INT PRIMARY KEY IDENTITY(1,1),
    ProjectID INT NOT NULL,
    EmployeeID INT NOT NULL,
    RoleOnProject VARCHAR(50),
    AssignmentDate DATE DEFAULT GETDATE(),
    HoursAllocated DECIMAL(6,2) CHECK (HoursAllocated > 0 AND HoursAllocated <= 40),
    CONSTRAINT FK_ProjectAssignments_Projects FOREIGN KEY (ProjectID) 
        REFERENCES HR.Projects(ProjectID),
    CONSTRAINT FK_ProjectAssignments_Employees FOREIGN KEY (EmployeeID) 
        REFERENCES HR.Employees(EmployeeID),
    CONSTRAINT UQ_ProjectAssignment UNIQUE (ProjectID, EmployeeID)
);
GO

-- Modify CHECK constraint to allow more hours
ALTER TABLE HR.ProjectAssignments
DROP CONSTRAINT CHK_HoursAllocated;
GO

ALTER TABLE HR.ProjectAssignments
ADD CONSTRAINT CHK_HoursAllocated CHECK (HoursAllocated > 0 AND HoursAllocated <= 60);
GO

-- Modify FOREIGN KEY constraint to add cascading delete
ALTER TABLE HR.ProjectAssignments
DROP CONSTRAINT FK_ProjectAssignments_Projects;
GO

ALTER TABLE HR.ProjectAssignments
ADD CONSTRAINT FK_ProjectAssignments_Projects FOREIGN KEY (ProjectID) 
    REFERENCES HR.Projects(ProjectID) ON DELETE CASCADE;
GO

-- 4. Disabling and Enabling Constraints
-- Disable a foreign key constraint
ALTER TABLE HR.ProjectAssignments
NOCHECK CONSTRAINT FK_ProjectAssignments_Employees;
GO

-- Enable a foreign key constraint
ALTER TABLE HR.ProjectAssignments
CHECK CONSTRAINT FK_ProjectAssignments_Employees;
GO

-- Disable all constraints on a table
ALTER TABLE HR.ProjectAssignments
NOCHECK CONSTRAINT ALL;
GO

-- Enable all constraints on a table
ALTER TABLE HR.ProjectAssignments
CHECK CONSTRAINT ALL;
GO

-- 5. Dropping Constraints
-- Drop a CHECK constraint
ALTER TABLE HR.Projects
DROP CONSTRAINT CHK_Project_Priority;
GO

-- Add a modified CHECK constraint
ALTER TABLE HR.Projects
ADD CONSTRAINT CHK_Project_Priority CHECK (Priority IN ('Low', 'Medium', 'High', 'Critical', 'Emergency'));
GO

-- Drop a DEFAULT constraint
ALTER TABLE HR.Projects
DROP CONSTRAINT DF_Project_Priority;
GO

-- Add a new DEFAULT constraint
ALTER TABLE HR.Projects
ADD CONSTRAINT DF_Project_Priority DEFAULT 'Low' FOR Priority;
GO

-- Drop a UNIQUE constraint
ALTER TABLE HR.ProjectAssignments
DROP CONSTRAINT UQ_ProjectAssignment;
GO

-- Add a modified UNIQUE constraint
ALTER TABLE HR.ProjectAssignments
ADD CONSTRAINT UQ_ProjectAssignment UNIQUE (ProjectID, EmployeeID, RoleOnProject);
GO

-- 6. Querying Constraint Information
-- List all constraints in the database
SELECT 
    OBJECT_SCHEMA_NAME(o.parent_object_id) AS SchemaName,
    OBJECT_NAME(o.parent_object_id) AS TableName,
    o.name AS ConstraintName,
    o.type_desc AS ConstraintType,
    o.create_date,
    o.modify_date,
    o.is_disabled
FROM sys.objects o
WHERE o.type_desc LIKE '%CONSTRAINT'
ORDER BY SchemaName, TableName, ConstraintType, ConstraintName;
GO

-- List all foreign key constraints
SELECT 
    OBJECT_SCHEMA_NAME(f.parent_object_id) AS SchemaName,
    OBJECT_NAME(f.parent_object_id) AS TableName,
    f.name AS ForeignKeyName,
    COL_NAME(fc.parent_object_id, fc.parent_column_id) AS ColumnName,
    OBJECT_SCHEMA_NAME(f.referenced_object_id) AS ReferencedSchemaName,
    OBJECT_NAME(f.referenced_object_id) AS ReferencedTableName,
    COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS ReferencedColumnName,
    f.delete_referential_action_desc AS DeleteAction,
    f.update_referential_action_desc AS UpdateAction,
    f.is_disabled
FROM sys.foreign_keys f
INNER JOIN sys.foreign_key_columns fc ON f.object_id = fc.constraint_object_id
ORDER BY SchemaName, TableName, ForeignKeyName;
GO

-- List all check constraints
SELECT 
    OBJECT_SCHEMA_NAME(o.parent_object_id) AS SchemaName,
    OBJECT_NAME(o.parent_object_id) AS TableName,
    o.name AS CheckConstraintName,
    c.definition AS CheckDefinition,
    o.create_date,
    o.modify_date,
    o.is_disabled
FROM sys.check_constraints c
JOIN sys.objects o ON c.object_id = o.object_id
ORDER BY SchemaName, TableName, CheckConstraintName;
GO

-- List all default constraints
SELECT 
    OBJECT_SCHEMA_NAME(o.parent_object_id) AS SchemaName,
    OBJECT_NAME(o.parent_object_id) AS TableName,
    o.name AS DefaultConstraintName,
    COL_NAME(d.parent_object_id, d.parent_column_id) AS ColumnName,
    d.definition AS DefaultDefinition,
    o.create_date,
    o.modify_date
FROM sys.default_constraints d
JOIN sys.objects o ON d.object_id = o.object_id
ORDER BY SchemaName, TableName, DefaultConstraintName;
GO

-- List all primary and unique key constraints
SELECT 
    OBJECT_SCHEMA_NAME(o.parent_object_id) AS SchemaName,
    OBJECT_NAME(o.parent_object_id) AS TableName,
    o.name AS ConstraintName,
    CASE i.is_primary_key WHEN 1 THEN 'PRIMARY KEY' ELSE 'UNIQUE' END AS ConstraintType,
    COL_NAME(ic.object_id, ic.column_id) AS ColumnName,
    i.type_desc AS IndexType,
    i.is_unique,
    o.create_date,
    o.modify_date
FROM sys.indexes i
JOIN sys.objects o ON i.object_id = o.object_id AND i.name = o.name
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
WHERE i.is_primary_key = 1 OR i.is_unique_constraint =