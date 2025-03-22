-- =============================================
-- SQL Server CERTIFICATES and KEYS Guide
-- =============================================

USE HRSystem;
GO

-- 1. Creating Certificates
-- Create a self-signed certificate
CREATE CERTIFICATE HRSystemCert
    WITH SUBJECT = 'Certificate for HRSystem Database',
    EXPIRY_DATE = '2025-12-31';
GO

-- Create a certificate from a file
-- CREATE CERTIFICATE HRSystemCertFromFile
--     FROM FILE = 'C:\Certificates\HRSystemCert.cer'
--     WITH PRIVATE KEY (FILE = 'C:\Certificates\HRSystemCert.pvk',
--     DECRYPTION BY PASSWORD = 'StrongP@ssw0rd');
-- GO

-- Create a certificate with encryption options
CREATE CERTIFICATE EncryptionCert
    WITH SUBJECT = 'Certificate for Data Encryption',
    START_DATE = '2023-01-01',
    EXPIRY_DATE = '2025-12-31',
    ENCRYPTION BY PASSWORD = 'StrongP@ssw0rd';
GO

-- 2. Altering Certificates
-- Change certificate properties
ALTER CERTIFICATE HRSystemCert
    WITH PRIVATE KEY (DECRYPTION BY PASSWORD = 'OldP@ssw0rd',
    ENCRYPTION BY PASSWORD = 'NewP@ssw0rd');
GO

-- 3. Backing Up and Restoring Certificates
-- Backup a certificate to a file
-- BACKUP CERTIFICATE HRSystemCert
--     TO FILE = 'C:\Backups\HRSystemCert.cer'
--     WITH PRIVATE KEY (FILE = 'C:\Backups\HRSystemCert.pvk',
--     ENCRYPTION BY PASSWORD = 'BackupP@ssw0rd');
-- GO

-- 4. Creating Symmetric Keys
-- Create a symmetric key with password
CREATE SYMMETRIC KEY HRDataKey
    WITH ALGORITHM = AES_256,
    IDENTITY_VALUE = 'HR Department Data Encryption Key',
    KEY_SOURCE = 'Strong Random Phrase for Key Generation',
    ENCRYPTION BY PASSWORD = 'StrongKeyP@ssw0rd';
GO

-- Create a symmetric key encrypted by certificate
CREATE SYMMETRIC KEY EmployeeDataKey
    WITH ALGORITHM = AES_256,
    KEY_SOURCE = 'Employee Data Protection Key',
    ENCRYPTION BY CERTIFICATE EncryptionCert;
GO

-- Create a symmetric key with multiple encryptions
CREATE SYMMETRIC KEY PayrollDataKey
    WITH ALGORITHM = AES_256,
    ENCRYPTION BY CERTIFICATE EncryptionCert,
    ENCRYPTION BY PASSWORD = 'PayrollKeyP@ssw0rd';
GO

-- 5. Opening and Closing Symmetric Keys
-- Open a symmetric key for use
OPEN SYMMETRIC KEY HRDataKey
    DECRYPTION BY PASSWORD = 'StrongKeyP@ssw0rd';
GO

-- Open a key encrypted by certificate
OPEN SYMMETRIC KEY EmployeeDataKey
    DECRYPTION BY CERTIFICATE EncryptionCert
    WITH PASSWORD = 'StrongP@ssw0rd';
GO

-- Close a symmetric key
CLOSE SYMMETRIC KEY HRDataKey;
GO

-- Close all symmetric keys
CLOSE ALL SYMMETRIC KEYS;
GO

-- 6. Altering Symmetric Keys
-- Add additional encryption to an existing key
ALTER SYMMETRIC KEY PayrollDataKey
    ADD ENCRYPTION BY CERTIFICATE HRSystemCert;
GO

-- Remove encryption from a key
ALTER SYMMETRIC KEY PayrollDataKey
    DROP ENCRYPTION BY CERTIFICATE EncryptionCert;
GO

-- 7. Creating Asymmetric Keys
-- Create an asymmetric key
CREATE ASYMMETRIC KEY HRAsymKey
    WITH ALGORITHM = RSA_2048;
GO

-- Create an asymmetric key with a password
CREATE ASYMMETRIC KEY PayrollAsymKey
    WITH ALGORITHM = RSA_2048,
    ENCRYPTION BY PASSWORD = 'AsymKeyP@ssw0rd';
GO

-- Create an asymmetric key from a file
-- CREATE ASYMMETRIC KEY ImportedAsymKey
--     FROM FILE = 'C:\Keys\ImportedKey.pvk'
--     WITH PRIVATE KEY (ENCRYPTION BY PASSWORD = 'ImportKeyP@ssw0rd');
-- GO

