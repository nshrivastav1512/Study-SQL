# SQL Deep Dive: Querying User and Login Information

## 1. Introduction: Monitoring Security Principals

Managing SQL Server security involves not only creating logins and users but also monitoring their configuration, permissions, and activity. SQL Server provides a rich set of system catalog views and Dynamic Management Views (DMVs) specifically for this purpose. These allow administrators to query metadata and real-time state information related to security principals.

**Why Query User Information?**

*   **Security Auditing:** Verify permissions, role memberships, and configurations align with security policies.
*   **Troubleshooting:** Identify login issues, permission problems, or orphaned users.
*   **Monitoring:** Track user activity, connection times, and object ownership.
*   **Administration:** List users, logins, roles, and their properties for management tasks.

**Key System Views/DMVs:**

*   `sys.database_principals`: Information about principals (users, roles, application roles) *within* a specific database.
*   `sys.server_principals`: Information about principals (logins, server roles) at the *server instance* level.
*   `sys.database_role_members`: Shows the membership links between database users and database roles.
*   `sys.server_role_members`: Shows the membership links between logins and server roles.
*   `sys.database_permissions`: Details permissions granted or denied to database principals on securables within the database.
*   `sys.server_permissions`: Details permissions granted or denied to server principals at the server level.
*   `sys.objects`: Information about objects (tables, views, procedures, etc.) within a database, including owner (`principal_id`).
*   `sys.dm_exec_sessions`: Information about currently active authenticated sessions on the server instance.
*   `sys.dm_exec_connections`: Information about physical connections associated with sessions.

## 2. Querying Security Information in Action: Analysis of `17_users_view.sql`

This script provides examples of querying various system views and DMVs to gather user-related information.

**a) View All Database Users (and Roles)**

```sql
USE HRSystem; -- Context of the specific database
GO
SELECT name, type_desc, create_date
FROM sys.database_principals
WHERE type IN ('S', 'U', 'G'); -- S=SQL User, U=Windows User, G=Windows Group
```

*   **Explanation:** Queries `sys.database_principals` within the `HRSystem` database to list SQL users, Windows users, and Windows groups that have been granted access to this specific database.

**b) View Server Logins**

```sql
-- No USE statement needed, or USE master
SELECT name, type_desc, create_date, is_disabled
FROM sys.server_principals
WHERE type IN ('S', 'U', 'G'); -- S=SQL Login, U=Windows Login, G=Windows Group Login
```

*   **Explanation:** Queries the server-level `sys.server_principals` view to list all SQL logins, Windows logins, and Windows group logins defined on the SQL Server instance. It also shows if a login is disabled.

**c) View User-Role Memberships**

```sql
USE HRSystem;
GO
SELECT DP1.name AS DatabaseUserName, DP2.name AS RoleName
FROM sys.database_role_members AS DRM
JOIN sys.database_principals AS DP1 ON DRM.member_principal_id = DP1.principal_id
JOIN sys.database_principals AS DP2 ON DRM.role_principal_id = DP2.principal_id;
```

*   **Explanation:** Joins `sys.database_role_members` with `sys.database_principals` (twice) to show which database users (`DP1`) are members of which database roles (`DP2`) within the current database.

**d) View User Permissions**

```sql
USE HRSystem;
GO
SELECT
    CASE WHEN DP.name IS NULL THEN '...' ELSE DP.name END AS UserName,
    CASE WHEN PE.permission_name IS NULL THEN '...' ELSE PE.permission_name END AS PermissionName,
    CASE WHEN OB.name IS NULL THEN '...' ELSE OB.name END AS ObjectName
FROM sys.database_principals AS DP
LEFT JOIN sys.database_permissions AS PE ON DP.principal_id = PE.grantee_principal_id
LEFT JOIN sys.objects AS OB ON PE.major_id = OB.object_id
WHERE DP.type IN ('S', 'U', 'G');
```

*   **Explanation:** A more complex query attempting to list users and their explicit permissions on objects within the database. It joins `sys.database_principals` (users/roles), `sys.database_permissions` (the permissions granted), and `sys.objects` (the object the permission applies to). `LEFT JOIN`s are used because a user might exist without specific object permissions being listed directly this way (they might inherit via roles). *Note: This query might not show all effective permissions, as role inheritance and schema-level or database-level permissions add complexity.*

**e) View Orphaned Users**

```sql
USE HRSystem;
GO
SELECT name AS OrphanedUser
FROM sys.database_principals
WHERE type IN ('S', 'U', 'G') -- SQL/Windows Users/Groups
  AND authentication_type_desc = 'INSTANCE' -- Mapped to a server login (not contained/no login)
  AND NOT EXISTS ( -- Check if the corresponding server principal (login) exists
      SELECT 1 FROM sys.server_principals AS SP
      WHERE SP.sid = sys.database_principals.sid
  );
```

