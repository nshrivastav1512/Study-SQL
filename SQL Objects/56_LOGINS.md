# SQL Deep Dive: Logins

## 1. Introduction: What are Logins?

A **Login** is a **server-level security principal** in SQL Server. Its primary purpose is to **authenticate** a connection attempt to the SQL Server instance. Think of it as the key that potentially gets you through the main gate of the SQL Server building.

Once authenticated via a login, access to specific databases and objects within those databases is controlled by **database users** and their permissions. A login must typically be mapped to a database user in each database the login needs to access (except for members of the `sysadmin` role or when using contained databases).

**Types of Logins:**

1.  **Windows Authentication Logins:** Based on Windows user accounts or groups (e.g., `DOMAIN\UserName`, `DOMAIN\GroupName`). Authentication is handled by Windows; SQL Server trusts the Windows security token. Generally preferred for security and manageability in domain environments.
2.  **SQL Server Authentication Logins:** Based on a username and password stored within SQL Server. SQL Server performs the authentication check. Requires careful password management and adherence to policies.
3.  **Certificate-Based Logins:** Authenticate using a certificate created in the `master` database.
4.  **Asymmetric Key-Based Logins:** Authenticate using an asymmetric key created in the `master` database.
5.  **Mapped from Windows Group:** A Windows group login allows any member of that Windows group to connect.

**Key Commands:**

*   `CREATE LOGIN ...`
*   `ALTER LOGIN ...`
*   `DROP LOGIN ...`
*   `ALTER SERVER ROLE ... ADD MEMBER ...`
*   `GRANT`/`DENY`/`REVOKE` (for server-level permissions)

**Context:** Login management commands (`CREATE`/`ALTER`/`DROP LOGIN`) are typically executed in the context of the `master` database.

## 2. Logins in Action: Analysis of `56_LOGINS.sql`

This script demonstrates creating, modifying, dropping, and querying logins.

**a) Creating Logins (`CREATE LOGIN`)**

```sql
-- SQL Authentication
CREATE LOGIN SQLLogin1 WITH PASSWORD = '...';
CREATE LOGIN SQLLogin2 WITH PASSWORD = '...', DEFAULT_DATABASE = HRSystem, CHECK_POLICY = ON, ...;

-- Windows Authentication
CREATE LOGIN [DOMAIN\WindowsUser1] FROM WINDOWS;
CREATE LOGIN [DOMAIN\HRGroup] FROM WINDOWS;

-- Certificate/Asymmetric Key Based
CREATE CERTIFICATE LoginCert ...; CREATE LOGIN CertLogin FROM CERTIFICATE LoginCert;
CREATE ASYMMETRIC KEY LoginAsymKey ...; CREATE LOGIN AsymKeyLogin FROM ASYMMETRIC KEY LoginAsymKey;
```

*   **Explanation:** Shows creating different types of logins.
    *   SQL Logins require `WITH PASSWORD`. Options like `DEFAULT_DATABASE`, `DEFAULT_LANGUAGE`, `CHECK_EXPIRATION` (enforce password expiry), and `CHECK_POLICY` (enforce Windows password complexity/lockout policies) can be set.
    *   Windows Logins use `FROM WINDOWS`. No password management within SQL Server.
    *   Certificate/Asymmetric Key logins provide alternative authentication mechanisms, often used for service-to-service or automated processes.

**b) Altering Logins (`ALTER LOGIN`)**

```sql
ALTER LOGIN SQLLogin1 WITH PASSWORD = 'NewPassword'; -- Change password
ALTER LOGIN SQLLogin2 WITH DEFAULT_DATABASE = master; -- Change default DB
ALTER LOGIN SQLLogin1 DISABLE; -- Disable login
ALTER LOGIN SQLLogin1 ENABLE; -- Enable login
ALTER LOGIN SQLLogin2 WITH CHECK_POLICY = OFF; -- Disable policy checks
ALTER LOGIN SQLLogin1 WITH PASSWORD = '...' UNLOCK; -- Unlock locked account
```

