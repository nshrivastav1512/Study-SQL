/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\114_SECURITY_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Security Functions with real-life examples
    using the HRSystem database schemas and tables.

    Security Functions covered:
    1. PWDENCRYPT() - Encrypts a password
    2. PWDCOMPARE() - Compares encrypted passwords
    3. ENCRYPTBYKEY() - Encrypts data using a symmetric key
    4. DECRYPTBYKEY() - Decrypts data using a symmetric key
    5. CERTENCODED() - Returns certificate's public key
    6. CERTPRIVATEKEY() - Returns certificate's private key
    7. SIGNATUREPROPERTY() - Returns signature properties
    8. ORIGINAL_LOGIN() - Returns original login name
    9. HAS_PERMS_BY_NAME() - Checks permissions
*/

USE HRSystem;
GO

-- Create sample tables if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[UserCredentials]') AND type in (N'U'))
BEGIN
    -- Create a master key for the database
    IF NOT EXISTS 
    (SELECT * FROM sys.symmetric_keys WHERE symmetric_key_id = 101)
    BEGIN
        CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'MyStr0ngP@ssw0rd123';
    END

    -- Create a certificate to protect the symmetric key
    IF NOT EXISTS 
    (SELECT * FROM sys.certificates WHERE name = 'UserDataCert')
    BEGIN
        CREATE CERTIFICATE UserDataCert
        WITH SUBJECT = 'Certificate for user data encryption',
        EXPIRY_DATE = '2025-12-31';
    END

    -- Create a symmetric key for data encryption
    IF NOT EXISTS 
    (SELECT * FROM sys.symmetric_keys WHERE name = 'UserDataKey')
    BEGIN
        CREATE SYMMETRIC KEY UserDataKey
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE UserDataCert;
    END

    -- Create table for user credentials
    CREATE TABLE HR.UserCredentials (
        UserID INT PRIMARY KEY IDENTITY(1,1),
        Username NVARCHAR(50) UNIQUE,
        PasswordHash VARBINARY(256),
        Email NVARCHAR(100),
        EncryptedSSN VARBINARY(256),
        LastLoginDate DATETIME2 DEFAULT SYSDATETIME(),
        CreatedBy NVARCHAR(100),
        CreatedDate DATETIME2 DEFAULT SYSDATETIME()
    );

    -- Create table for sensitive data
    CREATE TABLE HR.SensitiveData (
        DataID INT PRIMARY KEY IDENTITY(1,1),
        UserID INT,
        DataType NVARCHAR(50),
        EncryptedData VARBINARY(MAX),
        Signature VARBINARY(MAX),
        LastModified DATETIME2 DEFAULT SYSDATETIME(),
        ModifiedBy NVARCHAR(100)
    );

    -- Create table for access logs
    CREATE TABLE HR.AccessLogs (
        LogID INT PRIMARY KEY IDENTITY(1,1),
        UserID INT,
        AccessType NVARCHAR(50),
        AccessDate DATETIME2 DEFAULT SYSDATETIME(),
        OriginalLogin NVARCHAR(100),
        AccessResult NVARCHAR(20),
        Details NVARCHAR(MAX)
    );
END

-- 1. PWDENCRYPT() - Create encrypted password hashes
DECLARE @Password1 NVARCHAR(50) = 'MySecurePass123';
DECLARE @Password2 NVARCHAR(50) = 'AnotherPass456';

INSERT INTO HR.UserCredentials (Username, PasswordHash, Email, CreatedBy)
VALUES
('john.doe', PWDENCRYPT(@Password1), 'john.doe@email.com', SYSTEM_USER),
('jane.smith', PWDENCRYPT(@Password2), 'jane.smith@email.com', SYSTEM_USER);

-- 2. PWDCOMPARE() - Verify passwords
SELECT 
    Username,
    CASE 
        WHEN PWDCOMPARE('MySecurePass123', PasswordHash) = 1 THEN 'Valid Password'
        ELSE 'Invalid Password'
    END AS PasswordStatus
