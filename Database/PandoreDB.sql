DELIMITER //

DROP DATABASE IF EXISTS Pandore//
CREATE DATABASE Pandore//
USE Pandore//

CREATE TABLE Configuration(
	ANALYTICS_TIMEOUT INT NOT NULL,
	NUTRISCORE_REFERENCE_FREQUENCY INT NOT NULL,
	NUTRISCORE_REFERENCE_DEBIT FLOAT NOT NULL,
	NUTRISCORE_REFERENCE_DIVERSITY INT NOT NULL,
	NUTRISCORE_WEIGHT_FREQUENCY INT NOT NULL,
	NUTRISCORE_WEIGHT_DEBIT INT NOT NULL,
	NUTRISCORE_WEIGHT_DIVERSITY INT NOT NULL,
	NUTRISCORE_SIGMOIDE_SLOPE FLOAT NOT NULL,
	NUTRISCORE_AVERAGE_TYPE INT NOT NULL,
	SNIFFER_API_ADDRESS VARCHAR(1000) NOT NULL
)ENGINE=InnoDB//

CREATE TABLE Service(
	Service_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	Service_Name VARCHAR(255) NOT NULL,
	Service_Priority INT NOT NULL,
	CONSTRAINT Unique_Service_Name UNIQUE (Service_Name)
)ENGINE=InnoDB//

CREATE TABLE Service_Keyword(
	ServiceKeyword_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	ServiceKeyword_Value VARCHAR(255) NOT NULL,
	ServiceKeyword_Service INT NOT NULL,
	CONSTRAINT Unique_ServiceKeyword_Value UNIQUE (ServiceKeyword_Value),
	CONSTRAINT ServiceKeyword_Service FOREIGN KEY (ServiceKeyword_Service) REFERENCES Service(Service_ID)
)ENGINE=INNODB//

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
	Capture_ConnectionType VARCHAR(255) NULL,
	Capture_UE_Inactivity_Timeout INT NOT NULL
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

/*Stored procedures for table Configuration*/
CREATE PROCEDURE ReadConfiguration()
BEGIN
	SELECT * FROM Configuration LIMIT 1;
END//

CREATE PROCEDURE UpdateConfiguration(IN ANALYTICS_TIMEOUT INT, IN NUTRISCORE_REFERENCE_FREQUENCY INT, IN NUTRISCORE_REFERENCE_DEBIT FLOAT, IN NUTRISCORE_REFERENCE_DIVERSITY INT, IN NUTRISCORE_WEIGHT_FREQUENCY INT, IN NUTRISCORE_WEIGHT_DEBIT INT, IN NUTRISCORE_WEIGHT_DIVERSITY INT, IN NUTRISCORE_SIGMOIDE_SLOPE FLOAT, IN NUTRISCORE_AVERAGE_TYPE INT, IN SNIFFER_API_ADDRESS VARCHAR(1000))
BEGIN
	UPDATE Configuration SET ANALYTICS_TIMEOUT = ANALYTICS_TIMEOUT, NUTRISCORE_REFERENCE_FREQUENCY = NUTRISCORE_REFERENCE_FREQUENCY, NUTRISCORE_REFERENCE_DEBIT = NUTRISCORE_REFERENCE_DEBIT, NUTRISCORE_REFERENCE_DIVERSITY = NUTRISCORE_REFERENCE_DIVERSITY, NUTRISCORE_WEIGHT_FREQUENCY = NUTRISCORE_WEIGHT_FREQUENCY, NUTRISCORE_WEIGHT_DEBIT = NUTRISCORE_WEIGHT_DEBIT, NUTRISCORE_WEIGHT_DIVERSITY = NUTRISCORE_WEIGHT_DIVERSITY, NUTRISCORE_SIGMOIDE_SLOPE = NUTRISCORE_SIGMOIDE_SLOPE, NUTRISCORE_AVERAGE_TYPE = NUTRISCORE_AVERAGE_TYPE, SNIFFER_API_ADDRESS = SNIFFER_API_ADDRESS;
END//

/*Stored procedures for table Service*/
CREATE PROCEDURE CreateService (IN Name VARCHAR(255))
BEGIN
	SET @MaxPriority = (SELECT COALESCE((SELECT MAX(Service_Priority) FROM Service),0));
	INSERT INTO Service (Service_Name, Service_Priority) VALUES (Name, (@MaxPriority+1));
