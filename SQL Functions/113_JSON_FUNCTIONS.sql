/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\113_JSON_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server JSON Functions with real-life examples
    using the HRSystem database schemas and tables.

    JSON Functions covered:
    1. JSON_VALUE() - Extracts a scalar value from a JSON string
    2. JSON_QUERY() - Extracts an object or array from a JSON string
    3. ISJSON() - Tests if a string contains valid JSON
    4. JSON_MODIFY() - Updates value in JSON string
    5. OPENJSON() - Converts JSON array/object into rowset
*/

USE HRSystem;
GO

-- Create sample tables if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[EmployeeSkills]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.EmployeeSkills (
        SkillID INT PRIMARY KEY IDENTITY(1,1),
        EmployeeID INT,
        SkillsData NVARCHAR(MAX),  -- Stores JSON data
        Certifications NVARCHAR(MAX),  -- Stores JSON array
        ProjectHistory NVARCHAR(MAX),  -- Stores JSON object
        LastUpdated DATETIME2 DEFAULT SYSDATETIME()
    );

    -- Insert sample JSON data
    INSERT INTO HR.EmployeeSkills (EmployeeID, SkillsData, Certifications, ProjectHistory) VALUES
    (1, 
        '{"technical": {"programming": ["SQL", "Python", "Java"], "databases": ["SQL Server", "Oracle"], "level": "Senior"}, "soft": ["Leadership", "Communication"]}',
        '[{"name": "SQL Server Expert", "year": 2022, "score": 95}, {"name": "Project Management", "year": 2021, "score": 88}]',
        '{"current": {"name": "Database Migration", "role": "Lead"}, "previous": [{"name": "Data Warehouse", "role": "Developer"}, {"name": "BI Dashboard", "role": "Analyst"}]}'
    ),
    (2,
        '{"technical": {"programming": ["JavaScript", "C#"], "databases": ["MongoDB", "PostgreSQL"], "level": "Mid"}, "soft": ["Teamwork", "Problem Solving"]}',
        '[{"name": "Web Development", "year": 2023, "score": 92}, {"name": "Agile Methodology", "year": 2022, "score": 85}]',
        '{"current": {"name": "E-commerce Platform", "role": "Developer"}, "previous": [{"name": "CRM System", "role": "Frontend Dev"}, {"name": "Mobile App", "role": "Full Stack"}]}'
    );

    -- Create table for employee preferences
    CREATE TABLE HR.EmployeePreferences (
        PreferenceID INT PRIMARY KEY IDENTITY(1,1),
        EmployeeID INT,
        Preferences NVARCHAR(MAX)  -- Stores JSON object
    );

    -- Insert sample preferences
    INSERT INTO HR.EmployeePreferences (EmployeeID, Preferences) VALUES
    (1, '{"workSchedule": "Remote", "notifications": {"email": true, "sms": false}, "theme": "Dark", "dashboard": ["Performance", "Tasks", "Calendar"]}'),
    (2, '{"workSchedule": "Hybrid", "notifications": {"email": true, "sms": true}, "theme": "Light", "dashboard": ["Projects", "Team", "Reports"]}');
END

-- 1. JSON_VALUE() - Extract scalar values from JSON
SELECT 
    EmployeeID,
    JSON_VALUE(SkillsData, '$.technical.level') AS TechnicalLevel,
    JSON_VALUE(ProjectHistory, '$.current.role') AS CurrentRole,
    -- Extract nested values
    JSON_VALUE(SkillsData, '$.technical.programming[0]') AS PrimaryProgrammingSkill
FROM HR.EmployeeSkills;
/* Output example:
EmployeeID  TechnicalLevel  CurrentRole  PrimaryProgrammingSkill
1           Senior          Lead         SQL
2           Mid             Developer    JavaScript
*/

-- 2. JSON_QUERY() - Extract arrays and objects from JSON
SELECT 
    EmployeeID,
    JSON_QUERY(SkillsData, '$.technical.programming') AS ProgrammingSkills,
    JSON_QUERY(SkillsData, '$.soft') AS SoftSkills,
    JSON_QUERY(ProjectHistory, '$.previous') AS PreviousProjects
FROM HR.EmployeeSkills;
/* Output example:
EmployeeID  ProgrammingSkills              SoftSkills                          PreviousProjects
1           ["SQL", "Python", "Java"]      ["Leadership", "Communication"]     [{"name": "Data Warehouse", "role": "Developer"}, {"name": "BI Dashboard", "role": "Analyst"}]
*/

-- 3. ISJSON() - Validate JSON data
SELECT 
    PreferenceID,
    EmployeeID,
    Preferences,
    ISJSON(Preferences) AS IsValidJSON,
    CASE 
        WHEN ISJSON(Preferences) = 1 THEN 'Valid JSON'
        ELSE 'Invalid JSON'
    END AS ValidationResult
FROM HR.EmployeePreferences;
/* Output example:
PreferenceID  EmployeeID  Preferences                                          IsValidJSON  ValidationResult
1             1           {"workSchedule": "Remote", "notifications": {...}}    1           Valid JSON
*/

