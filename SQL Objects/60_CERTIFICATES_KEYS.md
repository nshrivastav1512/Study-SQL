# SQL Deep Dive: Certificates and Keys (Symmetric/Asymmetric)

## 1. Introduction: Encryption and Authentication Artifacts

SQL Server provides several cryptographic objects – Certificates, Symmetric Keys, and Asymmetric Keys – that serve various security purposes, primarily related to:

*   **Data Encryption:** Protecting sensitive data at rest within the database.
*   **Authentication:** Providing alternative methods for logins or users to authenticate (instead of passwords or Windows auth).
*   **Code Signing:** Signing modules (procedures, functions, triggers) to grant them permissions based on the signature, rather than the caller's permissions.

**Key Object Types:**

1.  **Certificates:** Public key certificates containing a public/private key pair. They adhere to the X.509 standard. Can be self-signed by SQL Server or created from external files. Used for encrypting other keys, signing modules, authenticating logins/users, or securing endpoints (like database mirroring).
2.  **Symmetric Keys:** Use a single key for both encryption and decryption. Faster than asymmetric encryption but require a secure way to share the key. In SQL Server, symmetric keys themselves must be encrypted for storage, typically using a password, certificate, asymmetric key, or the Database Master Key (DMK). Used primarily for encrypting column data (`EncryptByKey`/`DecryptByKey`). Supported algorithms include AES, DES, Triple DES, RC4, etc.
3.  **Asymmetric Keys:** Use a mathematically related public/private key pair. The public key can encrypt data or verify signatures, while only the corresponding private key can decrypt data or create signatures. Slower than symmetric encryption but simplifies key distribution (public key can be shared). Used for encrypting symmetric keys, signing modules, or authenticating logins/users. SQL Server primarily supports RSA algorithms.

**Encryption Hierarchy:** SQL Server uses a hierarchy to protect keys: Service Master Key (SMK) protects the Database Master Key (DMK), which can protect Certificates or Passwords, which in turn can protect Asymmetric Keys or Symmetric Keys.

## 2. Certificates and Keys in Action: Analysis of `60_CERTIFICATES_KEYS.sql`

This script demonstrates creating, managing, and using these cryptographic objects.

**a) Creating Certificates (`CREATE CERTIFICATE`)**

```sql
-- Self-signed
CREATE CERTIFICATE HRSystemCert WITH SUBJECT = '...', EXPIRY_DATE = '...';
-- From file (Conceptual)
-- CREATE CERTIFICATE ... FROM FILE = '...' WITH PRIVATE KEY (FILE = '...', DECRYPTION BY PASSWORD = '...');
-- With password protection for private key
CREATE CERTIFICATE EncryptionCert WITH SUBJECT = '...', ENCRYPTION BY PASSWORD = '...';
```

*   **Explanation:** Creates certificate objects. They can be self-signed within SQL Server or imported. The private key associated with the certificate can be protected by the Database Master Key (default) or by a user-supplied password (`ENCRYPTION BY PASSWORD`). `SUBJECT` and `EXPIRY_DATE` are important metadata.

**b) Altering Certificates (`ALTER CERTIFICATE`)**

```sql
ALTER CERTIFICATE HRSystemCert WITH PRIVATE KEY (DECRYPTION BY PASSWORD = 'Old', ENCRYPTION BY PASSWORD = 'New');
```

*   **Explanation:** Primarily used to change the password protection for the certificate's private key.

**c) Backing Up Certificates (`BACKUP CERTIFICATE`)**

```sql
-- BACKUP CERTIFICATE HRSystemCert TO FILE = '...' WITH PRIVATE KEY (FILE = '...', ENCRYPTION BY PASSWORD = '...');
```

*   **Explanation:** Exports the certificate (public key) and optionally its private key to files. The private key file *must* be encrypted with a password during backup. Essential for disaster recovery or moving certificates.

**d) Creating Symmetric Keys (`CREATE SYMMETRIC KEY`)**

```sql
-- Encrypted by Password
CREATE SYMMETRIC KEY HRDataKey WITH ALGORITHM = AES_256, ..., ENCRYPTION BY PASSWORD = '...';
-- Encrypted by Certificate
CREATE SYMMETRIC KEY EmployeeDataKey WITH ALGORITHM = AES_256, ..., ENCRYPTION BY CERTIFICATE EncryptionCert;
-- Encrypted by Multiple Methods
CREATE SYMMETRIC KEY PayrollDataKey WITH ..., ENCRYPTION BY CERTIFICATE ..., ENCRYPTION BY PASSWORD = '...';
```

