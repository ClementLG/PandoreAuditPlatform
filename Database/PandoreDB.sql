DELIMITER //

DROP DATABASE IF EXISTS Pandore//
CREATE DATABASE Pandore//
USE Pandore//

CREATE TABLE Configuration(
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
	DNS_Service INT NULL,
	CONSTRAINT Unique_DNS_Value UNIQUE (DNS_Value),
	CONSTRAINT DNS_Service FOREIGN KEY (DNS_Service) REFERENCES Service(Service_ID)
)ENGINE=INNODB//

CREATE TABLE Server(
	Server_ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	Server_Address VARCHAR(1000) NOT NULL,
	Server_DNS INT NULL,
	CONSTRAINT Unique_Server_Address_DNS UNIQUE (Server_Address),
	CONSTRAINT Server_DNS FOREIGN KEY (Server_DNS) REFERENCES DNS(DNS_ID)
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

CREATE PROCEDURE UpdateConfiguration(IN NUTRISCORE_REFERENCE_FREQUENCY INT, IN NUTRISCORE_REFERENCE_DEBIT FLOAT, IN NUTRISCORE_REFERENCE_DIVERSITY INT, IN NUTRISCORE_WEIGHT_FREQUENCY INT, IN NUTRISCORE_WEIGHT_DEBIT INT, IN NUTRISCORE_WEIGHT_DIVERSITY INT, IN NUTRISCORE_SIGMOIDE_SLOPE FLOAT, IN NUTRISCORE_AVERAGE_TYPE INT, IN SNIFFER_API_ADDRESS VARCHAR(1000))
BEGIN
	UPDATE Configuration SET NUTRISCORE_REFERENCE_FREQUENCY = NUTRISCORE_REFERENCE_FREQUENCY, NUTRISCORE_REFERENCE_DEBIT = NUTRISCORE_REFERENCE_DEBIT, NUTRISCORE_REFERENCE_DIVERSITY = NUTRISCORE_REFERENCE_DIVERSITY, NUTRISCORE_WEIGHT_FREQUENCY = NUTRISCORE_WEIGHT_FREQUENCY, NUTRISCORE_WEIGHT_DEBIT = NUTRISCORE_WEIGHT_DEBIT, NUTRISCORE_WEIGHT_DIVERSITY = NUTRISCORE_WEIGHT_DIVERSITY, NUTRISCORE_SIGMOIDE_SLOPE = NUTRISCORE_SIGMOIDE_SLOPE, NUTRISCORE_AVERAGE_TYPE = NUTRISCORE_AVERAGE_TYPE, SNIFFER_API_ADDRESS = SNIFFER_API_ADDRESS;
END//

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
	DELETE FROM Service_Keyword WHERE ServiceKeyword_Service = ID;
	UPDATE DNS SET DNS_Service = NULL WHERE DNS_Service = ID;
	DELETE FROM Service WHERE Service_ID = ID;
END//

CREATE PROCEDURE DeleteServiceByName (IN Name VARCHAR(255))
BEGIN
	SET @ServiceID = (SELECT Service_ID FROM Server WHERE LOWER(Service_Name) = LOWER(Name));
	DELETE FROM Service_Keyword WHERE ServiceKeyword_Service = @ServiceID;
	UPDATE Server SET DNS_Service = NULL WHERE DNS_Service = @ServiceID;
	DELETE FROM Service WHERE Service_ID = @ServiceID;
END//

/*Stored procedures for table Service_Keyword*/
CREATE PROCEDURE CreateServiceKeyword(IN Value VARCHAR(255), IN Service INT)
BEGIN
	INSERT INTO Service_Keyword (ServiceKeyword_Value, ServiceKeyword_Service) VALUES (Value, Service);
END//

CREATE PROCEDURE ReadAllServiceKeyword()
BEGIN
	SELECT * FROM Service_Keyword INNER JOIN Service ON ServiceKeyword_Service = Service_ID;
END//

CREATE PROCEDURE ReadServiceKeywordByService(IN Service INT)
BEGIN
	SELECT * FROM Service_Keyword WHERE ServiceKeyword_Service = Service;
END//

CREATE PROCEDURE DeleteServiceKeywordByID(IN ID INT)
BEGIN
	DELETE FROM Service_Keyword WHERE ServiceKeyword_ID = ID;
END//

/*Stored procedures for table Server*/
CREATE PROCEDURE CreateServer(IN Address VARCHAR(1000), IN DNS INT)
BEGIN
	INSERT INTO Server (Server_Address, Server_DNS) VALUES (Address, DNS);
END//

CREATE PROCEDURE CreateServerString(IN Address VARCHAR(1000), IN DNS VARCHAR(1000))
BEGIN
	IF (DNS IS NOT NULL AND DNS <> '') THEN
		SET @DNS = (SELECT COUNT(*) FROM DNS WHERE LOWER(DNS_Value) = LOWER(DNS));
		IF(@DNS = 0)THEN
			CALL CreateDNS(DNS, NULL);
		END IF;
		SET @NBSERV = (SELECT COUNT(*) FROM Server WHERE LOWER(Server_Address) = LOWER(Address));
		IF(@NBSERV = 0)THEN
			INSERT INTO Server (Server_Address, Server_DNS) VALUES (Address, (SELECT DNS_ID FROM DNS WHERE LOWER(DNS_Value) = LOWER(DNS)));
		ELSE
			SET @SERV_ID = (SELECT Server_ID FROM Server WHERE LOWER(Server_Address) = LOWER(Address));
			CALL UpdateServer(@SERV_ID, Address, (SELECT DNS_ID FROM DNS WHERE LOWER(DNS_Value) = LOWER(DNS)));
		END IF;
	ELSE
		SET @NBSERV = (SELECT COUNT(*) FROM Server WHERE LOWER(Server_Address) = LOWER(Address));
		IF(@NBSERV = 0)THEN
			INSERT INTO Server (Server_Address, Server_DNS) VALUES (Address, NULL);
		END IF;
	END IF;
END//

CREATE PROCEDURE ReadAllServers()
BEGIN
	SELECT * FROM Server ORDER BY Server_Address ASC;
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

CREATE PROCEDURE UpdateServer(IN ID INT, IN Address VARCHAR(1000), IN DNS INT)
BEGIN
	UPDATE Server SET Server_Address = Address, Server_DNS = DNS WHERE Server_ID = ID;
END//

CREATE PROCEDURE DeleteServerByID(IN ID INT)
BEGIN
	DELETE FROM Server WHERE Server_ID = ID;
END//

CREATE PROCEDURE DeleteServerByAddress(IN Address VARCHAR(1000))
BEGIN
	DELETE FROM Server WHERE LOWER(Server_Address) = LOWER(Address);
END//

/*Stored procedures for table DNS*/
CREATE PROCEDURE CreateDNS(IN Value VARCHAR(1000), IN Service INT)
BEGIN
	INSERT INTO DNS (DNS_Value, DNS_Service) VALUES (Value, Service);
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

CREATE PROCEDURE ReadDNSByServiceID(IN Service INT)
BEGIN
	SELECT * FROM DNS WHERE DNS_Service = Service ORDER BY DNS_Value ASC;
END//

CREATE PROCEDURE ReadIncompleteDNS()
BEGIN
	SELECT * FROM DNS WHERE DNS_Service IS NULL;
END//

CREATE PROCEDURE UpdateDNS(IN ID INT, IN Value VARCHAR(1000), IN Service INT)
BEGIN
	UPDATE DNS SET DNS_Value = Value, DNS_Service = Service WHERE DNS_ID = ID;
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
	SELECT * FROM (SELECT Service_Name, ROUND(SUM(CASE WHEN CaptureRequest_Direction = 1 THEN CaptureRequest_PacketSize ELSE 0 END)/(1024*1024), 2) AS UpTrafic, ROUND(SUM(CASE WHEN CaptureRequest_Direction = 0 THEN CaptureRequest_PacketSize ELSE 0 END)/(1024*1024), 2) AS DownTrafic FROM ((Capture_Request LEFT JOIN Server ON CaptureRequest_Server = Server_ID) LEFT JOIN DNS ON Server_DNS = DNS_ID) LEFT JOIN Service ON DNS_Service = Service_ID WHERE CaptureRequest_Capture = ID GROUP BY DNS_Service) AS sub ORDER BY (UpTrafic+DownTrafic) DESC LIMIT 10;
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
	INSERT INTO Capture_Request (CaptureRequest_PacketSize, CaptureRequest_Direction, CaptureRequest_DateTime, CaptureRequest_Protocol, CaptureRequest_Server, CaptureRequest_Capture) VALUES (PacketSize, Direction, UTC_TIMESTAMP, Protocol, Server, Capture);
END//

CREATE PROCEDURE CreateRequestString(IN PacketSize FLOAT, IN Direction TINYINT(1), IN Protocol VARCHAR(255), IN Server VARCHAR(1000), IN DNS VARCHAR(1000), IN Capture INT)
BEGIN
	IF (DNS IS NOT NULL AND DNS <> '') THEN
		CALL CreateServerString(Server, DNS);
		CALL CreateRequest(PacketSize, Direction, Protocol, (SELECT Server_ID FROM Server WHERE LOWER(Server_Address) = LOWER(Server)), Capture);
	ELSE
		IF (INET_ATON(Server) BETWEEN INET_ATON("10.0.0.0") AND INET_ATON("10.255.255.255")) OR (INET_ATON(Server) BETWEEN INET_ATON("172.16.0.0") AND INET_ATON("172.31.255.255")) OR (INET_ATON(Server) BETWEEN INET_ATON("192.168.0.0") AND INET_ATON("192.168.255.255")) THEN
			CALL CreateServerString(Server, "localhost");
		ELSE
			CALL CreateServerString(Server, NULL);
		END IF;
		CALL CreateRequest(PacketSize, Direction, Protocol, (SELECT Server_ID FROM Server WHERE LOWER(Server_Address) = LOWER(Server)), Capture);
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

INSERT INTO Configuration (NUTRISCORE_REFERENCE_FREQUENCY, NUTRISCORE_REFERENCE_DEBIT, NUTRISCORE_REFERENCE_DIVERSITY, NUTRISCORE_WEIGHT_FREQUENCY, NUTRISCORE_WEIGHT_DEBIT, NUTRISCORE_WEIGHT_DIVERSITY, NUTRISCORE_SIGMOIDE_SLOPE, NUTRISCORE_AVERAGE_TYPE, SNIFFER_API_ADDRESS) VALUES (15, 0.1, 50, 1, 1, 1, 1, 0, '10.0.51.142')//

/* Populate database with existing services */
CALL CreateService("Intranet service")//
CALL CreateDNS("localhost", 1)//

CALL CreateService("OnlyFans")//
CALL CreateServiceKeyword("(\.|^)onlyfans\.com$", 2)//
CALL CreateService("33Across")//
CALL CreateServiceKeyword("(\.|^)33across\.com$", 3)//
CALL CreateServiceKeyword("(\.|^)33across\.com\.cdn\.cloudflare\.net$", 3)//
CALL CreateServiceKeyword("(\.|^)33xchange-1576862511\.us-east-1\.elb\.amazonaws\.com$", 3)//
CALL CreateServiceKeyword("(\.|^)tynt\.com$", 3)//
CALL CreateServiceKeyword("(\.|^)tynt\.com\.cdn\.cloudflare\.net$", 3)//
CALL CreateService("AAX.media")//
CALL CreateServiceKeyword("(\.|^)aax\.media$", 4)//
CALL CreateServiceKeyword("(\.|^)aaxads\.com$", 4)//
CALL CreateServiceKeyword("(\.|^)aaxdetect\.com$", 4)//
CALL CreateServiceKeyword("(\.|^)e11089\.d\.akamaiedge\.net$", 4)//
CALL CreateServiceKeyword("(\.|^)e12767\.d\.akamaiedge\.net$", 4)//
CALL CreateService("ADITION")//
CALL CreateServiceKeyword("(\.|^)adition\.com$", 5)//
CALL CreateService("AdColony")//
CALL CreateServiceKeyword("(\.|^)adcolony\.com$", 6)//
CALL CreateServiceKeyword("(\.|^)adcolony\.xyz$", 6)//
CALL CreateService("AdTheorant")//
CALL CreateServiceKeyword("(\.|^)adentifi\.com$", 7)//
CALL CreateServiceKeyword("(\.|^)adtheorent\.com$", 7)//
CALL CreateService("Adform")//
CALL CreateServiceKeyword("(\.|^)adform\.com$", 8)//
CALL CreateServiceKeyword("(\.|^)adform\.net$", 8)//
CALL CreateServiceKeyword("(\.|^)adformnet\.akadns\.net$", 8)//
CALL CreateServiceKeyword("(\.|^)seadform\.net$", 8)//
CALL CreateService("Adjust")//
CALL CreateServiceKeyword("(\.|^)adj\.st$", 9)//
CALL CreateServiceKeyword("(\.|^)adjust\.com$", 9)//
CALL CreateServiceKeyword("(\.|^)adjust\.io$", 9)//
CALL CreateServiceKeyword("(\.|^)adjust\.net\.in$", 9)//
CALL CreateServiceKeyword("(\.|^)adjust\.world$", 9)//
CALL CreateService("Adobe")//
CALL CreateServiceKeyword("(\.|^)acrobat\.com$", 10)//
CALL CreateServiceKeyword("(\.|^)adobe-identity\.com$", 10)//
CALL CreateServiceKeyword("(\.|^)adobe\.com$", 10)//
CALL CreateServiceKeyword("(\.|^)adobe\.com\.edgesuite\.net$", 10)//
CALL CreateServiceKeyword("(\.|^)adobe\.com\.ssl\.d1\.sc\.omtrdc\.net$", 10)//
CALL CreateServiceKeyword("(\.|^)adobe\.io$", 10)//
CALL CreateServiceKeyword("(\.|^)adobe\.net$", 10)//
CALL CreateServiceKeyword("(\.|^)adobecc\.com$", 10)//
CALL CreateServiceKeyword("(\.|^)adobeexchange\.com$", 10)//
CALL CreateServiceKeyword("(\.|^)adobelogin\.com$", 10)//
CALL CreateServiceKeyword("(\.|^)adobesc\.com$", 10)//
CALL CreateServiceKeyword("(\.|^)createjs\.com$", 10)//
CALL CreateServiceKeyword("(\.|^)photoshop\.com$", 10)//
CALL CreateServiceKeyword("(\.|^)typekit\.com$", 10)//
CALL CreateServiceKeyword("(\.|^)typekit\.net$", 10)//
CALL CreateService("Adobe Ads")//
CALL CreateServiceKeyword("(\.|^)2o7\.net$", 11)//
CALL CreateServiceKeyword("(\.|^)adobe-aem\.map\.fastly\.net$", 11)//
CALL CreateServiceKeyword("(\.|^)adobeaemcloud\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)adobecce\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)adobeconnect\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)adobedtm\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)adobeprimetime\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)adobess\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)adobetag\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)business\.adobe\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)dcs-edge-usw2-620097651\.us-west-2\.elb\.amazonaws\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)dcs-edge-va6-802167536\.us-east-1\.elb\.amazonaws\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)demdex\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)demdex\.net$", 11)//
CALL CreateServiceKeyword("(\.|^)everestads\.net$", 11)//
CALL CreateServiceKeyword("(\.|^)everesttech\.net$", 11)//
CALL CreateServiceKeyword("(\.|^)everesttech\.net\.akadns\.net$", 11)//
CALL CreateServiceKeyword("(\.|^)marketo\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)mktoresp\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)mktoutil\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)omniture\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)omtrdc\.net$", 11)//
CALL CreateServiceKeyword("(\.|^)ss-omtrdc\.net$", 11)//
CALL CreateServiceKeyword("(\.|^)sstats\.adobe\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)tmogul\.com$", 11)//
CALL CreateServiceKeyword("(\.|^)tubemogul\.com$", 11)//
CALL CreateService("AdsWizz")//
CALL CreateServiceKeyword("(\.|^)adswizz\.com$", 12)//
CALL CreateService("Airship")//
CALL CreateServiceKeyword("(\.|^)airship\.com$", 13)//
CALL CreateServiceKeyword("(\.|^)apptimize\.com$", 13)//
CALL CreateServiceKeyword("(\.|^)urbanairship\.com$", 13)//
CALL CreateService("Alexa.com")//
CALL CreateServiceKeyword("(\.|^)alexa\.com$", 14)//
CALL CreateServiceKeyword("(\.|^)alexametrics\.com$", 14)//
CALL CreateService("Amazon Advertising")//
CALL CreateServiceKeyword("(\.|^)aax-eu\.amazon\.co\.uk$", 15)//
CALL CreateServiceKeyword("(\.|^)aax-eu\.amazon\.es$", 15)//
CALL CreateServiceKeyword("(\.|^)aax-eu\.amazon\.in$", 15)//
CALL CreateServiceKeyword("(\.|^)aax-eu\.amazon\.nl$", 15)//
CALL CreateServiceKeyword("(\.|^)amazon-adsystem\.amazon\.com$", 15)//
CALL CreateServiceKeyword("(\.|^)amazon-adsystem\.com$", 15)//
CALL CreateServiceKeyword("(\.|^)amazonadsi-a\.akamaihd\.net$", 15)//
CALL CreateServiceKeyword("(\.|^)amazonadsi-a\.akamaihd\.net\.edgesuite\.net$", 15)//
CALL CreateServiceKeyword("(\.|^)device-metrics-us\.amazon\.com$", 15)//
CALL CreateServiceKeyword("(\.|^)mads-eu\.amazon\.com$", 15)//
CALL CreateServiceKeyword("(\.|^)mads\.amazon\.com$", 15)//
CALL CreateServiceKeyword("(\.|^)rfihub\.com$", 15)//
CALL CreateServiceKeyword("(\.|^)rfihub\.com\.akadns\.net$", 15)//
CALL CreateServiceKeyword("(\.|^)rfihub\.net$", 15)//
CALL CreateServiceKeyword("(\.|^)serving-sys-lb\.com\.akadns\.net$", 15)//
CALL CreateServiceKeyword("(\.|^)serving-sys\.com$", 15)//
CALL CreateServiceKeyword("(\.|^)serving-sys\.com-v1\.edgesuite\.net$", 15)//
CALL CreateServiceKeyword("(\.|^)serving-sys\.com\.edgekey\.net$", 15)//
CALL CreateServiceKeyword("(\.|^)serving-sys\.com\.edgesuite\.net$", 15)//
CALL CreateServiceKeyword("(\.|^)sizmek\.com$", 15)//
CALL CreateServiceKeyword("(\.|^)video-ads\.a2z\.com$", 15)//
CALL CreateService("Amazon Assistant")//
CALL CreateServiceKeyword("(\.|^)amazonbrowserapp\.com$", 16)//
CALL CreateServiceKeyword("(\.|^)browserapps\.amazon\.com$", 16)//
CALL CreateService("Amobee")//
CALL CreateServiceKeyword("(\.|^)amgdgt\.com$", 17)//
CALL CreateServiceKeyword("(\.|^)amobee\.com$", 17)//
CALL CreateServiceKeyword("(\.|^)tidaltv\.com$", 17)//
CALL CreateServiceKeyword("(\.|^)tidaltv\.com\.akadns\.net$", 17)//
CALL CreateServiceKeyword("(\.|^)turn\.com$", 17)//
CALL CreateServiceKeyword("(\.|^)turn\.com\.akadns\.net$", 17)//
CALL CreateServiceKeyword("(\.|^)videologygroup\.com$", 17)//
CALL CreateService("Amplitude")//
CALL CreateServiceKeyword("(\.|^)amplitude\.com$", 18)//
CALL CreateServiceKeyword("(\.|^)amplitude\.map\.fastly\.net$", 18)//
CALL CreateService("AppLovin")//
CALL CreateServiceKeyword("(\.|^)applovin\.com$", 19)//
CALL CreateServiceKeyword("(\.|^)applovin\.com\.edgekey\.net$", 19)//
CALL CreateServiceKeyword("(\.|^)applvn\.com$", 19)//
CALL CreateServiceKeyword("(\.|^)e10204\.dsca\.akamaiedge\.net$", 19)//
CALL CreateService("AppNexus")//
CALL CreateServiceKeyword("(\.|^)adnxs-simple\.com$", 20)//
CALL CreateServiceKeyword("(\.|^)adnxs\.com$", 20)//
CALL CreateServiceKeyword("(\.|^)appnexus\.com$", 20)//
CALL CreateServiceKeyword("(\.|^)appnexus\.map\.fastly\.net$", 20)//
CALL CreateServiceKeyword("(\.|^)appnexusgslb\.net$", 20)//
CALL CreateServiceKeyword("(\.|^)e6115\.g\.akamaiedge\.net$", 20)//
CALL CreateServiceKeyword("(\.|^)geoadnxs\.com$", 20)//
CALL CreateServiceKeyword("(\.|^)geogslb\.com$", 20)//
CALL CreateServiceKeyword("(\.|^)secure-adnxs\.edgekey\.net$", 20)//
CALL CreateService("Appcues")//
CALL CreateServiceKeyword("(\.|^)appcues\.com$", 21)//
CALL CreateServiceKeyword("(\.|^)appcues\.net$", 21)//
CALL CreateService("AppsFlyer")//
CALL CreateServiceKeyword("(\.|^)appsflyer\.com$", 22)//
CALL CreateServiceKeyword("(\.|^)appsflyersdk\.com$", 22)//
CALL CreateService("Audigent")//
CALL CreateServiceKeyword("(\.|^)ad\.gt$", 23)//
CALL CreateServiceKeyword("(\.|^)audigent\.com$", 23)//
CALL CreateService("Barefruit")//
CALL CreateServiceKeyword("(\.|^)barefruit\.co\.uk$", 24)//
CALL CreateServiceKeyword("(\.|^)barefruit\.com$", 24)//
CALL CreateService("Beachfront Media")//
CALL CreateServiceKeyword("(\.|^)beachfront\.com$", 25)//
CALL CreateServiceKeyword("(\.|^)bfmio\.com$", 25)//
CALL CreateServiceKeyword("(\.|^)io-api-1173461934\.us-east-1\.elb\.amazonaws\.com$", 25)//
CALL CreateServiceKeyword("(\.|^)io-cookie-sync-1725936127\.us-east-1\.elb\.amazonaws\.com$", 25)//
CALL CreateService("BidSwitch")//
CALL CreateServiceKeyword("(\.|^)alb-aws-fr-bswx-1-445786803\.eu-central-1\.elb\.amazonaws\.com$", 26)//
CALL CreateServiceKeyword("(\.|^)alb-aws-fr-bswx-3-1125904451\.eu-central-1\.elb\.amazonaws\.com$", 26)//
CALL CreateServiceKeyword("(\.|^)bidswitch\.com$", 26)//
CALL CreateServiceKeyword("(\.|^)bidswitch\.net$", 26)//
CALL CreateServiceKeyword("(\.|^)mfadsrvr\.com$", 26)//
CALL CreateService("Bombora")//
CALL CreateServiceKeyword("(\.|^)bombora\.com$", 27)//
CALL CreateServiceKeyword("(\.|^)ml314\.com$", 27)//
CALL CreateService("Booyah Advertising")//
CALL CreateServiceKeyword("(\.|^)booyahadvertising\.com$", 28)//
CALL CreateServiceKeyword("(\.|^)booyahnetworks\.com$", 28)//
CALL CreateServiceKeyword("(\.|^)spotx\.tv$", 28)//
CALL CreateServiceKeyword("(\.|^)spotxcdn\.com$", 28)//
CALL CreateServiceKeyword("(\.|^)spotxchange\.com$", 28)//
CALL CreateServiceKeyword("(\.|^)spotxchange\.com\.akadns\.net$", 28)//
CALL CreateService("Branch IO")//
CALL CreateServiceKeyword("(\.|^)branch\.io$", 29)//
CALL CreateService("Braze")//
CALL CreateServiceKeyword("(\.|^)appboy\.com$", 30)//
CALL CreateServiceKeyword("(\.|^)braze\.com$", 30)//
CALL CreateServiceKeyword("(\.|^)braze\.eu$", 30)//
CALL CreateService("BritePool")//
CALL CreateServiceKeyword("(\.|^)britepool\.com$", 31)//
CALL CreateService("C3 Metrics")//
CALL CreateServiceKeyword("(\.|^)c3metrics\.com$", 32)//
CALL CreateServiceKeyword("(\.|^)c3tag\.com$", 32)//
CALL CreateService("CHEQ")//
CALL CreateServiceKeyword("(\.|^)cheq\.ai$", 33)//
CALL CreateServiceKeyword("(\.|^)cheqzone\.b-cdn\.net$", 33)//
CALL CreateServiceKeyword("(\.|^)cheqzone\.com$", 33)//
CALL CreateServiceKeyword("(\.|^)cheqzone2\.b-cdn\.net$", 33)//
CALL CreateService("Casale Media")//
CALL CreateServiceKeyword("(\.|^)casalemedia\.com$", 34)//
CALL CreateServiceKeyword("(\.|^)casalemedia\.com\.edgekey\.net$", 34)//
CALL CreateServiceKeyword("(\.|^)casalemedia\.com\.edgesuite\.net$", 34)//
CALL CreateServiceKeyword("(\.|^)indexww\.com$", 34)//
CALL CreateService("Centro")//
CALL CreateServiceKeyword("(\.|^)centro\.net$", 35)//
CALL CreateServiceKeyword("(\.|^)sitescout\.com$", 35)//
CALL CreateService("Chartbeat")//
CALL CreateServiceKeyword("(\.|^)chartbeat\.com$", 36)//
CALL CreateServiceKeyword("(\.|^)chartbeat\.net$", 36)//
CALL CreateService("Cheil PengTai")//
CALL CreateServiceKeyword("(\.|^)cheilpengtai\.com$", 37)//
CALL CreateServiceKeyword("(\.|^)galaxyappstore\.com$", 37)//
CALL CreateServiceKeyword("(\.|^)ipengtai\.com$", 37)//
CALL CreateService("ChurnZero")//
CALL CreateServiceKeyword("(\.|^)churnzero\.net$", 38)//
CALL CreateService("CleverTap")//
CALL CreateServiceKeyword("(\.|^)clevertap\.com$", 39)//
CALL CreateServiceKeyword("(\.|^)wizrocket\.com$", 39)//
CALL CreateServiceKeyword("(\.|^)wzrkt\.com$", 39)//
CALL CreateService("ClickMagick")//
CALL CreateServiceKeyword("(\.|^)clickmagick\.com$", 40)//
CALL CreateServiceKeyword("(\.|^)clkmg\.com$", 40)//
CALL CreateServiceKeyword("(\.|^)wealthclubnetworks\.com$", 40)//
CALL CreateService("Cloudinary")//
CALL CreateServiceKeyword("(\.|^)cloudinary\.com$", 41)//
CALL CreateServiceKeyword("(\.|^)cloudinary\.com\.edgekey\.net$", 41)//
CALL CreateServiceKeyword("(\.|^)cloudinary3\.map\.fastly\.net$", 41)//
CALL CreateServiceKeyword("(\.|^)res-cloudinary-com\.cdn\.ampproject\.org$", 41)//
CALL CreateServiceKeyword("(\.|^)s1-cloudinary-pin-sni\.map\.fastly\.net$", 41)//
CALL CreateServiceKeyword("(\.|^)s1-cloudinary-pin\.map\.fastly\.net$", 41)//
CALL CreateServiceKeyword("(\.|^)s2-cloudinary-pin-sni\.map\.fastly\.net$", 41)//
CALL CreateServiceKeyword("(\.|^)s2-cloudinary-pin\.map\.fastly\.net$", 41)//
CALL CreateServiceKeyword("(\.|^)s3-cloudinary-pin-sni\.map\.fastly\.net$", 41)//
CALL CreateServiceKeyword("(\.|^)s3-cloudinary-pin\.map\.fastly\.net$", 41)//
CALL CreateServiceKeyword("(\.|^)s4-cloudinary-pin\.map\.fastly\.net$", 41)//
CALL CreateServiceKeyword("(\.|^)s5-cloudinary-pin\.map\.fastly\.net$", 41)//
CALL CreateService("Constant Contact")//
CALL CreateServiceKeyword("(\.|^)constantcontact\.com$", 42)//
CALL CreateServiceKeyword("(\.|^)ctctcdn\.com$", 42)//
CALL CreateService("Conversant Media")//
CALL CreateServiceKeyword("(\.|^)anrdoezrs\.net$", 43)//
CALL CreateServiceKeyword("(\.|^)conversant\.mgr\.consensu\.org$", 43)//
CALL CreateServiceKeyword("(\.|^)conversantmedia\.com$", 43)//
CALL CreateServiceKeyword("(\.|^)dotomi\.com$", 43)//
CALL CreateServiceKeyword("(\.|^)dotomi\.weighted\.com\.akadns\.net$", 43)//
CALL CreateServiceKeyword("(\.|^)emjcd\.com$", 43)//
CALL CreateServiceKeyword("(\.|^)mediaplex\.com$", 43)//
CALL CreateServiceKeyword("(\.|^)qksrv\.net$", 43)//
CALL CreateServiceKeyword("(\.|^)rundsp\.com$", 43)//
CALL CreateServiceKeyword("(\.|^)track\.cj\.akadns\.net$", 43)//
CALL CreateService("Convertro")//
CALL CreateServiceKeyword("(\.|^)convertro\.com$", 44)//
CALL CreateService("Conviva")//
CALL CreateServiceKeyword("(\.|^)conviva\.com$", 45)//
CALL CreateService("Criteo")//
CALL CreateServiceKeyword("(\.|^)criteo\.com$", 46)//
CALL CreateServiceKeyword("(\.|^)criteo\.net$", 46)//
CALL CreateServiceKeyword("(\.|^)dnacdn\.net$", 46)//
CALL CreateServiceKeyword("(\.|^)hlserve\.com$", 46)//
CALL CreateService("Crownpeak")//
CALL CreateServiceKeyword("(\.|^)betrad\.com$", 47)//
CALL CreateServiceKeyword("(\.|^)crownpeak\.com$", 47)//
CALL CreateServiceKeyword("(\.|^)e5413\.g\.akamaiedge\.net$", 47)//
CALL CreateServiceKeyword("(\.|^)evidon\.com$", 47)//
CALL CreateServiceKeyword("(\.|^)privacycollector-production-457481513\.us-east-1\.elb\.amazonaws\.com$", 47)//
CALL CreateService("Devicescape")//
CALL CreateServiceKeyword("(\.|^)devicescape\.com$", 48)//
CALL CreateServiceKeyword("(\.|^)devicescape\.net$", 48)//
CALL CreateServiceKeyword("(\.|^)dsnu\.net$", 48)//
CALL CreateService("DoubleVerify")//
CALL CreateServiceKeyword("(\.|^)doubleverify\.com$", 49)//
CALL CreateServiceKeyword("(\.|^)doubleverify\.com\.cdn\.cloudflare\.net$", 49)//
CALL CreateServiceKeyword("(\.|^)doubleverify\.com\.edgekey\.net$", 49)//
CALL CreateServiceKeyword("(\.|^)dvgtm\.akadns\.net$", 49)//
CALL CreateServiceKeyword("(\.|^)dvtps\.com$", 49)//
CALL CreateServiceKeyword("(\.|^)e16611\.b\.akamaiedge\.net$", 49)//
CALL CreateServiceKeyword("(\.|^)watch-dv\.zentricknv\.netdna-cdn\.com$", 49)//
CALL CreateService("Drawbridge")//
CALL CreateServiceKeyword("(\.|^)adsymptotic\.com$", 50)//
CALL CreateServiceKeyword("(\.|^)drawbridge\.com$", 50)//
CALL CreateService("Drift")//
CALL CreateServiceKeyword("(\.|^)drift\.com$", 51)//
CALL CreateServiceKeyword("(\.|^)driftcdn\.com$", 51)//
CALL CreateServiceKeyword("(\.|^)driftt\.com$", 51)//
CALL CreateServiceKeyword("(\.|^)ee15ba61-wschat-wschatalb-6fcf-2062696737\.us-east-1\.elb\.amazonaws\.com$", 51)//
CALL CreateService("Dstillery")//
CALL CreateServiceKeyword("(\.|^)dstillery\.com$", 52)//
CALL CreateServiceKeyword("(\.|^)media6degrees\.com$", 52)//
CALL CreateServiceKeyword("(\.|^)media6degrees\.com\.cdn\.cloudflare\.net$", 52)//
CALL CreateService("E-planning")//
CALL CreateServiceKeyword("(\.|^)e-planning\.net$", 53)//
CALL CreateService("EMX")//
CALL CreateServiceKeyword("(\.|^)emxdgt\.com$", 54)//
CALL CreateServiceKeyword("(\.|^)emxdigital\.com$", 54)//
CALL CreateService("Epsilon")//
CALL CreateServiceKeyword("(\.|^)epsilon\.com$", 55)//
CALL CreateService("Exponential")//
CALL CreateServiceKeyword("(\.|^)exponential\.com$", 56)//
CALL CreateServiceKeyword("(\.|^)tribalfusion\.com$", 56)//
CALL CreateService("Flashtalking")//
CALL CreateServiceKeyword("(\.|^)e1486\.b\.akamaiedge\.net$", 57)//
CALL CreateServiceKeyword("(\.|^)flashtalking\.com$", 57)//
CALL CreateServiceKeyword("(\.|^)flashtalking\.com\.edgekey\.net$", 57)//
CALL CreateService("Flurry")//
CALL CreateServiceKeyword("(\.|^)flurry\.com$", 58)//
CALL CreateService("Freewheel")//
CALL CreateServiceKeyword("(\.|^)beeswax\.com$", 59)//
CALL CreateServiceKeyword("(\.|^)beeswax\.io$", 59)//
CALL CreateServiceKeyword("(\.|^)bidr\.io$", 59)//
CALL CreateServiceKeyword("(\.|^)freewheel\.com$", 59)//
CALL CreateServiceKeyword("(\.|^)fwmrm\.net$", 59)//
CALL CreateServiceKeyword("(\.|^)stickyadstv\.com$", 59)//
CALL CreateServiceKeyword("(\.|^)stickyadstv\.com\.akadns\.net$", 59)//
CALL CreateService("Fyber")//
CALL CreateServiceKeyword("(\.|^)cdn-inner-active\.edgekey\.net$", 60)//
CALL CreateServiceKeyword("(\.|^)fyber\.com$", 60)//
CALL CreateServiceKeyword("(\.|^)inner-active\.com$", 60)//
CALL CreateServiceKeyword("(\.|^)inner-active\.mobi$", 60)//
CALL CreateService("Gemius")//
CALL CreateServiceKeyword("(\.|^)gemius\.com$", 61)//
CALL CreateServiceKeyword("(\.|^)gemius\.pl$", 61)//
CALL CreateService("Google Marketing")//
CALL CreateServiceKeyword("(\.|^)2mdn\.net$", 62)//
CALL CreateServiceKeyword("(\.|^)adsense\.google\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.ca$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.co\.in$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.co\.kr$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.co\.uk$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.co\.za$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com\.ar$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com\.au$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com\.br$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com\.co$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com\.gt$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com\.mx$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com\.pe$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com\.ph$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com\.pk$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com\.tr$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com\.tw$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.com\.vn$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.de$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.dk$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.es$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.fr$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.nl$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.no$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.ru$", 62)//
CALL CreateServiceKeyword("(\.|^)adservice\.google\.vg$", 62)//
CALL CreateServiceKeyword("(\.|^)app-measurement\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)appspot\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)doubleclick\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)doubleclick\.net$", 62)//
CALL CreateServiceKeyword("(\.|^)doubleclickbygoogle\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)google-analytics\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)googleadservices\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)googlesyndication\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)googletagmanager\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)googletagservices\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)gstaticadssl\.l\.google\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)mail-ads\.google\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)ssl-google-analytics\.l\.google\.com$", 62)//
CALL CreateServiceKeyword("(\.|^)www-googletagmanager\.l\.google\.com$", 62)//
CALL CreateService("GumGum")//
CALL CreateServiceKeyword("(\.|^)gumgum\.com$", 63)//
CALL CreateServiceKeyword("(\.|^)ixlwvc\.com$", 63)//
CALL CreateService("HeyTap")//
CALL CreateServiceKeyword("(\.|^)heytap\.com$", 64)//
CALL CreateServiceKeyword("(\.|^)heytapdl\.com$", 64)//
CALL CreateServiceKeyword("(\.|^)heytapdownload\.com$", 64)//
CALL CreateServiceKeyword("(\.|^)heytapimage\.com$", 64)//
CALL CreateServiceKeyword("(\.|^)heytapimg\.com$", 64)//
CALL CreateServiceKeyword("(\.|^)heytapmobi\.com$", 64)//
CALL CreateServiceKeyword("(\.|^)heytapmobile\.com$", 64)//
CALL CreateService("Hotjar")//
CALL CreateServiceKeyword("(\.|^)hotjar\.com$", 65)//
CALL CreateServiceKeyword("(\.|^)hotjar\.io$", 65)//
CALL CreateService("HubSpot")//
CALL CreateServiceKeyword("(\.|^)hs-analytics\.net$", 66)//
CALL CreateServiceKeyword("(\.|^)hs-banner\.com$", 66)//
CALL CreateServiceKeyword("(\.|^)hs-scripts\.com$", 66)//
CALL CreateServiceKeyword("(\.|^)hsappstatic\.net$", 66)//
CALL CreateServiceKeyword("(\.|^)hscollectedforms\.net$", 66)//
CALL CreateServiceKeyword("(\.|^)hsforms\.com$", 66)//
CALL CreateServiceKeyword("(\.|^)hsforms\.net$", 66)//
CALL CreateServiceKeyword("(\.|^)hubapi\.com$", 66)//
CALL CreateServiceKeyword("(\.|^)hubspot-realtime\.ably\.io$", 66)//
CALL CreateServiceKeyword("(\.|^)hubspot-rest\.ably\.io$", 66)//
CALL CreateServiceKeyword("(\.|^)hubspot\.com$", 66)//
CALL CreateServiceKeyword("(\.|^)hubspot\.es$", 66)//
CALL CreateServiceKeyword("(\.|^)hubspot\.net$", 66)//
CALL CreateServiceKeyword("(\.|^)hubspotemail\.net$", 66)//
CALL CreateServiceKeyword("(\.|^)sidekickopen90\.com$", 66)//
CALL CreateServiceKeyword("(\.|^)usemessages\.com$", 66)//
CALL CreateService("ID5")//
CALL CreateServiceKeyword("(\.|^)id5-sync\.com$", 67)//
CALL CreateServiceKeyword("(\.|^)id5-sync\.com\.web\.cdn\.anycast\.me$", 67)//
CALL CreateServiceKeyword("(\.|^)id5\.io$", 67)//
CALL CreateService("Improve Digital")//
CALL CreateServiceKeyword("(\.|^)360yield\.com$", 68)//
CALL CreateServiceKeyword("(\.|^)improvedigital\.com$", 68)//
CALL CreateService("InMobi")//
CALL CreateServiceKeyword("(\.|^)ads-inmobi-com-tm\.trafficmanager\.net$", 69)//
CALL CreateServiceKeyword("(\.|^)inmobi\.com$", 69)//
CALL CreateService("Inmar")//
CALL CreateServiceKeyword("(\.|^)e11294\.g\.akamaiedge\.net$", 70)//
CALL CreateServiceKeyword("(\.|^)inmar\.com$", 70)//
CALL CreateServiceKeyword("(\.|^)inmar\.com\.akadns\.net$", 70)//
CALL CreateServiceKeyword("(\.|^)owneriq\.com$", 70)//
CALL CreateServiceKeyword("(\.|^)owneriq\.net$", 70)//
CALL CreateServiceKeyword("(\.|^)owneriq\.net\.edgekey\.net$", 70)//
CALL CreateService("Innovid")//
CALL CreateServiceKeyword("(\.|^)innovid\.com$", 71)//
CALL CreateServiceKeyword("(\.|^)innovid\.com\.akadns\.net$", 71)//
CALL CreateServiceKeyword("(\.|^)innovid\.com\.edgekey\.net$", 71)//
CALL CreateServiceKeyword("(\.|^)innovid\.com\.edgesuite\.net$", 71)//
CALL CreateService("Integral Ads")//
CALL CreateServiceKeyword("(\.|^)adsafeprotected\.com$", 72)//
CALL CreateServiceKeyword("(\.|^)dt-external-217593033\.us-east-1\.elb\.amazonaws\.com$", 72)//
CALL CreateServiceKeyword("(\.|^)firewall-external-1524972847\.us-east-1\.elb\.amazonaws\.com$", 72)//
CALL CreateServiceKeyword("(\.|^)firewall-external-1941599784\.us-west-2\.elb\.amazonaws\.com$", 72)//
CALL CreateServiceKeyword("(\.|^)firewall-external-2134955858\.eu-west-1\.elb\.amazonaws\.com$", 72)//
CALL CreateServiceKeyword("(\.|^)iasds01\.com$", 72)//
CALL CreateServiceKeyword("(\.|^)integralads\.com$", 72)//
CALL CreateServiceKeyword("(\.|^)stati-stati-17tzjzscs3ogp-2139164773\.us-west-2\.elb\.amazonaws\.com$", 72)//
CALL CreateServiceKeyword("(\.|^)stati-stati-5vqsw3ctlefo-93594259\.eu-west-1\.elb\.amazonaws\.com$", 72)//
CALL CreateServiceKeyword("(\.|^)stati-stati-ej48pxrn5tqy-1796364125\.us-east-1\.elb\.amazonaws\.com$", 72)//
CALL CreateService("Intercom")//
CALL CreateServiceKeyword("(\.|^)intercom-attachments-1\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom-attachments-10\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom-attachments-11\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom-attachments-12\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom-attachments-2\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom-attachments-3\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom-attachments-4\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom-attachments-5\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom-attachments-6\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom-attachments-7\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom-attachments-8\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom-attachments-9\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercom\.io$", 73)//
CALL CreateServiceKeyword("(\.|^)intercomassets\.com$", 73)//
CALL CreateServiceKeyword("(\.|^)intercomcdn\.com$", 73)//
CALL CreateService("JW Player")//
CALL CreateServiceKeyword("(\.|^)cdn-jwplayer-com\.cdn\.ampproject\.org$", 74)//
CALL CreateServiceKeyword("(\.|^)jwpcdn\.com$", 74)//
CALL CreateServiceKeyword("(\.|^)jwplatform\.com$", 74)//
CALL CreateServiceKeyword("(\.|^)jwplayer-dualstack\.map\.fastly\.net$", 74)//
CALL CreateServiceKeyword("(\.|^)jwplayer\.com$", 74)//
CALL CreateServiceKeyword("(\.|^)jwplayer\.map\.fastly\.net$", 74)//
CALL CreateServiceKeyword("(\.|^)jwpltx\.com$", 74)//
CALL CreateServiceKeyword("(\.|^)jwpsrv\.com$", 74)//
CALL CreateServiceKeyword("(\.|^)jwpsrv\.com\.cdn\.cloudflare\.net$", 74)//
CALL CreateService("Jivox")//
CALL CreateServiceKeyword("(\.|^)jivox\.com$", 75)//
CALL CreateService("Kissmetrics")//
CALL CreateServiceKeyword("(\.|^)kissmetrics\.com$", 76)//
CALL CreateServiceKeyword("(\.|^)kissmetricshq\.com$", 76)//
CALL CreateServiceKeyword("(\.|^)neilpatel\.com$", 76)//
CALL CreateService("Klaviyo")//
CALL CreateServiceKeyword("(\.|^)klaviyo-onsite\.map\.fastly\.net$", 77)//
CALL CreateServiceKeyword("(\.|^)klaviyo\.com$", 77)//
CALL CreateServiceKeyword("(\.|^)klaviyo\.map\.fastly\.net$", 77)//
CALL CreateServiceKeyword("(\.|^)klaviyo\.zendesk\.com$", 77)//
CALL CreateServiceKeyword("(\.|^)klaviyomail\.com$", 77)//
CALL CreateService("Liftoff")//
CALL CreateServiceKeyword("(\.|^)liftoff\.io$", 78)//
CALL CreateService("LiveIntent")//
CALL CreateServiceKeyword("(\.|^)liadm\.com$", 79)//
CALL CreateServiceKeyword("(\.|^)liadm\.com\.edgekey\.net$", 79)//
CALL CreateServiceKeyword("(\.|^)liveintent\.com$", 79)//
CALL CreateService("LiveRamp")//
CALL CreateServiceKeyword("(\.|^)liveramp\.com$", 80)//
CALL CreateServiceKeyword("(\.|^)pippio\.com$", 80)//
CALL CreateService("Localytics")//
CALL CreateServiceKeyword("(\.|^)localytics\.com$", 81)//
CALL CreateService("Lotame")//
CALL CreateServiceKeyword("(\.|^)crwdcntrl\.net$", 82)//
CALL CreateServiceKeyword("(\.|^)lotame\.com$", 82)//
CALL CreateService("MGID")//
CALL CreateServiceKeyword("(\.|^)mgid\.com$", 83)//
CALL CreateService("MPulse Software")//
CALL CreateServiceKeyword("(\.|^)e9858\.dscx\.akamaiedge\.net$", 84)//
CALL CreateServiceKeyword("(\.|^)go-mpulse\.net$", 84)//
CALL CreateServiceKeyword("(\.|^)go-mpulse\.net\.edgekey\.net$", 84)//
CALL CreateServiceKeyword("(\.|^)mpulsesoftware\.com$", 84)//
CALL CreateService("Magnite")//
CALL CreateServiceKeyword("(\.|^)e8960\.b\.akamaiedge\.net$", 85)//
CALL CreateServiceKeyword("(\.|^)e8960\.e2\.akamaiedge\.net$", 85)//
CALL CreateServiceKeyword("(\.|^)magnite\.com$", 85)//
CALL CreateServiceKeyword("(\.|^)rubiconproject\.com$", 85)//
CALL CreateServiceKeyword("(\.|^)rubiconproject\.com-v1\.edgekey\.net$", 85)//
CALL CreateServiceKeyword("(\.|^)rubiconproject\.com\.edgekey\.net$", 85)//
CALL CreateServiceKeyword("(\.|^)rubiconproject\.net\.akadns\.net$", 85)//
CALL CreateService("Mailchimp")//
CALL CreateServiceKeyword("(\.|^)chimpstatic\.com$", 86)//
CALL CreateServiceKeyword("(\.|^)e13829\.x\.akamaiedge\.net$", 86)//
CALL CreateServiceKeyword("(\.|^)list-manage\.com$", 86)//
CALL CreateServiceKeyword("(\.|^)mailchimp\.com$", 86)//
CALL CreateServiceKeyword("(\.|^)mcusercontent\.com$", 86)//
CALL CreateService("Marin Software")//
CALL CreateServiceKeyword("(\.|^)marinsoftware\.com$", 87)//
CALL CreateServiceKeyword("(\.|^)prfct\.co$", 87)//
CALL CreateService("Medallia")//
CALL CreateServiceKeyword("(\.|^)medallia\.ca$", 88)//
CALL CreateServiceKeyword("(\.|^)medallia\.com$", 88)//
CALL CreateServiceKeyword("(\.|^)medallia\.eu$", 88)//
CALL CreateServiceKeyword("(\.|^)medallia\.map\.fastly\.net$", 88)//
CALL CreateServiceKeyword("(\.|^)medallia\.s3\.amazonaws\.com$", 88)//
CALL CreateService("Media.net")//
CALL CreateServiceKeyword("(\.|^)media\.net$", 89)//
CALL CreateServiceKeyword("(\.|^)media\.net\.akadns6\.net$", 89)//
CALL CreateService("MediaMath")//
CALL CreateServiceKeyword("(\.|^)mathtag\.com$", 90)//
CALL CreateServiceKeyword("(\.|^)mediamath\.com$", 90)//
CALL CreateService("Merkle Marketing")//
CALL CreateServiceKeyword("(\.|^)4cite\.com$", 91)//
CALL CreateServiceKeyword("(\.|^)amicusdigital\.com\.au$", 91)//
CALL CreateServiceKeyword("(\.|^)axis41\.com$", 91)//
CALL CreateServiceKeyword("(\.|^)merkleinc\.com$", 91)//
CALL CreateServiceKeyword("(\.|^)merkleresponse\.com$", 91)//
CALL CreateServiceKeyword("(\.|^)rkdms\.com$", 91)//
CALL CreateServiceKeyword("(\.|^)securedvisit\.com$", 91)//
CALL CreateServiceKeyword("(\.|^)sokrati\.com$", 91)//
CALL CreateServiceKeyword("(\.|^)ugamsolutions\.com$", 91)//
CALL CreateService("Mixpanel")//
CALL CreateServiceKeyword("(\.|^)mixpanel\.com$", 92)//
CALL CreateService("MoPub")//
CALL CreateServiceKeyword("(\.|^)mopub\.com$", 93)//
CALL CreateService("Moat Ad Search")//
CALL CreateServiceKeyword("(\.|^)e13136\.d\.akamaiedge\.net$", 94)//
CALL CreateServiceKeyword("(\.|^)e13136\.g\.akamaiedge\.net$", 94)//
CALL CreateServiceKeyword("(\.|^)moat-ads\.s3\.amazonaws\.com$", 94)//
CALL CreateServiceKeyword("(\.|^)moat\.com$", 94)//
CALL CreateServiceKeyword("(\.|^)moatads\.com$", 94)//
CALL CreateServiceKeyword("(\.|^)moatads\.com\.edgekey\.net$", 94)//
CALL CreateServiceKeyword("(\.|^)moatpixel\.com$", 94)//
CALL CreateServiceKeyword("(\.|^)moatpixel1\.edgekey\.net$", 94)//
CALL CreateServiceKeyword("(\.|^)moatsearch-data\.s3\.amazonaws\.com$", 94)//
CALL CreateServiceKeyword("(\.|^)nado-ecs-lb-us-east-1-1502216065\.us-east-1\.elb\.amazonaws\.com$", 94)//
CALL CreateServiceKeyword("(\.|^)nado-ecs-lb-us-east-2-1690985176\.us-east-2\.elb\.amazonaws\.com$", 94)//
CALL CreateService("Momentive")//
CALL CreateServiceKeyword("(\.|^)getfeedback\.com$", 95)//
CALL CreateServiceKeyword("(\.|^)momentive\.ai$", 95)//
CALL CreateServiceKeyword("(\.|^)surveymonkey-assets\.s3\.amazonaws\.com$", 95)//
CALL CreateServiceKeyword("(\.|^)surveymonkey\.ca$", 95)//
CALL CreateServiceKeyword("(\.|^)surveymonkey\.co\.uk$", 95)//
CALL CreateServiceKeyword("(\.|^)surveymonkey\.com$", 95)//
CALL CreateServiceKeyword("(\.|^)surveymonkey\.net$", 95)//
CALL CreateServiceKeyword("(\.|^)usabilla\.com$", 95)//
CALL CreateService("Narratiive")//
CALL CreateServiceKeyword("(\.|^)effectivemeasure\.net$", 96)//
CALL CreateServiceKeyword("(\.|^)narratiive\.com$", 96)//
CALL CreateService("Narrativ")//
CALL CreateServiceKeyword("(\.|^)bam-x\.com$", 97)//
CALL CreateServiceKeyword("(\.|^)narrativ\.com$", 97)//
CALL CreateService("Nielsen Marketing")//
CALL CreateServiceKeyword("(\.|^)exelator\.com$", 98)//
CALL CreateServiceKeyword("(\.|^)imrworldwide\.com$", 98)//
CALL CreateServiceKeyword("(\.|^)nielsen\.com$", 98)//
CALL CreateService("OneSignal")//
CALL CreateServiceKeyword("(\.|^)onesignal\.com$", 99)//
CALL CreateService("OpenX")//
CALL CreateServiceKeyword("(\.|^)openx\.net$", 100)//
CALL CreateService("Opensignal")//
CALL CreateServiceKeyword("(\.|^)opensignal\.com$", 101)//
CALL CreateService("Optimizely")//
CALL CreateServiceKeyword("(\.|^)optimizely\.com$", 102)//
CALL CreateServiceKeyword("(\.|^)p13nlog-1106815646\.us-east-1\.elb\.amazonaws\.com$", 102)//
CALL CreateService("Oracle Advertising")//
CALL CreateServiceKeyword("(\.|^)a1cbafa5ea9a6480cb8e9ffba46cbad9-466059813\.us-west-2\.elb\.amazonaws\.com$", 103)//
CALL CreateServiceKeyword("(\.|^)a7cb1ba23276f4b358d8fca4e8cdf9ab-1165437553\.us-east-1\.elb\.amazonaws\.com$", 103)//
CALL CreateServiceKeyword("(\.|^)ac2409ed291e04841b424223a3ec4991-926974307\.us-west-2\.elb\.amazonaws\.com$", 103)//
CALL CreateServiceKeyword("(\.|^)addthis\.com$", 103)//
CALL CreateServiceKeyword("(\.|^)addthis\.com\.edgekey\.net$", 103)//
CALL CreateServiceKeyword("(\.|^)addthiscdn\.com$", 103)//
CALL CreateServiceKeyword("(\.|^)addthisedge\.com$", 103)//
CALL CreateServiceKeyword("(\.|^)addthisedge\.com\.edgekey\.net$", 103)//
CALL CreateServiceKeyword("(\.|^)bluekai\.com$", 103)//
CALL CreateServiceKeyword("(\.|^)bluekai\.com\.edgekey\.net$", 103)//
CALL CreateServiceKeyword("(\.|^)e11123\.x\.akamaiedge\.net$", 103)//
CALL CreateServiceKeyword("(\.|^)e4016\.a\.akamaiedge\.net$", 103)//
CALL CreateServiceKeyword("(\.|^)eloqua\.com$", 103)//
CALL CreateServiceKeyword("(\.|^)eloqua\.com\.edgesuite\.net$", 103)//
CALL CreateServiceKeyword("(\.|^)odc-addthis-prod-01\.oracle\.com$", 103)//
CALL CreateServiceKeyword("(\.|^)odc-pixel-prod-01\.oracle\.com$", 103)//
CALL CreateServiceKeyword("(\.|^)oracleinfinity\.io$", 103)//
CALL CreateServiceKeyword("(\.|^)oracleinfinity\.io\.akadns\.net$", 103)//
CALL CreateServiceKeyword("(\.|^)oracleinfinity\.io\.edgekey\.net$", 103)//
CALL CreateServiceKeyword("(\.|^)responsys\.net$", 103)//
CALL CreateServiceKeyword("(\.|^)responsys\.net\.edgekey\.net$", 103)//
CALL CreateService("Outbrain")//
CALL CreateServiceKeyword("(\.|^)discoveryfeed\.org$", 104)//
CALL CreateServiceKeyword("(\.|^)e10883\.g\.akamaiedge\.net$", 104)//
CALL CreateServiceKeyword("(\.|^)outbrain\.com$", 104)//
CALL CreateServiceKeyword("(\.|^)outbrain\.com\.edgekey\.net$", 104)//
CALL CreateServiceKeyword("(\.|^)outbrain\.map\.fastly\.net$", 104)//
CALL CreateServiceKeyword("(\.|^)outbrain\.org$", 104)//
CALL CreateServiceKeyword("(\.|^)outbrainimg\.com$", 104)//
CALL CreateServiceKeyword("(\.|^)outbrainimg\.com\.edgekey\.net$", 104)//
CALL CreateServiceKeyword("(\.|^)widgets-outbrain-com\.cdn\.ampproject\.org$", 104)//
CALL CreateServiceKeyword("(\.|^)zemanta\.com$", 104)//
CALL CreateService("PopAds")//
CALL CreateServiceKeyword("(\.|^)popads\.net$", 105)//
CALL CreateService("Postie")//
CALL CreateServiceKeyword("(\.|^)getletterpress\.com$", 106)//
CALL CreateServiceKeyword("(\.|^)postie\.com$", 106)//
CALL CreateService("Primis")//
CALL CreateServiceKeyword("(\.|^)primis\.tech$", 107)//
CALL CreateService("PubMatic")//
CALL CreateServiceKeyword("(\.|^)e6603\.g\.akamaiedge\.net$", 108)//
CALL CreateServiceKeyword("(\.|^)pubmatic\.com$", 108)//
CALL CreateServiceKeyword("(\.|^)pubmnet\.com$", 108)//
CALL CreateService("PulsePoint")//
CALL CreateServiceKeyword("(\.|^)contextweb\.com$", 109)//
CALL CreateServiceKeyword("(\.|^)pulsepoint\.com$", 109)//
CALL CreateService("Pusher")//
CALL CreateServiceKeyword("(\.|^)mt1-ws-1895636413\.us-east-1\.elb\.amazonaws\.com$", 110)//
CALL CreateServiceKeyword("(\.|^)pusher\.com$", 110)//
CALL CreateServiceKeyword("(\.|^)pusherapp\.com$", 110)//
CALL CreateService("Qualtrics")//
CALL CreateServiceKeyword("(\.|^)qualtrics\.com$", 111)//
CALL CreateServiceKeyword("(\.|^)qualtrics\.com\.cdn\.cloudflare\.net$", 111)//
CALL CreateServiceKeyword("(\.|^)qualtrics\.com\.edgekey\.net$", 111)//
CALL CreateService("Quantcast")//
CALL CreateServiceKeyword("(\.|^)quantcast\.com$", 112)//
CALL CreateServiceKeyword("(\.|^)quantcount\.com$", 112)//
CALL CreateServiceKeyword("(\.|^)quantserve\.com$", 112)//
CALL CreateService("RTB House")//
CALL CreateServiceKeyword("(\.|^)creativecdn\.com$", 113)//
CALL CreateServiceKeyword("(\.|^)rtbhouse\.com$", 113)//
CALL CreateService("RhythmOne")//
CALL CreateServiceKeyword("(\.|^)1rx\.io$", 114)//
CALL CreateServiceKeyword("(\.|^)1rxntv\.io$", 114)//
CALL CreateServiceKeyword("(\.|^)gwallet\.com$", 114)//
CALL CreateServiceKeyword("(\.|^)rhythmone\.com$", 114)//
CALL CreateServiceKeyword("(\.|^)unruly\.co$", 114)//
CALL CreateServiceKeyword("(\.|^)unruly\.systems$", 114)//
CALL CreateServiceKeyword("(\.|^)unrulymedia\.com$", 114)//
CALL CreateServiceKeyword("(\.|^)videohub\.tv$", 114)//
CALL CreateServiceKeyword("(\.|^)videohub\.tv\.cdn\.cloudflare\.net$", 114)//
CALL CreateService("Salesforce")//
CALL CreateServiceKeyword("(\.|^)documentforce\.com$", 115)//
CALL CreateServiceKeyword("(\.|^)exacttarget\.com$", 115)//
CALL CreateServiceKeyword("(\.|^)exacttarget\.com\.edgekey\.net$", 115)//
CALL CreateServiceKeyword("(\.|^)exacttarget\.com\.mdc\.edgesuite\.net$", 115)//
CALL CreateServiceKeyword("(\.|^)exct\.net$", 115)//
CALL CreateServiceKeyword("(\.|^)force\.com$", 115)//
CALL CreateServiceKeyword("(\.|^)krxd\.net$", 115)//
CALL CreateServiceKeyword("(\.|^)pardot\.com$", 115)//
CALL CreateServiceKeyword("(\.|^)prod-ash-beacon-1960876484\.us-east-1\.elb\.amazonaws\.com$", 115)//
CALL CreateServiceKeyword("(\.|^)prod-dub-beacon-1484770602\.eu-west-1\.elb\.amazonaws\.com$", 115)//
CALL CreateServiceKeyword("(\.|^)prod-pdx-beacon-1406086907\.us-west-2\.elb\.amazonaws\.com$", 115)//
CALL CreateServiceKeyword("(\.|^)salesforce\.com$", 115)//
CALL CreateServiceKeyword("(\.|^)salesforcecom\.demdex\.net$", 115)//
CALL CreateServiceKeyword("(\.|^)salesforceliveagent\.com$", 115)//
CALL CreateServiceKeyword("(\.|^)sfmc-content\.com$", 115)//
CALL CreateService("ScientiaMobile")//
CALL CreateServiceKeyword("(\.|^)scientiamobile\.com$", 116)//
CALL CreateServiceKeyword("(\.|^)wurfl\.io$", 116)//
CALL CreateService("Segment")//
CALL CreateServiceKeyword("(\.|^)segment\.com$", 117)//
CALL CreateServiceKeyword("(\.|^)segment\.io$", 117)//
CALL CreateService("ShareThis")//
CALL CreateServiceKeyword("(\.|^)sharethis\.com$", 118)//
CALL CreateService("Sharethrough")//
CALL CreateServiceKeyword("(\.|^)sharethrough\.com$", 119)//
CALL CreateService("Simpli.fi")//
CALL CreateServiceKeyword("(\.|^)simpli\.fi$", 120)//
CALL CreateService("Smart AdServer")//
CALL CreateServiceKeyword("(\.|^)sascdn\.com$", 121)//
CALL CreateServiceKeyword("(\.|^)smartadserver\.com$", 121)//
CALL CreateService("Sourcepoint")//
CALL CreateServiceKeyword("(\.|^)sourcepoint\.com$", 122)//
CALL CreateServiceKeyword("(\.|^)sp-prod\.net$", 122)//
CALL CreateServiceKeyword("(\.|^)summerhamster\.com$", 122)//
CALL CreateService("StackAdapt")//
CALL CreateServiceKeyword("(\.|^)stackadapt\.com$", 123)//
CALL CreateServiceKeyword("(\.|^)stackadaptdis\.s3\.amazonaws\.com$", 123)//
CALL CreateServiceKeyword("(\.|^)stackadapttemp\.s3\.amazonaws\.com$", 123)//
CALL CreateServiceKeyword("(\.|^)stackadaptvid\.s3\.amazonaws\.com$", 123)//
CALL CreateService("TANX Ads")//
CALL CreateServiceKeyword("(\.|^)tanx\.com$", 124)//
CALL CreateServiceKeyword("(\.|^)tanx\.com\.gds\.alibabadns\.com$", 124)//
CALL CreateService("Taboola")//
CALL CreateServiceKeyword("(\.|^)connexity\.com$", 125)//
CALL CreateServiceKeyword("(\.|^)connexity\.net$", 125)//
CALL CreateServiceKeyword("(\.|^)img-taboola\.com$", 125)//
CALL CreateServiceKeyword("(\.|^)perfectmarket\.com$", 125)//
CALL CreateServiceKeyword("(\.|^)taboola\.com$", 125)//
CALL CreateServiceKeyword("(\.|^)taboola\.map\.fastly\.net$", 125)//
CALL CreateServiceKeyword("(\.|^)zorosrv\.com$", 125)//
CALL CreateService("Tapad")//
CALL CreateServiceKeyword("(\.|^)tapad\.com$", 126)//
CALL CreateService("Tapjoy")//
CALL CreateServiceKeyword("(\.|^)rpc-tapjoy-com-lb-1378811527\.us-east-1\.elb\.amazonaws\.com$", 127)//
CALL CreateServiceKeyword("(\.|^)tapjoy-com-lb-vpc-332546193\.us-east-1\.elb\.amazonaws\.com$", 127)//
CALL CreateServiceKeyword("(\.|^)tapjoy\.com$", 127)//
CALL CreateService("Taplytics")//
CALL CreateServiceKeyword("(\.|^)taplytics\.com$", 128)//
CALL CreateService("Teads")//
CALL CreateServiceKeyword("(\.|^)e9957\.b\.akamaiedge\.net$", 129)//
CALL CreateServiceKeyword("(\.|^)e9957\.d\.akamaiedge\.net$", 129)//
CALL CreateServiceKeyword("(\.|^)e9957\.dsce4\.akamaiedge\.net$", 129)//
CALL CreateServiceKeyword("(\.|^)e9957\.e4\.akamaiedge\.net$", 129)//
CALL CreateServiceKeyword("(\.|^)teads\.com$", 129)//
CALL CreateServiceKeyword("(\.|^)teads\.tv$", 129)//
CALL CreateServiceKeyword("(\.|^)teads\.tv\.edgekey\.net$", 129)//
CALL CreateService("Tealium")//
CALL CreateServiceKeyword("(\.|^)tealium\.com$", 130)//
CALL CreateServiceKeyword("(\.|^)tiqcdn\.com$", 130)//
CALL CreateService("Telaria Video")//
CALL CreateServiceKeyword("(\.|^)partners-alb-1113315349\.us-east-1\.elb\.amazonaws\.com$", 131)//
CALL CreateServiceKeyword("(\.|^)telaria\.com$", 131)//
CALL CreateServiceKeyword("(\.|^)tremorhub\.com$", 131)//
CALL CreateServiceKeyword("(\.|^)wildcard-ads-new-1653986885\.us-east-1\.elb\.amazonaws\.com$", 131)//
CALL CreateService("The Trade Desk")//
CALL CreateServiceKeyword("(\.|^)adsrvr\.org$", 132)//
CALL CreateServiceKeyword("(\.|^)insight-1616140656\.us-west-2\.elb\.amazonaws\.com$", 132)//
CALL CreateServiceKeyword("(\.|^)insight-760077375\.us-east-1\.elb\.amazonaws\.com$", 132)//
CALL CreateServiceKeyword("(\.|^)match-1943069928\.eu-west-1\.elb\.amazonaws\.com$", 132)//
CALL CreateServiceKeyword("(\.|^)match-975362022\.us-east-1\.elb\.amazonaws\.com$", 132)//
CALL CreateServiceKeyword("(\.|^)quilvem\.com$", 132)//
CALL CreateServiceKeyword("(\.|^)thetradedesk\.com$", 132)//
CALL CreateServiceKeyword("(\.|^)tracking-1659963975\.ap-southeast-1\.elb\.amazonaws\.com$", 132)//
CALL CreateServiceKeyword("(\.|^)tracking-485952388\.us-east-1\.elb\.amazonaws\.com$", 132)//
CALL CreateService("TowerData")//
CALL CreateServiceKeyword("(\.|^)rlcdn\.com$", 133)//
CALL CreateServiceKeyword("(\.|^)towerdata\.com$", 133)//
CALL CreateService("TripleLift")//
CALL CreateServiceKeyword("(\.|^)3lift\.com$", 134)//
CALL CreateServiceKeyword("(\.|^)dualstack\.dmp-sync-prod-807518517\.us-east-1\.elb\.amazonaws\.com$", 134)//
CALL CreateServiceKeyword("(\.|^)dualstack\.engagement-bus-prod-641612343\.eu-central-1\.elb\.amazonaws\.com$", 134)//
CALL CreateServiceKeyword("(\.|^)dualstack\.engagement-bus-prod-713264365\.us-east-1\.elb\.amazonaws\.com$", 134)//
CALL CreateServiceKeyword("(\.|^)dualstack\.exchange-prod-1441208382\.us-east-1\.elb\.amazonaws\.com$", 134)//
CALL CreateServiceKeyword("(\.|^)dualstack\.exchange-prod-582331669\.us-west-1\.elb\.amazonaws\.com$", 134)//
CALL CreateServiceKeyword("(\.|^)triplelift\.com$", 134)//
CALL CreateService("Umeng")//
CALL CreateServiceKeyword("(\.|^)umeng\.com$", 135)//
CALL CreateServiceKeyword("(\.|^)umeng\.com\.gds\.alibabadns\.com$", 135)//
CALL CreateServiceKeyword("(\.|^)umengcloud\.com$", 135)//
CALL CreateServiceKeyword("(\.|^)umengcloud\.com\.gds\.alibabadns\.com$", 135)//
CALL CreateService("Undertone")//
CALL CreateServiceKeyword("(\.|^)undertone\.com$", 136)//
CALL CreateService("Verizon Media")//
CALL CreateServiceKeyword("(\.|^)adap\.tv$", 137)//
CALL CreateServiceKeyword("(\.|^)ads-b-1941474562\.us-east-1\.elb\.amazonaws\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)ads-b-480313385\.us-west-1\.elb\.amazonaws\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)ads-c-1854119718\.us-west-1\.elb\.amazonaws\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)adtechus\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)advertising\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)edgecastcdn\.net$", 137)//
CALL CreateServiceKeyword("(\.|^)edgecastdns\.net$", 137)//
CALL CreateServiceKeyword("(\.|^)log-c-2144142094\.us-west-1\.elb\.amazonaws\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)log-c-907025318\.us-east-1\.elb\.amazonaws\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)m-node-alb-ssl-1111-1982902297\.us-east-1\.elb\.amazonaws\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)nexage\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)nginx-uset1-ext-prod-a-1782952659\.us-east-1\.elb\.amazonaws\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)oath\.cloud$", 137)//
CALL CreateServiceKeyword("(\.|^)oath\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)onebyaol\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)phicdn\.net$", 137)//
CALL CreateServiceKeyword("(\.|^)verizondigitalmedia\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)verizonmedia\.com$", 137)//
CALL CreateServiceKeyword("(\.|^)vidible\.tv$", 137)//
CALL CreateService("Viant Adelphic")//
CALL CreateServiceKeyword("(\.|^)adelphic\.com$", 138)//
CALL CreateServiceKeyword("(\.|^)ipredictive\.com$", 138)//
CALL CreateServiceKeyword("(\.|^)viantinc\.com$", 138)//
CALL CreateService("Vungle")//
CALL CreateServiceKeyword("(\.|^)vungle\.akadns\.net$", 139)//
CALL CreateServiceKeyword("(\.|^)vungle\.com$", 139)//
CALL CreateServiceKeyword("(\.|^)vungle\.com\.edgekey\.net$", 139)//
CALL CreateServiceKeyword("(\.|^)vungle\.edgesuite\.net$", 139)//
CALL CreateService("WalkMe")//
CALL CreateServiceKeyword("(\.|^)e12923\.b\.akamaiedge\.net$", 140)//
CALL CreateServiceKeyword("(\.|^)e12923\.dscb\.akamaiedge\.net$", 140)//
CALL CreateServiceKeyword("(\.|^)walkme\.com$", 140)//
CALL CreateServiceKeyword("(\.|^)walkme\.com\.a\.edgekey\.net$", 140)//
CALL CreateServiceKeyword("(\.|^)walkme\.com\.edgekey\.net$", 140)//
CALL CreateServiceKeyword("(\.|^)walkmeusercontent\.com$", 140)//
CALL CreateService("Wistia")//
CALL CreateServiceKeyword("(\.|^)embedwistia-a\.akamaihd\.net$", 141)//
CALL CreateServiceKeyword("(\.|^)wistia\.com$", 141)//
CALL CreateService("Xaxis")//
CALL CreateServiceKeyword("(\.|^)mookie1\.com$", 142)//
CALL CreateServiceKeyword("(\.|^)themig\.com$", 142)//
CALL CreateServiceKeyword("(\.|^)xaxis\.com$", 142)//
CALL CreateService("Yahoo Ads")//
CALL CreateServiceKeyword("(\.|^)ads\.yahoo\.com$", 143)//
CALL CreateServiceKeyword("(\.|^)analytics\.yahoo\.com$", 143)//
CALL CreateService("Yandex")//
CALL CreateServiceKeyword("(\.|^)yandex\.com$", 144)//
CALL CreateServiceKeyword("(\.|^)yandex\.com\.tr$", 144)//
CALL CreateServiceKeyword("(\.|^)yandex\.kz$", 144)//
CALL CreateServiceKeyword("(\.|^)yandex\.net$", 144)//
CALL CreateServiceKeyword("(\.|^)yandex\.ru$", 144)//
CALL CreateServiceKeyword("(\.|^)yandex\.ua$", 144)//
CALL CreateServiceKeyword("(\.|^)yastatic\.net$", 144)//
CALL CreateService("Zeta Global")//
CALL CreateServiceKeyword("(\.|^)ignitionone\.com$", 145)//
CALL CreateServiceKeyword("(\.|^)netmng\.com$", 145)//
CALL CreateServiceKeyword("(\.|^)zetaglobal\.com$", 145)//
CALL CreateServiceKeyword("(\.|^)zetaglobal\.net$", 145)//
CALL CreateServiceKeyword("(\.|^)zetaglobal\.net\.akadns\.net$", 145)//
CALL CreateServiceKeyword("(\.|^)zetapgmt\.akadns\.net$", 145)//
CALL CreateService("comScore")//
CALL CreateServiceKeyword("(\.|^)comscore\.com$", 146)//
CALL CreateServiceKeyword("(\.|^)comscoreresearch\.com$", 146)//
CALL CreateServiceKeyword("(\.|^)scorecardresearch\.com$", 146)//
CALL CreateService("intent Media")//
CALL CreateServiceKeyword("(\.|^)intent\.com$", 147)//
CALL CreateServiceKeyword("(\.|^)intentmedia\.net$", 147)//
CALL CreateService("ironSource")//
CALL CreateServiceKeyword("(\.|^)ironsrc\.com$", 148)//
CALL CreateServiceKeyword("(\.|^)ironsrc\.net$", 148)//
CALL CreateServiceKeyword("(\.|^)supersonicads-a\.akamaihd\.net$", 148)//
CALL CreateServiceKeyword("(\.|^)supersonicads\.com$", 148)//
CALL CreateService("mParticle")//
CALL CreateServiceKeyword("(\.|^)mparticle\.com$", 149)//
CALL CreateServiceKeyword("(\.|^)mparticle\.map\.fastly\.net$", 149)//
CALL CreateService("ABC Australia")//
CALL CreateServiceKeyword("(\.|^)abc\.net\.au$", 150)//
CALL CreateServiceKeyword("(\.|^)abc\.net\.au\.edgekey\.net$", 150)//
CALL CreateServiceKeyword("(\.|^)abcaustralia\.net\.au$", 150)//
CALL CreateServiceKeyword("(\.|^)amp-abc-net-au\.cdn\.ampproject\.org$", 150)//
CALL CreateServiceKeyword("(\.|^)res-abc-net-au\.cdn\.ampproject\.org$", 150)//
CALL CreateService("Apple iTunes")//
CALL CreateServiceKeyword("(\.|^)applemusic\.apple$", 151)//
CALL CreateServiceKeyword("(\.|^)e673\.dsce9\.akamaiedge\.net$", 151)//
CALL CreateServiceKeyword("(\.|^)itun\.es$", 151)//
CALL CreateServiceKeyword("(\.|^)itunes-apple\.com\.akadns\.net$", 151)//
CALL CreateServiceKeyword("(\.|^)itunes\.apple\.com$", 151)//
CALL CreateServiceKeyword("(\.|^)itunes\.apple\.com\.edgesuite\.net$", 151)//
CALL CreateServiceKeyword("(\.|^)itunes\.ca$", 151)//
CALL CreateServiceKeyword("(\.|^)itunes\.co$", 151)//
CALL CreateServiceKeyword("(\.|^)itunes\.co\.th$", 151)//
CALL CreateServiceKeyword("(\.|^)itunes\.com$", 151)//
CALL CreateServiceKeyword("(\.|^)itunes\.hk$", 151)//
CALL CreateServiceKeyword("(\.|^)itunes\.mx$", 151)//
CALL CreateServiceKeyword("(\.|^)itunes\.org$", 151)//
CALL CreateServiceKeyword("(\.|^)itunes\.us$", 151)//
CALL CreateServiceKeyword("(\.|^)music\.apple\.com$", 151)//
CALL CreateService("Audible")//
CALL CreateServiceKeyword("(\.|^)audible\.ca$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.co\.jp$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.co\.uk$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.com$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.com\.au$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.custhelp\.com$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.de$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.demdex\.net$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.es$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.fr$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.in$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.it$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.sc\.omtrdc\.net$", 152)//
CALL CreateServiceKeyword("(\.|^)audible\.tt\.omtrdc\.net$", 152)//
CALL CreateService("BBC")//
CALL CreateServiceKeyword("(\.|^)bbc\.co\.uk$", 153)//
CALL CreateServiceKeyword("(\.|^)bbc\.co\.uk\.edgekey\.net$", 153)//
CALL CreateServiceKeyword("(\.|^)bbc\.com$", 153)//
CALL CreateServiceKeyword("(\.|^)bbc\.com\.edgekey\.net$", 153)//
CALL CreateServiceKeyword("(\.|^)bbc\.map\.fastly\.net$", 153)//
CALL CreateServiceKeyword("(\.|^)bbc\.net\.uk$", 153)//
CALL CreateServiceKeyword("(\.|^)bbcfmt\.s\.llnwi\.net$", 153)//
CALL CreateServiceKeyword("(\.|^)bbci\.co\.uk$", 153)//
CALL CreateServiceKeyword("(\.|^)bbci\.co\.uk\.edgekey\.net$", 153)//
CALL CreateServiceKeyword("(\.|^)bbcmedia\.co\.uk$", 153)//
CALL CreateServiceKeyword("(\.|^)bbctvapps\.co\.uk$", 153)//
CALL CreateServiceKeyword("(\.|^)gel-files-bbci-co-uk\.cdn\.ampproject\.org$", 153)//
CALL CreateServiceKeyword("(\.|^)ichef-bbci-co-uk\.cdn\.ampproject\.org$", 153)//
CALL CreateServiceKeyword("(\.|^)static-files-bbci-co-uk\.cdn\.ampproject\.org$", 153)//
CALL CreateServiceKeyword("(\.|^)www-bbc-com\.cdn\.ampproject\.org$", 153)//
CALL CreateService("Bell Media")//
CALL CreateServiceKeyword("(\.|^)bellmedia\.ca$", 154)//
CALL CreateServiceKeyword("(\.|^)bellmedia\.demdex\.net$", 154)//
CALL CreateServiceKeyword("(\.|^)bellmedia\.hb\.omtrdc\.net$", 154)//
CALL CreateServiceKeyword("(\.|^)bellmedia\.map\.fastly\.net$", 154)//
CALL CreateServiceKeyword("(\.|^)bellmedia\.sc\.omtrdc\.net$", 154)//
CALL CreateService("Blogger")//
CALL CreateServiceKeyword("(\.|^)blogger\.com$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.ae$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.al$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.am$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.ba$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.be$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.bg$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.ca$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.ch$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.cl$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.co\.at$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.co\.id$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.co\.il$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.co\.ke$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.co\.nz$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.co\.uk$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.co\.za$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.ar$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.au$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.br$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.by$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.co$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.cy$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.ee$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.eg$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.es$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.mt$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.ng$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.tr$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.com\.uy$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.cz$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.de$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.dk$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.fi$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.fr$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.gr$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.hk$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.hr$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.hu$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.ie$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.in$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.is$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.it$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.jp$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.kr$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.li$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.lt$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.lu$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.md$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.mk$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.mx$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.my$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.nl$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.no$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.pe$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.pt$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.qa$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.ro$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.rs$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.ru$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.se$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.sg$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.si$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.sk$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.sn$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.td$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.tw$", 155)//
CALL CreateServiceKeyword("(\.|^)blogspot\.ug$", 155)//
CALL CreateServiceKeyword("(\.|^)googleblog\.com$", 155)//
CALL CreateService("Brightcove")//
CALL CreateServiceKeyword("(\.|^)bcove\.video$", 156)//
CALL CreateServiceKeyword("(\.|^)bcovlive-a\.akamaihd\.net$", 156)//
CALL CreateServiceKeyword("(\.|^)bcovlive\.io$", 156)//
CALL CreateServiceKeyword("(\.|^)bcvp0rtal\.com$", 156)//
CALL CreateServiceKeyword("(\.|^)boltdns\.net$", 156)//
CALL CreateServiceKeyword("(\.|^)brightcove\.com$", 156)//
CALL CreateServiceKeyword("(\.|^)brightcove\.map\.fastly\.net$", 156)//
CALL CreateServiceKeyword("(\.|^)brightcove\.net$", 156)//
CALL CreateServiceKeyword("(\.|^)brightcove\.vo\.llnwd\.net$", 156)//
CALL CreateServiceKeyword("(\.|^)brightcovecdn\.com$", 156)//
CALL CreateServiceKeyword("(\.|^)ooyala\.com$", 156)//
CALL CreateService("BuzzFeed")//
CALL CreateServiceKeyword("(\.|^)buzzfeed-com\.videoplayerhub\.com$", 157)//
CALL CreateServiceKeyword("(\.|^)buzzfeed\.com$", 157)//
CALL CreateServiceKeyword("(\.|^)buzzfeed\.de$", 157)//
CALL CreateServiceKeyword("(\.|^)buzzfeed2\.map\.fastly\.net$", 157)//
CALL CreateServiceKeyword("(\.|^)buzzfeednews\.com$", 157)//
CALL CreateServiceKeyword("(\.|^)img-buzzfeed-com\.cdn\.ampproject\.org$", 157)//
CALL CreateServiceKeyword("(\.|^)www-buzzfeed-com\.cdn\.ampproject\.org$", 157)//
CALL CreateServiceKeyword("(\.|^)www-buzzfeednews-com\.cdn\.ampproject\.org$", 157)//
CALL CreateService("ByteDance")//
CALL CreateServiceKeyword("(\.|^)bytecdn\.cn$", 158)//
CALL CreateServiceKeyword("(\.|^)byted-static\.com$", 158)//
CALL CreateServiceKeyword("(\.|^)byted\.org$", 158)//
CALL CreateServiceKeyword("(\.|^)bytedance\.com$", 158)//
CALL CreateServiceKeyword("(\.|^)bytedance\.com\.edgesuite\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)bytedance\.com\.w\.cdngslb\.com$", 158)//
CALL CreateServiceKeyword("(\.|^)bytedance\.map\.fastly\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)bytedance\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)bytedanceapi\.com$", 158)//
CALL CreateServiceKeyword("(\.|^)bytedns\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)byteimg\.com$", 158)//
CALL CreateServiceKeyword("(\.|^)byteoversea\.com$", 158)//
CALL CreateServiceKeyword("(\.|^)byteoversea\.com\.edgekey\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)byteoversea\.com\.edgesuite\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)byteoversea\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)byteoversea\.net\.edgesuite\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)bytetcdn\.com$", 158)//
CALL CreateServiceKeyword("(\.|^)ibytedtos\.com$", 158)//
CALL CreateServiceKeyword("(\.|^)ibytedtos\.com\.edgekey\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)ibytedtos\.com\.edgesuite\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)ibyteimg\.com$", 158)//
CALL CreateServiceKeyword("(\.|^)ibyteimg\.com\.akamaized\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)ibyteimg\.com\.edgesuite\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)ipstatp\.com$", 158)//
CALL CreateServiceKeyword("(\.|^)ipstatp\.com\.edgekey\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)ipstatp\.com\.edgesuite\.net$", 158)//
CALL CreateServiceKeyword("(\.|^)pstatp\.com$", 158)//
CALL CreateService("CBC")//
CALL CreateServiceKeyword("(\.|^)api-cbc\.cloud\.clearleap\.com$", 159)//
CALL CreateServiceKeyword("(\.|^)cbc\.akamaized\.net$", 159)//
CALL CreateServiceKeyword("(\.|^)cbc\.ca$", 159)//
CALL CreateServiceKeyword("(\.|^)cbcca\.hb\.omtrdc\.net$", 159)//
CALL CreateServiceKeyword("(\.|^)cbcliveradio-lh\.akamaihd\.net$", 159)//
CALL CreateServiceKeyword("(\.|^)cbcmusic\.ca$", 159)//
CALL CreateServiceKeyword("(\.|^)cbcnews\.ca$", 159)//
CALL CreateServiceKeyword("(\.|^)cbcshop\.ca$", 159)//
CALL CreateServiceKeyword("(\.|^)cbcvott-a\.akamaihd\.net$", 159)//
CALL CreateServiceKeyword("(\.|^)community\.cbc\.pluck\.com$", 159)//
CALL CreateServiceKeyword("(\.|^)radio-canada\.ca$", 159)//
CALL CreateService("CBS")//
CALL CreateServiceKeyword("(\.|^)cbs\.com$", 160)//
CALL CreateServiceKeyword("(\.|^)cbsaavideo\.com$", 160)//
CALL CreateServiceKeyword("(\.|^)cbsaavideo\.map\.fastly\.net$", 160)//
CALL CreateServiceKeyword("(\.|^)cbsaccess\.map\.fastly\.net$", 160)//
CALL CreateServiceKeyword("(\.|^)cbsallaccess\.ca$", 160)//
CALL CreateServiceKeyword("(\.|^)cbsi\.com$", 160)//
CALL CreateServiceKeyword("(\.|^)cbsi\.demdex\.net$", 160)//
CALL CreateServiceKeyword("(\.|^)cbsi\.map\.fastly\.net$", 160)//
CALL CreateServiceKeyword("(\.|^)cbsimg\.net$", 160)//
CALL CreateServiceKeyword("(\.|^)cbsinteractive\.hb\.omtrdc\.net$", 160)//
CALL CreateServiceKeyword("(\.|^)cbsistatic\.com$", 160)//
CALL CreateServiceKeyword("(\.|^)cbsivideo\.com$", 160)//
CALL CreateServiceKeyword("(\.|^)cbsnews\.com\.ssl\.sc\.omtrdc\.net$", 160)//
CALL CreateServiceKeyword("(\.|^)cbssports\.com$", 160)//
CALL CreateServiceKeyword("(\.|^)vidtech-cbsinteractive\.map\.fastly\.net$", 160)//
CALL CreateService("CTV")//
CALL CreateServiceKeyword("(\.|^)ctv\.ca$", 161)//
CALL CreateServiceKeyword("(\.|^)ctvsales-pmd\.akamaized\.net$", 161)//
CALL CreateService("Cineplex")//
CALL CreateServiceKeyword("(\.|^)cineplex\.com$", 162)//
CALL CreateServiceKeyword("(\.|^)cineplex\.cpxstoreimages\.com$", 162)//
CALL CreateService("Comcast")//
CALL CreateServiceKeyword("(\.|^)comcast\.demdex\.net$", 163)//
CALL CreateServiceKeyword("(\.|^)corporate\.comcast\.com$", 163)//
CALL CreateService("Conde Nast")//
CALL CreateServiceKeyword("(\.|^)conde\.io$", 164)//
CALL CreateServiceKeyword("(\.|^)condenast\.com$", 164)//
CALL CreateServiceKeyword("(\.|^)condenast\.demdex\.net$", 164)//
CALL CreateServiceKeyword("(\.|^)condenast\.io$", 164)//
CALL CreateServiceKeyword("(\.|^)condenast\.map\.fastly\.net$", 164)//
CALL CreateServiceKeyword("(\.|^)condenastdigital\.com$", 164)//
CALL CreateService("Dailymotion")//
CALL CreateServiceKeyword("(\.|^)dailymotion\.com$", 165)//
CALL CreateServiceKeyword("(\.|^)dmcdn\.net$", 165)//
CALL CreateServiceKeyword("(\.|^)dmotion\.s\.llnwi\.net$", 165)//
CALL CreateServiceKeyword("(\.|^)dmxleo\.com$", 165)//
CALL CreateService("Diply")//
CALL CreateServiceKeyword("(\.|^)diply\.azure-api\.net$", 166)//
CALL CreateServiceKeyword("(\.|^)diply\.com$", 166)//
CALL CreateService("DirecTV")//
CALL CreateServiceKeyword("(\.|^)directv\.com$", 167)//
CALL CreateServiceKeyword("(\.|^)dtvbb\.tv$", 167)//
CALL CreateServiceKeyword("(\.|^)dtvce\.com$", 167)//
CALL CreateService("Disney")//
CALL CreateServiceKeyword("(\.|^)bamgrid\.com$", 168)//
CALL CreateServiceKeyword("(\.|^)bamtech\.sc\.omtrdc\.net$", 168)//
CALL CreateServiceKeyword("(\.|^)bamtech\.tt\.omtrdc\.net$", 168)//
CALL CreateServiceKeyword("(\.|^)bamtechmedia\.com$", 168)//
CALL CreateServiceKeyword("(\.|^)disney\.co\.uk$", 168)//
CALL CreateServiceKeyword("(\.|^)disney\.com$", 168)//
CALL CreateServiceKeyword("(\.|^)disney\.com\.c\.footprint\.net$", 168)//
CALL CreateServiceKeyword("(\.|^)disney\.com\.edgekey\.net$", 168)//
CALL CreateServiceKeyword("(\.|^)disney\.demdex\.net$", 168)//
CALL CreateServiceKeyword("(\.|^)disney\.io$", 168)//
CALL CreateServiceKeyword("(\.|^)disney\.tt\.omtrdc\.net$", 168)//
CALL CreateServiceKeyword("(\.|^)disneyjunior\.com$", 168)//
CALL CreateServiceKeyword("(\.|^)disneylandparis\.com$", 168)//
CALL CreateServiceKeyword("(\.|^)disneystore\.com$", 168)//
CALL CreateServiceKeyword("(\.|^)disneystreaming\.com$", 168)//
CALL CreateServiceKeyword("(\.|^)e11276\.dscg\.akamaiedge\.net$", 168)//
CALL CreateServiceKeyword("(\.|^)go\.com$", 168)//
CALL CreateServiceKeyword("(\.|^)marvel\.adobe\.com$", 168)//
CALL CreateServiceKeyword("(\.|^)registerdisney\.go\.com$", 168)//
CALL CreateServiceKeyword("(\.|^)registerdisney\.go\.com\.edgekey\.net$", 168)//
CALL CreateServiceKeyword("(\.|^)shopdisney\.fr$", 168)//
CALL CreateService("FANDOM")//
CALL CreateServiceKeyword("(\.|^)fandom\.com$", 169)//
CALL CreateServiceKeyword("(\.|^)wikia-services\.com$", 169)//
CALL CreateServiceKeyword("(\.|^)wikia\.com$", 169)//
CALL CreateService("FaceApp")//
CALL CreateServiceKeyword("(\.|^)faceapp\.com$", 170)//
CALL CreateServiceKeyword("(\.|^)faceapp\.io$", 170)//
CALL CreateService("Fox News")//
CALL CreateServiceKeyword("(\.|^)a57-foxnews-com\.cdn\.ampproject\.org$", 171)//
CALL CreateServiceKeyword("(\.|^)fncstatic\.com$", 171)//
CALL CreateServiceKeyword("(\.|^)foxbusiness\.com$", 171)//
CALL CreateServiceKeyword("(\.|^)foxnews\.com$", 171)//
CALL CreateServiceKeyword("(\.|^)foxnews\.com-v1\.edgekey\.net$", 171)//
CALL CreateServiceKeyword("(\.|^)foxnews\.com\.d1\.sc\.omtrdc\.net$", 171)//
CALL CreateServiceKeyword("(\.|^)foxnews\.com\.edgekey\.net$", 171)//
CALL CreateServiceKeyword("(\.|^)foxnews\.com\.ssl\.d1\.sc\.omtrdc\.net$", 171)//
CALL CreateServiceKeyword("(\.|^)foxnews\.demdex\.net$", 171)//
CALL CreateServiceKeyword("(\.|^)foxnews\.hb\.omtrdc\.net$", 171)//
CALL CreateServiceKeyword("(\.|^)foxnews\.tt\.omtrdc\.net$", 171)//
CALL CreateServiceKeyword("(\.|^)foxnewsplayer-a\.akamaihd\.net$", 171)//
CALL CreateServiceKeyword("(\.|^)foxnewsuni-f\.akamaihd\.net$", 171)//
CALL CreateServiceKeyword("(\.|^)static-foxnews-com\.cdn\.ampproject\.org$", 171)//
CALL CreateServiceKeyword("(\.|^)static-foxnews-com\.global\.ssl\.fastly\.net$", 171)//
CALL CreateServiceKeyword("(\.|^)www-foxnews-com\.cdn\.ampproject\.org$", 171)//
CALL CreateService("GIPHY")//
CALL CreateServiceKeyword("(\.|^)giphy\.com$", 172)//
CALL CreateServiceKeyword("(\.|^)giphy\.map\.fastly\.net$", 172)//
CALL CreateService("Gracenote")//
CALL CreateServiceKeyword("(\.|^)cddbp\.net$", 173)//
CALL CreateServiceKeyword("(\.|^)gracenote\.com$", 173)//
CALL CreateService("IMDb")//
CALL CreateServiceKeyword("(\.|^)imdb\.com$", 174)//
CALL CreateServiceKeyword("(\.|^)imdbws\.com$", 174)//
CALL CreateServiceKeyword("(\.|^)media-imdb\.com$", 174)//
CALL CreateServiceKeyword("(\.|^)www-imdb-com\.amazon\.map\.fastly\.net$", 174)//
CALL CreateService("Imgur")//
CALL CreateServiceKeyword("(\.|^)imgur\.com$", 175)//
CALL CreateServiceKeyword("(\.|^)imgur\.map\.fastly\.net$", 175)//
CALL CreateServiceKeyword("(\.|^)www\.imgur\.com$", 175)//
CALL CreateService("KuGou")//
CALL CreateServiceKeyword("(\.|^)kugou\.com$", 176)//
CALL CreateService("NBCUniversal")//
CALL CreateServiceKeyword("(\.|^)nbcuni\.com$", 177)//
CALL CreateServiceKeyword("(\.|^)nbcuni\.demdex\.net$", 177)//
CALL CreateServiceKeyword("(\.|^)nbcuniversal\.com$", 177)//
CALL CreateService("NPR")//
CALL CreateServiceKeyword("(\.|^)npr\.org$", 178)//
CALL CreateServiceKeyword("(\.|^)npr\.org\.edgekey\.net$", 178)//
CALL CreateService("QuickPlay")//
CALL CreateServiceKeyword("(\.|^)quickplay\.com$", 179)//
CALL CreateService("Rhino Entertainment")//
CALL CreateServiceKeyword("(\.|^)rhino\.com$", 180)//
CALL CreateService("SiriusXM")//
CALL CreateServiceKeyword("(\.|^)siriusxm-priprodart\.akamaized\.net$", 181)//
CALL CreateServiceKeyword("(\.|^)siriusxm-priprodlive\.akamaized\.net$", 181)//
CALL CreateServiceKeyword("(\.|^)siriusxm\.ca$", 181)//
CALL CreateServiceKeyword("(\.|^)siriusxm\.com$", 181)//
CALL CreateServiceKeyword("(\.|^)siriusxm\.com\.akamaized\.net$", 181)//
CALL CreateServiceKeyword("(\.|^)siriusxm\.com\.edgesuite\.net$", 181)//
CALL CreateServiceKeyword("(\.|^)siriusxmradioinc\.demdex\.net$", 181)//
CALL CreateService("TMZ")//
CALL CreateServiceKeyword("(\.|^)tmz\.com$", 182)//
CALL CreateService("The Movie Database")//
CALL CreateServiceKeyword("(\.|^)themoviedb\.org$", 183)//
CALL CreateServiceKeyword("(\.|^)tmdb\.org$", 183)//
CALL CreateService("The New Yorker")//
CALL CreateServiceKeyword("(\.|^)newyorker\.com$", 184)//
CALL CreateService("TheTVDB")//
CALL CreateServiceKeyword("(\.|^)thetvdb\.com$", 185)//
CALL CreateService("Tumblr")//
CALL CreateServiceKeyword("(\.|^)tumblr\.com$", 186)//
CALL CreateService("Turner")//
CALL CreateServiceKeyword("(\.|^)e12596\.dscj\.akamaiedge\.net$", 187)//
CALL CreateServiceKeyword("(\.|^)turner-tls\.map\.fastly\.net$", 187)//
CALL CreateServiceKeyword("(\.|^)turner\.com$", 187)//
CALL CreateServiceKeyword("(\.|^)turner2\.demdex\.net$", 187)//
CALL CreateServiceKeyword("(\.|^)ugdturner\.com$", 187)//
CALL CreateService("WarnerMedia")//
CALL CreateServiceKeyword("(\.|^)timerwarner\.com$", 188)//
CALL CreateServiceKeyword("(\.|^)warnermedia\.com$", 188)//
CALL CreateServiceKeyword("(\.|^)warnermediacdn\.com$", 188)//
CALL CreateServiceKeyword("(\.|^)wmcdp\.io$", 188)//
CALL CreateService("zombo.com")//
CALL CreateServiceKeyword("(\.|^)zombo\.com$", 189)//
CALL CreateService("101domains")//
CALL CreateServiceKeyword("(\.|^)101domain\.com$", 190)//
CALL CreateService("1Password")//
CALL CreateServiceKeyword("(\.|^)1password\.ca$", 191)//
CALL CreateServiceKeyword("(\.|^)1password\.com$", 191)//
CALL CreateServiceKeyword("(\.|^)1password\.eu$", 191)//
CALL CreateServiceKeyword("(\.|^)1passwordservices\.com$", 191)//
CALL CreateServiceKeyword("(\.|^)1passwordusercontent\.ca$", 191)//
CALL CreateServiceKeyword("(\.|^)1passwordusercontent\.com$", 191)//
CALL CreateServiceKeyword("(\.|^)1passwordusercontent\.eu$", 191)//
CALL CreateService("AMP Project")//
CALL CreateServiceKeyword("(\.|^)ampproject\.net$", 192)//
CALL CreateServiceKeyword("(\.|^)ampproject\.org$", 192)//
CALL CreateService("AT-T Monitoring")//
CALL CreateServiceKeyword("(\.|^)ciq\.labs\.att\.com$", 193)//
CALL CreateService("AT-and-T")//
CALL CreateServiceKeyword("(\.|^)att-idns\.net$", 194)//
CALL CreateServiceKeyword("(\.|^)att\.com$", 194)//
CALL CreateServiceKeyword("(\.|^)att\.demdex\.net$", 194)//
CALL CreateServiceKeyword("(\.|^)att\.net$", 194)//
CALL CreateService("Adobe Sign")//
CALL CreateServiceKeyword("(\.|^)adobesign\.com$", 195)//
CALL CreateServiceKeyword("(\.|^)adobesigncdn\.com$", 195)//
CALL CreateServiceKeyword("(\.|^)documents\.adobe\.com$", 195)//
CALL CreateServiceKeyword("(\.|^)echocdn\.com$", 195)//
CALL CreateServiceKeyword("(\.|^)echosign\.com$", 195)//
CALL CreateService("Amazon")//
CALL CreateServiceKeyword("(\.|^)a2z\.com$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon-corp\.com$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.ca$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.cn$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.co\.jp$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.co\.uk$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.com$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.com\.au$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.com\.edgekey\.net$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.com\.mx$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.de$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.es$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.eu$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.fr$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.in$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.it$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.map\.fastly\.net$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.nl$", 196)//
CALL CreateServiceKeyword("(\.|^)amazon\.sa$", 196)//
CALL CreateServiceKeyword("(\.|^)amazonbrowserapp\.co\.uk$", 196)//
CALL CreateServiceKeyword("(\.|^)amazonbrowserapp\.es$", 196)//
CALL CreateServiceKeyword("(\.|^)amazoncognito\.com$", 196)//
CALL CreateServiceKeyword("(\.|^)amazoncrl\.com$", 196)//
CALL CreateServiceKeyword("(\.|^)amazonpay\.com$", 196)//
CALL CreateServiceKeyword("(\.|^)amazonpay\.in$", 196)//
CALL CreateServiceKeyword("(\.|^)amazontrust\.com$", 196)//
CALL CreateServiceKeyword("(\.|^)associates-amazon\.com$", 196)//
CALL CreateServiceKeyword("(\.|^)images-amazon\.com$", 196)//
CALL CreateServiceKeyword("(\.|^)media-amazon\.com$", 196)//
CALL CreateServiceKeyword("(\.|^)ssl-images-amazon\.com$", 196)//
CALL CreateServiceKeyword("(\.|^)www-amazon-co-uk\.customer\.fastly\.net$", 196)//
CALL CreateServiceKeyword("(\.|^)www-amazon-com\.customer\.fastly\.net$", 196)//
CALL CreateService("Amazon Alexa")//
CALL CreateServiceKeyword("(\.|^)alexa\.amazon\.ca$", 197)//
CALL CreateServiceKeyword("(\.|^)alexa\.amazon\.co\.jp$", 197)//
CALL CreateServiceKeyword("(\.|^)alexa\.amazon\.co\.uk$", 197)//
CALL CreateServiceKeyword("(\.|^)alexa\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)alexa\.amazon\.it$", 197)//
CALL CreateServiceKeyword("(\.|^)alexa\.na\.gateway\.devices\.a2z\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)amazonalexa\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-1-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-10-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-10-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-11-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-11-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-12-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-12-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-13-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-13-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-14-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-14-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-15-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-15-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-16-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-16-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-17-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-17-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-18-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-18-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-19-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-19-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-2-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-2-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-20-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-20-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-3-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-3-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-4-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-4-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-5-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-5-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-6-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-6-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-7-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-7-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-8-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-8-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-9-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)avs-alexa-9-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)bob-dispatch-prod-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)bob-dispatch-prod-na\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)latinum-eu\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)layla\.amazon\.com$", 197)//
CALL CreateServiceKeyword("(\.|^)layla\.amazon\.de$", 197)//
CALL CreateServiceKeyword("(\.|^)pitangui\.amazon\.com$", 197)//
CALL CreateService("Amazon Silk")//
CALL CreateServiceKeyword("(\.|^)amazonsilk\.com$", 198)//
CALL CreateService("AnyDesk")//
CALL CreateServiceKeyword("(\.|^)anydesk\.com$", 199)//
CALL CreateService("AppDynamics")//
CALL CreateServiceKeyword("(\.|^)appdynamics\.com$", 200)//
CALL CreateServiceKeyword("(\.|^)eum-appdynamics\.com$", 200)//
CALL CreateService("Apple")//
CALL CreateServiceKeyword("(\.|^)aaplimg\.com$", 201)//
CALL CreateServiceKeyword("(\.|^)apple$", 201)//
CALL CreateServiceKeyword("(\.|^)apple-dns\.cn$", 201)//
CALL CreateServiceKeyword("(\.|^)apple-dns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)apple-support\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)apple\.com$", 201)//
CALL CreateServiceKeyword("(\.|^)apple\.com-v1\.edgesuite\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)apple\.com\.akamaized\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)apple\.com\.cn$", 201)//
CALL CreateServiceKeyword("(\.|^)apple\.com\.edgekey\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)apple\.com\.edgekey\.net\.globalredir\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)apple\.com\.edgesuite\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)apple\.news$", 201)//
CALL CreateServiceKeyword("(\.|^)apple\.tt\.omtrdc\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)blobstore-apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)cdn-apple\.com$", 201)//
CALL CreateServiceKeyword("(\.|^)cdn-apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)cdn-apple\.com\.edgekey\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)e10499\.dsce9\.akamaiedge\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)e1329\.g\.akamaiedge\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)e17437\.dscb\.akamaiedge\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)e6858\.dscx\.akamaiedge\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)ess-apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)gc-apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)gcsis-apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)guzzoni-apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)iad-apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)idms-apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)isg-apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)ls-apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)ls2-apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)ls4-apple\.com\.akadns\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)mzstatic\.com$", 201)//
CALL CreateServiceKeyword("(\.|^)mzstatic\.com\.edgekey\.net$", 201)//
CALL CreateServiceKeyword("(\.|^)origin-apple\.com\.akadns\.net$", 201)//
CALL CreateService("Apple ID")//
CALL CreateServiceKeyword("(\.|^)appleid\.apple\.com$", 202)//
CALL CreateServiceKeyword("(\.|^)iforget\.apple\.com$", 202)//
CALL CreateService("Apple Siri")//
CALL CreateServiceKeyword("(\.|^)dejavu\.apple\.com$", 203)//
CALL CreateServiceKeyword("(\.|^)guzzoni-apple-com\.v\.aaplimg\.com$", 203)//
CALL CreateServiceKeyword("(\.|^)guzzoni\.apple\.com$", 203)//
CALL CreateServiceKeyword("(\.|^)siri\.apple\.com$", 203)//
CALL CreateServiceKeyword("(\.|^)swallow\.apple\.com$", 203)//
CALL CreateService("Are You a Human")//
CALL CreateServiceKeyword("(\.|^)areyouahuman\.com$", 204)//
CALL CreateService("Autodesk")//
CALL CreateServiceKeyword("(\.|^)autodesk\.com$", 205)//
CALL CreateServiceKeyword("(\.|^)autodesk\.com\.cdn\.cloudflare\.net$", 205)//
CALL CreateServiceKeyword("(\.|^)autodesk\.demdex\.net$", 205)//
CALL CreateServiceKeyword("(\.|^)autodesk\.tt\.omtrdc\.net$", 205)//
CALL CreateService("Axacore")//
CALL CreateServiceKeyword("(\.|^)axacore\.com$", 206)//
CALL CreateServiceKeyword("(\.|^)faxagent\.com$", 206)//
CALL CreateService("Bell Canada")//
CALL CreateServiceKeyword("(\.|^)bell\.ca$", 207)//
CALL CreateServiceKeyword("(\.|^)bell\.ca\.akadns\.net$", 207)//
CALL CreateService("Brave Browser")//
CALL CreateServiceKeyword("(\.|^)brave\.com$", 208)//
CALL CreateServiceKeyword("(\.|^)bravesoftware\.com$", 208)//
CALL CreateService("Broadcom GPS")//
CALL CreateServiceKeyword("(\.|^)glpals\.com$", 209)//
CALL CreateService("Bugsnag")//
CALL CreateServiceKeyword("(\.|^)bugsnag\.com$", 210)//
CALL CreateService("CHOC")//
CALL CreateServiceKeyword("(\.|^)childrenshospitalofo\.content\.snapcomms\.com$", 211)//
CALL CreateServiceKeyword("(\.|^)choc\.org$", 211)//
CALL CreateServiceKeyword("(\.|^)choccactx\.cernerworkswan\.com$", 211)//
CALL CreateService("Carbonite")//
CALL CreateServiceKeyword("(\.|^)carbonite\.com$", 212)//
CALL CreateService("Cheetah Mobile")//
CALL CreateServiceKeyword("(\.|^)cmcm\.com$", 213)//
CALL CreateServiceKeyword("(\.|^)ksmobile\.com$", 213)//
CALL CreateService("Chunghwa Telecom")//
CALL CreateServiceKeyword("(\.|^)cht\.com\.tw$", 214)//
CALL CreateService("Citrix")//
CALL CreateServiceKeyword("(\.|^)cedexis-ssl\.cdn\.warpcache\.net$", 215)//
CALL CreateServiceKeyword("(\.|^)cedexis-test\.com$", 215)//
CALL CreateServiceKeyword("(\.|^)cedexis\.com$", 215)//
CALL CreateServiceKeyword("(\.|^)cedexis\.netdna-cdn\.com$", 215)//
CALL CreateServiceKeyword("(\.|^)cedexis\.pc\.cdn\.bitgravity\.com$", 215)//
CALL CreateServiceKeyword("(\.|^)citrix\.com$", 215)//
CALL CreateServiceKeyword("(\.|^)citrixnetworkapi\.net$", 215)//
CALL CreateServiceKeyword("(\.|^)img-cedexis\.mncdn\.com$", 215)//
CALL CreateService("ClearCenter")//
CALL CreateServiceKeyword("(\.|^)clearcenter\.com$", 216)//
CALL CreateServiceKeyword("(\.|^)clearshare\.staging\.storewise\.tech$", 216)//
CALL CreateServiceKeyword("(\.|^)clearunited\.com$", 216)//
CALL CreateServiceKeyword("(\.|^)clearvm\.com$", 216)//
CALL CreateServiceKeyword("(\.|^)contentfilter\.net$", 216)//
CALL CreateServiceKeyword("(\.|^)mytools\.management$", 216)//
CALL CreateServiceKeyword("(\.|^)thinkclearly\.news$", 216)//
CALL CreateServiceKeyword("(\.|^)witsbits\.com$", 216)//
CALL CreateService("ClearCenter DNS")//
CALL CreateServiceKeyword("(\.|^)poweredbyclear\.com$", 217)//
CALL CreateService("ClearFoundation")//
CALL CreateServiceKeyword("(\.|^)clearfoundation\.co\.nz$", 218)//
CALL CreateServiceKeyword("(\.|^)clearfoundation\.com$", 218)//
CALL CreateService("Clover")//
CALL CreateServiceKeyword("(\.|^)clover\.com$", 219)//
CALL CreateService("ConnectWise")//
CALL CreateServiceKeyword("(\.|^)connectwise\.com$", 220)//
CALL CreateServiceKeyword("(\.|^)continuum\.net$", 220)//
CALL CreateServiceKeyword("(\.|^)itsupport247\.net$", 220)//
CALL CreateService("CookieLaw")//
CALL CreateServiceKeyword("(\.|^)cookielaw\.org$", 221)//
CALL CreateService("Corel")//
CALL CreateServiceKeyword("(\.|^)corel\.com$", 222)//
CALL CreateService("Crashlytics")//
CALL CreateServiceKeyword("(\.|^)crashlytics\.com$", 223)//
CALL CreateService("D-Link")//
CALL CreateServiceKeyword("(\.|^)dlink\.com$", 224)//
CALL CreateService("Datadog")//
CALL CreateServiceKeyword("(\.|^)alb-logs-http-browser-shard0-714281947\.us-east-1\.elb\.amazonaws\.com$", 225)//
CALL CreateServiceKeyword("(\.|^)datadog\.com$", 225)//
CALL CreateServiceKeyword("(\.|^)datadoghq\.com$", 225)//
CALL CreateService("Datto")//
CALL CreateServiceKeyword("(\.|^)backupify\.com$", 226)//
CALL CreateServiceKeyword("(\.|^)centrastage\.net$", 226)//
CALL CreateServiceKeyword("(\.|^)datto\.com$", 226)//
CALL CreateServiceKeyword("(\.|^)dattobackup\.com$", 226)//
CALL CreateServiceKeyword("(\.|^)dattolocal\.net$", 226)//
CALL CreateServiceKeyword("(\.|^)dattoweb\.com$", 226)//
CALL CreateService("DocuSign")//
CALL CreateServiceKeyword("(\.|^)docusign-alb-1457800058\.us-east-1\.elb\.amazonaws\.com$", 227)//
CALL CreateServiceKeyword("(\.|^)docusign\.ca$", 227)//
CALL CreateServiceKeyword("(\.|^)docusign\.com$", 227)//
CALL CreateServiceKeyword("(\.|^)docusign\.com-2\.edgekey\.net$", 227)//
CALL CreateServiceKeyword("(\.|^)docusign\.com\.akadns\.net$", 227)//
CALL CreateServiceKeyword("(\.|^)docusign\.com\.edgekey\.net$", 227)//
CALL CreateServiceKeyword("(\.|^)docusign\.net$", 227)//
CALL CreateServiceKeyword("(\.|^)docusign\.net\.akadns\.net$", 227)//
CALL CreateService("Domotz")//
CALL CreateServiceKeyword("(\.|^)domotz\.com$", 228)//
CALL CreateService("DoorDash")//
CALL CreateServiceKeyword("(\.|^)api-doordash\.sendbird\.com$", 229)//
CALL CreateServiceKeyword("(\.|^)doordash-static\.s3-us-west-2\.amazonaws\.com$", 229)//
CALL CreateServiceKeyword("(\.|^)doordash-static\.s3\.amazonaws\.com$", 229)//
CALL CreateServiceKeyword("(\.|^)doordash\.com$", 229)//
CALL CreateServiceKeyword("(\.|^)doordash\.sparkpostmail\.com$", 229)//
CALL CreateServiceKeyword("(\.|^)ws-doordash\.sendbird\.com$", 229)//
CALL CreateService("Fedex")//
CALL CreateServiceKeyword("(\.|^)fedex\.com$", 230)//
CALL CreateServiceKeyword("(\.|^)fedex\.com\.akadns\.net$", 230)//
CALL CreateServiceKeyword("(\.|^)fedex\.com\.edgekey\.net$", 230)//
CALL CreateServiceKeyword("(\.|^)fedex\.demdex\.net$", 230)//
CALL CreateServiceKeyword("(\.|^)fedex\.tt\.omtrdc\.net$", 230)//
CALL CreateService("Fing")//
CALL CreateServiceKeyword("(\.|^)fing\.com$", 231)//
CALL CreateServiceKeyword("(\.|^)fing\.io$", 231)//
CALL CreateService("Firefox")//
CALL CreateServiceKeyword("(\.|^)firefox\.com$", 232)//
CALL CreateServiceKeyword("(\.|^)firefox\.com-v2\.edgesuite\.net$", 232)//
CALL CreateServiceKeyword("(\.|^)firefoxusercontent\.com$", 232)//
CALL CreateServiceKeyword("(\.|^)mozaws\.net$", 232)//
CALL CreateServiceKeyword("(\.|^)mozgcp\.net$", 232)//
CALL CreateServiceKeyword("(\.|^)mozilla\.com$", 232)//
CALL CreateServiceKeyword("(\.|^)mozilla\.net$", 232)//
CALL CreateServiceKeyword("(\.|^)mozilla\.net\.edgekey\.net$", 232)//
CALL CreateServiceKeyword("(\.|^)mozilla\.org$", 232)//
CALL CreateServiceKeyword("(\.|^)mozilla\.org\.cdn\.cloudflare\.net$", 232)//
CALL CreateServiceKeyword("(\.|^)pipeline-incoming-prod-elb-149169523\.us-west-2\.elb\.amazonaws\.com$", 232)//
CALL CreateService("Foxit")//
CALL CreateServiceKeyword("(\.|^)connectedpdf\.com$", 233)//
CALL CreateServiceKeyword("(\.|^)foxitcloud\.com$", 233)//
CALL CreateServiceKeyword("(\.|^)foxitreader\.cn$", 233)//
CALL CreateServiceKeyword("(\.|^)foxitservice\.com$", 233)//
CALL CreateServiceKeyword("(\.|^)foxitsoftware\.com$", 233)//
CALL CreateServiceKeyword("(\.|^)foxitsoftware\.com\.cdn\.cloudflare\.net$", 233)//
CALL CreateService("Freshdesk")//
CALL CreateServiceKeyword("(\.|^)freshdesk\.com$", 234)//
CALL CreateService("Freshworks")//
CALL CreateServiceKeyword("(\.|^)freshconnect\.io$", 235)//
CALL CreateServiceKeyword("(\.|^)freshworks\.com$", 235)//
CALL CreateServiceKeyword("(\.|^)freshworksapi\.com$", 235)//
CALL CreateService("Gartner")//
CALL CreateServiceKeyword("(\.|^)cebglobal\.com$", 236)//
CALL CreateServiceKeyword("(\.|^)gartner\.com$", 236)//
CALL CreateService("Giraffic")//
CALL CreateServiceKeyword("(\.|^)giraffic\.com$", 237)//
CALL CreateService("GoDaddy")//
CALL CreateServiceKeyword("(\.|^)godaddy\.com$", 238)//
CALL CreateServiceKeyword("(\.|^)godaddy\.com\.akadns\.net$", 238)//
CALL CreateService("GoGo")//
CALL CreateServiceKeyword("(\.|^)gogoair\.com$", 239)//
CALL CreateServiceKeyword("(\.|^)s25227\.pcdn\.co$", 239)//
CALL CreateService("GoTo")//
CALL CreateServiceKeyword("(\.|^)getgo\.com$", 240)//
CALL CreateServiceKeyword("(\.|^)getgocdn\.com$", 240)//
CALL CreateServiceKeyword("(\.|^)goto-rtc\.com$", 240)//
CALL CreateServiceKeyword("(\.|^)goto\.com$", 240)//
CALL CreateServiceKeyword("(\.|^)gotoconference\.com$", 240)//
CALL CreateServiceKeyword("(\.|^)gotomeeting\.com$", 240)//
CALL CreateServiceKeyword("(\.|^)gotomeeting\.com\.akadns\.net$", 240)//
CALL CreateServiceKeyword("(\.|^)gotomeeting\.com\.edgekey\.net$", 240)//
CALL CreateServiceKeyword("(\.|^)gototraining\.com$", 240)//
CALL CreateServiceKeyword("(\.|^)gotowebinar\.com$", 240)//
CALL CreateService("Google")//
CALL CreateServiceKeyword("(\.|^)1e100\.net$", 241)//
CALL CreateServiceKeyword("(\.|^)channel\.status\.request\.url$", 241)//
CALL CreateServiceKeyword("(\.|^)fonts-gstatic-com\.cdn\.ampproject\.org$", 241)//
CALL CreateServiceKeyword("(\.|^)g\.co$", 241)//
CALL CreateServiceKeyword("(\.|^)ggpht\.com$", 241)//
CALL CreateServiceKeyword("(\.|^)goo\.gl$", 241)//
CALL CreateServiceKeyword("(\.|^)goog$", 241)//
CALL CreateServiceKeyword("(\.|^)google$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ad$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ae$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.al$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.am$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.as$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.at$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.az$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ba$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.be$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.bf$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.bg$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.bi$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.bj$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.bs$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.bt$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.by$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ca$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.cat$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.cd$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.cf$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.cg$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ch$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ci$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.cl$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.cm$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.cn$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.ao$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.bw$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.ck$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.cr$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.id$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.il$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.in$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.jp$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.ke$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.kr$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.ls$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.ma$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.mz$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.nz$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.th$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.tz$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.ug$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.uk$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.uz$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.ve$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.vi$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.za$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.zm$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.co\.zw$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.af$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.ag$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.ai$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.ar$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.au$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.bd$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.bh$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.bn$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.bo$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.br$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.bz$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.co$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.cu$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.cy$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.do$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.ec$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.eg$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.et$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.fj$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.gh$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.gi$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.gt$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.hk$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.jm$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.kh$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.kw$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.lb$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.ly$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.mm$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.mt$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.mx$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.my$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.na$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.ng$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.ni$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.np$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.om$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.pa$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.pe$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.pg$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.ph$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.pk$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.pr$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.py$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.qa$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.sa$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.sb$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.sg$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.sl$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.sv$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.tj$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.tr$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.tw$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.ua$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.uy$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.vc$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.com\.vn$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.cv$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.cz$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.de$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.dj$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.dk$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.dm$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.dz$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ee$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.es$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.fi$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.fm$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.fr$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ga$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ge$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.gg$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.gl$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.gm$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.gr$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.gy$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.hn$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.hr$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ht$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.hu$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ie$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.im$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.in$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.iq$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.is$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.it$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.je$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.jo$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.kg$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ki$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.kz$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.la$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.li$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.lk$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.lt$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.lu$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.lv$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.md$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.me$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.mg$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.mk$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ml$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.mn$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ms$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.mu$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.mv$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.mw$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ne$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.net$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.nl$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.no$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.nr$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.nu$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.org$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.pl$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.pn$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ps$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.pt$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ro$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.rs$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ru$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.rw$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.sc$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.se$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.sh$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.si$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.sk$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.sm$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.sn$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.so$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.sr$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.st$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.td$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.tg$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.tk$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.tl$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.tm$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.tn$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.to$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.tt$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.vg$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.vu$", 241)//
CALL CreateServiceKeyword("(\.|^)google\.ws$", 241)//
CALL CreateServiceKeyword("(\.|^)googleapis\.cn$", 241)//
CALL CreateServiceKeyword("(\.|^)googleapis\.com$", 241)//
CALL CreateServiceKeyword("(\.|^)googlecode\.com$", 241)//
CALL CreateServiceKeyword("(\.|^)googlehosted\.com$", 241)//
CALL CreateServiceKeyword("(\.|^)googleoptimize\.com$", 241)//
CALL CreateServiceKeyword("(\.|^)googleusercontent\.com$", 241)//
CALL CreateServiceKeyword("(\.|^)googleweblight\.in$", 241)//
CALL CreateServiceKeyword("(\.|^)googlezip\.net$", 241)//
CALL CreateServiceKeyword("(\.|^)gstatic\.com$", 241)//
CALL CreateServiceKeyword("(\.|^)gvt2\.com$", 241)//
CALL CreateServiceKeyword("(\.|^)gvt3\.com$", 241)//
CALL CreateServiceKeyword("(\.|^)news\.google\.com$", 241)//
CALL CreateServiceKeyword("(\.|^)withgoogle\.com$", 241)//
CALL CreateService("Google Auth")//
CALL CreateServiceKeyword("(\.|^)accounts\.google\.com$", 242)//
CALL CreateServiceKeyword("(\.|^)myaccount\.google\.com$", 242)//
CALL CreateServiceKeyword("(\.|^)oauth2\.googleapis\.com$", 242)//
CALL CreateService("Google Domains")//
CALL CreateServiceKeyword("(\.|^)domains\.google$", 243)//
CALL CreateServiceKeyword("(\.|^)googledomains\.com$", 243)//
CALL CreateServiceKeyword("(\.|^)nic\.google$", 243)//
CALL CreateServiceKeyword("(\.|^)registry\.google$", 243)//
CALL CreateService("Google Firebase")//
CALL CreateServiceKeyword("(\.|^)fcm\.googleapis\.com$", 244)//
CALL CreateServiceKeyword("(\.|^)firebase\.google\.com$", 244)//
CALL CreateServiceKeyword("(\.|^)firebaseapp\.com$", 244)//
CALL CreateServiceKeyword("(\.|^)firebaseinstallations\.googleapis\.com$", 244)//
CALL CreateServiceKeyword("(\.|^)firebaseio\.com$", 244)//
CALL CreateService("Google Workspace")//
CALL CreateServiceKeyword("(\.|^)calendar\.google\.com$", 245)//
CALL CreateServiceKeyword("(\.|^)contacts\.google\.com$", 245)//
CALL CreateServiceKeyword("(\.|^)currents\.google\.com$", 245)//
CALL CreateServiceKeyword("(\.|^)docs\.google\.com$", 245)//
CALL CreateServiceKeyword("(\.|^)drive\.google\.com$", 245)//
CALL CreateServiceKeyword("(\.|^)forms\.google\.com$", 245)//
CALL CreateServiceKeyword("(\.|^)gsuite\.google\.com$", 245)//
CALL CreateServiceKeyword("(\.|^)jamboard\.google\.com$", 245)//
CALL CreateServiceKeyword("(\.|^)keep\.google\.com$", 245)//
CALL CreateServiceKeyword("(\.|^)plus\.google\.com$", 245)//
CALL CreateServiceKeyword("(\.|^)sheets\.google\.com$", 245)//
CALL CreateServiceKeyword("(\.|^)slides\.google\.com$", 245)//
CALL CreateServiceKeyword("(\.|^)spreadsheets\.google\.com$", 245)//
CALL CreateService("Got Junk")//
CALL CreateServiceKeyword("(\.|^)1800gotjunk\.com$", 246)//
CALL CreateService("Grafana Labs")//
CALL CreateServiceKeyword("(\.|^)grafana\.com$", 247)//
CALL CreateService("Helpshift")//
CALL CreateServiceKeyword("(\.|^)helpshift\.com$", 248)//
CALL CreateService("HomeSeer")//
CALL CreateServiceKeyword("(\.|^)homeseer\.com$", 249)//
CALL CreateService("HughesNet")//
CALL CreateServiceKeyword("(\.|^)hughesnet\.com$", 250)//
CALL CreateService("IBM")//
CALL CreateServiceKeyword("(\.|^)ibm\.com$", 251)//
CALL CreateServiceKeyword("(\.|^)ibmmarketingcloud\.com$", 251)//
CALL CreateServiceKeyword("(\.|^)silverpop\.com$", 251)//
CALL CreateService("ITarian")//
CALL CreateServiceKeyword("(\.|^)cmdm\.comodo\.com$", 252)//
CALL CreateServiceKeyword("(\.|^)comodormm\.com$", 252)//
CALL CreateServiceKeyword("(\.|^)itarian\.com$", 252)//
CALL CreateService("Infura")//
CALL CreateServiceKeyword("(\.|^)infura\.io$", 253)//
CALL CreateService("Inmarsat")//
CALL CreateServiceKeyword("(\.|^)inmarsat\.com$", 254)//
CALL CreateService("Intel")//
CALL CreateServiceKeyword("(\.|^)intel\.ca$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.cn$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.co\.id$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.co\.il$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.co\.jp$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.co\.kr$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.co\.uk$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.com$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.com\.au$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.com\.br$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.com\.tr$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.com\.tw$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.de$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.es$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.eu$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.fr$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.ie$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.in$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.it$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.la$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.me$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.ph$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.pl$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.ru$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.se$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.sg$", 255)//
CALL CreateServiceKeyword("(\.|^)intel\.vn$", 255)//
CALL CreateServiceKeyword("(\.|^)intelcorp\.demdex\.net$", 255)//
CALL CreateService("Intsig")//
CALL CreateServiceKeyword("(\.|^)camcard\.com$", 256)//
CALL CreateServiceKeyword("(\.|^)camscanner\.com$", 256)//
CALL CreateServiceKeyword("(\.|^)intsig\.com$", 256)//
CALL CreateServiceKeyword("(\.|^)intsig\.net$", 256)//
CALL CreateService("JumpCloud")//
CALL CreateServiceKeyword("(\.|^)jumpcloud\.com$", 257)//
CALL CreateService("K4 Mobility")//
CALL CreateServiceKeyword("(\.|^)k4mobility\.com$", 258)//
CALL CreateService("KeyCDN")//
CALL CreateServiceKeyword("(\.|^)keycdn\.com$", 259)//
CALL CreateServiceKeyword("(\.|^)kxcdn\.com$", 259)//
CALL CreateService("LANSolutions")//
CALL CreateServiceKeyword("(\.|^)lansolutions\.net$", 260)//
CALL CreateService("LG Uplus")//
CALL CreateServiceKeyword("(\.|^)lgdacom\.net$", 261)//
CALL CreateServiceKeyword("(\.|^)uplus\.co\.kr$", 261)//
CALL CreateService("LastPass")//
CALL CreateServiceKeyword("(\.|^)lastpass\.com$", 262)//
CALL CreateService("LaunchDarkly")//
CALL CreateServiceKeyword("(\.|^)launchdarkly\.com$", 263)//
CALL CreateService("Life360")//
CALL CreateServiceKeyword("(\.|^)amplitude-life360-com-207526384\.us-east-1\.elb\.amazonaws\.com$", 264)//
CALL CreateServiceKeyword("(\.|^)familysafetyproduction\.com$", 264)//
CALL CreateServiceKeyword("(\.|^)life360\.com$", 264)//
CALL CreateServiceKeyword("(\.|^)life360\.helpshift\.com$", 264)//
CALL CreateServiceKeyword("(\.|^)life360\.pubnub\.com$", 264)//
CALL CreateService("LivePerson")//
CALL CreateServiceKeyword("(\.|^)liveperson\.com$", 265)//
CALL CreateServiceKeyword("(\.|^)liveperson\.map\.fastly\.net$", 265)//
CALL CreateServiceKeyword("(\.|^)liveperson\.net$", 265)//
CALL CreateServiceKeyword("(\.|^)livepersonk\.akadns\.net$", 265)//
CALL CreateServiceKeyword("(\.|^)lpsnmedia\.net$", 265)//
CALL CreateServiceKeyword("(\.|^)lptag-cdn-liveperson-net\.map\.fastly\.net$", 265)//
CALL CreateService("LogicMonitor")//
CALL CreateServiceKeyword("(\.|^)logicmonitor\.com$", 266)//
CALL CreateService("MACVendors")//
CALL CreateServiceKeyword("(\.|^)macvendors\.com$", 267)//
CALL CreateService("MakerBot")//
CALL CreateServiceKeyword("(\.|^)makerbot\.com$", 268)//
CALL CreateServiceKeyword("(\.|^)makerbot\.map\.fastly\.net$", 268)//
CALL CreateService("ManageEngine")//
CALL CreateServiceKeyword("(\.|^)manageengine\.com$", 269)//
CALL CreateService("MarkMonitor")//
CALL CreateServiceKeyword("(\.|^)markmonitor\.com$", 270)//
CALL CreateService("Microsoft")//
CALL CreateServiceKeyword("(\.|^)a-msedge\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)aka\.ms$", 271)//
CALL CreateServiceKeyword("(\.|^)appcenter\.ms$", 271)//
CALL CreateServiceKeyword("(\.|^)aspnetcdn\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)au-msedge\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)auth\.gfx\.ms$", 271)//
CALL CreateServiceKeyword("(\.|^)b-msedge\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)c-msedge\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)com-c-3\.edgekey\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)dc-msedge\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)dynamics\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)e-msedge\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)exp-tas\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)gfx\.ms$", 271)//
CALL CreateServiceKeyword("(\.|^)hwcdn\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)img-prod-cms-rt-microsoft-com\.akamaized\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)k-msedge\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)l-msedge\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)live\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)live\.com\.akadns\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)live\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.akadns\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.az$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.be$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.by$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.ca$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.cat$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.ch$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.cl$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.com-c-3\.edgekey\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.com-c\.edgesuite\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.com\.akadns\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.com\.aria\.akadns\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.com\.edgekey\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.com\.edgesuite\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.com\.nsatc\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.cz$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.de$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.dk$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.ee$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.es$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.eu$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.fi$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.ge$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.hu$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.io$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.is$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.it$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.jp$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.lt$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.lu$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.lv$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.md$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.pl$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.pt$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.red$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.ro$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.rs$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.ru$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.se$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.si$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.tv$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.ua$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.us$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.uz$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoft\.vn$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoftmscompoc\.tt\.omtrdc\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoftonline\.us$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoftrewards\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)microsoftstoreemail\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)microsofttranslator\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)ms\.akadns\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)msa\.akadns6\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)msecnd\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)msedge\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)msft\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)msftconnecttest\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)msftncsi\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)msftncsi\.com\.edgesuite\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)mshome\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)nsatc\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)onecollector\.akadns\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)onecollector\.cloudapp\.aria\.akadns\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)onenote\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)onestore\.ms$", 271)//
CALL CreateServiceKeyword("(\.|^)powerbi\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)s-microsoft\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)s-msedge\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)s-msft\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)sfx\.ms$", 271)//
CALL CreateServiceKeyword("(\.|^)statics-marketingsites-eus-ms-com\.akamaized\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)statics-marketingsites-wcus-ms-com\.akamaized\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)swiftkey\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)t-msedge\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)touchtype-fluency\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)visualstudio\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)wbd\.ms$", 271)//
CALL CreateServiceKeyword("(\.|^)wd-prod-cp-us-west-1-fe\.westus\.cloudapp\.azure\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)whiteboard\.ms$", 271)//
CALL CreateServiceKeyword("(\.|^)windows\.akadns\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)windows\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)windows\.com\.akadns\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)windows\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)windowsmedia\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)windowsphone\.com$", 271)//
CALL CreateServiceKeyword("(\.|^)wpc\.v0cdn\.net$", 271)//
CALL CreateServiceKeyword("(\.|^)www\.microsoft\.com-c-3\.edgekey\.net$", 271)//
CALL CreateService("Microsoft Auth")//
CALL CreateServiceKeyword("(\.|^)account\.live\.com$", 272)//
CALL CreateServiceKeyword("(\.|^)activedirectory\.windowsazure\.com$", 272)//
CALL CreateServiceKeyword("(\.|^)ags\.akadns\.net$", 272)//
CALL CreateServiceKeyword("(\.|^)client\.hip\.live\.com$", 272)//
CALL CreateServiceKeyword("(\.|^)graph\.microsoft\.com$", 272)//
CALL CreateServiceKeyword("(\.|^)graph\.windows\.net$", 272)//
CALL CreateServiceKeyword("(\.|^)login\.live\.com$", 272)//
CALL CreateServiceKeyword("(\.|^)login\.microsoftonline\.com$", 272)//
CALL CreateServiceKeyword("(\.|^)login\.windows\.net$", 272)//
CALL CreateServiceKeyword("(\.|^)microsoftazuread-sso\.com$", 272)//
CALL CreateServiceKeyword("(\.|^)msauth\.net$", 272)//
CALL CreateServiceKeyword("(\.|^)msftauth\.net$", 272)//
CALL CreateServiceKeyword("(\.|^)msidentity\.com$", 272)//
CALL CreateServiceKeyword("(\.|^)myaccount\.microsoft\.com$", 272)//
CALL CreateServiceKeyword("(\.|^)mysignins\.microsoft\.com$", 272)//
CALL CreateServiceKeyword("(\.|^)passport\.net$", 272)//
CALL CreateServiceKeyword("(\.|^)passwordreset\.microsoftonline\.com$", 272)//
CALL CreateServiceKeyword("(\.|^)signup\.live\.com$", 272)//
CALL CreateServiceKeyword("(\.|^)tm\.a\.prd\.aadg\.akadns\.net$", 272)//
CALL CreateServiceKeyword("(\.|^)tm\.ak\.prd\.aadg\.akadns\.net$", 272)//
CALL CreateServiceKeyword("(\.|^)tm\.f\.prd\.aadg\.akadns\.net$", 272)//
CALL CreateService("Microsoft Office")//
CALL CreateServiceKeyword("(\.|^)assets-yammer\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)client-office365-tas\.msedge\.net$", 273)//
CALL CreateServiceKeyword("(\.|^)clo\.footprintdns\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)e11271\.dscg\.akamaiedge\.net$", 273)//
CALL CreateServiceKeyword("(\.|^)microsoftonline-p\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)microsoftonline\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)msocdn\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)msocsp\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)nrb\.footprintdns\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)o365filtering\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)office\.akadns\.net$", 273)//
CALL CreateServiceKeyword("(\.|^)office\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)office\.com\.akadns\.net$", 273)//
CALL CreateServiceKeyword("(\.|^)office\.de$", 273)//
CALL CreateServiceKeyword("(\.|^)office\.microsoft$", 273)//
CALL CreateServiceKeyword("(\.|^)office\.net$", 273)//
CALL CreateServiceKeyword("(\.|^)office\.net\.akadns\.net$", 273)//
CALL CreateServiceKeyword("(\.|^)office365\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)office365\.com\.edgekey\.net$", 273)//
CALL CreateServiceKeyword("(\.|^)office365\.us$", 273)//
CALL CreateServiceKeyword("(\.|^)officeapps\.live\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)officeapps\.live\.com\.edgekey\.net$", 273)//
CALL CreateServiceKeyword("(\.|^)officecdn-microsoft-com\.akamaized\.net$", 273)//
CALL CreateServiceKeyword("(\.|^)officecdn\.microsoft\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)officeclient\.microsoft\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)onmicrosoft\.com$", 273)//
CALL CreateServiceKeyword("(\.|^)svc\.ms$", 273)//
CALL CreateServiceKeyword("(\.|^)yammer\.com$", 273)//
CALL CreateService("Microsoft SharePoint")//
CALL CreateServiceKeyword("(\.|^)sharepoint-df\.com$", 274)//
CALL CreateServiceKeyword("(\.|^)sharepoint\.cn$", 274)//
CALL CreateServiceKeyword("(\.|^)sharepoint\.com$", 274)//
CALL CreateServiceKeyword("(\.|^)sharepoint\.com\.spo-0004\.spo-msedge\.net$", 274)//
CALL CreateServiceKeyword("(\.|^)sharepoint\.com\.spov-0006\.spov-msedge\.net$", 274)//
CALL CreateServiceKeyword("(\.|^)sharepoint\.de$", 274)//
CALL CreateServiceKeyword("(\.|^)sharepoint\.us$", 274)//
CALL CreateServiceKeyword("(\.|^)sharepointonline\.com$", 274)//
CALL CreateServiceKeyword("(\.|^)sharepointonline\.com\.akadns\.net$", 274)//
CALL CreateServiceKeyword("(\.|^)sharepointonline\.com\.edgekey\.net$", 274)//
CALL CreateServiceKeyword("(\.|^)spo-msedge\.net$", 274)//
CALL CreateServiceKeyword("(\.|^)spo-ring\.msedge\.net$", 274)//
CALL CreateServiceKeyword("(\.|^)spoppe\.com$", 274)//
CALL CreateServiceKeyword("(\.|^)spoppe\.com\.dual-spo-0002\.spo-msedge\.net$", 274)//
CALL CreateServiceKeyword("(\.|^)spov-msedge\.net$", 274)//
CALL CreateService("Microsoft Teams")//
CALL CreateServiceKeyword("(\.|^)api\.teams\.skype\.com$", 275)//
CALL CreateServiceKeyword("(\.|^)img\.teams\.skype\.com$", 275)//
CALL CreateServiceKeyword("(\.|^)teams-msgapi\.trafficmanager\.net$", 275)//
CALL CreateServiceKeyword("(\.|^)teams\.cdn\.office\.net$", 275)//
CALL CreateServiceKeyword("(\.|^)teams\.events\.data\.microsoft\.com$", 275)//
CALL CreateServiceKeyword("(\.|^)teams\.microsoft\.com$", 275)//
CALL CreateServiceKeyword("(\.|^)teams\.microsoft\.us$", 275)//
CALL CreateServiceKeyword("(\.|^)teams\.office\.com$", 275)//
CALL CreateServiceKeyword("(\.|^)teams\.office\.net$", 275)//
CALL CreateServiceKeyword("(\.|^)teams\.skype\.com$", 275)//
CALL CreateServiceKeyword("(\.|^)teams\.trafficmanager\.net$", 275)//
CALL CreateServiceKeyword("(\.|^)trouter-teams-prod\.akadns\.net$", 275)//
CALL CreateService("MobTech")//
CALL CreateServiceKeyword("(\.|^)mob\.com$", 276)//
CALL CreateService("NetSuite")//
CALL CreateServiceKeyword("(\.|^)netsuite\.com$", 277)//
CALL CreateServiceKeyword("(\.|^)netsuite\.com\.edgekey\.net$", 277)//
CALL CreateServiceKeyword("(\.|^)netsuite\.tt\.omtrdc\.net$", 277)//
CALL CreateService("Neustar")//
CALL CreateServiceKeyword("(\.|^)aa-agkn-com-https-1893222849\.eu-west-2\.elb\.amazonaws\.com$", 278)//
CALL CreateServiceKeyword("(\.|^)aa-agkn-com-https-2145740884\.eu-central-1\.elb\.amazonaws\.com$", 278)//
CALL CreateServiceKeyword("(\.|^)aa-agkn-com-https-51506257\.ap-northeast-1\.elb\.amazonaws\.com$", 278)//
CALL CreateServiceKeyword("(\.|^)agkn\.com$", 278)//
CALL CreateServiceKeyword("(\.|^)neustar$", 278)//
CALL CreateServiceKeyword("(\.|^)ultradns\.biz$", 278)//
CALL CreateServiceKeyword("(\.|^)ultradns\.co\.uk$", 278)//
CALL CreateServiceKeyword("(\.|^)ultradns\.com$", 278)//
CALL CreateServiceKeyword("(\.|^)ultradns\.info$", 278)//
CALL CreateServiceKeyword("(\.|^)ultradns\.net$", 278)//
CALL CreateServiceKeyword("(\.|^)ultradns\.org$", 278)//
CALL CreateService("New Relic")//
CALL CreateServiceKeyword("(\.|^)newrelic\.com$", 279)//
CALL CreateServiceKeyword("(\.|^)newrelic\.com\.cdn\.cloudflare\.net$", 279)//
CALL CreateServiceKeyword("(\.|^)newrelic\.map\.fastly\.net$", 279)//
CALL CreateServiceKeyword("(\.|^)nr-data\.net$", 279)//
CALL CreateService("Notarius")//
CALL CreateServiceKeyword("(\.|^)notarius\.com$", 280)//
CALL CreateServiceKeyword("(\.|^)notarius\.net$", 280)//
CALL CreateService("Notion")//
CALL CreateServiceKeyword("(\.|^)notion\.com$", 281)//
CALL CreateServiceKeyword("(\.|^)notion\.so$", 281)//
CALL CreateService("Nvidia")//
CALL CreateServiceKeyword("(\.|^)nvidia\.cn$", 282)//
CALL CreateServiceKeyword("(\.|^)nvidia\.com$", 282)//
CALL CreateServiceKeyword("(\.|^)nvidia\.tt\.omtrdc\.net$", 282)//
CALL CreateServiceKeyword("(\.|^)nvidiagrid\.net$", 282)//
CALL CreateService("One-Time Secret")//
CALL CreateServiceKeyword("(\.|^)onetimesecret\.com$", 283)//
CALL CreateService("OpenOffice")//
CALL CreateServiceKeyword("(\.|^)openoffice\.org$", 284)//
CALL CreateService("Opera")//
CALL CreateServiceKeyword("(\.|^)feednews\.com$", 285)//
CALL CreateServiceKeyword("(\.|^)op-cdn\.net$", 285)//
CALL CreateServiceKeyword("(\.|^)opera-api\.com$", 285)//
CALL CreateServiceKeyword("(\.|^)opera-mini\.net$", 285)//
CALL CreateServiceKeyword("(\.|^)opera\.com$", 285)//
CALL CreateServiceKeyword("(\.|^)opera\.io$", 285)//
CALL CreateServiceKeyword("(\.|^)opera\.no$", 285)//
CALL CreateServiceKeyword("(\.|^)opera\.software$", 285)//
CALL CreateServiceKeyword("(\.|^)opera\.technology$", 285)//
CALL CreateServiceKeyword("(\.|^)operacdn\.com$", 285)//
CALL CreateServiceKeyword("(\.|^)operachina\.com$", 285)//
CALL CreateServiceKeyword("(\.|^)operaunite\.com$", 285)//
CALL CreateService("Oracle")//
CALL CreateServiceKeyword("(\.|^)oracle\.com$", 286)//
CALL CreateServiceKeyword("(\.|^)oracle\.com\.akadns\.net$", 286)//
CALL CreateServiceKeyword("(\.|^)oracle\.com\.edgekey\.net$", 286)//
CALL CreateServiceKeyword("(\.|^)oraclecloud\.com$", 286)//
CALL CreateService("Orange")//
CALL CreateServiceKeyword("(\.|^)francetelecom\.com$", 287)//
CALL CreateServiceKeyword("(\.|^)orange\.com$", 287)//
CALL CreateServiceKeyword("(\.|^)orange\.es$", 287)//
CALL CreateServiceKeyword("(\.|^)orange\.fr$", 287)//
CALL CreateService("PDQ.com")//
CALL CreateServiceKeyword("(\.|^)pdq\.com$", 288)//
CALL CreateService("Parallels")//
CALL CreateServiceKeyword("(\.|^)parallels\.com$", 289)//
CALL CreateServiceKeyword("(\.|^)parallels\.com\.cdn\.cloudflare\.net$", 289)//
CALL CreateService("Pitney Bowes")//
CALL CreateServiceKeyword("(\.|^)d2sbh6dpxtmh7p\.cloudfront\.net$", 290)//
CALL CreateServiceKeyword("(\.|^)d9qjxq1oiycct\.cloudfront\.net$", 290)//
CALL CreateServiceKeyword("(\.|^)dp6ia2h50k4c\.cloudfront\.net$", 290)//
CALL CreateServiceKeyword("(\.|^)pb-ota\.redbend\.com$", 290)//
CALL CreateServiceKeyword("(\.|^)pb\.com$", 290)//
CALL CreateServiceKeyword("(\.|^)pitneybowes\.com$", 290)//
CALL CreateServiceKeyword("(\.|^)pitneybowes\.com\.cdn\.cloudflare\.net$", 290)//
CALL CreateServiceKeyword("(\.|^)pitneybowes\.demdex\.net$", 290)//
CALL CreateServiceKeyword("(\.|^)pitneybowes\.okta\.com$", 290)//
CALL CreateServiceKeyword("(\.|^)pitneybowes\.sc\.omtrdc\.net$", 290)//
CALL CreateServiceKeyword("(\.|^)pitneybowes\.us$", 290)//
CALL CreateServiceKeyword("(\.|^)pitneybowesinc\.tt\.omtrdc\.net$", 290)//
CALL CreateServiceKeyword("(\.|^)pitneycloud\.com$", 290)//
CALL CreateService("Pocket")//
CALL CreateServiceKeyword("(\.|^)getpocket\.cdn\.mozilla\.net$", 291)//
CALL CreateServiceKeyword("(\.|^)getpocket\.com$", 291)//
CALL CreateServiceKeyword("(\.|^)img-getpocket\.cdn\.mozilla\.net$", 291)//
CALL CreateServiceKeyword("(\.|^)proxyserverecs-1736642167\.us-east-1\.elb\.amazonaws\.com$", 291)//
CALL CreateService("Polyfill")//
CALL CreateServiceKeyword("(\.|^)polyfill\.io$", 292)//
CALL CreateServiceKeyword("(\.|^)polyfill\.map\.fastly\.net$", 292)//
CALL CreateService("PubNub")//
CALL CreateServiceKeyword("(\.|^)pndsn\.com$", 293)//
CALL CreateServiceKeyword("(\.|^)pubnub\.com$", 293)//
CALL CreateServiceKeyword("(\.|^)pubnubapi\.com$", 293)//
CALL CreateService("Pulseway")//
CALL CreateServiceKeyword("(\.|^)pulseway\.com$", 294)//
CALL CreateService("RBackup")//
CALL CreateServiceKeyword("(\.|^)remote-backup\.com$", 295)//
CALL CreateService("Reflected Networks")//
CALL CreateServiceKeyword("(\.|^)reflected\.net$", 296)//
CALL CreateServiceKeyword("(\.|^)rncdn1\.com$", 296)//
CALL CreateServiceKeyword("(\.|^)rncdn2\.com$", 296)//
CALL CreateServiceKeyword("(\.|^)rncdn3\.com$", 296)//
CALL CreateServiceKeyword("(\.|^)rncdn4\.com$", 296)//
CALL CreateServiceKeyword("(\.|^)rncdn5\.com$", 296)//
CALL CreateServiceKeyword("(\.|^)rncdn6\.com$", 296)//
CALL CreateServiceKeyword("(\.|^)rncdn7\.com$", 296)//
CALL CreateService("Rogers")//
CALL CreateServiceKeyword("(\.|^)ca\.rogers\.rcs\.telephony\.goog$", 297)//
CALL CreateServiceKeyword("(\.|^)rogers\.com$", 297)//
CALL CreateService("SAP")//
CALL CreateServiceKeyword("(\.|^)fieldglass\.net$", 298)//
CALL CreateServiceKeyword("(\.|^)sap\.com$", 298)//
CALL CreateServiceKeyword("(\.|^)sap\.com\.cloud\.sap\.akadns\.net$", 298)//
CALL CreateServiceKeyword("(\.|^)sap\.com\.edgekey\.net$", 298)//
CALL CreateServiceKeyword("(\.|^)sap\.com\.sdn\.akadns\.net$", 298)//
CALL CreateServiceKeyword("(\.|^)sap\.com\.ssl\.sc\.omtrdc\.net$", 298)//
CALL CreateService("SOS Online Backup")//
CALL CreateServiceKeyword("(\.|^)sosonlinebackup\.com$", 299)//
CALL CreateService("Samsara")//
CALL CreateServiceKeyword("(\.|^)samsara\.com$", 300)//
CALL CreateService("Seagate")//
CALL CreateServiceKeyword("(\.|^)seagate\.com$", 301)//
CALL CreateServiceKeyword("(\.|^)seagategov\.com$", 301)//
CALL CreateService("Sentry")//
CALL CreateServiceKeyword("(\.|^)sentry-cdn\.com$", 302)//
CALL CreateServiceKeyword("(\.|^)sentry\.io$", 302)//
CALL CreateService("ServiceNow")//
CALL CreateServiceKeyword("(\.|^)service-now\.com$", 303)//
CALL CreateServiceKeyword("(\.|^)servicenow\.com$", 303)//
CALL CreateService("Shaw")//
CALL CreateServiceKeyword("(\.|^)shaw\.ca$", 304)//
CALL CreateServiceKeyword("(\.|^)shaw\.ca\.ssl\.sc\.omtrdc\.net$", 304)//
CALL CreateServiceKeyword("(\.|^)shawcable\.net$", 304)//
CALL CreateServiceKeyword("(\.|^)shawdirect\.ca$", 304)//
CALL CreateServiceKeyword("(\.|^)shawtelevision\.hb\.omtrdc\.net$", 304)//
CALL CreateService("SimilarWeb")//
CALL CreateServiceKeyword("(\.|^)similarweb\.com$", 305)//
CALL CreateService("SimpleMining")//
CALL CreateServiceKeyword("(\.|^)simplemining\.net$", 306)//
CALL CreateService("Site24x7")//
CALL CreateServiceKeyword("(\.|^)site24x7\.com$", 307)//
CALL CreateService("Sky")//
CALL CreateServiceKeyword("(\.|^)sky\.com$", 308)//
CALL CreateServiceKeyword("(\.|^)sky\.com\.edgekey\.net$", 308)//
CALL CreateServiceKeyword("(\.|^)sky\.it$", 308)//
CALL CreateServiceKeyword("(\.|^)skynews\.com$", 308)//
CALL CreateServiceKeyword("(\.|^)skyq\.info$", 308)//
CALL CreateService("Slack")//
CALL CreateServiceKeyword("(\.|^)slack-core\.com$", 309)//
CALL CreateServiceKeyword("(\.|^)slack-edge\.com$", 309)//
CALL CreateServiceKeyword("(\.|^)slack-files\.com$", 309)//
CALL CreateServiceKeyword("(\.|^)slack-imgs\.com$", 309)//
CALL CreateServiceKeyword("(\.|^)slack-msgs\.com$", 309)//
CALL CreateServiceKeyword("(\.|^)slack-redir\.net$", 309)//
CALL CreateServiceKeyword("(\.|^)slack\.com$", 309)//
CALL CreateServiceKeyword("(\.|^)slack\.map\.fastly\.net$", 309)//
CALL CreateServiceKeyword("(\.|^)slackb\.com$", 309)//
CALL CreateService("SmartDrive")//
CALL CreateServiceKeyword("(\.|^)smartdrive\.net$", 310)//
CALL CreateService("SmugMug")//
CALL CreateServiceKeyword("(\.|^)smugmug\.com$", 311)//
CALL CreateService("SolarWinds")//
CALL CreateServiceKeyword("(\.|^)backup\.management$", 312)//
CALL CreateServiceKeyword("(\.|^)cdn-sw\.net$", 312)//
CALL CreateServiceKeyword("(\.|^)cloudbackup\.management$", 312)//
CALL CreateServiceKeyword("(\.|^)controlnow\.com$", 312)//
CALL CreateServiceKeyword("(\.|^)gficloud\.com$", 312)//
CALL CreateServiceKeyword("(\.|^)loggly\.com$", 312)//
CALL CreateServiceKeyword("(\.|^)logicnow\.com$", 312)//
CALL CreateServiceKeyword("(\.|^)logicnow\.us$", 312)//
CALL CreateServiceKeyword("(\.|^)n-able\.com$", 312)//
CALL CreateServiceKeyword("(\.|^)n-able\.com\.cdn\.cloudflare\.net$", 312)//
CALL CreateServiceKeyword("(\.|^)remote\.management$", 312)//
CALL CreateServiceKeyword("(\.|^)solarwinds\.com$", 312)//
CALL CreateServiceKeyword("(\.|^)solarwindsmsp\.com$", 312)//
CALL CreateServiceKeyword("(\.|^)system-monitor\.com$", 312)//
CALL CreateServiceKeyword("(\.|^)systemmonitor\.co\.uk$", 312)//
CALL CreateServiceKeyword("(\.|^)systemmonitor\.eu\.com$", 312)//
CALL CreateServiceKeyword("(\.|^)systemmonitor\.us$", 312)//
CALL CreateServiceKeyword("(\.|^)systemmonitor\.us\.cdn\.cloudflare\.net$", 312)//
CALL CreateService("Sony")//
CALL CreateServiceKeyword("(\.|^)ndmdhs\.com$", 313)//
CALL CreateServiceKeyword("(\.|^)sony$", 313)//
CALL CreateServiceKeyword("(\.|^)sony\.com$", 313)//
CALL CreateServiceKeyword("(\.|^)sony\.net$", 313)//
CALL CreateServiceKeyword("(\.|^)sonymusicfans\.com$", 313)//
CALL CreateService("SpaceX")//
CALL CreateServiceKeyword("(\.|^)spacex\.com$", 314)//
CALL CreateServiceKeyword("(\.|^)spacex\.map\.fastly\.net$", 314)//
CALL CreateService("Split")//
CALL CreateServiceKeyword("(\.|^)events-prod-1-1033355748\.us-east-1\.elb\.amazonaws\.com$", 315)//
CALL CreateServiceKeyword("(\.|^)split\.io$", 315)//
CALL CreateService("Splunk")//
CALL CreateServiceKeyword("(\.|^)splunk\.com$", 316)//
CALL CreateServiceKeyword("(\.|^)splunkcloud\.com$", 316)//
CALL CreateService("Starlink")//
CALL CreateServiceKeyword("(\.|^)starlink\.com$", 317)//
CALL CreateService("Statuspage")//
CALL CreateServiceKeyword("(\.|^)statuspage\.io$", 318)//
CALL CreateService("T-Mobile")//
CALL CreateServiceKeyword("(\.|^)t-mobile\.com$", 319)//
CALL CreateServiceKeyword("(\.|^)tmobile\.demdex\.net$", 319)//
CALL CreateServiceKeyword("(\.|^)tmobile\.tt\.omtrdc\.net$", 319)//
CALL CreateService("Telus")//
CALL CreateServiceKeyword("(\.|^)telus\.com$", 320)//
CALL CreateServiceKeyword("(\.|^)telusdigital-infra-1067146676\.ca-central-1\.elb\.amazonaws\.com$", 320)//
CALL CreateServiceKeyword("(\.|^)telusdigital\.openshiftapps\.com$", 320)//
CALL CreateService("Tesla")//
CALL CreateServiceKeyword("(\.|^)tesla\.com$", 321)//
CALL CreateServiceKeyword("(\.|^)tesla\.services$", 321)//
CALL CreateServiceKeyword("(\.|^)teslamotors\.com$", 321)//
CALL CreateService("Toshiba")//
CALL CreateServiceKeyword("(\.|^)toshiba\.com$", 322)//
CALL CreateService("Trello")//
CALL CreateServiceKeyword("(\.|^)trello\.com$", 323)//
CALL CreateService("Trimble MAPS")//
CALL CreateServiceKeyword("(\.|^)alk\.com$", 324)//
CALL CreateServiceKeyword("(\.|^)trimble\.com$", 324)//
CALL CreateService("UPS")//
CALL CreateServiceKeyword("(\.|^)h-ups\.online-metrix\.net$", 325)//
CALL CreateServiceKeyword("(\.|^)unitedparcelservice\.sc\.omtrdc\.net$", 325)//
CALL CreateServiceKeyword("(\.|^)ups\.com$", 325)//
CALL CreateServiceKeyword("(\.|^)ups\.com\.akadns\.net$", 325)//
CALL CreateServiceKeyword("(\.|^)ups\.com\.edgekey\.net\.globalredir\.akadns\.net$", 325)//
CALL CreateServiceKeyword("(\.|^)ups\.com\.ssl\.sc\.omtrdc\.net$", 325)//
CALL CreateServiceKeyword("(\.|^)ups\.demdex\.net$", 325)//
CALL CreateServiceKeyword("(\.|^)ups\.tt\.omtrdc\.net$", 325)//
CALL CreateService("Uber")//
CALL CreateServiceKeyword("(\.|^)geixahba\.com$", 326)//
CALL CreateServiceKeyword("(\.|^)oojoovae\.org$", 326)//
CALL CreateServiceKeyword("(\.|^)ooshahwa\.biz$", 326)//
CALL CreateServiceKeyword("(\.|^)shaipeeg\.net$", 326)//
CALL CreateServiceKeyword("(\.|^)uber\.com$", 326)//
CALL CreateServiceKeyword("(\.|^)ubereats\.com$", 326)//
CALL CreateService("Unpkg Javascript")//
CALL CreateServiceKeyword("(\.|^)unpkg\.com$", 327)//
CALL CreateService("UserEngage")//
CALL CreateServiceKeyword("(\.|^)user\.com$", 328)//
CALL CreateServiceKeyword("(\.|^)userengage\.com$", 328)//
CALL CreateServiceKeyword("(\.|^)userengage\.io$", 328)//
CALL CreateService("Verizon Wireless")//
CALL CreateServiceKeyword("(\.|^)myvzw\.com$", 329)//
CALL CreateServiceKeyword("(\.|^)verizonwireless\.com$", 329)//
CALL CreateServiceKeyword("(\.|^)vzw\.com$", 329)//
CALL CreateServiceKeyword("(\.|^)vzwwo\.com$", 329)//
CALL CreateService("ViaSat")//
CALL CreateServiceKeyword("(\.|^)exede\.net$", 330)//
CALL CreateServiceKeyword("(\.|^)viasat\.com$", 330)//
CALL CreateServiceKeyword("(\.|^)viasat\.io$", 330)//
CALL CreateService("Vodafone")//
CALL CreateServiceKeyword("(\.|^)omnitel\.it$", 331)//
CALL CreateServiceKeyword("(\.|^)vodafone\.com$", 331)//
CALL CreateServiceKeyword("(\.|^)vodafone\.de$", 331)//
CALL CreateServiceKeyword("(\.|^)vodafone\.gr$", 331)//
CALL CreateServiceKeyword("(\.|^)vodafone\.net$", 331)//
CALL CreateService("Volvo")//
CALL CreateServiceKeyword("(\.|^)volvo\.com$", 332)//
CALL CreateService("Vultr")//
CALL CreateServiceKeyword("(\.|^)vultr\.com$", 333)//
CALL CreateServiceKeyword("(\.|^)vultr\.com\.cdn\.cloudflare\.net$", 333)//
CALL CreateService("Wix")//
CALL CreateServiceKeyword("(\.|^)bi-flogger-alb-ext-343643057\.us-east-1\.elb\.amazonaws\.com$", 334)//
CALL CreateServiceKeyword("(\.|^)wix\.com$", 334)//
CALL CreateServiceKeyword("(\.|^)wixanswers\.com$", 334)//
CALL CreateServiceKeyword("(\.|^)wixapps\.net$", 334)//
CALL CreateServiceKeyword("(\.|^)wixdns\.net$", 334)//
CALL CreateServiceKeyword("(\.|^)wixsite\.com$", 334)//
CALL CreateServiceKeyword("(\.|^)wixstatic\.com$", 334)//
CALL CreateService("Wondershare")//
CALL CreateServiceKeyword("(\.|^)wondershare\.com$", 335)//
CALL CreateService("WordPress")//
CALL CreateServiceKeyword("(\.|^)w\.org$", 336)//
CALL CreateServiceKeyword("(\.|^)wordpress\.com$", 336)//
CALL CreateServiceKeyword("(\.|^)wordpress\.org$", 336)//
CALL CreateServiceKeyword("(\.|^)wp\.com$", 336)//
CALL CreateService("Workspace ONE")//
CALL CreateServiceKeyword("(\.|^)awmdm\.com$", 337)//
CALL CreateService("Xara Cloud")//
CALL CreateServiceKeyword("(\.|^)xara\.com$", 338)//
CALL CreateService("Xfinity")//
CALL CreateServiceKeyword("(\.|^)comcast\.com$", 339)//
CALL CreateServiceKeyword("(\.|^)comcast\.net$", 339)//
CALL CreateServiceKeyword("(\.|^)xfinity\.com$", 339)//
CALL CreateService("Zendesk")//
CALL CreateServiceKeyword("(\.|^)zdassets\.com$", 340)//
CALL CreateServiceKeyword("(\.|^)zendesk\.com$", 340)//
CALL CreateServiceKeyword("(\.|^)zopim\.com$", 340)//
CALL CreateService("Zoho")//
CALL CreateServiceKeyword("(\.|^)zoho\.com$", 341)//
CALL CreateServiceKeyword("(\.|^)zoho\.com\.au$", 341)//
CALL CreateServiceKeyword("(\.|^)zoho\.eu$", 341)//
CALL CreateServiceKeyword("(\.|^)zoho\.in$", 341)//
CALL CreateServiceKeyword("(\.|^)zohocal\.com$", 341)//
CALL CreateServiceKeyword("(\.|^)zohocdn\.com$", 341)//
CALL CreateServiceKeyword("(\.|^)zohomeeting\.com$", 341)//
CALL CreateServiceKeyword("(\.|^)zohopublic\.com$", 341)//
CALL CreateServiceKeyword("(\.|^)zohopublic\.com\.au$", 341)//
CALL CreateServiceKeyword("(\.|^)zohopublic\.eu$", 341)//
CALL CreateServiceKeyword("(\.|^)zohopublic\.in$", 341)//
CALL CreateServiceKeyword("(\.|^)zohosecurepay\.com$", 341)//
CALL CreateServiceKeyword("(\.|^)zohospotlight\.com$", 341)//
CALL CreateServiceKeyword("(\.|^)zohostatic\.com$", 341)//
CALL CreateServiceKeyword("(\.|^)zohostatic\.eu$", 341)//
CALL CreateServiceKeyword("(\.|^)zohovoice\.com$", 341)//
CALL CreateService("eGloo")//
CALL CreateServiceKeyword("(\.|^)egloo\.ca$", 342)//
CALL CreateServiceKeyword("(\.|^)pointclark\.com$", 342)//
CALL CreateService("jsDelivr")//
CALL CreateServiceKeyword("(\.|^)jsdelivr\.com$", 343)//
CALL CreateServiceKeyword("(\.|^)jsdelivr\.map\.fastly\.net$", 343)//
CALL CreateServiceKeyword("(\.|^)jsdelivr\.net$", 343)//
CALL CreateServiceKeyword("(\.|^)jsdelivr\.net\.cdn\.cloudflare\.net$", 343)//
CALL CreateService("pingdom.com")//
CALL CreateServiceKeyword("(\.|^)pingdom\.com$", 344)//
CALL CreateServiceKeyword("(\.|^)pingdom\.net$", 344)//
CALL CreateService("Edmodo")//
CALL CreateServiceKeyword("(\.|^)edmodo\.com$", 345)//
CALL CreateService("Freelancer")//
CALL CreateServiceKeyword("(\.|^)f-cdn\.com$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.ca$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.cl$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.co\.nz$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.co\.uk$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.co\.za$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.com$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.com\.au$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.com\.jm$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.de$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.ec$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.es$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.hk$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.in$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.is$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.mx$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.pk$", 346)//
CALL CreateServiceKeyword("(\.|^)freelancer\.sg$", 346)//
CALL CreateServiceKeyword("(\.|^)h-freelancer1\.online-metrix\.net$", 346)//
CALL CreateServiceKeyword("(\.|^)vworker\.com$", 346)//
CALL CreateService("Grammarly")//
CALL CreateServiceKeyword("(\.|^)grammarly\.com$", 347)//
CALL CreateServiceKeyword("(\.|^)grammarly\.io$", 347)//
CALL CreateServiceKeyword("(\.|^)grammarlyaws\.com$", 347)//
CALL CreateService("Indeed")//
CALL CreateServiceKeyword("(\.|^)indeed\.com$", 348)//
CALL CreateService("Instructure")//
CALL CreateServiceKeyword("(\.|^)instructure-uploads\.s3\.amazonaws\.com$", 349)//
CALL CreateServiceKeyword("(\.|^)instructure\.com$", 349)//
CALL CreateService("Khan Academy")//
CALL CreateServiceKeyword("(\.|^)khan\.map\.fastly\.net$", 350)//
CALL CreateServiceKeyword("(\.|^)khanacademy\.org$", 350)//
CALL CreateService("Queen's University")//
CALL CreateServiceKeyword("(\.|^)givetoqueens\.ca$", 351)//
CALL CreateServiceKeyword("(\.|^)queensu\.ca$", 351)//
CALL CreateService("Seesaw")//
CALL CreateServiceKeyword("(\.|^)seesaw\.me$", 352)//
CALL CreateService("Wikispaces")//
CALL CreateServiceKeyword("(\.|^)wikispaces\.com$", 353)//
CALL CreateService("Alipay")//
CALL CreateServiceKeyword("(\.|^)alipay$", 354)//
CALL CreateServiceKeyword("(\.|^)alipay\.cn$", 354)//
CALL CreateServiceKeyword("(\.|^)alipay\.com$", 354)//
CALL CreateServiceKeyword("(\.|^)alipay\.hk$", 354)//
CALL CreateServiceKeyword("(\.|^)alipayobjects\.com$", 354)//
CALL CreateService("American Express")//
CALL CreateServiceKeyword("(\.|^)aexp-static\.com$", 355)//
CALL CreateServiceKeyword("(\.|^)aexp\.demdex\.net$", 355)//
CALL CreateServiceKeyword("(\.|^)americanexpress\.com$", 355)//
CALL CreateServiceKeyword("(\.|^)americanexpress\.com\.akadns\.net$", 355)//
CALL CreateServiceKeyword("(\.|^)americanexpress\.com\.edgekey\.net$", 355)//
CALL CreateServiceKeyword("(\.|^)americanexpress\.com\.ssl\.d2\.sc\.omtrdc\.net$", 355)//
CALL CreateServiceKeyword("(\.|^)amex$", 355)//
CALL CreateService("Anthem")//
CALL CreateServiceKeyword("(\.|^)anthem\.com$", 356)//
CALL CreateServiceKeyword("(\.|^)antheminc\.com$", 356)//
CALL CreateServiceKeyword("(\.|^)bcbsga\.com$", 356)//
CALL CreateServiceKeyword("(\.|^)empireblue\.com$", 356)//
CALL CreateService("BMO")//
CALL CreateServiceKeyword("(\.|^)bankofmontreal\.tt\.omtrdc\.net$", 357)//
CALL CreateServiceKeyword("(\.|^)bmo\.com$", 357)//
CALL CreateServiceKeyword("(\.|^)bmocareers\.com$", 357)//
CALL CreateServiceKeyword("(\.|^)bmocm\.com$", 357)//
CALL CreateService("BNP Paribas")//
CALL CreateServiceKeyword("(\.|^)bnpparibas$", 358)//
CALL CreateServiceKeyword("(\.|^)bnpparibas\.com$", 358)//
CALL CreateServiceKeyword("(\.|^)bnpparibas\.net$", 358)//
CALL CreateService("Banamex")//
CALL CreateServiceKeyword("(\.|^)banamex\.com$", 359)//
CALL CreateServiceKeyword("(\.|^)citibanamex\.com$", 359)//
CALL CreateServiceKeyword("(\.|^)segurosbanamex\.com\.mx$", 359)//
CALL CreateService("Bank of America")//
CALL CreateServiceKeyword("(\.|^)bac\.com$", 360)//
CALL CreateServiceKeyword("(\.|^)bankofamerica\.com$", 360)//
CALL CreateServiceKeyword("(\.|^)bankofamerica\.tt\.omtrdc\.net$", 360)//
CALL CreateServiceKeyword("(\.|^)bankofamerica1\.sc\.omtrdc\.net$", 360)//
CALL CreateServiceKeyword("(\.|^)bofa\.demdex\.net$", 360)//
CALL CreateServiceKeyword("(\.|^)merrilledge\.com$", 360)//
CALL CreateServiceKeyword("(\.|^)ml\.com$", 360)//
CALL CreateServiceKeyword("(\.|^)prod-lb-9-1476932994\.us-east-1\.elb\.amazonaws\.com$", 360)//
CALL CreateServiceKeyword("(\.|^)totalmerrill\.com$", 360)//
CALL CreateService("CIBC")//
CALL CreateServiceKeyword("(\.|^)canadianimperialbank\.tt\.omtrdc\.net$", 361)//
CALL CreateServiceKeyword("(\.|^)cibc\.com$", 361)//
CALL CreateServiceKeyword("(\.|^)cibc\.com\.edgekey\.net$", 361)//
CALL CreateServiceKeyword("(\.|^)cibc\.com\.ssl\.d2\.sc\.omtrdc\.net$", 361)//
CALL CreateServiceKeyword("(\.|^)h-cibc\.online-metrix\.net$", 361)//
CALL CreateService("Canadian Tire Bank")//
CALL CreateServiceKeyword("(\.|^)ctfs\.com$", 362)//
CALL CreateServiceKeyword("(\.|^)myctfs\.com$", 362)//
CALL CreateServiceKeyword("(\.|^)triangle\.canadiantire\.ca$", 362)//
CALL CreateService("Capital One")//
CALL CreateServiceKeyword("(\.|^)capitalone\.com$", 363)//
CALL CreateServiceKeyword("(\.|^)capitalone\.com\.edgekey\.net$", 363)//
CALL CreateServiceKeyword("(\.|^)capitalone\.com\.ssl\.d1\.sc\.omtrdc\.net$", 363)//
CALL CreateService("Cigna")//
CALL CreateServiceKeyword("(\.|^)careallies\.com$", 364)//
CALL CreateServiceKeyword("(\.|^)cigna\.com$", 364)//
CALL CreateService("Citi")//
CALL CreateServiceKeyword("(\.|^)citi\.com$", 365)//
CALL CreateServiceKeyword("(\.|^)citi\.com\.edgekey\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)citi\.com\.ssl\.sc\.omtrdc\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)citi\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)citibank\.com$", 365)//
CALL CreateServiceKeyword("(\.|^)citicorp\.com$", 365)//
CALL CreateServiceKeyword("(\.|^)citicorpcreditservic\.tt\.omtrdc\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)citidirect\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-cards\.citidirect\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citibank-au\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citibank-hk\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citibank-id\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citibank-in\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citibank-my\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citibank-ph\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citibank-sg\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citibank-th\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citibank-tw\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citibank-vn\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citibankonline\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citicards\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-citidirect\.online-metrix\.net$", 365)//
CALL CreateServiceKeyword("(\.|^)h-online\.citi\.online-metrix\.net$", 365)//
CALL CreateService("Coinbase")//
CALL CreateServiceKeyword("(\.|^)coinbase\.com$", 366)//
CALL CreateService("Discover Card")//
CALL CreateServiceKeyword("(\.|^)discover\.com$", 367)//
CALL CreateServiceKeyword("(\.|^)discover\.com\.edgekey\.net$", 367)//
CALL CreateServiceKeyword("(\.|^)discover\.com\.ssl\.d1\.sc\.omtrdc\.net$", 367)//
CALL CreateServiceKeyword("(\.|^)discover\.tt\.omtrdc\.net$", 367)//
CALL CreateServiceKeyword("(\.|^)discovercard\.com$", 367)//
CALL CreateServiceKeyword("(\.|^)discovercard\.com\.edgekey\.net$", 367)//
CALL CreateServiceKeyword("(\.|^)h-discover\.online-metrix\.net$", 367)//
CALL CreateService("EY")//
CALL CreateServiceKeyword("(\.|^)ey\.com$", 368)//
CALL CreateService("Ethermine")//
CALL CreateServiceKeyword("(\.|^)ethermine\.org$", 369)//
CALL CreateService("Fiserv")//
CALL CreateServiceKeyword("(\.|^)cashedge\.com$", 370)//
CALL CreateServiceKeyword("(\.|^)checkfreeweb\.com$", 370)//
CALL CreateServiceKeyword("(\.|^)fiserv\.com$", 370)//
CALL CreateServiceKeyword("(\.|^)fiservapps\.com$", 370)//
CALL CreateServiceKeyword("(\.|^)fiservmobileapps\.com$", 370)//
CALL CreateServiceKeyword("(\.|^)fiservmobileapps\.us\.cloud-fdc\.com$", 370)//
CALL CreateServiceKeyword("(\.|^)fiservsolutions-1\.demdex\.net$", 370)//
CALL CreateServiceKeyword("(\.|^)onefiserv\.com$", 370)//
CALL CreateServiceKeyword("(\.|^)payanyone2\.com$", 370)//
CALL CreateService("Flypool BEAM")//
CALL CreateServiceKeyword("(\.|^)asia1-beam\.flypool\.org$", 371)//
CALL CreateServiceKeyword("(\.|^)beam\.flypool\.org$", 371)//
CALL CreateServiceKeyword("(\.|^)eu1-beam\.flypool\.org$", 371)//
CALL CreateServiceKeyword("(\.|^)us1-beam\.flypool\.org$", 371)//
CALL CreateService("Flypool Ravencoin")//
CALL CreateServiceKeyword("(\.|^)ravencoin\.flypool\.org$", 372)//
CALL CreateServiceKeyword("(\.|^)stratum-ravencoin\.flypool\.org$", 372)//
CALL CreateService("Flypool Ycash")//
CALL CreateServiceKeyword("(\.|^)ycash\.flypool\.org$", 373)//
CALL CreateService("Flypool Zcash")//
CALL CreateServiceKeyword("(\.|^)asia1-zcash\.flypool\.org$", 374)//
CALL CreateServiceKeyword("(\.|^)eu1-zcash\.flypool\.org$", 374)//
CALL CreateServiceKeyword("(\.|^)us1-zcash\.flypool\.org$", 374)//
CALL CreateServiceKeyword("(\.|^)zcash\.flypool\.org$", 374)//
CALL CreateService("HSBC")//
CALL CreateServiceKeyword("(\.|^)hangseng\.com$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.ca$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.co\.id$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.co\.in$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.co\.mu$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.co\.uk$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.com$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.com\.au$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.com\.bd$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.com\.br$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.com\.cn$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.com\.hk$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.com\.mx$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.com\.my$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.com\.ph$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.com\.sg$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.com\.tw$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.com\.vn$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.fr$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.lk$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.net$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbc\.uk$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbcamanah\.com\.my$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbcbankglobal\.sc\.omtrdc\.net$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbcnet\.com$", 375)//
CALL CreateServiceKeyword("(\.|^)hsbcprivatebank\.com$", 375)//
CALL CreateService("Intuit")//
CALL CreateServiceKeyword("(\.|^)apl-a-prd-263497741\.us-west-2\.elb\.amazonaws\.com$", 376)//
CALL CreateServiceKeyword("(\.|^)h-intuit\.online-metrix\.net$", 376)//
CALL CreateServiceKeyword("(\.|^)intuit\.ca$", 376)//
CALL CreateServiceKeyword("(\.|^)intuit\.com$", 376)//
CALL CreateServiceKeyword("(\.|^)intuit\.com\.ssl\.sc\.omtrdc\.net$", 376)//
CALL CreateServiceKeyword("(\.|^)intuit\.launchdarkly\.com$", 376)//
CALL CreateServiceKeyword("(\.|^)intuitcdn\.net$", 376)//
CALL CreateServiceKeyword("(\.|^)mint\.com$", 376)//
CALL CreateServiceKeyword("(\.|^)sw1prdwebbluealb-144153673\.us-west-2\.elb\.amazonaws\.com$", 376)//
CALL CreateServiceKeyword("(\.|^)sw6prdwebbluealb-1985872400\.us-west-2\.elb\.amazonaws\.com$", 376)//
CALL CreateService("JPMorgan Chase")//
CALL CreateServiceKeyword("(\.|^)chase\.com$", 377)//
CALL CreateServiceKeyword("(\.|^)gslbjpmchase\.com$", 377)//
CALL CreateServiceKeyword("(\.|^)jpmcbankna\.demdex\.net$", 377)//
CALL CreateServiceKeyword("(\.|^)jpmorgan\.com$", 377)//
CALL CreateServiceKeyword("(\.|^)jpmorganchase\.com$", 377)//
CALL CreateServiceKeyword("(\.|^)paymentech\.com$", 377)//
CALL CreateService("Mastercard")//
CALL CreateServiceKeyword("(\.|^)customercare-mastercard\.my\.salesforce\.com$", 378)//
CALL CreateServiceKeyword("(\.|^)mastercard\.ca$", 378)//
CALL CreateServiceKeyword("(\.|^)mastercard\.co\.in$", 378)//
CALL CreateServiceKeyword("(\.|^)mastercard\.com$", 378)//
CALL CreateServiceKeyword("(\.|^)mastercard\.com\.au$", 378)//
CALL CreateServiceKeyword("(\.|^)mastercard\.com\.edgekey\.net$", 378)//
CALL CreateServiceKeyword("(\.|^)mastercard\.com\.ssl\.sc\.omtrdc\.net$", 378)//
CALL CreateServiceKeyword("(\.|^)mastercard\.demdex\.net$", 378)//
CALL CreateServiceKeyword("(\.|^)mastercard\.int$", 378)//
CALL CreateServiceKeyword("(\.|^)mastercard\.us$", 378)//
CALL CreateServiceKeyword("(\.|^)mastercardconnect\.com$", 378)//
CALL CreateService("PayPal")//
CALL CreateServiceKeyword("(\.|^)braintreegateway\.com$", 379)//
CALL CreateServiceKeyword("(\.|^)e29432\.x\.akamaiedge\.net$", 379)//
CALL CreateServiceKeyword("(\.|^)paypal-dynamic-2\.map\.fastly\.net$", 379)//
CALL CreateServiceKeyword("(\.|^)paypal\.ca$", 379)//
CALL CreateServiceKeyword("(\.|^)paypal\.co\.uk$", 379)//
CALL CreateServiceKeyword("(\.|^)paypal\.com$", 379)//
CALL CreateServiceKeyword("(\.|^)paypal\.map\.fastly\.net$", 379)//
CALL CreateServiceKeyword("(\.|^)paypalobjects\.com$", 379)//
CALL CreateService("RBC Royal Bank")//
CALL CreateServiceKeyword("(\.|^)rbc\.com$", 380)//
CALL CreateServiceKeyword("(\.|^)rbc\.online-metrix\.net$", 380)//
CALL CreateServiceKeyword("(\.|^)rbcinsurance\.com$", 380)//
CALL CreateServiceKeyword("(\.|^)rbconlinebanking\.com$", 380)//
CALL CreateServiceKeyword("(\.|^)rbcroyalbank\.com$", 380)//
CALL CreateServiceKeyword("(\.|^)royalbank\.com$", 380)//
CALL CreateService("RBS")//
CALL CreateServiceKeyword("(\.|^)rbs\.co\.uk$", 381)//
CALL CreateService("Receipt Bank")//
CALL CreateServiceKeyword("(\.|^)receipt-bank\.com$", 382)//
CALL CreateService("Robinhood")//
CALL CreateServiceKeyword("(\.|^)robinhood\.com$", 383)//
CALL CreateService("Stripe")//
CALL CreateServiceKeyword("(\.|^)stripe\.com$", 384)//
CALL CreateServiceKeyword("(\.|^)stripe\.network$", 384)//
CALL CreateServiceKeyword("(\.|^)stripecdn\.com$", 384)//
CALL CreateServiceKeyword("(\.|^)stripecdn\.map\.fastly\.net$", 384)//
CALL CreateService("TD")//
CALL CreateServiceKeyword("(\.|^)h-tdcanada\.online-metrix\.net$", 385)//
CALL CreateServiceKeyword("(\.|^)td\.com$", 385)//
CALL CreateServiceKeyword("(\.|^)td\.demdex\.net$", 385)//
CALL CreateServiceKeyword("(\.|^)tdameritrade\.com$", 385)//
CALL CreateServiceKeyword("(\.|^)tdameritrade\.demdex\.net$", 385)//
CALL CreateServiceKeyword("(\.|^)tdassetmanagement\.com$", 385)//
CALL CreateServiceKeyword("(\.|^)tdautofinance\.ca$", 385)//
CALL CreateServiceKeyword("(\.|^)tdbank\.com$", 385)//
CALL CreateServiceKeyword("(\.|^)tdbank\.xyz$", 385)//
CALL CreateServiceKeyword("(\.|^)tdbankfinancialgroup\.tt\.omtrdc\.net$", 385)//
CALL CreateServiceKeyword("(\.|^)tdcanadatrust\.com$", 385)//
CALL CreateServiceKeyword("(\.|^)tdcommercialbanking\.com$", 385)//
CALL CreateServiceKeyword("(\.|^)tdsecurities\.com$", 385)//
CALL CreateServiceKeyword("(\.|^)tdwaterhouse\.ca$", 385)//
CALL CreateServiceKeyword("(\.|^)tdwealthmedia\.com$", 385)//
CALL CreateService("TransUnion")//
CALL CreateServiceKeyword("(\.|^)signal\.co$", 386)//
CALL CreateServiceKeyword("(\.|^)thebrighttag\.com$", 386)//
CALL CreateServiceKeyword("(\.|^)transunion\.com$", 386)//
CALL CreateService("Visa")//
CALL CreateServiceKeyword("(\.|^)h-visa2\.online-metrix\.net$", 387)//
CALL CreateServiceKeyword("(\.|^)visa\.ca$", 387)//
CALL CreateServiceKeyword("(\.|^)visa\.com$", 387)//
CALL CreateServiceKeyword("(\.|^)visa\.com\.akadns\.net$", 387)//
CALL CreateServiceKeyword("(\.|^)visa\.com\.cdn\.cloudflare\.net$", 387)//
CALL CreateService("Wells Fargo")//
CALL CreateServiceKeyword("(\.|^)accesswca\.com$", 388)//
CALL CreateServiceKeyword("(\.|^)sites-wellsfargo\.akadns\.net$", 388)//
CALL CreateServiceKeyword("(\.|^)wellsfargo\.com$", 388)//
CALL CreateServiceKeyword("(\.|^)wellsfargo\.com\.akadns\.net$", 388)//
CALL CreateServiceKeyword("(\.|^)wellsfargo\.net$", 388)//
CALL CreateServiceKeyword("(\.|^)wellsfargobankna\.demdex\.net$", 388)//
CALL CreateServiceKeyword("(\.|^)wellsfargomedia\.com$", 388)//
CALL CreateServiceKeyword("(\.|^)wfhm\.com$", 388)//
CALL CreateServiceKeyword("(\.|^)wfinterface\.com$", 388)//
CALL CreateService("Wolters Kluwer")//
CALL CreateServiceKeyword("(\.|^)prosystemfx\.com$", 389)//
CALL CreateServiceKeyword("(\.|^)secure-dx\.com$", 389)//
CALL CreateServiceKeyword("(\.|^)wolterskluwerfs\.com$", 389)//
CALL CreateService("Xero")//
CALL CreateServiceKeyword("(\.|^)xero\.com$", 390)//
CALL CreateServiceKeyword("(\.|^)xero\.com\.edgekey\.net$", 390)//
CALL CreateServiceKeyword("(\.|^)xerofiles\.com$", 390)//
CALL CreateService("Zillow")//
CALL CreateServiceKeyword("(\.|^)zillow\.com$", 391)//
CALL CreateServiceKeyword("(\.|^)zillow\.net$", 391)//
CALL CreateServiceKeyword("(\.|^)zillowapi\.com$", 391)//
CALL CreateServiceKeyword("(\.|^)zillowstatic\.com$", 391)//
CALL CreateService("4shared")//
CALL CreateServiceKeyword("(\.|^)4shared\.com$", 392)//
CALL CreateServiceKeyword("(\.|^)4sharedapi\.com$", 392)//
CALL CreateService("Apple iCloud")//
CALL CreateServiceKeyword("(\.|^)apple-cloudkit\.com$", 393)//
CALL CreateServiceKeyword("(\.|^)apple-icloud\.cn$", 393)//
CALL CreateServiceKeyword("(\.|^)appleicloud\.cn$", 393)//
CALL CreateServiceKeyword("(\.|^)e4478\.a\.akamaiedge\.net$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud-apple\.cn$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud-content\.com$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.apple$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.ch$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.com$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.com\.akadns\.net$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.com\.cn$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.com\.edgekey\.net$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.de$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.ee$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.fi$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.fr$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.hu$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.ie$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.is$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.jp$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.lv$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.net\.cn$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.om$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.org$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.pt$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.ro$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.se$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.si$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.sk$", 393)//
CALL CreateServiceKeyword("(\.|^)icloud\.vn$", 393)//
CALL CreateService("BitTorrent Apps")//
CALL CreateServiceKeyword("(\.|^)bittorrent\.com$", 394)//
CALL CreateServiceKeyword("(\.|^)bt\.co$", 394)//
CALL CreateServiceKeyword("(\.|^)btfs\.io$", 394)//
CALL CreateService("Box")//
CALL CreateServiceKeyword("(\.|^)box\.com$", 395)//
CALL CreateServiceKeyword("(\.|^)box\.net$", 395)//
CALL CreateServiceKeyword("(\.|^)boxcdn\.net$", 395)//
CALL CreateServiceKeyword("(\.|^)boxcdn\.net\.cdn\.cloudflare\.net$", 395)//
CALL CreateServiceKeyword("(\.|^)boxcdn\.net\.edgekey\.net$", 395)//
CALL CreateServiceKeyword("(\.|^)boxcloud\.com$", 395)//
CALL CreateService("Dropbox")//
CALL CreateServiceKeyword("(\.|^)db\.tt$", 396)//
CALL CreateServiceKeyword("(\.|^)dropbox-dns\.com$", 396)//
CALL CreateServiceKeyword("(\.|^)dropbox\.com$", 396)//
CALL CreateServiceKeyword("(\.|^)dropbox\.tech$", 396)//
CALL CreateServiceKeyword("(\.|^)dropboxapi\.com$", 396)//
CALL CreateServiceKeyword("(\.|^)dropboxbusiness\.com$", 396)//
CALL CreateServiceKeyword("(\.|^)dropboxcaptcha\.com$", 396)//
CALL CreateServiceKeyword("(\.|^)dropboxforum\.com$", 396)//
CALL CreateServiceKeyword("(\.|^)dropboxforums\.com$", 396)//
CALL CreateServiceKeyword("(\.|^)dropboxinsiders\.com$", 396)//
CALL CreateServiceKeyword("(\.|^)dropboxmail\.com$", 396)//
CALL CreateServiceKeyword("(\.|^)dropboxpartners\.com$", 396)//
CALL CreateServiceKeyword("(\.|^)dropboxstatic\.com$", 396)//
CALL CreateServiceKeyword("(\.|^)dropboxstatic\.com\.cdn\.cloudflare\.net$", 396)//
CALL CreateServiceKeyword("(\.|^)dropboxusercontent\.com$", 396)//
CALL CreateServiceKeyword("(\.|^)getdropbox\.com$", 396)//
CALL CreateService("Fastdrive")//
CALL CreateServiceKeyword("(\.|^)fastdrive\.io$", 397)//
CALL CreateServiceKeyword("(\.|^)fastdrive\.link$", 397)//
CALL CreateService("FileFactory")//
CALL CreateServiceKeyword("(\.|^)filefactory\.com$", 398)//
CALL CreateService("Leechers Paradise")//
CALL CreateServiceKeyword("(\.|^)leechers-paradise\.org$", 399)//
CALL CreateService("MediaFire")//
CALL CreateServiceKeyword("(\.|^)mediafire\.com$", 400)//
CALL CreateServiceKeyword("(\.|^)mediafire\.dev$", 400)//
CALL CreateService("Mega")//
CALL CreateServiceKeyword("(\.|^)mega\.co\.nz$", 401)//
CALL CreateServiceKeyword("(\.|^)mega\.io$", 401)//
CALL CreateServiceKeyword("(\.|^)mega\.nz$", 401)//
CALL CreateService("Microsoft OneDrive")//
CALL CreateServiceKeyword("(\.|^)1drv\.com$", 402)//
CALL CreateServiceKeyword("(\.|^)1drv\.ms$", 402)//
CALL CreateServiceKeyword("(\.|^)docs\.live\.net$", 402)//
CALL CreateServiceKeyword("(\.|^)livefilestore\.com$", 402)//
CALL CreateServiceKeyword("(\.|^)onedrive\.akadns\.net$", 402)//
CALL CreateServiceKeyword("(\.|^)onedrive\.com$", 402)//
CALL CreateServiceKeyword("(\.|^)onedrive\.live\.com$", 402)//
CALL CreateServiceKeyword("(\.|^)settings\.live\.net$", 402)//
CALL CreateServiceKeyword("(\.|^)skyapi\.live\.net$", 402)//
CALL CreateServiceKeyword("(\.|^)skyapi\.policies\.live\.net$", 402)//
CALL CreateServiceKeyword("(\.|^)skydrivesync\.policies\.live\.net$", 402)//
CALL CreateServiceKeyword("(\.|^)storage\.live\.com$", 402)//
CALL CreateServiceKeyword("(\.|^)windows\.policies\.live\.net$", 402)//
CALL CreateService("NZB.su")//
CALL CreateServiceKeyword("(\.|^)nzb\.su$", 403)//
CALL CreateService("OpenTrackr")//
CALL CreateServiceKeyword("(\.|^)opentrackr\.org$", 404)//
CALL CreateService("RARBG")//
CALL CreateServiceKeyword("(\.|^)proxyrarbg\.org$", 405)//
CALL CreateServiceKeyword("(\.|^)rarbg\.is$", 405)//
CALL CreateServiceKeyword("(\.|^)rarbg\.me$", 405)//
CALL CreateServiceKeyword("(\.|^)rarbg\.to$", 405)//
CALL CreateServiceKeyword("(\.|^)rarbgaccess\.org$", 405)//
CALL CreateServiceKeyword("(\.|^)rarbggo\.org$", 405)//
CALL CreateServiceKeyword("(\.|^)rarbgmirror\.com$", 405)//
CALL CreateServiceKeyword("(\.|^)rarbgmirror\.org$", 405)//
CALL CreateServiceKeyword("(\.|^)rarbgmirrored\.org$", 405)//
CALL CreateServiceKeyword("(\.|^)rarbgproxy\.org$", 405)//
CALL CreateServiceKeyword("(\.|^)rarbgprx\.org$", 405)//
CALL CreateServiceKeyword("(\.|^)rarbgunblock\.com$", 405)//
CALL CreateService("ShareFile")//
CALL CreateServiceKeyword("(\.|^)sf-api\.com$", 406)//
CALL CreateServiceKeyword("(\.|^)sf-api\.eu$", 406)//
CALL CreateServiceKeyword("(\.|^)sf-cdn\.net$", 406)//
CALL CreateServiceKeyword("(\.|^)sf-event\.com$", 406)//
CALL CreateServiceKeyword("(\.|^)sharefile-webdav\.com$", 406)//
CALL CreateServiceKeyword("(\.|^)sharefile\.com$", 406)//
CALL CreateServiceKeyword("(\.|^)sharefile\.eu$", 406)//
CALL CreateServiceKeyword("(\.|^)sharefileconnect\.com$", 406)//
CALL CreateServiceKeyword("(\.|^)sharefileftp\.com$", 406)//
CALL CreateService("Syncplicity")//
CALL CreateServiceKeyword("(\.|^)syncplicity\.com$", 407)//
CALL CreateService("Syncthing")//
CALL CreateServiceKeyword("(\.|^)syncthing\.net$", 408)//
CALL CreateService("The Pirate Bay")//
CALL CreateServiceKeyword("(\.|^)pirate-bay\.net$", 409)//
CALL CreateServiceKeyword("(\.|^)thepirate-bay\.org$", 409)//
CALL CreateServiceKeyword("(\.|^)thepiratebay\.us\.com$", 409)//
CALL CreateServiceKeyword("(\.|^)thepiratebay\.us\.org$", 409)//
CALL CreateServiceKeyword("(\.|^)thepiratebays3\.com$", 409)//
CALL CreateService("UsenetServer")//
CALL CreateServiceKeyword("(\.|^)usenetserver\.com$", 410)//
CALL CreateService("Xender")//
CALL CreateServiceKeyword("(\.|^)xender\.com$", 411)//
CALL CreateService("Zer0day Tracker")//
CALL CreateServiceKeyword("(\.|^)zer0day\.ch$", 412)//
CALL CreateServiceKeyword("(\.|^)zer0day\.to$", 412)//
CALL CreateService("torrent.eu.org")//
CALL CreateServiceKeyword("(\.|^)torrent\.eu\.org$", 413)//
CALL CreateService("uTorrent")//
CALL CreateServiceKeyword("(\.|^)utorrent\.com$", 414)//
CALL CreateService("2K Gaming")//
CALL CreateServiceKeyword("(\.|^)2k\.com$", 415)//
CALL CreateServiceKeyword("(\.|^)2kcoretech\.online$", 415)//
CALL CreateServiceKeyword("(\.|^)2ksports\.com$", 415)//
CALL CreateService("Activision Blizzard")//
CALL CreateServiceKeyword("(\.|^)activision\.com$", 416)//
CALL CreateServiceKeyword("(\.|^)activisionblizzard\.com$", 416)//
CALL CreateServiceKeyword("(\.|^)callofduty\.com$", 416)//
CALL CreateServiceKeyword("(\.|^)demonware\.net$", 416)//
CALL CreateService("Agar.io")//
CALL CreateServiceKeyword("(\.|^)agar\.io$", 417)//
CALL CreateService("Ark Game")//
CALL CreateServiceKeyword("(\.|^)arkdedicated\.com$", 418)//
CALL CreateServiceKeyword("(\.|^)arkdedicated\.com\.cdn\.cloudflare\.net$", 418)//
CALL CreateServiceKeyword("(\.|^)playark\.com$", 418)//
CALL CreateService("Big Fish Games")//
CALL CreateServiceKeyword("(\.|^)bigfishgames\.com$", 419)//
CALL CreateService("Blizzard")//
CALL CreateServiceKeyword("(\.|^)battle\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)battlenet\.com\.cn$", 420)//
CALL CreateServiceKeyword("(\.|^)blizzard-dl\.vo\.llnwd\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)blizzard\.cn$", 420)//
CALL CreateServiceKeyword("(\.|^)blizzard\.com$", 420)//
CALL CreateServiceKeyword("(\.|^)blizzardgames\.cn$", 420)//
CALL CreateServiceKeyword("(\.|^)blz-contentstack\.com$", 420)//
CALL CreateServiceKeyword("(\.|^)blzddist1-a\.akamaihd\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)blzddistkr1-a\.akamaihd\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)blzmedia-a\.akamaihd\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)blznav\.akamaized\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)blzstatic\.cn$", 420)//
CALL CreateServiceKeyword("(\.|^)bnet\.163\.com$", 420)//
CALL CreateServiceKeyword("(\.|^)bnet\.cn$", 420)//
CALL CreateServiceKeyword("(\.|^)bnetaccount\.akamaized\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)bnetcmsus-a\.akamaihd\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)bneteu-a\.akamaihd\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)bnetkr-a\.akamaihd\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)bnetproduct-a\.akamaihd\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)bnetshopeu\.akamaized\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)bnetshopus\.akamaized\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)bnettw-a\.akamaihd\.net$", 420)//
CALL CreateServiceKeyword("(\.|^)bnetus-a\.akamaihd\.net$", 420)//
CALL CreateService("Bluestacks")//
CALL CreateServiceKeyword("(\.|^)bluestacks\.com$", 421)//
CALL CreateService("CPMStar")//
CALL CreateServiceKeyword("(\.|^)cpmstar\.com$", 422)//
CALL CreateService("Candy Crush")//
CALL CreateServiceKeyword("(\.|^)candycrush4\.king\.com$", 423)//
CALL CreateServiceKeyword("(\.|^)king-candycrush-prod\.secure2\.footprint\.net$", 423)//
CALL CreateService("Clash Royale")//
CALL CreateServiceKeyword("(\.|^)clashroyale\.com$", 424)//
CALL CreateServiceKeyword("(\.|^)clashroyaleapp\.com$", 424)//
CALL CreateService("Clash of Clans")//
CALL CreateServiceKeyword("(\.|^)clashofclans\.com$", 425)//
CALL CreateService("Electronic Arts")//
CALL CreateServiceKeyword("(\.|^)ea\.com$", 426)//
CALL CreateServiceKeyword("(\.|^)eaassets-a\.akamaihd\.net$", 426)//
CALL CreateServiceKeyword("(\.|^)eamobile\.com$", 426)//
CALL CreateServiceKeyword("(\.|^)easports\.com$", 426)//
CALL CreateServiceKeyword("(\.|^)tnt-ea\.com$", 426)//
CALL CreateService("Epic Games")//
CALL CreateServiceKeyword("(\.|^)catalogv2-svc-prod06-pub-772318179\.us-east-1\.elb\.amazonaws\.com$", 427)//
CALL CreateServiceKeyword("(\.|^)epicgames-download1\.akamaized\.net$", 427)//
CALL CreateServiceKeyword("(\.|^)epicgames-pubassets\.akamaized\.net$", 427)//
CALL CreateServiceKeyword("(\.|^)epicgames\.com$", 427)//
CALL CreateServiceKeyword("(\.|^)epicgames\.dev$", 427)//
CALL CreateServiceKeyword("(\.|^)epicgames\.map\.fastly\.net$", 427)//
CALL CreateServiceKeyword("(\.|^)epicgames\.net$", 427)//
CALL CreateServiceKeyword("(\.|^)fortnite-vod\.akamaized\.net$", 427)//
CALL CreateServiceKeyword("(\.|^)unrealengine\.com$", 427)//
CALL CreateService("Forge of Empires")//
CALL CreateServiceKeyword("(\.|^)forgeofempires\.com$", 428)//
CALL CreateService("GOG.com")//
CALL CreateServiceKeyword("(\.|^)gog-statics\.com$", 429)//
CALL CreateServiceKeyword("(\.|^)gog\.com$", 429)//
CALL CreateServiceKeyword("(\.|^)gogalaxy\.com$", 429)//
CALL CreateServiceKeyword("(\.|^)gogcdn\.net$", 429)//
CALL CreateService("Gameloft")//
CALL CreateServiceKeyword("(\.|^)gameloft\.com$", 430)//
CALL CreateService("Hay Day")//
CALL CreateServiceKeyword("(\.|^)haydaygame\.com$", 431)//
CALL CreateService("King Games")//
CALL CreateServiceKeyword("(\.|^)king-contenido-prod\.secure2\.footprint\.net$", 432)//
CALL CreateServiceKeyword("(\.|^)king\.com$", 432)//
CALL CreateServiceKeyword("(\.|^)midasplayer\.com$", 432)//
CALL CreateServiceKeyword("(\.|^)midasplayer\.com\.akamaized\.net$", 432)//
CALL CreateService("Microsoft Games")//
CALL CreateServiceKeyword("(\.|^)microsoftcasualgames\.com$", 433)//
CALL CreateServiceKeyword("(\.|^)msgamestudios\.com$", 433)//
CALL CreateService("Minecraft")//
CALL CreateServiceKeyword("(\.|^)minecraft-services\.net$", 434)//
CALL CreateServiceKeyword("(\.|^)minecraft\.net$", 434)//
CALL CreateServiceKeyword("(\.|^)minecraftprod\.rtep\.msgamestudios\.com$", 434)//
CALL CreateServiceKeyword("(\.|^)minecraftservices\.com$", 434)//
CALL CreateServiceKeyword("(\.|^)mojang\.com$", 434)//
CALL CreateService("Miniclip")//
CALL CreateServiceKeyword("(\.|^)miniclip\.com$", 435)//
CALL CreateService("Mixer")//
CALL CreateServiceKeyword("(\.|^)mixer\.com$", 436)//
CALL CreateService("Niantic")//
CALL CreateServiceKeyword("(\.|^)niantic\.helpshift\.com$", 437)//
CALL CreateServiceKeyword("(\.|^)nianticlabs\.com$", 437)//
CALL CreateServiceKeyword("(\.|^)pokemongolive\.com$", 437)//
CALL CreateService("Nintendo")//
CALL CreateServiceKeyword("(\.|^)nintendo\.com$", 438)//
CALL CreateServiceKeyword("(\.|^)nintendo\.net$", 438)//
CALL CreateServiceKeyword("(\.|^)nintendowifi\.net$", 438)//
CALL CreateService("OP.GG")//
CALL CreateServiceKeyword("(\.|^)op\.gg$", 439)//
CALL CreateServiceKeyword("(\.|^)opgg-gnb\.akamaized\.net$", 439)//
CALL CreateServiceKeyword("(\.|^)opgg-static\.akamaized\.net$", 439)//
CALL CreateService("Origin by EA")//
CALL CreateServiceKeyword("(\.|^)origin\.com$", 440)//
CALL CreateService("Playrix")//
CALL CreateServiceKeyword("(\.|^)playrix\.com$", 441)//
CALL CreateServiceKeyword("(\.|^)playrix\.com\.edgekey\.net$", 441)//
CALL CreateServiceKeyword("(\.|^)playrix\.helpshift\.com$", 441)//
CALL CreateService("Playstation")//
CALL CreateServiceKeyword("(\.|^)playstation\.com$", 442)//
CALL CreateServiceKeyword("(\.|^)playstation\.com\.ssl\.d1\.sc\.omtrdc\.net$", 442)//
CALL CreateServiceKeyword("(\.|^)playstation\.net$", 442)//
CALL CreateServiceKeyword("(\.|^)playstation\.net\.edgekey\.net$", 442)//
CALL CreateServiceKeyword("(\.|^)sonycoment\.loris-e\.llnwd\.net$", 442)//
CALL CreateServiceKeyword("(\.|^)sonyentertainmentnetwork\.com$", 442)//
CALL CreateServiceKeyword("(\.|^)sonyjpnpsg-1\.hs\.llnwd\.net$", 442)//
CALL CreateService("ROBLOX")//
CALL CreateServiceKeyword("(\.|^)rbxcdn\.com$", 443)//
CALL CreateServiceKeyword("(\.|^)rbxtrk\.com$", 443)//
CALL CreateServiceKeyword("(\.|^)roblox\.com$", 443)//
CALL CreateServiceKeyword("(\.|^)roblox\.plus$", 443)//
CALL CreateService("Riot Games")//
CALL CreateServiceKeyword("(\.|^)leagueoflegends\.com$", 444)//
CALL CreateServiceKeyword("(\.|^)riotcdn\.net$", 444)//
CALL CreateServiceKeyword("(\.|^)riotgames\.com$", 444)//
CALL CreateServiceKeyword("(\.|^)riotgames\.com\.cdn\.cloudflare\.net$", 444)//
CALL CreateService("Rockstar Games")//
CALL CreateServiceKeyword("(\.|^)media-rockstargames-com\.akamaized\.net$", 445)//
CALL CreateServiceKeyword("(\.|^)rockstargames\.com$", 445)//
CALL CreateService("Steam")//
CALL CreateServiceKeyword("(\.|^)s\.team$", 446)//
CALL CreateServiceKeyword("(\.|^)steam-chat\.com$", 446)//
CALL CreateServiceKeyword("(\.|^)steambroadcast\.akamaized\.net$", 446)//
CALL CreateServiceKeyword("(\.|^)steamcdn-a\.akamaihd\.net$", 446)//
CALL CreateServiceKeyword("(\.|^)steamchina\.com$", 446)//
CALL CreateServiceKeyword("(\.|^)steamcommunity-a\.akamaihd\.net$", 446)//
CALL CreateServiceKeyword("(\.|^)steamcommunity\.com$", 446)//
CALL CreateServiceKeyword("(\.|^)steamcontent\.com$", 446)//
CALL CreateServiceKeyword("(\.|^)steamgames\.com$", 446)//
CALL CreateServiceKeyword("(\.|^)steampowered\.com$", 446)//
CALL CreateServiceKeyword("(\.|^)steampowered\.com\.8686c\.com$", 446)//
CALL CreateServiceKeyword("(\.|^)steamstatic\.com$", 446)//
CALL CreateServiceKeyword("(\.|^)steamstatic\.com\.8686c\.com$", 446)//
CALL CreateServiceKeyword("(\.|^)steamstore-a\.akamaihd\.net$", 446)//
CALL CreateServiceKeyword("(\.|^)steamusercontent-a\.akamaihd\.net$", 446)//
CALL CreateServiceKeyword("(\.|^)steamusercontent\.com$", 446)//
CALL CreateServiceKeyword("(\.|^)steamuserimages-a\.akamaihd\.net$", 446)//
CALL CreateServiceKeyword("(\.|^)steamvideo-a\.akamaihd\.net$", 446)//
CALL CreateServiceKeyword("(\.|^)valvesoftware\.com$", 446)//
CALL CreateService("Supercell")//
CALL CreateServiceKeyword("(\.|^)supercell\.com$", 447)//
CALL CreateServiceKeyword("(\.|^)supercell\.helpshift\.com$", 447)//
CALL CreateServiceKeyword("(\.|^)supercell\.net$", 447)//
CALL CreateService("Take-Two Interactive")//
CALL CreateServiceKeyword("(\.|^)take2games\.com$", 448)//
CALL CreateServiceKeyword("(\.|^)take2games\.com\.cdn\.cloudflare\.net$", 448)//
CALL CreateService("Ubisoft")//
CALL CreateServiceKeyword("(\.|^)ubi\.com$", 449)//
CALL CreateServiceKeyword("(\.|^)ubisoft-avatars\.akamaized\.net$", 449)//
CALL CreateServiceKeyword("(\.|^)ubisoft-uplay-savegames\.s3\.amazonaws\.com$", 449)//
CALL CreateServiceKeyword("(\.|^)ubisoft\.akadns\.net$", 449)//
CALL CreateServiceKeyword("(\.|^)ubisoft\.com$", 449)//
CALL CreateServiceKeyword("(\.|^)ubisoft\.org$", 449)//
CALL CreateServiceKeyword("(\.|^)ubisoftconnect\.com$", 449)//
CALL CreateService("Unity Games")//
CALL CreateServiceKeyword("(\.|^)unity3d\.com$", 450)//
CALL CreateService("Wargaming")//
CALL CreateServiceKeyword("(\.|^)wargaming\.net$", 451)//
CALL CreateService("Xbox")//
CALL CreateServiceKeyword("(\.|^)xbox\.com$", 452)//
CALL CreateService("Xbox Live")//
CALL CreateServiceKeyword("(\.|^)e87\.dspb\.akamaiedge\.net$", 453)//
CALL CreateServiceKeyword("(\.|^)e87\.dspg\.akamaiedge\.net$", 453)//
CALL CreateServiceKeyword("(\.|^)gamepass\.com$", 453)//
CALL CreateServiceKeyword("(\.|^)xboxab\.com$", 453)//
CALL CreateServiceKeyword("(\.|^)xboxab\.net$", 453)//
CALL CreateServiceKeyword("(\.|^)xboxlive\.com$", 453)//
CALL CreateServiceKeyword("(\.|^)xboxlive\.com\.akadns\.net$", 453)//
CALL CreateServiceKeyword("(\.|^)xboxlive\.com\.c\.footprint\.net$", 453)//
CALL CreateServiceKeyword("(\.|^)xboxlive\.com\.edgekey\.net$", 453)//
CALL CreateServiceKeyword("(\.|^)xboxservices\.com$", 453)//
CALL CreateService("Zynga")//
CALL CreateServiceKeyword("(\.|^)zynga\.com$", 454)//
CALL CreateServiceKeyword("(\.|^)zynga\.com\.edgekey\.net$", 454)//
CALL CreateServiceKeyword("(\.|^)zynga\.my$", 454)//
CALL CreateServiceKeyword("(\.|^)zynga1-a\.akamaihd\.net$", 454)//
CALL CreateServiceKeyword("(\.|^)zynga1-a\.akamaihd\.net\.edgesuite\.net$", 454)//
CALL CreateServiceKeyword("(\.|^)zynga2-a\.akamaihd\.net$", 454)//
CALL CreateServiceKeyword("(\.|^)zynga2-a\.akamaihd\.net\.edgesuite\.net$", 454)//
CALL CreateServiceKeyword("(\.|^)zynga3-a\.akamaihd\.net$", 454)//
CALL CreateServiceKeyword("(\.|^)zynga3-a\.akamaihd\.net\.edgesuite\.net$", 454)//
CALL CreateServiceKeyword("(\.|^)zynga4-a\.akamaihd\.net$", 454)//
CALL CreateServiceKeyword("(\.|^)zynga4-a\.akamaihd\.net\.edgesuite\.net$", 454)//
CALL CreateServiceKeyword("(\.|^)zyngagames\.com$", 454)//
CALL CreateServiceKeyword("(\.|^)zyngapoker\.com$", 454)//
CALL CreateServiceKeyword("(\.|^)zyngasupport\.helpshift\.com$", 454)//
CALL CreateService("Government of Australia")//
CALL CreateServiceKeyword("(\.|^)gov\.au$", 455)//
CALL CreateService("Government of Brazil")//
CALL CreateServiceKeyword("(\.|^)gov\.br$", 456)//
CALL CreateService("Government of Canada")//
CALL CreateServiceKeyword("(\.|^)canada\.ca$", 457)//
CALL CreateServiceKeyword("(\.|^)gc\.ca$", 457)//
CALL CreateService("Homeland Security")//
CALL CreateServiceKeyword("(\.|^)cbp\.gov$", 458)//
CALL CreateServiceKeyword("(\.|^)dhs\.gov$", 458)//
CALL CreateServiceKeyword("(\.|^)e6485\.dsca\.akamaiedge\.net$", 458)//
CALL CreateServiceKeyword("(\.|^)uscis\.gov$", 458)//
CALL CreateService("IRS")//
CALL CreateServiceKeyword("(\.|^)irs\.gov$", 459)//
CALL CreateService("U.S. Military")//
CALL CreateServiceKeyword("(\.|^)defense\.gov$", 460)//
CALL CreateServiceKeyword("(\.|^)mil$", 460)//
CALL CreateService("UK Government")//
CALL CreateServiceKeyword("(\.|^)gov\.uk$", 461)//
CALL CreateServiceKeyword("(\.|^)www-gov-uk\.map\.fastly\.net$", 461)//
CALL CreateService("US GSA")//
CALL CreateServiceKeyword("(\.|^)digital\.gov$", 462)//
CALL CreateServiceKeyword("(\.|^)digitalgov\.gov$", 462)//
CALL CreateServiceKeyword("(\.|^)gsa\.gov$", 462)//
CALL CreateService("USPS")//
CALL CreateServiceKeyword("(\.|^)usps\.com$", 463)//
CALL CreateService("Apple Mail")//
CALL CreateServiceKeyword("(\.|^)me\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)me\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)mr-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)ms-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p10-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p10-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p11-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p11-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p12-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p12-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p13-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p13-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p14-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p14-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p15-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p15-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p16-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p16-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p17-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p17-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p18-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p18-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p19-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p19-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p20-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p20-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p21-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p21-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p22-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p22-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p23-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p23-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p24-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p24-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p25-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p25-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p26-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p26-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p27-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p27-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p28-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p28-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p29-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p29-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p30-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p30-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p31-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p31-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p32-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p32-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p33-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p33-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p34-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p34-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p35-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p35-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p36-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p36-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p37-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p37-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p38-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p38-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p39-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p39-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p40-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p40-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p41-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p41-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p42-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p42-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p43-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p43-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p44-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p44-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p45-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p45-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p46-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p46-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p47-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p47-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p48-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p48-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p49-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p49-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p50-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p50-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p51-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p51-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p52-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p52-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p53-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p53-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p54-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p54-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p55-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p55-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p56-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p56-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p57-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p57-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p58-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p58-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p59-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p59-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p60-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p60-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p61-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p61-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p62-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p62-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p63-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p63-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p64-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p64-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p65-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p65-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p66-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p66-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p67-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p67-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p68-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p68-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p69-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p69-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p70-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p70-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p71-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p71-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)p72-mailws\.icloud\.com$", 464)//
CALL CreateServiceKeyword("(\.|^)p72-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)pv-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateServiceKeyword("(\.|^)st-mailws\.icloud\.com\.akadns\.net$", 464)//
CALL CreateService("GMX")//
CALL CreateServiceKeyword("(\.|^)g-ha-gmx\.net$", 465)//
CALL CreateServiceKeyword("(\.|^)gmx\.com$", 465)//
CALL CreateServiceKeyword("(\.|^)gmx\.net$", 465)//
CALL CreateService("Gmail")//
CALL CreateServiceKeyword("(\.|^)aspmx\.l\.google\.com$", 466)//
CALL CreateServiceKeyword("(\.|^)gm1\.ggpht\.com$", 466)//
CALL CreateServiceKeyword("(\.|^)gmail-smtp-in\.l\.google\.com$", 466)//
CALL CreateServiceKeyword("(\.|^)gmail\.com$", 466)//
CALL CreateServiceKeyword("(\.|^)googlemail\.com$", 466)//
CALL CreateServiceKeyword("(\.|^)googlemail\.l\.google\.com$", 466)//
CALL CreateServiceKeyword("(\.|^)inbox\.google\.com$", 466)//
CALL CreateServiceKeyword("(\.|^)mail\.google\.com$", 466)//
CALL CreateServiceKeyword("(\.|^)mobile-mail\.google\.com$", 466)//
CALL CreateService("Hushmail")//
CALL CreateServiceKeyword("(\.|^)hushmail\.com$", 467)//
CALL CreateService("Microsoft Outlook")//
CALL CreateServiceKeyword("(\.|^)acompli\.net$", 468)//
CALL CreateServiceKeyword("(\.|^)baydin\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)hotmail\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)imap-mail\.outlook\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)mail\.live\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)olsvc\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)outlook-1\.cdn\.office\.net$", 468)//
CALL CreateServiceKeyword("(\.|^)outlook\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)outlook\.com\.edgekey\.net$", 468)//
CALL CreateServiceKeyword("(\.|^)outlook\.ha\.office365\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)outlook\.live\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)outlook\.live\.net$", 468)//
CALL CreateServiceKeyword("(\.|^)outlook\.office365\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)outlookmobile\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)ow1\.res\.office365\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)ow2\.res\.office365\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)r3\.res\.office365\.com$", 468)//
CALL CreateServiceKeyword("(\.|^)r4\.res\.office365\.com$", 468)//
CALL CreateService("ProtonMail")//
CALL CreateServiceKeyword("(\.|^)protonmail\.ch$", 469)//
CALL CreateServiceKeyword("(\.|^)protonmail\.com$", 469)//
CALL CreateService("SendGrid")//
CALL CreateServiceKeyword("(\.|^)sendgrid\.com$", 470)//
CALL CreateServiceKeyword("(\.|^)sendgrid\.net$", 470)//
CALL CreateService("Thunderbird")//
CALL CreateServiceKeyword("(\.|^)thunderbird\.net$", 471)//
CALL CreateService("Yahoo Mail")//
CALL CreateServiceKeyword("(\.|^)imap\.aol\.com$", 472)//
CALL CreateServiceKeyword("(\.|^)mail\.bf2\.yahoo\.com$", 472)//
CALL CreateServiceKeyword("(\.|^)mail\.g03\.yahoodns\.net$", 472)//
CALL CreateServiceKeyword("(\.|^)mail\.gq1\.yahoo\.com$", 472)//
CALL CreateServiceKeyword("(\.|^)mail\.ne1\.yahoo\.com$", 472)//
CALL CreateServiceKeyword("(\.|^)mail\.yahoo\.com$", 472)//
CALL CreateServiceKeyword("(\.|^)mailyahoo\.com$", 472)//
CALL CreateService("Agafurretor Adware")//
CALL CreateServiceKeyword("(\.|^)agafurretor\.com$", 473)//
CALL CreateService("Conduit Toolbar")//
CALL CreateServiceKeyword("(\.|^)conduit-data\.com$", 474)//
CALL CreateServiceKeyword("(\.|^)conduit-services\.com$", 474)//
CALL CreateServiceKeyword("(\.|^)conduit\.com$", 474)//
CALL CreateServiceKeyword("(\.|^)databssint\.com$", 474)//
CALL CreateServiceKeyword("(\.|^)seccint\.com$", 474)//
CALL CreateServiceKeyword("(\.|^)spccint\.com$", 474)//
CALL CreateServiceKeyword("(\.|^)tbccint\.com$", 474)//
CALL CreateService("Apple Push")//
CALL CreateServiceKeyword("(\.|^)courier-push-apple\.com\.akadns\.net$", 475)//
CALL CreateServiceKeyword("(\.|^)courier-sandbox-push-apple\.com\.akadns\.net$", 475)//
CALL CreateServiceKeyword("(\.|^)courier2-push-apple\.com\.akadns\.net$", 475)//
CALL CreateServiceKeyword("(\.|^)push-apple\.com\.akadns\.net$", 475)//
CALL CreateServiceKeyword("(\.|^)push\.apple\.com$", 475)//
CALL CreateService("Discord")//
CALL CreateServiceKeyword("(\.|^)discord\.com$", 476)//
CALL CreateServiceKeyword("(\.|^)discord\.gg$", 476)//
CALL CreateServiceKeyword("(\.|^)discord\.media$", 476)//
CALL CreateServiceKeyword("(\.|^)discordapp\.com$", 476)//
CALL CreateServiceKeyword("(\.|^)discordapp\.net$", 476)//
CALL CreateServiceKeyword("(\.|^)discordstatus\.com$", 476)//
CALL CreateService("Disqus")//
CALL CreateServiceKeyword("(\.|^)disq\.us$", 477)//
CALL CreateServiceKeyword("(\.|^)disqus\.com$", 477)//
CALL CreateServiceKeyword("(\.|^)disqus\.map\.fastlylb\.net$", 477)//
CALL CreateServiceKeyword("(\.|^)disquscdn\.com$", 477)//
CALL CreateServiceKeyword("(\.|^)disquscdn\.com\.cdn\.cloudflare\.net$", 477)//
CALL CreateService("Facebook Messenger")//
CALL CreateServiceKeyword("(\.|^)m\.me$", 478)//
CALL CreateServiceKeyword("(\.|^)messenger\.com$", 478)//
CALL CreateServiceKeyword("(\.|^)msngr\.com$", 478)//
CALL CreateService("Google Chat")//
CALL CreateServiceKeyword("(\.|^)chat\.google\.com$", 479)//
CALL CreateService("ICQ")//
CALL CreateServiceKeyword("(\.|^)icq\.com$", 480)//
CALL CreateServiceKeyword("(\.|^)icq\.net$", 480)//
CALL CreateService("KIK")//
CALL CreateServiceKeyword("(\.|^)kik\.com$", 481)//
CALL CreateService("Kakao Talk")//
CALL CreateServiceKeyword("(\.|^)kakao\.com$", 482)//
CALL CreateService("Pushover")//
CALL CreateServiceKeyword("(\.|^)pushover\.net$", 483)//
CALL CreateService("Rocket.Chat")//
CALL CreateServiceKeyword("(\.|^)rocket\.chat$", 484)//
CALL CreateService("Signal")//
CALL CreateServiceKeyword("(\.|^)signal\.org$", 485)//
CALL CreateServiceKeyword("(\.|^)signal\.org\.cdn\.cloudflare\.net$", 485)//
CALL CreateServiceKeyword("(\.|^)whispersystems\.org$", 485)//
CALL CreateService("Snapchat")//
CALL CreateServiceKeyword("(\.|^)addlive\.io$", 486)//
CALL CreateServiceKeyword("(\.|^)feelinsonice-hrd\.appspot\.com$", 486)//
CALL CreateServiceKeyword("(\.|^)feelinsonice\.appspot\.com$", 486)//
CALL CreateServiceKeyword("(\.|^)feelinsonice\.com$", 486)//
CALL CreateServiceKeyword("(\.|^)impala-external-lb-1441126057\.us-east-1\.elb\.amazonaws\.com$", 486)//
CALL CreateServiceKeyword("(\.|^)sc-analytics\.appspot\.com$", 486)//
CALL CreateServiceKeyword("(\.|^)sc-cdn\.net$", 486)//
CALL CreateServiceKeyword("(\.|^)sc-corp\.net$", 486)//
CALL CreateServiceKeyword("(\.|^)sc-gw\.com$", 486)//
CALL CreateServiceKeyword("(\.|^)sc-jpl\.com$", 486)//
CALL CreateServiceKeyword("(\.|^)sc-prod\.net$", 486)//
CALL CreateServiceKeyword("(\.|^)sc-static\.net$", 486)//
CALL CreateServiceKeyword("(\.|^)snap-dev\.net$", 486)//
CALL CreateServiceKeyword("(\.|^)snapads\.com$", 486)//
CALL CreateServiceKeyword("(\.|^)snapchat\.com$", 486)//
CALL CreateServiceKeyword("(\.|^)snapkit\.com$", 486)//
CALL CreateService("Stream")//
CALL CreateServiceKeyword("(\.|^)getstream\.io$", 487)//
CALL CreateService("Telegram")//
CALL CreateServiceKeyword("(\.|^)t\.me$", 488)//
CALL CreateServiceKeyword("(\.|^)telegram\.org$", 488)//
CALL CreateServiceKeyword("(\.|^)telesco\.pe$", 488)//
CALL CreateService("Tencent QQ")//
CALL CreateServiceKeyword("(\.|^)gtimg\.cn$", 489)//
CALL CreateServiceKeyword("(\.|^)gtimg\.com$", 489)//
CALL CreateServiceKeyword("(\.|^)idqqimg\.com$", 489)//
CALL CreateServiceKeyword("(\.|^)qlogo\.cn$", 489)//
CALL CreateServiceKeyword("(\.|^)qpic\.cn$", 489)//
CALL CreateServiceKeyword("(\.|^)qq\.com$", 489)//
CALL CreateService("WeChat")//
CALL CreateServiceKeyword("(\.|^)wechat\.com$", 490)//
CALL CreateServiceKeyword("(\.|^)weixin\.qq\.com$", 490)//
CALL CreateService("WhatsApp")//
CALL CreateServiceKeyword("(\.|^)wa\.me$", 491)//
CALL CreateServiceKeyword("(\.|^)whatsapp-plus\.info$", 491)//
CALL CreateServiceKeyword("(\.|^)whatsapp-plus\.me$", 491)//
CALL CreateServiceKeyword("(\.|^)whatsapp-plus\.net$", 491)//
CALL CreateServiceKeyword("(\.|^)whatsapp\.cc$", 491)//
CALL CreateServiceKeyword("(\.|^)whatsapp\.com$", 491)//
CALL CreateServiceKeyword("(\.|^)whatsapp\.info$", 491)//
CALL CreateServiceKeyword("(\.|^)whatsapp\.net$", 491)//
CALL CreateServiceKeyword("(\.|^)whatsapp\.org$", 491)//
CALL CreateServiceKeyword("(\.|^)whatsapp\.tv$", 491)//
CALL CreateServiceKeyword("(\.|^)whatsappbrand\.com$", 491)//
CALL CreateService("Zalo")//
CALL CreateServiceKeyword("(\.|^)zadn\.vn$", 492)//
CALL CreateServiceKeyword("(\.|^)zalo\.me$", 492)//
CALL CreateServiceKeyword("(\.|^)zaloapp\.com$", 492)//
CALL CreateService("ABC News")//
CALL CreateServiceKeyword("(\.|^)abcnews\.com$", 493)//
CALL CreateServiceKeyword("(\.|^)abcnews\.edgesuite\.net$", 493)//
CALL CreateServiceKeyword("(\.|^)abcnews\.go\.com$", 493)//
CALL CreateServiceKeyword("(\.|^)abcnewslive-i\.akamaihd\.net$", 493)//
CALL CreateServiceKeyword("(\.|^)abcnewsplayer-a\.akamaihd\.net$", 493)//
CALL CreateServiceKeyword("(\.|^)abcnewsvod-f\.akamaihd\.net$", 493)//
CALL CreateService("AccuWeather")//
CALL CreateServiceKeyword("(\.|^)accu-weather\.com$", 494)//
CALL CreateServiceKeyword("(\.|^)accuweather-com\.videoplayerhub\.com$", 494)//
CALL CreateServiceKeyword("(\.|^)accuweather\.com$", 494)//
CALL CreateServiceKeyword("(\.|^)accuweather\.com\.edgekey\.net$", 494)//
CALL CreateServiceKeyword("(\.|^)e10414\.g\.akamaiedge\.net$", 494)//
CALL CreateService("Axios")//
CALL CreateServiceKeyword("(\.|^)axios\.com$", 495)//
CALL CreateServiceKeyword("(\.|^)axios\.com\.cdn\.cloudflare\.net$", 495)//
CALL CreateService("Bloomberg")//
CALL CreateServiceKeyword("(\.|^)bloomberg\.com$", 496)//
CALL CreateServiceKeyword("(\.|^)bloomberg\.fm$", 496)//
CALL CreateServiceKeyword("(\.|^)bloomberg\.map\.fastly\.net$", 496)//
CALL CreateServiceKeyword("(\.|^)bloomberglaw\.com$", 496)//
CALL CreateServiceKeyword("(\.|^)bloombergmedia\.com$", 496)//
CALL CreateServiceKeyword("(\.|^)bwbx\.io$", 496)//
CALL CreateService("CNBC")//
CALL CreateServiceKeyword("(\.|^)cnbc\.com$", 497)//
CALL CreateServiceKeyword("(\.|^)cnbc\.com\.edgekey\.net$", 497)//
CALL CreateServiceKeyword("(\.|^)www-cnbc-com\.cdn\.ampproject\.org$", 497)//
CALL CreateService("CNN")//
CALL CreateServiceKeyword("(\.|^)amp-cnn-com\.cdn\.ampproject\.org$", 498)//
CALL CreateServiceKeyword("(\.|^)cdn-cnn-com\.cdn\.ampproject\.org$", 498)//
CALL CreateServiceKeyword("(\.|^)cnn\.com$", 498)//
CALL CreateServiceKeyword("(\.|^)cnn\.io$", 498)//
CALL CreateServiceKeyword("(\.|^)cnn\.net$", 498)//
CALL CreateServiceKeyword("(\.|^)cnnios-f\.akamaihd\.net$", 498)//
CALL CreateServiceKeyword("(\.|^)sdc-cnn-com\.cdn\.ampproject\.org$", 498)//
CALL CreateServiceKeyword("(\.|^)www-i-cdn-cnn-com\.cdn\.ampproject\.org$", 498)//
CALL CreateService("Daily Mail")//
CALL CreateServiceKeyword("(\.|^)dailymail\.co\.uk$", 499)//
CALL CreateService("FiveThirtyEight")//
CALL CreateServiceKeyword("(\.|^)fivethirtyeight\.com$", 500)//
CALL CreateService("Forbes")//
CALL CreateServiceKeyword("(\.|^)blogs--images-forbes-com\.cdn\.ampproject\.org$", 501)//
CALL CreateServiceKeyword("(\.|^)forbes\.com$", 501)//
CALL CreateServiceKeyword("(\.|^)forbes\.com\.br$", 501)//
CALL CreateServiceKeyword("(\.|^)forbes\.com\.edgekey\.net$", 501)//
CALL CreateServiceKeyword("(\.|^)forbes\.com\.mx$", 501)//
CALL CreateServiceKeyword("(\.|^)forbesimg\.com$", 501)//
CALL CreateServiceKeyword("(\.|^)thumbor-forbes-com\.cdn\.ampproject\.org$", 501)//
CALL CreateServiceKeyword("(\.|^)www-forbes-com\.cdn\.ampproject\.org$", 501)//
CALL CreateService("NBC News")//
CALL CreateServiceKeyword("(\.|^)nbcnews-lh\.akamaihd\.net$", 502)//
CALL CreateServiceKeyword("(\.|^)nbcnews\.com$", 502)//
CALL CreateServiceKeyword("(\.|^)s-nbcnews\.com$", 502)//
CALL CreateService("RealClearPolitics")//
CALL CreateServiceKeyword("(\.|^)rcp\.evolok\.net$", 503)//
CALL CreateServiceKeyword("(\.|^)realclear\.com$", 503)//
CALL CreateServiceKeyword("(\.|^)realclearpolitics\.com$", 503)//
CALL CreateService("Slashdot")//
CALL CreateServiceKeyword("(\.|^)slashdot\.com$", 504)//
CALL CreateService("The Atlantic")//
CALL CreateServiceKeyword("(\.|^)atlanticmedia\.map\.fastly\.net$", 505)//
CALL CreateServiceKeyword("(\.|^)theatlantic\.com$", 505)//
CALL CreateService("The Globe and Mail")//
CALL CreateServiceKeyword("(\.|^)theglobeandmail\.com$", 506)//
CALL CreateService("The New York Times")//
CALL CreateServiceKeyword("(\.|^)g1-nyt-com\.cdn\.ampproject\.org$", 507)//
CALL CreateServiceKeyword("(\.|^)nyt\.com$", 507)//
CALL CreateServiceKeyword("(\.|^)nytimes\.com$", 507)//
CALL CreateServiceKeyword("(\.|^)nytimes\.map\.fastly\.net$", 507)//
CALL CreateServiceKeyword("(\.|^)static-nytimes-com\.cdn\.ampproject\.org$", 507)//
CALL CreateServiceKeyword("(\.|^)static01-nyt-com\.cdn\.ampproject\.org$", 507)//
CALL CreateServiceKeyword("(\.|^)www-nytimes-com\.cdn\.ampproject\.org$", 507)//
CALL CreateService("The Times of India")//
CALL CreateServiceKeyword("(\.|^)timesofindia\.indiatimes\.com$", 508)//
CALL CreateService("The Weather Channel")//
CALL CreateServiceKeyword("(\.|^)twc\.map\.fastly\.net$", 509)//
CALL CreateServiceKeyword("(\.|^)weather\.com$", 509)//
CALL CreateServiceKeyword("(\.|^)weather\.com\.cn$", 509)//
CALL CreateServiceKeyword("(\.|^)weather\.com\.edgekey\.net$", 509)//
CALL CreateService("The Weather Network")//
CALL CreateServiceKeyword("(\.|^)farmzone\.com$", 510)//
CALL CreateServiceKeyword("(\.|^)meteomedia\.com$", 510)//
CALL CreateServiceKeyword("(\.|^)pelmorex\.com$", 510)//
CALL CreateServiceKeyword("(\.|^)theweathernetwork\.com$", 510)//
CALL CreateServiceKeyword("(\.|^)twnmm\.com$", 510)//
CALL CreateServiceKeyword("(\.|^)wetterplus\.de$", 510)//
CALL CreateService("Thomson Reuters")//
CALL CreateServiceKeyword("(\.|^)reuters\.com$", 511)//
CALL CreateServiceKeyword("(\.|^)thomson\.com$", 511)//
CALL CreateServiceKeyword("(\.|^)thomsonreuters\.com$", 511)//
CALL CreateService("Tronc")//
CALL CreateServiceKeyword("(\.|^)trb\.com$", 512)//
CALL CreateServiceKeyword("(\.|^)tribpub\.com$", 512)//
CALL CreateServiceKeyword("(\.|^)tronc\.com$", 512)//
CALL CreateService("Vice")//
CALL CreateServiceKeyword("(\.|^)images-vice-com\.cdn\.ampproject\.org$", 513)//
CALL CreateServiceKeyword("(\.|^)vice--web--statics--cdn-vice-com\.cdn\.ampproject\.org$", 513)//
CALL CreateServiceKeyword("(\.|^)vice\.com$", 513)//
CALL CreateServiceKeyword("(\.|^)vice\.map\.fastly\.net$", 513)//
CALL CreateServiceKeyword("(\.|^)video--images-vice-com\.cdn\.ampproject\.org$", 513)//
CALL CreateServiceKeyword("(\.|^)www-vice-com\.cdn\.ampproject\.org$", 513)//
CALL CreateService("Vox")//
CALL CreateServiceKeyword("(\.|^)cdn-vox--cdn-com\.cdn\.ampproject\.org$", 514)//
CALL CreateServiceKeyword("(\.|^)vox-cdn\.com$", 514)//
CALL CreateServiceKeyword("(\.|^)vox-chorus\.map\.fastly\.net$", 514)//
CALL CreateServiceKeyword("(\.|^)vox\.com$", 514)//
CALL CreateServiceKeyword("(\.|^)vox\.map\.fastly\.net$", 514)//
CALL CreateServiceKeyword("(\.|^)voxmedia\.com$", 514)//
CALL CreateServiceKeyword("(\.|^)voxops\.net$", 514)//
CALL CreateService("Wall Street Journal")//
CALL CreateServiceKeyword("(\.|^)wsj\.com$", 515)//
CALL CreateServiceKeyword("(\.|^)wsj\.net$", 515)//
CALL CreateService("Washington Post")//
CALL CreateServiceKeyword("(\.|^)i0-wp-com\.cdn\.ampproject\.org$", 516)//
CALL CreateServiceKeyword("(\.|^)i1-wp-com\.cdn\.ampproject\.org$", 516)//
CALL CreateServiceKeyword("(\.|^)i2-wp-com\.cdn\.ampproject\.org$", 516)//
CALL CreateServiceKeyword("(\.|^)i3-wp-com\.cdn\.ampproject\.org$", 516)//
CALL CreateServiceKeyword("(\.|^)s0-wp-com\.cdn\.ampproject\.org$", 516)//
CALL CreateServiceKeyword("(\.|^)s1-wp-com\.cdn\.ampproject\.org$", 516)//
CALL CreateServiceKeyword("(\.|^)s2-wp-com\.cdn\.ampproject\.org$", 516)//
CALL CreateServiceKeyword("(\.|^)washingtonpost\.com$", 516)//
CALL CreateServiceKeyword("(\.|^)wpdigital\.net$", 516)//
CALL CreateService("Weather Underground")//
CALL CreateServiceKeyword("(\.|^)w-x\.co$", 517)//
CALL CreateServiceKeyword("(\.|^)wunderground\.com$", 517)//
CALL CreateServiceKeyword("(\.|^)wxug\.com$", 517)//
CALL CreateService("WeatherFlow")//
CALL CreateServiceKeyword("(\.|^)weatherflow\.com$", 518)//
CALL CreateService("Baidu")//
CALL CreateServiceKeyword("(\.|^)baidu\.com$", 519)//
CALL CreateServiceKeyword("(\.|^)baiducontent\.com$", 519)//
CALL CreateServiceKeyword("(\.|^)baidupcs\.com$", 519)//
CALL CreateServiceKeyword("(\.|^)baidustatic\.com$", 519)//
CALL CreateServiceKeyword("(\.|^)bcebos\.com$", 519)//
CALL CreateServiceKeyword("(\.|^)bdimg\.com$", 519)//
CALL CreateServiceKeyword("(\.|^)bdstatic\.com$", 519)//
CALL CreateServiceKeyword("(\.|^)gshifen\.com$", 519)//
CALL CreateServiceKeyword("(\.|^)popin\.cc$", 519)//
CALL CreateServiceKeyword("(\.|^)shifen\.com$", 519)//
CALL CreateServiceKeyword("(\.|^)wshifen\.com$", 519)//
CALL CreateService("Bing")//
CALL CreateServiceKeyword("(\.|^)api-bing-com\.e-0001\.e-msedge\.net$", 520)//
CALL CreateServiceKeyword("(\.|^)bi\.ng$", 520)//
CALL CreateServiceKeyword("(\.|^)bing\.com$", 520)//
CALL CreateServiceKeyword("(\.|^)bing\.com\.bo$", 520)//
CALL CreateServiceKeyword("(\.|^)bing\.com\.co$", 520)//
CALL CreateServiceKeyword("(\.|^)bing\.com\.cy$", 520)//
CALL CreateServiceKeyword("(\.|^)bing\.com\.gt$", 520)//
CALL CreateServiceKeyword("(\.|^)bing\.jp$", 520)//
CALL CreateServiceKeyword("(\.|^)bing\.net$", 520)//
CALL CreateServiceKeyword("(\.|^)bing\.office\.net$", 520)//
CALL CreateServiceKeyword("(\.|^)bingapis\.com$", 520)//
CALL CreateServiceKeyword("(\.|^)bingforbusiness\.com$", 520)//
CALL CreateServiceKeyword("(\.|^)cortana\.ai$", 520)//
CALL CreateServiceKeyword("(\.|^)windowssearch\.com$", 520)//
CALL CreateService("Daum")//
CALL CreateServiceKeyword("(\.|^)daum\.net$", 521)//
CALL CreateServiceKeyword("(\.|^)daumcdn\.net$", 521)//
CALL CreateService("DuckDuckGo")//
CALL CreateServiceKeyword("(\.|^)duckduckgo\.com$", 522)//
CALL CreateService("Hao123")//
CALL CreateServiceKeyword("(\.|^)hao123\.com$", 523)//
CALL CreateService("IndiaTimes")//
CALL CreateServiceKeyword("(\.|^)indiatimes\.com$", 524)//
CALL CreateServiceKeyword("(\.|^)indiatimes\.in$", 524)//
CALL CreateService("MSN")//
CALL CreateServiceKeyword("(\.|^)api-msn-com\.a-0003\.a-msedge\.net$", 525)//
CALL CreateServiceKeyword("(\.|^)img-s-msn-com\.akamaized\.net$", 525)//
CALL CreateServiceKeyword("(\.|^)msn-com\.akamaized\.net$", 525)//
CALL CreateServiceKeyword("(\.|^)msn\.cn$", 525)//
CALL CreateServiceKeyword("(\.|^)msn\.com$", 525)//
CALL CreateServiceKeyword("(\.|^)msn\.com\.akadns\.net$", 525)//
CALL CreateServiceKeyword("(\.|^)msn\.com\.edgekey\.net$", 525)//
CALL CreateServiceKeyword("(\.|^)msn\.com\.nsatc\.net$", 525)//
CALL CreateServiceKeyword("(\.|^)prod-streaming-video-msn-com\.akamaized\.net$", 525)//
CALL CreateServiceKeyword("(\.|^)s-msn\.com$", 525)//
CALL CreateServiceKeyword("(\.|^)static-entertainment-eus-s-msn-com\.akamaized\.net$", 525)//
CALL CreateServiceKeyword("(\.|^)static-global-s-msn-com\.akamaized\.net$", 525)//
CALL CreateServiceKeyword("(\.|^)static-spartan-eus-s-msn-com\.akamaized\.net$", 525)//
CALL CreateServiceKeyword("(\.|^)static-spartan-neu-s-msn-com\.akamaized\.net$", 525)//
CALL CreateServiceKeyword("(\.|^)static-spartan-wus-s-msn-com\.akamaized\.net$", 525)//
CALL CreateService("Mail.Ru")//
CALL CreateServiceKeyword("(\.|^)mail\.ru$", 526)//
CALL CreateServiceKeyword("(\.|^)mycdn\.me$", 526)//
CALL CreateService("Sina")//
CALL CreateServiceKeyword("(\.|^)sina\.cn$", 527)//
CALL CreateServiceKeyword("(\.|^)sina\.com$", 527)//
CALL CreateServiceKeyword("(\.|^)sina\.com\.cn$", 527)//
CALL CreateServiceKeyword("(\.|^)sinaimg\.cn$", 527)//
CALL CreateService("So 360")//
CALL CreateServiceKeyword("(\.|^)haosou\.com$", 528)//
CALL CreateServiceKeyword("(\.|^)so\.com$", 528)//
CALL CreateService("Sogou")//
CALL CreateServiceKeyword("(\.|^)sogou\.com$", 529)//
CALL CreateServiceKeyword("(\.|^)sogoucdn\.com$", 529)//
CALL CreateService("Sohu")//
CALL CreateServiceKeyword("(\.|^)sohu\.com$", 530)//
CALL CreateServiceKeyword("(\.|^)sohucs\.com$", 530)//
CALL CreateService("TouTiao")//
CALL CreateServiceKeyword("(\.|^)toutiao\.com$", 531)//
CALL CreateServiceKeyword("(\.|^)toutiaocdn\.com$", 531)//
CALL CreateServiceKeyword("(\.|^)toutiaocloud\.com$", 531)//
CALL CreateServiceKeyword("(\.|^)toutiaocloud\.net$", 531)//
CALL CreateServiceKeyword("(\.|^)toutiaohao\.com$", 531)//
CALL CreateServiceKeyword("(\.|^)toutiaohao\.net$", 531)//
CALL CreateServiceKeyword("(\.|^)toutiaoimg\.cn$", 531)//
CALL CreateServiceKeyword("(\.|^)toutiaoimg\.com$", 531)//
CALL CreateServiceKeyword("(\.|^)toutiaoimg\.net$", 531)//
CALL CreateServiceKeyword("(\.|^)toutiaopage\.com$", 531)//
CALL CreateServiceKeyword("(\.|^)toutiaostatic\.com$", 531)//
CALL CreateService("Yahoo")//
CALL CreateServiceKeyword("(\.|^)0-es--us-deportes-yahoo-com-0\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)0-es--us-vida--estilo-yahoo-com-0\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)au-sports-yahoo-com\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)autos-yahoo-com\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)finance-yahoo-com\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)id-berita-yahoo-com\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)m-node-alb-ssl-1113-1405303081\.us-east-1\.elb\.amazonaws\.com$", 532)//
CALL CreateServiceKeyword("(\.|^)m-node-alb-ssl-1213-249754922\.us-west-1\.elb\.amazonaws\.com$", 532)//
CALL CreateServiceKeyword("(\.|^)money-yahoo-com\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)news-yahoo-com\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)sg-news-yahoo-com\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)sports-yahoo-com\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)tw-news-yahoo-com\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)uk-news-yahoo-com\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)uk-style-yahoo-com\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)vop-yahoo\.akamaized\.net$", 532)//
CALL CreateServiceKeyword("(\.|^)vop-yahoo\.secure\.footprint\.net$", 532)//
CALL CreateServiceKeyword("(\.|^)www-yahoo-com\.cdn\.ampproject\.org$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo-inc\.com$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo-net\.jp$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.cm$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.cn$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.co\.id$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.co\.jp$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.co\.kr$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.co\.uk$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.com$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.com\.cn$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.com\.hk$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.com\.sg$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.com\.tw$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.com\.vn$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.fr$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.net$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.tw$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoo\.uservoice\.com$", 532)//
CALL CreateServiceKeyword("(\.|^)yahooapis\.com$", 532)//
CALL CreateServiceKeyword("(\.|^)yahooapis\.jp$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoodns\.net$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoofinance\.com$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoomail\.jp$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoosmallbusiness\.com$", 532)//
CALL CreateServiceKeyword("(\.|^)yahoovod\.hs\.llnwd\.net$", 532)//
CALL CreateServiceKeyword("(\.|^)yimg\.com$", 532)//
CALL CreateService("Air Canada")//
CALL CreateServiceKeyword("(\.|^)aircanada\.com$", 533)//
CALL CreateServiceKeyword("(\.|^)aircanada\.com\.edgekey\.net$", 533)//
CALL CreateServiceKeyword("(\.|^)aircanada\.demdex\.net$", 533)//
CALL CreateServiceKeyword("(\.|^)aircanada\.tt\.omtrdc\.net$", 533)//
CALL CreateService("Airbnb")//
CALL CreateServiceKeyword("(\.|^)airbnb\.ca$", 534)//
CALL CreateServiceKeyword("(\.|^)airbnb\.co\.uk$", 534)//
CALL CreateServiceKeyword("(\.|^)airbnb\.com$", 534)//
CALL CreateServiceKeyword("(\.|^)airbnb\.zendesk\.com$", 534)//
CALL CreateServiceKeyword("(\.|^)airbnbaction\.com$", 534)//
CALL CreateServiceKeyword("(\.|^)airbnbmail\.com$", 534)//
CALL CreateServiceKeyword("(\.|^)muscache\.com$", 534)//
CALL CreateService("American Airlines")//
CALL CreateServiceKeyword("(\.|^)aa\.com$", 535)//
CALL CreateServiceKeyword("(\.|^)aa\.online-metrix\.net$", 535)//
CALL CreateServiceKeyword("(\.|^)americanairlines\.sc\.omtrdc\.net$", 535)//
CALL CreateServiceKeyword("(\.|^)americanairlines\.tt\.omtrdc\.net$", 535)//
CALL CreateService("Booking.com")//
CALL CreateServiceKeyword("(\.|^)booking\.com$", 536)//
CALL CreateServiceKeyword("(\.|^)bstatic\.com$", 536)//
CALL CreateService("Expedia")//
CALL CreateServiceKeyword("(\.|^)expedia\.com$", 537)//
CALL CreateServiceKeyword("(\.|^)expediagroup\.com$", 537)//
CALL CreateServiceKeyword("(\.|^)travel-assets\.com$", 537)//
CALL CreateService("Fitbit")//
CALL CreateServiceKeyword("(\.|^)fitbit\.com$", 538)//
CALL CreateServiceKeyword("(\.|^)fitbit\.com\.cdn\.cloudflare\.net$", 538)//
CALL CreateService("Medium")//
CALL CreateServiceKeyword("(\.|^)medium\.com$", 539)//
CALL CreateService("OpenTable")//
CALL CreateServiceKeyword("(\.|^)bookarestaurant\.com$", 540)//
CALL CreateServiceKeyword("(\.|^)opentable\.ca$", 540)//
CALL CreateServiceKeyword("(\.|^)opentable\.co\.th$", 540)//
CALL CreateServiceKeyword("(\.|^)opentable\.co\.uk$", 540)//
CALL CreateServiceKeyword("(\.|^)opentable\.com$", 540)//
CALL CreateServiceKeyword("(\.|^)opentable\.com\.au$", 540)//
CALL CreateServiceKeyword("(\.|^)opentable\.fr$", 540)//
CALL CreateService("Peloton")//
CALL CreateServiceKeyword("(\.|^)onepeleton\.ca$", 541)//
CALL CreateServiceKeyword("(\.|^)onepeleton\.co\.uk$", 541)//
CALL CreateServiceKeyword("(\.|^)onepeleton\.de$", 541)//
CALL CreateServiceKeyword("(\.|^)onepeloton\.com$", 541)//
CALL CreateServiceKeyword("(\.|^)pelotoncycle\.com$", 541)//
CALL CreateService("SkipTheDishes")//
CALL CreateServiceKeyword("(\.|^)skipthedishes\.com$", 542)//
CALL CreateService("Tim Hortons")//
CALL CreateServiceKeyword("(\.|^)timhortons\.com$", 543)//
CALL CreateService("Tripadvisor")//
CALL CreateServiceKeyword("(\.|^)e10952\.b\.akamaiedge\.net$", 544)//
CALL CreateServiceKeyword("(\.|^)h-tripadvisorcdn\.online-metrix\.net$", 544)//
CALL CreateServiceKeyword("(\.|^)tacdn\.com$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.ar$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.at$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.ca$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.ch$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.cn$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.co$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.co\.hu$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.co\.id$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.co\.il$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.co\.kr$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.co\.nz$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.co\.uk$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.com$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.com\.au$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.com\.br$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.com\.edge\.tacdn\.com$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.com\.edgekey\.net$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.com\.hk$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.com\.my$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.com\.pe$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.com\.ph$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.com\.sg$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.com\.tw$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.com\.vn$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.cz$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.de$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.dk$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.es$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.fi$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.ie$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.in$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.it$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.jp$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.map\.fastly\.net$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.nl$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.rs$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.ru$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.sk$", 544)//
CALL CreateServiceKeyword("(\.|^)tripadvisor\.tr$", 544)//
CALL CreateService("Vrbo")//
CALL CreateServiceKeyword("(\.|^)h-homeaway2\.online-metrix\.net$", 545)//
CALL CreateServiceKeyword("(\.|^)ha-vrbo\.akadns\.net$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway-wildcard\.map\.fastly\.net$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.co\.id$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.co\.kr$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.co\.th$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.co\.uk$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.com$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.com\.au$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.com\.my$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.com\.ph$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.com\.sg$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.es$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.it$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.jp$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.live$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.map\.fastly\.net$", 545)//
CALL CreateServiceKeyword("(\.|^)homeaway\.tw$", 545)//
CALL CreateServiceKeyword("(\.|^)vrbo\.com$", 545)//
CALL CreateServiceKeyword("(\.|^)vrbo\.com\.edgekey\.net$", 545)//
CALL CreateServiceKeyword("(\.|^)vrbo\.io$", 545)//
CALL CreateService("Yelp")//
CALL CreateServiceKeyword("(\.|^)yelp-com\.map\.fastly\.net$", 546)//
CALL CreateServiceKeyword("(\.|^)yelp\.com$", 546)//
CALL CreateServiceKeyword("(\.|^)yelpcdn\.com$", 546)//
CALL CreateService("AutoNavi")//
CALL CreateServiceKeyword("(\.|^)amap\.com$", 547)//
CALL CreateServiceKeyword("(\.|^)autonavi\.com$", 547)//
CALL CreateService("Bing Maps")//
CALL CreateServiceKeyword("(\.|^)maps\.windows\.com$", 548)//
CALL CreateServiceKeyword("(\.|^)virtualearth\.net$", 548)//
CALL CreateServiceKeyword("(\.|^)virtualearth\.net\.edgekey\.net$", 548)//
CALL CreateService("Google Maps")//
CALL CreateServiceKeyword("(\.|^)geo0\.ggpht\.com$", 549)//
CALL CreateServiceKeyword("(\.|^)geo1\.ggpht\.com$", 549)//
CALL CreateServiceKeyword("(\.|^)geo2\.ggpht\.com$", 549)//
CALL CreateServiceKeyword("(\.|^)geo3\.ggpht\.com$", 549)//
CALL CreateServiceKeyword("(\.|^)kh\.google\.com$", 549)//
CALL CreateServiceKeyword("(\.|^)maps\.google\.ca$", 549)//
CALL CreateServiceKeyword("(\.|^)maps\.google\.ch$", 549)//
CALL CreateServiceKeyword("(\.|^)maps\.google\.co\.jp$", 549)//
CALL CreateServiceKeyword("(\.|^)maps\.google\.co\.uk$", 549)//
CALL CreateServiceKeyword("(\.|^)maps\.google\.com$", 549)//
CALL CreateServiceKeyword("(\.|^)maps\.google\.com\.mx$", 549)//
CALL CreateServiceKeyword("(\.|^)maps\.google\.es$", 549)//
CALL CreateServiceKeyword("(\.|^)maps\.google\.se$", 549)//
CALL CreateServiceKeyword("(\.|^)maps\.gstatic\.com$", 549)//
CALL CreateService("IpInfo")//
CALL CreateServiceKeyword("(\.|^)ipecho\.net$", 550)//
CALL CreateServiceKeyword("(\.|^)ipinfo\.io$", 550)//
CALL CreateServiceKeyword("(\.|^)myexternalip\.com$", 550)//
CALL CreateService("Mapbox")//
CALL CreateServiceKeyword("(\.|^)mapbox\.com$", 551)//
CALL CreateService("Moovit")//
CALL CreateServiceKeyword("(\.|^)moovitapp\.com$", 552)//
CALL CreateService("Quora")//
CALL CreateServiceKeyword("(\.|^)quora\.com$", 553)//
CALL CreateServiceKeyword("(\.|^)quora\.map\.fastly\.net$", 553)//
CALL CreateServiceKeyword("(\.|^)quoracdn\.net$", 553)//
CALL CreateService("Stack Overflow")//
CALL CreateServiceKeyword("(\.|^)sstatic\.net$", 554)//
CALL CreateServiceKeyword("(\.|^)stackoverflow\.com$", 554)//
CALL CreateService("StackExchange")//
CALL CreateServiceKeyword("(\.|^)askubuntu\.com$", 555)//
CALL CreateServiceKeyword("(\.|^)serverfault\.com$", 555)//
CALL CreateServiceKeyword("(\.|^)stackauth\.com$", 555)//
CALL CreateServiceKeyword("(\.|^)stackexchange\.com$", 555)//
CALL CreateServiceKeyword("(\.|^)stacksnippets\.net$", 555)//
CALL CreateServiceKeyword("(\.|^)superuser\.com$", 555)//
CALL CreateService("Transit App")//
CALL CreateServiceKeyword("(\.|^)transitapp\.com$", 556)//
CALL CreateService("Waze")//
CALL CreateServiceKeyword("(\.|^)waze\.com$", 557)//
CALL CreateServiceKeyword("(\.|^)wazespeechactiviation-pa\.googleapis\.com$", 557)//
CALL CreateService("Wikipedia")//
CALL CreateServiceKeyword("(\.|^)wikimedia\.org$", 558)//
CALL CreateServiceKeyword("(\.|^)wikimediafoundation\.org$", 558)//
CALL CreateServiceKeyword("(\.|^)wikipedia\.org$", 558)//
CALL CreateService("ipstack")//
CALL CreateServiceKeyword("(\.|^)ipstack\.com$", 559)//
CALL CreateService("AliExpress")//
CALL CreateServiceKeyword("(\.|^)aliexpress\.com$", 560)//
CALL CreateServiceKeyword("(\.|^)aliexpress\.ru$", 560)//
CALL CreateService("Alibaba")//
CALL CreateServiceKeyword("(\.|^)aliapp\.org$", 561)//
CALL CreateServiceKeyword("(\.|^)alibaba\.com$", 561)//
CALL CreateServiceKeyword("(\.|^)alibaba\.com\.gds\.alibabadns\.com$", 561)//
CALL CreateServiceKeyword("(\.|^)alibabacorp\.com$", 561)//
CALL CreateServiceKeyword("(\.|^)alibabacorp\.com\.gds\.alibabadns\.com$", 561)//
CALL CreateServiceKeyword("(\.|^)alicdn\.com$", 561)//
CALL CreateService("AutoTrader")//
CALL CreateServiceKeyword("(\.|^)autohebdo\.net$", 562)//
CALL CreateServiceKeyword("(\.|^)autotrader\.ca$", 562)//
CALL CreateServiceKeyword("(\.|^)trader\.ca$", 562)//
CALL CreateService("Best Buy")//
CALL CreateServiceKeyword("(\.|^)bbystatic\.com$", 563)//
CALL CreateServiceKeyword("(\.|^)bestbuy\.ca$", 563)//
CALL CreateServiceKeyword("(\.|^)bestbuy\.com$", 563)//
CALL CreateServiceKeyword("(\.|^)bestbuy\.com\.edgekey\.net$", 563)//
CALL CreateServiceKeyword("(\.|^)bestbuy\.com\.ssl\.sc\.omtrdc\.net$", 563)//
CALL CreateServiceKeyword("(\.|^)bestbuy\.demdex\.net$", 563)//
CALL CreateServiceKeyword("(\.|^)bestbuycanada\.demdex\.net$", 563)//
CALL CreateServiceKeyword("(\.|^)bestbuycanada\.my\.salesforce\.com$", 563)//
CALL CreateServiceKeyword("(\.|^)bestbuycanada\.tt\.omtrdc\.net$", 563)//
CALL CreateServiceKeyword("(\.|^)bestbuypromotions\.ca$", 563)//
CALL CreateServiceKeyword("(\.|^)h-bestbuy\.online-metrix\.net$", 563)//
CALL CreateService("Canadian Tire")//
CALL CreateServiceKeyword("(\.|^)canadiantire\.ca$", 564)//
CALL CreateServiceKeyword("(\.|^)cantire\.com$", 564)//
CALL CreateServiceKeyword("(\.|^)cantire\.d2\.sc\.omtrdc\.net$", 564)//
CALL CreateServiceKeyword("(\.|^)h-canadiantire\.online-metrix\.net$", 564)//
CALL CreateServiceKeyword("(\.|^)partycity\.ca$", 564)//
CALL CreateService("Costco")//
CALL CreateServiceKeyword("(\.|^)costco-static\.com$", 565)//
CALL CreateServiceKeyword("(\.|^)costco\.ca$", 565)//
CALL CreateServiceKeyword("(\.|^)costco\.co\.uk$", 565)//
CALL CreateServiceKeyword("(\.|^)costco\.com$", 565)//
CALL CreateServiceKeyword("(\.|^)costco\.d2\.sc\.omtrdc\.net$", 565)//
CALL CreateServiceKeyword("(\.|^)costco\.tt\.omtrdc\.net$", 565)//
CALL CreateServiceKeyword("(\.|^)costco\.widget\.custhelp\.com$", 565)//
CALL CreateService("Craigslist")//
CALL CreateServiceKeyword("(\.|^)craigslist\.ca$", 566)//
CALL CreateServiceKeyword("(\.|^)craigslist\.org$", 566)//
CALL CreateService("Etsy")//
CALL CreateServiceKeyword("(\.|^)etsy\.com$", 567)//
CALL CreateServiceKeyword("(\.|^)etsy\.com\.edgekey\.net$", 567)//
CALL CreateServiceKeyword("(\.|^)etsy\.map\.fastly\.net$", 567)//
CALL CreateServiceKeyword("(\.|^)etsy\.me$", 567)//
CALL CreateServiceKeyword("(\.|^)etsystatic\.com$", 567)//
CALL CreateServiceKeyword("(\.|^)etsystatic\.com\.edgekey\.net$", 567)//
CALL CreateService("FlightHub")//
CALL CreateServiceKeyword("(\.|^)flighthub\.com$", 568)//
CALL CreateService("Home Depot")//
CALL CreateServiceKeyword("(\.|^)h-homedepot\.online-metrix\.net$", 569)//
CALL CreateServiceKeyword("(\.|^)homedepot-static\.com$", 569)//
CALL CreateServiceKeyword("(\.|^)homedepot\.ca$", 569)//
CALL CreateServiceKeyword("(\.|^)homedepot\.ca\.ssl\.d2\.sc\.omtrdc\.net$", 569)//
CALL CreateServiceKeyword("(\.|^)homedepot\.com$", 569)//
CALL CreateServiceKeyword("(\.|^)homedepot\.com\.edgekey\.net$", 569)//
CALL CreateServiceKeyword("(\.|^)homedepot\.demdex\.net$", 569)//
CALL CreateServiceKeyword("(\.|^)homedepot\.tt\.omtrdc\.net$", 569)//
CALL CreateService("Honey")//
CALL CreateServiceKeyword("(\.|^)joinhoney\.com$", 570)//
CALL CreateService("IKEA")//
CALL CreateServiceKeyword("(\.|^)d1t9ym6jq29som\.cloudfront\.net$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.ca$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.cn$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.co\.uk$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.com$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.com\.edgekey\.net$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.com\.hk$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.com\.sa$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.com\.tr$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.de$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.es$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.gr$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.it$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.net$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.nl$", 571)//
CALL CreateServiceKeyword("(\.|^)ikea\.us$", 571)//
CALL CreateServiceKeyword("(\.|^)ingka\.com$", 571)//
CALL CreateServiceKeyword("(\.|^)ingka\.dev$", 571)//
CALL CreateServiceKeyword("(\.|^)ingkacentres\.com$", 571)//
CALL CreateService("Jingdong")//
CALL CreateServiceKeyword("(\.|^)jd\.com$", 572)//
CALL CreateService("Kijiji")//
CALL CreateServiceKeyword("(\.|^)h-kijiji\.online-metrix\.net$", 573)//
CALL CreateServiceKeyword("(\.|^)kijiji\.com$", 573)//
CALL CreateService("Kroger")//
CALL CreateServiceKeyword("(\.|^)kroger\.com$", 574)//
CALL CreateServiceKeyword("(\.|^)kroger\.com\.edgekey\.net$", 574)//
CALL CreateServiceKeyword("(\.|^)kroger\.com\.ssl\.sc\.omtrdc\.net$", 574)//
CALL CreateServiceKeyword("(\.|^)kroger\.demdex\.net$", 574)//
CALL CreateServiceKeyword("(\.|^)kroger\.sc\.omtrdc\.net$", 574)//
CALL CreateServiceKeyword("(\.|^)krogermail\.com$", 574)//
CALL CreateService("Purple")//
CALL CreateServiceKeyword("(\.|^)purple\.com$", 575)//
CALL CreateService("Shopee")//
CALL CreateServiceKeyword("(\.|^)deo-shopeemobile-com\.cdn\.ampproject\.org$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.cn$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.co\.id$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.co\.id\.akamaized\.net$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.co\.th$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.co\.th\.akamaized\.net$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.com$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.com\.akamaized\.net$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.com\.br$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.com\.my$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.com\.my\.akamaized\.net$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.io$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.ph$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.ph\.akamaized\.net$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.sg$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.tw$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.vn$", 576)//
CALL CreateServiceKeyword("(\.|^)shopee\.vn\.akamaized\.net$", 576)//
CALL CreateServiceKeyword("(\.|^)shopeemobile\.com$", 576)//
CALL CreateServiceKeyword("(\.|^)shopeemobile\.com\.akamaized\.net$", 576)//
CALL CreateService("Shopify")//
CALL CreateServiceKeyword("(\.|^)cdn-shopify-com\.cdn\.ampproject\.org$", 577)//
CALL CreateServiceKeyword("(\.|^)myshopify\.com$", 577)//
CALL CreateServiceKeyword("(\.|^)shopify\.com$", 577)//
CALL CreateServiceKeyword("(\.|^)shopify\.com-v2\.edgekey\.net$", 577)//
CALL CreateServiceKeyword("(\.|^)shopify\.map\.fastly\.net$", 577)//
CALL CreateServiceKeyword("(\.|^)shopifycdn\.com$", 577)//
CALL CreateServiceKeyword("(\.|^)shopifycloud\.com$", 577)//
CALL CreateServiceKeyword("(\.|^)shopifysvc\.com$", 577)//
CALL CreateService("Taobao")//
CALL CreateServiceKeyword("(\.|^)taobao\.com$", 578)//
CALL CreateServiceKeyword("(\.|^)taobao\.com\.gds\.alibabadns\.com$", 578)//
CALL CreateServiceKeyword("(\.|^)tb\.cn$", 578)//
CALL CreateService("Target")//
CALL CreateServiceKeyword("(\.|^)target-opus\.map\.fastly\.net$", 579)//
CALL CreateServiceKeyword("(\.|^)target\.com$", 579)//
CALL CreateServiceKeyword("(\.|^)target\.scene7\.com$", 579)//
CALL CreateServiceKeyword("(\.|^)targetimg1\.com$", 579)//
CALL CreateService("Ticketmaster")//
CALL CreateServiceKeyword("(\.|^)admission\.com$", 580)//
CALL CreateServiceKeyword("(\.|^)ticketmaster-intl\.map\.fastly\.net$", 580)//
CALL CreateServiceKeyword("(\.|^)ticketmaster\.com$", 580)//
CALL CreateServiceKeyword("(\.|^)ticketmaster\.map\.fastly\.net$", 580)//
CALL CreateServiceKeyword("(\.|^)ticketmaster4\.map\.fastly\.net$", 580)//
CALL CreateServiceKeyword("(\.|^)ticketmaster5\.map\.fastly\.net$", 580)//
CALL CreateServiceKeyword("(\.|^)ticketmaster6\.map\.fastly\.net$", 580)//
CALL CreateServiceKeyword("(\.|^)ticketmaster7\.map\.fastly\.net$", 580)//
CALL CreateServiceKeyword("(\.|^)tmconst\.com$", 580)//
CALL CreateServiceKeyword("(\.|^)tmol\.co$", 580)//
CALL CreateServiceKeyword("(\.|^)tmol\.io$", 580)//
CALL CreateService("Tmall")//
CALL CreateServiceKeyword("(\.|^)tmall\.com$", 581)//
CALL CreateServiceKeyword("(\.|^)tmall\.ru$", 581)//
CALL CreateServiceKeyword("(\.|^)tmall\.ru\.gds\.alibabadns\.com$", 581)//
CALL CreateService("Walmart")//
CALL CreateServiceKeyword("(\.|^)samsclub\.com$", 582)//
CALL CreateServiceKeyword("(\.|^)samsclub\.com\.akadns\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)samsclub\.com\.edgekey\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)samsclub\.com\.ssl\.d1\.sc\.omtrdc\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmart-nosni\.map\.fastly\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmart-wmi\.demdex\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmart\.ca$", 582)//
CALL CreateServiceKeyword("(\.|^)walmart\.ca\.edgekey\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmart\.ca\.ssl\.d1\.sc\.omtrdc\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmart\.com$", 582)//
CALL CreateServiceKeyword("(\.|^)walmart\.com\.akadns\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmart\.com\.edgekey\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmart\.com\.mx$", 582)//
CALL CreateServiceKeyword("(\.|^)walmart\.map\.fastly\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmart\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmartimages\.com$", 582)//
CALL CreateServiceKeyword("(\.|^)walmartimages\.com\.akadns\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmartimages\.com\.cdn\.cloudflare\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmartisd\.demdex\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmartisd\.sc\.omtrdc\.net$", 582)//
CALL CreateServiceKeyword("(\.|^)walmartisd\.tt\.omtrdc\.net$", 582)//
CALL CreateService("Wayfair")//
CALL CreateServiceKeyword("(\.|^)csnstores\.com$", 583)//
CALL CreateServiceKeyword("(\.|^)wayfair\.ca$", 583)//
CALL CreateServiceKeyword("(\.|^)wayfair\.co\.uk$", 583)//
CALL CreateServiceKeyword("(\.|^)wayfair\.com$", 583)//
CALL CreateServiceKeyword("(\.|^)wayfair\.com\.edgekey\.net$", 583)//
CALL CreateServiceKeyword("(\.|^)wayfair\.de$", 583)//
CALL CreateServiceKeyword("(\.|^)wayfair\.io$", 583)//
CALL CreateServiceKeyword("(\.|^)wayfair\.map\.fastly\.net$", 583)//
CALL CreateService("Wish")//
CALL CreateServiceKeyword("(\.|^)wish\.com$", 584)//
CALL CreateService("eBay")//
CALL CreateServiceKeyword("(\.|^)ebay-us\.com$", 585)//
CALL CreateServiceKeyword("(\.|^)ebay\.be$", 585)//
CALL CreateServiceKeyword("(\.|^)ebay\.ca$", 585)//
CALL CreateServiceKeyword("(\.|^)ebay\.co\.jp$", 585)//
CALL CreateServiceKeyword("(\.|^)ebay\.co\.uk$", 585)//
CALL CreateServiceKeyword("(\.|^)ebay\.com$", 585)//
CALL CreateServiceKeyword("(\.|^)ebay\.com\.au$", 585)//
CALL CreateServiceKeyword("(\.|^)ebay\.com\.edgekey\.net$", 585)//
CALL CreateServiceKeyword("(\.|^)ebay\.com\.my$", 585)//
CALL CreateServiceKeyword("(\.|^)ebay\.fr$", 585)//
CALL CreateServiceKeyword("(\.|^)ebay\.map\.fastly\.net$", 585)//
CALL CreateServiceKeyword("(\.|^)ebayadservices\.com$", 585)//
CALL CreateServiceKeyword("(\.|^)ebaycdn\.net$", 585)//
CALL CreateServiceKeyword("(\.|^)ebaydesc\.com$", 585)//
CALL CreateServiceKeyword("(\.|^)ebayimg\.com$", 585)//
CALL CreateServiceKeyword("(\.|^)ebayimg\.map\.fastly\.net$", 585)//
CALL CreateServiceKeyword("(\.|^)ebayinc\.demdex\.net$", 585)//
CALL CreateServiceKeyword("(\.|^)ebayrtm\.com$", 585)//
CALL CreateServiceKeyword("(\.|^)ebaystatic\.com$", 585)//
CALL CreateServiceKeyword("(\.|^)ebaystratus\.com$", 585)//
CALL CreateServiceKeyword("(\.|^)h-ebay\.online-metrix\.net$", 585)//
CALL CreateService("Badoo")//
CALL CreateServiceKeyword("(\.|^)badoo\.com$", 586)//
CALL CreateService("Bitmoji")//
CALL CreateServiceKeyword("(\.|^)bitmoji\.com$", 587)//
CALL CreateService("Douyin")//
CALL CreateServiceKeyword("(\.|^)douyin\.com$", 588)//
CALL CreateServiceKeyword("(\.|^)douyincdn\.com$", 588)//
CALL CreateServiceKeyword("(\.|^)douyinpic\.com$", 588)//
CALL CreateServiceKeyword("(\.|^)douyinstatic\.com$", 588)//
CALL CreateServiceKeyword("(\.|^)douyinvod\.com$", 588)//
CALL CreateServiceKeyword("(\.|^)lf6-douyin-ckv-tos\.pstatp\.com$", 588)//
CALL CreateService("Facebook")//
CALL CreateServiceKeyword("(\.|^)accountkit\.com$", 589)//
CALL CreateServiceKeyword("(\.|^)atdmt\.com$", 589)//
CALL CreateServiceKeyword("(\.|^)atlassolutions\.com$", 589)//
CALL CreateServiceKeyword("(\.|^)facebook\.com$", 589)//
CALL CreateServiceKeyword("(\.|^)facebook\.net$", 589)//
CALL CreateServiceKeyword("(\.|^)facebookmail\.com$", 589)//
CALL CreateServiceKeyword("(\.|^)fb\.com$", 589)//
CALL CreateServiceKeyword("(\.|^)fb\.gg$", 589)//
CALL CreateServiceKeyword("(\.|^)fb\.watch$", 589)//
CALL CreateServiceKeyword("(\.|^)fbcdn\.net$", 589)//
CALL CreateServiceKeyword("(\.|^)fbsbx\.com$", 589)//
CALL CreateServiceKeyword("(\.|^)fbwat\.ch$", 589)//
CALL CreateServiceKeyword("(\.|^)parse\.com$", 589)//
CALL CreateService("Flickr")//
CALL CreateServiceKeyword("(\.|^)flic\.kr$", 590)//
CALL CreateServiceKeyword("(\.|^)flickr\.com$", 590)//
CALL CreateServiceKeyword("(\.|^)flickr\.net$", 590)//
CALL CreateServiceKeyword("(\.|^)flickrprints\.com$", 590)//
CALL CreateServiceKeyword("(\.|^)flickrpro\.com$", 590)//
CALL CreateServiceKeyword("(\.|^)live-staticflickr-com\.cdn\.ampproject\.org$", 590)//
CALL CreateServiceKeyword("(\.|^)staticflickr\.com$", 590)//
CALL CreateService("Gravatar")//
CALL CreateServiceKeyword("(\.|^)gravatar\.com$", 591)//
CALL CreateServiceKeyword("(\.|^)secure-gravatar-com\.cdn\.ampproject\.org$", 591)//
CALL CreateService("Instagram")//
CALL CreateServiceKeyword("(\.|^)cdninstagram\.com$", 592)//
CALL CreateServiceKeyword("(\.|^)instagram\.c10r\.facebook\.com$", 592)//
CALL CreateServiceKeyword("(\.|^)instagram\.com$", 592)//
CALL CreateServiceKeyword("(\.|^)z-p42-instagram\.c10r\.facebook\.com$", 592)//
CALL CreateService("LinkedIn")//
CALL CreateServiceKeyword("(\.|^)bizographics\.com$", 593)//
CALL CreateServiceKeyword("(\.|^)e9706\.dscg\.akamaiedge\.net$", 593)//
CALL CreateServiceKeyword("(\.|^)licdn\.cn$", 593)//
CALL CreateServiceKeyword("(\.|^)licdn\.com$", 593)//
CALL CreateServiceKeyword("(\.|^)linkedin\.at$", 593)//
CALL CreateServiceKeyword("(\.|^)linkedin\.com$", 593)//
CALL CreateServiceKeyword("(\.|^)linkedin\.sc\.omtrdc\.net$", 593)//
CALL CreateService("Musical.ly")//
CALL CreateServiceKeyword("(\.|^)direct\.ly$", 594)//
CALL CreateServiceKeyword("(\.|^)livelycdn\.com$", 594)//
CALL CreateServiceKeyword("(\.|^)zhiliaoapp\.com$", 594)//
CALL CreateService("OkCupid")//
CALL CreateServiceKeyword("(\.|^)okcupid\.com$", 595)//
CALL CreateService("OpenWeb")//
CALL CreateServiceKeyword("(\.|^)94ece80e-kong-kongproxy-066b-501047668\.us-east-1\.elb\.amazonaws\.com$", 596)//
CALL CreateServiceKeyword("(\.|^)infra-events-pipeline-production-1520650058\.us-east-1\.elb\.amazonaws\.com$", 596)//
CALL CreateServiceKeyword("(\.|^)openweb\.com$", 596)//
CALL CreateServiceKeyword("(\.|^)spot\.im$", 596)//
CALL CreateService("Pinterest")//
CALL CreateServiceKeyword("(\.|^)ar-pinterest-com\.cdn\.ampproject\.org$", 597)//
CALL CreateServiceKeyword("(\.|^)br-pinterest-com\.cdn\.ampproject\.org$", 597)//
CALL CreateServiceKeyword("(\.|^)co-pinterest-com\.cdn\.ampproject\.org$", 597)//
CALL CreateServiceKeyword("(\.|^)e6449\.a\.akamaiedge\.net$", 597)//
CALL CreateServiceKeyword("(\.|^)e6449\.dsca\.akamaiedge\.net$", 597)//
CALL CreateServiceKeyword("(\.|^)i-pinimg-com\.cdn\.ampproject\.org$", 597)//
CALL CreateServiceKeyword("(\.|^)id-pinterest-com\.cdn\.ampproject\.org$", 597)//
CALL CreateServiceKeyword("(\.|^)in-pinterest-com\.cdn\.ampproject\.org$", 597)//
CALL CreateServiceKeyword("(\.|^)nl-pinterest-com\.cdn\.ampproject\.org$", 597)//
CALL CreateServiceKeyword("(\.|^)pinimg\.com$", 597)//
CALL CreateServiceKeyword("(\.|^)pinimg\.com\.cdn\.cloudflare\.net$", 597)//
CALL CreateServiceKeyword("(\.|^)pinimg\.com\.edgekey\.net$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.ca$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.cl$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.co\.kr$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.co\.uk$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.com$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.com\.akahost\.net$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.com\.edgekey\.net$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.com\.mx$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.de$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.dk$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.es$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.fr$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.global\.map\.fastly\.net$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.jp$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.map\.fastly\.net$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.nz$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.pt$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.ru$", 597)//
CALL CreateServiceKeyword("(\.|^)pinterest\.se$", 597)//
CALL CreateServiceKeyword("(\.|^)tr-pinterest-com\.cdn\.ampproject\.org$", 597)//
CALL CreateServiceKeyword("(\.|^)www-pinterest-com-mx\.cdn\.ampproject\.org$", 597)//
CALL CreateServiceKeyword("(\.|^)www-pinterest-com\.cdn\.ampproject\.org$", 597)//
CALL CreateService("Reddit")//
CALL CreateServiceKeyword("(\.|^)amp-reddit-com\.cdn\.ampproject\.org$", 598)//
CALL CreateServiceKeyword("(\.|^)external--preview-redd-it\.cdn\.ampproject\.org$", 598)//
CALL CreateServiceKeyword("(\.|^)preview-redd-it\.cdn\.ampproject\.org$", 598)//
CALL CreateServiceKeyword("(\.|^)redd\.it$", 598)//
CALL CreateServiceKeyword("(\.|^)reddit\.com$", 598)//
CALL CreateServiceKeyword("(\.|^)reddit\.map\.fastly\.net$", 598)//
CALL CreateServiceKeyword("(\.|^)redditinc\.com$", 598)//
CALL CreateServiceKeyword("(\.|^)redditmail\.com$", 598)//
CALL CreateServiceKeyword("(\.|^)redditmedia\.com$", 598)//
CALL CreateServiceKeyword("(\.|^)redditstatic\.com$", 598)//
CALL CreateServiceKeyword("(\.|^)redditstatus\.com$", 598)//
CALL CreateServiceKeyword("(\.|^)styles-redditmedia-com\.cdn\.ampproject\.org$", 598)//
CALL CreateServiceKeyword("(\.|^)www-redditstatic-com\.cdn\.ampproject\.org$", 598)//
CALL CreateService("TikTok")//
CALL CreateServiceKeyword("(\.|^)abtest-va-tiktok\.byteoversea\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)isnssdk\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)lf1-ttcdn-tos\.pstatp\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)muscdn\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)musemuse\.cn$", 599)//
CALL CreateServiceKeyword("(\.|^)musical\.ly$", 599)//
CALL CreateServiceKeyword("(\.|^)p1-tt-ipv6\.byteimg\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)p1-tt\.byteimg\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)p16-ad-sg\.ibyteimg\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)p16-tiktok-sg\.ibyteimg\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)p16-tiktok-sign-va-h2\.ibyteimg\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)p16-tiktok-va-h2\.ibyteimg\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)p16-tiktok-va\.ibyteimg\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)p16-tiktokcdn-com\.akamaized\.net$", 599)//
CALL CreateServiceKeyword("(\.|^)p16-va-tiktok\.ibyteimg\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)p26-tt\.byteimg\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)p3-tt-ipv6\.byteimg\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)p9-tt\.byteimg\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)sf1-ttcdn-tos\.pstatp\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)sf16-ttcdn-tos\.ipstatp\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)sf6-ttcdn-tos\.pstatp\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)sgsnssdk\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)tiktok\.bytedance\.map\.fastly\.net$", 599)//
CALL CreateServiceKeyword("(\.|^)tiktok\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)tiktok\.com\.c\.footprint\.net$", 599)//
CALL CreateServiceKeyword("(\.|^)tiktokcdn-in\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)tiktokcdn\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)tiktokcdn\.com\.c\.bytetcdn\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)tiktokcdn\.com\.c\.worldfcdn\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)tiktokcdn\.com\.wsdvs\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)tiktokcdn\.liveplay\.myqcloud\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)tiktokv\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)tiktokv\.com\.akamaized\.net$", 599)//
CALL CreateServiceKeyword("(\.|^)tiktokv\.com\.edgekey\.net$", 599)//
CALL CreateServiceKeyword("(\.|^)ttlivecdn\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)ttlivecdn\.com\.akamaized\.net$", 599)//
CALL CreateServiceKeyword("(\.|^)ttlivecdn\.com\.c\.worldfcdn\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)ttlivecdn\.com\.wsdvs\.com$", 599)//
CALL CreateServiceKeyword("(\.|^)ttoversea\.net$", 599)//
CALL CreateService("Tinder")//
CALL CreateServiceKeyword("(\.|^)gotinder\.com$", 600)//
CALL CreateServiceKeyword("(\.|^)tinder\.com$", 600)//
CALL CreateServiceKeyword("(\.|^)tindersparks\.com$", 600)//
CALL CreateService("Tuenti")//
CALL CreateServiceKeyword("(\.|^)tuenti\.com$", 601)//
CALL CreateService("Twitter")//
CALL CreateServiceKeyword("(\.|^)ads-twitter\.com$", 602)//
CALL CreateServiceKeyword("(\.|^)periscope\.tv$", 602)//
CALL CreateServiceKeyword("(\.|^)pscp\.tv$", 602)//
CALL CreateServiceKeyword("(\.|^)t\.co$", 602)//
CALL CreateServiceKeyword("(\.|^)tweetdeck\.com$", 602)//
CALL CreateServiceKeyword("(\.|^)twimg\.akadns\.net$", 602)//
CALL CreateServiceKeyword("(\.|^)twimg\.com$", 602)//
CALL CreateServiceKeyword("(\.|^)twimg\.com\.akahost\.net$", 602)//
CALL CreateServiceKeyword("(\.|^)twitpic\.com$", 602)//
CALL CreateServiceKeyword("(\.|^)twitter\.com$", 602)//
CALL CreateServiceKeyword("(\.|^)twitter\.map\.fastly\.net$", 602)//
CALL CreateServiceKeyword("(\.|^)twitterinc\.com$", 602)//
CALL CreateServiceKeyword("(\.|^)twitteroauth\.com$", 602)//
CALL CreateServiceKeyword("(\.|^)twitterstat\.us$", 602)//
CALL CreateServiceKeyword("(\.|^)twttr\.com$", 602)//
CALL CreateService("VK")//
CALL CreateServiceKeyword("(\.|^)userapi\.com$", 603)//
CALL CreateServiceKeyword("(\.|^)vk-portal\.net$", 603)//
CALL CreateServiceKeyword("(\.|^)vk\.com$", 603)//
CALL CreateServiceKeyword("(\.|^)vkuser\.net$", 603)//
CALL CreateServiceKeyword("(\.|^)vkuseraudio\.net$", 603)//
CALL CreateServiceKeyword("(\.|^)vkuservideo\.net$", 603)//
CALL CreateService("Weibo")//
CALL CreateServiceKeyword("(\.|^)weibo\.cn$", 604)//
CALL CreateServiceKeyword("(\.|^)weibo\.com$", 604)//
CALL CreateServiceKeyword("(\.|^)weibocdn\.com$", 604)//
CALL CreateService("DAZN")//
CALL CreateServiceKeyword("(\.|^)dazn\.com$", 605)//
CALL CreateServiceKeyword("(\.|^)daznfeeds\.com$", 605)//
CALL CreateServiceKeyword("(\.|^)daznservices\.com$", 605)//
CALL CreateServiceKeyword("(\.|^)eplayer2sp-vh\.akamaihd\.net$", 605)//
CALL CreateService("ESPN")//
CALL CreateServiceKeyword("(\.|^)a-espncdn-com\.cdn\.ampproject\.org$", 606)//
CALL CreateServiceKeyword("(\.|^)a1-espncdn-com\.cdn\.ampproject\.org$", 606)//
CALL CreateServiceKeyword("(\.|^)a2-espncdn-com\.cdn\.ampproject\.org$", 606)//
CALL CreateServiceKeyword("(\.|^)a3-espncdn-com\.cdn\.ampproject\.org$", 606)//
CALL CreateServiceKeyword("(\.|^)a4-espncdn-com\.cdn\.ampproject\.org$", 606)//
CALL CreateServiceKeyword("(\.|^)es\.pn$", 606)//
CALL CreateServiceKeyword("(\.|^)espn\.com$", 606)//
CALL CreateServiceKeyword("(\.|^)espn\.com\.ssl\.sc\.omtrdc\.net$", 606)//
CALL CreateServiceKeyword("(\.|^)espn\.hb\.omtrdc\.net$", 606)//
CALL CreateServiceKeyword("(\.|^)espn\.net$", 606)//
CALL CreateServiceKeyword("(\.|^)espncdn\.com$", 606)//
CALL CreateServiceKeyword("(\.|^)espncdn\.com\.edgesuite\.net$", 606)//
CALL CreateServiceKeyword("(\.|^)espncricinfo\.com$", 606)//
CALL CreateServiceKeyword("(\.|^)espndotcom\.tt\.omtrdc\.net$", 606)//
CALL CreateServiceKeyword("(\.|^)www-espn-com-br\.cdn\.ampproject\.org$", 606)//
CALL CreateServiceKeyword("(\.|^)www-espn-com\.cdn\.ampproject\.org$", 606)//
CALL CreateService("FIFA")//
CALL CreateServiceKeyword("(\.|^)fifa\.com$", 607)//
CALL CreateServiceKeyword("(\.|^)fifa\.com\.edgekey\.net$", 607)//
CALL CreateServiceKeyword("(\.|^)fifa\.com\.ssl\.d2\.sc\.omtrdc\.net$", 607)//
CALL CreateServiceKeyword("(\.|^)img-fifa-com\.cdn\.ampproject\.org$", 607)//
CALL CreateServiceKeyword("(\.|^)www-fifa-com\.cdn\.ampproject\.org$", 607)//
CALL CreateService("FotMob")//
CALL CreateServiceKeyword("(\.|^)fotmob\.com$", 608)//
CALL CreateService("MLB")//
CALL CreateServiceKeyword("(\.|^)img-mlbstatic-com\.cdn\.ampproject\.org$", 609)//
CALL CreateServiceKeyword("(\.|^)mlb\.com$", 609)//
CALL CreateServiceKeyword("(\.|^)mlb\.demdex\.net$", 609)//
CALL CreateServiceKeyword("(\.|^)mlb\.map\.fastly\.net$", 609)//
CALL CreateServiceKeyword("(\.|^)mlb\.sc\.omtrdc\.net$", 609)//
CALL CreateServiceKeyword("(\.|^)mlbadvancedmedialp\.tt\.omtrdc\.net$", 609)//
CALL CreateServiceKeyword("(\.|^)mlbstatic\.com$", 609)//
CALL CreateServiceKeyword("(\.|^)mlbstatic\.com\.cdn\.cloudflare\.net$", 609)//
CALL CreateServiceKeyword("(\.|^)mlbstatic\.com\.edgekey\.net$", 609)//
CALL CreateServiceKeyword("(\.|^)www-mlbstatic-com\.cdn\.ampproject\.org$", 609)//
CALL CreateService("NBA")//
CALL CreateServiceKeyword("(\.|^)nba\.com$", 610)//
CALL CreateServiceKeyword("(\.|^)nba\.com-v1\.edgekey\.net$", 610)//
CALL CreateServiceKeyword("(\.|^)nba\.com\.edgekey\.net$", 610)//
CALL CreateServiceKeyword("(\.|^)nba\.com\.ssl\.sc\.omtrdc\.net$", 610)//
CALL CreateServiceKeyword("(\.|^)nba\.demdex\.net$", 610)//
CALL CreateServiceKeyword("(\.|^)nbaprop\.tt\.omtrdc\.net$", 610)//
CALL CreateService("NFL")//
CALL CreateServiceKeyword("(\.|^)nfl\.com$", 611)//
CALL CreateServiceKeyword("(\.|^)nfl\.demdex\.net$", 611)//
CALL CreateServiceKeyword("(\.|^)nfl\.map\.fastly\.net$", 611)//
CALL CreateServiceKeyword("(\.|^)nflenterprises\.tt\.omtrdc\.net$", 611)//
CALL CreateService("NHL")//
CALL CreateServiceKeyword("(\.|^)nhl\.bamcontent\.com$", 612)//
CALL CreateServiceKeyword("(\.|^)nhl\.bamgrid\.com$", 612)//
CALL CreateServiceKeyword("(\.|^)nhl\.com$", 612)//
CALL CreateServiceKeyword("(\.|^)nhlstatic\.com$", 612)//
CALL CreateService("Sporting News")//
CALL CreateServiceKeyword("(\.|^)snimg\.com$", 613)//
CALL CreateServiceKeyword("(\.|^)sportingnews\.com$", 613)//
CALL CreateServiceKeyword("(\.|^)sportingnews\.com\.edgekey\.net$", 613)//
CALL CreateServiceKeyword("(\.|^)www-sportingnews-com\.cdn\.ampproject\.org$", 613)//
CALL CreateService("TeamSnap")//
CALL CreateServiceKeyword("(\.|^)teamsnap\.com$", 614)//
CALL CreateService("theScore")//
CALL CreateServiceKeyword("(\.|^)thescore\.com$", 615)//
CALL CreateServiceKeyword("(\.|^)thescore\.com\.cdn\.cloudflare\.net$", 615)//
CALL CreateService("AFRINIC")//
CALL CreateServiceKeyword("(\.|^)afrinic\.net$", 616)//
CALL CreateService("APNIC")//
CALL CreateServiceKeyword("(\.|^)apnic\.net$", 617)//
CALL CreateService("ARIN")//
CALL CreateServiceKeyword("(\.|^)arin\.net$", 618)//
CALL CreateService("Atlassian")//
CALL CreateServiceKeyword("(\.|^)atlassian\.com$", 619)//
CALL CreateServiceKeyword("(\.|^)atlassian\.net$", 619)//
CALL CreateServiceKeyword("(\.|^)bitbucket\.org$", 619)//
CALL CreateService("Bootstrap")//
CALL CreateServiceKeyword("(\.|^)bootstrapcdn\.com$", 620)//
CALL CreateServiceKeyword("(\.|^)getbootstrap\.com$", 620)//
CALL CreateService("ChangeIP")//
CALL CreateServiceKeyword("(\.|^)changeip\.com$", 621)//
CALL CreateService("Cloudflare DNS")//
CALL CreateServiceKeyword("(\.|^)cloudflare-dns\.com$", 622)//
CALL CreateService("DataTables")//
CALL CreateServiceKeyword("(\.|^)datatables\.net$", 623)//
CALL CreateService("Duck DNS")//
CALL CreateServiceKeyword("(\.|^)duckdns\.org$", 624)//
CALL CreateService("Dyn")//
CALL CreateServiceKeyword("(\.|^)dyn\.com$", 625)//
CALL CreateServiceKeyword("(\.|^)dyndns\.org$", 625)//
CALL CreateServiceKeyword("(\.|^)homeip\.net$", 625)//
CALL CreateService("Fast")//
CALL CreateServiceKeyword("(\.|^)fast\.com$", 626)//
CALL CreateService("Font Awesome")//
CALL CreateServiceKeyword("(\.|^)fontawesome\.com$", 627)//
CALL CreateServiceKeyword("(\.|^)fontawesome\.com\.cdn\.cloudflare\.net$", 627)//
CALL CreateServiceKeyword("(\.|^)use-fontawesome-com\.cdn\.ampproject\.org$", 627)//
CALL CreateService("GSMA")//
CALL CreateServiceKeyword("(\.|^)3gppnetwork\.org$", 628)//
CALL CreateServiceKeyword("(\.|^)gsma\.com$", 628)//
CALL CreateService("GitHub")//
CALL CreateServiceKeyword("(\.|^)ghcr\.io$", 629)//
CALL CreateServiceKeyword("(\.|^)github\.com$", 629)//
CALL CreateServiceKeyword("(\.|^)github\.io$", 629)//
CALL CreateServiceKeyword("(\.|^)github\.map\.fastly\.net$", 629)//
CALL CreateServiceKeyword("(\.|^)githubapp\.com$", 629)//
CALL CreateServiceKeyword("(\.|^)githubassets\.com$", 629)//
CALL CreateServiceKeyword("(\.|^)githubusercontent\.com$", 629)//
CALL CreateService("GitLab")//
CALL CreateServiceKeyword("(\.|^)gitlab-static\.net$", 630)//
CALL CreateServiceKeyword("(\.|^)gitlab\.com$", 630)//
CALL CreateServiceKeyword("(\.|^)gitlab\.io$", 630)//
CALL CreateServiceKeyword("(\.|^)gitlab\.net$", 630)//
CALL CreateService("Google DNS")//
CALL CreateServiceKeyword("(\.|^)dns\.google$", 631)//
CALL CreateServiceKeyword("(\.|^)dns\.google\.com$", 631)//
CALL CreateServiceKeyword("(\.|^)google-public-dns-a\.google\.com$", 631)//
CALL CreateServiceKeyword("(\.|^)google-public-dns-b\.google\.com$", 631)//
CALL CreateService("IANA Blackhole")//
CALL CreateServiceKeyword("(\.|^)blackhole-1\.iana\.org$", 632)//
CALL CreateServiceKeyword("(\.|^)blackhole-2\.iana\.org$", 632)//
CALL CreateServiceKeyword("(\.|^)prisoner\.iana\.org$", 632)//
CALL CreateService("LACNIC")//
CALL CreateServiceKeyword("(\.|^)lacnic\.net$", 633)//
CALL CreateService("Let's Encrypt")//
CALL CreateServiceKeyword("(\.|^)lencr\.edgesuite\.net$", 634)//
CALL CreateServiceKeyword("(\.|^)lencr\.org$", 634)//
CALL CreateServiceKeyword("(\.|^)letsencrypt\.org$", 634)//
CALL CreateServiceKeyword("(\.|^)letsencrypt\.org\.edgekey\.net$", 634)//
CALL CreateService("NIST")//
CALL CreateServiceKeyword("(\.|^)nist\.gov$", 635)//
CALL CreateService("NTP Project")//
CALL CreateServiceKeyword("(\.|^)ntp\.org$", 636)//
CALL CreateServiceKeyword("(\.|^)ntp\.org\.cn$", 636)//
CALL CreateServiceKeyword("(\.|^)pool\.ntp\.org$", 636)//
CALL CreateService("Netify")//
CALL CreateServiceKeyword("(\.|^)netify\.ai$", 637)//
CALL CreateServiceKeyword("(\.|^)netify\.user\.com$", 637)//
CALL CreateServiceKeyword("(\.|^)v1-netify-api\.egloo\.ca$", 637)//
CALL CreateServiceKeyword("(\.|^)v1-netify-sink\.egloo\.ca$", 637)//
CALL CreateServiceKeyword("(\.|^)v2-netify-api\.egloo\.ca$", 637)//
CALL CreateServiceKeyword("(\.|^)v2-netify-sink\.egloo\.ca$", 637)//
CALL CreateService("No-IP")//
CALL CreateServiceKeyword("(\.|^)3utilities\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)access\.ly$", 638)//
CALL CreateServiceKeyword("(\.|^)blogsyte\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)bounceme\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)brasilia\.me$", 638)//
CALL CreateServiceKeyword("(\.|^)cable-modem\.org$", 638)//
CALL CreateServiceKeyword("(\.|^)ciscofreak\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)collegefan\.org$", 638)//
CALL CreateServiceKeyword("(\.|^)couchpotatofries\.org$", 638)//
CALL CreateServiceKeyword("(\.|^)damnserver\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)ddns\.me$", 638)//
CALL CreateServiceKeyword("(\.|^)ddns\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)ddnsking\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)ditchyourip\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)dnsfor\.me$", 638)//
CALL CreateServiceKeyword("(\.|^)dnsiskinky\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)dvrcam\.info$", 638)//
CALL CreateServiceKeyword("(\.|^)dynns\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)eating-organic\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)fantasyleague\.cc$", 638)//
CALL CreateServiceKeyword("(\.|^)freedynamicdns\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)freedynamicdns\.org$", 638)//
CALL CreateServiceKeyword("(\.|^)geekgalaxy\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)golffan\.us$", 638)//
CALL CreateServiceKeyword("(\.|^)gotdns\.ch$", 638)//
CALL CreateServiceKeyword("(\.|^)health-carereform\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)homesecuritymac\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)homesecuritypc\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)hopto\.me$", 638)//
CALL CreateServiceKeyword("(\.|^)hopto\.org$", 638)//
CALL CreateServiceKeyword("(\.|^)hosthampster\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)ilovecollege\.info$", 638)//
CALL CreateServiceKeyword("(\.|^)loginto\.me$", 638)//
CALL CreateServiceKeyword("(\.|^)mlbfan\.org$", 638)//
CALL CreateServiceKeyword("(\.|^)mmafan\.biz$", 638)//
CALL CreateServiceKeyword("(\.|^)myactivedirectory\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)myddns\.me$", 638)//
CALL CreateServiceKeyword("(\.|^)mydissent\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)myeffect\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)myftp\.biz$", 638)//
CALL CreateServiceKeyword("(\.|^)myftp\.org$", 638)//
CALL CreateServiceKeyword("(\.|^)mymediapc\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)mypsx\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)mysecuritycamera\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)mysecuritycamera\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)mysecuritycamera\.org$", 638)//
CALL CreateServiceKeyword("(\.|^)myvnc\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)net-freaks\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)nflfan\.org$", 638)//
CALL CreateServiceKeyword("(\.|^)nhlfan\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)no-ip\.biz$", 638)//
CALL CreateServiceKeyword("(\.|^)no-ip\.ca$", 638)//
CALL CreateServiceKeyword("(\.|^)no-ip\.co\.uk$", 638)//
CALL CreateServiceKeyword("(\.|^)no-ip\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)no-ip\.info$", 638)//
CALL CreateServiceKeyword("(\.|^)no-ip\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)no-ip\.org$", 638)//
CALL CreateServiceKeyword("(\.|^)noip\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)onthewifi\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)pgafan\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)point2this\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)pointto\.us$", 638)//
CALL CreateServiceKeyword("(\.|^)privatizehealthinsurance\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)quicksytes\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)read-books\.org$", 638)//
CALL CreateServiceKeyword("(\.|^)redirectme\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)securitytactics\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)servebeer\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)serveblog\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)servecounterstrike\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)serveexchange\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)serveftp\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)servegame\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)servehalflife\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)servehttp\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)servehumour\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)serveirc\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)serveminecraft\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)servemp3\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)servep2p\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)servepics\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)servequake\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)servesarcasm\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)stufftoread\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)sytes\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)ufcfan\.org$", 638)//
CALL CreateServiceKeyword("(\.|^)unusualperson\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)viewdns\.net$", 638)//
CALL CreateServiceKeyword("(\.|^)webhop\.me$", 638)//
CALL CreateServiceKeyword("(\.|^)workisboring\.com$", 638)//
CALL CreateServiceKeyword("(\.|^)zapto\.org$", 638)//
CALL CreateService("Node.js")//
CALL CreateServiceKeyword("(\.|^)nodejs\.org$", 639)//
CALL CreateService("Number Resource Organization")//
CALL CreateServiceKeyword("(\.|^)nro\.net$", 640)//
CALL CreateService("RADb")//
CALL CreateServiceKeyword("(\.|^)radb\.net$", 641)//
CALL CreateService("RIPE")//
CALL CreateServiceKeyword("(\.|^)ripe\.net$", 642)//
CALL CreateService("Root Servers")//
CALL CreateServiceKeyword("(\.|^)root-servers\.net$", 643)//
CALL CreateServiceKeyword("(\.|^)root-servers\.org$", 643)//
CALL CreateService("Speedtest by Ookla")//
CALL CreateServiceKeyword("(\.|^)cdnst\.net$", 644)//
CALL CreateServiceKeyword("(\.|^)ooklaserver\.net$", 644)//
CALL CreateServiceKeyword("(\.|^)speedtest\.net$", 644)//
CALL CreateServiceKeyword("(\.|^)zd\.map\.fastly\.net$", 644)//
CALL CreateService("Traefik")//
CALL CreateServiceKeyword("(\.|^)traefik\.io$", 645)//
CALL CreateService("gTLD")//
CALL CreateServiceKeyword("(\.|^)gtld-servers\.net$", 646)//
CALL CreateService("jQuery")//
CALL CreateServiceKeyword("(\.|^)cdnjquery\.com$", 647)//
CALL CreateServiceKeyword("(\.|^)jquery\.com$", 647)//
CALL CreateServiceKeyword("(\.|^)jquery\.org$", 647)//
CALL CreateService("CyberGhost VPN")//
CALL CreateServiceKeyword("(\.|^)cyberghostvpn\.com$", 648)//
CALL CreateService("ExpressVPN")//
CALL CreateServiceKeyword("(\.|^)expressapisv2\.net$", 649)//
CALL CreateServiceKeyword("(\.|^)expressvpn\.com$", 649)//
CALL CreateServiceKeyword("(\.|^)mb6gpu84\.com$", 649)//
CALL CreateService("Hide.me VPN")//
CALL CreateServiceKeyword("(\.|^)hide\.me$", 650)//
CALL CreateService("Hola VPN")//
CALL CreateServiceKeyword("(\.|^)hola\.org$", 651)//
CALL CreateService("Hotspot Shield")//
CALL CreateServiceKeyword("(\.|^)anchorfree\.com$", 652)//
CALL CreateServiceKeyword("(\.|^)hotspotshield\.com$", 652)//
CALL CreateServiceKeyword("(\.|^)hsselite\.com$", 652)//
CALL CreateService("NordVPN")//
CALL CreateServiceKeyword("(\.|^)ndaccount\.com$", 653)//
CALL CreateServiceKeyword("(\.|^)nord-apps\.com$", 653)//
CALL CreateServiceKeyword("(\.|^)nordaccount\.com$", 653)//
CALL CreateServiceKeyword("(\.|^)nordcdn\.com$", 653)//
CALL CreateServiceKeyword("(\.|^)nordpass\.com$", 653)//
CALL CreateServiceKeyword("(\.|^)nordvpn\.com$", 653)//
CALL CreateServiceKeyword("(\.|^)nordvpn\.net$", 653)//
CALL CreateServiceKeyword("(\.|^)nordvpnteams\.com$", 653)//
CALL CreateServiceKeyword("(\.|^)zwyr157wwiu6eior\.com$", 653)//
CALL CreateService("SoftEther VPN")//
CALL CreateServiceKeyword("(\.|^)softether-network\.net$", 654)//
CALL CreateServiceKeyword("(\.|^)softether\.org$", 654)//
CALL CreateService("Surfshark")//
CALL CreateServiceKeyword("(\.|^)surfshark\.com$", 655)//
CALL CreateServiceKeyword("(\.|^)surfsharkstatus\.com$", 655)//
CALL CreateService("TunnelBear")//
CALL CreateServiceKeyword("(\.|^)tunnelbear\.com$", 656)//
CALL CreateService("Zscaler")//
CALL CreateServiceKeyword("(\.|^)zpath\.net$", 657)//
CALL CreateServiceKeyword("(\.|^)zscaler\.com$", 657)//
CALL CreateServiceKeyword("(\.|^)zscaler\.de$", 657)//
CALL CreateServiceKeyword("(\.|^)zscaler\.fr$", 657)//
CALL CreateServiceKeyword("(\.|^)zscaler\.jp$", 657)//
CALL CreateServiceKeyword("(\.|^)zscaler\.net$", 657)//
CALL CreateServiceKeyword("(\.|^)zscalerbeta\.net$", 657)//
CALL CreateServiceKeyword("(\.|^)zscalerone\.net$", 657)//
CALL CreateServiceKeyword("(\.|^)zscalerthree\.net$", 657)//
CALL CreateServiceKeyword("(\.|^)zscalertwo\.net$", 657)//
CALL CreateServiceKeyword("(\.|^)zscloud\.net$", 657)//
CALL CreateService("Amazon Video")//
CALL CreateServiceKeyword("(\.|^)aiv-cdn\.net$", 658)//
CALL CreateServiceKeyword("(\.|^)aiv-cdn\.net\.c\.footprint\.net$", 658)//
CALL CreateServiceKeyword("(\.|^)aiv-delivery\.net$", 658)//
CALL CreateServiceKeyword("(\.|^)amazonvideo\.com$", 658)//
CALL CreateServiceKeyword("(\.|^)atv-ext-eu\.amazon\.com$", 658)//
CALL CreateServiceKeyword("(\.|^)atv-ext-fe\.amazon\.com$", 658)//
CALL CreateServiceKeyword("(\.|^)atv-ext\.amazon\.com$", 658)//
CALL CreateServiceKeyword("(\.|^)atv-ps\.amazon\.com$", 658)//
CALL CreateServiceKeyword("(\.|^)d25xi40x97liuc\.cloudfront\.net$", 658)//
CALL CreateServiceKeyword("(\.|^)dmqdd6hw24ucf\.cloudfront\.net$", 658)//
CALL CreateServiceKeyword("(\.|^)primevideo\.com$", 658)//
CALL CreateServiceKeyword("(\.|^)pv-cdn\.net$", 658)//
CALL CreateService("Crave")//
CALL CreateServiceKeyword("(\.|^)9c9media\.ca$", 659)//
CALL CreateServiceKeyword("(\.|^)9c9media\.com$", 659)//
CALL CreateServiceKeyword("(\.|^)crave\.ca$", 659)//
CALL CreateServiceKeyword("(\.|^)pe-ak-vp02a-9c9media\.akamaized\.net$", 659)//
CALL CreateService("Deezer")//
CALL CreateServiceKeyword("(\.|^)deezer\.akamaized\.net$", 660)//
CALL CreateServiceKeyword("(\.|^)deezer\.com$", 660)//
CALL CreateServiceKeyword("(\.|^)deezer\.com\.edgekey\.net$", 660)//
CALL CreateServiceKeyword("(\.|^)dzcdn\.net$", 660)//
CALL CreateService("Disney Plus")//
CALL CreateServiceKeyword("(\.|^)disney-plus\.net$", 661)//
CALL CreateServiceKeyword("(\.|^)disneyplus\.com$", 661)//
CALL CreateServiceKeyword("(\.|^)disneyplus\.com\.edgekey\.net$", 661)//
CALL CreateServiceKeyword("(\.|^)disneyplus\.com\.ssl\.sc\.omtrdc\.net$", 661)//
CALL CreateServiceKeyword("(\.|^)disneyplus\.disney\.co\.jp$", 661)//
CALL CreateServiceKeyword("(\.|^)dss\.map\.fastly\.net$", 661)//
CALL CreateServiceKeyword("(\.|^)dssott\.com$", 661)//
CALL CreateServiceKeyword("(\.|^)dssott\.com\.akamaized\.net$", 661)//
CALL CreateServiceKeyword("(\.|^)search-api-disney\.bamgrid\.com$", 661)//
CALL CreateService("HBO")//
CALL CreateServiceKeyword("(\.|^)hbo\.com$", 662)//
CALL CreateServiceKeyword("(\.|^)hbo\.map\.fastly\.net$", 662)//
CALL CreateServiceKeyword("(\.|^)hbogo\.co\.th$", 662)//
CALL CreateServiceKeyword("(\.|^)hbogo\.com$", 662)//
CALL CreateServiceKeyword("(\.|^)hbogo\.eu$", 662)//
CALL CreateServiceKeyword("(\.|^)hbogoasia\.com$", 662)//
CALL CreateServiceKeyword("(\.|^)hbogoasia\.id$", 662)//
CALL CreateServiceKeyword("(\.|^)hbogoasia\.ph$", 662)//
CALL CreateServiceKeyword("(\.|^)hbogoprod-vod\.akamaized\.net$", 662)//
CALL CreateServiceKeyword("(\.|^)hbomax\.com$", 662)//
CALL CreateServiceKeyword("(\.|^)hbomaxcdn\.com$", 662)//
CALL CreateServiceKeyword("(\.|^)hbonow\.com$", 662)//
CALL CreateService("Hotdog Radio")//
CALL CreateServiceKeyword("(\.|^)hotdogradio\.com$", 663)//
CALL CreateService("Hulu")//
CALL CreateServiceKeyword("(\.|^)assetshuluimcom-a\.akamaihd\.net$", 664)//
CALL CreateServiceKeyword("(\.|^)cws-hulu\.conviva\.com$", 664)//
CALL CreateServiceKeyword("(\.|^)dual-hulu\.com\.edgekey\.net$", 664)//
CALL CreateServiceKeyword("(\.|^)hulu-ios\.hb-api\.omtrdc\.net$", 664)//
CALL CreateServiceKeyword("(\.|^)hulu-lr\.hb-api\.omtrdc\.net$", 664)//
CALL CreateServiceKeyword("(\.|^)hulu\.com$", 664)//
CALL CreateServiceKeyword("(\.|^)hulu\.com\.akadns\.net$", 664)//
CALL CreateServiceKeyword("(\.|^)hulu\.com\.c\.footprint\.net$", 664)//
CALL CreateServiceKeyword("(\.|^)hulu\.hb-api\.omtrdc\.net$", 664)//
CALL CreateServiceKeyword("(\.|^)hulu\.hb\.omtrdc\.net$", 664)//
CALL CreateServiceKeyword("(\.|^)hulu\.map\.fastly\.net$", 664)//
CALL CreateServiceKeyword("(\.|^)hulu\.sc\.omtrdc\.net$", 664)//
CALL CreateServiceKeyword("(\.|^)huluad\.com$", 664)//
CALL CreateServiceKeyword("(\.|^)huluim\.com$", 664)//
CALL CreateServiceKeyword("(\.|^)hulumail\.com$", 664)//
CALL CreateServiceKeyword("(\.|^)huluqa\.com$", 664)//
CALL CreateServiceKeyword("(\.|^)hulustream\.com$", 664)//
CALL CreateServiceKeyword("(\.|^)ibhuluimcom-a\.akamaihd\.net$", 664)//
CALL CreateService("Last.fm")//
CALL CreateServiceKeyword("(\.|^)last\.fm$", 665)//
CALL CreateServiceKeyword("(\.|^)lastfm\.freetls\.fastly\.net$", 665)//
CALL CreateService("Netflix")//
CALL CreateServiceKeyword("(\.|^)apiproxy-device-prod-nlb-3-a653f8a785200e05\.elb\.us-west-2\.amazonaws\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)dualstack\.apiproxy-device-prod-nlb-1-4d12762d4ba53e45\.elb\.eu-west-1\.amazonaws\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)dualstack\.apiproxy-device-prod-nlb-1-c582e7914e487bf4\.elb\.us-east-1\.amazonaws\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)dualstack\.apiproxy-device-prod-nlb-2-300c995e1ce8a001\.elb\.us-east-1\.amazonaws\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)dualstack\.apiproxy-device-prod-nlb-3-a6ae1986950e693f\.elb\.us-east-1\.amazonaws\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)dualstack\.apiproxy-device-prod-nlb-3-d601e17f0cb54f72\.elb\.eu-west-1\.amazonaws\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)dualstack\.apiproxy-device-prod-nlb-4-1f9e6a56738a49ec\.elb\.us-east-1\.amazonaws\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)dualstack\.apiproxy-device-prod-nlb-4-f1dce6fa09ac5989\.elb\.eu-west-1\.amazonaws\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)dualstack\.apiproxy-http1-199106617\.us-east-1\.elb\.amazonaws\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)dualstack\.ichnaea-web-121909266\.us-east-1\.elb\.amazonaws\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflix\.ca$", 666)//
CALL CreateServiceKeyword("(\.|^)netflix\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflix\.com\.edgesuite\.net$", 666)//
CALL CreateServiceKeyword("(\.|^)netflix\.net$", 666)//
CALL CreateServiceKeyword("(\.|^)netflixdnstest1\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflixdnstest10\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflixdnstest2\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflixdnstest3\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflixdnstest4\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflixdnstest5\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflixdnstest6\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflixdnstest7\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflixdnstest8\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflixdnstest9\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflixinvestor\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)netflixtechblog\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)nflxext\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)nflximg\.com$", 666)//
CALL CreateServiceKeyword("(\.|^)nflximg\.net$", 666)//
CALL CreateServiceKeyword("(\.|^)nflxso\.net$", 666)//
CALL CreateServiceKeyword("(\.|^)nflxvideo\.net$", 666)//
CALL CreateService("OCS")//
CALL CreateServiceKeyword("(\.|^)ocs\.fr$", 667)//
CALL CreateServiceKeyword("(\.|^)ocsdomain\.com$", 667)//
CALL CreateService("Pandora")//
CALL CreateServiceKeyword("(\.|^)p-cdn\.com$", 668)//
CALL CreateServiceKeyword("(\.|^)p-cdn\.us$", 668)//
CALL CreateServiceKeyword("(\.|^)pandora\.com$", 668)//
CALL CreateService("Plex")//
CALL CreateServiceKeyword("(\.|^)plex\.bz$", 669)//
CALL CreateServiceKeyword("(\.|^)plex\.direct$", 669)//
CALL CreateServiceKeyword("(\.|^)plex\.tv$", 669)//
CALL CreateServiceKeyword("(\.|^)plex\.tv\.cdn\.cloudflare\.net$", 669)//
CALL CreateServiceKeyword("(\.|^)plexapp\.com$", 669)//
CALL CreateServiceKeyword("(\.|^)plexapp\.com\.cdn\.cloudflare\.net$", 669)//
CALL CreateService("SomaFM")//
CALL CreateServiceKeyword("(\.|^)somafm\.com$", 670)//
CALL CreateService("SoundCloud")//
CALL CreateServiceKeyword("(\.|^)sndcdn\.com$", 671)//
CALL CreateServiceKeyword("(\.|^)soundcloud\.com$", 671)//
CALL CreateService("Spotify")//
CALL CreateServiceKeyword("(\.|^)audio-ak-spotify-com\.akamaized\.net$", 672)//
CALL CreateServiceKeyword("(\.|^)audio-akp-bbr-spotify-com\.akamaized\.net$", 672)//
CALL CreateServiceKeyword("(\.|^)audio4-ak-spotify-com\.akamaized\.net$", 672)//
CALL CreateServiceKeyword("(\.|^)heads-ak-spotify-com\.akamaized\.net$", 672)//
CALL CreateServiceKeyword("(\.|^)pscdn\.co$", 672)//
CALL CreateServiceKeyword("(\.|^)scdn\.co$", 672)//
CALL CreateServiceKeyword("(\.|^)spoti\.fi$", 672)//
CALL CreateServiceKeyword("(\.|^)spotify-com\.akamaized\.net$", 672)//
CALL CreateServiceKeyword("(\.|^)spotify\.com$", 672)//
CALL CreateServiceKeyword("(\.|^)spotify\.com\.edgesuite\.net$", 672)//
CALL CreateServiceKeyword("(\.|^)spotify\.demdex\.net$", 672)//
CALL CreateServiceKeyword("(\.|^)spotify\.edgekey\.net$", 672)//
CALL CreateServiceKeyword("(\.|^)spotify\.map\.fastly\.net$", 672)//
CALL CreateServiceKeyword("(\.|^)spotifycdn\.com$", 672)//
CALL CreateServiceKeyword("(\.|^)spotifycdn\.map\.fastly\.net$", 672)//
CALL CreateServiceKeyword("(\.|^)spotifycdn\.net$", 672)//
CALL CreateServiceKeyword("(\.|^)spotifycharts\.com$", 672)//
CALL CreateServiceKeyword("(\.|^)spotifycodes\.com$", 672)//
CALL CreateServiceKeyword("(\.|^)spotifyjobs\.com$", 672)//
CALL CreateServiceKeyword("(\.|^)spotilocal\.com$", 672)//
CALL CreateServiceKeyword("(\.|^)video-akp-cdn-spotify-com\.akamaized\.net$", 672)//
CALL CreateService("Streamable")//
CALL CreateServiceKeyword("(\.|^)streamable\.com$", 673)//
CALL CreateService("TuneIn")//
CALL CreateServiceKeyword("(\.|^)radiotime\.com$", 674)//
CALL CreateServiceKeyword("(\.|^)radiotime\.com\.cdn\.cloudflare\.net$", 674)//
CALL CreateServiceKeyword("(\.|^)tunein\.com$", 674)//
CALL CreateServiceKeyword("(\.|^)tunein\.com\.cdn\.cloudflare\.net$", 674)//
CALL CreateService("Twitch")//
CALL CreateServiceKeyword("(\.|^)countess-prod-public-176850629\.us-west-2\.elb\.amazonaws\.com$", 675)//
CALL CreateServiceKeyword("(\.|^)ext-twitch\.tv$", 675)//
CALL CreateServiceKeyword("(\.|^)jtvnw\.net$", 675)//
CALL CreateServiceKeyword("(\.|^)live-video\.net$", 675)//
CALL CreateServiceKeyword("(\.|^)science-edge-external-prod-73889260\.us-west-2\.elb\.amazonaws\.com$", 675)//
CALL CreateServiceKeyword("(\.|^)ttvnw\.net$", 675)//
CALL CreateServiceKeyword("(\.|^)twitch\.map\.fastly\.net$", 675)//
CALL CreateServiceKeyword("(\.|^)twitch\.tv$", 675)//
CALL CreateServiceKeyword("(\.|^)twitchcdn\.net$", 675)//
CALL CreateServiceKeyword("(\.|^)twitchsvc\.net$", 675)//
CALL CreateService("Vevo")//
CALL CreateServiceKeyword("(\.|^)vevo\.com$", 676)//
CALL CreateService("Vimeo")//
CALL CreateServiceKeyword("(\.|^)vimeo-video\.map\.fastly\.net$", 677)//
CALL CreateServiceKeyword("(\.|^)vimeo\.com$", 677)//
CALL CreateServiceKeyword("(\.|^)vimeo\.map\.fastly\.net$", 677)//
CALL CreateServiceKeyword("(\.|^)vimeocdn\.com$", 677)//
CALL CreateService("YouTube")//
CALL CreateServiceKeyword("(\.|^)googlevideo\.com$", 678)//
CALL CreateServiceKeyword("(\.|^)gvt1\.com$", 678)//
CALL CreateServiceKeyword("(\.|^)i-ytimg-com\.cdn\.ampproject\.org$", 678)//
CALL CreateServiceKeyword("(\.|^)s-yimg-com\.cdn\.ampproject\.org$", 678)//
CALL CreateServiceKeyword("(\.|^)video\.google\.com$", 678)//
CALL CreateServiceKeyword("(\.|^)youtu\.be$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube-nocookie\.com$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube-ui\.l\.google\.com$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ae$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.al$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.am$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.at$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.az$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ba$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.be$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.bg$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.bh$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.bo$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.by$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ca$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.cat$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ch$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.cl$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.ae$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.at$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.cr$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.hu$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.id$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.il$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.in$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.jp$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.ke$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.kr$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.ma$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.nz$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.th$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.tz$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.ug$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.uk$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.ve$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.za$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.co\.zw$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.ar$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.au$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.az$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.bd$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.bh$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.bo$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.br$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.by$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.co$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.do$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.ec$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.ee$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.eg$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.es$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.gh$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.gr$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.gt$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.hk$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.hn$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.hr$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.jm$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.jo$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.kw$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.lb$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.lv$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.ly$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.mk$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.mt$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.mx$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.my$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.ng$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.ni$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.om$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.pa$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.pe$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.ph$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.pk$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.pt$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.py$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.qa$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.ro$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.sa$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.sg$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.sv$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.tn$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.tr$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.tw$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.ua$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.uy$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.com\.ve$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.cr$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.cz$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.de$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.dk$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ee$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.es$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.fi$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.fr$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ge$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.googleapis\.com$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.gr$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.gt$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.hk$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.hr$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.hu$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ie$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.in$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.iq$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.is$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.it$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.jo$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.jp$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.kr$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.kz$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.la$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.lk$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.lt$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.lu$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.lv$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ly$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ma$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.md$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.me$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.mk$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.mn$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.mx$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.my$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ng$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ni$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.nl$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.no$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.pa$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.pe$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ph$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.pk$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.pl$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.pr$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.pt$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.qa$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ro$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.rs$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ru$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.sa$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.se$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.sg$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.si$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.sk$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.sn$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.soy$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.sv$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.tn$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.tv$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ua$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.ug$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.uy$", 678)//
CALL CreateServiceKeyword("(\.|^)youtube\.vn$", 678)//
CALL CreateServiceKeyword("(\.|^)youtubeeducation\.com$", 678)//
CALL CreateServiceKeyword("(\.|^)youtubei\.googleapis\.com$", 678)//
CALL CreateServiceKeyword("(\.|^)yt\.be$", 678)//
CALL CreateServiceKeyword("(\.|^)yt3\.ggpht\.com$", 678)//
CALL CreateServiceKeyword("(\.|^)ytimg\.com$", 678)//
CALL CreateService("iHeartRadio")//
CALL CreateServiceKeyword("(\.|^)iheart\.com$", 679)//
CALL CreateServiceKeyword("(\.|^)iheart\.com\.ssl\.sc\.omtrdc\.net$", 679)//
CALL CreateServiceKeyword("(\.|^)iheart\.map\.fastly\.net$", 679)//
CALL CreateServiceKeyword("(\.|^)iheartmedia\.com$", 679)//
CALL CreateServiceKeyword("(\.|^)iheartmedia\.map\.fastly\.net$", 679)//
CALL CreateServiceKeyword("(\.|^)iheartradio\.ca$", 679)//
CALL CreateServiceKeyword("(\.|^)ihrhls\.com$", 679)//
CALL CreateService("iQiyi")//
CALL CreateServiceKeyword("(\.|^)iq\.com$", 680)//
CALL CreateServiceKeyword("(\.|^)iqiyi\.com$", 680)//
CALL CreateServiceKeyword("(\.|^)iqiyi\.com\.edgekey\.net$", 680)//
CALL CreateServiceKeyword("(\.|^)iqiyi\.com\.edgesuite\.net$", 680)//
CALL CreateServiceKeyword("(\.|^)iqiyipic\.com$", 680)//
CALL CreateServiceKeyword("(\.|^)iqiyipic\.com\.edgekey\.net$", 680)//
CALL CreateServiceKeyword("(\.|^)iqiyiweb\.akadns\.net$", 680)//
CALL CreateServiceKeyword("(\.|^)pps\.tv$", 680)//
CALL CreateServiceKeyword("(\.|^)ppstream\.com$", 680)//
CALL CreateServiceKeyword("(\.|^)qiyipic\.com$", 680)//
CALL CreateServiceKeyword("(\.|^)qy\.net$", 680)//
CALL CreateService("ADAMnetworks")//
CALL CreateServiceKeyword("(\.|^)adamnet\.works$", 681)//
CALL CreateServiceKeyword("(\.|^)dnsthingy\.com$", 681)//
CALL CreateService("AVG Antivirus")//
CALL CreateServiceKeyword("(\.|^)avg\.com$", 682)//
CALL CreateServiceKeyword("(\.|^)nos-avg\.cz$", 682)//
CALL CreateService("Abuse.ch")//
CALL CreateServiceKeyword("(\.|^)abuse\.ch$", 683)//
CALL CreateService("Acronis")//
CALL CreateServiceKeyword("(\.|^)acronis-dl\.akamaized\.net$", 684)//
CALL CreateServiceKeyword("(\.|^)acronis\.com$", 684)//
CALL CreateService("Adaware")//
CALL CreateServiceKeyword("(\.|^)adaware\.com$", 685)//
CALL CreateService("Adblock Plus")//
CALL CreateServiceKeyword("(\.|^)adblockplus\.org$", 686)//
CALL CreateService("AhnLab")//
CALL CreateServiceKeyword("(\.|^)ahnlab\.com$", 687)//
CALL CreateService("Airo")//
CALL CreateServiceKeyword("(\.|^)airoav\.com$", 688)//
CALL CreateService("AnubisNetworks")//
CALL CreateServiceKeyword("(\.|^)anubisnetworks\.com$", 689)//
CALL CreateServiceKeyword("(\.|^)mailspike\.net$", 689)//
CALL CreateService("Avast")//
CALL CreateServiceKeyword("(\.|^)avast\.com$", 690)//
CALL CreateServiceKeyword("(\.|^)avast\.com\.akamaized\.net$", 690)//
CALL CreateServiceKeyword("(\.|^)avast\.com\.edgekey\.net$", 690)//
CALL CreateServiceKeyword("(\.|^)avast\.com\.edgesuite\.net$", 690)//
CALL CreateServiceKeyword("(\.|^)avastbrowser\.com$", 690)//
CALL CreateServiceKeyword("(\.|^)avcdn\.net$", 690)//
CALL CreateServiceKeyword("(\.|^)ns1dnsavast\.com$", 690)//
CALL CreateService("Avira")//
CALL CreateServiceKeyword("(\.|^)avira-update\.com$", 691)//
CALL CreateServiceKeyword("(\.|^)avira\.com$", 691)//
CALL CreateServiceKeyword("(\.|^)avira\.com-v1\.edgesuite\.net$", 691)//
CALL CreateServiceKeyword("(\.|^)avira\.com\.edgesuite\.net$", 691)//
CALL CreateService("Barracuda")//
CALL CreateServiceKeyword("(\.|^)barracuda\.com$", 692)//
CALL CreateServiceKeyword("(\.|^)barracudacentral\.org$", 692)//
CALL CreateServiceKeyword("(\.|^)barracudanetworks\.com$", 692)//
CALL CreateService("Bitdefender")//
CALL CreateServiceKeyword("(\.|^)bitdefender\.com$", 693)//
CALL CreateServiceKeyword("(\.|^)bitdefender\.demdex\.net$", 693)//
CALL CreateServiceKeyword("(\.|^)bitdefender\.net$", 693)//
CALL CreateServiceKeyword("(\.|^)bitdefender\.net\.cdn\.cloudflare\.net$", 693)//
CALL CreateServiceKeyword("(\.|^)bitdefender\.sc\.omtrdc\.net$", 693)//
CALL CreateServiceKeyword("(\.|^)bitdefender\.tt\.omtrdc\.net$", 693)//
CALL CreateServiceKeyword("(\.|^)kube-nimbus-1399884016\.eu-west-1\.elb\.amazonaws\.com$", 693)//
CALL CreateService("Check Point")//
CALL CreateServiceKeyword("(\.|^)checkpoint\.com$", 694)//
CALL CreateServiceKeyword("(\.|^)zonealarm\.com$", 694)//
CALL CreateServiceKeyword("(\.|^)zonelabs\.com$", 694)//
CALL CreateService("Cisco Umbrella")//
CALL CreateServiceKeyword("(\.|^)dnsomatic\.com$", 695)//
CALL CreateServiceKeyword("(\.|^)opendns\.com$", 695)//
CALL CreateServiceKeyword("(\.|^)umbrella\.cisco\.com$", 695)//
CALL CreateServiceKeyword("(\.|^)umbrella\.com$", 695)//
CALL CreateService("ClamAV")//
CALL CreateServiceKeyword("(\.|^)clamav\.net$", 696)//
CALL CreateServiceKeyword("(\.|^)clamav\.net\.cdn\.cloudflare\.net$", 696)//
CALL CreateService("Clario")//
CALL CreateServiceKeyword("(\.|^)clario\.co$", 697)//
CALL CreateService("Cloudmark")//
CALL CreateServiceKeyword("(\.|^)cloudmark\.com$", 698)//
CALL CreateService("Comodo")//
CALL CreateServiceKeyword("(\.|^)comodo\.com$", 699)//
CALL CreateServiceKeyword("(\.|^)comododns\.com$", 699)//
CALL CreateServiceKeyword("(\.|^)comododns\.net$", 699)//
CALL CreateService("CyberLucent")//
CALL CreateServiceKeyword("(\.|^)cyberlucent\.com$", 700)//
CALL CreateServiceKeyword("(\.|^)cytheia\.com$", 700)//
CALL CreateServiceKeyword("(\.|^)lucidsecure\.cloud$", 700)//
CALL CreateServiceKeyword("(\.|^)lucidsecure\.com$", 700)//
CALL CreateServiceKeyword("(\.|^)securework\.cloud$", 700)//
CALL CreateServiceKeyword("(\.|^)secureworkhome\.com$", 700)//
CALL CreateServiceKeyword("(\.|^)secureworkoffice\.com$", 700)//
CALL CreateService("Cylance")//
CALL CreateServiceKeyword("(\.|^)cylance\.com$", 701)//
CALL CreateService("Cyren")//
CALL CreateServiceKeyword("(\.|^)ctmail\.com$", 702)//
CALL CreateServiceKeyword("(\.|^)cyren\.com$", 702)//
CALL CreateService("DNSFilter")//
CALL CreateServiceKeyword("(\.|^)dnsfilter\.com$", 703)//
CALL CreateService("Deep Instinct")//
CALL CreateServiceKeyword("(\.|^)deepinstinct\.com$", 704)//
CALL CreateServiceKeyword("(\.|^)deepinstinctweb\.com$", 704)//
CALL CreateService("DigiCert")//
CALL CreateServiceKeyword("(\.|^)crl\.verisign\.com$", 705)//
CALL CreateServiceKeyword("(\.|^)cs9\.wac\.phicdn\.net$", 705)//
CALL CreateServiceKeyword("(\.|^)digicert\.cn$", 705)//
CALL CreateServiceKeyword("(\.|^)digicert\.com$", 705)//
CALL CreateServiceKeyword("(\.|^)digicertcdn\.com$", 705)//
CALL CreateServiceKeyword("(\.|^)digitalcertvalidation\.com$", 705)//
CALL CreateServiceKeyword("(\.|^)geotrust\.com$", 705)//
CALL CreateServiceKeyword("(\.|^)public-trust\.com$", 705)//
CALL CreateServiceKeyword("(\.|^)rapidssl\.com$", 705)//
CALL CreateServiceKeyword("(\.|^)symcb\.com$", 705)//
CALL CreateServiceKeyword("(\.|^)thawte\.com$", 705)//
CALL CreateService("Dynatrace")//
CALL CreateServiceKeyword("(\.|^)dynatrace-managed\.com$", 706)//
CALL CreateServiceKeyword("(\.|^)dynatrace\.com$", 706)//
CALL CreateService("EICAR")//
CALL CreateServiceKeyword("(\.|^)eicar\.com$", 707)//
CALL CreateServiceKeyword("(\.|^)eicar\.org$", 707)//
CALL CreateService("ESET")//
CALL CreateServiceKeyword("(\.|^)e5\.sk$", 708)//
CALL CreateServiceKeyword("(\.|^)eset\.com$", 708)//
CALL CreateServiceKeyword("(\.|^)eset\.eu$", 708)//
CALL CreateServiceKeyword("(\.|^)eset\.sk$", 708)//
CALL CreateService("Endian")//
CALL CreateServiceKeyword("(\.|^)endian\.com$", 709)//
CALL CreateService("Ensighten")//
CALL CreateServiceKeyword("(\.|^)ensighten\.com$", 710)//
CALL CreateServiceKeyword("(\.|^)nc0\.co$", 710)//
CALL CreateService("F-Secure")//
CALL CreateServiceKeyword("(\.|^)f-secure\.com$", 711)//
CALL CreateServiceKeyword("(\.|^)f-secure\.com\.pl$", 711)//
CALL CreateServiceKeyword("(\.|^)f-secure\.net$", 711)//
CALL CreateServiceKeyword("(\.|^)fsapi\.com$", 711)//
CALL CreateService("F5 Networks")//
CALL CreateServiceKeyword("(\.|^)defense\.net$", 712)//
CALL CreateServiceKeyword("(\.|^)f5\.com$", 712)//
CALL CreateService("Forcepoint")//
CALL CreateServiceKeyword("(\.|^)blackspider\.com$", 713)//
CALL CreateServiceKeyword("(\.|^)forcepoint\.com$", 713)//
CALL CreateServiceKeyword("(\.|^)forcepoint\.net$", 713)//
CALL CreateServiceKeyword("(\.|^)frcpt\.net$", 713)//
CALL CreateServiceKeyword("(\.|^)websense\.com$", 713)//
CALL CreateService("Forter")//
CALL CreateServiceKeyword("(\.|^)forter\.com$", 714)//
CALL CreateService("Fortinet")//
CALL CreateServiceKeyword("(\.|^)fortiguard\.com$", 715)//
CALL CreateServiceKeyword("(\.|^)fortinet\.com$", 715)//
CALL CreateServiceKeyword("(\.|^)fortinet\.net$", 715)//
CALL CreateService("Ghostery")//
CALL CreateServiceKeyword("(\.|^)ghostery\.com$", 716)//
CALL CreateServiceKeyword("(\.|^)ghostery\.net$", 716)//
CALL CreateService("GlobalSign")//
CALL CreateServiceKeyword("(\.|^)globalsign\.com$", 717)//
CALL CreateServiceKeyword("(\.|^)globalsign\.net$", 717)//
CALL CreateService("GoGuardian")//
CALL CreateServiceKeyword("(\.|^)goguardian\.com$", 718)//
CALL CreateService("Hermes Network")//
CALL CreateServiceKeyword("(\.|^)hermesnetwork\.cloud$", 719)//
CALL CreateService("Human")//
CALL CreateServiceKeyword("(\.|^)humansecurity\.com$", 720)//
CALL CreateService("Huntress")//
CALL CreateServiceKeyword("(\.|^)huntress-installers\.s3\.amazonaws\.com$", 721)//
CALL CreateServiceKeyword("(\.|^)huntress-updates\.s3\.amazonaws\.com$", 721)//
CALL CreateServiceKeyword("(\.|^)huntress-uploads\.s3\.us-west-2\.amazonaws\.com$", 721)//
CALL CreateServiceKeyword("(\.|^)huntress\.io$", 721)//
CALL CreateServiceKeyword("(\.|^)huntresslabs\.com$", 721)//
CALL CreateService("IBM Trusteer")//
CALL CreateServiceKeyword("(\.|^)trusteer\.com$", 722)//
CALL CreateService("IdenTrust")//
CALL CreateServiceKeyword("(\.|^)identrust\.com$", 723)//
CALL CreateService("Imperva")//
CALL CreateServiceKeyword("(\.|^)imperva\.com$", 724)//
CALL CreateServiceKeyword("(\.|^)incapdns\.net$", 724)//
CALL CreateService("Intego")//
CALL CreateServiceKeyword("(\.|^)intego\.com$", 725)//
CALL CreateService("Kali Linux")//
CALL CreateServiceKeyword("(\.|^)kali\.download$", 726)//
CALL CreateServiceKeyword("(\.|^)kali\.org$", 726)//
CALL CreateService("Kaspersky")//
CALL CreateServiceKeyword("(\.|^)kas-labs\.com$", 727)//
CALL CreateServiceKeyword("(\.|^)kaspersky-labs\.com$", 727)//
CALL CreateServiceKeyword("(\.|^)kaspersky\.com$", 727)//
CALL CreateServiceKeyword("(\.|^)labkas\.com$", 727)//
CALL CreateService("LexisNexis Risk")//
CALL CreateServiceKeyword("(\.|^)online-metrix\.net$", 728)//
CALL CreateServiceKeyword("(\.|^)risk\.lexisnexis\.com$", 728)//
CALL CreateService("Mailshell")//
CALL CreateServiceKeyword("(\.|^)mailshell\.com$", 729)//
CALL CreateServiceKeyword("(\.|^)mailshell\.net$", 729)//
CALL CreateService("Malwarebytes")//
CALL CreateServiceKeyword("(\.|^)malwarebytes\.com$", 730)//
CALL CreateServiceKeyword("(\.|^)malwarebytes\.com-lb\.ssopt\.net\.akadns\.net$", 730)//
CALL CreateServiceKeyword("(\.|^)malwarebytes\.com\.ssopt\.net\.akadns\.net$", 730)//
CALL CreateServiceKeyword("(\.|^)malwarebytes\.org$", 730)//
CALL CreateServiceKeyword("(\.|^)mb-cosmos\.com$", 730)//
CALL CreateServiceKeyword("(\.|^)mbamupdates\.com$", 730)//
CALL CreateServiceKeyword("(\.|^)mwbsys\.com$", 730)//
CALL CreateService("MaxMind")//
CALL CreateServiceKeyword("(\.|^)maxmind\.com$", 731)//
CALL CreateService("McAfee")//
CALL CreateServiceKeyword("(\.|^)hackerwatch\.org$", 732)//
CALL CreateServiceKeyword("(\.|^)mcafee\.akadns\.net$", 732)//
CALL CreateServiceKeyword("(\.|^)mcafee\.com$", 732)//
CALL CreateServiceKeyword("(\.|^)mcafee\.com\.edgekey\.net$", 732)//
CALL CreateServiceKeyword("(\.|^)mcafee\.net$", 732)//
CALL CreateServiceKeyword("(\.|^)mcafee12\.tt\.omtrdc\.net$", 732)//
CALL CreateServiceKeyword("(\.|^)mcafeemobilesecurity\.com$", 732)//
CALL CreateServiceKeyword("(\.|^)mcafeewebadvisor\.com$", 732)//
CALL CreateService("Norton")//
CALL CreateServiceKeyword("(\.|^)e859\.g\.akamaiedge\.net$", 733)//
CALL CreateServiceKeyword("(\.|^)norton\.com$", 733)//
CALL CreateServiceKeyword("(\.|^)nortoncdn\.com$", 733)//
CALL CreateServiceKeyword("(\.|^)nortonlifelock\.com$", 733)//
CALL CreateService("OPNsense")//
CALL CreateServiceKeyword("(\.|^)opnsense\.org$", 734)//
CALL CreateService("PC Matic")//
CALL CreateServiceKeyword("(\.|^)pcmatic\.com$", 735)//
CALL CreateServiceKeyword("(\.|^)pcpitstop\.com$", 735)//
CALL CreateService("PSBL")//
CALL CreateServiceKeyword("(\.|^)psbl\.org$", 736)//
CALL CreateServiceKeyword("(\.|^)surriel\.com$", 736)//
CALL CreateService("Palo Alto Networks")//
CALL CreateServiceKeyword("(\.|^)paloaltonetworks\.com$", 737)//
CALL CreateServiceKeyword("(\.|^)paloaltonetworks\.es$", 737)//
CALL CreateServiceKeyword("(\.|^)paloaltonetworks\.jp$", 737)//
CALL CreateServiceKeyword("(\.|^)paloaltonetworks\.kz$", 737)//
CALL CreateService("Panda Security")//
CALL CreateServiceKeyword("(\.|^)pandasecurity\.com$", 738)//
CALL CreateServiceKeyword("(\.|^)pandasoftware\.com$", 738)//
CALL CreateService("Proofpoint")//
CALL CreateServiceKeyword("(\.|^)ppe-hosted\.com$", 739)//
CALL CreateServiceKeyword("(\.|^)pphosted\.com$", 739)//
CALL CreateServiceKeyword("(\.|^)proofpoint\.com$", 739)//
CALL CreateService("Qihoo 360")//
CALL CreateServiceKeyword("(\.|^)360\.cn$", 740)//
CALL CreateServiceKeyword("(\.|^)360\.com$", 740)//
CALL CreateServiceKeyword("(\.|^)360safe\.com$", 740)//
CALL CreateServiceKeyword("(\.|^)360securityapps\.com$", 740)//
CALL CreateServiceKeyword("(\.|^)360totalsecurity\.com$", 740)//
CALL CreateServiceKeyword("(\.|^)qhimg\.com$", 740)//
CALL CreateService("Rapid7")//
CALL CreateServiceKeyword("(\.|^)rapid7\.com$", 741)//
CALL CreateService("RapidSSL")//
CALL CreateServiceKeyword("(\.|^)www\.rapidssl\.com$", 742)//
CALL CreateService("Rpsamd")//
CALL CreateServiceKeyword("(\.|^)rspamd\.com$", 743)//
CALL CreateService("SORBS")//
CALL CreateServiceKeyword("(\.|^)sorbs\.net$", 744)//
CALL CreateService("SURBL")//
CALL CreateServiceKeyword("(\.|^)surbl\.org$", 745)//
CALL CreateService("Secom Trust")//
CALL CreateServiceKeyword("(\.|^)secomtrust\.net$", 746)//
CALL CreateServiceKeyword("(\.|^)secomtrust\.net\.edgesuite\.net$", 746)//
CALL CreateService("Sectigo")//
CALL CreateServiceKeyword("(\.|^)comodoca\.com$", 747)//
CALL CreateServiceKeyword("(\.|^)comodoca4\.com$", 747)//
CALL CreateServiceKeyword("(\.|^)sectigo\.com$", 747)//
CALL CreateServiceKeyword("(\.|^)trust-provider\.com$", 747)//
CALL CreateServiceKeyword("(\.|^)usertrust\.com$", 747)//
CALL CreateService("Secureworks")//
CALL CreateServiceKeyword("(\.|^)secureworks\.com$", 748)//
CALL CreateService("Sender Score")//
CALL CreateServiceKeyword("(\.|^)senderscore\.com$", 749)//
CALL CreateServiceKeyword("(\.|^)senderscore\.org$", 749)//
CALL CreateService("Shodan")//
CALL CreateServiceKeyword("(\.|^)shodan\.io$", 750)//
CALL CreateService("Snort")//
CALL CreateServiceKeyword("(\.|^)snort-org-site\.s3\.amazonaws\.com$", 751)//
CALL CreateServiceKeyword("(\.|^)snort\.org$", 751)//
CALL CreateService("SonicWall")//
CALL CreateServiceKeyword("(\.|^)sonicwall\.com$", 752)//
CALL CreateService("Sophos")//
CALL CreateServiceKeyword("(\.|^)darkbytes\.io$", 753)//
CALL CreateServiceKeyword("(\.|^)sophos\.com$", 753)//
CALL CreateServiceKeyword("(\.|^)sophos\.net$", 753)//
CALL CreateServiceKeyword("(\.|^)sophosupd\.com$", 753)//
CALL CreateServiceKeyword("(\.|^)sophosupd\.net$", 753)//
CALL CreateServiceKeyword("(\.|^)sophosxl\.net$", 753)//
CALL CreateService("Spam Eating Monkey")//
CALL CreateServiceKeyword("(\.|^)spameatingmonkey\.net$", 754)//
CALL CreateService("SpamAssassin")//
CALL CreateServiceKeyword("(\.|^)sa-update\.secnap\.net$", 755)//
CALL CreateServiceKeyword("(\.|^)spamassassin\.apache\.org$", 755)//
CALL CreateServiceKeyword("(\.|^)spamassassin\.org$", 755)//
CALL CreateService("SpamCannibal")//
CALL CreateServiceKeyword("(\.|^)spamcannibal\.org$", 756)//
CALL CreateService("SpamCop")//
CALL CreateServiceKeyword("(\.|^)spamcop\.net$", 757)//
CALL CreateService("SpamExperts")//
CALL CreateServiceKeyword("(\.|^)antispamcloud\.com$", 758)//
CALL CreateServiceKeyword("(\.|^)spamexperts\.com$", 758)//
CALL CreateService("Spamhaus")//
CALL CreateServiceKeyword("(\.|^)spamhaus\.org$", 759)//
CALL CreateService("Spybot")//
CALL CreateServiceKeyword("(\.|^)safer-networking\.org$", 760)//
CALL CreateService("Support Intelligence")//
CALL CreateServiceKeyword("(\.|^)support-intelligence\.com$", 761)//
CALL CreateServiceKeyword("(\.|^)support-intelligence\.net$", 761)//
CALL CreateService("SuretyMail")//
CALL CreateServiceKeyword("(\.|^)isipp\.com$", 762)//
CALL CreateService("Symantec")//
CALL CreateServiceKeyword("(\.|^)symantec\.com$", 763)//
CALL CreateServiceKeyword("(\.|^)symantec\.com\.edgekey\.net$", 763)//
CALL CreateServiceKeyword("(\.|^)symantec\.com\.ssl\.d1\.sc\.omtrdc\.net$", 763)//
CALL CreateServiceKeyword("(\.|^)symantec\.demdex\.net$", 763)//
CALL CreateServiceKeyword("(\.|^)symantec\.edgesuite\.net$", 763)//
CALL CreateServiceKeyword("(\.|^)symantec\.net$", 763)//
CALL CreateServiceKeyword("(\.|^)symantec\.tt\.omtrdc\.net$", 763)//
CALL CreateServiceKeyword("(\.|^)symantecliveupdate\.com$", 763)//
CALL CreateServiceKeyword("(\.|^)symcd\.com$", 763)//
CALL CreateService("Tenable")//
CALL CreateServiceKeyword("(\.|^)tenable\.com$", 764)//
CALL CreateService("Thawte")//
CALL CreateServiceKeyword("(\.|^)www\.thawte\.com$", 765)//
CALL CreateService("Trend Micro")//
CALL CreateServiceKeyword("(\.|^)trendmicro\.co\.jp$", 766)//
CALL CreateServiceKeyword("(\.|^)trendmicro\.com$", 766)//
CALL CreateServiceKeyword("(\.|^)trendmicro\.com\.edgekey\.net$", 766)//
CALL CreateService("TrustArc")//
CALL CreateServiceKeyword("(\.|^)trustarc\.com$", 767)//
CALL CreateServiceKeyword("(\.|^)truste\.com$", 767)//
CALL CreateService("Trustwave")//
CALL CreateServiceKeyword("(\.|^)trustwave\.com$", 768)//
CALL CreateService("URIBL Blacklist")//
CALL CreateServiceKeyword("(\.|^)uribl\.com$", 769)//
CALL CreateService("Verisign")//
CALL CreateServiceKeyword("(\.|^)verisign\.com$", 770)//
CALL CreateService("Webroot")//
CALL CreateServiceKeyword("(\.|^)webroot\.com$", 771)//
CALL CreateServiceKeyword("(\.|^)webrootanywhere\.com$", 771)//
CALL CreateServiceKeyword("(\.|^)webrootcloudav\.com$", 771)//
CALL CreateServiceKeyword("(\.|^)webrootdns\.net$", 771)//
CALL CreateService("iboss")//
CALL CreateServiceKeyword("(\.|^)iboss\.com$", 772)//
CALL CreateServiceKeyword("(\.|^)ibosscloud\.com$", 772)//
CALL CreateServiceKeyword("(\.|^)ibossconnect\.com$", 772)//
CALL CreateService("pfSense")//
CALL CreateServiceKeyword("(\.|^)netgate\.com$", 773)//
CALL CreateServiceKeyword("(\.|^)pfsense\.org$", 773)//
CALL CreateService("Android")//
CALL CreateServiceKeyword("(\.|^)android\.clients\.google\.com$", 774)//
CALL CreateServiceKeyword("(\.|^)android\.com$", 774)//
CALL CreateServiceKeyword("(\.|^)android\.googleapis\.com$", 774)//
CALL CreateServiceKeyword("(\.|^)android\.l\.google\.com$", 774)//
CALL CreateService("Arch Linux")//
CALL CreateServiceKeyword("(\.|^)archlinux\.org$", 775)//
CALL CreateService("CentOS")//
CALL CreateServiceKeyword("(\.|^)centos\.ca-west\.mirror\.fullhost\.io$", 776)//
CALL CreateServiceKeyword("(\.|^)centos\.melbourneitmirror\.net$", 776)//
CALL CreateServiceKeyword("(\.|^)centos\.mirror\.colo-serv\.net$", 776)//
CALL CreateServiceKeyword("(\.|^)centos\.mirror\.garr\.it$", 776)//
CALL CreateServiceKeyword("(\.|^)centos\.mirror\.liquidtelecom\.com$", 776)//
CALL CreateServiceKeyword("(\.|^)centos\.mirror\.serversaustralia\.com\.au$", 776)//
CALL CreateServiceKeyword("(\.|^)centos\.mirrors\.theom\.nz$", 776)//
CALL CreateServiceKeyword("(\.|^)centos\.org$", 776)//
CALL CreateServiceKeyword("(\.|^)centos\.serverforge\.org$", 776)//
CALL CreateServiceKeyword("(\.|^)centos\.vwtonline\.net$", 776)//
CALL CreateServiceKeyword("(\.|^)mirrorlist\.centos\.org$", 776)//
CALL CreateService("ClearOS")//
CALL CreateServiceKeyword("(\.|^)clearos\.bhs\.mirrors\.ovh\.net$", 777)//
CALL CreateServiceKeyword("(\.|^)clearos\.com$", 777)//
CALL CreateServiceKeyword("(\.|^)clearos\.mirrors\.ovh\.net$", 777)//
CALL CreateServiceKeyword("(\.|^)clearos\.uberglobalmirror\.com$", 777)//
CALL CreateServiceKeyword("(\.|^)clearsdn\.com$", 777)//
CALL CreateService("Debian")//
CALL CreateServiceKeyword("(\.|^)debian\.map\.fastly\.net$", 778)//
CALL CreateServiceKeyword("(\.|^)debian\.map\.fastlydns\.net$", 778)//
CALL CreateServiceKeyword("(\.|^)debian\.org$", 778)//
CALL CreateServiceKeyword("(\.|^)prod\.debian\.map\.fastly\.net$", 778)//
CALL CreateService("Docker")//
CALL CreateServiceKeyword("(\.|^)docker\.com$", 779)//
CALL CreateServiceKeyword("(\.|^)docker\.io$", 779)//
CALL CreateService("Fedora Project")//
CALL CreateServiceKeyword("(\.|^)fedorapeople\.org$", 780)//
CALL CreateServiceKeyword("(\.|^)fedoraproject\.org$", 780)//
CALL CreateServiceKeyword("(\.|^)getfedora\.org$", 780)//
CALL CreateService("FreeBSD")//
CALL CreateServiceKeyword("(\.|^)freebsd\.org$", 781)//
CALL CreateService("Google Play")//
CALL CreateServiceKeyword("(\.|^)play-fe\.googleapis\.com$", 782)//
CALL CreateServiceKeyword("(\.|^)play-lh\.googleusercontent\.com$", 782)//
CALL CreateServiceKeyword("(\.|^)play\.google\.com$", 782)//
CALL CreateServiceKeyword("(\.|^)play\.googleapis\.com$", 782)//
CALL CreateService("Linux Mint")//
CALL CreateServiceKeyword("(\.|^)linuxmint\.com$", 783)//
CALL CreateService("NethServer")//
CALL CreateServiceKeyword("(\.|^)nethesis\.it$", 784)//
CALL CreateServiceKeyword("(\.|^)nethserver\.com$", 784)//
CALL CreateServiceKeyword("(\.|^)nethserver\.org$", 784)//
CALL CreateService("Ninite")//
CALL CreateServiceKeyword("(\.|^)ninite\.com$", 785)//
CALL CreateService("OpenWrt")//
CALL CreateServiceKeyword("(\.|^)lede-project\.org$", 786)//
CALL CreateServiceKeyword("(\.|^)openwrt\.org$", 786)//
CALL CreateService("Proxmox")//
CALL CreateServiceKeyword("(\.|^)proxmox\.com$", 787)//
CALL CreateService("Proxmox Updates")//
CALL CreateServiceKeyword("(\.|^)download\.proxmox\.com$", 788)//
CALL CreateService("Red Hat")//
CALL CreateServiceKeyword("(\.|^)jboss\.org$", 789)//
CALL CreateServiceKeyword("(\.|^)redhat\.com$", 789)//
CALL CreateServiceKeyword("(\.|^)redhat\.io$", 789)//
CALL CreateServiceKeyword("(\.|^)softwarecollections\.org$", 789)//
CALL CreateService("Samsung Apps")//
CALL CreateServiceKeyword("(\.|^)aibixby\.com$", 790)//
CALL CreateServiceKeyword("(\.|^)fe-pew1-ext-hub-lb-258008188\.eu-west-1\.elb\.amazonaws\.com$", 790)//
CALL CreateServiceKeyword("(\.|^)fe-pew1-ext-openapi-lb-547958838\.eu-west-1\.elb\.amazonaws\.com$", 790)//
CALL CreateServiceKeyword("(\.|^)samsungapps\.com$", 790)//
CALL CreateServiceKeyword("(\.|^)samsungapps\.com\.cdngc\.net$", 790)//
CALL CreateServiceKeyword("(\.|^)samsungdm\.com$", 790)//
CALL CreateServiceKeyword("(\.|^)samsungmdec\.com$", 790)//
CALL CreateServiceKeyword("(\.|^)samsungvisioncloud\.com$", 790)//
CALL CreateService("TrueNAS")//
CALL CreateServiceKeyword("(\.|^)freenas\.org$", 791)//
CALL CreateServiceKeyword("(\.|^)truenas\.com$", 791)//
CALL CreateService("TrueNAS Updates")//
CALL CreateServiceKeyword("(\.|^)download\.freenas\.org$", 792)//
CALL CreateServiceKeyword("(\.|^)download\.truenas\.com$", 792)//
CALL CreateServiceKeyword("(\.|^)update\.freenas\.org$", 792)//
CALL CreateService("Turnkey Linux")//
CALL CreateServiceKeyword("(\.|^)turnkeylinux\.org$", 793)//
CALL CreateService("UK Mirror Service")//
CALL CreateServiceKeyword("(\.|^)mirrorservice\.org$", 794)//
CALL CreateService("Ubuntu")//
CALL CreateServiceKeyword("(\.|^)canonical\.com$", 795)//
CALL CreateServiceKeyword("(\.|^)launchpad\.net$", 795)//
CALL CreateServiceKeyword("(\.|^)snapcraft\.io$", 795)//
CALL CreateServiceKeyword("(\.|^)ubuntu\.com$", 795)//
CALL CreateService("VirtualBox")//
CALL CreateServiceKeyword("(\.|^)virtualbox\.org$", 796)//
CALL CreateService("VyOS")//
CALL CreateServiceKeyword("(\.|^)vyos\.io$", 797)//
CALL CreateService("Windows Update")//
CALL CreateServiceKeyword("(\.|^)forefrontdl\.microsoft\.com$", 798)//
CALL CreateServiceKeyword("(\.|^)ntservicepack\.microsoft\.com$", 798)//
CALL CreateServiceKeyword("(\.|^)statsfe2\.ws\.microsoft\.com$", 798)//
CALL CreateServiceKeyword("(\.|^)update\.microsoft$", 798)//
CALL CreateServiceKeyword("(\.|^)update\.microsoft\.com$", 798)//
CALL CreateServiceKeyword("(\.|^)update\.microsoft\.com\.akadns\.net$", 798)//
CALL CreateServiceKeyword("(\.|^)update\.microsoft\.com\.nsatc\.net$", 798)//
CALL CreateServiceKeyword("(\.|^)windowsupdate\.com$", 798)//
CALL CreateServiceKeyword("(\.|^)windowsupdate\.com\.c\.footprint\.net$", 798)//
CALL CreateServiceKeyword("(\.|^)windowsupdate\.com\.edgesuite\.net$", 798)//
CALL CreateServiceKeyword("(\.|^)windowsupdate\.microsoft\.com$", 798)//
CALL CreateServiceKeyword("(\.|^)windowsupdate\.nsatc\.net$", 798)//
CALL CreateServiceKeyword("(\.|^)wustat\.windows\.com$", 798)//
CALL CreateService("openSUSE")//
CALL CreateServiceKeyword("(\.|^)opensuse\.org$", 799)//
CALL CreateServiceKeyword("(\.|^)susecloud\.net$", 799)//
CALL CreateService("3CX")//
CALL CreateServiceKeyword("(\.|^)3cx\.com$", 800)//
CALL CreateService("Amazon Chime")//
CALL CreateServiceKeyword("(\.|^)chime\.aws$", 801)//
CALL CreateService("Blue Jeans Network")//
CALL CreateServiceKeyword("(\.|^)bjn\.vc$", 802)//
CALL CreateServiceKeyword("(\.|^)bluejeans\.com$", 802)//
CALL CreateServiceKeyword("(\.|^)bluejeansnet\.com$", 802)//
CALL CreateService("Google Meet")//
CALL CreateServiceKeyword("(\.|^)alt1-mtalk\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)alt2-mtalk\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)alt3-mtalk\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)alt4-mtalk\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)alt5-mtalk\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)alt6-mtalk\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)alt7-mtalk\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)alt8-mtalk\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)hangouts\.clients6\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)hangouts\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)hangouts\.googleapis\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)meet\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)meetings\.googleapis\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)mobile-gtalk\.l\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)mobile-gtalk4\.l\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)mtalk\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)talk\.google\.com$", 803)//
CALL CreateServiceKeyword("(\.|^)talkx\.l\.google\.com$", 803)//
CALL CreateService("Google Voice")//
CALL CreateServiceKeyword("(\.|^)telephony\.goog$", 804)//
CALL CreateServiceKeyword("(\.|^)voice\.google\.com$", 804)//
CALL CreateService("Houseparty")//
CALL CreateServiceKeyword("(\.|^)houseparty\.com$", 805)//
CALL CreateServiceKeyword("(\.|^)joinhouse\.party$", 805)//
CALL CreateServiceKeyword("(\.|^)secrethouse\.party$", 805)//
CALL CreateService("Jive Communications")//
CALL CreateServiceKeyword("(\.|^)jive\.com$", 806)//
CALL CreateServiceKeyword("(\.|^)jive\.rtcfront\.net$", 806)//
CALL CreateServiceKeyword("(\.|^)jiveip\.net$", 806)//
CALL CreateServiceKeyword("(\.|^)onjive\.com$", 806)//
CALL CreateServiceKeyword("(\.|^)rtcfront\.net$", 806)//
CALL CreateService("LINE")//
CALL CreateServiceKeyword("(\.|^)lin\.ee$", 807)//
CALL CreateServiceKeyword("(\.|^)line-apps-beta\.com$", 807)//
CALL CreateServiceKeyword("(\.|^)line-apps\.com$", 807)//
CALL CreateServiceKeyword("(\.|^)line-apps\.com\.akadns\.net$", 807)//
CALL CreateServiceKeyword("(\.|^)line-apps\.com\.edgekey\.net$", 807)//
CALL CreateServiceKeyword("(\.|^)line-cdn\.net$", 807)//
CALL CreateServiceKeyword("(\.|^)line-cdn\.net\.edgesuite\.net$", 807)//
CALL CreateServiceKeyword("(\.|^)line-cdn\.net\.line-zero\.akadns\.net$", 807)//
CALL CreateServiceKeyword("(\.|^)line-scdn\.net$", 807)//
CALL CreateServiceKeyword("(\.|^)line-scdn\.net\.edgekey\.net$", 807)//
CALL CreateServiceKeyword("(\.|^)line-scdn\.net\.line-zero\.akadns\.net$", 807)//
CALL CreateServiceKeyword("(\.|^)line\.me$", 807)//
CALL CreateServiceKeyword("(\.|^)line\.me\.akadns\.net$", 807)//
CALL CreateServiceKeyword("(\.|^)line\.me\.edgekey\.net$", 807)//
CALL CreateServiceKeyword("(\.|^)line\.naver\.jp$", 807)//
CALL CreateServiceKeyword("(\.|^)linecorp\.com$", 807)//
CALL CreateServiceKeyword("(\.|^)today-line-me\.cdn\.ampproject\.org$", 807)//
CALL CreateService("RingCentral")//
CALL CreateServiceKeyword("(\.|^)glip\.com$", 808)//
CALL CreateServiceKeyword("(\.|^)ringcentral\.com$", 808)//
CALL CreateService("Skype")//
CALL CreateServiceKeyword("(\.|^)lync\.com$", 809)//
CALL CreateServiceKeyword("(\.|^)sfbassets\.com$", 809)//
CALL CreateServiceKeyword("(\.|^)skype-calling-missedcallsregistrar-prod-wus\.cloudapp\.net$", 809)//
CALL CreateServiceKeyword("(\.|^)skype-edf\.akadns\.net$", 809)//
CALL CreateServiceKeyword("(\.|^)skype-registar\.akadns\.net$", 809)//
CALL CreateServiceKeyword("(\.|^)skype\.akadns\.net$", 809)//
CALL CreateServiceKeyword("(\.|^)skype\.com$", 809)//
CALL CreateServiceKeyword("(\.|^)skypeassets\.com$", 809)//
CALL CreateServiceKeyword("(\.|^)skypedata\.akadns\.net$", 809)//
CALL CreateServiceKeyword("(\.|^)skypeecs-prod-use-0-b\.cloudapp\.net$", 809)//
CALL CreateServiceKeyword("(\.|^)skypeecs-prod-usw-0\.cloudapp\.net$", 809)//
CALL CreateServiceKeyword("(\.|^)skypeforbusiness\.com$", 809)//
CALL CreateService("Telehop")//
CALL CreateServiceKeyword("(\.|^)telehop\.com$", 810)//
CALL CreateServiceKeyword("(\.|^)telehoppbx\.com$", 810)//
CALL CreateService("Twilio")//
CALL CreateServiceKeyword("(\.|^)rtd-twilsock-239837944\.us-east-1\.elb\.amazonaws\.com$", 811)//
CALL CreateServiceKeyword("(\.|^)twilio\.com$", 811)//
CALL CreateService("Viber")//
CALL CreateServiceKeyword("(\.|^)viber-content\.s3\.amazonaws\.com$", 812)//
CALL CreateServiceKeyword("(\.|^)viber\.com$", 812)//
CALL CreateServiceKeyword("(\.|^)viber\.com\.edgesuite\.net$", 812)//
CALL CreateServiceKeyword("(\.|^)viber\.production\.dualstack\.edgekey\.net$", 812)//
CALL CreateService("VoIP.ms")//
CALL CreateServiceKeyword("(\.|^)voip\.ms$", 813)//
CALL CreateService("Voyant")//
CALL CreateServiceKeyword("(\.|^)vitelity\.com$", 814)//
CALL CreateServiceKeyword("(\.|^)vitelity\.net$", 814)//
CALL CreateServiceKeyword("(\.|^)voyant\.com$", 814)//
CALL CreateService("Webex")//
CALL CreateServiceKeyword("(\.|^)admin-webex-com-690861900\.us-east-2\.elb\.amazonaws\.com$", 815)//
CALL CreateServiceKeyword("(\.|^)ciscospark\.com$", 815)//
CALL CreateServiceKeyword("(\.|^)wbx2\.com$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.ca$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.co\.in$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.co\.it$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.co\.jp$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.co\.kr$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.co\.nz$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.co\.uk$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.com$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.com\.au$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.com\.br$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.com\.cn$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.com\.edgekey\.net$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.com\.hk$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.com\.mx$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.com\.ssl\.sc\.omtrdc\.net$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.de$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.es$", 815)//
CALL CreateServiceKeyword("(\.|^)webex\.fr$", 815)//
CALL CreateService("Zoom Video")//
CALL CreateServiceKeyword("(\.|^)zoom\.com$", 816)//
CALL CreateServiceKeyword("(\.|^)zoom\.com\.cn$", 816)//
CALL CreateServiceKeyword("(\.|^)zoom\.us$", 816)//
CALL CreateServiceKeyword("(\.|^)zoomgov\.com$", 816)//
CALL CreateService("ASUS")//
CALL CreateServiceKeyword("(\.|^)asus\.com$", 817)//
CALL CreateServiceKeyword("(\.|^)asus\.com\.cn$", 817)//
CALL CreateServiceKeyword("(\.|^)asus\.com\.tw$", 817)//
CALL CreateService("ASUSTOR")//
CALL CreateServiceKeyword("(\.|^)asustor\.com$", 818)//
CALL CreateService("Amazon Devices")//
CALL CreateServiceKeyword("(\.|^)amcs-tachyon\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)arcus-uswest\.amazon\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)d3p8zr0ffa9t17\.cloudfront\.net$", 819)//
CALL CreateServiceKeyword("(\.|^)device-messaging-na\.amazon\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)device-metrics-us-1\.amazon\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)device-metrics-us-2\.amazon\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)dp-discovery-na-ext\.amazon\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)dp-gw-na\.amazon\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)dp-rsm-prod\.amazon\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)fireoscaptiveportal\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)firetvcaptiveportal\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)fos5echocaptiveportal\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)ntp-fireos\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)pindorama\.amazon\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)softwareupdates\.amazon\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)spectrum\.s3\.amazonaws\.com$", 819)//
CALL CreateServiceKeyword("(\.|^)updates\.amazon\.com$", 819)//
CALL CreateService("Arlo")//
CALL CreateServiceKeyword("(\.|^)arlo\.com$", 820)//
CALL CreateServiceKeyword("(\.|^)arlo\.com\.cdn\.cloudflare\.net$", 820)//
CALL CreateServiceKeyword("(\.|^)arlodeviceprodlb-n-793345458\.eu-west-1\.elb\.amazonaws\.com$", 820)//
CALL CreateServiceKeyword("(\.|^)metric-collection-service-218867900\.eu-west-1\.elb\.amazonaws\.com$", 820)//
CALL CreateService("Aruba")//
CALL CreateServiceKeyword("(\.|^)arubainstanton\.com$", 821)//
CALL CreateServiceKeyword("(\.|^)arubanetworks\.com$", 821)//
CALL CreateService("Belkin")//
CALL CreateServiceKeyword("(\.|^)belkin\.com$", 822)//
CALL CreateService("BenQ")//
CALL CreateServiceKeyword("(\.|^)benq\.com$", 823)//
CALL CreateService("Brother")//
CALL CreateServiceKeyword("(\.|^)brother-ism\.com$", 824)//
CALL CreateServiceKeyword("(\.|^)brother-usa\.com$", 824)//
CALL CreateServiceKeyword("(\.|^)brother\.ca$", 824)//
CALL CreateServiceKeyword("(\.|^)brother\.co\.za$", 824)//
CALL CreateServiceKeyword("(\.|^)brother\.com$", 824)//
CALL CreateServiceKeyword("(\.|^)brother\.com\.mx$", 824)//
CALL CreateServiceKeyword("(\.|^)brother\.eu$", 824)//
CALL CreateServiceKeyword("(\.|^)brother\.fr$", 824)//
CALL CreateServiceKeyword("(\.|^)brother\.in$", 824)//
CALL CreateServiceKeyword("(\.|^)brother\.lu$", 824)//
CALL CreateServiceKeyword("(\.|^)brother\.tw$", 824)//
CALL CreateServiceKeyword("(\.|^)global\.brother$", 824)//
CALL CreateService("Buffalo Technology")//
CALL CreateServiceKeyword("(\.|^)buffalo-asia\.com$", 825)//
CALL CreateServiceKeyword("(\.|^)buffalo-technology\.com$", 825)//
CALL CreateServiceKeyword("(\.|^)buffalo\.jp$", 825)//
CALL CreateServiceKeyword("(\.|^)buffalotech\.com$", 825)//
CALL CreateService("Canon")//
CALL CreateServiceKeyword("(\.|^)c-ij\.com$", 826)//
CALL CreateServiceKeyword("(\.|^)c-wss\.com$", 826)//
CALL CreateServiceKeyword("(\.|^)canon$", 826)//
CALL CreateServiceKeyword("(\.|^)canon\.ca$", 826)//
CALL CreateServiceKeyword("(\.|^)canon\.com$", 826)//
CALL CreateServiceKeyword("(\.|^)canon\.jp$", 826)//
CALL CreateServiceKeyword("(\.|^)canon\.net$", 826)//
CALL CreateServiceKeyword("(\.|^)global\.canon$", 826)//
CALL CreateServiceKeyword("(\.|^)ugwdevice\.net$", 826)//
CALL CreateService("Cisco")//
CALL CreateServiceKeyword("(\.|^)cisco$", 827)//
CALL CreateServiceKeyword("(\.|^)cisco\.com$", 827)//
CALL CreateService("Cisco Meraki")//
CALL CreateServiceKeyword("(\.|^)meraki\.com$", 828)//
CALL CreateServiceKeyword("(\.|^)network-auth\.com$", 828)//
CALL CreateService("ClearPHONE")//
CALL CreateServiceKeyword("(\.|^)clearcellular\.org$", 829)//
CALL CreateServiceKeyword("(\.|^)clearos\.app$", 829)//
CALL CreateServiceKeyword("(\.|^)public-clearmdm\.s3\.us-west-2\.amazonaws\.com$", 829)//
CALL CreateService("Dell")//
CALL CreateServiceKeyword("(\.|^)dell-cidr\.akadns\.net$", 830)//
CALL CreateServiceKeyword("(\.|^)dell\.com$", 830)//
CALL CreateServiceKeyword("(\.|^)dell\.com-stls-dd\.edgesuite\.net$", 830)//
CALL CreateServiceKeyword("(\.|^)dell\.com-v2\.edgekey\.net$", 830)//
CALL CreateServiceKeyword("(\.|^)dell\.com\.br$", 830)//
CALL CreateServiceKeyword("(\.|^)dell\.com\.edgekey\.net$", 830)//
CALL CreateServiceKeyword("(\.|^)dell\.com\.edgekey\.net\.globalredir\.akadns\.net$", 830)//
CALL CreateServiceKeyword("(\.|^)dell\.demdex\.net$", 830)//
CALL CreateServiceKeyword("(\.|^)dellbackupandrecovery\.com$", 830)//
CALL CreateServiceKeyword("(\.|^)dellcdn\.com$", 830)//
CALL CreateServiceKeyword("(\.|^)dellinc\.tt\.omtrdc\.net$", 830)//
CALL CreateServiceKeyword("(\.|^)dellsupportcenter\.com$", 830)//
CALL CreateServiceKeyword("(\.|^)dellsupportcenter\.com\.edgekey\.net$", 830)//
CALL CreateServiceKeyword("(\.|^)delltechnologies\.com$", 830)//
CALL CreateService("Eero")//
CALL CreateServiceKeyword("(\.|^)e2ro\.com$", 831)//
CALL CreateServiceKeyword("(\.|^)eero\.com$", 831)//
CALL CreateService("Epson")//
CALL CreateServiceKeyword("(\.|^)epson\.ca$", 832)//
CALL CreateServiceKeyword("(\.|^)epson\.com$", 832)//
CALL CreateServiceKeyword("(\.|^)epson\.com\.jm$", 832)//
CALL CreateServiceKeyword("(\.|^)epson\.com\.mx$", 832)//
CALL CreateServiceKeyword("(\.|^)epson\.fr$", 832)//
CALL CreateServiceKeyword("(\.|^)epsonconnect\.com$", 832)//
CALL CreateService("Ezviz")//
CALL CreateServiceKeyword("(\.|^)ezvizlife\.com$", 833)//
CALL CreateService("FLIR Systems")//
CALL CreateServiceKeyword("(\.|^)flir\.com$", 834)//
CALL CreateService("Firewalla")//
CALL CreateServiceKeyword("(\.|^)firewalla\.com$", 835)//
CALL CreateServiceKeyword("(\.|^)firewalla\.encipher\.io$", 835)//
CALL CreateServiceKeyword("(\.|^)firewalla\.zendesk\.com$", 835)//
CALL CreateService("FreeIP")//
CALL CreateServiceKeyword("(\.|^)freeip\.com$", 836)//
CALL CreateService("GL.iNet")//
CALL CreateServiceKeyword("(\.|^)gl-inet\.com$", 837)//
CALL CreateService("Garmin")//
CALL CreateServiceKeyword("(\.|^)garmin\.cn$", 838)//
CALL CreateServiceKeyword("(\.|^)garmin\.com$", 838)//
CALL CreateServiceKeyword("(\.|^)garmin\.com\.cdn\.cloudflare\.net$", 838)//
CALL CreateService("Grandstream")//
CALL CreateServiceKeyword("(\.|^)gdms\.cloud$", 839)//
CALL CreateServiceKeyword("(\.|^)grandstream\.com$", 839)//
CALL CreateService("HP")//
CALL CreateServiceKeyword("(\.|^)hp\.com$", 840)//
CALL CreateServiceKeyword("(\.|^)hp\.demdex\.net$", 840)//
CALL CreateServiceKeyword("(\.|^)hp\.net$", 840)//
CALL CreateServiceKeyword("(\.|^)hpconnected\.com$", 840)//
CALL CreateServiceKeyword("(\.|^)hpe\.com$", 840)//
CALL CreateServiceKeyword("(\.|^)hpeprint\.com$", 840)//
CALL CreateService("Hikvision")//
CALL CreateServiceKeyword("(\.|^)hik-connect\.com$", 841)//
CALL CreateServiceKeyword("(\.|^)hikvision\.com$", 841)//
CALL CreateService("Honeywell")//
CALL CreateServiceKeyword("(\.|^)honeywell\.com$", 842)//
CALL CreateServiceKeyword("(\.|^)honeywell\.edgekey\.net$", 842)//
CALL CreateServiceKeyword("(\.|^)honeywell\.sc\.omtrdc\.net$", 842)//
CALL CreateServiceKeyword("(\.|^)honeywellaidc\.com$", 842)//
CALL CreateServiceKeyword("(\.|^)honeywellhome\.com$", 842)//
CALL CreateServiceKeyword("(\.|^)honeywellinternation\.tt\.omtrdc\.net$", 842)//
CALL CreateServiceKeyword("(\.|^)honeywellinternationalinc\.demdex\.net$", 842)//
CALL CreateServiceKeyword("(\.|^)honeywellstore\.com$", 842)//
CALL CreateServiceKeyword("(\.|^)resideo\.com$", 842)//
CALL CreateService("Huawei")//
CALL CreateServiceKeyword("(\.|^)dbank\.com$", 843)//
CALL CreateServiceKeyword("(\.|^)dbankcdn\.com$", 843)//
CALL CreateServiceKeyword("(\.|^)dbankcloud\.cn$", 843)//
CALL CreateServiceKeyword("(\.|^)dbankcloud\.com$", 843)//
CALL CreateServiceKeyword("(\.|^)dbankcloud\.eu$", 843)//
CALL CreateServiceKeyword("(\.|^)harmonyos\.com$", 843)//
CALL CreateServiceKeyword("(\.|^)hicloud\.com$", 843)//
CALL CreateServiceKeyword("(\.|^)huawei\.asia$", 843)//
CALL CreateServiceKeyword("(\.|^)huawei\.com$", 843)//
CALL CreateServiceKeyword("(\.|^)huaweicloud\.com$", 843)//
CALL CreateServiceKeyword("(\.|^)huaweistatic\.com$", 843)//
CALL CreateServiceKeyword("(\.|^)hwccpc\.com$", 843)//
CALL CreateServiceKeyword("(\.|^)vmall\.com$", 843)//
CALL CreateService("Juniper Networks")//
CALL CreateServiceKeyword("(\.|^)juniper\.net$", 844)//
CALL CreateService("Kindle")//
CALL CreateServiceKeyword("(\.|^)a4k\.amazon\.com$", 845)//
CALL CreateServiceKeyword("(\.|^)dogvgb9ujhybx\.cloudfront\.net$", 845)//
CALL CreateServiceKeyword("(\.|^)kindle-time\.amazon\.com$", 845)//
CALL CreateService("Kyocera")//
CALL CreateServiceKeyword("(\.|^)kyocera\.biz$", 846)//
CALL CreateServiceKeyword("(\.|^)kyocera\.com$", 846)//
CALL CreateServiceKeyword("(\.|^)kyods\.com$", 846)//
CALL CreateService("LG Smart TV")//
CALL CreateServiceKeyword("(\.|^)lgad\.cjpowercast\.com\.edgesuite\.net$", 847)//
CALL CreateServiceKeyword("(\.|^)lgappstv\.com$", 847)//
CALL CreateServiceKeyword("(\.|^)lgsmartad\.com$", 847)//
CALL CreateServiceKeyword("(\.|^)lgtvsdp\.com$", 847)//
CALL CreateServiceKeyword("(\.|^)netcast\.tv$", 847)//
CALL CreateServiceKeyword("(\.|^)ngfts\.lge\.com$", 847)//
CALL CreateService("LIFX")//
CALL CreateServiceKeyword("(\.|^)lifx\.co$", 848)//
CALL CreateServiceKeyword("(\.|^)lifx\.com$", 848)//
CALL CreateService("Lenovo")//
CALL CreateServiceKeyword("(\.|^)lenovo\.com$", 849)//
CALL CreateServiceKeyword("(\.|^)lenovo\.com\.akadns\.net$", 849)//
CALL CreateServiceKeyword("(\.|^)lenovo\.com\.cn$", 849)//
CALL CreateServiceKeyword("(\.|^)lenovo\.com\.edgekey\.net$", 849)//
CALL CreateServiceKeyword("(\.|^)lenovo\.com\.ssl\.d1\.sc\.omtrdc\.net$", 849)//
CALL CreateServiceKeyword("(\.|^)lenovo\.demdex\.net$", 849)//
CALL CreateServiceKeyword("(\.|^)lenovo\.tt\.omtrdc\.net$", 849)//
CALL CreateServiceKeyword("(\.|^)lenovoemc\.com$", 849)//
CALL CreateServiceKeyword("(\.|^)lenovomm\.cn$", 849)//
CALL CreateServiceKeyword("(\.|^)lenovomm\.com$", 849)//
CALL CreateService("Lexmark")//
CALL CreateServiceKeyword("(\.|^)lexmark\.com$", 850)//
CALL CreateService("Logitech")//
CALL CreateServiceKeyword("(\.|^)logitech\.com$", 851)//
CALL CreateService("Lorex")//
CALL CreateServiceKeyword("(\.|^)lorexservices\.com$", 852)//
CALL CreateServiceKeyword("(\.|^)lorextechnology\.com$", 852)//
CALL CreateService("MIUI OS")//
CALL CreateServiceKeyword("(\.|^)micloud\.xiaomi\.net$", 853)//
CALL CreateServiceKeyword("(\.|^)miui\.com$", 853)//
CALL CreateService("Meizu")//
CALL CreateServiceKeyword("(\.|^)flyme\.cn$", 854)//
CALL CreateServiceKeyword("(\.|^)flymeos\.com$", 854)//
CALL CreateServiceKeyword("(\.|^)meizu\.com$", 854)//
CALL CreateService("Meross")//
CALL CreateServiceKeyword("(\.|^)meross\.com$", 855)//
CALL CreateService("MiWiFi")//
CALL CreateServiceKeyword("(\.|^)miwifi\.com$", 856)//
CALL CreateService("MikroTik")//
CALL CreateServiceKeyword("(\.|^)mikrotik\.com$", 857)//
CALL CreateServiceKeyword("(\.|^)mt\.lv$", 857)//
CALL CreateServiceKeyword("(\.|^)routerboard\.com$", 857)//
CALL CreateService("Mitsubishi Electric")//
CALL CreateServiceKeyword("(\.|^)melcloud\.com$", 858)//
CALL CreateService("Nest")//
CALL CreateServiceKeyword("(\.|^)frontdoor-srt01-production-1909587911\.us-east-1\.elb\.amazonaws\.com$", 859)//
CALL CreateServiceKeyword("(\.|^)nest\.com$", 859)//
CALL CreateService("Netatmo")//
CALL CreateServiceKeyword("(\.|^)netatmo\.com$", 860)//
CALL CreateServiceKeyword("(\.|^)netatmo\.net$", 860)//
CALL CreateService("Netgear")//
CALL CreateServiceKeyword("(\.|^)advisor-z2-ngprod-1997768525\.us-west-2\.elb\.amazonaws\.com\.$", 861)//
CALL CreateServiceKeyword("(\.|^)d3jdtixm7cvu7y\.cloudfront\.net$", 861)//
CALL CreateServiceKeyword("(\.|^)netgear\.com$", 861)//
CALL CreateServiceKeyword("(\.|^)ngxcld\.com$", 861)//
CALL CreateService("Nimble Storage")//
CALL CreateServiceKeyword("(\.|^)nimblestorage\.com$", 862)//
CALL CreateService("OPPO")//
CALL CreateServiceKeyword("(\.|^)coloros\.com$", 863)//
CALL CreateServiceKeyword("(\.|^)oppo\.com$", 863)//
CALL CreateServiceKeyword("(\.|^)oppomobile\.com$", 863)//
CALL CreateService("Oculus")//
CALL CreateServiceKeyword("(\.|^)oculus\.c10r\.facebook\.com$", 864)//
CALL CreateServiceKeyword("(\.|^)oculus\.com$", 864)//
CALL CreateServiceKeyword("(\.|^)oculus\.xx\.fbcdn\.net$", 864)//
CALL CreateServiceKeyword("(\.|^)oculuscdn\.com$", 864)//
CALL CreateService("Peplink")//
CALL CreateServiceKeyword("(\.|^)peplink\.com$", 865)//
CALL CreateService("Philips")//
CALL CreateServiceKeyword("(\.|^)meethue\.com$", 866)//
CALL CreateServiceKeyword("(\.|^)philips-hue\.com$", 866)//
CALL CreateServiceKeyword("(\.|^)philips\.com$", 866)//
CALL CreateServiceKeyword("(\.|^)philips\.com\.cn$", 866)//
CALL CreateServiceKeyword("(\.|^)philips\.com\.cn\.edgekey\.net$", 866)//
CALL CreateServiceKeyword("(\.|^)philips\.com\.edgekey\.net$", 866)//
CALL CreateService("Polycom")//
CALL CreateServiceKeyword("(\.|^)poly\.com$", 867)//
CALL CreateServiceKeyword("(\.|^)polycom\.com$", 867)//
CALL CreateService("Powerley")//
CALL CreateServiceKeyword("(\.|^)powerley\.com$", 868)//
CALL CreateServiceKeyword("(\.|^)pwly\.io$", 868)//
CALL CreateService("QNAP Systems")//
CALL CreateServiceKeyword("(\.|^)myqnapcloud\.com$", 869)//
CALL CreateServiceKeyword("(\.|^)qcloud-pr-backend-390510218\.us-east-1\.elb\.amazonaws\.com$", 869)//
CALL CreateServiceKeyword("(\.|^)qnap\.com$", 869)//
CALL CreateService("Raspberry PI")//
CALL CreateServiceKeyword("(\.|^)raspberrypi\.org$", 870)//
CALL CreateServiceKeyword("(\.|^)raspbian\.freemirror\.org$", 870)//
CALL CreateService("Ring")//
CALL CreateServiceKeyword("(\.|^)ring\.com$", 871)//
CALL CreateServiceKeyword("(\.|^)ring\.com\.cdn\.cloudflare\.net$", 871)//
CALL CreateServiceKeyword("(\.|^)ring\.devices\.a2z\.com$", 871)//
CALL CreateServiceKeyword("(\.|^)rings\.solutions$", 871)//
CALL CreateService("Roku")//
CALL CreateServiceKeyword("(\.|^)dxedge-prod-lb-1585771072\.us-west-2\.elb\.amazonaws\.com$", 872)//
CALL CreateServiceKeyword("(\.|^)dxedge-prod-lb-389334914\.ap-southeast-1\.elb\.amazonaws\.com$", 872)//
CALL CreateServiceKeyword("(\.|^)dxedge-prod-lb-946522505\.us-east-1\.elb\.amazonaws\.com$", 872)//
CALL CreateServiceKeyword("(\.|^)roku\.com$", 872)//
CALL CreateServiceKeyword("(\.|^)rokutime\.com$", 872)//
CALL CreateServiceKeyword("(\.|^)w55c\.net$", 872)//
CALL CreateService("Ruckus Networks")//
CALL CreateServiceKeyword("(\.|^)ruckuswireless\.com$", 873)//
CALL CreateServiceKeyword("(\.|^)ruckuswireless\.com\.cdn\.cloudflare\.net$", 873)//
CALL CreateService("Salient Systems")//
CALL CreateServiceKeyword("(\.|^)salientconnect\.com$", 874)//
CALL CreateServiceKeyword("(\.|^)salientsys\.com$", 874)//
CALL CreateService("Samsung")//
CALL CreateServiceKeyword("(\.|^)game-mode\.net$", 875)//
CALL CreateServiceKeyword("(\.|^)gos-gsp\.io$", 875)//
CALL CreateServiceKeyword("(\.|^)pavv\.co\.kr$", 875)//
CALL CreateServiceKeyword("(\.|^)remotesamsung\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsung\.co\.kr$", 875)//
CALL CreateServiceKeyword("(\.|^)samsung\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsung\.com\.cn$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungcloud\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungcloudcdn\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungcloudsolution\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungcloudsolution\.net$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungelectronics\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsunghealth\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungiotcloud\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungknox\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungmobile\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungnyc\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungosp\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungotn\.net$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungpositioning\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungqbe\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungrm\.net$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungrs\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungsemi\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)samsungsetup\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)sbixby\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)secb2b\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)syncplusconfig\.s3\.amazonaws\.com$", 875)//
CALL CreateServiceKeyword("(\.|^)www\.samsungrm\.net$", 875)//
CALL CreateServiceKeyword("(\.|^)www\.smartthings\.com$", 875)//
CALL CreateService("Samsung Ads")//
CALL CreateServiceKeyword("(\.|^)adgear\.com$", 876)//
CALL CreateServiceKeyword("(\.|^)adgrx\.com$", 876)//
CALL CreateServiceKeyword("(\.|^)adgrx\.com\.tech\.akadns\.net$", 876)//
CALL CreateServiceKeyword("(\.|^)samsungacr\.com$", 876)//
CALL CreateServiceKeyword("(\.|^)samsungadhub\.com$", 876)//
CALL CreateServiceKeyword("(\.|^)samsungads\.com$", 876)//
CALL CreateServiceKeyword("(\.|^)samsungelectronicsamericainc\.demdex\.net$", 876)//
CALL CreateServiceKeyword("(\.|^)samsungtifa\.com$", 876)//
CALL CreateService("Samsung TV")//
CALL CreateServiceKeyword("(\.|^)internetat\.tv$", 877)//
CALL CreateServiceKeyword("(\.|^)samsungcloud\.tv$", 877)//
CALL CreateService("SiliconDust")//
CALL CreateServiceKeyword("(\.|^)hdhomerun\.com$", 878)//
CALL CreateServiceKeyword("(\.|^)silicondust\.com$", 878)//
CALL CreateService("SmartThings")//
CALL CreateServiceKeyword("(\.|^)smartthings\.com$", 879)//
CALL CreateService("SnapAV")//
CALL CreateServiceKeyword("(\.|^)ovrc\.com$", 880)//
CALL CreateServiceKeyword("(\.|^)snapav\.com$", 880)//
CALL CreateService("Sonos")//
CALL CreateServiceKeyword("(\.|^)onos\.com-v1\.edgekey\.net$", 881)//
CALL CreateServiceKeyword("(\.|^)sonos\.com$", 881)//
CALL CreateServiceKeyword("(\.|^)sonos\.radio$", 881)//
CALL CreateService("Sony TV")//
CALL CreateServiceKeyword("(\.|^)bravia\.dl\.playstation\.net$", 882)//
CALL CreateServiceKeyword("(\.|^)call\.me\.sel\.sony\.com$", 882)//
CALL CreateServiceKeyword("(\.|^)flingo\.tv$", 882)//
CALL CreateServiceKeyword("(\.|^)sony\.tv$", 882)//
CALL CreateServiceKeyword("(\.|^)sonybivstatic-a\.akamaihd\.net$", 882)//
CALL CreateService("Synology")//
CALL CreateServiceKeyword("(\.|^)synology\.com$", 883)//
CALL CreateServiceKeyword("(\.|^)synology\.me$", 883)//
CALL CreateService("TP-Link")//
CALL CreateServiceKeyword("(\.|^)tp-link\.com$", 884)//
CALL CreateServiceKeyword("(\.|^)tplinkcloud\.com$", 884)//
CALL CreateServiceKeyword("(\.|^)tplinkcloud\.com\.cn$", 884)//
CALL CreateServiceKeyword("(\.|^)tplinkcloudcom\.com$", 884)//
CALL CreateServiceKeyword("(\.|^)tplinkdns\.com$", 884)//
CALL CreateServiceKeyword("(\.|^)tplinknbu\.com$", 884)//
CALL CreateServiceKeyword("(\.|^)tplinkra\.com$", 884)//
CALL CreateService("Tenda")//
CALL CreateServiceKeyword("(\.|^)tenda\.com\.cn$", 885)//
CALL CreateServiceKeyword("(\.|^)tendacn\.com$", 885)//
CALL CreateServiceKeyword("(\.|^)tendawifi\.com$", 885)//
CALL CreateService("Tivo")//
CALL CreateServiceKeyword("(\.|^)tivo\.com$", 886)//
CALL CreateServiceKeyword("(\.|^)tivoservice\.com$", 886)//
CALL CreateService("Tuya Smart")//
CALL CreateServiceKeyword("(\.|^)tuya\.com$", 887)//
CALL CreateServiceKeyword("(\.|^)tuyaus\.com$", 887)//
CALL CreateService("Ubiquiti")//
CALL CreateServiceKeyword("(\.|^)d2cnv2pop2xy4v\.cloudfront\.net$", 888)//
CALL CreateServiceKeyword("(\.|^)r9sjd13s1zsp\.statuspage\.io$", 888)//
CALL CreateServiceKeyword("(\.|^)ubnt\.com$", 888)//
CALL CreateServiceKeyword("(\.|^)ui\.com$", 888)//
CALL CreateServiceKeyword("(\.|^)unifi-ai\.com$", 888)//
CALL CreateServiceKeyword("(\.|^)unms\.com$", 888)//
CALL CreateServiceKeyword("(\.|^)uwn\.com$", 888)//
CALL CreateService("VIZIO")//
CALL CreateServiceKeyword("(\.|^)tvinteractive\.tv$", 889)//
CALL CreateServiceKeyword("(\.|^)vizio\.com$", 889)//
CALL CreateService("Vestel Appliances")//
CALL CreateServiceKeyword("(\.|^)vestelinternational\.com$", 890)//
CALL CreateServiceKeyword("(\.|^)vstlsrv\.com$", 890)//
CALL CreateService("Vivo")//
CALL CreateServiceKeyword("(\.|^)vivo\.com$", 891)//
CALL CreateServiceKeyword("(\.|^)vivo\.com\.cn$", 891)//
CALL CreateServiceKeyword("(\.|^)vivoglobal\.com$", 891)//
CALL CreateServiceKeyword("(\.|^)vivoglobal\.com\.akamaized\.net$", 891)//
CALL CreateService("Withings")//
CALL CreateServiceKeyword("(\.|^)withings\.com$", 892)//
CALL CreateServiceKeyword("(\.|^)withings\.net$", 892)//
CALL CreateService("Wyze")//
CALL CreateServiceKeyword("(\.|^)wyze-device-alarm-cloud-ai\.s3\.us-west-2\.amazonaws\.com$", 893)//
CALL CreateServiceKeyword("(\.|^)wyze-device-alarm-file-ai\.s3\.us-west-2\.amazonaws\.com$", 893)//
CALL CreateServiceKeyword("(\.|^)wyze-device-log\.s3\.us-west-2\.amazonaws\.com$", 893)//
CALL CreateServiceKeyword("(\.|^)wyze\.com$", 893)//
CALL CreateServiceKeyword("(\.|^)wyzecam\.com$", 893)//
CALL CreateService("Xerox")//
CALL CreateServiceKeyword("(\.|^)xerox\.com$", 894)//
CALL CreateService("Xiaomi")//
CALL CreateServiceKeyword("(\.|^)mi\.com$", 895)//
CALL CreateServiceKeyword("(\.|^)xiaomi\.com$", 895)//
CALL CreateServiceKeyword("(\.|^)xiaomi\.net$", 895)//
CALL CreateService("Xiongmai")//
CALL CreateServiceKeyword("(\.|^)secu100\.net$", 896)//
CALL CreateServiceKeyword("(\.|^)xiongmaitech\.com$", 896)//
CALL CreateServiceKeyword("(\.|^)xmeye\.com$", 896)//
CALL CreateServiceKeyword("(\.|^)xmsecu\.com$", 896)//
CALL CreateService("Yealink")//
CALL CreateServiceKeyword("(\.|^)yealink\.com$", 897)//
CALL CreateService("Zyxel")//
CALL CreateServiceKeyword("(\.|^)zyxel\.com$", 898)//
CALL CreateServiceKeyword("(\.|^)zyxel\.com\.tw$", 898)//
CALL CreateService("iRobot")//
CALL CreateServiceKeyword("(\.|^)irobot\.com$", 899)//
CALL CreateServiceKeyword("(\.|^)irobotapi\.com$", 899)//
CALL CreateService("iXsystems")//
CALL CreateServiceKeyword("(\.|^)ixsystems\.com$", 900)//
CALL CreateService("iXsystems Updates")//
CALL CreateServiceKeyword("(\.|^)update-master\.ixsystems\.com$", 901)//
CALL CreateServiceKeyword("(\.|^)update\.ixsystems\.com$", 901)//
CALL CreateService("mydlink")//
CALL CreateServiceKeyword("(\.|^)mydlink\.com$", 902)//
CALL CreateService("LogMeIn")//
CALL CreateServiceKeyword("(\.|^)expertcity\.com$", 903)//
CALL CreateServiceKeyword("(\.|^)logmein-gateway\.com$", 903)//
CALL CreateServiceKeyword("(\.|^)logmein\.com$", 903)//
CALL CreateServiceKeyword("(\.|^)logmein\.com\.akadns\.net$", 903)//
CALL CreateServiceKeyword("(\.|^)logmeininc\.com$", 903)//
CALL CreateServiceKeyword("(\.|^)logmeinrescue\.com$", 903)//
CALL CreateService("RemotePC")//
CALL CreateServiceKeyword("(\.|^)www\.remotepc\.com$", 904)//
CALL CreateService("RescueAssist")//
CALL CreateServiceKeyword("(\.|^)gotoassist\.com$", 905)//
CALL CreateServiceKeyword("(\.|^)www\.logmeinrescue\.com$", 905)//
CALL CreateService("TeamViewer")//
CALL CreateServiceKeyword("(\.|^)client-teamviewer-com\.trafficmanager\.net\.$", 906)//
CALL CreateServiceKeyword("(\.|^)teamviewer\.cn$", 906)//
CALL CreateServiceKeyword("(\.|^)teamviewer\.com$", 906)//
CALL CreateServiceKeyword("(\.|^)teamviewer\.com\.cdn\.cloudflare\.net$", 906)//
CALL CreateServiceKeyword("(\.|^)teamviewer\.us$", 906)//
CALL CreateService("Akamai")//
CALL CreateServiceKeyword("(\.|^)akadns\.net$", 907)//
CALL CreateServiceKeyword("(\.|^)akagtm\.org$", 907)//
CALL CreateServiceKeyword("(\.|^)akahost\.net$", 907)//
CALL CreateServiceKeyword("(\.|^)akam\.net$", 907)//
CALL CreateServiceKeyword("(\.|^)akamai\.com$", 907)//
CALL CreateServiceKeyword("(\.|^)akamai\.net$", 907)//
CALL CreateServiceKeyword("(\.|^)akamaiedge\.net$", 907)//
CALL CreateServiceKeyword("(\.|^)akamaientrypoint\.net$", 907)//
CALL CreateServiceKeyword("(\.|^)akamaihd\.net$", 907)//
CALL CreateServiceKeyword("(\.|^)akamaistream\.net$", 907)//
CALL CreateServiceKeyword("(\.|^)akamaitech\.net$", 907)//
CALL CreateServiceKeyword("(\.|^)akamaitechnologies\.com$", 907)//
CALL CreateServiceKeyword("(\.|^)akamaitechnologies\.fr$", 907)//
CALL CreateServiceKeyword("(\.|^)akamaized\.net$", 907)//
CALL CreateServiceKeyword("(\.|^)akasecure\.net$", 907)//
CALL CreateServiceKeyword("(\.|^)akstat\.io$", 907)//
CALL CreateServiceKeyword("(\.|^)edgekey\.net$", 907)//
CALL CreateServiceKeyword("(\.|^)edgesuite\.net$", 907)//
CALL CreateService("Amazon CloudFront")//
CALL CreateServiceKeyword("(\.|^)cloudfront\.net$", 908)//
CALL CreateService("CDN77")//
CALL CreateServiceKeyword("(\.|^)cdn77\.com$", 909)//
CALL CreateServiceKeyword("(\.|^)cdn77\.org$", 909)//
CALL CreateService("CloudFlare")//
CALL CreateServiceKeyword("(\.|^)cloudflare\.com$", 910)//
CALL CreateServiceKeyword("(\.|^)cloudflare\.net$", 910)//
CALL CreateServiceKeyword("(\.|^)cloudflareinsights\.com$", 910)//
CALL CreateServiceKeyword("(\.|^)cloudflaressl\.com$", 910)//
CALL CreateService("Fastly")//
CALL CreateServiceKeyword("(\.|^)fastly\.com$", 911)//
CALL CreateServiceKeyword("(\.|^)fastly\.net$", 911)//
CALL CreateServiceKeyword("(\.|^)fastlylb\.net$", 911)//
CALL CreateService("Google CDN")//
CALL CreateServiceKeyword("(\.|^)cache\.google\.com$", 912)//
CALL CreateServiceKeyword("(\.|^)cache\.googlevideo\.com$", 912)//
CALL CreateService("Limelight Networks")//
CALL CreateServiceKeyword("(\.|^)limelight\.com$", 913)//
CALL CreateServiceKeyword("(\.|^)llnwd\.net$", 913)//
CALL CreateServiceKeyword("(\.|^)llnwi\.net$", 913)//
CALL CreateService("Lumen CDN")//
CALL CreateServiceKeyword("(\.|^)footprint\.net$", 914)//
CALL CreateService("StackPath")//
CALL CreateServiceKeyword("(\.|^)highwinds\.com$", 915)//
CALL CreateServiceKeyword("(\.|^)stackpath\.com$", 915)//
CALL CreateServiceKeyword("(\.|^)stackpathedge\.net$", 915)//
CALL CreateService("Alibaba Cloud")//
CALL CreateServiceKeyword("(\.|^)alibaba\.tanx\.com$", 916)//
CALL CreateServiceKeyword("(\.|^)alibabacloud\.com$", 916)//
CALL CreateServiceKeyword("(\.|^)alibabadns\.com$", 916)//
CALL CreateServiceKeyword("(\.|^)alibabausercontent\.com$", 916)//
CALL CreateServiceKeyword("(\.|^)aliyuncs\.com$", 916)//
CALL CreateServiceKeyword("(\.|^)cdngslb\.com$", 916)//
CALL CreateService("Amazon AWS")//
CALL CreateServiceKeyword("(\.|^)amazon-dss\.com$", 917)//
CALL CreateServiceKeyword("(\.|^)amazonaws\.com$", 917)//
CALL CreateServiceKeyword("(\.|^)amazonaws\.com\.cn$", 917)//
CALL CreateServiceKeyword("(\.|^)amazonaws\.org$", 917)//
CALL CreateServiceKeyword("(\.|^)amazonses\.com$", 917)//
CALL CreateServiceKeyword("(\.|^)amazonwebservices\.com$", 917)//
CALL CreateServiceKeyword("(\.|^)aws$", 917)//
CALL CreateServiceKeyword("(\.|^)aws\.amazon\.com$", 917)//
CALL CreateServiceKeyword("(\.|^)awsglobalaccelerator\.com$", 917)//
CALL CreateServiceKeyword("(\.|^)awsstatic\.com$", 917)//
CALL CreateServiceKeyword("(\.|^)elasticbeanstalk\.com$", 917)//
CALL CreateService("DigitalOcean")//
CALL CreateServiceKeyword("(\.|^)digitalocean\.com$", 918)//
CALL CreateService("Google Cloud")//
CALL CreateServiceKeyword("(\.|^)cloud\.google\.com$", 919)//
CALL CreateServiceKeyword("(\.|^)cloudfunctions\.net$", 919)//
CALL CreateServiceKeyword("(\.|^)run\.app$", 919)//
CALL CreateService("Heroku")//
CALL CreateServiceKeyword("(\.|^)heroku\.com$", 920)//
CALL CreateServiceKeyword("(\.|^)herokuapp\.com$", 920)//
CALL CreateServiceKeyword("(\.|^)herokucdn\.com$", 920)//
CALL CreateServiceKeyword("(\.|^)herokussl\.com$", 920)//
CALL CreateServiceKeyword("(\.|^)production-evvnt-plugin-herokuapp-com\.global\.ssl\.fastly\.net$", 920)//
CALL CreateServiceKeyword("(\.|^)storemapper-herokuapp-com\.global\.ssl\.fastly\.net$", 920)//
CALL CreateService("Hetzner")//
CALL CreateServiceKeyword("(\.|^)hetzner\.com$", 921)//
CALL CreateServiceKeyword("(\.|^)hetzner\.de$", 921)//
CALL CreateService("HostGator")//
CALL CreateServiceKeyword("(\.|^)hostgator\.cl$", 922)//
CALL CreateServiceKeyword("(\.|^)hostgator\.co$", 922)//
CALL CreateServiceKeyword("(\.|^)hostgator\.com$", 922)//
CALL CreateServiceKeyword("(\.|^)hostgator\.com\.br$", 922)//
CALL CreateServiceKeyword("(\.|^)hostgator\.com\.tr$", 922)//
CALL CreateServiceKeyword("(\.|^)hostgator\.in$", 922)//
CALL CreateServiceKeyword("(\.|^)hostgator\.mx$", 922)//
CALL CreateServiceKeyword("(\.|^)hostgator\.sg$", 922)//
CALL CreateService("IBM Cloud")//
CALL CreateServiceKeyword("(\.|^)cloud\.ibm\.com$", 923)//
CALL CreateServiceKeyword("(\.|^)mybluemix\.net$", 923)//
CALL CreateService("Linode")//
CALL CreateServiceKeyword("(\.|^)linode\.com$", 924)//
CALL CreateServiceKeyword("(\.|^)linode\.com\.cdn\.cloudflare\.net$", 924)//
CALL CreateServiceKeyword("(\.|^)linodestore\.com$", 924)//
CALL CreateService("Lumen")//
CALL CreateServiceKeyword("(\.|^)lumen\.com$", 925)//
CALL CreateService("Manitu Hosting")//
CALL CreateServiceKeyword("(\.|^)manitu\.de$", 926)//
CALL CreateServiceKeyword("(\.|^)manitu\.net$", 926)//
CALL CreateService("Microsoft Azure")//
CALL CreateServiceKeyword("(\.|^)aadrm\.com$", 927)//
CALL CreateServiceKeyword("(\.|^)azure-api\.us$", 927)//
CALL CreateServiceKeyword("(\.|^)azure-dns\.com$", 927)//
CALL CreateServiceKeyword("(\.|^)azure-dns\.info$", 927)//
CALL CreateServiceKeyword("(\.|^)azure-dns\.net$", 927)//
CALL CreateServiceKeyword("(\.|^)azure-dns\.org$", 927)//
CALL CreateServiceKeyword("(\.|^)azure\.akadns\.net$", 927)//
CALL CreateServiceKeyword("(\.|^)azure\.com$", 927)//
CALL CreateServiceKeyword("(\.|^)azure\.microsoft$", 927)//
CALL CreateServiceKeyword("(\.|^)azure\.microsoft\.com$", 927)//
CALL CreateServiceKeyword("(\.|^)azure\.us$", 927)//
CALL CreateServiceKeyword("(\.|^)azurecr\.us$", 927)//
CALL CreateServiceKeyword("(\.|^)azuredns-prd\.info$", 927)//
CALL CreateServiceKeyword("(\.|^)azuredns-prd\.org$", 927)//
CALL CreateServiceKeyword("(\.|^)azureedge\.net$", 927)//
CALL CreateServiceKeyword("(\.|^)azureedge\.us$", 927)//
CALL CreateServiceKeyword("(\.|^)azurefd\.net$", 927)//
CALL CreateServiceKeyword("(\.|^)azurefd\.us$", 927)//
CALL CreateServiceKeyword("(\.|^)azurewebsites\.net$", 927)//
CALL CreateServiceKeyword("(\.|^)cloudapp\.net$", 927)//
CALL CreateServiceKeyword("(\.|^)dns-tm\.com$", 927)//
CALL CreateServiceKeyword("(\.|^)edgedns-tm\.info$", 927)//
CALL CreateServiceKeyword("(\.|^)trafficmanager\.net$", 927)//
CALL CreateServiceKeyword("(\.|^)usgovcloudapi\.net$", 927)//
CALL CreateServiceKeyword("(\.|^)usgovtrafficmanager\.net$", 927)//
CALL CreateServiceKeyword("(\.|^)vsassets\.io$", 927)//
CALL CreateServiceKeyword("(\.|^)windowsazure\.com$", 927)//
CALL CreateService("OVHcloud")//
CALL CreateServiceKeyword("(\.|^)ovh\.com$", 928)//
CALL CreateServiceKeyword("(\.|^)ovh\.net$", 928)//
CALL CreateService("QX.net")//
CALL CreateServiceKeyword("(\.|^)qx\.net$", 929)//
CALL CreateService("Rackspace")//
CALL CreateServiceKeyword("(\.|^)emailsrvr\.com$", 930)//
CALL CreateServiceKeyword("(\.|^)rackspace\.com$", 930)//
CALL CreateService("Squarespace")//
CALL CreateServiceKeyword("(\.|^)sqspcdn\.com$", 931)//
CALL CreateServiceKeyword("(\.|^)squarespace-cdn\.com$", 931)//
CALL CreateServiceKeyword("(\.|^)squarespace-mail\.com$", 931)//
CALL CreateServiceKeyword("(\.|^)squarespace\.com$", 931)//
CALL CreateServiceKeyword("(\.|^)squarespace\.map\.fastly\.net$", 931)//
CALL CreateService("Tencent Cloud")//
CALL CreateServiceKeyword("(\.|^)cloud\.tencent\.com$", 932)//
CALL CreateServiceKeyword("(\.|^)myqcloud\.com$", 932)//
CALL CreateServiceKeyword("(\.|^)qcloud\.com$", 932)//
CALL CreateServiceKeyword("(\.|^)tencent-cloud\.com$", 932)//
CALL CreateService("Whois")//
CALL CreateServiceKeyword("(\.|^)whois\.com$", 933)//
CALL CreateService("Zayo")//
CALL CreateServiceKeyword("(\.|^)zayo\.com$", 934)//
CALL CreateService("Zenlayer")//
CALL CreateServiceKeyword("(\.|^)zenlayer\.com$", 935)//