FROM HR.UserCredentials
WHERE Username = 'john.doe';
/* Output example:
Username   PasswordStatus
john.doe   Valid Password
*/

-- 3. ENCRYPTBYKEY() and 4. DECRYPTBYKEY() - Encrypt and decrypt sensitive data
-- Open the symmetric key
OPEN SYMMETRIC KEY UserDataKey
DECRYPTION BY CERTIFICATE UserDataCert;

-- Encrypt SSN
UPDATE HR.UserCredentials
SET EncryptedSSN = ENCRYPTBYKEY(
    KEY_GUID('UserDataKey'), 
    '123-45-6789'
)
WHERE Username = 'john.doe';

-- Decrypt and view SSN
SELECT 
    Username,
    CONVERT(NVARCHAR(11), 
        DECRYPTBYKEY(EncryptedSSN)
    ) AS DecryptedSSN
FROM HR.UserCredentials
WHERE Username = 'john.doe';
/* Output example:
Username   DecryptedSSN
john.doe   123-45-6789
*/

-- Close the symmetric key
CLOSE SYMMETRIC KEY UserDataKey;

-- 5. CERTENCODED() - Get certificate information
SELECT 
    name AS CertificateName,
    CERTENCODED(certificate_id) AS EncodedCert,
    'Shows binary representation of certificate' AS Description
FROM sys.certificates
WHERE name = 'UserDataCert';
/* Output example:
CertificateName  EncodedCert                  Description
UserDataCert     0x308204A830820390A003...   Shows binary representation of certificate
*/

-- 6. CERTPRIVATEKEY() - Get private key information
SELECT 
    name AS CertificateName,
    CERTPRIVATEKEY(certificate_id) AS PrivateKeyInfo,
    'Shows binary representation of private key' AS Description
FROM sys.certificates
WHERE name = 'UserDataCert';
/* Output example:
CertificateName  PrivateKeyInfo               Description
UserDataCert     0x4B8C12A7F352B8A9D31...   Shows binary representation of private key
*/

-- 7. SIGNATUREPROPERTY() - Check signature properties
DECLARE @Signature VARBINARY(MAX);

-- Create a signature using certificate
SELECT @Signature = SIGNBYCERT(
    CERT_ID('UserDataCert'),
    'Important Data',
    'SHA2_256'
);

-- Insert signed data
INSERT INTO HR.SensitiveData 
(UserID, DataType, EncryptedData, Signature, ModifiedBy)
VALUES
(1, 'Confidential', CAST('Important Data' AS VARBINARY(MAX)), @Signature, SYSTEM_USER);

-- Check signature properties
SELECT 
    DataType,
    SIGNATUREPROPERTY(Signature, 'CounterSignature') AS CounterSign,
    SIGNATUREPROPERTY(Signature, 'Timestamp') AS SignatureTime
FROM HR.SensitiveData;
/* Output example:
DataType      CounterSign  SignatureTime
Confidential  NULL         NULL
*/

-- 8. ORIGINAL_LOGIN() - Track original login information
INSERT INTO HR.AccessLogs 
(UserID, AccessType, OriginalLogin, AccessResult, Details)
VALUES
(1, 'Database Access', ORIGINAL_LOGIN(), 'Success', 'Regular database access');

SELECT 
    AccessType,
    AccessDate,
    OriginalLogin,
    AccessResult
FROM HR.AccessLogs;
/* Output example:
AccessType       AccessDate              OriginalLogin  AccessResult
Database Access  2023-08-20 15:30:45.123 sa            Success
*/

-- 9. HAS_PERMS_BY_NAME() - Check user permissions
SELECT 
    'HR.UserCredentials' AS ObjectName,
    HAS_PERMS_BY_NAME('HR.UserCredentials', 'OBJECT', 'SELECT') AS CanSelect,
    HAS_PERMS_BY_NAME('HR.UserCredentials', 'OBJECT', 'INSERT') AS CanInsert,
    HAS_PERMS_BY_NAME('HR.UserCredentials', 'OBJECT', 'UPDATE') AS CanUpdate,
    HAS_PERMS_BY_NAME('HR.UserCredentials', 'OBJECT', 'DELETE') AS CanDelete;
