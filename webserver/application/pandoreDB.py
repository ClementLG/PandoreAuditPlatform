import mysql.connector
import sys
from application import configuration
from application import pandoreException

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

    def create_request(self, packet_size, direction, protocol, server_id, dns_id, capture):
        self.cursor().callproc('CreateRequest', [packet_size, direction, protocol, server_id, dns_id, capture])
        self.conn.commit()

    def create_request_string(self, packet_size, direction, protocol, server_ip, dns_name, capture):
        self.conn.cursor().callproc('CreateRequestString', [packet_size, direction, protocol, server_ip, dns_name, capture])
        self.conn.commit()

    # Capture
    def get_running_capture(self):
        self.cursor.callproc('ReadRunningCapture')
        for result in self.cursor.stored_results():
            res = result.fetchall()
        if res:
            return res[0]
        else:
            return None

    def create_capture(self, name, start_time, end_time, description, interface, connection_type):
        self.cursor.callproc('CreateCapture', [name, start_time, end_time, description, interface, connection_type])
        self.conn.commit()

    def update_capture(self, id, name, start_time, end_time, description, interface, connection_type):
        self.cursor.callproc('UpdateCapture', [id, name, start_time, end_time, description, interface, connection_type])
        self.conn.commit()

    def get_capture_id(self, name):
        self.cursor.execute("SELECT Capture_ID FROM Capture WHERE Capture_Name=\"" + str(name) + "\";")
        result = self.cursor.fetchall()
        return result[0][0]

    def find_saved_captures(self):
        self.cursor.callproc('ReadSavedCaptures')
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res

    def find_capture_by_id(self, id):
        self.cursor.callproc('ReadCaptureByID', [int(id)])
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res[0]

    def get_capture_service_stat(self, id):
        self.cursor.callproc('ReadCaptureServicesStats', [int(id)])
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res

    def get_capture_total_trafic(self, id):
        self.cursor.callproc('ReadCaptureTotalTrafic', [int(id)])
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res[0]

    # Capture request
    def find_all_capture_request(self, id, details):
        self.cursor.callproc('ReadRequestsByCaptureID', [int(id), int(bool(details))])
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res

    # DNS
    def find_all_dns(self):
        self.cursor.callproc('ReadAllDNS')
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res

    def find_dns_by_id(self, id):
        self.cursor.callproc('ReadDNSByID', [int(id)])
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res

    # Server
    def find_incomplete_servers(self):
       self.cursor.callproc('ReadIncompleteServers')
       for result in self.cursor.stored_results():
           res = result.fetchall()
       return res
   
    def find_server_by_id(self, id):
        self.cursor.callproc('ReadServerByID', [int(id)])
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res[0]

    def find_server_by_address(self, address):
        self.cursor.callproc('ReadServerByAddress', [address])
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res

    def create_server_dns(self, service, ip, domain_name):
        if not service:
            raise pandoreException.PandoreException("Service is missing");
        elif not ip:
            raise pandoreException.PandoreException("Server address is missing")
        elif not self.find_service_by_id(service):
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
            self.cursor.callproc('CreateServerString', [ip, service, domain_name])
            self.conn.commit()

    def remove_service_from_server(self, id):
        if not id:
            raise pandoreException.PandoreException("Server not found");
        server = self.find_server_by_id(id)
        if not server:
            raise pandoreException.PandoreException("Invalid server");
        self.update_server(server[0], server[1], None, server[2] or None)

    def update_server(self, id, address, service, dns):
        if not id:
            raise pandoreException.PandoreException("Server not found");
        elif not address:
            raise pandoreException.PandoreException("Server address is missing")
        elif not self.find_server_by_id(id):
            raise pandoreException.PandoreException("Invalid server")
        elif len(address) < 1:
            raise pandoreException.PandoreException("Server address minimum size is 1")
        elif len(address) > 1000:
            raise pandoreException.PandoreException("Server address maximum size is 1000")
        elif service and not self.find_service_by_id(service):
            raise pandoreException.PandoreException("Invalid server service")
        elif dns and not self.find_dns_by_id(dns):
            raise pandoreException.PandoreException("Invalid server dns")
        else:
            existingServer = self.find_server_by_address(address);
            if(existingServer and existingServer[0][0] != int(id)):
                raise pandoreException.PandoreException("This server address already exists")
            else:
                self.cursor.callproc('UpdateServer', [id, address, service, dns])
                self.conn.commit()

   # Service
    def find_all_services(self):
        self.cursor.callproc('ReadAllServices')
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res

    def find_service_by_id(self, id):
        self.cursor.callproc('ReadServiceByID', [int(id)])
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res[0]

    def find_service_by_name(self, name):
        self.cursor.callproc('ReadServiceByName', [name])
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res

    def find_service_all_servers(self, id, details):
        self.cursor.callproc('ReadServersByServiceID', [id, details])
        for result in self.cursor.stored_results():
            res = result.fetchall()
        return res

    def create_service(self, name):
        if not name:
            raise pandoreException.PandoreException("Service name is missing");
        elif (name == '' or len(name) < 1):
            raise pandoreException.PandoreException("Service name minimum size is 1");
        elif(len(name) > 255):
            raise pandoreException.PandoreException("Service name can't exceed 255 characters");
        elif(len(self.find_service_by_name(name)) > 0):
            raise pandoreException.PandoreException("This service name is already used");
        self.cursor.callproc('CreateService', [str(name), ])
        self.conn.commit()