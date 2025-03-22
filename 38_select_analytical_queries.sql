-- =============================================
-- DQL Analytical Queries
-- =============================================

USE HRSystem;
GO

-- 1. Year-over-Year Comparison
-- Comparing metrics across time periods
SELECT 
    YEAR(OrderDate) AS OrderYear,
    MONTH(OrderDate) AS OrderMonth,
    SUM(OrderAmount) AS CurrentMonthSales,
    LAG(SUM(OrderAmount), 12) OVER(ORDER BY YEAR(OrderDate), MONTH(OrderDate)) AS PreviousYearSales,
    SUM(OrderAmount) - LAG(SUM(OrderAmount), 12) OVER(ORDER BY YEAR(OrderDate), MONTH(OrderDate)) AS YoYDifference,
    CASE 
        WHEN LAG(SUM(OrderAmount), 12) OVER(ORDER BY YEAR(OrderDate), MONTH(OrderDate)) = 0 THEN NULL
        ELSE (SUM(OrderAmount) - LAG(SUM(OrderAmount), 12) OVER(ORDER BY YEAR(OrderDate), MONTH(OrderDate))) * 100.0 / 
             LAG(SUM(OrderAmount), 12) OVER(ORDER BY YEAR(OrderDate), MONTH(OrderDate))
    END AS YoYPercentChange
FROM HR.Orders
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY OrderYear, OrderMonth;
-- Calculates sales for each month
-- Compares with same month in previous year
-- Shows absolute and percentage differences
-- LAG(12) looks back 12 months for year-over-year comparison

