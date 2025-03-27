# SQL Deep Dive: Analytical Queries

## 1. Introduction: Deriving Insights from Data

Beyond simple retrieval and filtering, SQL is a powerful tool for **analytical queries** – queries designed to derive insights, identify trends, segment data, and understand complex relationships within your data. These queries often involve combining aggregation, window functions, CTEs, and time-series analysis techniques.

## 2. Analytical Patterns in Action: Analysis of `38_select_analytical_queries.sql`

This script showcases several common and powerful analytical query patterns.

**a) Year-over-Year (YoY) Comparison**

```sql
SELECT
    YEAR(OrderDate) AS OrderYear, MONTH(OrderDate) AS OrderMonth,
    SUM(OrderAmount) AS CurrentMonthSales,
    LAG(SUM(OrderAmount), 12) OVER(ORDER BY YEAR(OrderDate), MONTH(OrderDate)) AS PreviousYearSales,
    -- Calculate Difference and Percentage Change...
FROM HR.Orders
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY OrderYear, OrderMonth;
```

*   **Pattern:** Compare a metric (e.g., sales) for a specific period (e.g., month) with the same period in the previous year.
*   **Mechanism:**
    1.  Aggregate data by the desired period (Year, Month).
    2.  Use the `LAG(value, offset)` window function with an `offset` of 12 (for months) and ordered by date to retrieve the value from the corresponding period in the previous year.
    3.  Calculate the absolute difference and percentage change.

**b) Rolling Time Window Analysis**

```sql
SELECT OrderDate, OrderAmount,
    SUM(OrderAmount) OVER(ORDER BY OrderDate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS Rolling7DayTotal,
    AVG(OrderAmount) OVER(ORDER BY OrderDate ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS Rolling30DayAvg
FROM HR.Orders WHERE ... ORDER BY OrderDate;
```

*   **Pattern:** Analyze trends over a moving time window (e.g., 7-day rolling average, 30-day cumulative total).
*   **Mechanism:** Uses aggregate window functions (`SUM`, `AVG`, `MIN`, `MAX`) with an `ORDER BY` clause and an explicit window frame (`ROWS BETWEEN N PRECEDING AND CURRENT ROW` or similar) to define the rolling period relative to the current row.

**c) Cohort Analysis**

```sql
WITH UserCohorts AS (
    SELECT UserID, MIN(OrderDate) AS FirstPurchaseDate FROM HR.Orders GROUP BY UserID
), Activity AS (
    SELECT UserID, DATEFROMPARTS(...) AS CohortMonth, DATEDIFF(MONTH, FirstPurchaseDate, OrderDate) AS MonthNumber
    FROM HR.Orders o JOIN UserCohorts uc ON o.UserID = uc.UserID
)
SELECT CohortMonth, COUNT(DISTINCT CASE WHEN MonthNumber = 0 THEN UserID END) AS Month0Users, ...
FROM Activity GROUP BY CohortMonth ORDER BY CohortMonth;
```

*   **Pattern:** Group users based on when they first started an activity (e.g., first purchase, signup date) – the "cohort" – and track their behavior or retention over subsequent time periods.
*   **Mechanism:**
    1.  Identify the cohort assignment date for each user (e.g., `MIN(PurchaseDate)`).
    2.  For each subsequent activity/purchase, calculate the time difference (e.g., `MonthNumber`) relative to their cohort date.
    3.  Aggregate results, grouping by the `CohortMonth` and pivoting or using conditional aggregation (`COUNT(DISTINCT CASE WHEN MonthNumber = N THEN UserID END)`) to count active users from each cohort in subsequent months (`MonthNumber` = 0, 1, 2...).

**d) Funnel Analysis**

