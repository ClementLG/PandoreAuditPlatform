DROP DATABASE IF EXISTS Pandore;
CREATE DATABASE Pandore;
USE Pandore;

CREATE TABLE Service(
	Service_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	Service_Name VARCHAR(255) NOT NULL,
	CONSTRAINT Unique_Service_Name UNIQUE (Service_Name)
)ENGINE=InnoDB;

CREATE TABLE Server(
	Server_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	Server_Address VARCHAR(1000) NOT NULL,
	Server_Service INT NULL,
	CONSTRAINT Unique_Server_Address UNIQUE (Server_Address),
	CONSTRAINT Server_Service FOREIGN KEY (Server_Service) REFERENCES Service(Service_ID)
)ENGINE=INNODB;

CREATE TABLE DNS(
	DNS_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	DNS_Value VARCHAR(1000) NOT NULL,
	DNS_Service INT NULL,
	CONSTRAINT Unique_DNS_Value UNIQUE (DNS_Value),
	CONSTRAINT DNS_Service FOREIGN KEY (DNS_Service) REFERENCES Service(Service_ID)
)ENGINE=INNODB;

CREATE TABLE Capture(
	Capture_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	Capture_Name VARCHAR(255) NULL,
	Capture_StartTime DATETIME NOT NULL,
	Capture_EndTime DATETIME NULL,
	Capture_Description VARCHAR(1000) NULL,
	Capture_Interface VARCHAR(255) NULL,
	Capture_ConnectionType VARCHAR(255) NULL
)ENGINE=INNODB;

CREATE TABLE Capture_Request(
	CaptureRequest_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	CaptureRequest_PacketSize FLOAT NOT NULL,
	CaptureRequest_Direction TINYINT NOT NULL, /* 0 = DOWN, 1 = UP */ 
	CaptureRequest_DateTime TIMESTAMP NOT NULL,
	CaptureRequest_Protocol VARCHAR(255) NOT NULL,
	CaptureRequest_Server INT NOT NULL,
	CaptureRequest_DNS INT NOT NULL,
	CaptureRequest_Capture INT NOT NULL,
	CONSTRAINT Request_Server FOREIGN KEY (CaptureRequest_Server) REFERENCES Server(Server_ID),
	CONSTRAINT Request_DNS FOREIGN KEY (CaptureRequest_DNS) REFERENCES DNS(DNS_ID),
	CONSTRAINT Request_Capture FOREIGN KEY (CaptureRequest_Capture) REFERENCES Capture(Capture_ID)
)ENGINE=INNODB;

/*Stored procedures for table Service*/
CREATE PROCEDURE CreateService (IN Name VARCHAR(255))
BEGIN
	INSERT INTO Service (Service_Name) VALUES (Name);
END;

CREATE PROCEDURE ReadAllServices()
BEGIN
	SELECT * FROM Service ORDER BY Service_Name ASC;
END;

CREATE PROCEDURE ReadServiceByID(IN ID INT)
BEGIN
	SELECT * FROM Service WHERE Service_ID = ID;
END;

CREATE PROCEDURE ReadServiceByName(IN Name VARCHAR(255))
BEGIN
	SELECT * FROM Service WHERE Service_Name = Name;
END;

CREATE PROCEDURE UpdateService(IN ID INT, IN Name VARCHAR(255))
BEGIN
	UPDATE Service SET Service_Name = Name WHERE Service_ID = ID;
END;

CREATE PROCEDURE DeleteServiceByID (IN ID INT)
BEGIN
	 DELETE FROM Service WHERE Service_ID = ID;
END;

CREATE PROCEDURE DeleteServiceByName (IN Name VARCHAR(255))
BEGIN
	 DELETE FROM Service WHERE LOWER(Service_Name) = LOWER(Name);
END;

/*Stored procedures for table Server*/
CREATE PROCEDURE CreateServer(IN Address VARCHAR(1000), IN Service INT)
BEGIN
	INSERT INTO Server (Server_Address, Server_Service) VALUES (Address, Service);
END;

CREATE PROCEDURE ReadAllServers()
BEGIN
	SELECT * FROM Server ORDER BY Server_Address ASC;
