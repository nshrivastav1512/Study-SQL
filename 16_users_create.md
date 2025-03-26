# SQL Deep Dive: Creating Logins and Users

## 1. Introduction: Logins vs. Users

Understanding SQL Server security starts with differentiating between **Logins** and **Users**:

*   **Login:** A *server-level* principal. It grants access to the SQL Server *instance*. Logins authenticate users trying to connect to the server. They can be based on Windows authentication (using Windows accounts/groups) or SQL Server authentication (using a username and password managed by SQL Server).
*   **User:** A *database-level* principal. It grants access to a *specific database*. A database user must typically be mapped to a server login (except for contained database users or users without login). Permissions to access objects *within* a database (like tables, views, procedures) are granted to database users or roles they belong to.

Think of it like this:
1.  The **Login** gets you through the main gate of the SQL Server instance.
2.  The **User** (mapped to your login) gets you into a specific building (database) inside the instance.
3.  **Permissions** granted to the User (or its roles) determine which rooms (tables, procedures) you can access inside that building.

## 2. Creating Logins and Users in Action: Analysis of `16_users_create.sql`

This script demonstrates creating various types of logins and users.

**a) Create SQL Server Authentication Login**

```sql
USE master; -- Logins are server-level objects, created in master
GO
CREATE LOGIN JohnDoe
WITH PASSWORD = 'StrongPass123!';
```

*   **Explanation:** Creates a login named `JohnDoe` that authenticates using a password managed by SQL Server.
*   **Considerations:** Requires specifying a password. Subject to SQL Server password policies (complexity, expiration) unless `CHECK_POLICY = OFF` is used (generally not recommended for user accounts).

**b) Create Windows Authentication Login**

```sql
USE master;
GO
CREATE LOGIN [DOMAIN\JaneSmith] -- Use square brackets if name contains special chars like '\'
FROM WINDOWS;
```

*   **Explanation:** Creates a login based on an existing Windows domain user (`DOMAIN\JaneSmith`) or group. Authentication is handled by Windows; SQL Server trusts the Windows authentication token. No password is stored in SQL Server. This is generally considered more secure than SQL authentication.

**c) Create Database User from SQL Login**

```sql
USE HRSystem; -- Switch to the specific database
GO
CREATE USER JohnDoe -- Database user name (often matches login name)
FOR LOGIN JohnDoe; -- Map to the existing server login
```

*   **Explanation:** Creates a user named `JohnDoe` *within the `HRSystem` database* and links it to the server login `JohnDoe` created earlier. Now, when the `JohnDoe` login connects and accesses the `HRSystem` database, it acts as the `JohnDoe` database user.

**d) Create Database User from Windows Login**

```sql
USE HRSystem;
GO
CREATE USER [DOMAIN\JaneSmith]
FOR LOGIN [DOMAIN\JaneSmith];
```

*   **Explanation:** Creates a user within `HRSystem` mapped to the `[DOMAIN\JaneSmith]` Windows login.

**e) Create User Without Login (Contained Database User)**

```sql
-- Assumes HRSystem is configured as a contained database
-- ALTER DATABASE HRSystem SET CONTAINMENT = PARTIAL; (If not already set)
USE HRSystem;
GO
CREATE USER ContainedUser
WITH PASSWORD = 'Pass123!';
```

*   **Explanation:** Creates a database user *directly within the database* with its own password. This user does **not** require a corresponding server-level login. Authentication occurs at the database level.
*   **Requirement:** The database must be configured for containment (`CONTAINMENT = PARTIAL` or `FULL`). Useful for database portability, as users move with the database.

**f) Create User Mapped to Certificate**

```sql
USE master; -- Certificates often created in master or database depending on scope
GO
CREATE CERTIFICATE HRCertificate WITH SUBJECT = 'HR Department Certificate';
GO
USE HRSystem;
GO
CREATE USER CertUser
FOR CERTIFICATE HRCertificate;
```

*   **Explanation:** Creates a database user associated with a digital certificate created within SQL Server. Authentication can be achieved using this certificate, often used for code signing (e.g., granting permissions to signed procedures) or specific application authentication scenarios, rather than direct user login.

**g) Create Application Role**

```sql
USE HRSystem;
GO
CREATE APPLICATION ROLE HRApp
WITH PASSWORD = 'AppPass123!';
```

