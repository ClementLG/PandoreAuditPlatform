# PANDORE SENDER


# IMPORTS======================================================================

import mysql.connector # mysql-connector-python package
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
            print("Error connecting to MariaDB Platform: "+str(e))
            sys.exit(1)
        print("Pandore agent connected to "+str(db_host)+" on db "+str(database))

    def create_service(self, name):
        self.cursor.callproc('CreateService', [str(name),])
        self.conn.commit()

    def create_capture(self, name, start_time, end_time, description, interface, connection_type):
        self.cursor.callproc('CreateCapture', [name, start_time, end_time, description, interface, connection_type])
        self.conn.commit()

    def get_capture_id(self, name):
        self.cursor.execute("SELECT Capture_ID FROM Capture WHERE Capture_Name=\""+str(name)+"\";")
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



