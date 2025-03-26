# SQL Deep Dive: The `REVOKE` Statement

## 1. Introduction: What is `REVOKE`?

The `REVOKE` statement is a **Data Control Language (DCL)** command used to **remove** previously assigned permissions (`GRANT` or `DENY`) from a security principal (login, user, role) on a securable (object, schema, database, server).

**`GRANT` vs. `DENY` vs. `REVOKE`:**

*   `GRANT`: Gives permission.
*   `DENY`: Explicitly prohibits permission, overriding `GRANT`.
*   `REVOKE`: Removes a specific `GRANT` or `DENY`. It doesn't necessarily mean the principal *loses* the permission entirely – they might still inherit it from another role. It simply removes the specified permission entry.

**Why use `REVOKE`?**

*   **Removing Access:** The standard way to take away permissions that are no longer needed.
*   **Cleaning Up Permissions:** Removing explicit `GRANT`s or `DENY`s to rely on role-based permissions or default behavior.
*   **Modifying Access:** Often used before granting a different level of access (e.g., `REVOKE UPDATE` before `GRANT SELECT`).

**Key Characteristics:**

*   Removes a specific `GRANT` or `DENY`.
*   Does *not* override permissions inherited from other roles (unlike `DENY`).
*   Can remove permissions granted `WITH GRANT OPTION`.
*   Can optionally use `CASCADE` to also revoke permissions that were granted *by* the principal being revoked from (if they used `WITH GRANT OPTION`).

**General Syntax:**

```sql
REVOKE [GRANT OPTION FOR] {permission [,...n] | ALL [PRIVILEGES]}
ON {securable_class :: securable_name | securable_name} [(column [,...n])]
{FROM | TO} principal [,...n] -- Use FROM for GRANTs, TO for DENYs (though FROM often works for both)
[CASCADE]
[AS grantor_principal]; -- Optional
```

*   `GRANT OPTION FOR`: Specifically revokes only the `GRANT OPTION`, leaving the underlying permission intact.
*   `{FROM | TO}`: `FROM` is typically used when revoking a `GRANT`. `TO` is typically used when revoking a `DENY`. However, SQL Server often accepts `FROM` for both.
*   `CASCADE`: If revoking a permission that was granted `WITH GRANT OPTION`, `CASCADE` also revokes that permission from any principals it was subsequently granted to by the principal listed in the `REVOKE` statement.

## 2. `REVOKE` in Action: Analysis of `24_revoke.sql`

This script demonstrates various uses of the `REVOKE` statement. *Note: Assumes the permissions being revoked were previously granted or denied.*

**a) Basic Permission Removal**

```sql
REVOKE SELECT ON HR.EMP_Details FROM HRClerks;
```

*   **Explanation:** Removes the `SELECT` permission (presumably previously granted) on the `HR.EMP_Details` table from the `HRClerks` role. Members of `HRClerks` may still be able to select if they belong to another role that has `SELECT` permission.

**b) Multiple Permission Removal**

```sql
REVOKE SELECT, INSERT, UPDATE ON HR.Departments FROM HRClerks;
```

*   **Explanation:** Removes multiple specific permissions (`SELECT`, `INSERT`, `UPDATE`) on `HR.Departments` from `HRClerks` in one statement.

**c) Schema Level Revocation**

```sql
REVOKE SELECT ON SCHEMA::HR FROM DataAnalysts;
```

*   **Explanation:** Removes the `SELECT` permission previously granted at the schema level (`SCHEMA::HR`) from the `DataAnalysts` role. This affects access to all objects within that schema covered by the original grant.

**d) Column Level Revocation**

```sql
REVOKE SELECT ON HR.EMP_Details(Salary, Bonus) FROM PayrollStaff;
```

*   **Explanation:** Removes the `SELECT` permission specifically on the `Salary` and `Bonus` columns of `HR.EMP_Details` from `PayrollStaff`.

**e) `CASCADE` Option**

```sql
-- Assumes HRManagers had SELECT WITH GRANT OPTION
REVOKE SELECT ON HR.Departments FROM HRManagers CASCADE;
```

*   **Explanation:** Revokes the `SELECT` permission on `HR.Departments` from `HRManagers`. Because `CASCADE` is specified, if any member of `HRManagers` had previously granted `SELECT` on this table to *other* principals (using their `GRANT OPTION`), those subsequent grants are also revoked.

**f) Procedure Execution Revocation**

```sql
REVOKE EXECUTE ON HR.AddNewEmployee FROM HRClerks;
```

*   **Explanation:** Removes the permission for `HRClerks` to execute the `HR.AddNewEmployee` stored procedure.

**g) View Access Revocation**

```sql
REVOKE SELECT ON HR.EmployeeSummary FROM Reports;
```

