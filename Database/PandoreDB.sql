DELIMITER //

DROP DATABASE IF EXISTS Pandore//
CREATE DATABASE Pandore//
USE Pandore//

CREATE TABLE Service(
	Service_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	Service_Name VARCHAR(255) NOT NULL,
	CONSTRAINT Unique_Service_Name UNIQUE (Service_Name)
)ENGINE=InnoDB//

CREATE TABLE DNS(
	DNS_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	DNS_Value VARCHAR(1000) NOT NULL,
	CONSTRAINT Unique_DNS_Value UNIQUE (DNS_Value)
)ENGINE=INNODB//

CREATE TABLE Server(
	Server_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	Server_Address VARCHAR(1000) NOT NULL,
	Server_DNS INT NULL,
	Server_Service INT NULL,
	CONSTRAINT Unique_Server_Address_DNS UNIQUE (Server_Address),
	CONSTRAINT Server_DNS FOREIGN KEY (Server_DNS) REFERENCES DNS(DNS_ID),
	CONSTRAINT Server_Service FOREIGN KEY (Server_Service) REFERENCES Service(Service_ID)
)ENGINE=INNODB//

CREATE TABLE Capture(
	Capture_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	Capture_Name VARCHAR(255) NULL,
	Capture_StartTime DATETIME NOT NULL,
	Capture_EndTime DATETIME NULL,
	Capture_Description VARCHAR(1000) NULL,
	Capture_Interface VARCHAR(255) NULL,
	Capture_ConnectionType VARCHAR(255) NULL
)ENGINE=INNODB//

CREATE TABLE Capture_Request(
	CaptureRequest_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	CaptureRequest_PacketSize FLOAT NOT NULL,
	CaptureRequest_Direction TINYINT NOT NULL, /* 0 = DOWN, 1 = UP */ 
	CaptureRequest_DateTime TIMESTAMP NOT NULL,
	CaptureRequest_Protocol VARCHAR(255) NOT NULL,
	CaptureRequest_Server INT NOT NULL,
	CaptureRequest_Capture INT NOT NULL,
	CONSTRAINT Request_Server FOREIGN KEY (CaptureRequest_Server) REFERENCES Server(Server_ID),
	CONSTRAINT Request_Capture FOREIGN KEY (CaptureRequest_Capture) REFERENCES Capture(Capture_ID)
)ENGINE=INNODB//

/*Stored procedures for table Service*/
CREATE PROCEDURE CreateService (IN Name VARCHAR(255))
BEGIN
	INSERT INTO Service (Service_Name) VALUES (Name);
END//

CREATE PROCEDURE ReadAllServices()
BEGIN
	SELECT * FROM Service ORDER BY Service_Name ASC;
END//

CREATE PROCEDURE ReadServiceByID(IN ID INT)
BEGIN
	SELECT * FROM Service WHERE Service_ID = ID;
END//

CREATE PROCEDURE ReadServiceByName(IN Name VARCHAR(255))
BEGIN
	SELECT * FROM Service WHERE Service_Name = Name;
END//

CREATE PROCEDURE UpdateService(IN ID INT, IN Name VARCHAR(255))
BEGIN
	UPDATE Service SET Service_Name = Name WHERE Service_ID = ID;
END//

CREATE PROCEDURE DeleteServiceByID (IN ID INT)
BEGIN
	 DELETE FROM Service WHERE Service_ID = ID;
END//

CREATE PROCEDURE DeleteServiceByName (IN Name VARCHAR(255))
BEGIN
	 DELETE FROM Service WHERE LOWER(Service_Name) = LOWER(Name);
END//

/*Stored procedures for table Server*/
CREATE PROCEDURE CreateServer(IN Address VARCHAR(1000), IN Service INT, IN DNS INT)
BEGIN
	INSERT INTO Server (Server_Address, Server_Service, Server_DNS) VALUES (Address, Service, DNS);
END//

CREATE PROCEDURE CreateServerString(IN Address VARCHAR(1000), IN Service INT, IN DNS VARCHAR(1000))
BEGIN
	IF (DNS IS NOT NULL AND DNS <> '') THEN
		SET @DNS = (SELECT COUNT(*) FROM DNS WHERE LOWER(DNS_Value) = LOWER(DNS));
		IF(@DNS = 0)THEN
			CALL CreateDNS(DNS);
		END IF;
		INSERT INTO Server (Server_Address, Server_Service, Server_DNS) VALUES (Address, Service, (SELECT DNS_ID FROM DNS WHERE LOWER(DNS_Value) = LOWER(DNS)));
	ELSE
		INSERT INTO Server (Server_Address, Server_Service, Server_DNS) VALUES (Address, Service, NULL);
	END IF;