-- 2. Rolling Time Window Analysis
-- Analyzing data over moving time periods
SELECT 
    OrderDate,
    OrderAmount,
    SUM(OrderAmount) OVER(ORDER BY OrderDate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS Rolling7DayTotal,
    AVG(OrderAmount) OVER(ORDER BY OrderDate ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS Rolling30DayAvg,
    MIN(OrderAmount) OVER(ORDER BY OrderDate ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS Rolling30DayMin,
    MAX(OrderAmount) OVER(ORDER BY OrderDate ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS Rolling30DayMax
FROM HR.Orders
WHERE OrderDate >= DATEADD(DAY, -90, GETDATE())
ORDER BY OrderDate;
-- Shows rolling 7-day total and 30-day statistics
-- Window frame specifies how many rows to include
-- Useful for trend analysis and smoothing out fluctuations

-- 3. Cohort Analysis
-- Tracking groups of users/customers over time
WITH UserCohorts AS (
    SELECT 
        UserID,
        DATEFROMPARTS(YEAR(FirstPurchaseDate), MONTH(FirstPurchaseDate), 1) AS CohortMonth,
        OrderDate,
        OrderAmount,
        DATEDIFF(MONTH, 
                 DATEFROMPARTS(YEAR(FirstPurchaseDate), MONTH(FirstPurchaseDate), 1),
                 DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1)) AS MonthNumber
    FROM HR.Orders o
    JOIN (
        SELECT 
            UserID, 
            MIN(OrderDate) AS FirstPurchaseDate
        FROM HR.Orders
        GROUP BY UserID
    ) fp ON o.UserID = fp.UserID
)
SELECT 
    CohortMonth,
    COUNT(DISTINCT CASE WHEN MonthNumber = 0 THEN UserID END) AS Month0Users,
    COUNT(DISTINCT CASE WHEN MonthNumber = 1 THEN UserID END) AS Month1Users,
    COUNT(DISTINCT CASE WHEN MonthNumber = 2 THEN UserID END) AS Month2Users,
    COUNT(DISTINCT CASE WHEN MonthNumber = 3 THEN UserID END) AS Month3Users,
    COUNT(DISTINCT CASE WHEN MonthNumber = 6 THEN UserID END) AS Month6Users,
    COUNT(DISTINCT CASE WHEN MonthNumber = 12 THEN UserID END) AS Month12Users
FROM UserCohorts
GROUP BY CohortMonth
ORDER BY CohortMonth;
-- Groups users by their first purchase month (cohort)
-- Tracks how many users from each cohort remain active in subsequent months
-- Shows retention patterns over time
-- Useful for measuring user engagement and loyalty

-- 4. Funnel Analysis
-- Tracking conversion through sequential steps
WITH UserStages AS (
    SELECT 
        UserID,
        MAX(CASE WHEN EventType = 'Visit' THEN 1 ELSE 0 END) AS ReachedVisit,
        MAX(CASE WHEN EventType = 'Signup' THEN 1 ELSE 0 END) AS ReachedSignup,
        MAX(CASE WHEN EventType = 'AddToCart' THEN 1 ELSE 0 END) AS ReachedCart,
        MAX(CASE WHEN EventType = 'Purchase' THEN 1 ELSE 0 END) AS ReachedPurchase
    FROM HR.UserEvents
    WHERE EventDate >= DATEADD(MONTH, -1, GETDATE())
    GROUP BY UserID
)
SELECT 
    COUNT(*) AS TotalUsers,
    SUM(ReachedVisit) AS VisitCount,
    SUM(ReachedSignup) AS SignupCount,
    SUM(ReachedCart) AS CartCount,
    SUM(ReachedPurchase) AS PurchaseCount,
    FORMAT(SUM(ReachedSignup) * 100.0 / SUM(ReachedVisit), 'N2') + '%' AS VisitToSignupRate,
    FORMAT(SUM(ReachedCart) * 100.0 / SUM(ReachedSignup), 'N2') + '%' AS SignupToCartRate,
    FORMAT(SUM(ReachedPurchase) * 100.0 / SUM(ReachedCart), 'N2') + '%' AS CartToPurchaseRate,
    FORMAT(SUM(ReachedPurchase) * 100.0 / SUM(ReachedVisit), 'N2') + '%' AS OverallConversionRate
FROM UserStages;
-- Identifies how many users reach each stage of a process
-- Calculates conversion rates between stages
-- Shows where users drop off in the process
-- Useful for optimizing conversion funnels

-- 5. RFM (Recency, Frequency, Monetary) Analysis
-- Customer segmentation based on purchase behavior
WITH CustomerRFM AS (
    SELECT 
        UserID,
        DATEDIFF(DAY, MAX(OrderDate), GETDATE()) AS Recency,
        COUNT(*) AS Frequency,
        SUM(OrderAmount) AS MonetaryValue,
        NTILE(5) OVER(ORDER BY DATEDIFF(DAY, MAX(OrderDate), GETDATE())) AS RecencyScore,
        NTILE(5) OVER(ORDER BY COUNT(*)) AS FrequencyScore,
        NTILE(5) OVER(ORDER BY SUM(OrderAmount)) AS MonetaryScore
    FROM HR.Orders
    WHERE OrderDate >= DATEADD(YEAR, -2, GETDATE())
    GROUP BY UserID
)
SELECT 
    UserID,
    Recency,
    Frequency,
    MonetaryValue,
    RecencyScore,
    FrequencyScore,
    MonetaryScore,
    CONCAT(RecencyScore, FrequencyScore, MonetaryScore) AS RFMScore,
    CASE 
        WHEN (RecencyScore >= 4 AND FrequencyScore >= 4 AND MonetaryScore >= 4) THEN 'Champions'
        WHEN (RecencyScore >= 3 AND FrequencyScore >= 3 AND MonetaryScore >= 3) THEN 'Loyal Customers'
        WHEN (RecencyScore >= 3 AND FrequencyScore >= 1 AND MonetaryScore >= 2) THEN 'Potential Loyalists'
        WHEN (RecencyScore >= 4 AND FrequencyScore <= 2 AND MonetaryScore <= 2) THEN 'New Customers'
        WHEN (RecencyScore <= 2 AND FrequencyScore >= 3 AND MonetaryScore >= 3) THEN 'At Risk'
        WHEN (RecencyScore <= 2 AND FrequencyScore >= 2 AND MonetaryScore >= 2) THEN 'Needs Attention'
        WHEN (RecencyScore <= 1 AND FrequencyScore <= 2 AND MonetaryScore <= 2) THEN 'Lost'
        ELSE 'Others'
    END AS CustomerSegment
FROM CustomerRFM
ORDER BY RFMScore DESC;
-- Calculates recency (days since last purchase), frequency (number of purchases), and monetary value
-- Scores each dimension from 1-5 (5 being best)
-- Combines scores into RFM segments
-- Categorizes customers into meaningful business segments

-- 6. Market Basket Analysis
-- Finding products frequently purchased together
WITH ProductPairs AS (
    SELECT 
        o1.OrderID,
        o1.ProductID AS Product1,
        o2.ProductID AS Product2,
        p1.ProductName AS Product1Name,
        p2.ProductName AS Product2Name
    FROM HR.OrderDetails o1
    JOIN HR.OrderDetails o2 ON o1.OrderID = o2.OrderID AND o1.ProductID < o2.ProductID
    JOIN HR.Products p1 ON o1.ProductID = p1.ProductID
    JOIN HR.Products p2 ON o2.ProductID = p2.ProductID
)
SELECT 
    Product1,
    Product2,
    Product1Name,
    Product2Name,
    COUNT(*) AS PairCount,
    (SELECT COUNT(DISTINCT OrderID) FROM HR.OrderDetails WHERE ProductID = Product1) AS Product1Orders,
    (SELECT COUNT(DISTINCT OrderID) FROM HR.OrderDetails WHERE ProductID = Product2) AS Product2Orders,
    COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT OrderID) FROM HR.OrderDetails WHERE ProductID = Product1) AS Support1,
    COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT OrderID) FROM HR.OrderDetails WHERE ProductID = Product2) AS Support2