*   **Explanation:** Creates a special type of database role intended for applications. Applications can activate this role using `sp_setapprole` (providing the password). Once activated, the application gains the permissions granted *to the application role*, rather than the permissions of the user/login the application connected with. This allows granting permissions specifically for application contexts. It's not a user itself.

**h) Create User with Default Schema**

```sql
USE HRSystem;
GO
CREATE USER SchemaUser
FOR LOGIN JohnDoe -- Assuming JohnDoe login exists
WITH DEFAULT_SCHEMA = HR; -- Specify the default schema
```

*   **Explanation:** Creates a database user and specifies their default schema. When this user references objects without explicitly specifying a schema (e.g., `SELECT * FROM Employee_Details`), SQL Server will first look for the object in the user's default schema (`HR` in this case) before looking in the `dbo` schema.

**i) Create Group User (Database Role and Membership)**

```sql
USE HRSystem;
GO
CREATE ROLE HRStaff; -- Create a database role (group)
-- Assume NewHRLogin exists at server level
CREATE USER NewHRUser FOR LOGIN NewHRLogin; -- Create the user in the database
ALTER ROLE HRStaff ADD MEMBER NewHRUser; -- Add the user to the role
```

*   **Explanation:** Demonstrates role-based security.
    1.  `CREATE ROLE`: Creates a database role (like a group).
    2.  `CREATE USER`: Creates the individual database user.
    3.  `ALTER ROLE ... ADD MEMBER ...`: Adds the user to the role. Permissions can then be granted to the `HRStaff` role, and `NewHRUser` (and any other members) will inherit those permissions. This simplifies permission management.

**j) Create Service Account User**

```sql
USE master;
GO
-- Create login, potentially disabling policy checks if it's a service account password
CREATE LOGIN ServiceAccount WITH PASSWORD = 'Service123!', CHECK_POLICY = OFF;
GO
USE HRSystem;
GO
CREATE USER ServiceUser FOR LOGIN ServiceAccount;
-- Grant minimal necessary permissions to ServiceUser or roles it belongs to
```

