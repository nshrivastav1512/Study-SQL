-- =============================================
-- DQL Advanced Filtering
-- =============================================

USE HRSystem;
GO

-- 1. Comparison Operators
-- These operators compare values and return TRUE or FALSE
-- Rows are returned only when the condition evaluates to TRUE

-- Equal (=): Returns rows where values match exactly
SELECT * FROM HR.EMP_Details WHERE Salary = 50000;
-- Returns only employees with a salary of exactly $50,000

-- Not Equal (!=, <>): Returns rows where values don't match
SELECT * FROM HR.EMP_Details WHERE Salary != 50000;  -- Both operators
SELECT * FROM HR.EMP_Details WHERE Salary <> 50000;  -- do the same thing
-- Returns all employees except those with a salary of $50,000

-- Greater Than (>): Returns rows where values exceed the comparison
SELECT * FROM HR.EMP_Details WHERE Salary > 50000;
-- Returns employees with salaries above $50,000

-- Less Than (<): Returns rows where values are below the comparison
SELECT * FROM HR.EMP_Details WHERE Salary < 50000;
-- Returns employees with salaries below $50,000

-- Greater Than or Equal (>=): Returns rows where values are >= comparison
SELECT * FROM HR.EMP_Details WHERE Salary >= 50000;
-- Returns employees with salaries of $50,000 or higher

-- Less Than or Equal (<=): Returns rows where values are <= comparison
SELECT * FROM HR.EMP_Details WHERE Salary <= 50000;
-- Returns employees with salaries of $50,000 or lower

-- 2. Logical Operators
-- Combine multiple conditions for complex filtering

-- AND: Both conditions must be TRUE
SELECT * FROM HR.EMP_Details 
WHERE DepartmentID = 1 AND Salary > 50000;
-- Returns employees who are BOTH in department 1 AND earn more than $50,000
-- If either condition is FALSE, the row is not returned

-- OR: At least one condition must be TRUE
SELECT * FROM HR.EMP_Details 
WHERE DepartmentID = 1 OR DepartmentID = 2;
-- Returns employees who are in EITHER department 1 OR department 2
-- The row is returned if either condition is TRUE

-- NOT: Negates a condition (TRUE becomes FALSE, FALSE becomes TRUE)
SELECT * FROM HR.EMP_Details 
WHERE NOT DepartmentID = 3;
-- Returns all employees EXCEPT those in department 3
-- Equivalent to: WHERE DepartmentID <> 3

-- 3. BETWEEN Operator
-- Shorthand for >= AND <= (inclusive range)

-- Numeric range
SELECT * FROM HR.EMP_Details 
WHERE Salary BETWEEN 40000 AND 60000;
-- Returns employees with salaries from $40,000 to $60,000 (inclusive)
-- Equivalent to: WHERE Salary >= 40000 AND Salary <= 60000

-- Date range
SELECT * FROM HR.EMP_Details 
WHERE HireDate BETWEEN '2020-01-01' AND '2020-12-31';
-- Returns employees hired during the year 2020
-- Includes both January 1 and December 31, 2020

-- 4. IN Operator
-- Shorthand for multiple OR conditions

-- Numeric IN list
SELECT * FROM HR.EMP_Details 
WHERE DepartmentID IN (1, 3, 5);
-- Returns employees in departments 1, 3, or 5
-- Equivalent to: WHERE DepartmentID = 1 OR DepartmentID = 3 OR DepartmentID = 5

-- String IN list
SELECT * FROM HR.EMP_Details 
WHERE LastName IN ('Smith', 'Johnson', 'Williams');
-- Returns employees with last names Smith, Johnson, or Williams

-- 5. LIKE Operator with Wildcards
-- Pattern matching for strings

-- % wildcard: Matches any string of zero or more characters
SELECT * FROM HR.EMP_Details 
WHERE LastName LIKE 'S%';
-- Returns employees whose last name starts with 'S'
-- Examples: Smith, Stevens, Sanchez, S

SELECT * FROM HR.EMP_Details 
WHERE Email LIKE '%@gmail.com';
-- Returns employees with Gmail addresses
-- The % matches anything before @gmail.com

-- _ wildcard: Matches exactly one character
SELECT * FROM HR.EMP_Details 
WHERE FirstName LIKE '_a%';
-- Returns employees whose first name has 'a' as the second letter
-- Examples: James, David, Nancy, Sam

-- Character ranges with []
SELECT * FROM HR.EMP_Details 
WHERE Phone LIKE '[0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]';
-- Returns employees with phone numbers in the format: 123-456-7890

-- 6. NULL Handling
-- Special operators for NULL values
-- NULL means "no value" or "unknown" - not zero, not empty string

-- IS NULL: Finds rows with NULL values
SELECT * FROM HR.EMP_Details 
WHERE ManagerID IS NULL;
-- Returns employees without a manager
-- Note: WHERE ManagerID = NULL would not work!

