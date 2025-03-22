-- =============================================
-- INSERT Operations Complete Guide
-- =============================================
/*
-- INSERT Keyword Complete Guide
-- The INSERT statement is a DML (Data Manipulation Language) command used to add new rows of data into a database table. It supports single-row insertion, multi-row insertion, and inserting data from other tables or result sets. The INSERT statement can be used with VALUES clause for direct data insertion, with SELECT statement for inserting query results, and with EXEC for inserting data from stored procedure results.

1. Basic INSERT Statement: This section demonstrates the fundamental usage of INSERT statement with VALUES clause to add single and multiple rows, showing proper column listing, handling NULL values, and using default values while maintaining data integrity and type constraints.
2. INSERT with SELECT Statement: This section illustrates how to insert data by querying from other tables, including filtering conditions, joining multiple tables, and using derived columns, while ensuring data consistency and handling potential duplicate records.
3. Bulk INSERT Operations: This section covers techniques for inserting large volumes of data efficiently, including BULK INSERT command for file imports, table-valued parameters, and using temporary tables as staging areas, with consideration for transaction management and performance optimization.
4. INSERT with IDENTITY Columns: This section explains working with identity columns, including IDENTITY_INSERT settings, retrieving generated identity values using SCOPE_IDENTITY(), and handling identity column reseeding scenarios while maintaining referential integrity.
5. INSERT with Computed Columns: This section demonstrates inserting data into tables with computed columns, showing how to handle persisted vs. non-persisted computed columns, and understanding the implications of dependencies on other columns.
6. INSERT with Triggers: This section covers considerations when inserting data into tables with INSERT triggers, including handling recursive triggers, managing trigger execution order, and ensuring data consistency across related tables.
7. INSERT with Constraints: This section shows how to insert data while respecting various constraints including CHECK constraints, UNIQUE constraints, and FOREIGN KEY constraints, with proper error handling and validation.
8. INSERT with Table Variables and Temporary Tables: This section illustrates inserting data into table variables and temporary tables, including scope considerations, session management, and performance implications.
9. INSERT with OUTPUT Clause: This section demonstrates using the OUTPUT clause to capture inserted data, including inserted identity values, computed columns, and using the inserted virtual table for audit trailing and data verification.
10. INSERT Error Handling: This section covers proper error handling techniques for INSERT operations, including TRY-CATCH blocks, handling constraint violations, and managing transaction rollbacks while maintaining data integrity.
11. INSERT Performance Considerations: This section discusses optimization techniques for INSERT operations, including proper indexing strategies, minimizing logging, and managing lock escalation while balancing performance and concurrency.
12. INSERT with Partitioned Tables: This section explains inserting data into partitioned tables, including partition scheme considerations, handling partition switching, and managing data distribution across partitions.

Author: Nikhil Shrivastav
Date: February 2025
*/

USE HRSystem;
GO

-- 1. Basic INSERT Operations
-- 1.1 Single Row Insert
INSERT INTO HR.Departments (DepartmentName, LocationID)
VALUES ('Research & Development', 1);

-- 1.2 Multi-Row Insert
INSERT INTO HR.Locations (City, State, Country)
VALUES 
    ('Seattle', 'Washington', 'USA'),
    ('London', NULL, 'UK'),
    ('Mumbai', 'Maharashtra', 'India');

-- 1.3 Insert with DEFAULT Values
INSERT INTO HR.EMP_Details 
    (FirstName, LastName, Email, HireDate, DepartmentID, Salary)
VALUES 
    ('John', 'Doe', 'john.doe@hr.com', DEFAULT, 1, 50000);

-- 2. INSERT INTO SELECT
-- 2.1 Basic INSERT INTO SELECT
INSERT INTO PAYROLL.Salary_History (EmployeeID, OldSalary, NewSalary, EffectiveDate)
SELECT 
    EmployeeID,
    Salary,
    Salary * 1.1,
    GETDATE()
FROM HR.EMP_Details
WHERE DepartmentID = 1;

-- 2.2 INSERT INTO SELECT with JOIN
INSERT INTO HR.Performance_Reviews (EmployeeID, ReviewDate, Rating, ReviewedBy)
SELECT 
    e.EmployeeID,
    GETDATE(),
    4,
    d.ManagerID
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID;