*   **Explanation:** Removes `SELECT` permission on the `HR.EmployeeSummary` view from the `Reports` role.

**h) Database Level Revocation**

```sql
REVOKE CREATE TABLE FROM HRManagers;
REVOKE CREATE VIEW FROM DataAnalysts;
```

*   **Explanation:** Removes database-wide permissions like `CREATE TABLE` or `CREATE VIEW` from the specified roles.

**i) Role Permission Revocation**

```sql
REVOKE SELECT ON HR.SalaryReports FROM PayrollManagers;
```

*   **Explanation:** Removes a specific permission (`SELECT` on `HR.SalaryReports`) from an entire role (`PayrollManagers`).

**j) Server Level Revocation**

```sql
-- Assumes run in master context or by sysadmin
REVOKE VIEW SERVER STATE FROM ITSupport; -- Revoke from Login or Server Role
REVOKE ALTER ANY DATABASE FROM DBAdmins; -- Revoke from Login or Server Role
```

*   **Explanation:** Removes server-wide permissions from server principals (Logins or Server Roles).

**k) Application Role Revocation**

```sql
REVOKE SELECT ON HR.EMP_Details FROM HRApplication;
```

*   **Explanation:** Removes permissions previously granted to an application role.

**l) Function Execution Revocation**

```sql
REVOKE EXECUTE ON HR.CalculateTax FROM PayrollStaff;
```

*   **Explanation:** Removes permission to execute a specific user-defined function.

**m) Backup Permission Revocation**

```sql
REVOKE BACKUP DATABASE FROM BackupOperators;
REVOKE BACKUP LOG FROM BackupOperators;
```

*   **Explanation:** Removes the ability for members of the `BackupOperators` role to perform backups.

**n) Grant Option Revocation**

```sql
-- Assumes ProjectManagers had SELECT ON HR.Projects WITH GRANT OPTION
REVOKE GRANT OPTION FOR SELECT ON HR.Projects FROM ProjectManagers;
```

*   **Explanation:** Uses `REVOKE GRANT OPTION FOR` to remove *only* the ability for `ProjectManagers` to grant `SELECT` permission on `HR.Projects` to others. They *retain* the underlying `SELECT` permission for themselves, but can no longer delegate it.

**o) Clean Up All Permissions (Object Level)**

```sql
-- REVOKE ALL is generally discouraged; be specific.
-- This removes all object-level permissions on HR.EMP_Details from Contractors
REVOKE ALL ON HR.EMP_Details FROM Contractors;
```

