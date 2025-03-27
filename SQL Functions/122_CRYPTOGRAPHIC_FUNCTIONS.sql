/*
    FILEPATH: c:\AI Use and Deveopment\Study SQL\SQL Functions\122_CRYPTOGRAPHIC_FUNCTIONS.sql
    
    This script demonstrates the usage of SQL Server Cryptographic Functions
    using the HRSystem database. These functions help in securing sensitive
    data through encryption, hashing, and digital signatures.

    Cryptographic Functions covered:
    1. HASHBYTES - Generate hash values
    2. CERTENCODED - Get certificate's encoded form
    3. CERTPRIVATEKEY - Get certificate's private key
    4. ENCRYPTBYASYMKEY - Encrypt using asymmetric key
    5. ENCRYPTBYPASSPHRASE - Encrypt using passphrase
    6. SIGNBYASYMKEY - Sign data using asymmetric key
    7. SIGNBYCERT - Sign data using certificate
    8. VERIFY_SIGNBYCERT - Verify certificate signature
    9. VERIFY_SIGNBYASYMKEY - Verify asymmetric key signature
*/

USE HRSystem;
GO

-- Create necessary security objects if not exists
IF NOT EXISTS (SELECT * FROM sys.asymmetric_keys WHERE name = 'HRSystemAsymKey')
BEGIN
    -- Create master key if not exists
    IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE symmetric_key_id = 101)
    BEGIN
        CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'MyStr0ngP@ssw0rd123';
    END

    -- Create certificate
    CREATE CERTIFICATE HRSystemCert
    WITH SUBJECT = 'HR System Security Certificate',
    EXPIRY_DATE = '2025-12-31';

    -- Create asymmetric key
    CREATE ASYMMETRIC KEY HRSystemAsymKey
    WITH ALGORITHM = RSA_2048
    ENCRYPTION BY PASSWORD = 'AsymK3yP@ssw0rd';
END

-- Create tables for storing encrypted data if not exists
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[HR].[EncryptedData]') AND type in (N'U'))
BEGIN
    CREATE TABLE HR.EncryptedData (
        DataID INT PRIMARY KEY IDENTITY(1,1),
        Description NVARCHAR(100),
        HashedData VARBINARY(8000),
        EncryptedValue VARBINARY(8000),
        Signature VARBINARY(8000),
        CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
        LastModified DATETIME2,
        ModifiedBy NVARCHAR(50)
    );
END

-- 1. HASHBYTES - Generate hash values for sensitive data
DECLARE @SensitiveData NVARCHAR(100) = 'Confidential Information';

INSERT INTO HR.EncryptedData (Description, HashedData, ModifiedBy)
VALUES (
    'Hashed using SHA2_256',
    HASHBYTES('SHA2_256', @SensitiveData),
    SYSTEM_USER
);

-- 2. CERTENCODED - Get certificate information
SELECT 
    'HRSystemCert' AS CertificateName,
    CERTENCODED(CERT_ID('HRSystemCert')) AS EncodedCertificate,
    'Certificate encoded form' AS Description;

-- 3. CERTPRIVATEKEY - Get private key information
SELECT 
    'HRSystemCert' AS CertificateName,
    CERTPRIVATEKEY(CERT_ID('HRSystemCert')) AS PrivateKeyInfo,
    'Certificate private key info' AS Description;

-- 4. ENCRYPTBYASYMKEY - Encrypt data using asymmetric key
DECLARE @DataToEncrypt NVARCHAR(100) = 'Sensitive employee data';

INSERT INTO HR.EncryptedData (Description, EncryptedValue, ModifiedBy)
VALUES (
    'Encrypted by asymmetric key',
    ENCRYPTBYASYMKEY(
        ASYMKEY_ID('HRSystemAsymKey'),
        @DataToEncrypt
    ),
    SYSTEM_USER
);