END//

CREATE PROCEDURE ReadAllServices()
BEGIN
	SELECT * FROM Service ORDER BY Service_Name ASC;
END//

CREATE PROCEDURE ReadServiceByID(IN ID INT)
BEGIN
	SELECT * FROM Service WHERE Service_ID = ID;
END//

CREATE PROCEDURE ReadServiceByPriority(IN Priority INT)
BEGIN
	SELECT * FROM Service WHERE Service_Priority = Priority;
END//

CREATE PROCEDURE ReadServiceByName(IN Name VARCHAR(255))
BEGIN
	SELECT * FROM Service WHERE Service_Name = Name;
END//

CREATE PROCEDURE UpdateService(IN ID INT, IN Name VARCHAR(255), IN Priority INT)
BEGIN
	SET @OldPriority = (SELECT Service_Priority FROM Service WHERE Service_ID = ID);

	IF (@OldPriority < Priority) THEN
		UPDATE Service SET Service_Priority = (Service_Priority-1) WHERE Service_Priority <= Priority AND Service_Priority > @OldPriority;
	ELSEIF (@OldPriority > Priority) THEN
		UPDATE Service SET Service_Priority = (Service_Priority+1) WHERE Service_Priority >= Priority AND Service_Priority < @OldPriority;
	END IF;

	UPDATE Service SET Service_Name = Name, Service_Priority = Priority WHERE Service_ID = ID;
END//

CREATE PROCEDURE DeleteServiceByID (IN ID INT)
BEGIN
	SET @ServicePriority = (SELECT Service_Priority FROM Service WHERE Service_ID = ID);
	DELETE FROM Service_Keyword WHERE ServiceKeyword_Service = @ServicePriority;
	UPDATE Server SET Server_Service = NULL WHERE Server_Service = ID;
	DELETE FROM Service WHERE Service_ID = ID;
	UPDATE Service SET Service_Priority = (Service_Priority - 1) WHERE Service_Priority > @ServicePriority;
END//

CREATE PROCEDURE DeleteServiceByName (IN Name VARCHAR(255))
BEGIN
	SET @ServiceID = (SELECT Service_ID FROM Server WHERE LOWER(Service_Name) = LOWER(Name));
	SET @ServicePriority = (SELECT Service_Priority FROM Service WHERE Service_ID = ID);
	DELETE FROM Service_Keyword WHERE ServiceKeyword_Service = @ServicePriority;
	UPDATE Server SET Server_Service = NULL WHERE Server_Service = @ServiceID;
	DELETE FROM Service WHERE Service_ID = @ServiceID;
	UPDATE Service SET Service_Priority = (Service_Priority - 1) WHERE Service_Priority > @ServicePriority;
END//

/*Stored procedures for table Service_Keyword*/
CREATE PROCEDURE CreateServiceKeyword(IN Value VARCHAR(255), IN Service INT)
BEGIN
	INSERT INTO Service_Keyword (ServiceKeyword_Value, ServiceKeyword_Service) VALUES (Value, Service);
END//

CREATE PROCEDURE ReadServiceKeywordByService(IN Service INT)
BEGIN
	SELECT * FROM Service_Keyword WHERE ServiceKeyword_Service = Service;
END;

CREATE PROCEDURE DeleteServiceKeywordByID(IN ID INT)
BEGIN
	DELETE FROM Service_Keyword WHERE ServiceKeyword_ID = ID;
END;

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
CREATE PROCEDURE CreateCapture(IN Name VARCHAR(255), IN StartTime DATETIME, IN EndTime DATETIME, IN Description VARCHAR(1000), IN Interface VARCHAR(1000), IN ConnectionType VARCHAR(1000), IN InactivityTimeout INT)
BEGIN
	INSERT INTO Capture (Capture_Name, Capture_StartTime, Capture_EndTime, Capture_Description, Capture_Interface, Capture_ConnectionType, Capture_UE_Inactivity_Timeout) VALUES (Name, StartTime, EndTime, Description, Interface, ConnectionType, InactivityTimeout);
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