END//

CREATE PROCEDURE ReadAllServers()
BEGIN
	SELECT * FROM Server ORDER BY Server_Address ASC;
END//

CREATE PROCEDURE ReadServersByServiceID(IN Service INT, IN Details TINYINT)
BEGIN
	IF (Details = 1) THEN
		SELECT * FROM Server LEFT JOIN DNS ON Server_DNS = DNS_ID WHERE Server_Service = Service ORDER BY Server_Address ASC;
	ELSE
		SELECT * FROM Server WHERE Server_Service = Service ORDER BY Server_Address ASC;
	END IF;
END//

CREATE PROCEDURE ReadServerByDNSID(IN DNS INT)
BEGIN
	SELECT * FROM Server WHERE Server_DNS = DNS;
END//

CREATE PROCEDURE ReadServerByID(IN ID INT)
BEGIN
	SELECT * FROM Server WHERE Server_ID = ID;
END//

CREATE PROCEDURE ReadServerByAddress(IN Address VARCHAR(1000))
BEGIN
	SELECT * FROM Server WHERE LOWER(Server_Address) = LOWER(Address);
END//

CREATE PROCEDURE ReadIncompleteServers()
BEGIN
	SELECT Server_ID, Server_Address, Server_Service, Server_DNS, Service_Name, DNS_Value FROM (Server LEFT JOIN Service ON Server_Service = Service_ID) LEFT JOIN DNS ON Server_DNS = DNS_ID WHERE Server_Service IS NULL;
END//

CREATE PROCEDURE UpdateServer(IN ID INT, IN Address VARCHAR(1000), IN Service INT, IN DNS INT)
BEGIN
	UPDATE Server SET Server_Address = Address, Server_Service = Service, Server_DNS = DNS WHERE Server_ID = ID;
END//

CREATE PROCEDURE UpdateServerService(IN ID INT, IN Service INT)
BEGIN
	UPDATE Server SET Server_Service = Service, Server_DNS = DNS WHERE Server_ID = ID;
END//

CREATE PROCEDURE DeleteServerByID(IN ID INT)
BEGIN
	DELETE FROM Server WHERE Server_ID = ID;
END//

CREATE PROCEDURE DeleteServerByAddress(IN Address VARCHAR(1000))
BEGIN
	DELETE FROM Server WHERE LOWER(Server_Address) = LOWER(Address);
END//

CREATE PROCEDURE DeleteServerByServiceID(IN Service INT)
BEGIN
	DELETE FROM Server WHERE Server_Service = Service;
END//

/*Stored procedures for table DNS*/
CREATE PROCEDURE CreateDNS(IN Value VARCHAR(1000))
BEGIN
	INSERT INTO DNS (DNS_Value) VALUES (Value);
END//

CREATE PROCEDURE ReadAllDNS()
BEGIN
	SELECT * FROM DNS ORDER BY DNS_Value ASC;
END//

CREATE PROCEDURE ReadDNSByID(IN ID INT)
BEGIN
	SELECT * FROM DNS WHERE DNS_ID = ID;
END//

CREATE PROCEDURE ReadDNSByValue(IN Value VARCHAR(1000))
BEGIN
	SELECT * FROM DNS WHERE LOWER(DNS_Value) = LOWER(Value);
END//

CREATE PROCEDURE UpdateDNS(IN ID INT, IN Value VARCHAR(1000))
BEGIN
	UPDATE DNS SET DNS_Value = Address WHERE DNS_ID = ID;
END//

CREATE PROCEDURE DeleteDNSByID(IN ID INT)
BEGIN
	DELETE FROM DNS WHERE DNS_ID = ID;
END//

CREATE PROCEDURE DeleteDNSByValue(IN Value VARCHAR(1000))
BEGIN
	DELETE FROM DNS WHERE LOWER(DNS_Value) = LOWER(Value);
END//

/*Stored procedures for table Capture*/
CREATE PROCEDURE CreateCapture(IN Name VARCHAR(255), IN StartTime DATETIME, IN EndTime DATETIME, IN Description VARCHAR(1000), IN Interface VARCHAR(1000), IN ConnectionType VARCHAR(1000))
BEGIN
	INSERT INTO Capture (Capture_Name, Capture_StartTime, Capture_EndTime, Capture_Description, Capture_Interface, Capture_ConnectionType) VALUES (Name, StartTime, EndTime, Description, Interface, ConnectionType);
	SELECT Capture_ID FROM Capture WHERE Capture_Name = Name AND Capture_StartTime = StartTime AND (CASE WHEN EndTime IS NULL THEN EndTime IS NULL ELSE Capture_EndTime = EndTime END) AND (CASE WHEN Description IS NULL THEN Description IS NULL ELSE Capture_Description = Description END) AND (CASE WHEN Interface IS NULL THEN Interface IS NULL ELSE Capture_Interface = Interface END) AND (CASE WHEN ConnectionType IS NULL THEN ConnectionType IS NULL ELSE Capture_ConnectionType = ConnectionType END);
