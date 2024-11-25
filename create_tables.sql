USE master
GO
-- Create the new database if it does not exist already
IF NOT EXISTS (
    SELECT [name]
        FROM sys.databases
        WHERE [name] = N'Airline'
)
CREATE DATABASE AIRLINE
GO

USE AIRLINE;
GO

IF OBJECT_ID('[dbo].[MaintenanceTask]', 'U') IS NOT NULL
DROP TABLE [dbo].[MaintenanceTask]
IF OBJECT_ID('[dbo].[CrewAssignment]', 'U') IS NOT NULL
DROP TABLE [dbo].[CrewAssignment]
GO
IF OBJECT_ID('[dbo].[Ticket]', 'U') IS NOT NULL
DROP TABLE [dbo].[Ticket]
IF OBJECT_ID('[dbo].[MaintenanceWorker]', 'U') IS NOT NULL
DROP TABLE [dbo].[MaintenanceWorker]
IF OBJECT_ID('[dbo].[Order]', 'U') IS NOT NULL
DROP TABLE [dbo].[Order]
IF OBJECT_ID('[dbo].[License]', 'U') IS NOT NULL
DROP TABLE [dbo].[License]
GO
IF OBJECT_ID('[dbo].[Employee]', 'U') IS NOT NULL
DROP TABLE [dbo].[Employee]
IF OBJECT_ID('[dbo].[Flight]', 'U') IS NOT NULL
DROP TABLE [dbo].[Flight]
IF OBJECT_ID('[dbo].[Reservation]', 'U') IS NOT NULL
DROP TABLE [dbo].[Reservation]
IF OBJECT_ID('[dbo].[ServiceRequest]', 'U') IS NOT NULL
DROP TABLE [dbo].[ServiceRequest]
GO
IF OBJECT_ID('[dbo].[Airport]', 'U') IS NOT NULL
DROP TABLE [dbo].[Airport]
IF OBJECT_ID('[dbo].[Customer]', 'U') IS NOT NULL
DROP TABLE [dbo].[Customer]
IF OBJECT_ID('[dbo].[Plane]', 'U') IS NOT NULL
DROP TABLE [dbo].[Plane]
IF OBJECT_ID('[dbo].[Part]', 'U') IS NOT NULL
DROP TABLE [dbo].[Part]
IF OBJECT_ID('[dbo].[Vendor]', 'U') IS NOT NULL
DROP TABLE [dbo].[Vendor]
GO

CREATE TABLE [dbo].[Airport]
(
    [IATACode] VARCHAR(3) NOT NULL PRIMARY KEY, -- Primary Key column
    [Name] NVARCHAR(50) NOT NULL,
    [Street] NVARCHAR(50),
    [City] NVARCHAR(50),
    [State] NVARCHAR(50),   
    [PostalCode] NVARCHAR(50),
    [Country] NVARCHAR(50) NOT NULL,
    [ExactLocation] GEOGRAPHY NOT NULL
);