FROM ProductPairs
GROUP BY Product1, Product2, Product1Name, Product2Name
HAVING COUNT(*) >= 10
ORDER BY PairCount DESC;
-- Identifies products frequently purchased together
-- Self-join creates all possible product pairs within each order
-- Support percentage shows how often products appear together
-- Useful for product recommendations and store layout

-- 7. Churn Analysis
-- Identifying and analyzing customer churn
WITH UserActivity AS (
    SELECT 
        UserID,
        MAX(ActivityDate) AS LastActivityDate,
        DATEDIFF(DAY, MAX(ActivityDate), GETDATE()) AS DaysSinceLastActivity,
        COUNT(DISTINCT MONTH(ActivityDate)) AS ActiveMonths,
        MIN(ActivityDate) AS FirstActivityDate,
        DATEDIFF(MONTH, MIN(ActivityDate), MAX(ActivityDate)) + 1 AS TotalPossibleMonths,
        CAST(COUNT(DISTINCT MONTH(ActivityDate)) AS FLOAT) / 
            (DATEDIFF(MONTH, MIN(ActivityDate), MAX(ActivityDate)) + 1) AS ActivityRate
    FROM HR.UserActivities
    GROUP BY UserID
)
SELECT 
    UserID,
    LastActivityDate,
    DaysSinceLastActivity,
    CASE 
        WHEN DaysSinceLastActivity > 90 THEN 'Churned'
        WHEN DaysSinceLastActivity BETWEEN 60 AND 90 THEN 'At Risk'
        WHEN DaysSinceLastActivity BETWEEN 30 AND 59 THEN 'Recent'
        ELSE 'Active'
    END AS ChurnStatus,
    ActiveMonths,
    TotalPossibleMonths,
    ActivityRate,
    CASE 
        WHEN ActivityRate < 0.3 THEN 'Low Engagement'
        WHEN ActivityRate BETWEEN 0.3 AND 0.7 THEN 'Medium Engagement'
        ELSE 'High Engagement'
    END AS EngagementLevel
FROM UserActivity
ORDER BY DaysSinceLastActivity DESC;
-- Calculates days since last activity for each user
-- Categorizes users by churn status
-- Measures engagement level based on activity rate
-- Helps identify at-risk users before they churn