END//

CREATE PROCEDURE ReadAllCaptures()
BEGIN
	SELECT * FROM Capture ORDER BY Capture_StartTime, Capture_EndTime;
END//

CREATE PROCEDURE ReadCaptureByID(IN ID INT)
BEGIN
	SELECT * FROM Capture WHERE Capture_ID = ID;
END//

CREATE PROCEDURE ReadSavedCaptures()
BEGIN
	SELECT * FROM Capture WHERE Capture_EndTime IS NOT NULL;
END//

CREATE PROCEDURE ReadCaptureServicesStats(IN ID INT)
BEGIN
	/*IN MB*/
	SELECT * FROM (SELECT Service_Name, ROUND(SUM(CASE WHEN CaptureRequest_Direction = 1 THEN CaptureRequest_PacketSize ELSE 0 END)/(1024*1024), 2) AS UpTrafic, ROUND(SUM(CASE WHEN CaptureRequest_Direction = 0 THEN CaptureRequest_PacketSize ELSE 0 END)/(1024*1024), 2) AS DownTrafic FROM ((Capture_Request LEFT JOIN Server ON CaptureRequest_Server = Server_ID) LEFT JOIN DNS ON Server_DNS = DNS_ID) LEFT JOIN Service ON Server_Service = Service_ID WHERE CaptureRequest_Capture = ID GROUP BY Server_Service) AS sub ORDER BY (UpTrafic+DownTrafic) DESC LIMIT 10;
END//

CREATE PROCEDURE ReadRunningCapture()
BEGIN
	SELECT * FROM Capture WHERE Capture_EndTime IS NULL;
END//

CREATE PROCEDURE ReadCaptureTotalTrafic(IN Capture INT)
BEGIN
	SELECT SUM(CASE WHEN CaptureRequest_Direction = 0 THEN CaptureRequest_PacketSize ELSE 0 END) as DOWN, SUM(CASE WHEN CaptureRequest_Direction = 1 THEN CaptureRequest_PacketSize ELSE 0 END) as UP FROM Capture INNER JOIN Capture_Request ON Capture_ID = CaptureRequest_Capture WHERE Capture_ID = Capture;
END//

CREATE PROCEDURE UpdateCapture(IN ID INT, IN Name VARCHAR(255), IN StartTime DATETIME, IN EndTime DATETIME, IN Description VARCHAR(1000), IN Interface VARCHAR(1000), IN ConnectionType VARCHAR(1000))
BEGIN
	UPDATE Capture SET Capture_Name = Name, Capture_StartTime = StartTime, Capture_EndTime = EndTime, Capture_Description = Description, Capture_Interface = Interface, Capture_ConnectionType = ConnectionType WHERE Capture_ID = ID;
END//

CREATE PROCEDURE UpdateCaptureEndTime(IN ID INT, IN EndTime DATETIME)
BEGIN
	UPDATE Capture SET Capture_EndTime = EndTime WHERE Capture_ID = ID;
END//

CREATE PROCEDURE DeleteCaptureByID(IN ID INT)
BEGIN
	DELETE FROM Capture WHERE Capture_ID = ID;
END//

/*Stored procedures for table Capture_Request*/
CREATE PROCEDURE CreateRequest(IN PacketSize FLOAT, IN Direction TINYINT(1), IN Protocol VARCHAR(255), IN Server INT, IN Capture INT)
BEGIN
	INSERT INTO Capture_Request (CaptureRequest_PacketSize, CaptureRequest_Direction, CaptureRequest_DateTime, CaptureRequest_Protocol, CaptureRequest_Server, CaptureRequest_Capture) VALUES (PacketSize, Direction, CURRENT_TIMESTAMP, Protocol, Server, Capture);
END//

