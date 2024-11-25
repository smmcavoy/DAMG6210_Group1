USE AIRLINE
GO

-- Check if the master key exists before creating
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'password123';
END;
GO

CREATE CERTIFICATE AirlineCertificate
WITH SUBJECT = 'Certificate for DOB Encryption';
GO

CREATE SYMMETRIC KEY DOBEncryptionKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE AirlineCertificate;
GO

ALTER TABLE Ticket 
    ADD EncryptedDoB varbinary(128);   
GO  

OPEN SYMMETRIC KEY DOBEncryptionKey
DECRYPTION BY CERTIFICATE AirlineCertificate;

UPDATE Ticket
SET EncryptedDoB = ENCRYPTBYKEY(
    KEY_GUID('DOBEncryptionKey'), 
    CAST(BirthDt AS NVARCHAR(50))
);

CLOSE SYMMETRIC KEY DOBEncryptionKey;
GO

ALTER TABLE Ticket
DROP COLUMN BirthDt
GO
/*
OPEN SYMMETRIC KEY DOBEncryptionKey
DECRYPTION BY CERTIFICATE AirlineCertificate;
SELECT FName, LName,  CAST(CONVERT(NVARCHAR(50),DECRYPTBYKEY(EncryptedDoB)) AS DATE) AS DecryptedDOB FROM Ticket;
CLOSE SYMMETRIC KEY DOBEncryptionKey;
/*