-- 4. JSON_MODIFY() - Update JSON values
SELECT 
    EmployeeID,
    -- Update a simple value
    JSON_MODIFY(SkillsData, '$.technical.level', 'Principal') AS UpdatedLevel,
    -- Add a new value to an array
    JSON_MODIFY(SkillsData, 'append $.technical.programming', 'TypeScript') AS UpdatedSkills,
    -- Update nested object value
    JSON_MODIFY(ProjectHistory, '$.current.role', 'Senior Lead') AS UpdatedRole
FROM HR.EmployeeSkills
WHERE EmployeeID = 1;
/* Output example:
EmployeeID  UpdatedLevel                                                UpdatedSkills                                              UpdatedRole
1           {"technical":{"level":"Principal",...},...}                {"technical":{"programming":["SQL",...,"TypeScript"],...},...}  {"current":{"role":"Senior Lead",...},...}
*/

-- 5. OPENJSON() - Convert JSON to rowset
-- Example 1: Parse certification array
SELECT 
    es.EmployeeID,
    cert.*
FROM HR.EmployeeSkills es
CROSS APPLY OPENJSON(es.Certifications)
WITH (
    CertificationName VARCHAR(100) '$.name',
    CertificationYear INT '$.year',
    CertificationScore INT '$.score'
) cert;
/* Output example:
EmployeeID  CertificationName    CertificationYear  CertificationScore
1           SQL Server Expert    2022               95
1           Project Management   2021               88
*/

-- Example 2: Parse nested technical skills
SELECT 
    es.EmployeeID,
    tech.ProgrammingLanguage
FROM HR.EmployeeSkills es
CROSS APPLY OPENJSON(JSON_QUERY(es.SkillsData, '$.technical.programming')) 
WITH (ProgrammingLanguage VARCHAR(50) '$') tech;
/* Output example:
EmployeeID  ProgrammingLanguage
1           SQL
1           Python
1           Java
*/

-- Example 3: Parse preferences with nested objects
SELECT 
    ep.EmployeeID,
    pref.*
FROM HR.EmployeePreferences ep
CROSS APPLY OPENJSON(ep.Preferences)
WITH (
    WorkSchedule VARCHAR(20) '$.workSchedule',
    EmailNotifications BIT '$.notifications.email',
    SMSNotifications BIT '$.notifications.sms',
    Theme VARCHAR(20) '$.theme',
    DashboardConfig NVARCHAR(MAX) '$.dashboard' AS JSON
) pref;
/* Output example:
EmployeeID  WorkSchedule  EmailNotifications  SMSNotifications  Theme  DashboardConfig
1           Remote        1                  0                 Dark   ["Performance","Tasks","Calendar"]
*/

-- Complex example combining multiple JSON functions
SELECT 
    es.EmployeeID,
    -- Extract scalar values
    JSON_VALUE(es.SkillsData, '$.technical.level') AS TechnicalLevel,
    -- Extract and parse arrays
    JSON_QUERY(es.SkillsData, '$.technical.programming') AS ProgrammingSkills,
    -- Validate JSON
    ISJSON(es.ProjectHistory) AS IsValidProjectHistory,
    -- Modify JSON
    JSON_MODIFY(
        JSON_MODIFY(es.SkillsData, '$.technical.level', 
            CASE 
                WHEN JSON_VALUE(es.SkillsData, '$.technical.level') = 'Senior' THEN 'Principal'
                ELSE 'Senior'
            END
        ),
        'append $.soft',
        'Mentoring'
    ) AS UpdatedSkills,
    -- Parse certifications
    (
        SELECT 
            COUNT(*) AS CertificationCount,
            AVG(CAST(JSON_VALUE(value, '$.score') AS FLOAT)) AS AvgScore
        FROM OPENJSON(es.Certifications)
        WHERE CAST(JSON_VALUE(value, '$.year') AS INT) >= 2022
    ) AS RecentCertifications,
    -- Parse preferences
    JSON_VALUE(ep.Preferences, '$.workSchedule') AS WorkPreference,
    -- Check notification settings
    CASE 
        WHEN JSON_VALUE(ep.Preferences, '$.notifications.email') = 'true' 
             AND JSON_VALUE(ep.Preferences, '$.notifications.sms') = 'true'
        THEN 'All Notifications'
        WHEN JSON_VALUE(ep.Preferences, '$.notifications.email') = 'true'
        THEN 'Email Only'
        WHEN JSON_VALUE(ep.Preferences, '$.notifications.sms') = 'true'
        THEN 'SMS Only'
        ELSE 'No Notifications'
    END AS NotificationPreference
FROM HR.EmployeeSkills es
JOIN HR.EmployeePreferences ep ON es.EmployeeID = ep.EmployeeID;
/* Output example:
EmployeeID  TechnicalLevel  ProgrammingSkills              IsValidProjectHistory  UpdatedSkills                  RecentCertifications  WorkPreference  NotificationPreference
1           Senior          ["SQL", "Python", "Java"]      1                     {"technical":{...},"soft":[...]}  {"count":1,"avg":95}    Remote          Email Only
*/