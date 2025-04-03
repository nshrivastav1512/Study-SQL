# SQL Mathematical Functions

## Introduction

**Definition:** SQL Mathematical Functions are built-in functions that perform calculations on numeric data types. They encompass a wide range of operations, including arithmetic, trigonometric, logarithmic, rounding, and statistical calculations.

**Explanation:** These functions are essential for performing quantitative analysis, data transformation, financial calculations, scientific computations, and geometric problems directly within SQL queries. They allow you to manipulate numeric values to derive meaningful insights and results without needing to process the data externally.

## Functions Covered in this Section

This document covers various SQL Server Mathematical Functions, demonstrated using hypothetical `HR.SalesTransactions` and `HR.GeometricShapes` tables:

1.  `ABS(numeric_expression)`: Returns the absolute (non-negative) value.
2.  `ROUND(numeric_expression, length, [function])`: Rounds a number to a specified number of decimal places (`length`). Optional `function` parameter (non-zero) truncates instead of rounding.
3.  `CEILING(numeric_expression)`: Returns the smallest integer greater than or equal to the specified numeric expression.
4.  `FLOOR(numeric_expression)`: Returns the largest integer less than or equal to the specified numeric expression.
5.  `SQRT(float_expression)`: Returns the square root of the specified non-negative float value.
6.  `RAND([seed])`: Returns a pseudo-random `float` value between 0 (inclusive) and 1 (exclusive). An optional integer `seed` can provide repeatable sequences.
7.  `POWER(float_expression, y)`: Returns the value of the specified expression raised to the specified power (`y`).
8.  `LOG(float_expression, [base])`: Returns the natural logarithm (base *e*) of the specified float expression, or the logarithm to the specified `base`.
9.  `LOG10(float_expression)`: Returns the base-10 logarithm.
10. `EXP(float_expression)`: Returns the exponential value (*e* raised to the power of the float expression).
11. `SIN(float_expression)`: Returns the trigonometric sine of the specified angle (in radians).
12. `COS(float_expression)`: Returns the trigonometric cosine of the specified angle (in radians).
13. `TAN(float_expression)`: Returns the trigonometric tangent of the specified angle (in radians).
14. `ASIN(float_expression)`: Returns the arc sine (angle in radians whose sine is the specified float expression). Input must be between -1 and 1.
15. `ACOS(float_expression)`: Returns the arc cosine (angle in radians whose cosine is the specified float expression). Input must be between -1 and 1.
16. `ATAN(float_expression)`: Returns the arc tangent (angle in radians whose tangent is the specified float expression).
17. `ATN2(y_float_expression, x_float_expression)`: Returns the angle in radians between the positive x-axis and the ray from the origin to the point (y, x).
18. `SIGN(numeric_expression)`: Returns the sign of the specified expression: +1 (positive), 0 (zero), or -1 (negative).
19. `DEGREES(radian_expression)`: Converts an angle from radians to degrees.
20. `RADIANS(degree_expression)`: Converts an angle from degrees to radians.
21. `COT(float_expression)`: Returns the trigonometric cotangent of the specified angle (in radians).
22. `PI()`: Returns the constant value of Pi (π).
23. `BINARY_CHECKSUM(* | expression [,...n])`: Returns the binary checksum value computed over a list of expressions or all columns (`*`) of a table row. Sensitive to order and data type.
24. `CHECKSUM(* | expression [,...n])`: Returns the checksum value computed over a list of expressions or all columns. Less sensitive to order/type changes than `BINARY_CHECKSUM`.