-- 8. Using Encryption for Data Protection
-- Example table with encrypted data
CREATE TABLE HR.EmployeeConfidential (
    EmployeeID INT PRIMARY KEY,
    SSN VARBINARY(256),
    BankAccountNumber VARBINARY(256),
    Salary VARBINARY(256)
);
GO

-- Insert encrypted data (after opening the appropriate key)
OPEN SYMMETRIC KEY EmployeeDataKey
    DECRYPTION BY CERTIFICATE EncryptionCert
    WITH PASSWORD = 'StrongP@ssw0rd';

INSERT INTO HR.EmployeeConfidential (EmployeeID, SSN, BankAccountNumber, Salary)
VALUES (1, 
    EncryptByKey(Key_GUID('EmployeeDataKey'), '123-45-6789'),
    EncryptByKey(Key_GUID('EmployeeDataKey'), '9876543210'),
    EncryptByKey(Key_GUID('EmployeeDataKey'), CONVERT(VARCHAR, 75000))
);

CLOSE SYMMETRIC KEY EmployeeDataKey;
GO

-- Query encrypted data
OPEN SYMMETRIC KEY EmployeeDataKey
    DECRYPTION BY CERTIFICATE EncryptionCert
    WITH PASSWORD = 'StrongP@ssw0rd';

SELECT 
    EmployeeID,
    CONVERT(VARCHAR(11), DecryptByKey(SSN)) AS SSN,
    CONVERT(VARCHAR(10), DecryptByKey(BankAccountNumber)) AS BankAccountNumber,
    CONVERT(INT, DecryptByKey(Salary)) AS Salary
FROM HR.EmployeeConfidential;

CLOSE SYMMETRIC KEY EmployeeDataKey;
GO

-- 9. Dropping Encryption Objects
-- Drop a symmetric key
DROP SYMMETRIC KEY HRDataKey;
GO

-- Drop an asymmetric key
DROP ASYMMETRIC KEY HRAsymKey;
GO

-- Drop a certificate
DROP CERTIFICATE HRSystemCert;
GO

-- 10. Querying Encryption Metadata
-- List all certificates in the database
SELECT 
    name AS CertificateName,
    certificate_id,
    principal_id,
    pvt_key_encryption_type_desc AS PrivateKeyEncryption,
    issuer_name,
    subject,
    expiry_date,
    start_date,
    thumbprint,
    pvt_key_last_backup_date
FROM sys.certificates
ORDER BY name;
GO

-- List all symmetric keys
SELECT 
    k.name AS KeyName,
    k.symmetric_key_id,
    k.principal_id,
    k.key_algorithm AS Algorithm,
    k.key_length AS KeyLength,
    k.key_guid AS KeyGUID,
    k.create_date,
    k.modify_date,
    c.name AS EncryptingCertificate
FROM sys.symmetric_keys k
LEFT JOIN sys.key_encryptions ke ON k.symmetric_key_id = ke.key_id
LEFT JOIN sys.certificates c ON ke.thumbprint = c.thumbprint
WHERE ke.crypt_type = 'CERTIFICATE'
ORDER BY KeyName;
GO

-- List all asymmetric keys
SELECT 
    name AS KeyName,
    asymmetric_key_id,
    principal_id,
    pvt_key_encryption_type_desc AS PrivateKeyEncryption,
    algorithm_desc AS Algorithm,
    key_length AS KeyLength,
    create_date,
    modify_date,
    pvt_key_last_backup_date
FROM sys.asymmetric_keys
ORDER BY name;
GO

-- List encryption by certificate
SELECT 
    sk.name AS SymmetricKeyName,
    c.name AS CertificateName,
    c.subject AS CertificateSubject,
    c.expiry_date AS CertificateExpiryDate
FROM sys.symmetric_keys sk
JOIN sys.key_encryptions ke ON sk.symmetric_key_id = ke.key_id
JOIN sys.certificates c ON ke.thumbprint = c.thumbprint
WHERE ke.crypt_type = 'CERTIFICATE'
ORDER BY SymmetricKeyName, CertificateName;
GO

-- List database principals using certificates and keys
SELECT 
    dp.name AS PrincipalName,
    dp.type_desc AS PrincipalType,
    CASE 
        WHEN c.name IS NOT NULL THEN 'Certificate: ' + c.name
        WHEN ak.name IS NOT NULL THEN 'Asymmetric Key: ' + ak.name
        ELSE NULL
    END AS AuthenticationMethod
FROM sys.database_principals dp
LEFT JOIN sys.certificates c ON dp.sid = c.sid
LEFT JOIN sys.asymmetric_keys ak ON dp.sid = ak.sid
WHERE dp.type IN ('C', 'K')
ORDER BY PrincipalType, PrincipalName;
GO