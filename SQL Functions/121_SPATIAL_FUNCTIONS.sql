/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\121_SPATIAL_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Spatial Functions
    using the HRSystem database. These functions help in handling
    geographic and geometric data operations.

    Spatial Functions covered:
    1. STDistance - Calculate distance between points
    2. STIntersects - Check if geometries intersect
    3. STContains - Check if one geometry contains another
    4. STBuffer - Create buffer around geometry
    5. STArea - Calculate area
    6. STLength - Calculate length
    7. STPointN - Get point from linestring
    8. STSrid - Get spatial reference ID
    9. STAsText - Convert to WKT format
    10. STGeomFromText - Create from WKT format
*/

USE HRSystem;
GO

-- Create tables for storing location data if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[Locations]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.Locations (
        LocationID INT PRIMARY KEY IDENTITY(1,1),
        LocationName NVARCHAR(100),
        Address NVARCHAR(200),
        City NVARCHAR(50),
        GeoLocation GEOGRAPHY,
        Boundary GEOMETRY,
        CreatedDate DATETIME2 DEFAULT SYSDATETIME()
    );

    -- Insert sample office locations
    INSERT INTO HR.Locations (LocationName, Address, City, GeoLocation, Boundary)
    VALUES
    ('Main Office', 
     '123 Business Ave', 
     'New York',
     geography::STPointFromText('POINT(-74.005974 40.712776)', 4326),
     geometry::STGeomFromText('POLYGON((-74.006974 40.713776, -74.004974 40.713776, -74.004974 40.711776, -74.006974 40.711776, -74.006974 40.713776))', 0)
    ),
    ('Branch Office', 
     '456 Corporate Blvd', 
     'Los Angeles',
     geography::STPointFromText('POINT(-118.243683 34.052235)', 4326),
     geometry::STGeomFromText('POLYGON((-118.244683 34.053235, -118.242683 34.053235, -118.242683 34.051235, -118.244683 34.051235, -118.244683 34.053235))', 0)
    ),
    ('Research Center', 
     '789 Innovation Dr', 
     'Boston',
     geography::STPointFromText('POINT(-71.058880 42.360082)', 4326),
     geometry::STGeomFromText('POLYGON((-71.059880 42.361082, -71.057880 42.361082, -71.057880 42.359082, -71.059880 42.359082, -71.059880 42.361082))', 0)
    );
END

-- Create table for employee work locations
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[EmployeeLocations]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.EmployeeLocations (
        EmployeeID INT PRIMARY KEY,
        WorkLocation GEOGRAPHY,
        HomeLocation GEOGRAPHY,
        CommutePath GEOGRAPHY,
        LastUpdated DATETIME2 DEFAULT SYSDATETIME()
    );

    -- Insert sample employee locations
    INSERT INTO HR.EmployeeLocations (EmployeeID, WorkLocation, HomeLocation)
    VALUES
    (1, 
     geography::STPointFromText('POINT(-74.005974 40.712776)', 4326),
     geography::STPointFromText('POINT(-74.015974 40.722776)', 4326)
    ),
    (2,
     geography::STPointFromText('POINT(-118.243683 34.052235)', 4326),
     geography::STPointFromText('POINT(-118.253683 34.062235)', 4326)
    ),
    (3,
     geography::STPointFromText('POINT(-71.058880 42.360082)', 4326),
     geography::STPointFromText('POINT(-71.068880 42.370082)', 4326)
    );
END

-- 1. STDistance - Calculate distance between office and employee home
SELECT 
    e.EmployeeID,
    l.LocationName,
    e.WorkLocation.STDistance(e.HomeLocation) / 1000.0 AS CommuteDistanceKM
FROM HR.EmployeeLocations e
JOIN HR.Locations l ON e.WorkLocation.STEquals(l.GeoLocation) = 1;

-- 2. STIntersects - Check if employee is within office boundary
SELECT 
    e.EmployeeID,
    l.LocationName,
    CASE 
        WHEN l.Boundary.STIntersects(e.WorkLocation.STAsText()::geometry) = 1
        THEN 'Inside office boundary'
        ELSE 'Outside office boundary'
    END AS LocationStatus
