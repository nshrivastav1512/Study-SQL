/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\109_MATHEMATICAL_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Mathematical Functions with real-life examples
    using the HRSystem database schemas and tables.

    Mathematical Functions covered:
    1. ABS() - Returns absolute value
    2. ROUND() - Rounds a number to specified decimal places
    3. CEILING() - Returns smallest integer greater than or equal to
    4. FLOOR() - Returns largest integer less than or equal to
    5. SQRT() - Returns square root
    6. RAND() - Returns random float between 0 and 1
    7. POWER() - Raises number to specified power
    8. LOG() - Returns natural logarithm
    9. LOG10() - Returns base-10 logarithm
    10. EXP() - Returns exponential value
    11. SIN() - Returns sine
    12. COS() - Returns cosine
    13. TAN() - Returns tangent
    14. ASIN() - Returns arc sine
    15. ACOS() - Returns arc cosine
    16. ATAN() - Returns arc tangent
    17. ATN2() - Returns angle in radians between x-axis and point
    18. SIGN() - Returns sign of number
    19. DEGREES() - Converts radians to degrees
    20. RADIANS() - Converts degrees to radians
    21. COT() - Returns cotangent
    22. PI() - Returns value of π
    23. BINARY_CHECKSUM() - Returns binary checksum
    24. CHECKSUM() - Returns checksum
*/

USE HRSystem;
GO

-- Create sample tables if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[SalesTransactions]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.SalesTransactions (
        TransactionID INT PRIMARY KEY IDENTITY(1,1),
        ProductID INT,
        Quantity INT,
        UnitPrice DECIMAL(10,2),
        Discount DECIMAL(4,2),
        TransactionDate DATE,
        Latitude DECIMAL(9,6),
        Longitude DECIMAL(9,6)
    );

    -- Insert sample data
    INSERT INTO HR.SalesTransactions (ProductID, Quantity, UnitPrice, Discount, TransactionDate, Latitude, Longitude) VALUES
    (1, -5, 29.99, 0.15, '2023-08-01', 40.7128, -74.0060),  -- Negative quantity (return)
    (2, 10, 49.99, 0.25, '2023-08-02', 34.0522, -118.2437),
    (3, 3, 99.99, 0.10, '2023-08-03', 51.5074, -0.1278),
    (4, 8, 74.99, 0.20, '2023-08-04', 48.8566, 2.3522);

    -- Create table for geometric calculations
    CREATE TABLE HR.GeometricShapes (
        ShapeID INT PRIMARY KEY IDENTITY(1,1),
        ShapeName VARCHAR(50),
        Radius DECIMAL(10,2),
        Angle DECIMAL(10,2),
        Height DECIMAL(10,2),
        Width DECIMAL(10,2)
    );

    -- Insert sample shapes data
    INSERT INTO HR.GeometricShapes (ShapeName, Radius, Angle, Height, Width) VALUES
    ('Circle', 5.0, NULL, NULL, NULL),
    ('Triangle', NULL, 45.0, 4.0, 3.0),
    ('Rectangle', NULL, NULL, 6.0, 8.0),
    ('Sector', 10.0, 60.0, NULL, NULL);
END

-- 1. ABS() - Get absolute value of negative quantities
SELECT 
    TransactionID,
    Quantity AS OriginalQuantity,
    ABS(Quantity) AS AbsoluteQuantity,
    'Returns positive value' AS Description
FROM HR.SalesTransactions
WHERE Quantity < 0;
/* Output example:
TransactionID  OriginalQuantity  AbsoluteQuantity  Description
1              -5               5                 Returns positive value
*/

-- 2. ROUND() - Round unit prices to different decimal places
SELECT 
    UnitPrice AS OriginalPrice,
    ROUND(UnitPrice, 0) AS RoundedToWhole,
    ROUND(UnitPrice, 1) AS RoundedToTenth,
    ROUND(UnitPrice * (1 - Discount), 2) AS RoundedDiscountedPrice
FROM HR.SalesTransactions;
/* Output example:
OriginalPrice  RoundedToWhole  RoundedToTenth  RoundedDiscountedPrice
29.99          30.00           30.0            25.49
*/

