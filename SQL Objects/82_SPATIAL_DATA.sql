-- =============================================
-- SQL Server SPATIAL DATA Guide
-- =============================================

/*
This guide demonstrates the use of Spatial Data in SQL Server for HR scenarios:
- Managing office locations and facilities
- Analyzing employee distribution and commute patterns
- Planning office space and resource allocation
- Optimizing service areas and coverage
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: CREATING SPATIAL DATA TABLES
-- =============================================

-- 1. Office Locations Table
IF OBJECT_ID('HR.OfficeLocations', 'U') IS NOT NULL
    DROP TABLE HR.OfficeLocations;

CREATE TABLE HR.OfficeLocations (
    LocationID INT PRIMARY KEY,
    LocationName NVARCHAR(100),
    Address NVARCHAR(200),
    Location GEOGRAPHY,
    Boundary GEOMETRY,
    Capacity INT,
    CurrentOccupancy INT,
    FacilityType NVARCHAR(50)
);

-- 2. Employee Addresses Table
IF OBJECT_ID('HR.EmployeeAddresses', 'U') IS NOT NULL
    DROP TABLE HR.EmployeeAddresses;

CREATE TABLE HR.EmployeeAddresses (
    EmployeeID INT PRIMARY KEY,
    Address NVARCHAR(200),
    Location GEOGRAPHY,
    PreferredOffice INT,
    CONSTRAINT FK_EmployeeAddresses_Employees
        FOREIGN KEY (EmployeeID) REFERENCES HR.Employees(EmployeeID),
    CONSTRAINT FK_EmployeeAddresses_Office
        FOREIGN KEY (PreferredOffice) REFERENCES HR.OfficeLocations(LocationID)
);

-- =============================================
-- PART 2: INSERTING SAMPLE DATA
-- =============================================

-- 1. Insert Office Locations
INSERT INTO HR.OfficeLocations (
    LocationID, LocationName, Address, Location, Boundary, 
    Capacity, CurrentOccupancy, FacilityType
)
VALUES
(
    1,
    'HQ Building',
    '100 Main Street, New York, NY 10001',
    geography::Point(40.7128, -74.0060, 4326), -- NYC coordinates
    geometry::STGeomFromText(
        'POLYGON((0 0, 0 100, 100 100, 100 0, 0 0))', -- Simple square building footprint
        0
    ),
    500,
    350,
    'Main Office'
),
(
    2,
    'West Coast Office',
    '200 Tech Drive, San Francisco, CA 94105',
    geography::Point(37.7749, -122.4194, 4326), -- SF coordinates
    geometry::STGeomFromText(
        'POLYGON((0 0, 0 75, 75 75, 75 0, 0 0))', -- Smaller office footprint
        0
    ),
    250,
    180,
    'Regional Office'
);

-- 2. Insert Employee Addresses (Sample data)
INSERT INTO HR.EmployeeAddresses (
    EmployeeID, Address, Location, PreferredOffice
)
VALUES
(
    1,
    '123 Park Ave, New York, NY 10002',
    geography::Point(40.7142, -73.9900, 4326),
    1
),
(
    2,
    '456 Market St, San Francisco, CA 94103',
    geography::Point(37.7790, -122.4100, 4326),
    2
);

-- =============================================
-- PART 3: SPATIAL QUERIES AND ANALYSIS
-- =============================================

-- 1. Find Nearest Office
CREATE OR ALTER PROCEDURE HR.FindNearestOffice
    @EmployeeLocation GEOGRAPHY
AS
BEGIN
    SELECT TOP 1
        LocationName,
        Address,
        Location.STDistance(@EmployeeLocation) / 1609.34 AS DistanceMiles,
        Capacity - CurrentOccupancy AS AvailableSpace
    FROM HR.OfficeLocations
    WHERE Capacity > CurrentOccupancy
    ORDER BY Location.STDistance(@EmployeeLocation);
END;

-- 2. Analyze Employee Commute Distances
CREATE OR ALTER PROCEDURE HR.AnalyzeCommutes
    @MaxCommuteMiles FLOAT = 50
AS
BEGIN
    SELECT 
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        ol.LocationName AS Office,
        ea.Address AS EmployeeAddress,
        ea.Location.STDistance(ol.Location) / 1609.34 AS CommuteMiles,
        CASE 
            WHEN ea.Location.STDistance(ol.Location) / 1609.34 <= 10 THEN 'Short'
            WHEN ea.Location.STDistance(ol.Location) / 1609.34 <= 25 THEN 'Medium'
            ELSE 'Long'
        END AS CommuteCategory
    FROM HR.Employees e
    JOIN HR.EmployeeAddresses ea ON e.EmployeeID = ea.EmployeeID
    JOIN HR.OfficeLocations ol ON ea.PreferredOffice = ol.LocationID
    WHERE ea.Location.STDistance(ol.Location) / 1609.34 <= @MaxCommuteMiles
    ORDER BY CommuteMiles DESC;
END;

-- 3. Calculate Office Coverage Areas
CREATE OR ALTER PROCEDURE HR.AnalyzeOfficeCoverage
    @RadiusMiles FLOAT = 25
AS
BEGIN
    SELECT 
        ol.LocationName,
        ol.Location.STBuffer(@RadiusMiles * 1609.34) AS CoverageArea,
        (
            SELECT COUNT(*)
            FROM HR.EmployeeAddresses ea
            WHERE ea.Location.STIntersects(
                ol.Location.STBuffer(@RadiusMiles * 1609.34)
            ) = 1
        ) AS EmployeesInRange,
        FORMAT(ol.CurrentOccupancy * 100.0 / ol.Capacity, 'N2') + '%' AS Utilization
    FROM HR.OfficeLocations ol;
END;

-- =============================================
-- PART 4: OFFICE SPACE PLANNING
-- =============================================

-- 1. Analyze Office Space Utilization
CREATE OR ALTER PROCEDURE HR.AnalyzeSpaceUtilization
AS
BEGIN
    SELECT 
        LocationName,
        Capacity,
        CurrentOccupancy,
        FORMAT(CurrentOccupancy * 100.0 / Capacity, 'N2') + '%' AS UtilizationRate,
        Boundary.STArea() AS TotalArea,
        Boundary.STArea() / CurrentOccupancy AS AreaPerEmployee,
        CASE
            WHEN CurrentOccupancy * 1.0 / Capacity >= 0.9 THEN 'Critical'
            WHEN CurrentOccupancy * 1.0 / Capacity >= 0.75 THEN 'High'
            WHEN CurrentOccupancy * 1.0 / Capacity >= 0.5 THEN 'Moderate'
            ELSE 'Low'
        END AS UtilizationLevel
    FROM HR.OfficeLocations
    ORDER BY CurrentOccupancy * 1.0 / Capacity DESC;
END;

-- 2. Plan Office Expansion
CREATE OR ALTER PROCEDURE HR.PlanOfficeExpansion
    @GrowthRate DECIMAL(5,2) = 0.15, -- 15% growth
    @PlanningHorizonMonths INT = 12
AS
BEGIN
    WITH ProjectedGrowth AS (
        SELECT 
            LocationID,
            LocationName,
            CurrentOccupancy,
            Capacity,
            CEILING(CurrentOccupancy * POWER(1 + @GrowthRate, @PlanningHorizonMonths / 12.0)) 
                AS ProjectedOccupancy
        FROM HR.OfficeLocations
    )
    SELECT 
        LocationName,
        CurrentOccupancy AS CurrentEmployees,
        ProjectedOccupancy AS ProjectedEmployees,
        Capacity AS CurrentCapacity,
        CASE 
            WHEN ProjectedOccupancy > Capacity 
            THEN ProjectedOccupancy - Capacity
            ELSE 0
        END AS AdditionalCapacityNeeded,
        CASE 
            WHEN ProjectedOccupancy > Capacity 
            THEN 'Expansion Required'
            WHEN ProjectedOccupancy > Capacity * 0.9
            THEN 'Monitor Closely'
            ELSE 'Adequate Capacity'
        END AS ExpansionStatus
    FROM ProjectedGrowth
    ORDER BY 
        CASE 
            WHEN ProjectedOccupancy > Capacity THEN 1
            WHEN ProjectedOccupancy > Capacity * 0.9 THEN 2
            ELSE 3
        END;
END;

-- =============================================
-- PART 5: SPATIAL INDEXING AND OPTIMIZATION
-- =============================================

-- 1. Create Spatial Indexes
CREATE SPATIAL INDEX [IX_OfficeLocations_Location] ON HR.OfficeLocations
(
    Location
)
USING GEOMETRY_GRID
WITH (
    BOUNDING_BOX = (xmin=-180, ymin=-90, xmax=180, ymax=90),
    GRIDS = (LEVEL_1 = MEDIUM, LEVEL_2 = MEDIUM, LEVEL_3 = MEDIUM, LEVEL_4 = MEDIUM),
    CELLS_PER_OBJECT = 16,
    PAD_INDEX = OFF,
    STATISTICS_NORECOMPUTE = OFF,
    SORT_IN_TEMPDB = OFF,
    DROP_EXISTING = OFF,
    ONLINE = OFF,
    ALLOW_ROW_LOCKS = ON,
    ALLOW_PAGE_LOCKS = ON
) ON [PRIMARY];

CREATE SPATIAL INDEX [IX_EmployeeAddresses_Location] ON HR.EmployeeAddresses
(
    Location
)
USING GEOMETRY_GRID
WITH (
    BOUNDING_BOX = (xmin=-180, ymin=-90, xmax=180, ymax=90),
    GRIDS = (LEVEL_1 = MEDIUM, LEVEL_2 = MEDIUM, LEVEL_3 = MEDIUM, LEVEL_4 = MEDIUM),
    CELLS_PER_OBJECT = 16,
    PAD_INDEX = OFF,
    STATISTICS_NORECOMPUTE = OFF,
    SORT_IN_TEMPDB = OFF,
    DROP_EXISTING = OFF,
    ONLINE = OFF,
    ALLOW_ROW_LOCKS = ON,
    ALLOW_PAGE_LOCKS = ON
) ON [PRIMARY];