*   **Explanation:** Identifies database users (`type` S, U, G) that are supposed to be mapped to a server login (`authentication_type_desc = 'INSTANCE'`) but where no corresponding login exists on the current server instance with the same Security Identifier (SID). This uses a `NOT EXISTS` subquery comparing SIDs between `sys.database_principals` (database level) and `sys.server_principals` (server level).

**f) View User Default Schemas**

```sql
USE HRSystem;
GO
SELECT name AS UserName, default_schema_name AS DefaultSchema
FROM sys.database_principals
WHERE type IN ('S', 'U', 'G') AND default_schema_name IS NOT NULL;
```

*   **Explanation:** Lists database users and their assigned default schema, if one has been explicitly set.

**g) View Database Access (from Server Level)**

```sql
-- No USE needed, or USE master
SELECT
    SP.name AS LoginName, SP.type_desc AS LoginType,
    CASE WHEN DP.name IS NULL THEN 'No database access' ELSE 'Has database access' END AS DatabaseAccess
FROM sys.server_principals AS SP
LEFT JOIN sys.database_principals AS DP ON SP.sid = DP.sid AND DB_ID('HRSystem') = DB_ID() -- Join on SID within target DB context (implicitly HRSystem here)
WHERE SP.type IN ('S', 'U', 'G');
-- Note: This query needs refinement to accurately check access *specifically* for HRSystem if run from master. A better approach might query sys.databases and cross-apply.
-- A simpler check from within HRSystem is just querying sys.database_principals.
```

*   **Explanation:** Attempts to list server logins and indicate if they have *any* corresponding user in the *current* database (`HRSystem` because of the `USE` statement). It joins server principals and database principals on their SID. *Correction:* The original query logic might be slightly flawed if run outside the target database context. A more robust check often involves querying `sys.databases` and checking user existence within each. However, the intent is to link logins to database access.

**h) View Last Login Times (DMV)**

```sql
-- No USE needed
SELECT login_name, MAX(login_time) AS LastLoginTime
FROM sys.dm_exec_sessions -- DMV showing active sessions
GROUP BY login_name;
```

*   **Explanation:** Queries the Dynamic Management View `sys.dm_exec_sessions` to find the most recent login time for each distinct `login_name` *currently connected* to the instance. Note that this DMV only shows *active* sessions; it doesn't provide a historical record of all past logins unless login auditing is specifically enabled elsewhere.

**i) View User-Created Objects**

```sql
USE HRSystem;
GO
SELECT DP.name AS UserName, OB.name AS ObjectName, OB.type_desc AS ObjectType, OB.create_date
FROM sys.objects AS OB
JOIN sys.database_principals AS DP ON OB.principal_id = DP.principal_id -- Check object owner
WHERE DP.type IN ('S', 'U', 'G');
```

*   **Explanation:** Lists objects within the database and attempts to identify the user principal that *owns* the object (based on `principal_id` in `sys.objects`). Note that objects are often owned by the *schema* rather than the user directly, so `OB.principal_id` might be NULL or point to the schema owner if the user created the object within a schema they don't own directly.

**j) View Connection Information (DMV)**

```sql
-- No USE needed
SELECT login_name, COUNT(*) AS ConnectionCount, MIN(login_time) AS OldestConnection, MAX(login_time) AS NewestConnection
FROM sys.dm_exec_sessions
WHERE login_name IS NOT NULL -- Filter out system sessions
GROUP BY login_name;
```

*   **Explanation:** Queries `sys.dm_exec_sessions` again, this time grouping by `login_name` to show the number of currently active sessions for each login, along with the time of their oldest and newest current connections.

## 3. Targeted Interview Questions (Based on `17_users_view.sql`)

**Question 1:** Which system view would you query to find out which database roles the user `JohnDoe` belongs to within the `HRSystem` database? Briefly describe the join conditions needed.

**Solution 1:** You would primarily query `sys.database_role_members`.
*   You need to join `sys.database_role_members` with `sys.database_principals` twice:
    1.  Join `sys.database_role_members.member_principal_id` to `sys.database_principals.principal_id` to get the member's name (filtering `WHERE name = 'JohnDoe'`).
    2.  Join `sys.database_role_members.role_principal_id` to `sys.database_principals.principal_id` to get the name of the role the user is a member of.

**Question 2:** The script uses `sys.dm_exec_sessions` to find the `LastLoginTime`. What is a limitation of using this DMV for tracking login history?

**Solution 2:** The main limitation is that `sys.dm_exec_sessions` only shows information about **currently active sessions**. It does not store historical login data. Once a session disconnects, its record is removed from this DMV. Therefore, `MAX(login_time)` only shows the last login time *among the sessions that are still connected*, not the overall last time a user ever logged in. For historical login tracking, you would need to enable SQL Server Audit or use Extended Events.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Where would you look to find the definition of server-level logins: `sys.database_principals` or `sys.server_principals`?
    *   **Answer:** `sys.server_principals` (typically queried within the `master` database context).
