-- =============================================
-- SQL Server TABLES Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating a Basic Table
CREATE TABLE Projects (
    ProjectID INT PRIMARY KEY IDENTITY(1,1),
    ProjectName VARCHAR(100) NOT NULL,
    StartDate DATE,
    EndDate DATE,
    Budget DECIMAL(15,2),
    Status VARCHAR(20) DEFAULT 'Not Started',
    Description VARCHAR(500),
    CreatedDate DATETIME DEFAULT GETDATE()
);
GO

-- 2. Creating a Table with Foreign Key Constraints
CREATE TABLE ProjectAssignments (
    AssignmentID INT PRIMARY KEY IDENTITY(1,1),
    ProjectID INT NOT NULL,
    EmployeeID INT NOT NULL,
    RoleOnProject VARCHAR(50),
    AssignmentDate DATE DEFAULT GETDATE(),
    HoursAllocated DECIMAL(6,2),
    CONSTRAINT FK_ProjectAssignments_Projects FOREIGN KEY (ProjectID) 
        REFERENCES Projects(ProjectID),
    CONSTRAINT FK_ProjectAssignments_Employees FOREIGN KEY (EmployeeID) 
        REFERENCES HR.Employees(EmployeeID)
);
GO

-- 3. Creating a Table with Check Constraints
CREATE TABLE ProjectMilestones (
    MilestoneID INT PRIMARY KEY IDENTITY(1,1),
    ProjectID INT NOT NULL,
    MilestoneName VARCHAR(100) NOT NULL,
    TargetDate DATE NOT NULL,
    CompletionDate DATE,
    CompletionPercentage DECIMAL(5,2) DEFAULT 0,
    CONSTRAINT FK_ProjectMilestones_Projects FOREIGN KEY (ProjectID) 
        REFERENCES Projects(ProjectID),
    CONSTRAINT CHK_CompletionPercentage CHECK (CompletionPercentage BETWEEN 0 AND 100),
    CONSTRAINT CHK_CompletionDate CHECK (CompletionDate IS NULL OR CompletionDate >= TargetDate)
);
GO

-- 4. Creating a Table with Unique Constraint
CREATE TABLE ProjectDocuments (
    DocumentID INT PRIMARY KEY IDENTITY(1,1),
    ProjectID INT NOT NULL,
    DocumentName VARCHAR(100) NOT NULL,
    DocumentPath VARCHAR(255) NOT NULL,
    UploadDate DATETIME DEFAULT GETDATE(),
    FileSize INT,
    FileType VARCHAR(50),
    CONSTRAINT FK_ProjectDocuments_Projects FOREIGN KEY (ProjectID) 
        REFERENCES Projects(ProjectID),
    CONSTRAINT UQ_ProjectDocument UNIQUE (ProjectID, DocumentPath)
);
GO

-- 5. Creating a Table with Computed Column
CREATE TABLE ProjectBudgetItems (
    BudgetItemID INT PRIMARY KEY IDENTITY(1,1),
    ProjectID INT NOT NULL,
    ItemName VARCHAR(100) NOT NULL,
    EstimatedCost DECIMAL(12,2) NOT NULL,
    ActualCost DECIMAL(12,2),
    Variance AS (ActualCost - EstimatedCost),
    ItemCategory VARCHAR(50),
    CONSTRAINT FK_ProjectBudgetItems_Projects FOREIGN KEY (ProjectID) 
        REFERENCES Projects(ProjectID)
);
GO

-- 6. Creating a Table with Default Constraints
CREATE TABLE ProjectRisks (
    RiskID INT PRIMARY KEY IDENTITY(1,1),
    ProjectID INT NOT NULL,
    RiskDescription VARCHAR(200) NOT NULL,
    Probability VARCHAR(20) DEFAULT 'Low',
    Impact VARCHAR(20) DEFAULT 'Low',
    MitigationPlan VARCHAR(500),
    IdentifiedDate DATE DEFAULT GETDATE(),
    Status VARCHAR(20) DEFAULT 'Open',
    CONSTRAINT FK_ProjectRisks_Projects FOREIGN KEY (ProjectID) 
        REFERENCES Projects(ProjectID),
    CONSTRAINT CHK_Probability CHECK (Probability IN ('Low', 'Medium', 'High')),
    CONSTRAINT CHK_Impact CHECK (Impact IN ('Low', 'Medium', 'High')),
    CONSTRAINT CHK_Status CHECK (Status IN ('Open', 'Mitigated', 'Closed', 'Accepted'))
);
GO