*   **Explanation:** Creates a symmetric key. Requires specifying an `ALGORITHM` (e.g., `AES_128`, `AES_192`, `AES_256`, `TRIPLE_DES`). Crucially, requires at least one `ENCRYPTION BY` clause (Password, Certificate, Asymmetric Key, or implicitly the DMK if none specified) to protect the key itself within the database.

**e) Opening/Closing Symmetric Keys (`OPEN SYMMETRIC KEY`, `CLOSE SYMMETRIC KEY`)**

```sql
-- Open using password
OPEN SYMMETRIC KEY HRDataKey DECRYPTION BY PASSWORD = '...';
-- Open using certificate (requires certificate's private key password if applicable)
OPEN SYMMETRIC KEY EmployeeDataKey DECRYPTION BY CERTIFICATE EncryptionCert WITH PASSWORD = '...';
-- Close specific key
CLOSE SYMMETRIC KEY HRDataKey;
-- Close all keys opened in the session
CLOSE ALL SYMMETRIC KEYS;
```

*   **Explanation:** Before a symmetric key can be used for encryption (`EncryptByKey`) or decryption (`DecryptByKey`) within a session, it must be **opened**. Opening requires providing the credential (password, or unlocking the encrypting certificate/key) used to protect the symmetric key. Keys are automatically closed when the session ends, but explicit `CLOSE` is good practice.

**f) Altering Symmetric Keys (`ALTER SYMMETRIC KEY`)**

```sql
ALTER SYMMETRIC KEY PayrollDataKey ADD ENCRYPTION BY CERTIFICATE HRSystemCert;
ALTER SYMMETRIC KEY PayrollDataKey DROP ENCRYPTION BY CERTIFICATE EncryptionCert;
```

*   **Explanation:** Allows adding or removing encryption methods protecting the symmetric key (e.g., adding certificate encryption alongside password encryption for key management flexibility).

**g) Creating Asymmetric Keys (`CREATE ASYMMETRIC KEY`)**

```sql
CREATE ASYMMETRIC KEY HRAsymKey WITH ALGORITHM = RSA_2048; -- Protected by DMK
CREATE ASYMMETRIC KEY PayrollAsymKey WITH ALGORITHM = RSA_2048, ENCRYPTION BY PASSWORD = '...'; -- Protected by password
-- CREATE ASYMMETRIC KEY ... FROM FILE = '...' ...; -- Import from file
```

*   **Explanation:** Creates an asymmetric key pair (public/private). Requires specifying an `ALGORITHM` (e.g., `RSA_512`, `RSA_1024`, `RSA_2048`). The private key can be protected by the DMK (default) or a password. Can also be created from existing key files.

**h) Using Encryption for Data (`EncryptByKey`, `DecryptByKey`)**

```sql
CREATE TABLE HR.EmployeeConfidential (..., SSN VARBINARY(256), ...);
-- Open the key first!
OPEN SYMMETRIC KEY EmployeeDataKey DECRYPTION BY ...;
-- Encrypt during INSERT
INSERT INTO HR.EmployeeConfidential (..., SSN, ...) VALUES (..., EncryptByKey(Key_GUID('EmployeeDataKey'), '123-45-6789'), ...);
-- Decrypt during SELECT
SELECT ..., CONVERT(VARCHAR(11), DecryptByKey(SSN)) AS SSN, ... FROM HR.EmployeeConfidential;
-- Close the key!
CLOSE SYMMETRIC KEY EmployeeDataKey;
```

*   **Explanation:** Demonstrates column-level encryption using a symmetric key.
    1.  The symmetric key (`EmployeeDataKey`) must be opened first using the correct decryption method.
    2.  `EncryptByKey(Key_GUID('KeyName'), 'plaintext')` encrypts the data using the opened key. The result is `VARBINARY`.
    3.  `DecryptByKey(Ciphertext)` decrypts the `VARBINARY` data using the opened key. Requires `CONVERT` or `CAST` back to the original data type.
    4.  The key must be closed (`CLOSE SYMMETRIC KEY`) when finished.

**i) Dropping Encryption Objects (`DROP ...`)**

