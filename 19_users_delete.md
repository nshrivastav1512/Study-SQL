# SQL Deep Dive: Deleting Logins, Users, and Roles (`DROP`)

## 1. Introduction: Removing Security Principals

Just as important as creating and modifying security principals is knowing how to remove them cleanly when they are no longer needed. SQL Server uses various `DROP` commands to remove logins, users, roles, and other related security objects.

**Why Remove Security Principals?**

*   **Security Hygiene:** Remove access for departed employees, decommissioned applications, or unused service accounts to minimize the attack surface.
*   **Cleanup:** Remove temporary or test principals.
*   **Resource Management:** Although minor, removing unused principals cleans up metadata.

**Key `DROP` Commands:**

*   `DROP LOGIN login_name`: Removes a server-level login.
*   `DROP USER user_name`: Removes a database user from the current database.
*   `DROP ROLE role_name`: Removes a custom database role.
*   `DROP APPLICATION ROLE role_name`: Removes an application role.
*   `DROP CERTIFICATE certificate_name`: Removes a certificate.

**Important Considerations:**

*   **Dependencies:** You often cannot drop a principal if it owns objects (like schemas, tables) or has certain dependencies. Ownership must be transferred or objects dropped first.
*   **Permissions:** Dropping principals requires specific high-level permissions (e.g., `ALTER ANY LOGIN`, `ALTER ANY USER`, `CONTROL` on the database).
*   **Logins vs. Users:** Dropping a login does *not* automatically drop corresponding database users in user databases. This creates orphaned users. Dropping a database user does *not* drop the server login. Best practice is often to drop the database user first, then the login.
*   **Irreversible:** Like other `DROP` commands, these are generally irreversible without restoring from backups.

## 2. Deleting Principals in Action: Analysis of `19_users_delete.sql`

This script shows how to drop different types of principals and handle related issues. *Note: Assumes the principals mentioned (e.g., `JohnDoeNew`, `HRStaff`) were created in previous steps.*

**a) Basic User Deletion**

```sql
USE HRSystem;
GO
DROP USER JohnDoeNew;
```

*   **Explanation:** Removes the database user `JohnDoeNew` from the `HRSystem` database. This will fail if `JohnDoeNew` owns any objects or schemas within this database.

**b) Delete Login**

```sql
USE master; -- Or no USE needed
GO
DROP LOGIN JohnDoeNew;
```

*   **Explanation:** Removes the server-level login `JohnDoeNew`. This will fail if the login is currently connected or has certain server-level dependencies (like owning server roles or endpoints). This does *not* remove the `JohnDoeNew` user from the `HRSystem` database, potentially orphaning that user.

**c) Delete User and Clean Up Permissions/Roles**

```sql
USE HRSystem;
GO
-- Step 1: Remove from roles
ALTER ROLE HRStaff DROP MEMBER JohnDoeNew;
-- Step 2: Remove explicit permissions (optional but good practice)
-- REVOKE ALL FROM JohnDoeNew; -- Syntax might need refinement depending on permissions granted
-- Step 3: Drop the user
DROP USER JohnDoeNew;
```

*   **Explanation:** A more complete process for removing a user. First, remove the user from any database roles they are a member of. Optionally (and often recommended), explicitly revoke any permissions granted directly to the user. Finally, drop the user itself. This avoids errors related to role membership during the drop.

**d) Delete Application Role**

```sql
USE HRSystem;
GO
DROP APPLICATION ROLE HRApp;
```

*   **Explanation:** Removes the application role `HRApp` from the database.

**e) Delete Database Role**

```sql
USE HRSystem;
GO
DROP ROLE HRStaff;
```

*   **Explanation:** Removes the custom database role `HRStaff`. This will fail if the role still has members or owns objects/schemas. Members must be dropped first (`ALTER ROLE ... DROP MEMBER ...`), and ownership transferred (`ALTER AUTHORIZATION ...`).

**f) Clean Up Orphaned Users (Scripting Example)**

