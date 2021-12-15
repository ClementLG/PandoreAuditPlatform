from typing import Optional
import mysql.connector
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
        self.cursor = self.conn.cursor()

    # Other
    def close_db(self):
        self.conn.close()

    # Capture
    def get_running_capture(self) -> Optional[PandoreCapture]:
        self.cursor.callproc('ReadRunningCapture')
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreCapture(int(res[0]), str(res[1]), res[2], res[3] or None, str(res[4]), str(res[5]), str(res[6]))
        return None

    def update_capture(self, capture: PandoreCapture) -> None:
        self.cursor.callproc('UpdateCapture', [capture.ID, capture.Name, capture.StartTime, capture.EndTime, capture.Description, capture.Interface, capture.ConnectionType])
        self.conn.commit()

    def find_saved_captures(self) -> list[PandoreCapture]:
        captures = []
        self.cursor.callproc('ReadSavedCaptures')
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                captures.append(PandoreCapture(int(res[0]), str(res[1]), res[2], res[3] or None, str(res[4]), str(res[5]), str(res[6])))
        return captures

    def find_capture_by_id(self, id: int) -> PandoreCapture:
        if not id:
            return None
        self.cursor.callproc('ReadCaptureByID', [int(id)])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreCapture(int(res[0]), str(res[1]), res[2], res[3] or None, str(res[4]), str(res[5]), str(res[6]))
        return res[0]

    def get_capture_service_stat(self, id: int):
        self.cursor.callproc('ReadCaptureServicesStats', [int(id)])
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res

    def get_capture_total_trafic(self, id: int):
        self.cursor.callproc('ReadCaptureTotalTrafic', [int(id)])
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res[0]

    # Capture request
    def find_all_capture_request(self, id: int) -> list[PandoreCaptureRequest]:
        requests = []
        self.cursor.callproc('ReadRequestsByCaptureID', [int(id), 0])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                requests.append(PandoreCaptureRequest(int(res[0]), int(res[1]), bool(res[2]), res[3], str(res[4]), self.find_server_by_id(int(res[5])), self.find_capture_by_id(int(res[6]))))
        return requests

    def find_all_capture_request_not_detailed(self, id: int) -> list[PandoreCaptureRequestNotDetailed]:
        requests = []
        self.cursor.callproc('ReadRequestsByCaptureID', [int(id), 1])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                requests.append(PandoreCaptureRequestNotDetailed(int(res[0]), int(res[1]), bool(res[2]), res[3], str(res[4]), str(res[8]), res[12], int(res[6])))
        
        return sorted(requests, key=lambda request: request.DateTime)

    # DNS
    def find_all_dns(self) -> list[PandoreDNS]:
        DNSs = []
        self.cursor.callproc('ReadAllDNS')
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                DNSs.append(PandoreDNS(int(res[0]), str(res[1])))
        return DNSs

    def find_dns_by_id(self, id: int) -> Optional[PandoreDNS]:
        if not id:
            return None
        self.cursor.callproc('ReadDNSByID', [int(id)])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreDNS(int(res[0]), str(res[1]))
        return None

    def find_dns_by_value(self, value: str) -> Optional[PandoreDNS]:
        if not value:
            return None
        self.cursor.callproc('ReadDNSByValue', [value])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreDNS(int(res[0]), str(res[1]))
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
                servers.append(PandoreServer(int(res[0]), str(res[1]), self.find_dns_by_id(res[3]), self.find_service_by_id(res[2])))
        return servers
   
    def find_server_by_id(self, id: int) -> Optional[PandoreServer]:
        if not id:
            return None
        self.cursor.callproc('ReadServerByID', [int(id)])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreServer(int(res[0]), str(res[1]), self.find_dns_by_id(res[2]), self.find_service_by_id(res[3]))
        return None

    def find_server_by_address(self, address: str) -> Optional[PandoreServer]:
        if not address:
            return None
        self.cursor.callproc('ReadServerByAddress', [address])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreServer(int(res[0]), str(res[1]), self.find_dns_by_id(res[2]), self.find_service_by_id(res[3]))
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
                self.cursor.callproc('UpdateServer', [server.ID, server.Address, None if server.Service is None else server.Service.ID, None if server.DNS is None else server.DNS.ID])
                self.conn.commit()

    # Service
    def find_all_services(self) -> list[PandoreService]:
        services = []
        self.cursor.callproc('ReadAllServices')
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                services.append(PandoreService(int(res[0]), str(res[1])))
        return services

    def find_service_by_id(self, id: int) -> Optional[PandoreService]:
        if not id:
            return None
        self.cursor.callproc('ReadServiceByID', [int(id)])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreService(int(res[0]), str(res[1]))
        return None

    def find_service_by_name(self, name: str) -> Optional[PandoreService]:
        if not name:
            return None
        self.cursor.callproc('ReadServiceByName', [name])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return PandoreService(int(res[0]), str(res[1]))
        return None

    def find_service_all_servers(self, id: int, details: bool) -> list[PandoreServer]:
        servers = []
        service = self.find_service_by_id(id)
        self.cursor.callproc('ReadServersByServiceID', [id, details])
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                servers.append(PandoreServer(int(res[0]), str(res[1]), self.find_dns_by_id(res[2]), service))
        return servers

    def create_service(self, service: PandoreService) -> None:
        if not service:
            raise pandoreException.PandoreException("Service is missing");
        elif not service.Name or len(service.Name) < 1:
            raise pandoreException.PandoreException("Service name minimum size is 1");
        elif len(service.Name) > 255:
            raise pandoreException.PandoreException("Service name can't exceed 255 characters");
        elif self.find_service_by_name(service.Name):
            raise pandoreException.PandoreException("This service name is already used");
        self.cursor.callproc('CreateService', [str(service.Name)])
        self.conn.commit()