-- 7. Creating a Table with Temporal Features (System-Versioned)
CREATE TABLE ProjectStatus (
    StatusID INT PRIMARY KEY IDENTITY(1,1),
    ProjectID INT NOT NULL,
    StatusDate DATE NOT NULL,
    StatusUpdate VARCHAR(500) NOT NULL,
    UpdatedBy VARCHAR(100),
    ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
    ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo),
    CONSTRAINT FK_ProjectStatus_Projects FOREIGN KEY (ProjectID) 
        REFERENCES Projects(ProjectID)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProjectStatusHistory));
GO

-- 8. Altering Tables
-- Add a new column
ALTER TABLE Projects
ADD ProjectManager VARCHAR(100);
GO

-- Modify an existing column
ALTER TABLE Projects
ALTER COLUMN Description VARCHAR(1000);
GO

-- Add a constraint
ALTER TABLE Projects
ADD CONSTRAINT CHK_ProjectDates CHECK (EndDate IS NULL OR EndDate >= StartDate);
GO

-- Drop a column
ALTER TABLE ProjectRisks
DROP COLUMN MitigationPlan;
GO

-- 9. Truncating a Table (Remove all rows but keep structure)
TRUNCATE TABLE ProjectDocuments;
GO

-- 10. Dropping Tables (Remove table and data)
-- Note: Must drop tables with foreign key dependencies first
DROP TABLE ProjectStatus;
DROP TABLE ProjectBudgetItems;
DROP TABLE ProjectRisks;
DROP TABLE ProjectDocuments;
DROP TABLE ProjectMilestones;
DROP TABLE ProjectAssignments;
DROP TABLE Projects;
GO

-- 11. Inserting Data into Tables
CREATE TABLE Projects (
    ProjectID INT PRIMARY KEY IDENTITY(1,1),
    ProjectName VARCHAR(100) NOT NULL,
    StartDate DATE,
    EndDate DATE,
    Budget DECIMAL(15,2),
    Status VARCHAR(20) DEFAULT 'Not Started',
    Description VARCHAR(500),
    CreatedDate DATETIME DEFAULT GETDATE()
);
GO

-- Basic INSERT
INSERT INTO Projects (ProjectName, StartDate, EndDate, Budget, Status, Description)
VALUES ('Website Redesign', '2023-01-15', '2023-06-30', 75000.00, 'In Progress', 'Complete overhaul of company website');
GO

-- Multiple row INSERT
INSERT INTO Projects (ProjectName, StartDate, EndDate, Budget, Status, Description)
VALUES 
('Mobile App Development', '2023-02-01', '2023-08-31', 120000.00, 'Planning', 'Develop iOS and Android apps'),
('Database Migration', '2023-03-15', '2023-05-15', 45000.00, 'Not Started', 'Migrate from SQL Server 2016 to 2022'),
('Network Infrastructure Upgrade', '2023-04-01', '2023-07-31', 200000.00, 'Not Started', 'Upgrade all network equipment');
GO

-- 12. Updating Data in Tables
UPDATE Projects
SET Status = 'In Progress', 
    Description = 'Migrate from SQL Server 2016 to 2022 with minimal downtime'
WHERE ProjectName = 'Database Migration';
GO

-- 13. Deleting Data from Tables
DELETE FROM Projects
WHERE ProjectName = 'Network Infrastructure Upgrade';
GO

-- 14. Selecting Data from Tables
-- Basic SELECT
SELECT * FROM Projects;
GO

-- Filtered SELECT
SELECT ProjectID, ProjectName, StartDate, EndDate, Budget
FROM Projects
WHERE Status = 'In Progress';
GO

-- Ordered SELECT
SELECT ProjectName, Budget, StartDate
FROM Projects
ORDER BY Budget DESC;
GO