-- IS NOT NULL: Finds rows without NULL values
SELECT * FROM HR.EMP_Details 
WHERE MiddleName IS NOT NULL;
-- Returns employees who have a middle name

-- 7. Compound Conditions
-- Complex filtering with parentheses to control evaluation order

SELECT * FROM HR.EMP_Details 
WHERE (DepartmentID = 1 OR DepartmentID = 2)
AND Salary > 50000;
-- Returns employees who:
-- 1. Are in department 1 OR 2, AND
-- 2. Have a salary over $50,000
-- Parentheses ensure the OR is evaluated first, then the AND

-- 8. EXISTS Operator
-- Checks if a subquery returns any rows
-- Returns TRUE if at least one row is returned, FALSE otherwise

SELECT * FROM HR.Departments d
WHERE EXISTS (
    SELECT 1 FROM HR.EMP_Details e
    WHERE e.DepartmentID = d.DepartmentID  -- This links the subquery to the outer query
    AND e.Salary > 70000
);
-- DETAILED EXPLANATION:
-- 1. The outer query starts to process each department (d) one by one
-- 2. For EACH department being processed, the subquery runs
-- 3. The subquery looks for employees (e) who:
--    a. Belong to the CURRENT department being processed (e.DepartmentID = d.DepartmentID)
--    b. Have a salary over $70,000
-- 4. If the subquery finds ANY employees meeting these conditions, EXISTS returns TRUE
-- 5. Only departments where EXISTS returns TRUE are included in the final result
--
-- Result: Returns only departments that have at least one employee earning over $70,000

-- 9. NOT EXISTS
-- Opposite of EXISTS - returns TRUE if subquery returns no rows

SELECT * FROM HR.Departments d
WHERE NOT EXISTS (
    SELECT 1 FROM HR.EMP_Details e
    WHERE e.DepartmentID = d.DepartmentID
);
-- Returns departments that have no employees
-- For each department, checks if there are any matching employees
-- Only returns departments where no matching employees are found

-- 10. ALL Operator
-- Returns TRUE if all values returned by subquery satisfy the condition

SELECT * FROM HR.EMP_Details
WHERE Salary > ALL (
    SELECT AVG(Salary) FROM HR.EMP_Details
    GROUP BY DepartmentID
);
-- Returns employees whose salary is higher than ALL department averages
-- 1. Subquery calculates average salary for each department
-- 2. Main query finds employees with salary greater than ALL these averages
-- 3. Only employees with salary higher than EVERY department's average are returned

-- 11. ANY/SOME Operator
-- Returns TRUE if any value returned by subquery satisfies the condition
-- ANY and SOME are identical in functionality

SELECT * FROM HR.EMP_Details
WHERE Salary > ANY (
    SELECT Salary FROM HR.EMP_Details
    WHERE DepartmentID = 1
);
-- Returns employees whose salary is higher than ANY employee in department 1
-- If the lowest salary in department 1 is $40,000, this returns all employees
-- with salaries above $40,000, regardless of their department

-- 12. Filtering with Scalar Subqueries
-- Uses a subquery that returns a single value

SELECT * FROM HR.EMP_Details
WHERE DepartmentID = (
    SELECT DepartmentID FROM HR.Departments
    WHERE DepartmentName = 'Finance'
);
-- Returns all employees in the Finance department
-- 1. Subquery finds the DepartmentID for 'Finance'
-- 2. Main query uses this ID to filter employees

-- 13. Filtering with CASE
-- Uses conditional logic in the WHERE clause

SELECT * FROM HR.EMP_Details
WHERE 
    CASE 
        WHEN DepartmentID = 1 THEN Salary > 60000  -- HR department needs higher salary
        WHEN DepartmentID = 2 THEN Salary > 70000  -- IT department needs even higher
        ELSE Salary > 50000                        -- Other departments need lower
    END;
-- Returns employees who meet department-specific salary thresholds
-- Different salary requirements based on department

-- 14. Date Filtering
-- Various techniques for working with dates

-- Extract parts of dates
SELECT * FROM HR.EMP_Details
WHERE YEAR(HireDate) = 2020;
-- Returns employees hired in 2020, regardless of month or day

-- Calculate date differences
SELECT * FROM HR.EMP_Details
WHERE DATEDIFF(YEAR, HireDate, GETDATE()) > 5;
-- Returns employees who have been with the company for more than 5 years
-- DATEDIFF calculates the difference between HireDate and current date

-- 15. String Filtering Functions
-- Uses string functions in WHERE clause

-- String length
SELECT * FROM HR.EMP_Details
WHERE LEN(LastName) > 6;
-- Returns employees whose last name is longer than 6 characters

-- Substring extraction
SELECT * FROM HR.EMP_Details
WHERE SUBSTRING(Email, 1, 1) = 'j';
-- Returns employees whose email starts with 'j'
-- SUBSTRING(column, start, length) extracts part of a string