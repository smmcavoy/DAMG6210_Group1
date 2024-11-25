USE AIRLINE
GO

IF OBJECT_ID('dbo.trg_UpdateMaintenanceWorker', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_UpdateMaintenanceWorker;
GO

CREATE TRIGGER trg_UpdateMaintenanceWorker
--  Automatically adds rows to MaintenanceWorker table for added/updated employees with a job code of 'M'
ON [dbo].[Employee]
AFTER INSERT, UPDATE
AS
BEGIN
    -- Insert into MaintenanceWorker if JobCode is 'M' for newly inserted or updated employees
    INSERT INTO [dbo].[MaintenanceWorker] (EmployeeId)  -- Assuming Id is the EmployeeID and PK in MaintenanceWorker
    SELECT EmployeeId
    FROM inserted
    WHERE JobCode = 'M' AND EmployeeId NOT IN (SELECT EmployeeId FROM [dbo].[MaintenanceWorker]);
END;
GO

--FUNCTIONS
--  FlightLength - gets length of flight, in kilometers
--  KMFlown - calculates how far an airplane has flown, based on the flights completed within a timeframe (defaults to the past year)
--  RepairCosts - calculates money spent on repairing a plane within a set time period (defaults to the past year)

IF OBJECT_ID('dbo.FlightLength') IS NOT NULL
    DROP FUNCTION dbo.FlightLength
GO

CREATE FUNCTION dbo.FlightLength (
    @FlightNo INT
)
RETURNS FLOAT
AS
BEGIN
    --calculates flight distance in kilometers
    DECLARE @orig GEOGRAPHY;
    DECLARE @dest GEOGRAPHY;

    SELECT @orig = a1.ExactLocation, @dest = a2.ExactLocation
    FROM Flight f
    JOIN Airport a1 ON f.Origin = a1.IATACode
    JOIN Airport a2 ON f.Destination = a2.IATACode
    WHERE f.FlightNumber = @FlightNo

    RETURN @orig.STDistance(@dest)/1000
END
GO

--SELECT dbo.FlightLength(1)

IF OBJECT_ID('dbo.KMFlown') IS NOT NULL
    DROP FUNCTION dbo.KMFlown
GO

CREATE FUNCTION dbo.KMFlown (
    @PlaneRegNo NVARCHAR(50),
    @Start DATETIME = NULL,
    @End DATETIME = NULL
)
RETURNS FLOAT
AS
BEGIN
    SET @Start = ISNULL(@Start, DATEADD(YEAR, -1, GETDATE()));
    SET @End = IIF(@End<GETDATE(), @End, GETDATE());
    
    DECLARE @KM FLOAT;
    --calculates total distance flown in kilometers
    SELECT @KM = SUM(dbo.FlightLength(f.FlightNumber))
    FROM Flight f
    WHERE f.Plane = @PlaneRegNo AND f.ArrivalDtTm BETWEEN @Start AND @End
    RETURN ISNULL(@KM, 0)
END
GO

--SELECT dbo.KMFlown('N11170', Default, Default)

IF OBJECT_ID('dbo.RepairCosts') IS NOT NULL
    DROP FUNCTION dbo.RepairCosts
GO

CREATE FUNCTION dbo.RepairCosts (
    @PlaneRegNo NVARCHAR(50),
    @Start DATETIME = NULL,
    @End DATETIME = NULL
)
RETURNS MONEY
AS
BEGIN
    SET @Start = ISNULL(@Start, DATEADD(YEAR, -1, GETDATE()));
    SET @End = ISNULL(@End, GETDATE());
    DECLARE @Cost MONEY;
    --calculates total cost of repairs between dates Start and End
    SELECT @Cost = SUM(o.TotalPrice)
    FROM ServiceRequest s JOIN [Order] o ON s.ServiceRequestNumber = o.ServiceRequest
    WHERE s.Plane = @PlaneRegNo AND s.ResolutionDt BETWEEN @Start AND @End
    RETURN ISNULL(@Cost, 0)
END
GO

--SELECT dbo.RepairCosts('N17098', Default, Default)

--PROCEDURES
--  sp_getCustomerReservations - gets all reservation details associated with a customer, including ticket/flight/plane info
--  sp_getFlightManifest - gets tickets & passenger information associated with a specific flight
--  sp_getAssignments - get all flights a flight crew employee has ever been assigned to

IF OBJECT_ID('dbo.sp_getCustomerReservations') IS NOT NULL
    DROP PROCEDURE dbo.sp_getCustomerReservations;
GO

CREATE PROCEDURE dbo.sp_getCustomerReservations
--gets reservations associated with a specific customer, including all tickets/flights associated with each.
    @custId INT
AS
    SELECT r.ReservationId, t.TicketNumber, t.Price, t.FName, t.LName, 
        f.Plane, p.Manufacturer, p.Model,
        f.Origin, f.DepartureTerminal, f.DepartureGate,
        f.Destination, f.ArrivalTerminal, f.ArrivalGate,
        f.DepartureDtTm, f.ArrivalDtTm, f.Duration, 
        dbo.FlightLength(f.FlightNumber) AS "Distance (km)"
    FROM Reservation r 
        JOIN Ticket t ON t.Reservation=r.ReservationId
        JOIN Flight f ON t.Flight=f.FlightNumber
        JOIN Plane p ON f.Plane=p.RegistrationNumber
    WHERE r.Customer = @custId
    RETURN;
GO

IF OBJECT_ID('dbo.sp_getFlightManifest') IS NOT NULL
    DROP PROCEDURE dbo.sp_getFlightManifest;
GO

CREATE PROCEDURE dbo.sp_getFlightManifest
--gets all passengers named on tickets for a specific flight
    @FlightNo INT
AS
    SELECT t.TicketNumber, t.FName, t.LName
    FROM Ticket t
    WHERE t.Flight = @FlightNo
    RETURN;
GO

IF OBJECT_ID('dbo.getAssignments') IS NOT NULL
    DROP PROCEDURE dbo.getAssignments;
GO

CREATE PROCEDURE dbo.getAssignments
--gets all flights a crew member has ever been assigned to
    @Emp INT
AS
    SELECT f.FlightNumber, f.Origin, f.Destination, f.DepartureDtTm, f.ArrivalDtTm, c.Pilot
    FROM Flight f JOIN CrewAssignment c ON f.FlightNumber = c.Flight
    WHERE c.CrewId = @Emp
    RETURN;
GO

--VIEWS
--  FleetStatus: Gets status of all planes in the database, includining all-time kilometers flown, open service requests, and date/time of next flight
--  FlightRevenue: Gets money generated by completed flights
--  CustomerActivity: Shows aggregated statistics for 

IF OBJECT_ID('dbo.FleetStatus', 'V') IS NOT NULL
    DROP VIEW dbo.FleetStatus;
GO

CREATE VIEW dbo.FleetStatus AS
WITH NextFlight (plane, origin, destination, departs, arrives)
AS
(
    SELECT f.Plane, f.Origin, f.Destination, f.DepartureDtTm, f.ArrivalDtTm
    FROM Flight f
    WHERE f.ArrivalDtTm > GETDATE()
), SRsOpen (Plane, NumberOpenSRs, MaxPriority)
AS
(
    SELECT s.Plane, COUNT(*), MAX(s.Priority)
    FROM ServiceRequest s 
    WHERE s.ResolutionDt IS NULL 
    GROUP BY s.Plane
) 
SELECT p.RegistrationNumber, p.Manufacturer, p.Model, p.Capacity, dbo.KMFlown(p.RegistrationNumber, '1800-01-01', Default) AS KMFlown, n.origin, n.destination, n.departs, n.arrives, ISNULL(sr.NumberOpenSRs,0) AS NumberOpenSRs, sr.MaxPriority
FROM Plane p
    LEFT OUTER JOIN NextFlight n ON p.RegistrationNumber=n.plane
    LEFT OUTER JOIN SRsOpen sr ON p.RegistrationNumber=sr.Plane
WHERE n.departs = (
    SELECT MIN(n1.departs)
    FROM NextFlight n1
    WHERE n1.plane = p.RegistrationNumber
) OR n.departs IS NULL
GO

IF OBJECT_ID('dbo.FlightRevenue', 'V') IS NOT NULL
    DROP VIEW dbo.FlightRevenue;
GO

CREATE VIEW dbo.FlightRevenue AS
SELECT f.FlightNumber, f.Plane, f.Origin, f.Destination, dbo.FlightLength(f.FlightNumber) AS RouteLength, f.DepartureDtTm, f.ArrivalDtTm, COUNT(t.TicketNumber) AS TicketsSold, ISNULL(SUM(t.Price),0) AS Revenue
FROM Flight f
    LEFT OUTER JOIN Ticket t ON f.FlightNumber=t.Flight
WHERE f.ArrivalDtTm<GETDATE()
GROUP BY f.FlightNumber, f.Plane, f.Origin, f.Destination, f.DepartureDtTm, f.ArrivalDtTm;
GO

IF OBJECT_ID('dbo.CustomerActivity', 'V') IS NOT NULL
    DROP VIEW dbo.CustomerActivity
GO

CREATE VIEW dbo.CustomerActivity AS
SELECT c.Email, COUNT(t.TicketNumber) AS TicketsBought, ISNULL(SUM(t.Price), 0) AS MoneySpent
FROM Customer c
    LEFT OUTER JOIN Reservation r ON r.Customer = c.CustomerId
    LEFT OUTER JOIN Ticket t ON t.Reservation = r.ReservationId
GROUP BY c.Email
GO