*   **Explanation:** Modifies properties of existing logins. Common uses include changing passwords, setting default database/language, enabling/disabling the login (preventing connections), modifying password policy enforcement, or unlocking an account locked due to failed login attempts.

**c) Dropping Logins (`DROP LOGIN`)**

```sql
DROP LOGIN SQLLogin1;
DROP LOGIN [DOMAIN\WindowsUser1];
DROP LOGIN CertLogin;
DROP LOGIN AsymKeyLogin;
```

*   **Explanation:** Permanently removes a login from the SQL Server instance.
*   **Caution:** Fails if the login is currently connected or owns server-level objects (like jobs, endpoints) or databases. Dropping a login does *not* automatically drop corresponding database users, potentially creating orphaned users.

**d) Managing Login Properties (Permissions/Roles)**

```sql
-- Grant server-level permission
GRANT VIEW SERVER STATE TO SQLLogin2;
-- Add login to server role
ALTER SERVER ROLE sysadmin ADD MEMBER SQLLogin2;
-- Remove login from server role
ALTER SERVER ROLE sysadmin DROP MEMBER SQLLogin2;
```

*   **Explanation:** Shows how server-level permissions (like `VIEW SERVER STATE`) are granted directly `TO` logins (or server roles). Also shows how logins are added to or removed from fixed server roles (like `sysadmin`, `serveradmin`, `dbcreator`, etc.) using `ALTER SERVER ROLE`.

**e) Querying Login Information (System Views/Functions)**

```sql
-- All server principals (logins, server roles)
SELECT name, type_desc, create_date, is_disabled FROM sys.server_principals WHERE type IN (...);
-- SQL Logins specifically + properties
SELECT name, LOGINPROPERTY(name, 'PasswordLastSetTime'), ... FROM sys.sql_logins;
-- Windows Logins/Groups
SELECT name, type_desc, ... FROM sys.server_principals WHERE type IN ('U', 'G');
-- Certificate/Key Logins
SELECT p.name, ..., c.name, k.name FROM sys.server_principals p LEFT JOIN sys.certificates c ON ... LEFT JOIN sys.asymmetric_keys k ON ... WHERE p.type IN ('C', 'K');
-- Server Role Membership
SELECT r.name AS RoleName, m.name AS MemberName, ... FROM sys.server_role_members rm JOIN sys.server_principals r ON ... JOIN sys.server_principals m ON ...;
-- Server Permissions granted TO logins
SELECT p.name AS LoginName, ..., perm.permission_name, ... FROM sys.server_principals p JOIN sys.server_permissions perm ON ... WHERE p.type IN (...);
```

*   **Explanation:** Uses various system catalog views (`sys.server_principals`, `sys.sql_logins`, `sys.server_role_members`, `sys.server_permissions`, etc.) and functions (`LOGINPROPERTY`) to retrieve metadata about logins, their properties (password status, lockout state), role memberships, and explicitly granted server-level permissions.

## 3. Targeted Interview Questions (Based on `56_LOGINS.sql`)

**Question 1:** What is the difference between a SQL Server Authentication Login and a Windows Authentication Login? Which is generally recommended in a domain environment?

**Solution 1:**

*   **SQL Server Authentication Login:** Authenticated by SQL Server using a username and password stored within SQL Server. Requires manual password management.
*   **Windows Authentication Login:** Authenticated by the Windows operating system (Active Directory). SQL Server trusts the Windows authentication token. Uses existing Windows accounts/groups.
*   **Recommendation:** Windows Authentication is generally recommended in a domain environment because it provides stronger security (no passwords stored/transmitted to SQL Server), leverages existing Windows security infrastructure (password policies, group management), and supports single sign-on.

**Question 2:** If you execute `DROP LOGIN MyLogin;`, does this also remove the user `MyUser` from the `HRSystem` database if `MyUser` was created `FOR LOGIN MyLogin`? What is the potential consequence?