```sql
WITH UserStages AS (
    SELECT UserID,
        MAX(CASE WHEN EventType = 'Visit' THEN 1 ELSE 0 END) AS ReachedVisit,
        MAX(CASE WHEN EventType = 'Signup' THEN 1 ELSE 0 END) AS ReachedSignup, ...
    FROM HR.UserEvents GROUP BY UserID
)
SELECT COUNT(*) AS Total, SUM(ReachedVisit) AS Visits, SUM(ReachedSignup) AS Signups, ...
FROM UserStages;
```

*   **Pattern:** Track users as they progress through a sequence of defined steps or events (e.g., Visit -> Signup -> AddToCart -> Purchase) and calculate conversion rates between stages.
*   **Mechanism:**
    1.  Use conditional aggregation (`MAX(CASE WHEN EventType = 'Stage' THEN 1 ELSE 0 END)`) grouped by `UserID` to determine if each user reached each stage (results in 1 if reached, 0 otherwise).
    2.  Aggregate these flags across all users (`SUM(ReachedStage)`) to get the total count of users reaching each stage.
    3.  Calculate conversion rates by dividing the count at one stage by the count at the previous stage.

**e) RFM (Recency, Frequency, Monetary) Analysis**

```sql
WITH CustomerRFM AS (
    SELECT UserID,
        DATEDIFF(DAY, MAX(OrderDate), GETDATE()) AS Recency,
        COUNT(*) AS Frequency, SUM(OrderAmount) AS MonetaryValue,
        NTILE(5) OVER(ORDER BY DATEDIFF(DAY, MAX(OrderDate), GETDATE())) AS RecencyScore,
        NTILE(5) OVER(ORDER BY COUNT(*)) AS FrequencyScore,
        NTILE(5) OVER(ORDER BY SUM(OrderAmount)) AS MonetaryScore
    FROM HR.Orders GROUP BY UserID
) SELECT ..., CASE WHEN (...) THEN 'Champions' ... END AS CustomerSegment FROM CustomerRFM;
```

*   **Pattern:** Segment customers based on their transaction history:
    *   **Recency:** How recently did they purchase? (Lower days = better)
    *   **Frequency:** How often do they purchase? (Higher count = better)
    *   **Monetary:** How much do they spend? (Higher amount = better)
*   **Mechanism:**
    1.  Aggregate order data per customer to calculate `Recency` (`DATEDIFF` from `MAX(OrderDate)`), `Frequency` (`COUNT(*)`), and `Monetary` (`SUM(OrderAmount)`).
    2.  Use `NTILE(N)` (commonly N=5 for quintiles) window function over the calculated R, F, and M values to assign scores (e.g., 1-5, where 5 is often best for F/M, but lowest Recency days gets score 5).
    3.  Combine the R, F, M scores (e.g., concatenate) and use `CASE` expressions based on score ranges to assign customers to predefined segments (e.g., 'Champions', 'Loyal', 'At Risk', 'Lost').

**f) Market Basket Analysis (Association Rules)**

```sql
WITH ProductPairs AS (
    SELECT o1.OrderID, o1.ProductID AS P1, o2.ProductID AS P2
    FROM HR.OrderDetails o1 JOIN HR.OrderDetails o2 ON o1.OrderID = o2.OrderID AND o1.ProductID < o2.ProductID
) SELECT P1, P2, COUNT(*) AS PairCount, ... FROM ProductPairs GROUP BY P1, P2 HAVING COUNT(*) >= N ORDER BY PairCount DESC;
```

*   **Pattern:** Identify items that are frequently purchased together in the same transaction (basket).
*   **Mechanism:**
    1.  Self-join the order details table (`OrderDetails`) on `OrderID`, ensuring `ProductID` in the first instance is less than the second (`o1.ProductID < o2.ProductID`) to generate unique pairs within each order.
    2.  Group by the product pair (`P1`, `P2`) and count the occurrences (`PairCount`).
    3.  Optionally calculate metrics like Support (frequency of the pair in all transactions) and Confidence (likelihood of buying P2 given P1 was bought).
    4.  Filter (`HAVING`) for pairs occurring above a minimum threshold.

**g) Churn Analysis**