```sql
DROP SYMMETRIC KEY HRDataKey;
DROP ASYMMETRIC KEY HRAsymKey;
DROP CERTIFICATE HRSystemCert;
```

*   **Explanation:** Removes the cryptographic objects. Fails if the object is still in use (e.g., a key encrypting another key, a certificate used by a user or endpoint). Dependencies must be removed first. **Dropping a key or certificate used for encryption makes the encrypted data permanently unrecoverable unless a backup exists.**

**j) Querying Encryption Metadata (System Views)**

```sql
SELECT name, subject, expiry_date, ... FROM sys.certificates;
SELECT k.name, k.key_algorithm, ..., c.name AS EncryptingCert FROM sys.symmetric_keys k LEFT JOIN sys.key_encryptions ke ON ... LEFT JOIN sys.certificates c ON ...;
SELECT name, algorithm_desc, key_length, ... FROM sys.asymmetric_keys;
-- Find principals using certs/keys
SELECT dp.name, ..., c.name, ak.name FROM sys.database_principals dp LEFT JOIN sys.certificates c ON ... LEFT JOIN sys.asymmetric_keys ak ON ... WHERE dp.type IN ('C', 'K');
```

*   **Explanation:** Uses system views `sys.certificates`, `sys.symmetric_keys`, `sys.asymmetric_keys`, `sys.key_encryptions`, and `sys.database_principals` to retrieve metadata about existing keys and certificates, including their properties, how they are encrypted, and which users might be mapped to them.

## 3. Targeted Interview Questions (Based on `60_CERTIFICATES_KEYS.sql`)

**Question 1:** What is the difference between symmetric and asymmetric encryption in SQL Server, and which is generally faster for encrypting/decrypting large amounts of data?

**Solution 1:**

*   **Symmetric Encryption:** Uses the **same key** for both encryption and decryption. Requires a secure method to manage and share this single key. Algorithms include AES, Triple DES.
*   **Asymmetric Encryption:** Uses a **pair** of keys: a public key (for encryption or signature verification) and a private key (for decryption or signing). The public key can be shared without compromising the private key. Algorithms include RSA.
*   **Speed:** **Symmetric encryption** is significantly faster than asymmetric encryption and is therefore preferred for encrypting large amounts of column data using `EncryptByKey`/`DecryptByKey`. Asymmetric encryption is typically used for encrypting smaller amounts of data, like encrypting the symmetric keys themselves, or for digital signatures.

**Question 2:** Before you can use `EncryptByKey` or `DecryptByKey` with a specific symmetric key in your session, what command must you execute first, and what information might you need to provide?

