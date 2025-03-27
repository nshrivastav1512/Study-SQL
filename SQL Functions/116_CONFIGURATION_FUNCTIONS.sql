/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\116_CONFIGURATION_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Configuration Functions
    using the HRSystem database. These functions provide information about
    system settings, server status, and session configurations.

    Configuration Functions covered:
    1. @@LOCK_TIMEOUT - Returns current lock timeout setting
    2. @@MAX_CONNECTIONS - Maximum allowed connections
    3. @@SPID - Current session ID
    4. @@TEXTSIZE - Current text size setting
    5. @@SERVERNAME - Name of the current server
    6. @@LANGUAGE - Current language setting
    7. @@TOTAL_ERRORS - Number of disk read/write errors
    8. @@PACK_RECEIVED - Number of input packets
    9. @@CPU_BUSY - CPU busy time
    10. @@IDLE - CPU idle time
    11. @@TIMETICKS - Number of microseconds per tick
*/

USE HRSystem;
GO

-- Create a logging table for configuration checks
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ConfigurationLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.ConfigurationLog (
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        CheckTime DATETIME2 DEFAULT SYSDATETIME(),
        ConfigName NVARCHAR(50),
        ConfigValue NVARCHAR(MAX),
        SessionID INT,
        Description NVARCHAR(255)
    );
END

-- 1. Lock Timeout Configuration
-- Set lock timeout to 5000 milliseconds (5 seconds)
SET LOCK_TIMEOUT 5000;

-- Log current lock timeout setting
INSERT INTO dbo.ConfigurationLog (ConfigName, ConfigValue, SessionID, Description)
VALUES (
    'LOCK_TIMEOUT',
    CAST(@@LOCK_TIMEOUT AS NVARCHAR(20)),
    @@SPID,
    'Current lock timeout setting in milliseconds'
);

-- 2. Maximum Connections
INSERT INTO dbo.ConfigurationLog (ConfigName, ConfigValue, SessionID, Description)
VALUES (
    'MAX_CONNECTIONS',
    CAST(@@MAX_CONNECTIONS AS NVARCHAR(20)),
    @@SPID,
    'Maximum number of simultaneous user connections allowed'
);

-- 3. Current Session ID
INSERT INTO dbo.ConfigurationLog (ConfigName, ConfigValue, SessionID, Description)
VALUES (
    'SPID',
    CAST(@@SPID AS NVARCHAR(20)),
    @@SPID,
    'Current session ID'
);

-- 4. Text Size Setting
-- Set text size to 2048 bytes
SET TEXTSIZE 2048;

INSERT INTO dbo.ConfigurationLog (ConfigName, ConfigValue, SessionID, Description)
VALUES (
    'TEXTSIZE',
    CAST(@@TEXTSIZE AS NVARCHAR(20)),
    @@SPID,
    'Current text size setting in bytes'
);

-- 5. Server Name
INSERT INTO dbo.ConfigurationLog (ConfigName, ConfigValue, SessionID, Description)
VALUES (
    'SERVERNAME',
    @@SERVERNAME,
    @@SPID,
    'Current SQL Server instance name'
);

-- 6. Language Setting
INSERT INTO dbo.ConfigurationLog (ConfigName, ConfigValue, SessionID, Description)
VALUES (
    'LANGUAGE',
    @@LANGUAGE,
    @@SPID,
    'Current language setting'
);

-- 7. Total Errors
INSERT INTO dbo.ConfigurationLog (ConfigName, ConfigValue, SessionID, Description)
VALUES (
    'TOTAL_ERRORS',
    CAST(@@TOTAL_ERRORS AS NVARCHAR(20)),
    @@SPID,
    'Number of disk read/write errors encountered'
);

-- 8. Packets Received
INSERT INTO dbo.ConfigurationLog (ConfigName, ConfigValue, SessionID, Description)
VALUES (
    'PACK_RECEIVED',
    CAST(@@PACK_RECEIVED AS NVARCHAR(20)),
    @@SPID,
    'Number of input packets read from network'
);

-- 9. CPU Busy Time
INSERT INTO dbo.ConfigurationLog (ConfigName, ConfigValue, SessionID, Description)
VALUES (
    'CPU_BUSY',
    CAST(@@CPU_BUSY AS NVARCHAR(20)),
    @@SPID,
    'Time CPU has spent executing code'
);

-- 10. CPU Idle Time
INSERT INTO dbo.ConfigurationLog (ConfigName, ConfigValue, SessionID, Description)
VALUES (
    'IDLE',
    CAST(@@IDLE AS NVARCHAR(20)),
    @@SPID,
    'Time CPU has been idle'
);

-- 11. Time Ticks
INSERT INTO dbo.ConfigurationLog (ConfigName, ConfigValue, SessionID, Description)
VALUES (
    'TIMETICKS',
    CAST(@@TIMETICKS AS NVARCHAR(20)),
    @@SPID,
    'Number of microseconds per tick'
);

-- Create a view to analyze configuration history
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[ConfigurationHistory]'))
BEGIN
    EXECUTE sp_executesql N'
    CREATE VIEW dbo.ConfigurationHistory
    AS
    SELECT 
        ConfigName,
        ConfigValue,
        SessionID,
        Description,
        CheckTime,
        LEAD(CheckTime) OVER (PARTITION BY ConfigName ORDER BY CheckTime) AS NextCheckTime,
        LEAD(ConfigValue) OVER (PARTITION BY ConfigName ORDER BY CheckTime) AS NextConfigValue,
        CASE 
            WHEN LEAD(ConfigValue) OVER (PARTITION BY ConfigName ORDER BY CheckTime) <> ConfigValue 
            THEN 1 ELSE 0 
        END AS ValueChanged
    FROM dbo.ConfigurationLog;
    ';
END

-- Example query to view configuration changes
SELECT 
    ConfigName,
    ConfigValue,
    Description,
    CheckTime,
    CASE ValueChanged 
        WHEN 1 THEN 'Changed'
        ELSE 'Unchanged'
    END AS Status
FROM dbo.ConfigurationHistory
WHERE CheckTime >= DATEADD(HOUR, -1, SYSDATETIME())
ORDER BY CheckTime DESC;

-- Example of using configuration values in a procedure
IF NOT EXISTS (SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[GetServerStatus]'))
BEGIN
    EXECUTE sp_executesql N'
    CREATE PROCEDURE dbo.GetServerStatus
    AS
    BEGIN
        SET NOCOUNT ON;
        
        SELECT
            @@SERVERNAME AS ServerName,
            @@VERSION AS ServerVersion,
            @@LANGUAGE AS CurrentLanguage,
            @@MAX_CONNECTIONS AS MaxConnections,
            @@CPU_BUSY AS CPUBusyTime,
            @@IDLE AS CPUIdleTime,
            @@TOTAL_ERRORS AS TotalErrors,
            @@PACK_RECEIVED AS PacketsReceived,
            SYSDATETIME() AS CheckTime;
    END;
    ';
END

-- Execute the procedure to get current server status
EXECUTE dbo.GetServerStatus;

-- Cleanup (optional)
-- SET LOCK_TIMEOUT -1; -- Reset to default (wait indefinitely)
-- SET TEXTSIZE 0; -- Reset to default