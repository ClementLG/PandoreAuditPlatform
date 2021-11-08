# Linked between DNS/Server and service


# IMPORTS======================================================================

import mariadb
import sys
from pprint import pprint
from ipwhois import IPWhois


# VARIABLES=====================================================================

# CLASS=========================================================================
class Linker:

    def __init__(self, db_host, db_port, user, password, database):
        try:
            self.conn = mariadb.connect(
                user=user,
                password=password,
                host=db_host,
                port=db_port,
                database=database

            )
            self.cursor = self.conn.cursor()
        except mariadb.Error as e:
            print(f"Error connecting to MariaDB Platform: {e}")
            sys.exit(1)
        print(f"Pandore agent connected to {db_host} on db {database}")

    def getServiceFromIp(self,ip):
        obj = IPWhois(ip)
        res = obj.lookup_rdap(root_ent_check=False).network().name()