END;

CREATE PROCEDURE ReadServersByServiceID(IN Service INT)
BEGIN
	SELECT * FROM Server WHERE Server_Service = Service ORDER BY Server_Address ASC;
END;

CREATE PROCEDURE ReadServerByID(IN ID INT)
BEGIN
	SELECT * FROM Server WHERE Server_ID = ID;
END;

CREATE PROCEDURE ReadServerByAddress(IN Address VARCHAR(1000))
BEGIN
	SELECT * FROM Server WHERE LOWER(Server_Address) = LOWER(Address);
END;

CREATE PROCEDURE UpdateServer(IN ID INT, IN Address VARCHAR(1000), IN Service INT)
BEGIN
	UPDATE Server SET Server_Address = Address, Server_Service = Service WHERE Server_ID = ID;
END;

CREATE PROCEDURE DeleteServerByID(IN ID INT)
BEGIN
	DELETE FROM Server WHERE Server_ID = ID;
END;

CREATE PROCEDURE DeleteServerByAddress(IN Address VARCHAR(1000))
BEGIN
	DELETE FROM Server WHERE LOWER(Server_Address) = LOWER(Address);
END;

CREATE PROCEDURE DeleteServerByServiceID(IN Service INT)
BEGIN
	DELETE FROM Server WHERE Server_Service = Service;
END;

/*Stored procedures for table DNS*/
CREATE PROCEDURE CreateDNS(IN Value VARCHAR(1000), IN Service INT)
BEGIN
	INSERT INTO DNS (DNS_Value, DNS_Service) VALUES (Value, Service);
END;

CREATE PROCEDURE ReadAllDNS()
BEGIN
	SELECT * FROM DNS ORDER BY DNS_Value ASC;
END;

CREATE PROCEDURE ReadDNSByServiceID(IN Service INT)
BEGIN
	SELECT * FROM DNS WHERE DNS_Service = Service ORDER BY DNS_Value ASC;
END;

CREATE PROCEDURE ReadDNSByID(IN ID INT)
BEGIN
	SELECT * FROM DNS WHERE DNS_ID = ID;
END;

CREATE PROCEDURE ReadDNSByValue(IN Value VARCHAR(1000))
BEGIN
	SELECT * FROM DNS WHERE LOWER(DNS_Value) = LOWER(Value);
END;

CREATE PROCEDURE UpdateDNS(IN ID INT, IN Value VARCHAR(1000), IN Service INT)
BEGIN
	UPDATE DNS SET DNS_Value = Address, DNS_Service = Service WHERE DNS_ID = ID;
END;

CREATE PROCEDURE DeleteDNSByID(IN ID INT)
BEGIN
	DELETE FROM DNS WHERE DNS_ID = ID;
END;

CREATE PROCEDURE DeleteDNSByValue(IN Value VARCHAR(1000))
BEGIN
	DELETE FROM DNS WHERE LOWER(DNS_Value) = LOWER(Value);
END;

CREATE PROCEDURE DeleteDNSByServiceID(IN Service INT)
BEGIN
	DELETE FROM DNS WHERE DNS_Service = Service;
END;

/*Stored procedures for table Capture*/
CREATE PROCEDURE CreateCapture(IN Name VARCHAR(255), IN StartTime DATETIME, IN EndTime DATETIME, IN Description VARCHAR(1000), IN Interface VARCHAR(1000), IN ConnectionType VARCHAR(1000))
BEGIN
	INSERT INTO Capture (Capture_Name, Capture_StartTime, Capture_EndTime, Capture_Description, Capture_Interface, Capture_ConnectionType) VALUES (Name, StartTime, EndTime, Description, Interface, ConnectionType);
END;

CREATE PROCEDURE ReadAllCaptures()
BEGIN
	SELECT * FROM Capture ORDER BY Capture_StartTime, Capture_EndTime;
END;

CREATE PROCEDURE ReadCaptureByID(IN ID INT)
BEGIN
	SELECT * FROM Capture WHERE Capture_ID = ID;
END;

