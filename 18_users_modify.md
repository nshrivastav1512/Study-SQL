# SQL Deep Dive: Modifying Logins, Users, and Roles (`ALTER`)

## 1. Introduction: Modifying Security Principals

After creating logins, users, and roles, you often need to modify their properties or relationships. SQL Server provides various `ALTER` commands specifically for managing these existing security principals without needing to drop and recreate them.

**Why Modify Security Principals?**

*   **Maintenance:** Changing passwords, enabling/disabling logins, updating default settings.
*   **Reorganization:** Renaming users/logins (use with caution!), changing role memberships, transferring schema ownership.
*   **Security Policy Enforcement:** Modifying password policy settings for logins.
*   **Troubleshooting:** Fixing orphaned users by remapping them to logins.

**Key `ALTER` Commands:**

*   `ALTER LOGIN login_name ...`: Modifies server-level login properties (password, default database/language, enable/disable, policy checks).
*   `ALTER USER user_name ...`: Modifies database-level user properties (name, default schema, login mapping).
*   `ALTER ROLE role_name ...`: Modifies database role membership (`ADD MEMBER`, `DROP MEMBER`).
*   `ALTER SERVER ROLE role_name ...`: Modifies server role membership.
*   `ALTER APPLICATION ROLE role_name ...`: Modifies application role properties (password).
*   `ALTER AUTHORIZATION ON [SCHEMA:: | OBJECT::] ... TO principal_name`: Changes the owner of a schema or object.

## 2. Modifying Principals in Action: Analysis of `18_users_modify.sql`

This script demonstrates common modification tasks using `ALTER` statements.

**a) Rename User**

```sql
USE HRSystem;
GO
ALTER USER JohnDoe WITH NAME = JohnDoeNew;
```

*   **Explanation:** Renames the database user `JohnDoe` to `JohnDoeNew` within the `HRSystem` database.
*   **Caution:** Renaming users (or logins) can break code or scripts that reference the old name, similar to using `sp_rename`. Use carefully and update dependencies.

**b) Change Default Schema**

```sql
USE HRSystem;
GO
ALTER USER JohnDoeNew WITH DEFAULT_SCHEMA = Sales; -- Assuming Sales schema exists
```

*   **Explanation:** Changes the default schema associated with the database user `JohnDoeNew`. Object references without explicit schema qualification will now first look in the `Sales` schema.

**c) Change Login Password**

```sql
USE master; -- Or no USE needed
GO
ALTER LOGIN JohnDoeNew WITH PASSWORD = 'NewPass123!';
```

*   **Explanation:** Changes the password for the SQL Server authentication login `JohnDoeNew`. The new password must comply with applicable Windows password policies unless `CHECK_POLICY = OFF` is specified for the login. Requires `ALTER ANY LOGIN` server permission or ownership.

**d) Enable/Disable Login**

```sql
USE master;
GO
ALTER LOGIN JohnDoeNew DISABLE; -- Prevents login from connecting
ALTER LOGIN JohnDoeNew ENABLE;  -- Allows login to connect again
```

*   **Explanation:** Disables or enables a server login. A disabled login cannot connect to the SQL Server instance, effectively blocking all access for that login, even if corresponding database users exist.

**e) Change User Role Membership**

```sql
USE HRSystem;
GO
ALTER ROLE HRStaff ADD MEMBER JohnDoeNew; -- Add user to role
ALTER ROLE HRStaff DROP MEMBER JohnDoeNew; -- Remove user from role
```

*   **Explanation:** Modifies the membership of a database role (`HRStaff`). `ADD MEMBER` grants the user the permissions associated with the role; `DROP MEMBER` revokes them (unless granted through other means).

**f) Modify Login Authentication Policy Settings**

```sql
USE master;
GO
ALTER LOGIN JohnDoeNew
WITH CHECK_POLICY = ON, -- Enforce Windows password policies
     CHECK_EXPIRATION = ON; -- Enforce password expiration
```

*   **Explanation:** Modifies policy settings for a SQL login. `CHECK_POLICY` enforces complexity, lockout, etc. `CHECK_EXPIRATION` enforces the Windows password expiration policy. Can be set to `OFF` to disable these checks (e.g., for service accounts, but use cautiously).

**g) Map User to Different Login (Remapping)**

```sql
USE HRSystem;
GO
-- Assume JohnDoeNew user exists, NewLoginName login exists
ALTER USER JohnDoeNew WITH LOGIN = NewLoginName;
```

*   **Explanation:** Changes the server login associated with an existing database user. This updates the SID mapping for the user within the database. Useful for correcting mappings or changing the login associated with a user.

