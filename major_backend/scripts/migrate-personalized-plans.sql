-- Create PersonalizedWorkoutPlans table
IF OBJECT_ID('dbo.PersonalizedWorkoutPlans', 'U') IS NOT NULL
DROP TABLE dbo.PersonalizedWorkoutPlans;
GO

CREATE TABLE PersonalizedWorkoutPlans (
    id INT IDENTITY(1,1) PRIMARY KEY,
    firebaseUid NVARCHAR(255) NOT NULL,
    planType NVARCHAR(50) NOT NULL, -- e.g., 'Primary', 'Secondary', 'Balance'
    planTitle NVARCHAR(255) NOT NULL,
    planData NVARCHAR(MAX) NOT NULL, -- Store full JSON plan
    createdAt DATETIME DEFAULT GETDATE(),
    updatedAt DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_PersonalizedPlans_Users FOREIGN KEY (firebaseUid) REFERENCES Users(firebaseUid)
);
GO

-- Create WorkoutDayProgress table
IF OBJECT_ID('dbo.WorkoutDayProgress', 'U') IS NOT NULL
DROP TABLE dbo.WorkoutDayProgress;
GO

CREATE TABLE WorkoutDayProgress (
    id INT IDENTITY(1,1) PRIMARY KEY,
    firebaseUid NVARCHAR(255) NOT NULL,
    planTitle NVARCHAR(255) NOT NULL,
    dayNumber INT NOT NULL,
    completedAt DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_WorkoutProgress_Users FOREIGN KEY (firebaseUid) REFERENCES Users(firebaseUid),
    CONSTRAINT UC_User_Plan_Day UNIQUE (firebaseUid, planTitle, dayNumber)
);
GO