**Solution 2:** You must first execute the `OPEN SYMMETRIC KEY KeyName ...` command. You need to provide the necessary credential to decrypt the symmetric key itself, using the `DECRYPTION BY ...` clause. This might be `DECRYPTION BY PASSWORD = '...'` if the key is password-protected, or `DECRYPTION BY CERTIFICATE CertName` (potentially with `WITH PASSWORD = '...'` if the certificate's private key is password protected), or `DECRYPTION BY ASYMMETRIC KEY KeyName`.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which function encrypts data using a symmetric key: `EncryptByKey` or `DecryptByKey`?
    *   **Answer:** `EncryptByKey`.
2.  **[Easy]** Can you create a symmetric key without specifying how it should be encrypted (e.g., by password, certificate)? If so, how is it protected?
    *   **Answer:** Yes. If no `ENCRYPTION BY` clause is specified, the symmetric key is automatically encrypted using the **Database Master Key (DMK)**. The DMK itself is encrypted by the Service Master Key (SMK).
3.  **[Medium]** What happens if you `DROP CERTIFICATE MyCert;` when `MyCert` was used to encrypt `SymmetricKey1` (`CREATE SYMMETRIC KEY SymmetricKey1 ... ENCRYPTION BY CERTIFICATE MyCert;`)? Can you still use `SymmetricKey1`?
    *   **Answer:** Dropping the certificate `MyCert` makes `SymmetricKey1` unusable *if* the certificate was the *only* method used to encrypt it. You would no longer be able to `OPEN` `SymmetricKey1` because the means to decrypt it (the certificate) is gone. Any data encrypted with `SymmetricKey1` would become unrecoverable unless you had backups of the certificate and its private key password. If the symmetric key was also encrypted by another method (e.g., a password), you could potentially still open it using that alternative method.
4.  **[Medium]** What is the purpose of backing up a certificate *with its private key*?
    *   **Answer:** Backing up the certificate with its private key is crucial for disaster recovery or migrating the certificate to another server. Without the private key backup (and its corresponding decryption password), you cannot restore the certificate on another instance in a way that allows it to be used for decryption or signing operations that require the private key.
5.  **[Medium]** Can you use `EncryptByKey` with an asymmetric key?
    *   **Answer:** No. `EncryptByKey` and `DecryptByKey` work only with **symmetric** keys. For asymmetric encryption/decryption, you use the functions `EncryptByAsymKey()` / `DecryptByAsymKey()` or `EncryptByCert()` / `DecryptByCert()`.
6.  **[Medium]** Does opening a symmetric key (`OPEN SYMMETRIC KEY`) require special permissions beyond accessing the database?
    *   **Answer:** Yes. To open a symmetric key, the user typically needs `CONTROL` permission on the key itself, or `VIEW DEFINITION` permission plus the necessary permission to access the encrypting principal (e.g., `CONTROL` on the certificate if encrypted by certificate, or knowledge of the password if encrypted by password).
7.  **[Hard]** What is the difference between `EncryptByKey` and Transparent Data Encryption (TDE)? When would you use each?
    *   **Answer:**
        *   `EncryptByKey`: Provides **column-level encryption**. You explicitly call functions (`EncryptByKey`/`DecryptByKey`) in your code to encrypt/decrypt data in specific `VARBINARY` columns. Requires key management (`OPEN`/`CLOSE KEY`). Offers granular control over what is encrypted.
        *   **TDE (Transparent Data Encryption):** Provides **database-level encryption at rest**. It encrypts the entire database data (`.mdf`/`.ndf`) and log (`.ldf`) files on disk using a Database Encryption Key (DEK), which is protected by a certificate or asymmetric key in `master`. Encryption/decryption happens transparently in memory during I/O operations. It protects data if the physical files are stolen but does *not* protect data from users with database access.
        *   **Use Cases:** Use `EncryptByKey` for protecting specific sensitive columns within a table from users who might otherwise have access to the table. Use TDE for compliance requirements needing encryption of the entire database at rest (protecting against physical media theft). They can be used together.
8.  **[Hard]** Can you add multiple passwords as encryption methods for a single symmetric key?
    *   **Answer:** No. A symmetric key can be encrypted by *one* password, *one* certificate, *one* asymmetric key, or any combination of these *different types*, but you cannot have multiple password encryptions on the same key. You use `ALTER SYMMETRIC KEY ... ADD/DROP ENCRYPTION BY ...` to manage these protectors.
9.  **[Hard]** What is the Database Master Key (DMK), and how is it typically protected? Why is backing it up important?
    *   **Answer:** The Database Master Key (DMK) is a symmetric key that exists within each database and acts as the root of the encryption hierarchy *within that database*. It's used to encrypt other keys and certificates created within the database if no other explicit encryption method (like a password) is specified. The DMK itself is encrypted by the server-level **Service Master Key (SMK)** using AES_256. Backing up the DMK (`BACKUP MASTER KEY`) is crucial because if you restore the database to a different server instance (with a different SMK), you will need to restore the DMK (using the backup password) on the new server before you can access any keys or certificates that were encrypted by it.
10. **[Hard/Tricky]** If you encrypt data using `EncryptByKey` with `AES_256`, what data type should the target column be, and roughly how much larger will the encrypted data be compared to the original plaintext?
    *   **Answer:**
        *   **Data Type:** The target column must be `VARBINARY`. The required size depends on the plaintext size and the encryption algorithm overhead.
        *   **Size Increase:** `VARBINARY(8000)` is the maximum size for non-LOB storage. For `VARBINARY(MAX)`, the limit is 2GB. The size of the ciphertext generated by `EncryptByKey` using AES_256 includes the original data size plus overhead added by the algorithm (padding, initialization vector, etc.). This overhead for AES_256 is typically around 16-32 bytes, plus padding to the block size (16 bytes for AES). So, the `VARBINARY` column needs to be large enough to accommodate the largest possible plaintext *plus* this overhead (e.g., `VARBINARY(256)` might be suitable for encrypting moderately sized strings, but larger columns or `VARBINARY(MAX)` are needed for larger data). It's not a simple percentage increase; there's a fixed overhead plus padding.