2.  **[Easy]** What does the `type` column signify in `sys.database_principals` and `sys.server_principals` (e.g., 'S', 'U', 'G', 'R')?
    *   **Answer:** It indicates the type of principal: 'S' = SQL Login/User, 'U' = Windows Login/User, 'G' = Windows Group Login/User, 'R' = Role (Database or Server Role).
3.  **[Medium]** How can you identify an orphaned user by querying system views? What two views are typically compared?
    *   **Answer:** You compare `sys.database_principals` (in the specific database) with `sys.server_principals` (in `master`). An orphaned user exists in `sys.database_principals` with an `authentication_type` indicating instance-level authentication, but there is no matching row in `sys.server_principals` based on the SID (Security Identifier).
4.  **[Medium]** If a user is a member of a Windows Group (e.g., `DOMAIN\HRGroup`), and that group has a login and a user in the database, will querying `sys.database_role_members` show the individual user as a member of roles granted to the group user?
    *   **Answer:** No. `sys.database_role_members` only shows direct membership. It would show the *group user* (`DOMAIN\HRGroup`) as a member of any database roles it was added to. It does not expand the Windows group membership within SQL Server views. SQL Server checks Windows group membership during authentication/authorization checks.
5.  **[Medium]** Can the `principal_id` column in `sys.objects` be NULL? If so, what does it typically signify about the object's owner?
    *   **Answer:** Yes, `principal_id` in `sys.objects` can be NULL. This usually signifies that the object is owned by the **schema** itself, rather than a specific user principal. The permissions are then typically managed at the schema level or via explicit grants.
6.  **[Medium]** What permission is generally required to query most Dynamic Management Views (DMVs) like `sys.dm_exec_sessions`?
    *   **Answer:** `VIEW SERVER STATE`. Granting this server-level permission allows a login to query most DMVs and Dynamic Management Functions (DMFs). Some specific DMVs might require additional permissions like `VIEW DATABASE STATE`.
7.  **[Hard]** How could you find all *explicit* permissions granted directly to a specific database user (`SpecificUser`) on a specific table (`hr.Employees`)?
    *   **Answer:** You would query `sys.database_permissions` and join it with `sys.database_principals` (to filter by user name) and `sys.objects` (to filter by object name and schema).
        ```sql
        SELECT perm.permission_name, perm.state_desc -- GRANT, DENY, etc.
        FROM sys.database_permissions AS perm
        JOIN sys.database_principals AS grantee ON perm.grantee_principal_id = grantee.principal_id
        JOIN sys.objects AS obj ON perm.major_id = obj.object_id
        JOIN sys.schemas AS sch ON obj.schema_id = sch.schema_id
        WHERE grantee.name = 'SpecificUser'
          AND perm.class_desc = 'OBJECT_OR_COLUMN'
          AND sch.name = 'hr'
          AND obj.name = 'Employees';
        ```
8.  **[Hard]** If you want to see the *effective* permissions for a user (including permissions inherited from roles and Windows groups), are the system catalog views like `sys.database_permissions` sufficient on their own? What function might be helpful?
    *   **Answer:** No, the catalog views generally show only *explicitly* granted/denied permissions. They don't automatically resolve the complex inheritance from multiple roles or nested Windows groups. The built-in function `sys.fn_my_permissions(securable, 'securable_class')` is helpful. It returns a list of effective permissions the *current user* has on a specified securable (like a table or database). To check for *another* user, you might need to use `EXECUTE AS USER = 'OtherUser'` before calling the function (requires `IMPERSONATE` permission).
9.  **[Hard]** How does the information in `sys.dm_exec_sessions` relate to `sys.dm_exec_connections`? Can one session have multiple connections?
    *   **Answer:** `sys.dm_exec_sessions` represents logical user sessions authenticated to the SQL Server instance. `sys.dm_exec_connections` represents the physical network connections (like TCP/IP) to the server. Typically, a single session uses a single physical connection. However, with Multiple Active Result Sets (MARS) enabled, a single session *can* have multiple logical requests active concurrently, potentially utilizing more than one connection implicitly or explicitly under the covers, although it still appears as one `session_id`. So, while usually 1:1, the relationship isn't strictly guaranteed to be one connection per session in all scenarios, especially with MARS. Each row in `sys.dm_exec_connections` links back to a `session_id`.
10. **[Hard/Tricky]** You query `sys.server_principals` and find a login named `##MS_PolicyEventProcessingLogin##`. What is the likely nature of this login, and should you typically interact with it directly?
    *   **Answer:** Logins enclosed in double hash marks (`##...##`) are typically internal, system-generated certificate-based logins used for specific SQL Server features. `##MS_PolicyEventProcessingLogin##` is associated with Policy-Based Management, used internally for processing policy evaluation events. You should **not** typically interact with these logins directly (e.g., drop them, change their passwords, or grant/revoke permissions) as doing so can break the corresponding SQL Server feature. They are managed internally by SQL Server.