*(Note: The SQL script includes logic to create and populate sample `HR.SalesTransactions` and `HR.GeometricShapes` tables if they don't exist.)*

---

## Examples

### 1. ABS()

**Goal:** Get the absolute quantity for sales transactions, treating returns (negative quantity) as positive for volume calculation.

```sql
SELECT
    TransactionID,
    Quantity AS OriginalQuantity,
    ABS(Quantity) AS AbsoluteQuantity
FROM HR.SalesTransactions
WHERE Quantity < 0;
```

**Explanation:**
*   `ABS(Quantity)` returns the non-negative value of the `Quantity`. If `Quantity` is -5, `ABS` returns 5.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
TransactionID  OriginalQuantity  AbsoluteQuantity
-------------  ----------------  ----------------
1              -5                5
</code></pre>
</details>

### 2. ROUND()

**Goal:** Round unit prices to the nearest whole number, nearest tenth, and calculate a rounded discounted price.

```sql
SELECT
    UnitPrice AS OriginalPrice,
    ROUND(UnitPrice, 0) AS RoundedToWhole,
    ROUND(UnitPrice, 1) AS RoundedToTenth,
    ROUND(UnitPrice * (1 - Discount), 2) AS RoundedDiscountedPrice
FROM HR.SalesTransactions;
```

**Explanation:**
*   `ROUND(number, decimals)` rounds the `number` to the specified number of `decimals`.
*   `decimals = 0` rounds to the nearest integer.
*   `decimals = 1` rounds to one decimal place.
*   `decimals = 2` rounds to two decimal places (typical for currency).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
OriginalPrice  RoundedToWhole  RoundedToTenth  RoundedDiscountedPrice
-------------  --------------  --------------  ----------------------
29.99          30.00           30.0            25.49
49.99          50.00           50.0            37.49
99.99          100.00          100.0           89.99
74.99          75.00           75.0            59.99
</code></pre>
</details>

### 3. CEILING() and 4. FLOOR()

**Goal:** Calculate the number of full boxes needed (assuming 3 items per box) using `CEILING`, and determine a wholesale price using `FLOOR`.

```sql
SELECT
    Quantity,
    UnitPrice,
    CEILING(Quantity / 3.0) AS PackagesNeeded, -- Use 3.0 for float division
    FLOOR(UnitPrice) AS WholesalePrice
FROM HR.SalesTransactions
WHERE Quantity > 0; -- Only for sales, not returns
```

**Explanation:**
*   `CEILING(number)` returns the smallest integer greater than or equal to the `number` (rounds up). Useful for determining how many containers are needed.
*   `FLOOR(number)` returns the largest integer less than or equal to the `number` (rounds down).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
Quantity  UnitPrice  PackagesNeeded  WholesalePrice
--------  ---------  --------------  --------------
10        49.99      4               49.00
3         99.99      1               99.00
8         74.99      3               74.00
</code></pre>
</details>

### 5. SQRT()

**Goal:** Calculate the diagonal length of rectangular shapes using the Pythagorean theorem (a² + b² = c² => c = sqrt(a² + b²)).

```sql
SELECT
    ShapeName,
    Height,
    Width,
    SQRT(POWER(Height, 2) + POWER(Width, 2)) AS Diagonal
FROM HR.GeometricShapes
WHERE ShapeName = 'Rectangle';
```

**Explanation:**
*   `POWER(Height, 2)` calculates Height squared.
*   `POWER(Width, 2)` calculates Width squared.
*   `SQRT(...)` calculates the square root of the sum of the squares.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
ShapeName  Height  Width  Diagonal
---------  ------  -----  --------
Rectangle  6.00    8.00   10.00
</code></pre>
</details>

### 6. RAND()

**Goal:** Generate a few sample random discount percentages between 0% and 50%.

```sql
-- Generate one random value
SELECT RAND() AS RandomValue;

-- Generate a random discount between 0 and 0.5 (50%)
SELECT ROUND(RAND() * 0.5, 2) AS RandomDiscount;
```

**Explanation:**
*   `RAND()` returns a random `float` between 0 and 1.
*   Multiplying by 0.5 scales the range to 0 to 0.5.
*   `ROUND(..., 2)` formats it to two decimal places.
*   Note: Calling `RAND()` repeatedly within the *same query batch* without a seed might return the same value. The script uses a `WHILE` loop to demonstrate different values across separate executions.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Output will vary on each execution.</p>
<pre><code>
RandomValue
------------------
0.75398187663015

RandomDiscount
--------------
0.38
</code></pre>
</details>

### 7. POWER()

**Goal:** Calculate the future value of an investment using the compound interest formula: Amount = Principal * (1 + Rate)^Years.

```sql
SELECT
    1000 AS Principal,
    0.05 AS InterestRate,
    YearNumber,
    ROUND(1000 * POWER(1 + 0.05, YearNumber), 2) AS CompoundAmount
FROM (VALUES (1),(2),(3),(4),(5)) AS Years(YearNumber);
```

**Explanation:**
*   `POWER(base, exponent)` calculates `base` raised to the power of `exponent`.
*   Here, `base` is `(1 + InterestRate)` and `exponent` is `YearNumber`.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
Principal  InterestRate  YearNumber  CompoundAmount
---------  ------------  ----------  --------------
1000       0.05          1           1050.00
1000       0.05          2           1102.50
1000       0.05          3           1157.63
1000       0.05          4           1215.51
1000       0.05          5           1276.28
</code></pre>
</details>

### 8. LOG() and 9. LOG10()

**Goal:** Calculate the natural logarithm (`LOG`) and base-10 logarithm (`LOG10`) of a growth factor (EndValue / StartValue).

```sql
SELECT
    100 AS StartValue,
    200 AS EndValue,
    LOG(200.0 / 100.0) AS NaturalLogGrowth, -- Log base e
    LOG10(200.0 / 100.0) AS Base10LogGrowth   -- Log base 10
FROM (VALUES (1)) AS Dummy(N); -- Dummy table for single row calculation
```

**Explanation:**
*   `LOG(number)` returns the natural logarithm (base *e*).
*   `LOG10(number)` returns the base-10 logarithm. Logarithms are often used in growth rate calculations and analyzing exponential processes.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
StartValue  EndValue  NaturalLogGrowth   Base10LogGrowth
----------  --------  -----------------  ---------------
100         200       0.693147180559945  0.301029995663981
</code></pre>
</details>

### 10. EXP()

**Goal:** Project future prices assuming a 10% continuous annual growth rate using the formula: FuturePrice = CurrentPrice * e^(Rate * Years).

```sql
SELECT
    TransactionID,
    UnitPrice,
    GrowthYear,
    ROUND(UnitPrice * EXP(0.1 * GrowthYear), 2) AS ProjectedPrice
FROM HR.SalesTransactions
CROSS APPLY (VALUES (1),(2),(3)) AS Years(GrowthYear);
```

**Explanation:**
*   `EXP(number)` calculates *e* (Euler's number, ~2.718) raised to the power of `number`. It's the inverse of the natural logarithm (`LOG`). Used here for continuous compounding/growth.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Showing results for TransactionID 2:</p>
<pre><code>
TransactionID  UnitPrice  GrowthYear  ProjectedPrice
-------------  ---------  ----------  --------------
2              49.99      1           55.25
2              49.99      2           61.07
2              49.99      3           67.49
</code></pre>
</details>

### 11-13. SIN(), COS(), TAN()

**Goal:** Calculate the sine, cosine, and tangent of angles (given in degrees) from the shapes table.

```sql
SELECT
    Angle,
    ROUND(SIN(RADIANS(Angle)), 4) AS SineValue,   -- Input must be in radians
    ROUND(COS(RADIANS(Angle)), 4) AS CosineValue, -- Input must be in radians
    ROUND(TAN(RADIANS(Angle)), 4) AS TangentValue -- Input must be in radians
FROM HR.GeometricShapes
WHERE Angle IS NOT NULL;
```

**Explanation:**
*   These functions calculate standard trigonometric ratios.
*   **Crucially**, they expect the input angle to be in **radians**. The `RADIANS()` function is used to convert the `Angle` (assumed to be in degrees) before calculation.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data (Angle = 45 and 60 degrees):</p>
<pre><code>
Angle  SineValue  CosineValue  TangentValue
-----  ---------  -----------  ------------
45.00  0.7071     0.7071       1.0000
60.00  0.8660     0.5000       1.7321
</code></pre>
</details>

### 14-16. ASIN(), ACOS(), ATAN()

**Goal:** Calculate the inverse trigonometric functions (arc sine, arc cosine, arc tangent) for given values, returning the angle in degrees.

```sql
SELECT
    Value,
    ROUND(DEGREES(ASIN(Value)), 4) AS ArcSineDegrees,   -- Output is in radians, convert to degrees
    ROUND(DEGREES(ACOS(Value)), 4) AS ArcCosineDegrees, -- Output is in radians, convert to degrees
    ROUND(DEGREES(ATAN(Value)), 4) AS ArcTangentDegrees -- Output is in radians, convert to degrees
FROM (VALUES (0), (0.5), (1)) AS Numbers(Value)
WHERE Value BETWEEN -1 AND 1; -- Input domain for ASIN/ACOS
```

**Explanation:**
*   These functions return the angle (in **radians**) whose sine, cosine, or tangent is the input value.
*   `ASIN` and `ACOS` require input between -1 and 1.
*   The `DEGREES()` function is used to convert the radian result back to degrees for easier interpretation.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<pre><code>
Value  ArcSineDegrees  ArcCosineDegrees  ArcTangentDegrees
-----  --------------  ----------------  -----------------
0.0   0.0000          90.0000           0.0000
0.5   30.0000         60.0000           26.5651
1.0   90.0000         0.0000            45.0000
</code></pre>
</details>

### 17. ATN2()

**Goal:** Calculate the angle (relative to the positive X-axis) for geographic coordinates (Longitude as X, Latitude as Y).

```sql
SELECT
    TransactionID,
    Latitude,
    Longitude,
    ROUND(DEGREES(ATN2(Latitude, Longitude)), 2) AS AngleFromOriginEast
FROM HR.SalesTransactions;
```

**Explanation:**
*   `ATN2(y, x)` returns the arc tangent of `y / x` but correctly handles all four quadrants and the signs of `y` and `x` to return an angle between -π and +π radians.
*   `DEGREES()` converts the result to degrees.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
TransactionID  Latitude  Longitude  AngleFromOriginEast
-------------  --------  ---------  -------------------
1              40.7128   -74.0060   151.23
2              34.0522   -118.2437  163.95
3              51.5074   -0.1278    90.15
4              48.8566   2.3522     87.27
</code></pre>
</details>

### 18. SIGN()

**Goal:** Determine if a sales transaction represents a sale (+1), a return (-1), or zero change (0).

```sql
SELECT
    TransactionID,
    Quantity,
    SIGN(Quantity) AS TransactionSign,
    CASE SIGN(Quantity)
        WHEN -1 THEN 'Return'
        WHEN 1 THEN 'Sale'
        ELSE 'No Change'
    END AS TransactionDescription
FROM HR.SalesTransactions;
```

**Explanation:**
*   `SIGN(number)` returns -1, 0, or 1 based on the sign of the input number. Useful for conditional logic.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data:</p>
<pre><code>
TransactionID  Quantity  TransactionSign  TransactionDescription
-------------  --------  ---------------  ----------------------
1              -5        -1               Return
2              10        1                Sale
3              3         1                Sale
4              8         1                Sale
</code></pre>
</details>

### 19. DEGREES() and 20. RADIANS()

**Goal:** Convert angles between degrees and radians.

```sql
SELECT
    Angle AS AngleDegrees,
    ROUND(RADIANS(Angle), 4) AS AngleRadians,
    ROUND(DEGREES(RADIANS(Angle)), 4) AS BackToDegrees
FROM HR.GeometricShapes
WHERE Angle IS NOT NULL;
```

**Explanation:**
*   `RADIANS(degrees)` converts degrees to radians (multiply by π/180).
*   `DEGREES(radians)` converts radians to degrees (multiply by 180/π). Essential when working with trigonometric functions.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data (Angle = 45 and 60 degrees):</p>
<pre><code>
AngleDegrees  AngleRadians  BackToDegrees
------------  ------------  -------------
45.00         0.7854        45.0000
60.00         1.0472        60.0000
</code></pre>
</details>

### 21. COT()

**Goal:** Calculate the cotangent (1 / tangent) of angles.

```sql
SELECT
    Angle,
    ROUND(COT(RADIANS(Angle)), 4) AS CotangentValue
FROM HR.GeometricShapes
WHERE Angle IS NOT NULL AND TAN(RADIANS(Angle)) <> 0; -- Avoid division by zero
```

**Explanation:**
*   `COT(angle_in_radians)` calculates the cotangent. Requires input in radians.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data (Angle = 45 and 60 degrees):</p>
<pre><code>
Angle  CotangentValue
-----  --------------
45.00  1.0000
60.00  0.5774
</code></pre>
</details>

### 22. PI()

**Goal:** Calculate the circumference (2 * π * r) and area (π * r²) of circles.

```sql
SELECT
    ShapeName,
    Radius,
    ROUND(2 * PI() * Radius, 2) AS Circumference,
    ROUND(PI() * POWER(Radius, 2), 2) AS Area
FROM HR.GeometricShapes
WHERE ShapeName = 'Circle';
```

**Explanation:**
*   `PI()` returns the mathematical constant π (~3.14159).

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Based on sample data (Radius = 5.0):</p>
<pre><code>
ShapeName  Radius  Circumference  Area
---------  ------  -------------  -----
Circle     5.00    31.42          78.54
</code></pre>
</details>

### 23. BINARY_CHECKSUM() and 24. CHECKSUM()

**Goal:** Calculate checksums for transaction rows to detect potential data changes.

```sql
SELECT
    TransactionID,
    ProductID,
    Quantity,
    UnitPrice,
    BINARY_CHECKSUM(ProductID, Quantity, UnitPrice) AS BinaryCheck,
    CHECKSUM(ProductID, Quantity, UnitPrice) AS RegularCheck
FROM HR.SalesTransactions;
```

**Explanation:**
*   `BINARY_CHECKSUM` computes a checksum based on the binary representation of the column values. It's generally more sensitive to changes (including data type or collation changes) but collisions are still possible.
*   `CHECKSUM` computes a checksum based on the values themselves. Less sensitive to underlying representation changes but can have more collisions than `BINARY_CHECKSUM`.
*   Useful for comparing rows or detecting changes, but not cryptographically secure.

<details>
<summary>Example Query Output (Hypothetical)</summary>
<p>Checksum values are integers and depend on the exact input values.</p>
<pre><code>
TransactionID  ProductID  Quantity  UnitPrice  BinaryCheck  RegularCheck
-------------  ---------  --------  ---------  -----------  ------------
1              1          -5        29.99      [Some Int]   [Some Int]
2              2          10        49.99      [Some Int]   [Some Int]
3              3          3         99.99      [Some Int]   [Some Int]
4              4          8         74.99      [Some Int]   [Some Int]
</code></pre>
</details>

---

## Interview Question

**Question:** Write a SQL query for the `HR.SalesTransactions` table to calculate the final `TotalAmount` for each transaction (`Quantity * UnitPrice * (1 - Discount)`), ensuring the result is rounded to 2 decimal places. Only include transactions where the calculated `TotalAmount` is greater than $100.

### Solution Script

```sql
SELECT
    TransactionID,
    ProductID,
    Quantity,
    UnitPrice,
    Discount,
    ROUND(Quantity * UnitPrice * (1 - Discount), 2) AS TotalAmount
FROM HR.SalesTransactions
WHERE ROUND(Quantity * UnitPrice * (1 - Discount), 2) > 100;
-- Note: Calculating in WHERE is generally less efficient than HAVING after aggregation,
-- but here we filter individual rows before any aggregation.
-- Alternatively, use a subquery or CTE:
-- WITH CalculatedSales AS (
--     SELECT
--         TransactionID, ProductID, Quantity, UnitPrice, Discount,
--         ROUND(Quantity * UnitPrice * (1 - Discount), 2) AS TotalAmount
--     FROM HR.SalesTransactions
-- )
-- SELECT * FROM CalculatedSales WHERE TotalAmount > 100;

```

### Explanation

1.  **`SELECT ..., ROUND(Quantity * UnitPrice * (1 - Discount), 2) AS TotalAmount`**: Selects the relevant columns and calculates the total amount.
    *   `Quantity * UnitPrice` gives the gross amount.
    *   `(1 - Discount)` calculates the factor to apply after the discount (e.g., 0.15 discount means a factor of 0.85).
    *   Multiplying these gives the net amount.
    *   `ROUND(..., 2)` rounds the final calculated amount to two decimal places, suitable for currency.
2.  **`FROM HR.SalesTransactions`**: Specifies the source table.
3.  **`WHERE ROUND(Quantity * UnitPrice * (1 - Discount), 2) > 100`**: Filters the rows *before* output. It recalculates the rounded `TotalAmount` and keeps only those rows where this value exceeds 100. While functional, repeating the calculation isn't ideal. Using a Common Table Expression (CTE) or subquery (as shown in the comments) is often cleaner and potentially more efficient as the calculation is done only once.

---

## Tricky Interview Questions (Easy to Hard)

1.  **Easy:** What is the difference between `ROUND(123.456, 1)` and `ROUND(123.456, -1)`?
    *   *(Answer Hint: Positive length rounds decimals, negative length rounds to the left of the decimal point)*
2.  **Easy:** Does `RAND()` guarantee a unique number every time it's called within a single query? Explain.
    *   *(Answer Hint: No, without a seed, it might return the same value multiple times within one statement execution)*
3.  **Medium:** Explain the difference between `CEILING(X)` and `FLOOR(X)` when X is negative (e.g., -3.4).
    *   *(Answer Hint: `CEILING(-3.4)` is -3, `FLOOR(-3.4)` is -4)*
4.  **Medium:** Why do trigonometric functions like `SIN`, `COS`, `TAN` require input in radians? How do you convert degrees to radians in SQL?
    *   *(Answer Hint: Mathematical standard for these functions. Use `RADIANS(degrees)`)*
5.  **Medium:** What potential issue might arise when using `SQRT()` or `LOG()`/`LOG10()`? How can you prevent errors?
    *   *(Answer Hint: Invalid input - negative numbers for `SQRT`, non-positive numbers for `LOG`/`LOG10`. Use `WHERE` clause or `CASE` statement to check input)*
6.  **Medium/Hard:** When might `ATN2(Y, X)` be preferred over `ATAN(Y/X)`?
    *   *(Answer Hint: `ATN2` handles X=0 correctly and determines the correct quadrant based on the signs of both Y and X)*
7.  **Hard:** Can `CHECKSUM` or `BINARY_CHECKSUM` be reliably used to detect *all* data modifications in a row? Explain the concept of collisions.
    *   *(Answer Hint: No, collisions are possible (different inputs producing the same checksum), although less likely with `BINARY_CHECKSUM`. Not cryptographically secure)*
8.  **Hard:** How would you calculate the Nth root of a number (e.g., the cube root) using standard mathematical functions?
    *   *(Answer Hint: Use `POWER(number, 1.0/N)`. E.g., cube root is `POWER(number, 1.0/3.0)`)*
9.  **Hard:** Describe how you could simulate rolling a standard six-sided die using `RAND()`.
    *   *(Answer Hint: Scale `RAND()` to the desired range and use `FLOOR` or `CEILING`. E.g., `FLOOR(RAND() * 6) + 1`)*
10. **Hard:** Explain the difference in behavior between `ROUND(2.5, 0)` and `ROUND(3.5, 0)` in SQL Server compared to typical "round half to even" (Banker's rounding) rules sometimes seen elsewhere.
    *   *(Answer Hint: SQL Server's `ROUND` typically rounds .5 away from zero. `ROUND(2.5, 0)` is 3, `ROUND(3.5, 0)` is 4)*