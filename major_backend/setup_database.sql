USE spottr;
GO

IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL
DROP TABLE dbo.Users;
GO

CREATE TABLE Users (
    id INT IDENTITY(1,1) PRIMARY KEY,
    firebaseUid NVARCHAR(255) NOT NULL UNIQUE,
    fullName NVARCHAR(255),
    email NVARCHAR(255),
    phone NVARCHAR(50),
    gender NVARCHAR(20),
    age INT,
    weight INT,
    height INT,
    createdAt DATETIME DEFAULT GETDATE(),
    updatedAt DATETIME DEFAULT GETDATE()
);
GO

PRINT 'Users table recreated successfully.';