CREATE TABLE [dbo].[Customer]
(
    [CustomerId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY, -- Primary Key column
    [FName] NVARCHAR(50) NOT NULL,
    [LName] NVARCHAR(50) NOT NULL,
    [Email] NVARCHAR(50) NOT NULL,
    [PhoneCountryCode] SMALLINT,
    [PhoneSubscriberNumber] BIGINT,
    CONSTRAINT chk_Email CHECK (
        Email LIKE '%_@__%.__%'
    )
);

CREATE TABLE [dbo].[Plane]
(
    [RegistrationNumber] NVARCHAR(50) NOT NULL PRIMARY KEY, -- Primary Key column
    [Manufacturer] NVARCHAR(50) NOT NULL,
    [Model] NVARCHAR(50) NOT NULL,
    [Capacity] SMALLINT NOT NULL
);

CREATE TABLE [dbo].[Part]
(
    [NSN] BIGINT NOT NULL PRIMARY KEY,
    [Description] NVARCHAR(50) NOT NULL,
    [UOM] NVARCHAR(10) NOT NULL,
    CONSTRAINT chk_uom CHECK (UOM IN ('EA', 'GAL', 'L', 'FT', 'M', 'LB', 'KG'))
);

CREATE TABLE [dbo].[Vendor]
(
    [VendorId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [Name] NVARCHAR(50) NOT NULL,
    [City] NVARCHAR(50) NOT NULL,
    [State] NVARCHAR(50),
    [PostalCode] NVARCHAR(50),
    [Country] NVARCHAR(50) NOT NULL
);
GO

CREATE TABLE [dbo].[Employee]
(
    [EmployeeId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,-- Primary Key column
    [HomeAirport] VARCHAR(3) NOT NULL FOREIGN KEY REFERENCES Airport(IATACode),
    [FName] NVARCHAR(50) NOT NULL,
    [LName] NVARCHAR(50) NOT NULL,
    [StartDt] DATE NOT NULL,
    [JobCode] NVARCHAR(1) NULL,
    [Tenure] AS DATEDIFF(MONTH, StartDt, GETDATE()),
    CONSTRAINT chk_job CHECK (JobCode IN ('F', 'M') OR JobCode IS NULL)
);

CREATE TABLE [dbo].[Flight]
(
    [FlightNumber] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,-- Primary Key column
    [Plane] NVARCHAR(50) NOT NULL REFERENCES Plane(RegistrationNumber),
    [Origin] VARCHAR(3) NOT NULL FOREIGN KEY REFERENCES Airport(IATACode),
    [DepartureDtTm] DATETIME NOT NULL,
    [DepartureTerminal] NVARCHAR(20),
    [DepartureGate] NVARCHAR(20),
    [Destination] VARCHAR(3) NOT NULL FOREIGN KEY REFERENCES Airport(IATACode),
    [ArrivalDtTm] DATETIME NOT NULL,
    [ArrivalTerminal] NVARCHAR(20),
    [ArrivalGate] NVARCHAR(20),
    [Duration] AS DATEDIFF(MINUTE, DepartureDtTm, ArrivalDtTm)
);

CREATE TABLE [dbo].[Reservation]
(
    [ReservationId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [Customer] INT NOT NULL FOREIGN KEY REFERENCES Customer(CustomerId)
);

CREATE TABLE [dbo].[ServiceRequest]
(
    [ServiceRequestNumber] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [Plane] NVARCHAR(50) NOT NULL FOREIGN KEY REFERENCES Plane(RegistrationNumber),
    [Priority] TINYINT NOT NULL,
    [MaintenanceLevel] TINYINT NOT NULL,
    [Description] NVARCHAR(255) NOT NULL,
    [CreationDt] DATE NOT NULL DEFAULT GETDATE(),
    [ResolutionDt] DATE,
    CONSTRAINT chk_sr_level CHECK (MaintenanceLevel BETWEEN 1 AND 5),
    CONSTRAINT chk_priority CHECK (Priority BETWEEN 1 AND 3) 
);
GO

CREATE TABLE [dbo].[Ticket]
(
    [TicketNumber] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [Flight] INT NOT NULL FOREIGN KEY REFERENCES Flight(FlightNumber),
    [Price] MONEY NOT NULL,
    [FName] NVARCHAR(50) NOT NULL,
    [LName] NVARCHAR(50) NOT NULL,
    [BirthDt] DATE NOT NULL,
    [Reservation] INT FOREIGN KEY REFERENCES Reservation(ReservationId)
);

CREATE TABLE [dbo].[MaintenanceWorker]
(
    [EmployeeId] INT NOT NULL PRIMARY KEY FOREIGN KEY REFERENCES Employee(EmployeeId),
    [MaintenanceLevel] TINYINT NOT NULL DEFAULT 1,
    CONSTRAINT chk_emp_level CHECK (MaintenanceLevel BETWEEN 1 AND 5)
);

CREATE TABLE [dbo].[Order]
(
    [OrderId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [PartNSN] BIGINT NOT NULL FOREIGN KEY REFERENCES Part(NSN),
    [VendorId] INT NOT NULL FOREIGN KEY REFERENCES Vendor(VendorId),
    [ServiceRequest] INT NOT NULL FOREIGN KEY REFERENCES ServiceRequest(ServiceRequestNumber),
    [Qty] INT NOT NULL,
    [TotalPrice] MONEY NOT NULL,
    [UnitPrice] AS TotalPrice/Qty
);

CREATE TABLE [dbo].[License]
(
    [LicenseNumber] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [PilotId] INT NOT NULL FOREIGN KEY REFERENCES Employee(EmployeeId),
    [Manufacturer] NVARCHAR(50) NOT NULL,
    [Model] NVARCHAR(50) NOT NULL
);

GO

CREATE TABLE [dbo].[MaintenanceTask]
(
    [TaskId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [MaintenanceWorker] INT NOT NULL FOREIGN KEY REFERENCES MaintenanceWorker(EmployeeId),
    [ServiceRequest] INT NOT NULL REFERENCES ServiceRequest(ServiceRequestNumber),
    [Description] NVARCHAR(255) NOT NULL,
    [TmSpentInMinutes] INT NOT NULL
);

CREATE TABLE [dbo].[CrewAssignment]
(
    [CrewId] INT NOT NULL FOREIGN KEY REFERENCES Employee(EmployeeId),
    [Flight] INT NOT NULL FOREIGN KEY REFERENCES Flight(FlightNumber),
    [Pilot] BIT NOT NULL DEFAULT 0,
    PRIMARY KEY (CrewId, Flight)
);
GO

--  NON-CLUSTERED INDEXES
IF EXISTS (SELECT name FROM sys.indexes
            WHERE name = N'IX_Flight_ArrivalDtTm')
    DROP INDEX IX_Flight_ArrivalDtTm ON Flight.ArrivalDtTm;
GO

CREATE NONCLUSTERED INDEX IX_Flight_ArrivalDtTm ON Flight (ArrivalDtTm ASC);
GO

IF EXISTS (SELECT name FROM sys.indexes
            WHERE name = N'IX_Flight_DepartureDtTm')
    DROP INDEX IX_Flight_ArrivalDtTm ON Flight.DepartureDtTm;
GO

CREATE NONCLUSTERED INDEX IX_Flight_DepartureDtTm ON Flight (DepartureDtTm ASC);
GO

IF EXISTS (SELECT name FROM sys.indexes
            WHERE name = N'IX_Ticket_Flight')
    DROP INDEX IX_Ticket_Flight ON Ticket.Flight;
GO

CREATE NONCLUSTERED INDEX IX_Ticket_Flight ON Ticket (Flight ASC);
GO