-- 8. Seasonal Analysis
-- Identifying seasonal patterns in data
SELECT 
    YEAR(OrderDate) AS OrderYear,
    DATEPART(QUARTER, OrderDate) AS OrderQuarter,
    MONTH(OrderDate) AS OrderMonth,
    DATENAME(MONTH, OrderDate) AS MonthName,
    SUM(OrderAmount) AS TotalSales,
    COUNT(*) AS OrderCount,
    SUM(SUM(OrderAmount)) OVER(PARTITION BY YEAR(OrderDate)) AS YearlySales,
    SUM(OrderAmount) * 100.0 / SUM(SUM(OrderAmount)) OVER(PARTITION BY YEAR(OrderDate)) AS PercentOfYearlySales,
    LAG(SUM(OrderAmount)) OVER(PARTITION BY MONTH(OrderDate) ORDER BY YEAR(OrderDate)) AS PreviousYearSameMonth,
    CASE 
        WHEN LAG(SUM(OrderAmount)) OVER(PARTITION BY MONTH(OrderDate) ORDER BY YEAR(OrderDate)) = 0 THEN NULL
        ELSE (SUM(OrderAmount) - LAG(SUM(OrderAmount)) OVER(PARTITION BY MONTH(OrderDate) ORDER BY YEAR(OrderDate))) * 100.0 / 
             LAG(SUM(OrderAmount)) OVER(PARTITION BY MONTH(OrderDate) ORDER BY YEAR(OrderDate))
    END AS YoYGrowthRate
FROM HR.Orders
GROUP BY YEAR(OrderDate), DATEPART(QUARTER, OrderDate), MONTH(OrderDate), DATENAME(MONTH, OrderDate)
ORDER BY OrderYear, OrderMonth;
-- Aggregates data by year, quarter, and month
-- Calculates percentage of yearly sales for each month
-- Compares with same month in previous year
-- Helps identify seasonal patterns and growth trends

-- 9. Anomaly Detection
-- Identifying outliers and unusual patterns
WITH DailySales AS (
    SELECT 
        CAST(OrderDate AS DATE) AS OrderDay,
        SUM(OrderAmount) AS DailySales,
        COUNT(*) AS OrderCount,
        AVG(SUM(OrderAmount)) OVER(ORDER BY CAST(OrderDate AS DATE) 
            ROWS BETWEEN 15 PRECEDING AND 15 FOLLOWING) AS MovingAvgSales,
        STDEV(SUM(OrderAmount)) OVER(ORDER BY CAST(OrderDate AS DATE) 
            ROWS BETWEEN 15 PRECEDING AND 15 FOLLOWING) AS StdDevSales
    FROM HR.Orders
    GROUP BY CAST(OrderDate AS DATE)
)
SELECT 
    OrderDay,
    DailySales,
    OrderCount,
    MovingAvgSales,
    StdDevSales,
    (DailySales - MovingAvgSales) / NULLIF(StdDevSales, 0) AS ZScore,
    CASE 
        WHEN ABS((DailySales - MovingAvgSales) / NULLIF(StdDevSales, 0)) > 2 THEN 'Anomaly'
        ELSE 'Normal'
    END AS AnomalyFlag
FROM DailySales
WHERE ABS((DailySales - MovingAvgSales) / NULLIF(StdDevSales, 0)) > 2
ORDER BY OrderDay;
-- Calculates daily sales statistics
-- Computes moving average and standard deviation
-- Identifies days with Z-scores > 2 (outside 95% confidence interval)
-- Flags unusual sales days that may require investigation

