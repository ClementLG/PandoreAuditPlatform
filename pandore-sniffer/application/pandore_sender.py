# PANDORE SENDER

# -*- coding: utf-8 -*-
# INFO=========================================================================
__project__ = "Pandore"
__maintainer__ = "Clement LE GRUIEC"
__version__ = "1.0"
__Created__ = "09/10/2021"
__team__ = ["Clement LE GRUIEC", "Hugo HOUILLON", "Salma CHAHMI", "Nathan OLBORSKI"]
__school__ = "IMT Atlantique"
__course__ = "3rd year engineering project"
__subject__ = "Characterization of the sneaky traffic generated by mobile applications"
__description__ = "The agent is the application which allow to send the network traffic in a formatted manner " \
                  "in a second application which will carry out more specific and cumbersome processing."

# IMPORTS======================================================================

import mysql.connector  # mysql-connector-python package
import sys


# VARIABLES=====================================================================

# CLASS=========================================================================

class PandoreSender:

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
            print("Error connecting to MariaDB Platform: " + str(e))
            sys.exit(1)
        print("Pandore agent connected to " + str(db_host) + " on db " + str(database))

    def create_service(self, name):
        self.cursor.callproc('CreateService', [str(name), ])
        self.conn.commit()

    def create_capture(self, name, start_time, end_time, description, interface, connection_type):
        self.cursor.callproc('CreateCapture', [name, start_time, end_time, description, interface, connection_type, 10])
        self.conn.commit()
        for result in self.cursor.stored_results():
            for res in result.fetchall():
                return int(res[0])

    def update_capture(self, id, name, start_time, end_time, description, interface, connection_type):
        self.cursor.callproc('UpdateCapture', [id, name, start_time, end_time, description, interface, connection_type, 10])
        self.conn.commit()

    def update_capture_end_time(self, time, capture_id):
        self.cursor.callproc('UpdateCaptureEndTime', [capture_id, time])
        self.conn.commit()

    def get_capture_id(self, name, start_time, end_time, description, interface, connection_type):
        self.cursor.execute("SELECT Capture_ID FROM Capture WHERE Capture_Name = \"" + str(name) + "\" AND Capture_StartTime = \"" + str(self.hour_rounder(start_time)) + "\" AND Capture_Description = \"" + str(description) + "\" AND Capture_Interface = \"" + str(interface) + "\" AND Capture_ConnectionType = \"" + str(connection_type) + "\";")
        # self.cursor.execute("SELECT Capture_ID FROM Capture WHERE Capture_Name=\"" + str(name) + "\";")
        result = self.cursor.fetchall()
        return result[0][0]

    def create_request(self, packet_size, direction, protocol, server_id, dns_id, capture):
        self.cursor().callproc('CreateRequest', [packet_size, direction, protocol, server_id, dns_id, capture])
        self.conn.commit()

    def create_request_string(self, packet_size, direction, protocol, server_ip, dns_name, capture):
        self.conn.cursor().callproc('CreateRequestString',
                                    [packet_size, direction, protocol, server_ip, dns_name, capture])
        self.conn.commit()

    def create_server_dns(self, ip, domain_name):
        self.cursor.callproc('CreateServerString', [ip, domain_name])
        self.conn.commit()

    def path_blank_end_time(self, time):
        self.cursor.execute("SELECT Capture_ID FROM Capture WHERE Capture_EndTime IS NULL ORDER BY Capture_ID DESC;")
        result = self.cursor.fetchall()
        if result is not None:
            self.cursor.callproc('UpdateCaptureEndTime', [result[0][0], time])
            self.conn.commit()
            return True
        return False

    def path_blank_end_time_by_id(self, time, capture_id):
        self.cursor.callproc('UpdateCaptureEndTime', [capture_id, time])
        self.conn.commit()

    def hour_rounder(self, t):
        return t.replace(microsecond=0)

    def close_db(self):
        self.conn.close()