**h) Change User Default Language**

```sql
USE HRSystem;
GO
ALTER USER JohnDoeNew WITH DEFAULT_LANGUAGE = French;
```

*   **Explanation:** Changes the default language setting for the database user. This affects date formats, system messages, etc., for the user's session within that database if not overridden.

**i) Modify Application Role Password**

```sql
USE HRSystem;
GO
ALTER APPLICATION ROLE HRApp WITH PASSWORD = 'NewAppPass123!';
```

*   **Explanation:** Changes the password required for an application to activate the `HRApp` application role using `sp_setapprole`.

**j) Fix Orphaned User**

```sql
USE HRSystem;
GO
-- Remaps the existing database user JohnDoeNew to the server login JohnDoeNew
-- This assumes the login JohnDoeNew exists and is the correct one.
ALTER USER JohnDoeNew WITH LOGIN = JohnDoeNew;
```

*   **Explanation:** This is the modern syntax (`ALTER USER ... WITH LOGIN = ...`) for fixing an orphaned user. It explicitly links the database user (`JohnDoeNew`) to the specified server login (`JohnDoeNew`), updating the user's SID in the database metadata to match the login's SID.

**k) Change Login Default Database/Language**

```sql
USE master;
GO
ALTER LOGIN JohnDoeNew
WITH DEFAULT_DATABASE = HRSystem,
     DEFAULT_LANGUAGE = [us_english];
```

*   **Explanation:** Changes the default database the login connects to if none is specified in the connection string, and sets the default language for server-level messages for the login's session.

**l) Modify Service Account Login Policy**

```sql
USE master;
GO
ALTER LOGIN ServiceAccount
WITH CHECK_POLICY = OFF,
     CHECK_EXPIRATION = OFF;
```

*   **Explanation:** Disables Windows password policy enforcement (`CHECK_POLICY=OFF`) and expiration checks (`CHECK_EXPIRATION=OFF`) for the `ServiceAccount` SQL login. Often done for service accounts using SQL authentication where password rotation is handled externally or not desired.

**m) Change Certificate Mapping (Rename User)**

```sql
USE HRSystem;
GO
-- Renames the user associated with the certificate
ALTER USER CertUser WITH NAME = NewCertUser;
-- Note: To change the certificate itself, you'd typically drop/recreate the user
-- or potentially use ALTER USER ... FOR CERTIFICATE NewCertificateName; if supported.
```

*   **Explanation:** This example simply renames the user associated with a certificate. Modifying the actual certificate mapping might involve dropping and recreating the user or potentially using `ALTER USER ... FOR CERTIFICATE ...` if changing the certificate itself.

**n) Modify User Connection Limits (Incorrect Example)**

```sql
-- This syntax is incorrect for limiting connections via ALTER LOGIN
-- ALTER LOGIN JohnDoeNew WITH DEFAULT_DATABASE = HRSystem;
-- Connection limits are typically managed via Resource Governor or external tools.
```

*   **Explanation:** The script shows `ALTER LOGIN ... WITH DEFAULT_DATABASE`, which sets the default database, *not* connection limits. SQL Server doesn't have a direct `ALTER LOGIN` syntax to limit the number of connections for a specific login. Connection limits are usually managed through application connection pooling, the dedicated administrator connection (DAC), or potentially using Resource Governor (though Resource Governor primarily manages CPU, memory, and I/O, not connection count directly).

**o) Change Schema Ownership**

```sql
USE HRSystem;
GO
ALTER AUTHORIZATION ON SCHEMA::HR TO JohnDoeNew;
```

*   **Explanation:** Transfers the ownership of the specified schema (`HR`) to a different database principal (`JohnDoeNew`, which must be a user or role). The new owner gains control over the schema and permissions associated with ownership.

## 3. Targeted Interview Questions (Based on `18_users_modify.sql`)

**Question 1:** What command would you use to prevent the login `AppLogin` from connecting to the SQL Server instance temporarily, without deleting the login?

**Solution 1:** You would use the `ALTER LOGIN` command with the `DISABLE` option:
```sql
ALTER LOGIN AppLogin DISABLE;
```

**Question 2:** How do you fix an orphaned database user named `OrphanUser` so that it maps to an existing server login named `ExistingLogin`?

**Solution 2:** You use the `ALTER USER` command with the `WITH LOGIN` clause:
```sql
USE YourDatabaseName; -- Switch to the database containing the orphaned user
GO
ALTER USER OrphanUser WITH LOGIN = ExistingLogin;
```

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can you change a login's name using `ALTER LOGIN`?
    *   **Answer:** No. To rename a server login, you must use the system stored procedure `sp_rename` (e.g., `EXEC sp_rename 'OldLoginName', 'NewLoginName';`). `ALTER LOGIN` is used for changing passwords, defaults, enabling/disabling, etc.