*   **Explanation:** Shows creating a SQL login (often used for service accounts where Windows authentication isn't feasible) and its corresponding database user. `CHECK_POLICY = OFF` bypasses Windows password policy checks for this SQL login (use cautiously). The key principle for service accounts is to grant only the *minimal permissions* required for the service to function (Principle of Least Privilege).

## 3. Targeted Interview Questions (Based on `16_users_create.sql`)

**Question 1:** What is the difference between the principal created by `CREATE LOGIN JohnDoe WITH PASSWORD = ...;` and the principal created by `CREATE USER JohnDoe FOR LOGIN JohnDoe;`? Where does each principal "live"?

**Solution 1:**

*   `CREATE LOGIN JohnDoe WITH PASSWORD = ...;`: Creates a **Login**. This is a **server-level** principal used for authenticating connections to the SQL Server *instance*. It lives in the `master` database metadata.
*   `CREATE USER JohnDoe FOR LOGIN JohnDoe;`: Creates a **User**. This is a **database-level** principal used for authorization *within* a specific database (e.g., `HRSystem`). It lives in the target database's metadata and is mapped to the server-level login. Permissions on database objects are granted to the User, not the Login.

**Question 2:** Section 5 creates a "User Without Login". What is required for this type of user to function, and what is a primary benefit of using them?

**Solution 2:**

*   **Requirement:** The database must be configured as a **contained database** (`ALTER DATABASE dbName SET CONTAINMENT = PARTIAL;`).
*   **Benefit:** The primary benefit is **database portability**. Since the user definition and authentication information (password hash) are stored entirely *within* the database itself, the database can be moved (backed up and restored) to another SQL Server instance without needing to recreate corresponding server-level logins on the new instance. The contained user can authenticate directly to the database.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can two different Logins be mapped to the same database User name in a specific database?
    *   **Answer:** No. A database user name must be unique within that database. While you could potentially map LoginA to UserA and LoginB to UserB, you cannot map both LoginA and LoginB to the *same* UserA principal.
2.  **[Easy]** Can a single Login be mapped to different User names in different databases?
    *   **Answer:** Yes. A server-level Login (e.g., `MyLogin`) can be mapped to `UserX` in `Database1` and `UserY` in `Database2`. The user principal is specific to each database.
3.  **[Medium]** What happens if you try to create a database user `FOR LOGIN MyLogin` but the server login `MyLogin` does not exist?
    *   **Answer:** The `CREATE USER` statement will fail with an error indicating that the specified login does not exist or you do not have permission to use it.
4.  **[Medium]** What is the purpose of assigning a `DEFAULT_SCHEMA` to a database user?
    *   **Answer:** It specifies the schema that SQL Server will search first when the user references an object (like a table or procedure) without explicitly qualifying it with a schema name. If the object isn't found in the default schema, SQL Server then typically searches the `dbo` schema. It simplifies object referencing for users who primarily work within a specific schema.
5.  **[Medium]** Besides `ADD MEMBER`, what other command is used with `ALTER ROLE` to manage role membership?
    *   **Answer:** `ALTER ROLE role_name DROP MEMBER user_name;` is used to remove a user from a database role.
6.  **[Medium]** What is the difference between a server role (like `sysadmin`, `serveradmin`) and a database role (like `db_owner`, `db_datareader`, or custom roles like `HRStaff`)?
    *   **Answer:**
        *   **Server Roles:** Fixed roles defined at the *server level*. They grant permissions related to managing the SQL Server instance itself (e.g., creating databases, managing logins, server configuration). Logins are added as members to server roles.
        *   **Database Roles:** Roles defined *within a specific database*. They grant permissions on objects and actions *within that database* (e.g., selecting from tables, executing procedures). Database users are added as members to database roles.
7.  **[Hard]** Can a Windows Group login (e.g., `CREATE LOGIN [DOMAIN\HRGroup] FROM WINDOWS;`) be added directly as a member to a database role?
    *   **Answer:** No. You cannot add a *login* (Windows or SQL) directly to a *database* role. You must first create a database *user* mapped to that Windows group login (`CREATE USER [DOMAIN\HRGroup] FOR LOGIN [DOMAIN\HRGroup];`), and then add that database *user* to the database role (`ALTER ROLE db_datareader ADD MEMBER [DOMAIN\HRGroup];`). Permissions are inherited through the group membership at the Windows level, recognized via the mapped database user.
8.  **[Hard]** What security principal actually owns database objects (like tables, views) by default if the creating user doesn't explicitly specify an owner via `AUTHORIZATION`? How does this relate to the user's default schema?
    *   **Answer:** By default, objects are typically owned by the **schema** specified (or implied) during creation, not directly by the user principal itself. If a user creates an object without specifying a schema (e.g., `CREATE TABLE MyTable (...)`), the object is created in the user's **default schema**. The schema itself usually has an owner (often `dbo` or the user who created the schema). While the user has implicit permissions on objects they create in their default schema, the ownership technically resides with the schema. Explicitly using schema names (e.g., `CREATE TABLE hr.MyTable`) is best practice.
9.  **[Hard]** Explain the concept of "orphaned users". How do they occur, and how can they be fixed?
    *   **Answer:** An orphaned user is a database user whose corresponding server-level login (referenced by the user's SID - Security Identifier) no longer exists on the SQL Server instance, or the SID mapping is incorrect.
        *   **Occurrence:** This commonly happens when a database is restored or attached to a *different* server instance where the original logins (with matching SIDs) do not exist. The user definition comes with the database, but its link to a server login is broken.
        *   **Fixing:** You can fix orphaned users using the system stored procedure `sp_change_users_login` (older method) or preferably `ALTER USER ... WITH LOGIN = ...` (modern method).
            *   `ALTER USER OrphanedUserName WITH LOGIN = ExistingLoginName;` remaps the database user to an existing login on the new server (this updates the user's SID in the database to match the login's SID).
            *   `sp_change_users_login @Action='Auto_Fix', @UserNamePattern='UserName', @LoginName='LoginName'` (older) attempts automatic remapping.
            *   Alternatively, you can create a new login on the server with the *same SID* as stored for the user in the database (possible if you know the original SID), or drop and recreate the user mapped to a new login. Using contained database users avoids this problem altogether.
10. **[Hard/Tricky]** Can you grant a server-level permission (like `VIEW SERVER STATE`) directly to a database user?
    *   **Answer:** No. Server-level permissions can only be granted to server-level principals, which are **Logins** or **Server Roles**. You cannot grant server permissions directly to a database user. To give a database user server-level permissions, you must grant the permission to the *Login* that the database user is mapped to, or add that Login to a Server Role that possesses the required permission.
