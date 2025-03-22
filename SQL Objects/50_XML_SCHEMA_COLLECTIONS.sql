-- =============================================
-- SQL Server XML SCHEMA COLLECTIONS Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating XML Schema Collections
-- Basic XML Schema Collection creation
CREATE XML SCHEMA COLLECTION EmployeeXMLSchema AS 
'<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="Employee">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="EmployeeID" type="xs:integer"/>
        <xs:element name="FirstName" type="xs:string"/>
        <xs:element name="LastName" type="xs:string"/>
        <xs:element name="Email" type="xs:string"/>
        <xs:element name="Phone" type="xs:string" minOccurs="0"/>
        <xs:element name="Department" type="xs:string"/>
        <xs:element name="HireDate" type="xs:date"/>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>';
GO

-- Creating XML Schema Collection in a specific schema
CREATE XML SCHEMA COLLECTION HR.EmployeeResumeSchema AS 
'<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="Resume">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="Education">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="Degree" maxOccurs="unbounded">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element name="Institution" type="xs:string"/>
                    <xs:element name="Major" type="xs:string"/>
                    <xs:element name="Year" type="xs:integer"/>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
        <xs:element name="Experience">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="Job" maxOccurs="unbounded">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element name="Company" type="xs:string"/>
                    <xs:element name="Position" type="xs:string"/>
                    <xs:element name="StartDate" type="xs:date"/>
                    <xs:element name="EndDate" type="xs:date" minOccurs="0"/>
                    <xs:element name="Description" type="xs:string"/>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
        <xs:element name="Skills">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="Skill" type="xs:string" maxOccurs="unbounded"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>';
GO

-- 2. Using XML Schema Collections in Tables
-- Create a table with XML column using schema validation
CREATE TABLE HR.EmployeeXMLData (
    EmployeeDataID INT PRIMARY KEY IDENTITY(1,1),
    EmployeeID INT FOREIGN KEY REFERENCES HR.Employees(EmployeeID),
    EmployeeInfo XML(EmployeeXMLSchema),
    Resume XML(HR.EmployeeResumeSchema),
    LastUpdated DATETIME DEFAULT GETDATE()
);
GO

-- 3. Inserting Valid XML Data
-- Insert data that conforms to the schema
INSERT INTO HR.EmployeeXMLData (EmployeeID, EmployeeInfo)
VALUES (
    1001,
    '<Employee>
        <EmployeeID>1001</EmployeeID>
        <FirstName>John</FirstName>
        <LastName>Doe</LastName>
        <Email>john.doe@example.com</Email>
        <Phone>555-123-4567</Phone>
        <Department>IT</Department>
        <HireDate>2020-01-15</HireDate>
    </Employee>'
);
GO

-- Insert resume data
UPDATE HR.EmployeeXMLData
SET Resume = 
'<Resume>
    <Education>
        <Degree>
            <Institution>University of Technology</Institution>
            <Major>Computer Science</Major>
            <Year>2018</Year>
        </Degree>
        <Degree>
            <Institution>Business School</Institution>
            <Major>MBA</Major>
            <Year>2020</Year>
        </Degree>
    </Education>
    <Experience>
        <Job>
            <Company>Tech Solutions Inc.</Company>
            <Position>Junior Developer</Position>
            <StartDate>2018-06-01</StartDate>
            <EndDate>2019-12-31</EndDate>
            <Description>Developed web applications using .NET technologies</Description>
        </Job>
        <Job>
            <Company>HRSystem</Company>
            <Position>Senior Developer</Position>
            <StartDate>2020-01-15</StartDate>
            <Description>Leading development team for HR applications</Description>
        </Job>
    </Experience>
    <Skills>
        <Skill>C#</Skill>
        <Skill>SQL</Skill>
        <Skill>JavaScript</Skill>
        <Skill>Azure</Skill>
    </Skills>
</Resume>'
WHERE EmployeeID = 1001;
GO

-- 4. Attempting to Insert Invalid XML Data
-- This will fail because it doesn't conform to the schema
-- (Department is missing, which is required)
BEGIN TRY
    INSERT INTO HR.EmployeeXMLData (EmployeeID, EmployeeInfo)
    VALUES (
        1002,
        '<Employee>
            <EmployeeID>1002</EmployeeID>
            <FirstName>Jane</FirstName>
            <LastName>Smith</LastName>
            <Email>jane.smith@example.com</Email>
            <Phone>555-987-6543</Phone>
            <HireDate>2021-03-10</HireDate>
        </Employee>'
    );
    PRINT 'Insert succeeded';
END TRY
BEGIN CATCH
    PRINT 'Insert failed: ' + ERROR_MESSAGE();
END CATCH;
GO

-- 5. Modifying XML Schema Collections
-- SQL Server doesn't support direct ALTER XML SCHEMA COLLECTION statements
-- You need to drop and recreate the schema collection, but first handle dependencies

-- Create a new schema collection for demonstration
CREATE XML SCHEMA COLLECTION TempXMLSchema AS 
'<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="TempData">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="ID" type="xs:integer"/>
        <xs:element name="Value" type="xs:string"/>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>';
GO

-- Create a table using this schema collection
CREATE TABLE TempXMLTable (
    ID INT PRIMARY KEY,
    Data XML(TempXMLSchema)
);
GO

-- To modify the schema collection, we need to:
-- 1. Find all dependencies
SELECT 
    OBJECT_SCHEMA_NAME(o.object_id) + '.' + o.name AS TableName,
    c.name AS ColumnName
FROM sys.columns c
JOIN sys.objects o ON c.object_id = o.object_id
JOIN sys.xml_schema_collections x ON c.xml_collection_id = x.xml_collection_id
WHERE x.name = 'TempXMLSchema';
GO