-- 3. INSERT with OUTPUT
-- 3.1 Basic OUTPUT
INSERT INTO HR.Locations (City, State, Country)
OUTPUT 
    inserted.LocationID,
    inserted.City,
    inserted.Country
VALUES ('Tokyo', NULL, 'Japan');

-- 3.2 OUTPUT into Table Variable
DECLARE @InsertedEmployees TABLE (
    EmployeeID INT,
    FullName VARCHAR(100),
    InsertedAt DATETIME
);

INSERT INTO HR.EMP_Details (FirstName, LastName, Email, HireDate, DepartmentID, Salary)
OUTPUT 
    inserted.EmployeeID,
    inserted.FirstName + ' ' + inserted.LastName,
    GETDATE()
INTO @InsertedEmployees
VALUES 
    ('Jane', 'Smith', 'jane.smith@hr.com', GETDATE(), 1, 60000);

-- 4. INSERT with EXECUTE
-- 4.1 Dynamic INSERT
DECLARE @TableName NVARCHAR(100) = 'HR.Departments';
DECLARE @SQL NVARCHAR(MAX);

SET @SQL = N'INSERT INTO ' + @TableName + 
          N' (DepartmentName, LocationID) VALUES (@Name, @LocID)';

EXECUTE sp_executesql @SQL, 
    N'@Name NVARCHAR(50), @LocID INT',
    @Name = N'Legal Affairs',
    @LocID = 1;

-- 5. INSERT with Table Constructor
-- 5.1 Using Table Value Constructor
INSERT INTO HR.TrainingCourses (CourseID, CourseName)
SELECT CourseID, CourseName
FROM (VALUES
    (2, 'Project Management'),
    (3, 'Leadership Skills'),
    (4, 'Technical Writing')
) AS Courses(CourseID, CourseName);

-- 6. INSERT with TOP
INSERT TOP(5) INTO HR.Performance_Reviews 
    (EmployeeID, ReviewDate, Rating, ReviewedBy)
SELECT 
    EmployeeID,
    GETDATE(),
    5,
    1000
FROM HR.EMP_Details
WHERE ReviewDate IS NULL;

-- 7. INSERT into Partitioned Table
INSERT INTO HR.PartitionedEmployees (EmployeeID, Name, Department)
VALUES 
    (1300, 'Sarah Connor', 'Security'),
    (2100, 'Kyle Reese', 'Operations');

-- 8. INSERT with IDENTITY_INSERT
SET IDENTITY_INSERT HR.EMP_Details ON;

INSERT INTO HR.EMP_Details 
    (EmployeeID, FirstName, LastName, Email, HireDate, DepartmentID, Salary)
VALUES 
    (9999, 'Special', 'Employee', 'special@hr.com', GETDATE(), 1, 75000);

SET IDENTITY_INSERT HR.EMP_Details OFF;

-- 9. INSERT with SELECT INTO (Creating New Table)
SELECT EmployeeID, FirstName, LastName, Salary
INTO #HighPaidEmployees
FROM HR.EMP_Details
WHERE Salary > 70000;

-- 10. INSERT with OPENROWSET (External Data)
-- Note: Requires appropriate permissions
/*
INSERT INTO HR.EMP_Details (FirstName, LastName, Email, HireDate, DepartmentID, Salary)
SELECT FirstName, LastName, Email, HireDate, DeptID, Salary
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=C:\Employees.xlsx;HDR=YES',
    'SELECT * FROM [Sheet1$]'
);
*/

-- 11. Bulk Insert Example
-- Note: Requires file access permissions
/*
BULK INSERT HR.Locations
FROM 'C:\Locations.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    MAXERRORS = 0,
    TABLOCK
);
*/

-- 12. INSERT with Error Handling
    BEGIN TRY
        BEGIN TRANSACTION;
            INSERT INTO HR.EMP_Details 
                (FirstName, LastName, Email, HireDate, DepartmentID, Salary)
            VALUES 
                ('Test', 'User', 'invalid_email', GETDATE(), 999, 50000);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        INSERT INTO HR.AuditLog (Action, TableName, UserName)
        VALUES ('Failed Insert', 'HR.EMP_Details', SYSTEM_USER);
        
        THROW;
    END CATCH;