FROM HR.EmployeeLocations e
CROSS JOIN HR.Locations l;

-- 3. STContains - Find offices that contain specific points
SELECT 
    LocationName,
    CASE 
        WHEN Boundary.STContains(geometry::STPointFromText('POINT(-74.005974 40.712776)', 0)) = 1
        THEN 'Contains point'
        ELSE 'Does not contain point'
    END AS ContainsPoint
FROM HR.Locations;

-- 4. STBuffer - Create 1km buffer around offices
SELECT 
    LocationName,
    GeoLocation.STBuffer(1000) AS BufferZone
FROM HR.Locations;

-- 5. STArea - Calculate office boundary areas
SELECT 
    LocationName,
    Boundary.STArea() AS AreaSquareUnits
FROM HR.Locations;

-- 6. STLength - Calculate boundary perimeter
SELECT 
    LocationName,
    Boundary.STLength() AS PerimeterLength
FROM HR.Locations;

-- 7. STPointN - Get corner points of office boundaries
SELECT 
    LocationName,
    Boundary.STBoundary().STPointN(1) AS FirstCorner,
    Boundary.STBoundary().STPointN(2) AS SecondCorner
FROM HR.Locations;

-- 8. STSrid - Check spatial reference IDs
SELECT 
    LocationName,
    GeoLocation.STSrid AS GeographySRID,
    Boundary.STSrid AS GeometrySRID
FROM HR.Locations;

-- 9. STAsText - Convert locations to WKT format
SELECT 
    LocationName,
    GeoLocation.STAsText() AS WKTLocation,
    Boundary.STAsText() AS WKTBoundary
FROM HR.Locations;

-- 10. Complex spatial analysis example
DECLARE @OfficePoint geometry = geometry::STGeomFromText('POINT(-74.005974 40.712776)', 0);
DECLARE @SearchRadius float = 5.0; -- 5 kilometer radius

SELECT 
    e.EmployeeID,
    l.LocationName,
    e.WorkLocation.STDistance(e.HomeLocation) / 1000.0 AS CommuteDistanceKM,
    l.Boundary.STArea() AS OfficeBoundaryArea,
    CASE 
        WHEN e.WorkLocation.STDistance(l.GeoLocation) / 1000.0 <= @SearchRadius
        THEN 'Within ' + CAST(@SearchRadius AS VARCHAR) + 'km'
        ELSE 'Outside ' + CAST(@SearchRadius AS VARCHAR) + 'km'
    END AS DistanceFromMainOffice
FROM HR.EmployeeLocations e
CROSS JOIN HR.Locations l
WHERE e.WorkLocation.STSrid = l.GeoLocation.STSrid
ORDER BY CommuteDistanceKM;

-- Create a view for location analytics
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[HR].[LocationAnalytics]'))
BEGIN
    EXECUTE sp_executesql N'
    CREATE VIEW HR.LocationAnalytics
    AS
    SELECT 
        l.LocationName,
        l.City,
        COUNT(e.EmployeeID) AS EmployeeCount,
        AVG(e.WorkLocation.STDistance(e.HomeLocation) / 1000.0) AS AvgCommuteDistanceKM,
        MAX(e.WorkLocation.STDistance(e.HomeLocation) / 1000.0) AS MaxCommuteDistanceKM,
        l.Boundary.STArea() AS OfficeBoundaryArea
    FROM HR.Locations l
    LEFT JOIN HR.EmployeeLocations e ON e.WorkLocation.STEquals(l.GeoLocation) = 1
    GROUP BY l.LocationName, l.City, l.Boundary.STArea();
    ';
END

-- Query the analytics view
SELECT 
    LocationName,
    City,
    EmployeeCount,
    ROUND(AvgCommuteDistanceKM, 2) AS AvgCommuteKM,
    ROUND(MaxCommuteDistanceKM, 2) AS MaxCommuteKM,
    ROUND(OfficeBoundaryArea, 2) AS BoundaryArea
FROM HR.LocationAnalytics
ORDER BY EmployeeCount DESC;