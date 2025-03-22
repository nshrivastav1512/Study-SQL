-- =============================================
-- SQL Server GRAPH TABLES Guide
-- =============================================

/*
This guide demonstrates the use of Graph Tables in SQL Server for HR scenarios:
- Modeling organizational relationships
- Team collaboration networks
- Project dependencies
- Skill relationships and recommendations
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: CREATING NODE TABLES
-- =============================================

-- 1. Create Employee Node Table
IF OBJECT_ID('HR.EmployeeNode', 'U') IS NOT NULL
    DROP TABLE HR.EmployeeNode;

CREATE TABLE HR.EmployeeNode (
    EmployeeID INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Position NVARCHAR(100),
    Department NVARCHAR(50)
) AS NODE;

-- 2. Create Project Node Table
IF OBJECT_ID('HR.ProjectNode', 'U') IS NOT NULL
    DROP TABLE HR.ProjectNode;

CREATE TABLE HR.ProjectNode (
    ProjectID INT PRIMARY KEY,
    ProjectName NVARCHAR(100),
    StartDate DATE,
    EndDate DATE,
    Status NVARCHAR(20)
) AS NODE;

-- 3. Create Skill Node Table
IF OBJECT_ID('HR.SkillNode', 'U') IS NOT NULL
    DROP TABLE HR.SkillNode;

CREATE TABLE HR.SkillNode (
    SkillID INT PRIMARY KEY,
    SkillName NVARCHAR(100),
    Category NVARCHAR(50),
    Description NVARCHAR(500)
) AS NODE;

-- =============================================
-- PART 2: CREATING EDGE TABLES
-- =============================================

-- 1. Create Reports-To Relationship
IF OBJECT_ID('HR.ReportsTo', 'U') IS NOT NULL
    DROP TABLE HR.ReportsTo;

CREATE TABLE HR.ReportsTo AS EDGE;

-- 2. Create Works-On Relationship
IF OBJECT_ID('HR.WorksOn', 'U') IS NOT NULL
    DROP TABLE HR.WorksOn;

CREATE TABLE HR.WorksOn (
    Role NVARCHAR(50),
    HoursPerWeek INT
) AS EDGE;

-- 3. Create Has-Skill Relationship
IF OBJECT_ID('HR.HasSkill', 'U') IS NOT NULL
    DROP TABLE HR.HasSkill;

CREATE TABLE HR.HasSkill (
    ProficiencyLevel NVARCHAR(20),
    YearsOfExperience INT
) AS EDGE;

-- 4. Create Requires-Skill Relationship
IF OBJECT_ID('HR.RequiresSkill', 'U') IS NOT NULL
    DROP TABLE HR.RequiresSkill;

CREATE TABLE HR.RequiresSkill (
    ImportanceLevel NVARCHAR(20)
) AS EDGE;

-- =============================================
-- PART 3: INSERTING SAMPLE DATA
-- =============================================

-- 1. Insert Employee Nodes
INSERT INTO HR.EmployeeNode
VALUES
    (1, 'John', 'Smith', 'CEO', 'Executive'),
    (2, 'Jane', 'Doe', 'CTO', 'Technology'),
    (3, 'Bob', 'Johnson', 'Development Manager', 'Technology'),
    (4, 'Alice', 'Brown', 'Senior Developer', 'Technology'),
    (5, 'Charlie', 'Wilson', 'HR Director', 'Human Resources');

-- 2. Insert Project Nodes
INSERT INTO HR.ProjectNode
VALUES
    (1, 'HR System Upgrade', '2023-01-01', '2023-12-31', 'In Progress'),
    (2, 'Mobile App Development', '2023-03-01', '2023-09-30', 'In Progress'),
    (3, 'Cloud Migration', '2023-06-01', '2024-06-30', 'Planning');

-- 3. Insert Skill Nodes
INSERT INTO HR.SkillNode
VALUES
    (1, 'SQL Server', 'Database', 'Microsoft SQL Server development and administration'),
    (2, 'Project Management', 'Management', 'Project planning and execution'),
    (3, 'Python', 'Programming', 'Python programming language'),
    (4, 'Azure', 'Cloud', 'Microsoft Azure cloud platform');

-- 4. Insert Edge Relationships
-- Reports-To relationships
INSERT INTO HR.ReportsTo
    ($from_id, $to_id)
SELECT
    e1.$node_id,
    e2.$node_id
FROM HR.EmployeeNode e1, HR.EmployeeNode e2
WHERE
    (e1.EmployeeID = 2 AND e2.EmployeeID = 1) OR
    (e1.EmployeeID = 3 AND e2.EmployeeID = 2) OR
    (e1.EmployeeID = 4 AND e2.EmployeeID = 3) OR
    (e1.EmployeeID = 5 AND e2.EmployeeID = 1);

-- Works-On relationships
INSERT INTO HR.WorksOn
    ($from_id, $to_id, Role, HoursPerWeek)
SELECT
    e.$node_id,
    p.$node_id,
    'Project Manager',
    20
FROM HR.EmployeeNode e, HR.ProjectNode p
WHERE e.EmployeeID = 2 AND p.ProjectID = 1;

-- Has-Skill relationships
INSERT INTO HR.HasSkill
    ($from_id, $to_id, ProficiencyLevel, YearsOfExperience)
SELECT
    e.$node_id,
    s.$node_id,
    'Expert',
    5
FROM HR.EmployeeNode e, HR.SkillNode s
WHERE e.EmployeeID = 4 AND s.SkillID = 1;

-- =============================================
-- PART 4: QUERYING GRAPH DATA
-- =============================================

-- 1. Find all direct reports (one level down)
SELECT
    mgr.FirstName + ' ' + mgr.LastName AS Manager,
    emp.FirstName + ' ' + emp.LastName AS DirectReport
FROM
    HR.EmployeeNode mgr,
    HR.ReportsTo rt,
    HR.EmployeeNode emp
WHERE MATCH(emp-(rt)->mgr);

-- 2. Find all employees in the reporting chain (multiple levels)
SELECT
    emp1.FirstName + ' ' + emp1.LastName AS Employee,
    STRING_AGG(emp2.FirstName + ' ' + emp2.LastName, ' > ') WITHIN GROUP (GRAPH PATH) AS ReportingChain,
    COUNT(emp2.EmployeeID) WITHIN GROUP (GRAPH PATH) AS ChainLength
FROM
    HR.EmployeeNode emp1,
    HR.ReportsTo FOR PATH rt,
    HR.EmployeeNode FOR PATH emp2
WHERE MATCH(SHORTEST_PATH(emp1(-(rt)->emp2)+))
AND emp1.Position <> 'CEO'
ORDER BY ChainLength;

-- 3. Find employees with specific skills working on projects
SELECT
    e.FirstName + ' ' + e.LastName AS Employee,
    s.SkillName,
    hs.ProficiencyLevel,
    p.ProjectName,
    wo.Role
FROM
    HR.EmployeeNode e,
    HR.HasSkill hs,
    HR.SkillNode s,
    HR.WorksOn wo,
    HR.ProjectNode p
WHERE MATCH(e-(hs)->s AND e-(wo)->p)
ORDER BY e.LastName;

-- =============================================
-- PART 5: ADVANCED GRAPH QUERIES
-- =============================================

-- 1. Skill Gap Analysis
CREATE OR ALTER PROCEDURE HR.AnalyzeProjectSkillGaps
    @ProjectID INT
AS
BEGIN
    -- Find required skills for the project vs. available skills
    WITH RequiredSkills AS (
        SELECT
            p.ProjectName,
            s.SkillName,
            rs.ImportanceLevel
        FROM
            HR.ProjectNode p,
            HR.RequiresSkill rs,
            HR.SkillNode s
        WHERE 
            MATCH(p-(rs)->s)
            AND p.ProjectID = @ProjectID
    ),
    AvailableSkills AS (
        SELECT
            p.ProjectName,
            s.SkillName,
            COUNT(DISTINCT e.EmployeeID) AS SkilledEmployees
        FROM
            HR.ProjectNode p,
            HR.WorksOn wo,
            HR.EmployeeNode e,
            HR.HasSkill hs,
            HR.SkillNode s
        WHERE 
            MATCH(p<-(wo)-e-(hs)->s)
            AND p.ProjectID = @ProjectID
        GROUP BY p.ProjectName, s.SkillName
    )
    SELECT
        rs.ProjectName,
        rs.SkillName,
        rs.ImportanceLevel,
        ISNULL(as.SkilledEmployees, 0) AS AvailableEmployees,
        CASE
            WHEN as.SkilledEmployees IS NULL THEN 'Missing Skill'
            WHEN as.SkilledEmployees < 2 THEN 'Insufficient Coverage'
            ELSE 'Adequate Coverage'
        END AS GapStatus
    FROM RequiredSkills rs
    LEFT JOIN AvailableSkills as ON rs.SkillName = as.SkillName
    ORDER BY
        CASE rs.ImportanceLevel
            WHEN 'Critical' THEN 1
            WHEN 'Important' THEN 2
            ELSE 3
        END,
        CASE
            WHEN as.SkilledEmployees IS NULL THEN 1
            WHEN as.SkilledEmployees < 2 THEN 2
            ELSE 3
        END;
END;

-- 2. Find Collaboration Networks
CREATE OR ALTER PROCEDURE HR.AnalyzeCollaborationNetwork
    @EmployeeID INT
AS
BEGIN
    -- Find all employees who work on the same projects
    WITH DirectCollaborators AS (
        SELECT DISTINCT
            e1.EmployeeID AS Employee1ID,
            e1.FirstName + ' ' + e1.LastName AS Employee1Name,
            e2.EmployeeID AS Employee2ID,
            e2.FirstName + ' ' + e2.LastName AS Employee2Name,
            p.ProjectName,
            p.ProjectID
        FROM
            HR.EmployeeNode e1,
            HR.WorksOn wo1,
            HR.ProjectNode p,
            HR.WorksOn wo2,
            HR.EmployeeNode e2
        WHERE 
            MATCH(e1-(wo1)->p<-(wo2)-e2)
            AND e1.EmployeeID = @EmployeeID
            AND e1.EmployeeID <> e2.EmployeeID
    )
    SELECT
        dc.Employee2Name AS Collaborator,
        STRING_AGG(dc.ProjectName, ', ') AS SharedProjects,
        COUNT(DISTINCT dc.ProjectID) AS ProjectCount
    FROM DirectCollaborators dc
    GROUP BY dc.Employee2ID, dc.Employee2Name
    ORDER BY ProjectCount DESC;
END;

-- =============================================
-- PART 6: MAINTAINING GRAPH DATA
-- =============================================

-- 1. Add new relationships
CREATE OR ALTER PROCEDURE HR.AddProjectAssignment
    @EmployeeID INT,
    @ProjectID INT,
    @Role NVARCHAR(50),
    @HoursPerWeek INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if the assignment already exists
    IF EXISTS (
        SELECT 1
        FROM HR.EmployeeNode e, HR.WorksOn wo, HR.ProjectNode p
        WHERE MATCH(e-(wo)->p)
        AND e.EmployeeID = @EmployeeID
        AND p.ProjectID = @ProjectID
    )
    BEGIN
        THROW 50000, 'Employee is already assigned to this project.', 1;
        RETURN;
    END

    -- Add the new assignment
    INSERT INTO HR.WorksOn
        ($from_id, $to_id, Role, HoursPerWeek)
    SELECT
        e.$node_id,
        p.$node_id,
        @Role,
        @HoursPerWeek
    FROM HR.EmployeeNode e, HR.ProjectNode p
    WHERE e.EmployeeID = @EmployeeID
    AND p.ProjectID = @ProjectID;
END;

-- 2. Update existing relationships
CREATE OR ALTER PROCEDURE HR.UpdateSkillProficiency
    @EmployeeID INT,
    @SkillID INT,
    @NewProficiencyLevel NVARCHAR(20),
    @NewYearsOfExperience INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Update the skill relationship
    UPDATE HR.HasSkill
    SET 
        ProficiencyLevel = @NewProficiencyLevel,
        YearsOfExperience = @NewYearsOfExperience
    FROM HR.EmployeeNode e, HR.HasSkill hs, HR.SkillNode s
    WHERE MATCH(e-(hs)->s)
    AND e.EmployeeID = @EmployeeID
    AND s.SkillID = @SkillID;
END;

-- 3. Remove relationships
CREATE OR ALTER PROCEDURE HR.RemoveProjectAssignment
    @EmployeeID INT,
    @ProjectID INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Remove the project assignment
    DELETE wo
    FROM HR.EmployeeNode e, HR.WorksOn wo, HR.ProjectNode p
    WHERE MATCH(e-(wo)->p)
    AND e.EmployeeID = @EmployeeID
    AND p.ProjectID = @ProjectID;
END;