-- =============================================
-- SQL Server Linked Servers Configuration and Management
-- =============================================

/*
This script demonstrates SQL Server Linked Servers configuration for HR system integration:
- Creating and managing linked servers
- Configuring security and authentication
- Setting up distributed queries
- Managing linked server performance
*/

USE HRSystem;
GO

-- =============================================
-- PART 1: CREATING LINKED SERVERS
-- =============================================

-- 1. Create Linked Server to External HR System
EXEC sp_addlinkedserver
    @server = 'EXTERNAL_HR_SYSTEM',
    @srvproduct = 'SQL Server',
    @provider = 'SQLNCLI', -- SQL Native Client
    @datasrc = 'EXTERNAL_SERVER_NAME';

-- 2. Create Linked Server to HR Document Server
EXEC sp_addlinkedserver
    @server = 'HR_DOCUMENT_SERVER',
    @srvproduct = '',
    @provider = 'Microsoft.ACE.OLEDB.12.0',
    @datasrc = '\\FileServer\HRDocuments\EmployeeFiles.accdb';

-- =============================================
-- PART 2: CONFIGURING SECURITY
-- =============================================

-- 1. Configure Linked Server Security
EXEC sp_addlinkedsrvlogin
    @rmtsrvname = 'EXTERNAL_HR_SYSTEM',
    @useself = 'FALSE',
    @locallogin = NULL,
    @rmtuser = 'HR_Reader',
    @rmtpassword = '********'; -- Replace with actual password

-- 2. Set Up Security Context
EXEC sp_serveroption
    @server = 'EXTERNAL_HR_SYSTEM',
    @optname = 'rpc out',
    @optvalue = 'true';

-- =============================================
-- PART 3: DISTRIBUTED QUERIES
-- =============================================

-- 1. Query External Employee Data
/*
SELECT 
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    ext.DepartmentName,
    ext.Position
FROM HRSystem.dbo.Employees e
JOIN EXTERNAL_HR_SYSTEM.HRData.dbo.EmployeeDetails ext
    ON e.EmployeeID = ext.EmployeeID;
*/

-- 2. Insert Data Through Linked Server
/*
INSERT INTO EXTERNAL_HR_SYSTEM.HRData.dbo.EmployeeLog
    (EmployeeID, ActionType, ActionDate, Description)
VALUES
    (1001, 'UPDATE', GETDATE(), 'Employee information updated');
*/

-- =============================================
-- PART 4: PERFORMANCE OPTIMIZATION
-- =============================================

-- 1. Configure Query Options
EXEC sp_serveroption
    @server = 'EXTERNAL_HR_SYSTEM',
    @optname = 'collation compatible',
    @optvalue = 'true';

EXEC sp_serveroption
    @server = 'EXTERNAL_HR_SYSTEM',
    @optname = 'lazy schema validation',
    @optvalue = 'true';

-- 2. Set Connection Options
EXEC sp_serveroption
    @server = 'EXTERNAL_HR_SYSTEM',
    @optname = 'connect timeout',
    @optvalue = '10';

-- =============================================
-- PART 5: MAINTENANCE AND MONITORING
-- =============================================

-- 1. View Linked Server Configuration
SELECT *
FROM sys.servers
WHERE is_linked = 1;

-- 2. Check Linked Server Status
SELECT 
    name,
    product,
    provider,
    data_source,
    is_linked,
    is_remote_login_enabled,
    is_rpc_out_enabled,
    is_data_access_enabled
FROM sys.servers
WHERE is_linked = 1;

-- 3. Monitor Linked Server Performance
SELECT *
FROM sys.dm_exec_connections
WHERE parent_connection_id IS NOT NULL;

-- =============================================
-- PART 6: BEST PRACTICES
-- =============================================

/*
1. Security Best Practices:
   - Use Windows Authentication when possible
   - Implement least-privilege access
   - Regularly rotate credentials
   - Encrypt connection strings

2. Performance Best Practices:
   - Minimize data transfer across servers
   - Use appropriate indexes
   - Implement error handling
   - Monitor query performance

3. Maintenance Best Practices:
   - Regular connectivity testing
   - Monitor resource usage
   - Document server dependencies
   - Keep provider versions updated
*/

-- =============================================
-- PART 7: TROUBLESHOOTING
-- =============================================

-- 1. Test Linked Server Connection
EXEC sp_testlinkedserver 'EXTERNAL_HR_SYSTEM';

-- 2. View Linked Server Errors
SELECT *
FROM sys.dm_exec_connections
WHERE parent_connection_id IS NOT NULL
    AND last_read < DATEADD(minute, -5, GETDATE());

-- 3. Check Provider Information
SELECT 
    name,
    product,
    provider,
    data_source,
    provider_string
FROM sys.servers
WHERE is_linked = 1;