/* Output example:
ObjectName          CanSelect  CanInsert  CanUpdate  CanDelete
HR.UserCredentials  1          1          1          1
*/

-- Complex example combining multiple security functions
DECLARE @SensitiveInfo NVARCHAR(100) = 'Confidential Employee Data';
DECLARE @UserPassword NVARCHAR(50) = 'SecurePass789';

-- Open symmetric key
OPEN SYMMETRIC KEY UserDataKey
DECRYPTION BY CERTIFICATE UserDataCert;

BEGIN TRY
    -- Create new user with encrypted data
    INSERT INTO HR.UserCredentials
    (Username, PasswordHash, Email, EncryptedSSN, CreatedBy)
    VALUES
    ('robert.brown',
     PWDENCRYPT(@UserPassword),
     'robert.brown@email.com',
     ENCRYPTBYKEY(KEY_GUID('UserDataKey'), '987-65-4321'),
     ORIGINAL_LOGIN());

    -- Get the new user's ID
    DECLARE @NewUserID INT = SCOPE_IDENTITY();

    -- Create signature for sensitive data
    DECLARE @DataSignature VARBINARY(MAX) = SIGNBYCERT(
        CERT_ID('UserDataCert'),
        @SensitiveInfo,
        'SHA2_256'
    );

    -- Store encrypted sensitive data with signature
    INSERT INTO HR.SensitiveData
    (UserID, DataType, EncryptedData, Signature, ModifiedBy)
    VALUES
    (@NewUserID,
     'Employee Info',
     ENCRYPTBYKEY(KEY_GUID('UserDataKey'), @SensitiveInfo),
     @DataSignature,
     SYSTEM_USER);

    -- Log the access
    INSERT INTO HR.AccessLogs
    (UserID, AccessType, OriginalLogin, AccessResult, Details)
    VALUES
    (@NewUserID,
     'Data Creation',
     ORIGINAL_LOGIN(),
     'Success',
     'Created new user with encrypted data');

    -- Verify the data
    SELECT 
        uc.Username,
        CASE 
            WHEN PWDCOMPARE(@UserPassword, uc.PasswordHash) = 1 THEN 'Valid'
            ELSE 'Invalid'
        END AS PasswordCheck,
        CONVERT(NVARCHAR(11), DECRYPTBYKEY(uc.EncryptedSSN)) AS DecryptedSSN,
        CONVERT(NVARCHAR(100), DECRYPTBYKEY(sd.EncryptedData)) AS DecryptedData,
        CASE
            WHEN VERIFYSIGNBYCERT(
                CERT_ID('UserDataCert'),
                CONVERT(NVARCHAR(100), DECRYPTBYKEY(sd.EncryptedData)),
                sd.Signature,
                'SHA2_256'
            ) = 1 THEN 'Valid'
            ELSE 'Invalid'
        END AS SignatureCheck,
        al.AccessType,
        al.AccessDate,
        al.AccessResult
    FROM HR.UserCredentials uc
    JOIN HR.SensitiveData sd ON uc.UserID = sd.UserID
    JOIN HR.AccessLogs al ON uc.UserID = al.UserID
    WHERE uc.Username = 'robert.brown';

END TRY
BEGIN CATCH
    -- Log error
    INSERT INTO HR.AccessLogs
    (UserID, AccessType, OriginalLogin, AccessResult, Details)
    VALUES
    (@NewUserID,
     'Error',
     ORIGINAL_LOGIN(),
     'Failure',
     ERROR_MESSAGE());
END CATCH

-- Close symmetric key
CLOSE SYMMETRIC KEY UserDataKey;
/* Output example:
Username      PasswordCheck  DecryptedSSN  DecryptedData                SignatureCheck  AccessType     AccessDate              AccessResult
robert.brown  Valid          987-65-4321   Confidential Employee Data   Valid           Data Creation  2023-08-20 15:30:45.123  Success
*/