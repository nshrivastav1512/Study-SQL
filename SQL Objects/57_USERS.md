# SQL Deep Dive: Database Users

## 1. Introduction: What are Database Users?

A **Database User** is a **database-level security principal**. It represents an identity that can be granted permissions to access and interact with objects *within a specific database*.

**Logins vs. Users (Recap):**

*   **Login:** Server-level principal for *authentication* (connecting to the SQL Server instance).
*   **User:** Database-level principal for *authorization* (performing actions within a specific database).

Typically, a server login must be **mapped** to a database user in each database the login needs to access. When a login connects and switches context to a database, it assumes the identity and permissions of its mapped database user.

**Types of Database Users:**

1.  **User Mapped to a Windows Login/Group:** Created `FOR LOGIN [DOMAIN\Name]`. Inherits identity from the Windows principal.
2.  **User Mapped to a SQL Server Login:** Created `FOR LOGIN LoginName`. Inherits identity from the SQL login.
3.  **Contained Database User:** Created `WITH PASSWORD = '...'` (or `WITHOUT LOGIN` if authentication handled differently). Exists only within a contained database, authenticates at the database level, and does not require a server login.
4.  **User Mapped to a Certificate:** Created `FROM CERTIFICATE CertName`. Used for certificate-based authentication or code signing permissions.
5.  **User Mapped to an Asymmetric Key:** Created `FROM ASYMMETRIC KEY KeyName`. Used for key-based authentication or code signing.
6.  **User Without Login:** Created `WITHOUT LOGIN`. Cannot connect directly but can be used to own schemas or grant permissions to objects that might be accessed via `EXECUTE AS`.
7.  **User Mapped to Azure Active Directory Principal:** (Azure SQL specific) Created `FROM EXTERNAL PROVIDER`.

**Key Commands:**

*   `CREATE USER ...`
*   `ALTER USER ...`
*   `DROP USER ...`
*   `ALTER ROLE ... ADD MEMBER ...`
*   `GRANT`/`DENY`/`REVOKE` (for database/schema/object permissions TO the user or roles)

**Context:** User management commands (`CREATE`/`ALTER`/`DROP USER`) are executed within the context of the specific database where the user will reside (`USE DatabaseName;`).

## 2. Users in Action: Analysis of `57_USERS.sql`

This script demonstrates creating, altering, dropping, and querying database users.

**a) Creating Database Users (`CREATE USER`)**

```sql
-- Mapped to SQL Login
CREATE USER SQLUser1 FOR LOGIN SQLLogin1;
CREATE USER SQLUser2 FOR LOGIN SQLLogin2 WITH DEFAULT_SCHEMA = HR;

-- Mapped to Windows Login/Group
CREATE USER [DOMAIN\WindowsUser1] FOR LOGIN [DOMAIN\WindowsUser1];
CREATE USER [DOMAIN\HRGroup] FOR LOGIN [DOMAIN\HRGroup];

-- Contained User (Requires Contained Database)
CREATE USER ContainedUser1 WITH PASSWORD = '...';

-- Based on Certificate/Key
CREATE CERTIFICATE UserCert ...; CREATE USER CertUser FROM CERTIFICATE UserCert;
CREATE ASYMMETRIC KEY UserAsymKey ...; CREATE USER AsymKeyUser FROM ASYMMETRIC KEY UserAsymKey;

-- User without login capability
CREATE USER NoLoginUser WITHOUT LOGIN;

-- Azure AD User (Conceptual)
-- CREATE USER [user@domain.com] FROM EXTERNAL PROVIDER;
```

*   **Explanation:** Shows various ways to create users.
    *   `FOR LOGIN`: Links the database user to an existing server login (SQL or Windows). The user's SID in the database matches the login's SID.
    *   `WITH DEFAULT_SCHEMA`: Specifies the schema used for object name resolution if not explicitly provided.
    *   `WITH PASSWORD`: Creates a contained database user with a password stored within the database itself (requires database containment enabled).
    *   `FROM CERTIFICATE`/`FROM ASYMMETRIC KEY`: Creates users linked to security artifacts within the database/server.
    *   `WITHOUT LOGIN`: Creates a user principal that cannot log in directly but can own schemas or be granted permissions (useful for `EXECUTE AS` scenarios or schema organization).

**b) Altering Database Users (`ALTER USER`)**