CREATE PROCEDURE UpdateCapture(IN ID INT, IN Name VARCHAR(255), IN StartTime DATETIME, IN EndTime DATETIME, IN Description VARCHAR(1000), IN Interface VARCHAR(1000), IN ConnectionType VARCHAR(1000))
BEGIN
	UPDATE Capture SET Capture_Name = Name, Capture_StartTime = StartTime, Capture_EndTime = EndTime, Capture_Description = Description, Capture_Interface = Interface, Capture_ConnectionType = ConnectionType WHERE Capture_ID = ID;
END;

CREATE PROCEDURE DeleteCaptureByID(IN ID INT)
BEGIN
	DELETE FROM Capture WHERE Capture_ID = ID;
END; 

/*Stored procedures for table Capture_Request*/
CREATE PROCEDURE CreateRequest(IN PacketSize FLOAT, IN Direction TINYINT(1), IN Protocol VARCHAR(255), IN Server INT, IN DNS INT, IN Capture INT)
BEGIN
	INSERT INTO Capture_Request (CaptureRequest_PacketSize, CaptureRequest_Direction, CaptureRequest_DateTime, CaptureRequest_Protocol, CaptureRequest_Server, CaptureRequest_DNS, CaptureRequest_Capture) VALUES (PacketSize, Direction, CURRENT_TIMESTAMP, Protocol, Server, DNS, Capture);
END;

CREATE PROCEDURE CreateRequestString(IN PacketSize FLOAT, IN Direction TINYINT(1), IN Protocol VARCHAR(255), IN Server VARCHAR(1000), IN DNS VARCHAR(1000), IN Capture INT)
BEGIN
	IF (Server IS NOT NULL AND Server <> '' AND DNS IS NOT NULL AND DNS <> '') THEN
		SET @SERVER_ID = (SELECT COUNT(*) FROM Server WHERE LOWER(Server_Address) = LOWER(Server));
		SET @DNS_ID = (SELECT COUNT(*) FROM DNS WHERE LOWER(DNS_Value) = LOWER(DNS));
		IF(@SERVER_ID = 0) THEN
			CALL CreateServer(Server, NULL);
		END IF;
		IF(@DNS_ID = 0) THEN
			CALL CreateDNS(DNS, NULL);
		END IF;
		CALL CreateRequest(PacketSize, Direction, Protocol, (SELECT Server_ID FROM Server WHERE LOWER(Server_Address) = LOWER(Server)), (SELECT DNS_ID FROM DNS WHERE LOWER(DNS_Value) = LOWER(DNS)), Capture);
	END IF;
END;

CREATE PROCEDURE ReadAllRequests()
BEGIN
	SELECT * FROM Capture_Request ORDER BY CaptureRequest_DateTime DESC;
END;

CREATE PROCEDURE ReadRequestsByCaptureID(IN Capture INT)
BEGIN
	SELECT * FROM Capture_Request WHERE CaptureRequest_Capture = Capture;
END;

CREATE PROCEDURE ReadRequestByID(IN ID INT)
BEGIN
	SELECT * FROM Capture_Request WHERE CaptureRequest_ID = ID;
END;

CREATE PROCEDURE UpdateRequest(IN ID INT, IN PacketSize FLOAT, IN Direction TINYINT(1), IN DateTime TIMESTAMP, IN Protocol VARCHAR(255), IN Server INT, IN DNS INT, IN Capture INT)
BEGIN
	UPDATE Capture_Request SET CaptureRequest_PacketSize = PacketSize, CaptureRequest_Direction = Direction, CaptureRequest_DateTime = DateTime, CaptureRequest_Protocol = Protocol, CaptureRequest_Server = Server, CaptureRequest_DNS = DNS, CaptureRequest_Capture = Capture WHERE CaptureRequest_ID = ID;
END;

CREATE PROCEDURE DeleteRequestByID(IN ID INT)
BEGIN
	DELETE FROM Capture_Request WHERE CaptureRequest_ID = ID;
END;

CREATE PROCEDURE DeleteRequestByCaptureID(IN Capture INT)
BEGIN
	DELETE FROM Capture_Request WHERE CaptureRequest_Capture = Capture;
END;