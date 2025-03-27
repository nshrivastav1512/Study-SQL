/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\123_XML_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server XML Functions
    using the HRSystem database. These functions help in handling
    and querying XML data structures.

    XML Functions covered:
    1. XMLNAMESPACES - Declare XML namespaces
    2. NODES - Extract nodes from XML
    3. VALUE - Extract scalar value
    4. QUERY - Query XML data
    5. EXISTS - Check XML node existence
    6. MODIFY - Modify XML data
*/

USE HRSystem;
GO

-- Create tables for storing XML data if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[EmployeeXMLData]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.EmployeeXMLData (
        EmployeeID INT PRIMARY KEY,
        PersonalInfo XML,
        WorkHistory XML,
        Skills XML,
        LastModified DATETIME2 DEFAULT SYSDATETIME(),
        ModifiedBy NVARCHAR(50)
    );

    -- Insert sample XML data
    INSERT INTO HR.EmployeeXMLData (EmployeeID, PersonalInfo, WorkHistory, Skills, ModifiedBy)
    VALUES
    (1,
    '<Employee xmlns="http://schemas.hr.com/employee">
        <Name>John Doe</Name>
        <BirthDate>1985-03-15</BirthDate>
        <Contact>
            <Email>john.doe@email.com</Email>
            <Phone>555-0101</Phone>
            <Address>
                <Street>123 Main St</Street>
                <City>New York</City>
                <State>NY</State>
                <ZipCode>10001</ZipCode>
            </Address>
        </Contact>
    </Employee>',
    '<WorkHistory xmlns="http://schemas.hr.com/work">
        <Position>
            <Title>Senior Developer</Title>
            <Department>IT</Department>
            <StartDate>2020-01-15</StartDate>
            <Salary>85000</Salary>
        </Position>
        <Position>
            <Title>Developer</Title>
            <Department>IT</Department>
            <StartDate>2018-06-01</StartDate>
            <EndDate>2019-12-31</EndDate>
            <Salary>65000</Salary>
        </Position>
    </WorkHistory>',
    '<Skills xmlns="http://schemas.hr.com/skills">
        <Skill>
            <Name>SQL Server</Name>
            <Level>Expert</Level>
            <YearsExperience>8</YearsExperience>
        </Skill>
        <Skill>
            <Name>Python</Name>
            <Level>Intermediate</Level>
            <YearsExperience>5</YearsExperience>
        </Skill>
        <Skill>
            <Name>Azure</Name>
            <Level>Advanced</Level>
            <YearsExperience>3</YearsExperience>
        </Skill>
    </Skills>',
    SYSTEM_USER);
END

-- 1. XMLNAMESPACES - Declare XML namespaces for queries
WITH XMLNAMESPACES (
    'http://schemas.hr.com/employee' AS emp,
    'http://schemas.hr.com/work' AS work,
    'http://schemas.hr.com/skills' AS skills
)
SELECT 
    EmployeeID,
    PersonalInfo.query('/emp:Employee/emp:Name') AS EmployeeName,
    WorkHistory.query('/work:WorkHistory/work:Position[1]/work:Title') AS CurrentPosition,
    Skills.query('/skills:Skills/skills:Skill/skills:Name') AS SkillNames
FROM HR.EmployeeXMLData;

-- 2. NODES - Extract individual nodes from XML
WITH XMLNAMESPACES ('http://schemas.hr.com/skills' AS skills)
SELECT 
    EmployeeID,
    Skill.value('(skills:Name)[1]', 'NVARCHAR(50)') AS SkillName,
    Skill.value('(skills:Level)[1]', 'NVARCHAR(20)') AS SkillLevel,
    Skill.value('(skills:YearsExperience)[1]', 'INT') AS Experience
FROM HR.EmployeeXMLData
CROSS APPLY Skills.nodes('/skills:Skills/skills:Skill') AS SkillTable(Skill);

-- 3. VALUE - Extract specific values from XML
WITH XMLNAMESPACES ('http://schemas.hr.com/employee' AS emp)
SELECT 
    EmployeeID,
    PersonalInfo.value('(/emp:Employee/emp:Name)[1]', 'NVARCHAR(100)') AS Name,
    PersonalInfo.value('(/emp:Employee/emp:Contact/emp:Email)[1]', 'NVARCHAR(100)') AS Email,
    PersonalInfo.value('(/emp:Employee/emp:Contact/emp:Address/emp:City)[1]', 'NVARCHAR(50)') AS City