-- 3. CEILING() and 4. FLOOR() - Calculate inventory packaging
SELECT 
    Quantity,
    UnitPrice,
    CEILING(Quantity/3.0) AS PackagesNeeded,    -- Boxes needed (3 items per box)
    FLOOR(UnitPrice) AS WholesalePrice          -- Wholesale price (floor value)
FROM HR.SalesTransactions;
/* Output example:
Quantity  UnitPrice  PackagesNeeded  WholesalePrice
10        49.99     4               49
*/

-- 5. SQRT() - Calculate diagonal of rectangular shapes
SELECT 
    ShapeName,
    Height,
    Width,
    SQRT(POWER(Height, 2) + POWER(Width, 2)) AS Diagonal
FROM HR.GeometricShapes
WHERE Height IS NOT NULL AND Width IS NOT NULL;
/* Output example:
ShapeName  Height  Width  Diagonal
Rectangle  6.0     8.0    10.0
*/

-- 6. RAND() - Generate random discounts
DECLARE @Counter INT = 1;
WHILE @Counter <= 5
BEGIN
    SELECT 
        @Counter AS SampleNumber,
        ROUND(RAND() * 0.5, 2) AS RandomDiscount,  -- Random discount between 0 and 50%
        'Sample random value' AS Description;
    SET @Counter += 1;
END;
/* Output example:
SampleNumber  RandomDiscount  Description
1             0.23           Sample random value
2             0.45           Sample random value
*/

-- 7. POWER() - Calculate compound interest
SELECT 
    1000 AS Principal,
    0.05 AS InterestRate,
    YearNumber,
    ROUND(1000 * POWER(1 + 0.05, YearNumber), 2) AS CompoundAmount
FROM (VALUES (1),(2),(3),(4),(5)) AS Years(YearNumber);
/* Output example:
Principal  InterestRate  YearNumber  CompoundAmount
1000       0.05          1           1050.00
1000       0.05          2           1102.50
*/

-- 8. LOG() and 9. LOG10() - Calculate growth rates
SELECT 
    100 AS StartValue,
    200 AS EndValue,
    LOG(200.0/100.0) AS NaturalGrowthRate,
    LOG10(200.0/100.0) AS Log10GrowthRate;
/* Output example:
StartValue  EndValue  NaturalGrowthRate  Log10GrowthRate
100         200       0.693147           0.301030
*/

-- 10. EXP() - Project future values
SELECT 
    TransactionID,
    UnitPrice,
    GrowthYear,
    ROUND(UnitPrice * EXP(0.1 * GrowthYear), 2) AS ProjectedPrice  -- 10% continuous growth
FROM HR.SalesTransactions
CROSS APPLY (VALUES (1),(2),(3)) AS Years(GrowthYear);
/* Output example:
TransactionID  UnitPrice  GrowthYear  ProjectedPrice
1              29.99      1           33.14
1              29.99      2           36.62
*/

-- 11. SIN(), 12. COS(), 13. TAN() - Trigonometric calculations
SELECT 
    Angle,
    ROUND(SIN(RADIANS(Angle)), 4) AS SineValue,
    ROUND(COS(RADIANS(Angle)), 4) AS CosineValue,
    ROUND(TAN(RADIANS(Angle)), 4) AS TangentValue
FROM HR.GeometricShapes
WHERE Angle IS NOT NULL;
/* Output example:
Angle  SineValue  CosineValue  TangentValue
45.0   0.7071     0.7071       1.0000
*/

-- 14. ASIN(), 15. ACOS(), 16. ATAN() - Inverse trigonometric functions
SELECT 
    Value,
    ROUND(DEGREES(ASIN(Value)), 4) AS ArcSine,
    ROUND(DEGREES(ACOS(Value)), 4) AS ArcCosine,
    ROUND(DEGREES(ATAN(Value)), 4) AS ArcTangent
FROM (VALUES (0), (0.5), (1)) AS Numbers(Value);
/* Output example:
Value  ArcSine  ArcCosine  ArcTangent
0      0.0000   90.0000    0.0000
0.5    30.0000  60.0000    26.5651
*/

-- 17. ATN2() - Calculate angles between points
SELECT 
    TransactionID,
    Latitude,
    Longitude,
    ROUND(DEGREES(ATN2(Latitude, Longitude)), 2) AS AngleFromEast
FROM HR.SalesTransactions;
/* Output example:
TransactionID  Latitude  Longitude  AngleFromEast
1              40.7128   -74.0060   151.23
*/