```sql
WITH UserActivity AS (
    SELECT UserID, MAX(ActivityDate) AS LastActivityDate, DATEDIFF(...) AS DaysSinceLast, ...
    FROM HR.UserActivities GROUP BY UserID
) SELECT ..., CASE WHEN DaysSinceLast > 90 THEN 'Churned' ... END AS ChurnStatus FROM UserActivity;
```

*   **Pattern:** Identify users who have stopped using a service or product (churned) or are at risk of churning based on their activity patterns.
*   **Mechanism:**
    1.  Aggregate user activity data (`UserActivities`) per user to find the `MAX(ActivityDate)`.
    2.  Calculate `DaysSinceLastActivity` using `DATEDIFF`.
    3.  Use `CASE` expressions based on `DaysSinceLastActivity` thresholds (e.g., > 90 days = 'Churned', 60-90 days = 'At Risk') to categorize users.
    4.  Can be enhanced by calculating other engagement metrics (e.g., frequency of activity, monetary value).

**h) Seasonal Analysis**

```sql
SELECT YEAR(OrderDate) AS OY, MONTH(OrderDate) AS OM, ..., SUM(OrderAmount) AS Sales,
    LAG(SUM(OrderAmount)) OVER(PARTITION BY MONTH(OrderDate) ORDER BY YEAR(OrderDate)) AS PrevYearSameMonth
FROM HR.Orders GROUP BY YEAR(OrderDate), MONTH(OrderDate), ... ORDER BY OY, OM;
```

*   **Pattern:** Identify recurring patterns or trends in data related to specific times of the year (months, quarters).
*   **Mechanism:**
    1.  Aggregate data by time periods (Year, Quarter, Month) using functions like `YEAR()`, `MONTH()`, `DATEPART()`.
    2.  Use window functions like `LAG()` partitioned by the shorter period (e.g., `Month`) and ordered by the longer period (e.g., `Year`) to compare with the same period in previous cycles.
    3.  Calculate growth rates or percentage contributions.

**i) Anomaly Detection (using Z-Score)**

```sql
WITH DailyStats AS (
    SELECT CAST(OrderDate AS DATE) AS Day, SUM(OrderAmount) AS DailySales,
        AVG(SUM(OrderAmount)) OVER(ORDER BY CAST(OrderDate AS DATE) ROWS BETWEEN 15 PRECEDING AND 15 FOLLOWING) AS MovingAvg,
        STDEV(SUM(OrderAmount)) OVER(ORDER BY CAST(OrderDate AS DATE) ROWS BETWEEN 15 PRECEDING AND 15 FOLLOWING) AS StdDev
    FROM HR.Orders GROUP BY CAST(OrderDate AS DATE)
) SELECT *, (DailySales - MovingAvg) / NULLIF(StdDev, 0) AS ZScore FROM DailyStats WHERE ABS(...) > 2;
```

*   **Pattern:** Identify data points that deviate significantly from the norm or expected trend.
*   **Mechanism:**
    1.  Calculate a baseline or expected value (e.g., using a moving average `AVG(...) OVER(...)`).
    2.  Calculate the standard deviation over the same window (`STDEV(...) OVER(...)`).
    3.  Calculate the Z-Score for each data point: `(ActualValue - AverageValue) / StandardDeviation`.
    4.  Filter for rows where the absolute Z-Score exceeds a threshold (e.g., 2 or 3), indicating points that are statistically unusual.

**j) Customer Lifetime Value (CLV) Analysis**

```sql
WITH CustomerPurchases AS (
    SELECT UserID, COUNT(*) AS Freq, SUM(Amount) AS Mon, DATEDIFF(...) AS Age, ... FROM HR.Orders GROUP BY UserID
) SELECT ..., (AvgOrderValue * PurchaseRate * ExpectedLifespan) AS PredictedCLV FROM CustomerPurchases;
```