```sql
ALTER USER SQLUser1 WITH DEFAULT_SCHEMA = Sales; -- Change default schema
ALTER USER SQLUser2 WITH NAME = SQLUser2Renamed; -- Rename user
ALTER USER SQLUser1 WITH LOGIN = SQLLogin2; -- Remap to different login (Fix Orphaned User)
ALTER USER ContainedUser1 WITH PASSWORD = 'NewPassword'; -- Change contained user password
```

*   **Explanation:** Modifies properties of an existing database user, such as their name, default schema, or the login they are mapped to. Remapping the login (`WITH LOGIN = ...`) is the primary way to fix orphaned users.

**c) Dropping Database Users (`DROP USER`)**

```sql
DROP USER SQLUser1;
DROP USER [DOMAIN\WindowsUser1];
DROP USER CertUser;
DROP USER AsymKeyUser;
```

*   **Explanation:** Permanently removes a user principal from the *current database*.
*   **Caution:** Fails if the user owns objects (like tables, views, procedures) or schemas within the database. Ownership must be transferred (`ALTER AUTHORIZATION`) or the objects dropped first. Dropping a user does *not* drop the associated server login.

**d) Managing User Properties (Permissions/Roles)**

```sql
-- Grant database-level permission
GRANT CREATE TABLE TO SQLUser2Renamed;
-- Add user to database role
ALTER ROLE db_datareader ADD MEMBER SQLUser2Renamed;
-- Remove user from database role
ALTER ROLE db_datareader DROP MEMBER SQLUser2Renamed;
-- Grant object/schema permissions
GRANT SELECT, INSERT ON SCHEMA::HR TO SQLUser2Renamed;
```

*   **Explanation:** Shows how permissions (database-level like `CREATE TABLE`, or object/schema-level like `SELECT`) are granted `TO` database users (or roles). Also shows adding/removing users from database roles using `ALTER ROLE`.

**e) Querying User Information (System Views)**

```sql
-- All database principals (Users, Roles, etc.)
SELECT name, type_desc, authentication_type_desc, ... FROM sys.database_principals WHERE type IN (...) AND is_fixed_role = 0 ...;
-- Users mapped to logins
SELECT dp.name AS UserName, ..., sp.name AS LoginName FROM sys.database_principals dp LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid WHERE ...;
-- Contained users
SELECT name, authentication_type_desc, ... FROM sys.database_principals WHERE authentication_type > 0 AND type = 'S';
-- Certificate/Key users
SELECT dp.name, ..., c.name, k.name FROM sys.database_principals dp LEFT JOIN sys.certificates c ON ... LEFT JOIN sys.asymmetric_keys k ON ... WHERE dp.type IN ('C', 'K');
-- Role membership
SELECT r.name AS RoleName, m.name AS MemberName, ... FROM sys.database_role_members rm JOIN sys.database_principals r ON ... JOIN sys.database_principals m ON ...;
-- User permissions
SELECT pr.name AS UserName, ..., perm.permission_name, ... FROM sys.database_principals pr JOIN sys.database_permissions perm ON ...;
```

*   **Explanation:** Uses system catalog views, primarily `sys.database_principals`, joined with other views like `sys.server_principals` (for login mapping), `sys.database_role_members` (for role membership), and `sys.database_permissions` (for explicit permissions) to retrieve metadata about database users and their configurations. `authentication_type_desc` helps distinguish between users mapped to instance logins, contained users, and users without login.

## 3. Targeted Interview Questions (Based on `57_USERS.sql`)

**Question 1:** What is the difference between `CREATE USER MyUser FOR LOGIN MyLogin;` and `CREATE USER MyUser WITHOUT LOGIN;`?

**Solution 1:**

*   `CREATE USER MyUser FOR LOGIN MyLogin;`: Creates a database user (`MyUser`) that is **mapped** to an existing server login (`MyLogin`). This user relies on the server login for authentication to the instance. Permissions within the database are granted to `MyUser`.
*   `CREATE USER MyUser WITHOUT LOGIN;`: Creates a database user (`MyUser`) that is **not mapped** to any server login. This user cannot be used to log in to the database directly. Its primary purpose is to own schemas or objects, or to be used as a target for impersonation (`EXECUTE AS USER = 'MyUser'`), allowing code to run under a specific security context without needing a connectable login.

**Question 2:** How would you change the default schema for an existing database user named `AppUser` to `WebAppSchema`?