-- 2. Drop the dependent objects or modify them to use a different type
DROP TABLE TempXMLTable;
GO

-- 3. Drop the schema collection
DROP XML SCHEMA COLLECTION TempXMLSchema;
GO

-- 4. Recreate the schema collection with new definition
CREATE XML SCHEMA COLLECTION TempXMLSchema AS 
'<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="TempData">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="ID" type="xs:integer"/>
        <xs:element name="Value" type="xs:string"/>
        <xs:element name="Description" type="xs:string"/>  <!-- New element added -->
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>';
GO

-- 5. Recreate the dependent objects
CREATE TABLE TempXMLTable (
    ID INT PRIMARY KEY,
    Data XML(TempXMLSchema)
);
GO

-- 6. Dropping XML Schema Collections
-- First, drop any dependencies
DROP TABLE TempXMLTable;
GO

-- Then drop the schema collection
DROP XML SCHEMA COLLECTION TempXMLSchema;
GO

-- 7. Querying XML Schema Collection Information
-- List all XML schema collections in the database
SELECT 
    xsc.name AS SchemaCollectionName,
    SCHEMA_NAME(xsc.schema_id) AS SchemaName,
    xsc.xml_collection_id,
    xsc.create_date,
    xsc.modify_date
FROM sys.xml_schema_collections xsc
WHERE xsc.schema_id != 4  -- Exclude system schema collections
ORDER BY SchemaName, SchemaCollectionName;
GO

-- Get XML schema collection content
SELECT 
    xsc.name AS SchemaCollectionName,
    SCHEMA_NAME(xsc.schema_id) AS SchemaName,
    xscn.name AS NamespaceURI,
    CAST(xsd.xmlcomponent AS XML) AS SchemaComponent
FROM sys.xml_schema_collections xsc
JOIN sys.xml_schema_namespaces xscn ON xsc.xml_collection_id = xscn.xml_collection_id
JOIN sys.xml_schema_components xsd ON xscn.xml_collection_id = xsd.xml_collection_id AND xscn.name = xsd.xml_namespace
WHERE xsc.schema_id != 4  -- Exclude system schema collections
ORDER BY SchemaName, SchemaCollectionName, NamespaceURI;
GO

-- Find tables using XML schema collections
SELECT 
    OBJECT_SCHEMA_NAME(o.object_id) + '.' + o.name AS TableName,
    c.name AS ColumnName,
    SCHEMA_NAME(xsc.schema_id) + '.' + xsc.name AS SchemaCollectionName
FROM sys.columns c
JOIN sys.objects o ON c.object_id = o.object_id
JOIN sys.xml_schema_collections xsc ON c.xml_collection_id = xsc.xml_collection_id
WHERE o.type = 'U'  -- User tables only
ORDER BY TableName, ColumnName;
GO

-- 8. Querying XML Data with XQuery
-- Query XML data using XQuery expressions
SELECT 
    EmployeeID,
    EmployeeInfo.value('(/Employee/FirstName)[1]', 'VARCHAR(50)') AS FirstName,
    EmployeeInfo.value('(/Employee/LastName)[1]', 'VARCHAR(50)') AS LastName,
    EmployeeInfo.value('(/Employee/Email)[1]', 'VARCHAR(100)') AS Email,
    EmployeeInfo.value('(/Employee/Department)[1]', 'VARCHAR(50)') AS Department
FROM HR.EmployeeXMLData;
GO

-- Query resume data
SELECT 
    EmployeeID,
    Resume.query('/Resume/Education/Degree') AS Education,
    Resume.query('/Resume/Skills/Skill') AS Skills
FROM HR.EmployeeXMLData
WHERE EmployeeID = 1001;
GO

-- Find employees with specific skills
SELECT 
    EmployeeID
FROM HR.EmployeeXMLData
WHERE Resume.exist('/Resume/Skills/Skill[text()="SQL"]') = 1;
GO

-- 9. Modifying XML Data
-- Update XML data using modify() method
UPDATE HR.EmployeeXMLData
SET EmployeeInfo.modify('
    replace value of (/Employee/Phone/text())[1]
    with "555-111-2222"
')
WHERE EmployeeID = 1001;
GO

-- Add a new skill to the resume
UPDATE HR.EmployeeXMLData
SET Resume.modify('
    insert <Skill>XML</Skill>
    into (/Resume/Skills)[1]
')
WHERE EmployeeID = 1001;
GO

-- 10. XML Indexes
-- Create a primary XML index
CREATE PRIMARY XML INDEX IDX_EmployeeInfo_XML 
ON HR.EmployeeXMLData(EmployeeInfo);
GO

-- Create secondary XML indexes
CREATE XML INDEX IDX_EmployeeInfo_XML_Path 
ON HR.EmployeeXMLData(EmployeeInfo)
USING XML INDEX IDX_EmployeeInfo_XML FOR PATH;
GO

CREATE XML INDEX IDX_EmployeeInfo_XML_Value 
ON HR.EmployeeXMLData(EmployeeInfo)
USING XML INDEX IDX_EmployeeInfo_XML FOR VALUE;
GO

CREATE XML INDEX IDX_EmployeeInfo_XML_Property 
ON HR.EmployeeXMLData(EmployeeInfo)
USING XML INDEX IDX_EmployeeInfo_XML FOR PROPERTY;
GO

-- 11. XML Schema Collection Best Practices
-- Example of using XML schema collection with namespaces
CREATE XML SCHEMA COLLECTION ProjectXMLSchema AS 
'<?xml version="1.0" encoding="UTF-8"?>