-- 10. Customer Lifetime Value (CLV) Analysis (continued)
-- Calculating and predicting customer value
WITH CustomerPurchases AS (
    SELECT 
        UserID,
        MIN(OrderDate) AS FirstPurchaseDate,
        MAX(OrderDate) AS LastPurchaseDate,
        DATEDIFF(DAY, MIN(OrderDate), MAX(OrderDate)) AS CustomerAgeDays,
        COUNT(*) AS TotalOrders,
        SUM(OrderAmount) AS TotalSpent,
        SUM(OrderAmount) / COUNT(*) AS AvgOrderValue,
        COUNT(*) * 1.0 / NULLIF(DATEDIFF(DAY, MIN(OrderDate), MAX(OrderDate)), 0) * 30 AS MonthlyPurchaseRate
    FROM HR.Orders
    GROUP BY UserID
)
SELECT 
    UserID,
    FirstPurchaseDate,
    LastPurchaseDate,
    CustomerAgeDays,
    TotalOrders,
    TotalSpent,
    AvgOrderValue,
    MonthlyPurchaseRate,
    AvgOrderValue * MonthlyPurchaseRate * 12 AS AnnualValue,
    AvgOrderValue * MonthlyPurchaseRate * 12 * 3 AS ThreeYearCLV,
    CASE 
        WHEN TotalSpent > 5000 THEN 'High Value'
        WHEN TotalSpent > 1000 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS ValueSegment
FROM CustomerPurchases
WHERE CustomerAgeDays > 30
ORDER BY TotalSpent DESC;
-- Calculates key customer metrics
-- Estimates future value based on purchase patterns
-- Segments customers by value
-- Helps prioritize marketing and retention efforts

-- 11. Retention Analysis
-- Measuring customer retention over time
WITH MonthlyActivity AS (
    SELECT 
        UserID,
        DATEFROMPARTS(YEAR(ActivityDate), MONTH(ActivityDate), 1) AS ActivityMonth
    FROM HR.UserActivities
    GROUP BY UserID, DATEFROMPARTS(YEAR(ActivityDate), MONTH(ActivityDate), 1)
),
UserFirstMonth AS (
    SELECT 
        UserID,
        MIN(ActivityMonth) AS FirstMonth
    FROM MonthlyActivity
    GROUP BY UserID
),
RetentionTable AS (
    SELECT 
        ufm.FirstMonth AS CohortMonth,
        DATEDIFF(MONTH, ufm.FirstMonth, ma.ActivityMonth) AS MonthNumber,
        COUNT(DISTINCT ma.UserID) AS ActiveUsers
    FROM UserFirstMonth ufm
    JOIN MonthlyActivity ma ON ufm.UserID = ma.UserID
    GROUP BY ufm.FirstMonth, DATEDIFF(MONTH, ufm.FirstMonth, ma.ActivityMonth)
),
CohortSize AS (
    SELECT 
        CohortMonth,
        ActiveUsers AS InitialUsers
    FROM RetentionTable
    WHERE MonthNumber = 0
)
SELECT 
    rt.CohortMonth,
    rt.MonthNumber,
    rt.ActiveUsers,
    cs.InitialUsers,
    CAST(rt.ActiveUsers * 100.0 / cs.InitialUsers AS DECIMAL(5,2)) AS RetentionRate
FROM RetentionTable rt
JOIN CohortSize cs ON rt.CohortMonth = cs.CohortMonth
ORDER BY rt.CohortMonth, rt.MonthNumber;
-- Groups users by their first month of activity
-- Tracks how many remain active in subsequent months
-- Calculates retention rate for each cohort and month
-- Shows how well the business retains customers over time