CREATE PROCEDURE CreateRequestString(IN PacketSize FLOAT, IN Direction TINYINT(1), IN Protocol VARCHAR(255), IN Server VARCHAR(1000), IN DNS VARCHAR(1000), IN Capture INT)
BEGIN
	IF (Server IS NOT NULL AND Server <> '' AND DNS IS NOT NULL AND DNS <> '') THEN
		SET @SERVER_ID = (SELECT COUNT(*) FROM Server WHERE LOWER(Server_Address) = LOWER(Server) AND Server_DNS = (SELECT DNS_ID FROM DNS WHERE LOWER(DNS_Value) = LOWER(DNS)));
		SET @DNS_ID = (SELECT COUNT(*) FROM DNS WHERE LOWER(DNS_Value) = LOWER(DNS));
		IF(@DNS_ID = 0) THEN
			CALL CreateDNS(DNS);
		END IF;
		IF(@SERVER_ID = 0) THEN
			CALL CreateServer(Server, NULL, (SELECT DNS_ID FROM DNS WHERE LOWER(DNS_Value) = LOWER(DNS)));
		END IF;
		CALL CreateRequest(PacketSize, Direction, Protocol, (SELECT Server_ID FROM Server WHERE LOWER(Server_Address) = LOWER(Server)), Capture);
	ELSE
		IF (Server IS NULL OR Server = '') THEN
			CALL CreateRequest(PacketSize, Direction, Protocol, NULL, Capture);
		ELSE
			SET @SERVER_ID = (SELECT COUNT(*) FROM Server WHERE LOWER(Server_Address) = LOWER(Server));
			IF(@SERVER_ID = 0) THEN
				CALL CreateServer(Server, NULL, NULL);
			END IF;
			CALL CreateRequest(PacketSize, Direction, Protocol, (SELECT Server_ID FROM Server WHERE LOWER(Server_Address) = LOWER(Server)), Capture);
		END IF;
	END IF;
END//

CREATE PROCEDURE ReadAllRequests(IN Details TINYINT(1))
BEGIN
	IF(Details = 0)THEN
		SELECT * FROM Capture_Request ORDER BY CaptureRequest_DateTime DESC;
	ELSE
		SELECT * FROM (Capture_Request LEFT JOIN Server ON CaptureRequest_Server = Server_ID) LEFT JOIN DNS ON CaptureRequest_DNS = DNS_ID ORDER BY CaptureRequest_DateTime DESC;
	END IF;
END//

CREATE PROCEDURE ReadRequestsByCaptureID(IN Capture INT, IN Details TINYINT(1))
BEGIN
	IF(Details = 0)THEN
		SELECT * FROM Capture_Request WHERE CaptureRequest_Capture = Capture;
	ELSE
		SELECT * FROM (Capture_Request LEFT JOIN Server ON CaptureRequest_Server = Server_ID) LEFT JOIN DNS ON Server_DNS = DNS_ID WHERE CaptureRequest_Capture = Capture;
	END IF;
END//

CREATE PROCEDURE ReadRequestByID(IN ID INT, IN Details TINYINT(1))
BEGIN
	IF(Details = 0)THEN
		SELECT * FROM Capture_Request WHERE CaptureRequest_ID = ID;
	ELSE
		SELECT * FROM (Capture_Request LEFT JOIN Server ON CaptureRequest_Server = Server_ID) LEFT JOIN DNS ON CaptureRequest_DNS = DNS_ID WHERE CaptureRequest_ID = ID;
	END IF;
	
END//

CREATE PROCEDURE UpdateRequest(IN ID INT, IN PacketSize FLOAT, IN Direction TINYINT(1), IN DateTime TIMESTAMP, IN Protocol VARCHAR(255), IN Server INT, IN Capture INT)
BEGIN
	UPDATE Capture_Request SET CaptureRequest_PacketSize = PacketSize, CaptureRequest_Direction = Direction, CaptureRequest_DateTime = DateTime, CaptureRequest_Protocol = Protocol, CaptureRequest_Server = Server, CaptureRequest_Capture = Capture WHERE CaptureRequest_ID = ID;
END//

CREATE PROCEDURE DeleteRequestByID(IN ID INT)
BEGIN
	DELETE FROM Capture_Request WHERE CaptureRequest_ID = ID;
END//

CREATE PROCEDURE DeleteRequestByCaptureID(IN Capture INT)
BEGIN
	DELETE FROM Capture_Request WHERE CaptureRequest_Capture = Capture;
END//

/* Populate database with existing services */

CALL CreateService("Youtube")//
CALL CreateService("Android")//
CALL CreateService("Google")//
CALL CreateService("Whatsapp")//
CALL CreateService("Instagram")//
CALL CreateService("Facebook")//
CALL CreateService("AWS")//
CALL CreateService("Twitch")//
CALL CreateService("Amazon")//
CALL CreateService("Windows")//
CALL CreateService("Microsoft")//
CALL CreateService("Discord")//
CALL CreateService("Twitter")//
CALL CreateService("Ubuntu")//
CALL CreateService("Tiktok")//
CALL CreateService("IMT Atlantique")//
CALL CreateService("Firefox")//
CALL CreateService("Netflix")//
CALL CreateService("Wordpress")//
CALL CreateService("Quantcast")//