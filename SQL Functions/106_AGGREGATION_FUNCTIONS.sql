/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\106_AGGREGATION_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Aggregate Functions with real-life examples
    using the HRSystem database schemas and tables.

    Aggregate Functions covered:
    1. SUM() - Calculates the total of numeric values
    2. AVG() - Calculates the average of numeric values
    3. COUNT() - Counts the number of rows or non-null values
    4. MIN() - Returns the minimum value
    5. MAX() - Returns the maximum value
    6. STRING_AGG() - Concatenates string values with a separator
    7. GROUPING() - Indicates whether a column is aggregated
    8. STDEV() - Calculates statistical standard deviation

    Additional Aggregate Functions covered:
    9. GROUPING_ID() - Returns a bit pattern indicating grouping level
    10. VAR() and VARP() - Calculate statistical variance
    11. STDEV() and STDEVP() - Calculate standard deviation
    12. COUNT_BIG() - Returns big integer count
    13. CHECKSUM_AGG() - Calculates checksum of values
*/

USE HRSystem;
GO

-- Sample data insertion (if not already present)
INSERT INTO HR.Departments (DepartmentName, LocationID) VALUES 
('IT', 1), ('HR', 1), ('Finance', 2), ('Marketing', 2);

INSERT INTO HR.EMP_Details (FirstName, LastName, Email, HireDate, DepartmentID, Salary) VALUES
('John', 'Doe', 'john.doe@email.com', '2020-01-15', 1, 75000),
('Jane', 'Smith', 'jane.smith@email.com', '2020-02-20', 1, 85000),
('Bob', 'Johnson', 'bob.johnson@email.com', '2021-03-10', 2, 65000),
('Alice', 'Brown', 'alice.brown@email.com', '2021-04-05', 3, 95000);

-- 1. SUM() Example - Calculate total salary budget by department
SELECT 
    d.DepartmentName,
    SUM(e.Salary) AS TotalDepartmentBudget
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName;
/* Output example:
DepartmentName    TotalDepartmentBudget
IT               160000
HR               65000
Finance          95000
*/

-- 2. AVG() Example - Calculate average salary by department
SELECT 
    d.DepartmentName,
    AVG(e.Salary) AS AverageSalary,
    COUNT(*) AS EmployeeCount
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName;

-- 3. COUNT() with different variations
SELECT 
    COUNT(*) AS TotalEmployees,              -- Counts all rows
    COUNT(Phone) AS EmployeesWithPhone,      -- Counts non-null phone numbers
    COUNT(DISTINCT DepartmentID) AS UniqueDepartments
FROM HR.EMP_Details;

-- 4. MIN() and 5. MAX() Example - Salary range by department
SELECT 
    d.DepartmentName,
    MIN(e.Salary) AS LowestSalary,
    MAX(e.Salary) AS HighestSalary,
    MAX(e.Salary) - MIN(e.Salary) AS SalaryRange
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName;

-- 6. STRING_AGG() Example - Concatenate employee names by department
SELECT 
    d.DepartmentName,
    STRING_AGG(CONCAT(e.FirstName, ' ', e.LastName), ', ') AS EmployeeList
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName;
/* Output example:
DepartmentName    EmployeeList
IT               John Doe, Jane Smith
HR               Bob Johnson
Finance          Alice Brown
*/

-- 7. GROUPING() Example - Hierarchical reporting with subtotals
SELECT 
    CASE 
        WHEN GROUPING(d.DepartmentName) = 1 THEN 'All Departments'
        ELSE d.DepartmentName 
    END AS Department,
    COUNT(*) AS EmployeeCount,
    SUM(e.Salary) AS TotalSalary
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY ROLLUP(d.DepartmentName);

-- 8. STDEV() Example - Salary deviation analysis
SELECT 
    d.DepartmentName,
    AVG(e.Salary) AS AverageSalary,
    STDEV(e.Salary) AS SalaryStandardDeviation,
    COUNT(*) AS EmployeeCount
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName
HAVING COUNT(*) > 1; -- Only show departments with more than one employee

-- 9. GROUPING_ID() Example - Multi-level grouping analysis
SELECT 
    CASE 
        WHEN GROUPING_ID(d.DepartmentName, YEAR(e.HireDate)) = 3 THEN 'Grand Total'
        WHEN GROUPING_ID(d.DepartmentName, YEAR(e.HireDate)) = 1 THEN d.DepartmentName + ' Total'
        ELSE d.DepartmentName + ' - ' + CAST(YEAR(e.HireDate) AS VARCHAR)
    END AS GroupLevel,
    COUNT(*) AS EmployeeCount,
    SUM(e.Salary) AS TotalSalary
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY ROLLUP(d.DepartmentName, YEAR(e.HireDate));
/* Output example:
GroupLevel           EmployeeCount    TotalSalary
IT - 2020           2                160000
IT Total            2                160000
HR - 2021           1                65000
HR Total            1                65000
Grand Total         3                225000
*/