*   **Pattern:** Estimate the total net profit a business can expect to make from a customer over the entire duration of their relationship.
*   **Mechanism:** Involves calculating historical metrics per customer (Average Order Value, Purchase Frequency, Customer Lifespan/Age) and often using these to predict future behavior and value. Simple models might multiply average value by frequency by estimated lifespan. More complex models exist.

**k) Retention Analysis (Cohort-based)**

```sql
-- Similar structure to Cohort Analysis, but focuses on % remaining active
WITH MonthlyActivity AS (...), UserFirstMonth AS (...), RetentionTable AS (
    SELECT ufm.FirstMonth AS Cohort, DATEDIFF(...) AS MonthNum, COUNT(DISTINCT ma.UserID) AS Active
    FROM UserFirstMonth ufm JOIN MonthlyActivity ma ON ... GROUP BY Cohort, MonthNum
), CohortSize AS (SELECT Cohort, Active AS Initial FROM RetentionTable WHERE MonthNum = 0)
SELECT rt.Cohort, rt.MonthNum, rt.Active * 100.0 / cs.Initial AS RetentionRate
FROM RetentionTable rt JOIN CohortSize cs ON rt.Cohort = cs.Cohort ORDER BY Cohort, MonthNum;
```

*   **Pattern:** Measures the percentage of users from an initial cohort who are still active in subsequent time periods.
*   **Mechanism:** Similar to cohort analysis, but the final step calculates the ratio of active users in month `N` to the initial number of users in that cohort (`MonthNumber = 0`). Often displayed as a triangular matrix.

**l) Attribution Analysis**

```sql
WITH TouchPoints AS (
    SELECT ..., ROW_NUMBER() OVER(...) AS RN, FIRST_VALUE(...) OVER(...) AS FirstTouch, LAST_VALUE(...) OVER(...) AS LastTouch
    FROM HR.MarketingTouchpoints WHERE ConversionID IS NOT NULL
) SELECT TouchpointType, SUM(CASE WHEN RN = 1 THEN 1 ELSE 0 END) AS FirstTouches, ... FROM TouchPoints GROUP BY TouchpointType;
```

*   **Pattern:** Determine which marketing channels or touchpoints contribute most effectively to conversions (e.g., signups, purchases).
*   **Mechanism:** Often involves tracking user interactions across various channels over time. Window functions (`ROW_NUMBER`, `FIRST_VALUE`, `LAST_VALUE`) partitioned by user/conversion and ordered by time are used to identify the first, last, or other significant touchpoints in the conversion path. Aggregation then attributes conversions based on different models (first-touch, last-touch, linear, etc.).

**m) Forecasting with Linear Regression**

```sql
WITH MonthlyData AS (SELECT ..., ROW_NUMBER() OVER(...) AS X, Value AS Y FROM ...),
RegressionCalc AS (SELECT AVG(X) AX, AVG(Y) AY, ..., COUNT(*) N FROM MonthlyData),
Params AS (SELECT ... AS Slope, ... AS Intercept FROM RegressionCalc)
SELECT ..., p.Intercept + p.Slope * md.X AS Predicted FROM MonthlyData md CROSS JOIN Params p;
```

*   **Pattern:** Predict future values based on a linear trend observed in historical data.
*   **Mechanism:** Calculates the slope and intercept of the best-fit line through historical data points (e.g., Sales vs. Time Period Number) using standard linear regression formulas (often involving averages, sums of squares, and sums of products, which can be calculated using window functions or aggregations). The calculated slope and intercept are then used to predict future values (`Y = Intercept + Slope * FutureX`). *Note: SQL is not primarily a statistical tool; more complex forecasting often uses dedicated libraries/languages like R or Python.*

**n) Basket Analysis with Association Rules (Advanced)**

```sql
-- Finding sets of 3 items
WITH OrderProducts AS (...), ProductSets AS (
    SELECT a.P1, b.P2, c.P3, COUNT(DISTINCT a.OrderID) AS SetCount
    FROM OrderProducts a JOIN OrderProducts b ON ... JOIN OrderProducts c ON ... GROUP BY ... HAVING ...
) SELECT ..., SetCount * 100.0 / TotalOrders AS Support FROM ProductSets;
```