-- 12. Attribution Analysis
-- Analyzing which marketing channels drive conversions
WITH TouchPoints AS (
    SELECT 
        UserID,
        ConversionID,
        TouchpointType,
        TouchpointTime,
        ROW_NUMBER() OVER(PARTITION BY UserID, ConversionID ORDER BY TouchpointTime) AS TouchpointOrder,
        FIRST_VALUE(TouchpointType) OVER(PARTITION BY UserID, ConversionID ORDER BY TouchpointTime) AS FirstTouch,
        LAST_VALUE(TouchpointType) OVER(
            PARTITION BY UserID, ConversionID 
            ORDER BY TouchpointTime
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS LastTouch
    FROM HR.MarketingTouchpoints
    WHERE ConversionID IS NOT NULL
)
SELECT 
    TouchpointType,
    COUNT(*) AS TotalTouchpoints,
    SUM(CASE WHEN TouchpointOrder = 1 THEN 1 ELSE 0 END) AS FirstTouchCount,
    SUM(CASE WHEN TouchpointType = LastTouch THEN 1 ELSE 0 END) AS LastTouchCount,
    FORMAT(SUM(CASE WHEN TouchpointOrder = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT ConversionID), 'N2') + '%' AS FirstTouchAttribution,
    FORMAT(SUM(CASE WHEN TouchpointType = LastTouch THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT ConversionID), 'N2') + '%' AS LastTouchAttribution
FROM TouchPoints
GROUP BY TouchpointType
ORDER BY TotalTouchpoints DESC;
-- Identifies first and last marketing touchpoints before conversion
-- Calculates attribution percentages for each channel
-- Shows which channels initiate vs. close conversions
-- Helps optimize marketing spend across channels

-- 13. Forecasting with Linear Regression
-- Simple forecasting using statistical methods
WITH MonthlySales AS (
    SELECT 
        DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS SalesMonth,
        SUM(OrderAmount) AS MonthlySales,
        ROW_NUMBER() OVER(ORDER BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1)) AS MonthNumber
    FROM HR.Orders
    WHERE OrderDate >= DATEADD(MONTH, -24, GETDATE())
    GROUP BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1)
),
RegressionCalculation AS (
    SELECT 
        COUNT(*) AS n,
        AVG(MonthNumber) AS AvgX,
        AVG(MonthlySales) AS AvgY,
        SUM((MonthNumber - AVG(MonthNumber) OVER()) * (MonthlySales - AVG(MonthlySales) OVER())) AS Numerator,
        SUM(POWER(MonthNumber - AVG(MonthNumber) OVER(), 2)) AS Denominator
    FROM MonthlySales
),
RegressionParameters AS (
    SELECT 
        Numerator / Denominator AS Slope,
        AvgY - (Numerator / Denominator) * AvgX AS Intercept
    FROM RegressionCalculation
)
SELECT 
    ms.SalesMonth,
    ms.MonthlySales AS ActualSales,
    rp.Intercept + rp.Slope * ms.MonthNumber AS PredictedSales,
    -- Forecast next 6 months
    DATEADD(MONTH, 1, MAX(ms.SalesMonth) OVER()) AS ForecastMonth1,
    rp.Intercept + rp.Slope * (MAX(ms.MonthNumber) OVER() + 1) AS ForecastSales1,
    DATEADD(MONTH, 2, MAX(ms.SalesMonth) OVER()) AS ForecastMonth2,
    rp.Intercept + rp.Slope * (MAX(ms.MonthNumber) OVER() + 2) AS ForecastSales2,
    DATEADD(MONTH, 3, MAX(ms.SalesMonth) OVER()) AS ForecastMonth3,
    rp.Intercept + rp.Slope * (MAX(ms.MonthNumber) OVER() + 3) AS ForecastSales3
FROM MonthlySales ms
CROSS JOIN RegressionParameters rp
ORDER BY ms.SalesMonth;
-- Implements simple linear regression for sales forecasting
-- Calculates slope and intercept from historical data
-- Predicts sales for future months
-- Shows actual vs. predicted values for model validation

-- 14. Basket Analysis with Association Rules
-- Finding product associations beyond simple pairs
WITH OrderProducts AS (
    SELECT 
        o.OrderID,
        p.ProductID,
        p.ProductName,
        p.CategoryID
    FROM HR.OrderDetails o
    JOIN HR.Products p ON o.ProductID = p.ProductID
),
ProductSets AS (
    SELECT 
        a.ProductID AS Product1ID,
        a.ProductName AS Product1Name,
        b.ProductID AS Product2ID,
        b.ProductName AS Product2Name,
        c.ProductID AS Product3ID,
        c.ProductName AS Product3Name,
        COUNT(DISTINCT a.OrderID) AS SetCount
    FROM OrderProducts a
    JOIN OrderProducts b ON a.OrderID = b.OrderID AND a.ProductID < b.ProductID
    JOIN OrderProducts c ON a.OrderID = c.OrderID AND b.ProductID < c.ProductID
    GROUP BY 
        a.ProductID, a.ProductName,
        b.ProductID, b.ProductName,
        c.ProductID, c.ProductName
    HAVING COUNT(DISTINCT a.OrderID) >= 5
)
SELECT 
    Product1Name,
    Product2Name,
    Product3Name,
    SetCount,
    (SELECT COUNT(DISTINCT OrderID) FROM HR.OrderDetails) AS TotalOrders,
    FORMAT(SetCount * 100.0 / (SELECT COUNT(DISTINCT OrderID) FROM HR.OrderDetails), 'N2') + '%' AS SupportPercentage