**Solution 2:** You would use the `ALTER USER` statement:
```sql
USE YourDatabaseName; -- Ensure you are in the correct database
GO
ALTER USER AppUser WITH DEFAULT_SCHEMA = WebAppSchema;
```

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can a database user exist without a corresponding server login? If so, what is this type of user called?
    *   **Answer:** Yes. It can be a **Contained Database User** (if the database is contained and the user is created `WITH PASSWORD`) or a user created `WITHOUT LOGIN`.
2.  **[Easy]** Which system view is the primary source for information about database users and roles?
    *   **Answer:** `sys.database_principals`.
3.  **[Medium]** If you grant `SELECT` permission to a Windows Group user (e.g., `DOMAIN\HRGroup`) in a database, who actually gets the permission?
    *   **Answer:** All Windows users who are members of the `DOMAIN\HRGroup` Windows group *and* who can authenticate to the SQL Server instance (via the corresponding `DOMAIN\HRGroup` login) will inherit the `SELECT` permission when accessing that database.
4.  **[Medium]** What happens if you try to `DROP USER MyUser` when `MyUser` owns a schema named `MySchema`?
    *   **Answer:** The `DROP USER` statement will fail with an error because the user owns a schema. You must first transfer ownership of the schema (`ALTER AUTHORIZATION ON SCHEMA::MySchema TO dbo;`) or drop the schema (if empty) before dropping the user.
5.  **[Medium]** Can you change a database user mapped to a Windows login (`UserA` created `FOR LOGIN [DOMAIN\UserA]`) to be mapped to a SQL login (`SQLLoginB`) using `ALTER USER`?
    *   **Answer:** Yes. You can use `ALTER USER UserA WITH LOGIN = SQLLoginB;`. This changes the SID associated with the database user `UserA` to match the SID of the server login `SQLLoginB`. The original Windows login `[DOMAIN\UserA]` would no longer be associated with the database user `UserA`.
6.  **[Medium]** What is the purpose of creating a user `WITHOUT LOGIN`?
    *   **Answer:** Users created `WITHOUT LOGIN` cannot log in directly but serve as database principals that can own schemas or objects, or have permissions granted to them. This is useful for:
        *   Schema ownership where no specific login should own it.
        *   Creating a specific security context for impersonation using `EXECUTE AS USER = 'NoLoginUser'` within modules like stored procedures or triggers, allowing the code to run with the permissions granted to `NoLoginUser` without needing a connectable login.
7.  **[Hard]** How does SQL Server link a database user (like `UserA`) to its corresponding server login (like `LoginA`)? What identifier is used?
    *   **Answer:** They are linked by the **Security Identifier (SID)**. When a user is created `FOR LOGIN`, the SID of the login from `master.sys.server_principals` is copied into the SID column for the user in the database's `sys.database_principals` view. Authentication happens at the server level using the login's SID, and authorization within the database uses the matching user's SID.
8.  **[Hard]** Can you grant server-level permissions (e.g., `VIEW SERVER STATE`) directly `TO` a database user?
    *   **Answer:** No. Server-level permissions can only be granted `TO` server-level principals (Logins or Server Roles). You grant the permission to the login that the user maps to.
9.  **[Hard]** What is the difference in authentication mechanism between a user created `FOR LOGIN SQL_Login` and a contained user created `WITH PASSWORD = '...'`?
    *   **Answer:**
        *   `FOR LOGIN SQL_Login`: Authentication occurs at the **server instance level**. The client provides the SQL login name and password, which SQL Server validates against `master.sys.sql_logins`. If successful, the connection then maps to the database user.
        *   `WITH PASSWORD`: Authentication occurs at the **database level** (requires a contained database). The client specifies the database name in the connection string along with the contained username and password. The database itself validates the credentials without reference to server-level logins.
10. **[Hard/Tricky]** If you restore a database containing a user `UserX` (created `FOR LOGIN LoginX`) onto a server where `LoginX` exists but has a *different SID* than it did on the original server, will `UserX` be able to log in? What is this user's state?
    *   **Answer:** No, `UserX` will likely **not** be able to log in successfully using `LoginX`. Although a login with the same name exists, the database user `UserX` restored from the backup retains the **SID** from the *original* server's `LoginX`. Since this SID does not match the SID of the *new* server's `LoginX`, the mapping is broken. `UserX` is now an **orphaned user**. It needs to be fixed using `ALTER USER UserX WITH LOGIN = LoginX;` to update the user's SID in the restored database to match the existing login's SID on the new server.
