import mysql.connector
from typing import Optional
from application import configuration, pandoreException
from application.models import *
from datetime import datetime

class PandoreDB:

    def __init__(self):
        self.conn = mysql.connector.connect(
            user=configuration.DB_USER,
            password=configuration.DB_PASSWORD,
            host=configuration.DB_HOST,
            port=configuration.DB_PORT,
            database=configuration.DB
        )
        self.cursor = self.conn.cursor(dictionary=True)

    # Other
    def close_db(self):
        self.conn.close()

    # Configuration
    def get_configuration(self) -> PandoreConfiguration:
        self.cursor.callproc('ReadConfiguration')
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreConfiguration(
                    int(res["NUTRISCORE_REFERENCE_FREQUENCY"]), 
                    float(res["NUTRISCORE_REFERENCE_DEBIT"]), 
                    int(res["NUTRISCORE_REFERENCE_DIVERSITY"]), 
                    int(res["NUTRISCORE_WEIGHT_FREQUENCY"]), 
                    int(res["NUTRISCORE_WEIGHT_DEBIT"]), 
                    int(res["NUTRISCORE_WEIGHT_DIVERSITY"]), 
                    float(res["NUTRISCORE_SIGMOIDE_SLOPE"]), 
                    int(res["NUTRISCORE_AVERAGE_TYPE"]), 
                    str(res["SNIFFER_API_ADDRESS"]))
        return None

    def update_configuration(self, config: PandoreConfiguration) -> None:
        self.cursor.callproc('UpdateConfiguration', [
            config.NUTRISCORE_REFERENCE_FREQUENCY, 
            config.NUTRISCORE_REFERENCE_DEBIT, 
            config.NUTRISCORE_REFERENCE_DIVERSITY, 
            config.NUTRISCORE_WEIGHT_FREQUENCY, 
            config.NUTRISCORE_WEIGHT_DEBIT, 
            config.NUTRISCORE_WEIGHT_DIVERSITY, 
            config.NUTRISCORE_SIGMOIDE_SLOPE, 
            config.NUTRISCORE_AVERAGE_TYPE, 
            config.SNIFFER_API_ADDRESS
            ])
        self.conn.commit()

    # Capture
    def get_running_captures(self) -> list[PandoreCapture]:
        captures = []
        self.cursor.callproc('ReadRunningCapture')
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                captures.append(PandoreCapture(
                    int(res["Capture_ID"]), 
                    str(res["Capture_Name"]), 
                    res["Capture_StartTime"], 
                    res["Capture_EndTime"] or None, 
                    str(res["Capture_Description"]), 
                    str(res["Capture_Interface"]), 
                    str(res["Capture_ConnectionType"]), 
                    int(res["Capture_UE_Inactivity_Timeout"])
                    ))
        return captures

    def update_capture(self, capture: PandoreCapture) -> None:
        self.cursor.callproc('UpdateCapture', [
            capture.ID, 
            capture.Name, 
            capture.StartTime, 
            capture.EndTime, 
            capture.Description, 
            capture.Interface, 
            capture.ConnectionType, 
            capture.InactivityTimeout
            ])
        self.conn.commit()

    def find_saved_captures(self) -> list[PandoreCapture]:
        captures = []
        self.cursor.callproc('ReadSavedCaptures')
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                captures.append(PandoreCapture(
                    int(res["Capture_ID"]), 
                    str(res["Capture_Name"]), 
                    res["Capture_StartTime"], 
                    res["Capture_EndTime"] or None, 
                    str(res["Capture_Description"]), 
                    str(res["Capture_Interface"]), 
                    str(res["Capture_ConnectionType"]), 
                    int(res["Capture_UE_Inactivity_Timeout"])
                    ))
        return captures

    def find_capture_by_id(self, id: int) -> PandoreCapture:
        if not id:
            return None
        self.cursor.callproc('ReadCaptureByID', [int(id)])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreCapture(
                    int(res["Capture_ID"]), 
                    str(res["Capture_Name"]), 
                    res["Capture_StartTime"], 
                    res["Capture_EndTime"] or None, 
                    str(res["Capture_Description"]), 
                    str(res["Capture_Interface"]), 
                    str(res["Capture_ConnectionType"]), 
                    int(res["Capture_UE_Inactivity_Timeout"])
                    )
        return res[0]

    def get_capture_service_stat(self, id: int) -> list[PandoreServiceStat]:
        stats = []
        self.cursor.callproc('ReadCaptureServicesStats', [int(id)])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                stats.append(PandoreServiceStat(
                    res["Service_Name"],
                    float(res["UpTrafic"]),
                    float(res["DownTrafic"])
                    ))
        return stats

    def get_capture_total_trafic(self, id: int):
        trafic = {"Up": 0, "Down": 0}
        self.cursor.callproc('ReadCaptureTotalTrafic', [int(id)])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                if res["DOWN"] is not None:
                    trafic["Down"] = int(res["DOWN"])
                if res["UP"] is not None:
                    trafic["Up"] = int(res["UP"])
        return trafic

    # Capture request
    def find_all_capture_request(self, id: int) -> list[PandoreCaptureRequest]:
        requests = []
        self.cursor.callproc('ReadRequestsByCaptureID', [int(id), 0])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                    requests.append(PandoreCaptureRequest(
                        int(res["CaptureRequest_ID"]),
                        int(res["CaptureRequest_PacketSize"]), 
                        bool(res["CaptureRequest_Direction"]), 
                        res["CaptureRequest_DateTime"], 
                        str(res["CaptureRequest_Protocol"]), 
                        self.find_server_by_id(int(res["CaptureRequest_Server"])), 
                        self.find_capture_by_id(int(res["CaptureRequest_Capture"]))
                        ))
        return requests

    def find_all_capture_request_not_detailed(self, id: int) -> list[PandoreCaptureRequestNotDetailed]:
        requests = []
        self.cursor.callproc('ReadRequestsByCaptureID', [int(id), 1])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                requests.append(PandoreCaptureRequestNotDetailed(
                    int(res["CaptureRequest_ID"]), 
                    int(res["CaptureRequest_PacketSize"]), 
                    bool(res["CaptureRequest_Direction"]), 
                    res["CaptureRequest_DateTime"], 
                    str(res["CaptureRequest_Protocol"]), 
                    str(res["Server_Address"]), 
                    str(res["DNS_Value"]), 
                    int(res["CaptureRequest_Capture"])
                    ))
        
        return sorted(requests, key=lambda request: request.DateTime)

    # DNS
    def find_all_dns(self) -> list[PandoreDNS]:
        DNSs = []
        self.cursor.callproc('ReadAllDNS')
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                DNSs.append(PandoreDNS(int(res["DNS_ID"]), str(res["DNS_Value"])))
        return DNSs

    def find_dns_by_id(self, id: int) -> Optional[PandoreDNS]:
        if not id:
            return None
        self.cursor.callproc('ReadDNSByID', [int(id)])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreDNS(int(res["DNS_ID"]), str(res["DNS_Value"]))
        return None

    def find_dns_by_value(self, value: str) -> Optional[PandoreDNS]:
        if not value:
            return None
        self.cursor.callproc('ReadDNSByValue', [value])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreDNS(int(res["DNS_ID"]), str(res["DNS_Value"]))
        return None

    def create_dns(self, dns: PandoreDNS) -> None:
        if not dns:
            raise pandoreException.PandoreException("DNS is missing")
        elif not dns.Value or len(dns.Value) < 1:
            raise pandoreException.PandoreException("DNS value minimum size is 1")
        elif len(dns.Value) > 1000:
            raise pandoreException.PandoreException("DNS value maximum size is 1000")
        elif not self.find_dns_by_value(dns.Value):
            self.cursor.callproc('CreateDNS', [dns.Value])
            self.conn.commit()

    # Server
    def find_incomplete_servers(self) -> list[PandoreServer]:
        servers = []
        self.cursor.callproc('ReadIncompleteServers')
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                servers.append(PandoreServer(
                    int(res["Server_ID"]), 
                    str(res["Server_Address"]), 
                    self.find_dns_by_id(res["Server_DNS"]), 
                    self.find_service_by_id(res["Server_Service"])
                    ))
        return servers
   
    def find_server_by_id(self, id: int) -> Optional[PandoreServer]:
        if not id:
            return None
        self.cursor.callproc('ReadServerByID', [int(id)])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreServer(
                    int(res["Server_ID"]), 
                    str(res["Server_Address"]), 
                    self.find_dns_by_id(res["Server_DNS"]), 
                    self.find_service_by_id(res["Server_Service"])
                    )
        return None

    def find_server_by_address(self, address: str) -> Optional[PandoreServer]:
        if not address:
            return None
        self.cursor.callproc('ReadServerByAddress', [address])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreServer(
                    int(res["Server_ID"]), 
                    str(res["Server_Address"]), 
                    self.find_dns_by_id(res["Server_DNS"]), 
                    self.find_service_by_id(res["Server_Service"])
                    )
        return None

    def create_server_dns(self, service: PandoreService, ip: str, domain_name: str) -> None:
        if not service:
            raise pandoreException.PandoreException("Service is missing");
        elif not ip:
            raise pandoreException.PandoreException("Server address is missing")
        elif not self.find_service_by_id(service.ID):
            raise pandoreException.PandoreException("Unknown service")
        elif len(ip) < 1:
            raise pandoreException.PandoreException("Server address minimum size is 1")
        elif len(ip) > 1000:
            raise pandoreException.PandoreException("Server address maximum size is 1000")
        elif domain_name and len(domain_name) < 1:
            raise pandoreException.PandoreException("Server DNS minimum size is 1")
        elif domain_name and len(domain_name) > 1000:
            raise pandoreException.PandoreException("Server DNS maximum size is 1000")
        else:
            if self.find_server_by_address(ip):
                raise pandoreException.PandoreException("This server address is already used");
            self.cursor.callproc('CreateServerString', [ip, service.ID, domain_name])
            self.conn.commit()

    def remove_service_from_server(self, id: int) -> None:
        if not id:
            raise pandoreException.PandoreException("Server not found");
        server = self.find_server_by_id(id)
        if not server:
            raise pandoreException.PandoreException("Invalid server");
        server.Service = None
        self.update_server(server)

    def update_server(self, server: PandoreServer) -> None:
        if not server.ID:
            raise pandoreException.PandoreException("Server not found");
        elif not server.Address:
            raise pandoreException.PandoreException("Server address is missing")
        elif not self.find_server_by_id(server.ID):
            raise pandoreException.PandoreException("Invalid server")
        elif len(server.Address) < 1:
            raise pandoreException.PandoreException("Server address minimum size is 1")
        elif len(server.Address) > 1000:
            raise pandoreException.PandoreException("Server address maximum size is 1000")
        elif server.Service and not self.find_service_by_id(server.Service.ID):
            raise pandoreException.PandoreException("Invalid server service")
        elif server.DNS and not self.find_dns_by_id(server.DNS.ID):
            raise pandoreException.PandoreException("Invalid server dns")
        else:
            existingServer = self.find_server_by_address(server.Address);
            if(existingServer and existingServer.ID != server.ID):
                raise pandoreException.PandoreException("This server address already exists")
            else:
                self.cursor.callproc('UpdateServer', [
                    server.ID, 
                    server.Address, 
                    None if server.Service is None else server.Service.ID, 
                    None if server.DNS is None else server.DNS.ID
                    ])
                self.conn.commit()

    # Service
    def find_all_services(self) -> list[PandoreService]:
        services = []
        self.cursor.callproc('ReadAllServices')
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                services.append(PandoreService(
                    int(res["Service_ID"]), 
                    str(res["Service_Name"])
                    ))
        return services

    def find_service_by_id(self, id: int) -> Optional[PandoreService]:
        if not id:
            return None
        self.cursor.callproc('ReadServiceByID', [int(id)])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreService(
                    int(res["Service_ID"]), 
                    str(res["Service_Name"])
                    )
        return None

    def find_service_by_name(self, name: str) -> Optional[PandoreService]:
        if not name:
            return None
        self.cursor.callproc('ReadServiceByName', [name])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreService(
                    int(res["Service_ID"]), 
                    str(res["Service_Name"])
                    )
        return None

    def find_service_all_servers(self, id: int, details: bool) -> list[PandoreServer]:
        servers = []
        service = self.find_service_by_id(id)
        self.cursor.callproc('ReadServersByServiceID', [id, details])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                servers.append(PandoreServer(
                    int(res["Server_ID"]), 
                    str(res["Server_Address"]), 
                    self.find_dns_by_id(res["Server_DNS"]), 
                    service
                    ))
        return servers

    def create_service(self, service: PandoreService) -> None:
        if not service:
            raise pandoreException.PandoreException("Service is missing")
        elif not service.Name or len(service.Name) < 1:
            raise pandoreException.PandoreException("Service name minimum size is 1")
        elif len(service.Name) > 255:
            raise pandoreException.PandoreException("Service name can't exceed 255 characters")
        elif self.find_service_by_name(service.Name):
            raise pandoreException.PandoreException("This service name is already used")
        self.cursor.callproc('CreateService', [str(service.Name)])
        self.conn.commit()

    def delete_service(self, service: PandoreService) -> None:
        if not service:
            raise pandoreException.PandoreException("Service is missing")
        else:
            self.cursor.callproc('DeleteServiceByID', [int(service.ID)])
            self.conn.commit()

    def update_service(self, service: PandoreService) -> None:
        if not service:
            raise pandoreException.PandoreException("Service is missing")
        elif not service.Name or len(service.Name) < 1:
            raise pandoreException.PandoreException("Service name minimum size is 1")
        elif len(service.Name) > 255:
            raise pandoreException.PandoreException("Service name can't exceed 255 characters")
        else:
            checkService = self.find_service_by_name(service.Name)
            if checkService and checkService.ID != service.ID:
                raise pandoreException.PandoreException("This service name is already used")
            else:
                self.cursor.callproc('UpdateService', [
                    service.ID, 
                    service.Name
                    ])
                self.conn.commit()

    # ServiceKeyword
    def find_all_service_keyword(self) -> list[PandoreServiceKeyword]:
        keywords = []
        self.cursor.callproc('ReadAllServiceKeyword', [])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                keywords.append(PandoreServiceKeyword(
                    int(res["ServiceKeyword_ID"]), 
                    str(res["ServiceKeyword_Value"]), 
                    PandoreService(int(res["Service_ID"]), str(res["Service_Name"]))
                    ))
        return keywords

    def find_all_keyword_by_service(self, id: int) -> list[PandoreServiceKeyword]:
        keywords = []
        if not id:
            raise pandoreException.PandoreException("Service is missing")
        else:
            service = self.find_service_by_id(id)
            if not service:
                raise pandoreException.PandoreException("Invalid service");
            else:
                self.cursor.callproc('ReadServiceKeywordByService', [service.ID])
                for result in self.cursor.stored_results():
                    for res in result.fetchall():
                        keywords.append(PandoreServiceKeyword(
                            int(res["ServiceKeyword_ID"]), 
                            str(res["ServiceKeyword_Value"]), 
                            service
                            ))
        return keywords

    def create_service_keyword(self, keyword: PandoreServiceKeyword) -> None:
        if not PandoreServiceKeyword:
            raise pandoreException.PandoreException("Keyword is missing")
        elif len(keyword.Value) > 255:
            raise pandoreException.PandoreException("Keyword value can't exceed 255 characters")
        else:
            self.cursor.callproc('CreateServiceKeyword', [
                str(keyword.Value), 
                keyword.Service.ID
                ])
            self.conn.commit()

    def delete_keyword(self, keyword: PandoreServiceKeyword) -> None:
        if not PandoreServiceKeyword:
            raise pandoreException.PandoreException("Keyword is missing")
        else:
            self.cursor.callproc('DeleteServiceKeywordByID', [keyword.ID])
            self.conn.commit()