-- 5. ENCRYPTBYPASSPHRASE - Encrypt using passphrase
DECLARE @Passphrase NVARCHAR(100) = 'MySecurePassphrase123';
DECLARE @DataForPassphrase NVARCHAR(100) = 'Data encrypted with passphrase';

INSERT INTO HR.EncryptedData (Description, EncryptedValue, ModifiedBy)
VALUES (
    'Encrypted by passphrase',
    ENCRYPTBYPASSPHRASE(
        @Passphrase,
        @DataForPassphrase
    ),
    SYSTEM_USER
);

-- 6. SIGNBYASYMKEY - Sign data using asymmetric key
DECLARE @DataToSign NVARCHAR(100) = 'Data requiring signature';

INSERT INTO HR.EncryptedData (Description, Signature, ModifiedBy)
VALUES (
    'Signed by asymmetric key',
    SIGNBYASYMKEY(
        ASYMKEY_ID('HRSystemAsymKey'),
        @DataToSign,
        'SHA2_256'
    ),
    SYSTEM_USER
);

-- 7. SIGNBYCERT - Sign data using certificate
DECLARE @CertData NVARCHAR(100) = 'Data signed by certificate';

INSERT INTO HR.EncryptedData (Description, Signature, ModifiedBy)
VALUES (
    'Signed by certificate',
    SIGNBYCERT(
        CERT_ID('HRSystemCert'),
        @CertData,
        'SHA2_256'
    ),
    SYSTEM_USER
);

-- 8. VERIFY_SIGNBYCERT - Verify certificate signature
SELECT 
    DataID,
    Description,
    CASE 
        WHEN VERIFY_SIGNBYCERT(
            CERT_ID('HRSystemCert'),
            'Data signed by certificate',
            Signature,
            'SHA2_256'
        ) = 1 THEN 'Valid'
        ELSE 'Invalid'
    END AS SignatureStatus
FROM HR.EncryptedData
WHERE Description = 'Signed by certificate';

-- 9. VERIFY_SIGNBYASYMKEY - Verify asymmetric key signature
SELECT 
    DataID,
    Description,
    CASE 
        WHEN VERIFY_SIGNBYASYMKEY(
            ASYMKEY_ID('HRSystemAsymKey'),
            'Data requiring signature',
            Signature,
            'SHA2_256'
        ) = 1 THEN 'Valid'
        ELSE 'Invalid'
    END AS SignatureStatus
FROM HR.EncryptedData
WHERE Description = 'Signed by asymmetric key';

-- Create a view for encryption analysis
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[HR].[EncryptionAnalysis]'))
BEGIN
    EXECUTE sp_executesql N'
    CREATE VIEW HR.EncryptionAnalysis
    AS
    SELECT 
        Description,
        COUNT(*) AS OperationCount,
        MAX(CreatedDate) AS LastOperation,
        MAX(LastModified) AS LastModified,
        MAX(ModifiedBy) AS LastModifiedBy,
        CASE
            WHEN HashedData IS NOT NULL THEN ''Hashed''
            WHEN EncryptedValue IS NOT NULL THEN ''Encrypted''
            WHEN Signature IS NOT NULL THEN ''Signed''
            ELSE ''Unknown''
        END AS OperationType
    FROM HR.EncryptedData
    GROUP BY 
        Description,
        CASE
            WHEN HashedData IS NOT NULL THEN ''Hashed''
            WHEN EncryptedValue IS NOT NULL THEN ''Encrypted''
            WHEN Signature IS NOT NULL THEN ''Signed''
            ELSE ''Unknown''
        END;
    ';
END

-- Example of analyzing encryption operations
SELECT 
    Description,
    OperationType,
    OperationCount,
    LastOperation,
    LastModifiedBy
FROM HR.EncryptionAnalysis
ORDER BY LastOperation DESC;

-- Cleanup (optional)
-- DROP ASYMMETRIC KEY HRSystemAsymKey;
-- DROP CERTIFICATE HRSystemCert;
-- DROP MASTER KEY;