-- 18. SIGN() - Classify transactions
SELECT 
    TransactionID,
    Quantity,
    SIGN(Quantity) AS TransactionType,
    CASE SIGN(Quantity)
        WHEN -1 THEN 'Return'
        WHEN 1 THEN 'Sale'
        ELSE 'No Change'
    END AS TransactionDescription
FROM HR.SalesTransactions;
/* Output example:
TransactionID  Quantity  TransactionType  TransactionDescription
1              -5        -1               Return
2              10        1                Sale
*/

-- 19. DEGREES() and 20. RADIANS() - Convert between degrees and radians
SELECT 
    Angle AS AngleDegrees,
    ROUND(RADIANS(Angle), 4) AS AngleRadians,
    ROUND(DEGREES(RADIANS(Angle)), 4) AS BackToDegrees
FROM HR.GeometricShapes
WHERE Angle IS NOT NULL;
/* Output example:
AngleDegrees  AngleRadians  BackToDegrees
45.0          0.7854        45.0000
*/

-- 21. COT() - Calculate cotangent values
SELECT 
    Angle,
    ROUND(COT(RADIANS(Angle)), 4) AS CotangentValue,
    'Reciprocal of tangent' AS Description
FROM HR.GeometricShapes
WHERE Angle IS NOT NULL;
/* Output example:
Angle  CotangentValue  Description
45.0   1.0000          Reciprocal of tangent
*/

-- 22. PI() - Circle calculations
SELECT 
    ShapeName,
    Radius,
    ROUND(2 * PI() * Radius, 2) AS Circumference,
    ROUND(PI() * POWER(Radius, 2), 2) AS Area
FROM HR.GeometricShapes
WHERE Radius IS NOT NULL;
/* Output example:
ShapeName  Radius  Circumference  Area
Circle     5.0     31.42          78.54
*/

-- 23. BINARY_CHECKSUM() and 24. CHECKSUM() - Data change detection
SELECT 
    TransactionID,
    ProductID,
    Quantity,
    UnitPrice,
    BINARY_CHECKSUM(ProductID, Quantity, UnitPrice) AS BinaryCheck,
    CHECKSUM(ProductID, Quantity, UnitPrice) AS RegularCheck
FROM HR.SalesTransactions;
/* Output example:
TransactionID  ProductID  Quantity  UnitPrice  BinaryCheck  RegularCheck
1              1          -5        29.99      -123456789   -123456789
*/

-- Complex example combining multiple mathematical functions
SELECT 
    t.TransactionID,
    t.ProductID,
    t.Quantity,
    t.UnitPrice,
    -- Basic calculations
    ABS(t.Quantity) AS AbsoluteQty,
    ROUND(t.UnitPrice * (1 - t.Discount), 2) AS DiscountedPrice,
    -- Advanced calculations
    ROUND(t.UnitPrice * t.Quantity * (1 - t.Discount), 2) AS TotalAmount,
    -- Statistical calculations
    ROUND(SQRT(POWER(ABS(t.Quantity), 2) + POWER(t.UnitPrice, 2)), 2) AS VectorMagnitude,
    -- Geometric calculations
    ROUND(DEGREES(ATN2(t.Latitude, t.Longitude)), 2) AS LocationAngle,
    -- Random variation for analysis
    ROUND(t.UnitPrice * (1 + (RAND() - 0.5) * 0.1), 2) AS RandomizedPrice,
    -- Checksum for change detection
    BINARY_CHECKSUM(t.ProductID, t.Quantity, t.UnitPrice) AS RowChecksum
FROM HR.SalesTransactions t
WHERE 
    -- Filter using mathematical functions
    ABS(t.Quantity) > 0
    AND SIGN(t.UnitPrice) = 1
ORDER BY 
    -- Order by calculated values
    SQRT(POWER(ABS(t.Quantity), 2) + POWER(t.UnitPrice, 2)) DESC;
/* Output example:
TransactionID  ProductID  Quantity  UnitPrice  AbsoluteQty  DiscountedPrice  TotalAmount  VectorMagnitude  LocationAngle  RandomizedPrice  RowChecksum
2              2          10        49.99      10           37.49            374.90       51.23            151.23         52.49           -987654321
*/