2.  **[Easy]** What permission is typically required to change *your own* SQL login password using `ALTER LOGIN`? What about changing *someone else's* password?
    *   **Answer:** To change your own password, you generally don't need specific permissions beyond being authenticated. To change someone else's password, you typically need the `ALTER ANY LOGIN` server-level permission.
3.  **[Medium]** If you change a user's default schema using `ALTER USER ... WITH DEFAULT_SCHEMA = ...`, does this affect permissions?
    *   **Answer:** No, changing the default schema does not directly grant or revoke any permissions. It only changes the schema SQL Server searches first when the user references objects without a schema qualifier. The user still needs appropriate permissions (`SELECT`, `INSERT`, `EXECUTE`, etc.) on objects, regardless of whether they are in the default schema or another schema.
4.  **[Medium]** What is the difference between disabling a login (`ALTER LOGIN ... DISABLE`) and denying connect permission (`DENY CONNECT SQL TO login_name`)?
    *   **Answer:**
        *   `ALTER LOGIN ... DISABLE`: Completely prevents the login from authenticating and connecting to the SQL Server instance.
        *   `DENY CONNECT SQL`: Explicitly denies the server-level permission to connect. While it also prevents connection, it's part of the permission system. Disabling is often considered a more direct administrative action to temporarily block access. Functionally, both prevent login, but `DISABLE` is often simpler to manage for temporary lockout. A disabled login cannot connect even if `CONNECT SQL` is granted.
5.  **[Medium]** Can you add a server login directly as a member to a database role using `ALTER ROLE`?
    *   **Answer:** No. `ALTER ROLE` (for database roles) operates on database principals (users). You must first create a database user mapped to the server login (`CREATE USER ... FOR LOGIN ...`) and then add the *user* to the database role (`ALTER ROLE role_name ADD MEMBER user_name;`).
6.  **[Medium]** What does `CHECK_POLICY = ON` enforce for a SQL login?
    *   **Answer:** It enforces the Windows password policies of the machine hosting SQL Server onto the SQL login's password. This typically includes requirements for password complexity (length, character types), password history, and potentially account lockout thresholds after failed login attempts.
7.  **[Hard]** If you use `ALTER USER OrphanedUser WITH LOGIN = ExistingLogin;` to fix an orphaned user, what underlying identifier is actually being updated in the database metadata?
    *   **Answer:** The Security Identifier (SID). This command updates the SID stored for the database user (`OrphanedUser`) in the database's `sys.database_principals` view to match the SID of the server login (`ExistingLogin`) found in `master.sys.server_principals`.
8.  **[Hard]** Can you change a Windows login (`CREATE LOGIN [DOMAIN\User] FROM WINDOWS`) to be a SQL authentication login using `ALTER LOGIN`?
    *   **Answer:** No. You cannot change the fundamental authentication type of an existing login using `ALTER LOGIN`. A Windows login is always authenticated by Windows, and a SQL login is always authenticated by SQL Server using a password. To switch authentication methods for a user, you would typically need to drop the existing login and create a new login of the desired type, then remap any corresponding database users.
9.  **[Hard]** What happens if you try to change the ownership of a schema (`ALTER AUTHORIZATION ON SCHEMA::SomeSchema TO NewOwner`) but the `NewOwner` principal does not have `IMPERSONATE` permissions on the original owner or sufficient administrative privileges?
    *   **Answer:** The `ALTER AUTHORIZATION` statement will likely fail. Transferring ownership requires specific permissions. The caller typically needs `ALTER AUTHORIZATION` permission on the schema itself, `IMPERSONATE` permission on the new owner, and potentially `CONTROL` permission on the database or higher administrative privileges (`sysadmin` role) depending on the specific principals involved. Without sufficient rights, the ownership transfer is denied.
10. **[Hard/Tricky]** You disable a login using `ALTER LOGIN MyLogin DISABLE;`. Does this prevent a database user mapped to `MyLogin` from being used with `EXECUTE AS USER = 'MappedUser'` within a stored procedure by another authenticated user?
    *   **Answer:** No, disabling the *login* does not prevent the corresponding database *user* from being impersonated using `EXECUTE AS USER` (assuming the caller has the necessary `IMPERSONATE` permission on that user). `DISABLE` only prevents the login itself from establishing a *new connection* to the server instance. The database user principal still exists and can be used for context switching within an existing, authenticated session.