-- 15. Creating a Temporary Table
-- Local temporary table (visible only to current session)
CREATE TABLE #TempProjects (
    ID INT IDENTITY(1,1),
    ProjectName VARCHAR(100),
    Budget DECIMAL(15,2)
);

-- Global temporary table (visible to all sessions)
CREATE TABLE ##GlobalTempProjects (
    ID INT IDENTITY(1,1),
    ProjectName VARCHAR(100),
    Budget DECIMAL(15,2)
);
GO

-- 16. Creating a Table from SELECT
SELECT ProjectID, ProjectName, Budget, Status
INTO ProjectsSummary
FROM Projects
WHERE Budget > 50000;
GO

-- 17. Creating a Table with SPARSE Columns (for tables with many NULL values)
CREATE TABLE ProjectExtendedAttributes (
    AttributeID INT PRIMARY KEY IDENTITY(1,1),
    ProjectID INT NOT NULL,
    Attribute1 VARCHAR(100) SPARSE NULL,
    Attribute2 VARCHAR(100) SPARSE NULL,
    Attribute3 VARCHAR(100) SPARSE NULL,
    Attribute4 VARCHAR(100) SPARSE NULL,
    Attribute5 VARCHAR(100) SPARSE NULL,
    Attribute6 VARCHAR(100) SPARSE NULL,
    Attribute7 VARCHAR(100) SPARSE NULL,
    Attribute8 VARCHAR(100) SPARSE NULL,
    Attribute9 VARCHAR(100) SPARSE NULL,
    Attribute10 VARCHAR(100) SPARSE NULL,
    CONSTRAINT FK_ProjectExtendedAttributes_Projects FOREIGN KEY (ProjectID) 
        REFERENCES Projects(ProjectID)
);
GO

-- 18. Creating a Table with FILESTREAM (for storing large binary data)
-- Note: Requires FILESTREAM to be enabled on the server
/*
CREATE TABLE ProjectFiles (
    FileID UNIQUEIDENTIFIER PRIMARY KEY ROWGUIDCOL DEFAULT NEWID(),
    ProjectID INT NOT NULL,
    FileName VARCHAR(255) NOT NULL,
    FileData VARBINARY(MAX) FILESTREAM,
    UploadDate DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_ProjectFiles_Projects FOREIGN KEY (ProjectID) 
        REFERENCES Projects(ProjectID)
);
GO
*/

-- 19. Creating a Partitioned Table
-- First create a partition function
/*
CREATE PARTITION FUNCTION ProjectDateRangePF (DATE)
AS RANGE RIGHT FOR VALUES ('2023-01-01', '2023-04-01', '2023-07-01', '2023-10-01');
GO

-- Create a partition scheme
CREATE PARTITION SCHEME ProjectDateRangePS
AS PARTITION ProjectDateRangePF
ALL TO ([PRIMARY]);
GO

-- Create the partitioned table
CREATE TABLE ProjectActivities (
    ActivityID INT IDENTITY(1,1),
    ProjectID INT NOT NULL,
    ActivityDate DATE NOT NULL,
    ActivityDescription VARCHAR(500),
    LoggedBy VARCHAR(100),
    LoggedTime DATETIME DEFAULT GETDATE(),
    CONSTRAINT PK_ProjectActivities PRIMARY KEY (ActivityID, ActivityDate) 
        ON ProjectDateRangePS(ActivityDate),
    CONSTRAINT FK_ProjectActivities_Projects FOREIGN KEY (ProjectID) 
        REFERENCES Projects(ProjectID)
);
GO
*/

-- 20. Creating a Memory-Optimized Table (for high-performance scenarios)
-- Note: Requires In-Memory OLTP to be enabled
/*
CREATE TABLE ProjectTasks (
    TaskID INT IDENTITY(1,1) PRIMARY KEY NONCLUSTERED,
    ProjectID INT NOT NULL,
    TaskName VARCHAR(100) NOT NULL,
    AssignedTo VARCHAR(100),
    DueDate DATE,
    Priority INT,
    Status VARCHAR(20) DEFAULT 'Not Started',
    INDEX IX_ProjectTasks_ProjectID HASH (ProjectID) WITH (BUCKET_COUNT = 1024)
) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);
GO
*/