*   **Explanation:** `REVOKE ALL` removes all applicable object-level permissions (like `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `REFERENCES`) on the specified object (`HR.EMP_Details`) from the principal (`Contractors`). Using `ALL` is generally discouraged in favor of revoking specific permissions for clarity and control.

## 3. Targeted Interview Questions (Based on `24_revoke.sql`)

**Question 1:** If `HRClerks` were initially granted `SELECT ON SCHEMA::HR` and later you execute `REVOKE SELECT ON HR.EMP_Details FROM HRClerks;`, can members of `HRClerks` still select from `HR.EMP_Details`? Why or why not?

**Solution 1:** Yes, they likely still can. Revoking the object-level permission (`ON HR.EMP_Details`) only removes that specific grant (or a corresponding deny). It does **not** remove permissions inherited from higher scopes. Since they still have `SELECT ON SCHEMA::HR`, they inherit the right to select from all objects within that schema, including `HR.EMP_Details`. To prevent access in this case, you would need to either `REVOKE` the schema-level permission or use `DENY SELECT ON HR.EMP_Details TO HRClerks;`.

**Question 2:** What is the difference between `REVOKE SELECT ON HR.Departments FROM HRManagers;` and `REVOKE GRANT OPTION FOR SELECT ON HR.Departments FROM HRManagers;`?

**Solution 2:**

*   `REVOKE SELECT ON HR.Departments FROM HRManagers;`: Removes the actual `SELECT` permission from the `HRManagers` role. They (and members inheriting *only* through this role) can no longer select from the table. If they had the `GRANT OPTION`, that is implicitly removed as well since the base permission is gone.
*   `REVOKE GRANT OPTION FOR SELECT ON HR.Departments FROM HRManagers;`: Removes *only* the ability for `HRManagers` to grant `SELECT` permission on `HR.Departments` to others. They *keep* the underlying `SELECT` permission for themselves but lose the ability to delegate it.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which command removes a previously granted permission: `DENY` or `REVOKE`?
    *   **Answer:** `REVOKE`. (`DENY` explicitly forbids permission).
2.  **[Easy]** Can `REVOKE` remove a permission that was inherited through role membership?
    *   **Answer:** No. `REVOKE` operates on specific permission entries (direct grants or denies to a user/role). It cannot remove permissions that a user has solely because they are a member of a role that possesses the permission. To remove inherited permissions, you must either remove the user from the role (`ALTER ROLE ... DROP MEMBER`) or revoke the permission from the role itself.
3.  **[Medium]** If `UserA` was granted `SELECT WITH GRANT OPTION` on `TableX`, and `UserA` then granted `SELECT` on `TableX` to `UserB`. What happens to `UserB`'s permission if you execute `REVOKE SELECT ON TableX FROM UserA CASCADE;`? What if you execute it without `CASCADE`?
    *   **Answer:**
        *   `WITH CASCADE`: `UserA` loses `SELECT` permission, and because `CASCADE` is specified, `UserB` (who received the grant from `UserA`) *also* loses the `SELECT` permission.
        *   `WITHOUT CASCADE`: The `REVOKE` statement will fail because `UserA` has granted the permission to others (`UserB`). You must use `CASCADE` to revoke when the permission has been re-granted.
4.  **[Medium]** Can you `REVOKE` permissions from built-in roles like `public` or `db_owner`? Is it generally effective or advisable?
    *   **Answer:** You *can* technically issue `REVOKE` statements against fixed roles like `public` or `db_owner`. However, revoking fundamental permissions from `public` can break basic database functionality for all users. Revoking permissions from powerful roles like `db_owner` or `sysadmin` is often ineffective as members of these roles typically bypass many standard permission checks. It's better to control membership *in* these roles rather than trying to revoke their inherent permissions.
5.  **[Medium]** What happens if you try to `REVOKE` a permission that was never explicitly granted or denied to the specified principal?
    *   **Answer:** The `REVOKE` statement completes successfully but has no effect and does not raise an error. It simply removes the specified permission entry if it exists; if it doesn't exist, nothing happens.
6.  **[Medium]** Does `REVOKE ALL ON MyTable FROM UserA;` remove permissions like `CONTROL` or `TAKE OWNERSHIP`?
    *   **Answer:** No. `REVOKE ALL` typically refers to the common object-level DML permissions (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `REFERENCES`). It does *not* usually include control-type permissions like `CONTROL`, `TAKE OWNERSHIP`, or `ALTER`. These higher-level permissions need to be revoked explicitly if granted.
7.  **[Hard]** If `UserA` is denied `SELECT` on `TableX`, what is the effect of executing `REVOKE SELECT ON TableX FROM UserA;`?
    *   **Answer:** Executing `REVOKE SELECT ON TableX FROM UserA;` removes the explicit `DENY` that was placed on `UserA`. After the `REVOKE`, `UserA`'s ability to select depends on other permissions. If they have no other `GRANT` (directly or via roles), they still won't be able to select (default deny). If they *do* inherit a `GRANT SELECT` from a role, they *will* now be able to select because the overriding `DENY` has been removed.
8.  **[Hard]** Can you `REVOKE` server-level permissions (like `VIEW SERVER STATE`) while connected to a user database (e.g., `HRSystem`), or must you be in the `master` database?
    *   **Answer:** You must typically be connected to the `master` database to `GRANT`, `DENY`, or `REVOKE` server-level permissions. These permissions apply to the instance, and their metadata is managed within `master`.
9.  **[Hard]** If a permission was granted using the `AS grantor_principal` clause (e.g., `GRANT SELECT ... TO UserA AS AdminUser;`), how do you revoke it? Do you revoke `FROM UserA` or `FROM AdminUser`?
    *   **Answer:** You revoke the permission `FROM` the grantee (`UserA`), just like a normal revoke. The `AS` clause only affects the metadata recording *who* originally issued the grant; it doesn't change *who* received the permission.
        ```sql
        REVOKE SELECT ... FROM UserA;
        ```
10. **[Hard/Tricky]** `UserA` is a member of `Role1` and `Role2`. `Role1` has `GRANT SELECT ON TableX`. `Role2` has `GRANT SELECT ON TableX WITH GRANT OPTION`. If you execute `REVOKE GRANT OPTION FOR SELECT ON TableX FROM Role2;`, can `UserA` still select from `TableX`? Can `UserA` grant `SELECT` on `TableX` to others?
    *   **Answer:**
        *   **Can UserA select?** Yes. `UserA` still inherits the basic `SELECT` permission from `Role1` (and also retains the underlying `SELECT` from `Role2` as only the grant option was revoked).
        *   **Can UserA grant select?** No. The `REVOKE GRANT OPTION FOR` specifically removed the ability to delegate the permission inherited from `Role2`. Since `Role1` did not have `WITH GRANT OPTION`, `UserA` no longer inherits the grant option from any role and therefore cannot grant `SELECT` on `TableX` to others.