```sql
USE HRSystem;
GO
DECLARE @OrphanUser nvarchar(128);
DECLARE orphan_cursor CURSOR FOR
    SELECT name FROM sys.database_principals
    WHERE type IN ('S', 'U', 'G') AND authentication_type_desc = 'INSTANCE'
      AND NOT EXISTS (SELECT 1 FROM sys.server_principals SP WHERE SP.sid = sys.database_principals.sid);
OPEN orphan_cursor; FETCH NEXT FROM orphan_cursor INTO @OrphanUser;
WHILE @@FETCH_STATUS = 0 BEGIN
    PRINT 'Dropping orphaned user: ' + @OrphanUser;
    -- Use dynamic SQL to drop the user
    EXEC('DROP USER [' + QUOTENAME(@OrphanUser) + ']'); -- Use QUOTENAME for safety
    FETCH NEXT FROM orphan_cursor INTO @OrphanUser;
END
CLOSE orphan_cursor; DEALLOCATE orphan_cursor;
```

*   **Explanation:** This demonstrates a scripted approach to find and drop orphaned users within the current database.
    1.  It queries `sys.database_principals` to find users mapped to instance logins (`authentication_type_desc = 'INSTANCE'`).
    2.  It uses `NOT EXISTS` to check if a corresponding login exists in `sys.server_principals` based on the SID.
    3.  A cursor iterates through the names of identified orphaned users.
    4.  Dynamic SQL (`EXEC('DROP USER ...')`) is used to execute the `DROP USER` command for each orphaned user found. `QUOTENAME` is added for safety around user names that might contain special characters.

**g) Delete Certificate User and Certificate**

```sql
USE HRSystem;
GO
DROP USER CertUser; -- Drop the user mapped to the certificate
GO
USE master; -- Or wherever the certificate was created
GO
DROP CERTIFICATE HRCertificate; -- Drop the certificate itself
```

*   **Explanation:** Shows the two steps often required: first drop the database user associated with the certificate, then drop the certificate object itself.

**h) Delete User with Dependencies Check (Schema Ownership)**

```sql
USE HRSystem;
GO
IF EXISTS (SELECT 1 FROM sys.objects WHERE schema_id IN (SELECT principal_id FROM sys.database_principals WHERE name = 'JohnDoeNew'))
BEGIN
    RAISERROR ('User owns schema objects. Clean up required.', 16, 1);
    -- RETURN; -- Use RETURN in procedures/functions, not standalone batch
END ELSE BEGIN
    DROP USER JohnDoeNew;
END
```

*   **Explanation:** Attempts to check if the user potentially owns objects by checking if any object's `schema_id` matches the user's `principal_id`. *Correction:* This check is slightly flawed, as users don't typically own objects directly via `principal_id` in `sys.objects` (schemas usually do). A better check would be `sys.schemas` where `principal_id` matches the user's ID, or checking `sys.objects` where the schema owner matches the user. The *intent* is correct: check for dependencies (like schema ownership) before dropping. If dependencies exist, raise an error; otherwise, drop the user.

**i) Delete Windows Authentication User and Login**

```sql
USE HRSystem;
GO
DROP USER [DOMAIN\JaneSmith]; -- Drop the database user first
GO
USE master;
GO
DROP LOGIN [DOMAIN\JaneSmith]; -- Then drop the server login
```

*   **Explanation:** The standard two-step process for completely removing access for a Windows principal: drop the database user, then drop the server login.

**j) Delete Service Account (with care)**

```sql
USE master;
GO
ALTER LOGIN ServiceAccount DISABLE; -- Disable first to prevent new connections
WAITFOR DELAY '00:00:05'; -- Allow time for existing connections to potentially close
-- Check for active sessions before dropping if critical: SELECT session_id FROM sys.dm_exec_sessions WHERE login_name = 'ServiceAccount';
-- KILL session_id; (If necessary and safe)
GO
USE HRSystem;
GO
DROP USER ServiceUser; -- Drop database user
GO
USE master;
GO
DROP LOGIN ServiceAccount; -- Drop server login
```

*   **Explanation:** A more cautious approach for service accounts. Disabling the login first prevents new connections. A delay (or active session check/kill) allows existing connections to finish before dropping the user and login, minimizing disruption.

## 3. Targeted Interview Questions (Based on `19_users_delete.sql`)

**Question 1:** Why is it generally recommended to `DROP USER` *before* `DROP LOGIN` when removing a principal's access completely? What problem does this help avoid?

**Solution 1:** Dropping the database user first ensures that the user principal within the database (which holds permissions and potentially object/schema ownership) is cleanly removed. If you drop the login first, the database user remains but becomes an **orphaned user** because its corresponding server login (identified by SID) no longer exists. Orphaned users can cause issues and need to be cleaned up separately. Dropping the user first avoids creating orphans.