-- 10. VAR() and VARP() Example - Salary variance analysis
SELECT 
    d.DepartmentName,
    COUNT(*) AS EmployeeCount,
    AVG(e.Salary) AS AverageSalary,
    VAR(e.Salary) AS SalaryVariance,        -- Sample variance
    VARP(e.Salary) AS SalaryPopVariance     -- Population variance
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName
HAVING COUNT(*) > 1;

-- 11. STDEV() and STDEVP() Example - Detailed statistical analysis
SELECT 
    d.DepartmentName,
    COUNT(*) AS EmployeeCount,
    AVG(e.Salary) AS AverageSalary,
    STDEV(e.Salary) AS SalaryStdDev,        -- Sample standard deviation
    STDEVP(e.Salary) AS SalaryPopStdDev     -- Population standard deviation
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName
HAVING COUNT(*) > 1;

-- 12. COUNT_BIG() Example - Large dataset counting
-- Useful for tables with more than 2 billion rows
SELECT 
    COUNT_BIG(*) AS TotalEmployeesBig,
    COUNT_BIG(DISTINCT DepartmentID) AS UniqueDepartmentsBig
FROM HR.EMP_Details;

-- 13. CHECKSUM_AGG() Example - Data change detection
SELECT 
    d.DepartmentName,
    COUNT(*) AS EmployeeCount,
    CHECKSUM_AGG(CAST(e.Salary AS INT)) AS SalaryChecksum
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName;

-- Example of using multiple aggregate functions together
SELECT 
    d.DepartmentName,
    COUNT(*) AS EmployeeCount,
    COUNT_BIG(*) AS EmployeeCountBig,
    SUM(e.Salary) AS TotalSalary,
    AVG(e.Salary) AS AverageSalary,
    MIN(e.Salary) AS MinSalary,
    MAX(e.Salary) AS MaxSalary,
    STRING_AGG(e.FirstName, ', ') AS EmployeeFirstNames,
    VAR(e.Salary) AS SalaryVariance,
    STDEV(e.Salary) AS SalaryStdDev,
    CHECKSUM_AGG(CAST(e.Salary AS INT)) AS SalaryChecksum
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
GROUP BY d.DepartmentName;

-- Create a sample table for demonstrating GROUPING_ID with multiple levels
CREATE TABLE HR.EmployeeProjects (
    ProjectID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeID INT REFERENCES HR.EMP_Details(EmployeeID),
    ProjectName VARCHAR(50),
    ProjectCost DECIMAL(12,2),
    StartDate DATE
);

-- Insert sample project data
INSERT INTO HR.EmployeeProjects (EmployeeID, ProjectName, ProjectCost, StartDate) VALUES
(1000, 'Project A', 50000, '2023-01-01'),
(1001, 'Project B', 75000, '2023-02-01'),
(1000, 'Project C', 60000, '2023-03-01'),
(1002, 'Project D', 45000, '2023-04-01');

-- Complex grouping example with GROUPING_ID
SELECT 
    CASE 
        WHEN GROUPING_ID(d.DepartmentName, YEAR(p.StartDate), DATEPART(QUARTER, p.StartDate)) = 7 
            THEN 'All Projects'
        WHEN GROUPING_ID(d.DepartmentName, YEAR(p.StartDate), DATEPART(QUARTER, p.StartDate)) = 3 
            THEN d.DepartmentName + ' Total'
        WHEN GROUPING_ID(d.DepartmentName, YEAR(p.StartDate), DATEPART(QUARTER, p.StartDate)) = 1 
            THEN d.DepartmentName + ' - ' + CAST(YEAR(p.StartDate) AS VARCHAR)
        ELSE d.DepartmentName + ' - ' + CAST(YEAR(p.StartDate) AS VARCHAR) + ' Q' + 
             CAST(DATEPART(QUARTER, p.StartDate) AS VARCHAR)
    END AS GroupLevel,
    COUNT(*) AS ProjectCount,
    SUM(p.ProjectCost) AS TotalCost
FROM HR.EMP_Details e
JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
JOIN HR.EmployeeProjects p ON e.EmployeeID = p.EmployeeID
GROUP BY ROLLUP(
    d.DepartmentName, 
    YEAR(p.StartDate), 
    DATEPART(QUARTER, p.StartDate)
);