CREATE PROCEDURE UpdateCapture(IN ID INT, IN Name VARCHAR(255), IN StartTime DATETIME, IN EndTime DATETIME, IN Description VARCHAR(1000), IN Interface VARCHAR(1000), IN ConnectionType VARCHAR(1000), IN InactivityTimeout INT)
BEGIN
	UPDATE Capture SET Capture_Name = Name, Capture_StartTime = StartTime, Capture_EndTime = EndTime, Capture_Description = Description, Capture_Interface = Interface, Capture_ConnectionType = ConnectionType, Capture_UE_Inactivity_Timeout = InactivityTimeout WHERE Capture_ID = ID;
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

INSERT INTO Configuration (ANALYTICS_TIMEOUT, NUTRISCORE_REFERENCE_FREQUENCY, NUTRISCORE_REFERENCE_DEBIT, NUTRISCORE_REFERENCE_DIVERSITY, NUTRISCORE_WEIGHT_FREQUENCY, NUTRISCORE_WEIGHT_DEBIT, NUTRISCORE_WEIGHT_DIVERSITY, NUTRISCORE_SIGMOIDE_SLOPE, NUTRISCORE_AVERAGE_TYPE, SNIFFER_IP) VALUES (5, 15, 0.1, 50, 1, 1, 1, 1, 0, '10.0.51.142')//

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
CALL CreateService("Intranet service")//

/* Link keywords to services */
CALL CreateServiceKeyword("youtube", 1)//
CALL CreateServiceKeyword("ytb", 1)//
CALL CreateServiceKeyword("ytimg", 1)//
CALL CreateServiceKeyword("yt", 1)//
CALL CreateServiceKeyword("googlevideo.com", 1)//
CALL CreateServiceKeyword("android", 2)//
CALL CreateServiceKeyword("google", 3)//
CALL CreateServiceKeyword("gstatic", 3)//
CALL CreateServiceKeyword("ggpht", 3)//
CALL CreateServiceKeyword("gmodules", 3)//
CALL CreateServiceKeyword("doubleclick", 3)//
CALL CreateServiceKeyword("gvt1", 3)//
CALL CreateServiceKeyword("1e100", 3)//
CALL CreateServiceKeyword("ocsp.pki.goog", 3)//
CALL CreateServiceKeyword("whatsapp", 4)//
CALL CreateServiceKeyword("instagram", 5)//
CALL CreateServiceKeyword("facebook", 6)//
CALL CreateServiceKeyword("fbcdb", 6)//
CALL CreateServiceKeyword("tfbnw", 6)//
CALL CreateServiceKeyword("awsdns", 7)//
CALL CreateServiceKeyword("amazonaws", 7)//
CALL CreateServiceKeyword("cloudfront", 7)//
CALL CreateServiceKeyword("s0.ipstatp", 7)//
CALL CreateServiceKeyword("twitch", 8)//
CALL CreateServiceKeyword("amazon", 9)//
CALL CreateServiceKeyword("alexa", 9)//
CALL CreateServiceKeyword("amzn", 9)//
CALL CreateServiceKeyword("windows", 10)//
CALL CreateServiceKeyword("microsoft", 11)//
CALL CreateServiceKeyword("live", 11)//
CALL CreateServiceKeyword("msn", 11)//
CALL CreateServiceKeyword("msedge", 11)//
CALL CreateServiceKeyword("live365", 11)//
CALL CreateServiceKeyword("office365now", 11)//
CALL CreateServiceKeyword("o365filtering", 11)//
CALL CreateServiceKeyword("discord", 12)//
CALL CreateServiceKeyword("discordapp", 12)//
CALL CreateServiceKeyword("twitter", 13)//
CALL CreateServiceKeyword("ubuntu", 14)//
CALL CreateServiceKeyword("xenial", 14)//
CALL CreateServiceKeyword("tiktok", 15)//
CALL CreateServiceKeyword("telecom-bretagne", 16)//
CALL CreateServiceKeyword("imt-atlantique", 16)//
CALL CreateServiceKeyword("firefox", 17)//
CALL CreateServiceKeyword("mozilla", 17)//
CALL CreateServiceKeyword("netflix", 18)//
CALL CreateServiceKeyword("wordpress", 19)//
CALL CreateServiceKeyword("quantserve", 20)//