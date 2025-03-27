/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\118_STATISTICAL_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Statistical Functions
    using the HRSystem database. These functions help in analyzing data
    distributions and correlations.

    Statistical Functions covered:
    1. PERCENTILE_CONT - Continuous percentile
    2. PERCENTILE_DISC - Discrete percentile
    3. CUME_DIST - Cumulative distribution
    4. PERCENT_RANK - Relative rank
    5. STDEV - Standard deviation
    6. VAR - Statistical variance
    7. VARP - Population variance
    8. CORR - Correlation coefficient
    9. COVAR_POP - Population covariance
    10. COVAR_SAMP - Sample covariance
*/

USE HRSystem;
GO

-- Create sample tables if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[EmployeeStats]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.EmployeeStats (
        EmployeeID INT PRIMARY KEY,
        Salary DECIMAL(10,2),
        YearsOfService INT,
        PerformanceScore DECIMAL(3,2),
        SalesAmount DECIMAL(12,2),
        Department NVARCHAR(50)
    );

    -- Insert sample data
    INSERT INTO HR.EmployeeStats (EmployeeID, Salary, YearsOfService, PerformanceScore, SalesAmount, Department)
    VALUES
        (1, 55000.00, 3, 4.2, 150000.00, 'Sales'),
        (2, 62000.00, 5, 4.5, 180000.00, 'Sales'),
        (3, 48000.00, 2, 3.8, 120000.00, 'Sales'),
        (4, 71000.00, 7, 4.7, 220000.00, 'Sales'),
        (5, 45000.00, 1, 3.5, 90000.00, 'Sales'),
        (6, 58000.00, 4, 4.0, 160000.00, 'Sales'),
        (7, 67000.00, 6, 4.3, 200000.00, 'Sales'),
        (8, 52000.00, 3, 3.9, 140000.00, 'Sales'),
        (9, 75000.00, 8, 4.8, 250000.00, 'Sales'),
        (10, 49000.00, 2, 3.7, 110000.00, 'Sales');
END

-- 1. PERCENTILE_CONT - Calculate median salary (0.5)
SELECT 
    Department,
    PERCENTILE_CONT(0.5) 
    WITHIN GROUP (ORDER BY Salary)
    OVER (PARTITION BY Department) AS MedianSalary
FROM HR.EmployeeStats
GROUP BY Department, Salary;

-- 2. PERCENTILE_DISC - Calculate discrete 75th percentile of performance scores
SELECT 
    Department,
    PERCENTILE_DISC(0.75) 
    WITHIN GROUP (ORDER BY PerformanceScore)
    OVER (PARTITION BY Department) AS Top25PercentScore
FROM HR.EmployeeStats
GROUP BY Department, PerformanceScore;

-- 3. CUME_DIST - Calculate cumulative distribution of salaries
SELECT 
    EmployeeID,
    Salary,
    CUME_DIST() OVER (ORDER BY Salary) AS SalaryCumulativeDistribution
FROM HR.EmployeeStats;

-- 4. PERCENT_RANK - Calculate relative ranking by performance
SELECT 
    EmployeeID,
    PerformanceScore,
    PERCENT_RANK() OVER (ORDER BY PerformanceScore) AS PerformanceRank
FROM HR.EmployeeStats;

-- 5. STDEV - Calculate standard deviation of salaries
SELECT 
    Department,
    STDEV(Salary) AS SalaryStandardDeviation,
    AVG(Salary) AS AverageSalary
FROM HR.EmployeeStats
GROUP BY Department;

-- 6. VAR - Calculate variance of performance scores
SELECT 
    Department,
    VAR(PerformanceScore) AS ScoreVariance,
    AVG(PerformanceScore) AS AverageScore
FROM HR.EmployeeStats
GROUP BY Department;

-- 7. VARP - Calculate population variance of sales amounts
SELECT 
    Department,
    VARP(SalesAmount) AS SalesVariance,
    AVG(SalesAmount) AS AverageSales
FROM HR.EmployeeStats
GROUP BY Department;

-- 8. CORR - Calculate correlation between years of service and performance
SELECT 
    Department,
    CORR(YearsOfService, PerformanceScore) AS ServicePerformanceCorrelation
FROM HR.EmployeeStats
GROUP BY Department;

-- 9. COVAR_POP - Calculate population covariance between salary and sales
SELECT 
    Department,
    COVAR_POP(Salary, SalesAmount) AS SalarySalesCovariance
FROM HR.EmployeeStats
GROUP BY Department;

-- 10. COVAR_SAMP - Calculate sample covariance between performance and sales
SELECT 
    Department,
    COVAR_SAMP(PerformanceScore, SalesAmount) AS PerformanceSalesCovariance
FROM HR.EmployeeStats
GROUP BY Department;

-- Create a view for statistical analysis
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[HR].[EmployeeStatistics]'))
BEGIN
    EXECUTE sp_executesql N'
    CREATE VIEW HR.EmployeeStatistics
    AS
    SELECT 
        Department,
        COUNT(*) AS EmployeeCount,
        AVG(Salary) AS AvgSalary,
        STDEV(Salary) AS SalaryStdDev,
        AVG(PerformanceScore) AS AvgPerformance,
        STDEV(PerformanceScore) AS PerformanceStdDev,
        AVG(SalesAmount) AS AvgSales,
        STDEV(SalesAmount) AS SalesStdDev,
        CORR(YearsOfService, PerformanceScore) AS ServicePerformanceCorr,
        CORR(Salary, SalesAmount) AS SalarySalesCorr
    FROM HR.EmployeeStats
    GROUP BY Department;
    ';
END

-- Example of comprehensive statistical analysis
SELECT 
    e.EmployeeID,
    e.Salary,
    e.PerformanceScore,
    e.SalesAmount,
    PERCENT_RANK() OVER (ORDER BY e.Salary) AS SalaryRank,
    CUME_DIST() OVER (ORDER BY e.PerformanceScore) AS PerformanceDistribution,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.SalesAmount) 
        OVER (PARTITION BY e.Department) AS MedianSales,
    stats.AvgSalary,
    stats.SalaryStdDev,
    stats.ServicePerformanceCorr
FROM HR.EmployeeStats e
JOIN HR.EmployeeStatistics stats ON e.Department = stats.Department
ORDER BY e.EmployeeID;