*   **Pattern:** Extends simple pair analysis to find larger sets of items frequently purchased together and calculate metrics like support, confidence, and lift.
*   **Mechanism:** Involves multiple self-joins on the order details table (or pre-processed item sets) to generate combinations of 3 or more items. Aggregation counts the frequency of these sets. Calculations for support, confidence, etc., require additional counts (total transactions, individual item frequencies). Can become computationally intensive for larger item sets.

**o) Customer Segmentation (Advanced)**

```sql
WITH CustomerMetrics AS (SELECT UserID, Recency, Frequency, Monetary, NTILE(...) R, NTILE(...) F, NTILE(...) M FROM ...),
CustomerSegments AS (SELECT ..., CASE WHEN R>=4 AND F>=4 ... THEN 1 ... END AS SegmentID FROM CustomerMetrics)
SELECT SegmentID, ..., COUNT(*), AVG(Recency), ... FROM CustomerSegments GROUP BY SegmentID;
```

*   **Pattern:** Group customers into distinct segments based on multiple dimensions of their behavior (beyond just RFM) using techniques potentially inspired by clustering algorithms like K-Means.
*   **Mechanism:** Calculates various customer metrics (RFM, product category preferences, engagement scores, etc.). Uses business rules (often via `CASE` expressions based on metric scores/ranges) or statistical clustering results (potentially calculated externally and imported) to assign customers to segments. Finally, aggregates metrics by segment to understand the characteristics and value of each group.

## 3. Targeted Interview Questions (Based on `38_select_analytical_queries.sql`)

**Question 1:** In the Year-over-Year comparison (section 1), what does `LAG(SUM(OrderAmount), 12) OVER(ORDER BY YEAR(OrderDate), MONTH(OrderDate))` calculate? Why is the offset 12?

**Solution 1:** It calculates the `SUM(OrderAmount)` from the row that is 12 positions *before* the current row, based on the specified ordering (Year, then Month). Since the data is grouped by month and ordered chronologically, looking back 12 rows effectively retrieves the sales sum for the **same month in the previous year**. The offset is 12 because there are 12 months in a year.

**Question 2:** Explain the purpose of the `UserCohorts` CTE in the Cohort Analysis example (section 3). What key pieces of information does it calculate for each order?

