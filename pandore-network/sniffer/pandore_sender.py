# PANDORE SENDER


# IMPORTS======================================================================

import mariadb
import sys


# VARIABLES=====================================================================

# CLASS=========================================================================

class PandoreSender:

    def __init__(self, db_host, db_port, user, password, database):
        try:
            self.conn = mariadb.connect(
                user=user,
                password=password,
                host=db_host,
                port=db_port,
                database=database

            )
        except mariadb.Error as e:
            print(f"Error connecting to MariaDB Platform: {e}")
            sys.exit(1)
        print(f"Pandore agent connected to {db_host} on db {database}")

    def create_service(self, name):
        self.conn.cursor().callproc('CreateService', [f"{name}",])
        self.conn.commit()

    def create_capture(self, name, start_time, end_time, description, interface, connection_type):
        self.conn.cursor().callproc('CreateCapture', [name, start_time, end_time, description, interface, connection_type ])
        self.conn.commit()

    #def create_request(self, packet_size, direction, timestamp, protocol, server, capture):
    #    self.conn.cursor().callproc('CreateService', [f"{name}", ])
    #    self.conn.commit()