FROM HR.EmployeeXMLData;

-- 4. QUERY - Query XML data with complex conditions
WITH XMLNAMESPACES ('http://schemas.hr.com/work' AS work)
SELECT 
    EmployeeID,
    WorkHistory.query('
        for $pos in /work:WorkHistory/work:Position
        where $pos/work:Salary > 70000
        return $pos
    ') AS HighPayingPositions
FROM HR.EmployeeXMLData;

-- 5. EXISTS - Check for specific conditions in XML
WITH XMLNAMESPACES ('http://schemas.hr.com/skills' AS skills)
SELECT 
    EmployeeID,
    CASE 
        WHEN Skills.exist('/skills:Skills/skills:Skill[skills:Level="Expert"]') = 1
        THEN 'Has Expert Skills'
        ELSE 'No Expert Skills'
    END AS ExpertiseStatus
FROM HR.EmployeeXMLData;

-- 6. MODIFY - Update XML data
DECLARE @NewSkill XML;
SET @NewSkill = '
<Skill xmlns="http://schemas.hr.com/skills">
    <Name>Docker</Name>
    <Level>Beginner</Level>
    <YearsExperience>1</YearsExperience>
</Skill>';

UPDATE HR.EmployeeXMLData
SET Skills.modify('
    insert sql:variable("@NewSkill")
    as last into (/Skills)[1]
'),
LastModified = SYSDATETIME(),
ModifiedBy = SYSTEM_USER
WHERE EmployeeID = 1;

-- Create a view for XML data analysis
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[HR].[EmployeeXMLSummary]'))
BEGIN
    EXECUTE sp_executesql N'
    CREATE VIEW HR.EmployeeXMLSummary
    WITH SCHEMABINDING
    AS
    WITH XMLNAMESPACES (
        ''http://schemas.hr.com/employee'' AS emp,
        ''http://schemas.hr.com/work'' AS work,
        ''http://schemas.hr.com/skills'' AS skills
    )
    SELECT 
        EmployeeID,
        PersonalInfo.value(''(/emp:Employee/emp:Name)[1]'', ''NVARCHAR(100)'') AS EmployeeName,
        PersonalInfo.value(''(/emp:Employee/emp:Contact/emp:Email)[1]'', ''NVARCHAR(100)'') AS Email,
        WorkHistory.value(''(/work:WorkHistory/work:Position[1]/work:Title)[1]'', ''NVARCHAR(100)'') AS CurrentPosition,
        WorkHistory.value(''(/work:WorkHistory/work:Position[1]/work:Salary)[1]'', ''DECIMAL(10,2)'') AS CurrentSalary,
        Skills.value(''count(/skills:Skills/skills:Skill)'', ''INT'') AS TotalSkills,
        LastModified,
        ModifiedBy
    FROM dbo.EmployeeXMLData;
    ';
END

-- Example of complex XML analysis
WITH XMLNAMESPACES (
    'http://schemas.hr.com/employee' AS emp,
    'http://schemas.hr.com/work' AS work,
    'http://schemas.hr.com/skills' AS skills
)
SELECT 
    e.EmployeeID,
    e.PersonalInfo.value('(/emp:Employee/emp:Name)[1]', 'NVARCHAR(100)') AS Name,
    e.WorkHistory.query('
        for $pos in /work:WorkHistory/work:Position
        order by $pos/work:StartDate descending
        return concat($pos/work:Title, " (", $pos/work:StartDate, ")")'
    ) AS CareerProgression,
    e.Skills.query('
        for $skill in /skills:Skills/skills:Skill
        where $skill/skills:Level = "Expert"
        return $skill/skills:Name
    ') AS ExpertSkills,
    s.TotalSkills,
    s.CurrentPosition,
    s.CurrentSalary
FROM HR.EmployeeXMLData e
JOIN HR.EmployeeXMLSummary s ON e.EmployeeID = s.EmployeeID
WHERE e.Skills.exist('/skills:Skills/skills:Skill[skills:Level="Expert"]') = 1;