**Question 2:** The script in section 6 uses a cursor and dynamic SQL to drop orphaned users. Why is dynamic SQL necessary in this case?

**Solution 2:** Dynamic SQL (`EXEC('DROP USER ...')`) is necessary because the `DROP USER` command requires the user name as a literal identifier directly in the statement text. You cannot use a variable directly like `DROP USER @OrphanUser;`. The script retrieves the user name into the `@OrphanUser` variable within the cursor loop, constructs the `DROP USER` command as a string including the retrieved user name, and then executes that string using `EXEC`.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can you `DROP` the built-in `dbo` user or the `guest` user?
    *   **Answer:** No. You cannot drop the `dbo` (database owner) user or the `guest` user. They are special built-in principals. You can disable the `guest` user if needed (`REVOKE CONNECT FROM guest;`).
2.  **[Easy]** Can you `DROP` a server login while it has an active connection to SQL Server?
    *   **Answer:** No. The `DROP LOGIN` statement will fail if the login has any active sessions connected to the instance. You need to ensure the user is disconnected (or `KILL` the sessions) first.
3.  **[Medium]** What happens if you try to `DROP ROLE MyRole;` but there are still users who are members of `MyRole`?
    *   **Answer:** The `DROP ROLE` statement will fail with an error indicating that the role cannot be dropped because it still has members. You must first remove all members using `ALTER ROLE MyRole DROP MEMBER UserName;` before you can drop the role.
4.  **[Medium]** If a user owns a schema, can you directly `DROP USER` for that user? What must be done first?
    *   **Answer:** No, you cannot drop a user that owns a schema. You must first transfer the ownership of the schema to another user or role using `ALTER AUTHORIZATION ON SCHEMA::SchemaName TO NewOwner;` before you can drop the original user.
5.  **[Medium]** Does dropping a login (`DROP LOGIN`) remove the login's SID from the `sys.server_principals` view?
    *   **Answer:** Yes. `DROP LOGIN` removes the entire record for that login, including its name and SID, from the `sys.server_principals` metadata view (in the `master` database).
6.  **[Medium]** If you drop a database user, are the permissions explicitly granted *to* that user automatically revoked?
    *   **Answer:** Yes. When a database user (the grantee) is dropped, all explicit permissions granted *to* that user are automatically removed as part of the drop operation. The permission grant records referencing the dropped user's principal ID become invalid and are cleaned up.
7.  **[Hard]** Can you `DROP LOGIN` for a login that is the owner of a database? What needs to happen first?
    *   **Answer:** No, you cannot drop a login that owns a database. You must first change the database owner to a different login using `ALTER AUTHORIZATION ON DATABASE::DatabaseName TO NewLoginOwner;` (often set to `sa` temporarily or another administrative login).
8.  **[Hard]** If you drop a certificate using `DROP CERTIFICATE`, what happens to a database user that was created `FOR CERTIFICATE` using that certificate?
    *   **Answer:** Dropping the certificate does *not* automatically drop the database user created `FOR CERTIFICATE`. However, the user becomes effectively unusable for certificate-based authentication or operations requiring the certificate (like signature verification) because the underlying certificate object no longer exists. You should typically `DROP USER` *before* dropping the associated certificate.
9.  **[Hard]** Consider a scenario where a login `MyLogin` exists, and a user `MyUser` exists in `DatabaseA` mapped `FOR LOGIN MyLogin`. If you restore a backup of `DatabaseA` onto a *different server* where `MyLogin` does *not* exist, what is the state of `MyUser` in the restored database?
    *   **Answer:** `MyUser` will exist in the restored `DatabaseA`, but it will be an **orphaned user**. Its definition (including its original SID from the source server) is restored, but there is no login on the *new* server with a matching SID. The user cannot log in directly (unless it was a contained user) and needs to be remapped using `ALTER USER MyUser WITH LOGIN = SomeExistingLoginOnNewServer;` or by creating a new login `MyLogin` on the new server (potentially with the original SID if known).
10. **[Hard/Tricky]** Can you use `DROP USER` within a transaction? If you `DROP USER MyUser;` inside a `BEGIN TRAN ... ROLLBACK TRAN` block, is the user actually dropped?
    *   **Answer:** Yes, `DROP USER` (like most DDL) is transactional. If you execute `DROP USER MyUser;` within a transaction that is subsequently rolled back, the user deletion will be undone, and the user will still exist as if the `DROP USER` command never happened.
