import ipaddress, time, re
from application import pandoreDB
from application.models import *

class PandoreAnalytics:
    __numberOfUnknownServers: int
    __numberOfProcessedServers: int
    __stopAnalytics: bool
    __analyticsRunning: bool

    def __init__(self):
        self.__numberOfProcessedServers = 0
        self.__numberOfUnknownServers = 0
        self.__stopAnalytics = False
        self.__analyticsRunning = False

    def run_analytics(self, unknownServers: list[PandoreServer], dictionary: list[PandoreServiceKeyword]):
        try:
            if not self.isAnalyticsRunning():
                self.__analyticsRunning = True
                self.__numberOfUnknownServers = len(unknownServers)
                self.__numberOfProcessedServers = 0
                self.__stopAnalytics = False

                for server in unknownServers:
                    if(self.__stopAnalytics): break

                    domain_name = None
          
                    if (ipaddress.ip_address(server.Address).is_private):
                        domain_name = "Intranet"
                    else:
                        if server.DNS:
                            domain_name = server.DNS.Value

                    if domain_name is not None:
                        if domain_name == "Intranet":
                            server.Service = PandoreService(1, "Intranet service", 0)
                        else:
                            bestMatch = None
                            for i in range(len(dictionary)):
                                res = re.search(dictionary[i].Value, domain_name)
                                if res:
                                    if bestMatch is None:
                                        bestMatch = dictionary[i]
                                    else:
                                        if len(bestMatch.Value) < len(dictionary[i].Value):
                                            bestMatch = dictionary[i]
                            if bestMatch is not None:
                                server.Service = bestMatch.Service
 
                    self.__numberOfProcessedServers = self.__numberOfProcessedServers + 1

                    if server.Service is not None:
                        db = pandoreDB.PandoreDB()
                        db.update_server(server)
                        db.close_db()
                self.__analyticsRunning = False
        except Exception as e:
            if 'db' in locals():
                db.close_db()
            self.stop_analytics()

    def stop_analytics(self):
        self.__stopAnalytics = True
        while self.isAnalyticsRunning(): 
            time.sleep(0.5)
        return None

    def isAnalyticsRunning(self) -> bool:
        return self.__analyticsRunning

    def getNumberOfUnknownServers(self) -> int:
        if not self.isAnalyticsRunning():
            return 0
        else:
            return self.__numberOfUnknownServers

    def getNumberOfProcessedServers(self) -> int:
        if not self.isAnalyticsRunning():
            return 0
        else:
            return self.__numberOfProcessedServers