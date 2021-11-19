# PANDORE SENDER


# IMPORTS======================================================================

import mysql.connector
import sys


# VARIABLES=====================================================================

# CLASS=========================================================================

class PandoreSenderV2:

    def __init__(self, db_host, db_port, user, password, database):
        try:
            self.conn = mysql.connector.connect(
                user=user,
                password=password,
                host=db_host,
                port=db_port,
                database=database
            )
            self.cursor = self.conn.cursor()
        except mysql.connector.Error as e:
            print(f"Error connecting to MariaDB Platform: {e}")
            sys.exit(1)
        print(f"Pandore agent connected to {db_host} on db {database}")

    def create_service(self, name):
        self.cursor.callproc('CreateService', [f"{name}",])
        self.conn.commit()

    def create_capture(self, name, start_time, end_time, description, interface, connection_type):
        self.cursor.callproc('CreateCapture', [name, start_time, end_time, description, interface, connection_type])
        self.conn.commit()

    def get_capture_id(self, name):
        self.cursor.execute(f"SELECT Capture_ID FROM Capture WHERE Capture_Name=\"{name}\";")
        result = self.cursor.fetchall()
        return result[0][0]

    def create_request(self, packet_size, direction, protocol, server_id, dns_id, capture):
        self.cursor().callproc('CreateRequest', [packet_size,direction, protocol, server_id, dns_id, capture])
        self.conn.commit()

    def create_request_string(self, packet_size, direction, protocol, server_ip, dns_name, capture):
        self.conn.cursor().callproc('CreateRequestString', [packet_size,direction, protocol, server_ip, dns_name, capture])
        self.conn.commit()

    def close_db(self):
        self.conn.close()