**Solution 2:** The `UserCohorts` CTE prepares the data for cohort analysis by calculating cohort assignment and timing for each individual order:
1.  It joins the `Orders` table with a subquery that finds the `FirstPurchaseDate` for each `UserID`.
2.  It determines the `CohortMonth` (the month of the user's first purchase).
3.  It calculates the `MonthNumber` for each order, representing how many months *after* the user's `CohortMonth` that specific order occurred (`DATEDIFF(MONTH, CohortMonth, OrderDate)`).
This allows the subsequent aggregation step to group users by their `CohortMonth` and count how many were active (`COUNT(DISTINCT UserID)`) in each subsequent `MonthNumber`.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which window function is commonly used to access data from a previous row in an ordered set?
    *   **Answer:** `LAG()`.
2.  **[Easy]** In RFM analysis, what do Recency, Frequency, and Monetary typically measure?
    *   **Answer:** Recency: Time since last purchase. Frequency: Number of purchases in a period. Monetary: Total amount spent in a period.
3.  **[Medium]** What is the difference between a rolling average and a running total, as calculated using window functions?
    *   **Answer:** A **running total** (e.g., `SUM(...) OVER (ORDER BY ... ROWS UNBOUNDED PRECEDING)`) accumulates values from the start of the partition up to the current row. A **rolling average** (e.g., `AVG(...) OVER (ORDER BY ... ROWS N PRECEDING)`) calculates the average over a fixed-size window of rows relative to the current row (e.g., the last 7 days).
4.  **[Medium]** In the Funnel Analysis example (section 4), why is `MAX(CASE WHEN EventType = 'Stage' THEN 1 ELSE 0 END)` used instead of `COUNT(CASE WHEN EventType = 'Stage' THEN 1 END)` when grouping by `UserID`?
    *   **Answer:** `MAX` is used to determine *if* the user reached that stage at least once. If a user performs the 'Visit' event multiple times, `MAX` will still result in 1 for `ReachedVisit`. `COUNT` would give the number of times the event occurred, which isn't what's needed to see if they simply reached that stage in the funnel.
5.  **[Medium]** What does "Support" typically represent in Market Basket Analysis?
    *   **Answer:** Support measures the frequency or proportion of transactions that contain a specific item or itemset. For a pair {A, B}, support is often calculated as `(Number of transactions containing both A and B) / (Total number of transactions)`. High support indicates the itemset appears frequently.
6.  **[Medium]** Can the Z-score calculation in the Anomaly Detection example (section 9) produce an error? How is it handled?
    *   **Answer:** Yes, it can produce a division-by-zero error if the standard deviation (`StdDevSales`) is zero (which happens if all values within the window are identical). The query handles this using `NULLIF(StdDevSales, 0)`. If `StdDevSales` is 0, `NULLIF` returns `NULL`, and division by `NULL` results in `NULL` for the Z-score, avoiding the error.
7.  **[Hard]** What are the potential challenges or limitations of using simple linear regression in SQL (as shown in section 13) for forecasting?
    *   **Answer:** Limitations include:
        *   Assumes a linear relationship between time and the value being forecast, which may not hold true.
        *   Doesn't account for seasonality or other complex patterns.
        *   Sensitive to outliers in historical data.
        *   SQL is not primarily a statistical tool; calculations can be complex to write and validate compared to dedicated statistical packages (R, Python).
        *   Doesn't provide confidence intervals or statistical significance measures for the forecast.
8.  **[Hard]** In the Cohort Analysis (section 3) or Retention Analysis (section 11), why is `COUNT(DISTINCT UserID)` often used in the final aggregation instead of just `COUNT(*)`?
    *   **Answer:** `COUNT(DISTINCT UserID)` is used to count the number of *unique* users from a specific cohort who were active in a given subsequent month (`MonthNumber`). A single user might have multiple activities or orders within that month (`COUNT(*)` would count all activities). For cohort retention/activity, we usually want to know how many *individual users* from the cohort performed *any* activity in that period, hence the distinct count on the user identifier.
9.  **[Hard]** Explain the difference between First-Touch and Last-Touch attribution models mentioned conceptually in section 12.
    *   **Answer:**
        *   **First-Touch Attribution:** Assigns 100% of the credit for a conversion to the *first* marketing channel or touchpoint that a user interacted with in their conversion journey.
        *   **Last-Touch Attribution:** Assigns 100% of the credit for a conversion to the *last* marketing channel or touchpoint that a user interacted with *before* converting.
    *   Other models exist (linear, time decay, U-shaped) that distribute credit across multiple touchpoints.
10. **[Hard/Tricky]** Could you use window functions to calculate RFM scores (Recency, Frequency, Monetary) without using a CTE or subquery first to calculate the base R, F, M values per customer? Why or why not?
    *   **Answer:** No, not directly in a single step on the base `Orders` table. The base RFM values (`Recency = DATEDIFF(DAY, MAX(OrderDate), GETDATE())`, `Frequency = COUNT(*)`, `Monetary = SUM(OrderAmount)`) require *aggregation* per `UserID` using `GROUP BY UserID`. Window functions like `NTILE` operate on individual rows or partitions *before* or *without* collapsing rows via `GROUP BY`. Therefore, you must first calculate the per-user R, F, M aggregates (using `GROUP BY` in a subquery or CTE), and *then* apply the `NTILE` window function to that aggregated result set to assign the scores.