**Solution 2:** No, `DROP LOGIN MyLogin;` does **not** remove the database user `MyUser` from `HRSystem`. The consequence is that `MyUser` becomes an **orphaned user** within the `HRSystem` database, as its corresponding server-level login (identified by SID) no longer exists. The orphaned user cannot log in and may cause issues until it is either dropped or remapped to an existing login.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which database context should you typically be in to execute `CREATE LOGIN` or `DROP LOGIN`?
    *   **Answer:** `master`.
2.  **[Easy]** What command disables a login, preventing it from connecting?
    *   **Answer:** `ALTER LOGIN login_name DISABLE;`.
3.  **[Medium]** What do the `CHECK_POLICY` and `CHECK_EXPIRATION` options control for a SQL Login?
    *   **Answer:** They control whether the Windows password policies (complexity, history, lockout for `CHECK_POLICY`) and password expiration policy (`CHECK_EXPIRATION`) defined on the server hosting SQL Server are enforced for that specific SQL Login's password.
4.  **[Medium]** Can you grant database-level permissions (like `SELECT` on a table) directly to a server Login?
    *   **Answer:** No. Database-level permissions are granted to database Users or Roles. You must first create a User in the database mapped to the Login, and then grant the permission to that User (or a role the User belongs to).
5.  **[Medium]** What is the difference between adding a Windows User login (`[DOMAIN\User]`) and a Windows Group login (`[DOMAIN\Group]`)?
    *   **Answer:** A Windows User login grants access only to that specific user account. A Windows Group login grants access to *all* Windows user accounts that are members of that Windows group. Using group logins simplifies management, as access is controlled by adding/removing users from the Windows group rather than managing individual logins in SQL Server.
6.  **[Medium]** What does the `LOGINPROPERTY(login_name, 'IsLocked')` function tell you? How can a login become locked?
    *   **Answer:** It returns 1 if the SQL Login account is currently locked out, 0 otherwise. A login typically becomes locked if `CHECK_POLICY = ON` is enabled and the user exceeds the configured number of failed login attempts (defined by the Windows account lockout policy).
7.  **[Hard]** Can a single login be mapped to users in multiple databases?
    *   **Answer:** Yes. A single server login (e.g., `MyLogin`) can be mapped to a database user (e.g., `UserA` in `DB1`, `UserB` in `DB2`, or even `MyLogin` user in both `DB1` and `DB2`) in multiple different databases on the same SQL Server instance.
8.  **[Hard]** What is the SID (Security Identifier) in the context of logins and users, and why is it important for understanding orphaned users?
    *   **Answer:** The SID is a unique binary value that identifies a login at the server level (`sys.server_principals.sid`) and a user at the database level (`sys.database_principals.sid`). When a database user is mapped to a login (`CREATE USER ... FOR LOGIN ...`), their SIDs must match. An orphaned user occurs when a database user's SID exists in the database, but there is no corresponding login with the same SID at the server level (often after restoring a database to a different server).
9.  **[Hard]** Can you create a SQL Login that does *not* require a password (e.g., for a specific trusted internal process)?
    *   **Answer:** No, not directly in the standard sense. `CREATE LOGIN ... WITH PASSWORD = ...` requires a password. While you could potentially use certificate or asymmetric key-based logins which don't use traditional passwords, or rely on Windows authentication, creating a standard SQL login without any password credential is not supported for security reasons. You could create one with `CHECK_POLICY=OFF` and a known/simple password, but this is insecure.
10. **[Hard/Tricky]** If you grant `CONTROL SERVER` to `LoginA`, and then explicitly `DENY ALTER ANY LOGIN` to `LoginA`, can `LoginA` still alter other logins?
    *   **Answer:** Yes. `CONTROL SERVER` is the highest level of server permission, equivalent to being a member of the `sysadmin` fixed server role. Membership in `sysadmin` (or having `CONTROL SERVER`) generally overrides explicit `DENY` statements for most permissions, including `ALTER ANY LOGIN`. The `DENY` would be ineffective against a principal with `CONTROL SERVER`.