FROM ProductSets
ORDER BY SetCount DESC;
-- Identifies sets of three products frequently purchased together
-- Calculates support percentage (frequency of occurrence)
-- More sophisticated than simple product pairs
-- Useful for bundle offers and product placement

-- 15. Customer Segmentation with RFM and K-Means
-- Advanced customer segmentation using multiple dimensions
WITH CustomerMetrics AS (
    SELECT 
        UserID,
        DATEDIFF(DAY, MAX(OrderDate), GETDATE()) AS Recency,
        COUNT(*) AS Frequency,
        SUM(OrderAmount) AS Monetary,
        NTILE(5) OVER(ORDER BY DATEDIFF(DAY, MAX(OrderDate), GETDATE())) AS RecencyScore,
        NTILE(5) OVER(ORDER BY COUNT(*)) AS FrequencyScore,
        NTILE(5) OVER(ORDER BY SUM(OrderAmount)) AS MonetaryScore
    FROM HR.Orders
    GROUP BY UserID
),
CustomerSegments AS (
    SELECT 
        UserID,
        Recency,
        Frequency,
        Monetary,
        RecencyScore,
        FrequencyScore,
        MonetaryScore,
        -- K-Means approximation using RFM scores
        CASE 
            WHEN RecencyScore >= 4 AND FrequencyScore >= 4 AND MonetaryScore >= 4 THEN 1 -- Champions
            WHEN RecencyScore >= 3 AND FrequencyScore >= 3 AND MonetaryScore >= 3 THEN 2 -- Loyal Customers
            WHEN RecencyScore >= 3 AND FrequencyScore >= 1 AND MonetaryScore >= 2 THEN 3 -- Potential Loyalists
            WHEN RecencyScore >= 4 AND FrequencyScore <= 2 AND MonetaryScore <= 2 THEN 4 -- New Customers
            WHEN RecencyScore <= 2 AND FrequencyScore >= 3 AND MonetaryScore >= 3 THEN 5 -- At Risk
            WHEN RecencyScore <= 2 AND FrequencyScore >= 2 AND MonetaryScore >= 2 THEN 6 -- Needs Attention
            WHEN RecencyScore <= 1 AND FrequencyScore <= 2 AND MonetaryScore <= 2 THEN 7 -- Lost
            ELSE 8 -- Others
        END AS SegmentID
    FROM CustomerMetrics
)
SELECT 
    SegmentID,
    CASE 
        WHEN SegmentID = 1 THEN 'Champions'
        WHEN SegmentID = 2 THEN 'Loyal Customers'
        WHEN SegmentID = 3 THEN 'Potential Loyalists'
        WHEN SegmentID = 4 THEN 'New Customers'
        WHEN SegmentID = 5 THEN 'At Risk'
        WHEN SegmentID = 6 THEN 'Needs Attention'
        WHEN SegmentID = 7 THEN 'Lost'
        ELSE 'Others'
    END AS SegmentName,
    COUNT(*) AS CustomerCount,
    AVG(Recency) AS AvgRecency,
    AVG(Frequency) AS AvgFrequency,
    AVG(Monetary) AS AvgMonetary,
    SUM(Monetary) AS TotalRevenue,
    FORMAT(SUM(Monetary) * 100.0 / SUM(SUM(Monetary)) OVER(), 'N2') + '%' AS RevenuePercentage
FROM CustomerSegments
GROUP BY SegmentID
ORDER BY SegmentID;
-- Combines RFM analysis with K-means-like segmentation
-- Creates meaningful customer segments based on behavior
-- Shows key metrics for each segment
-- Helps target marketing strategies to specific segments