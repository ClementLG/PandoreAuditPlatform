import ipaddress, time, re
from application import pandoreDB
from application.models import *

class PandoreAnalytics:
    __numberOfUnknownDNS: int
    __numberOfProcessedDNS: int
    __stopAnalytics: bool
    __analyticsRunning: bool

    def __init__(self):
        self.__numberOfProcessedDNS = 0
        self.__numberOfUnknownDNS = 0
        self.__stopAnalytics = False
        self.__analyticsRunning = False

    def run_analytics(self, unknownDNSs: list[PandoreServer], dictionary: list[PandoreServiceKeyword]):
        try:
            if not self.isAnalyticsRunning():
                self.__analyticsRunning = True
                self.__numberOfUnknownDNS = len(unknownDNSs)
                self.__numberOfProcessedDNS = 0
                self.__stopAnalytics = False

                for dns in unknownDNSs:
                    if(self.__stopAnalytics): break

                    if dns.Value == "localhost":
                        dns.Service = PandoreService(1, "Intranet service")
                    else:
                        bestMatch = None
                        for i in range(len(dictionary)):
                            res = re.search(dictionary[i].Value, dns.Value)
                            if res:
                                if bestMatch is None:
                                    bestMatch = dictionary[i]
                                else:
                                    if len(bestMatch.Value) < len(dictionary[i].Value):
                                        bestMatch = dictionary[i]
                        if bestMatch is not None:
                            dns.Service = bestMatch.Service

                    self.__numberOfProcessedDNS = self.__numberOfProcessedDNS + 1

                    if dns.Service is not None:
                        db = pandoreDB.PandoreDB()
                        db.update_dns(dns)
                        db.close_db()
                self.__analyticsRunning = False
        except Exception as e:
            if 'db' in locals():
                db.close_db()
            self.__analyticsRunning = False

    def stop_analytics(self):
        self.__stopAnalytics = True
        while self.isAnalyticsRunning(): 
            time.sleep(0.5)
        return None

    def isAnalyticsRunning(self) -> bool:
        return self.__analyticsRunning

    def getNumberOfUnknownDNS(self) -> int:
        if not self.isAnalyticsRunning():
            return 0
        else:
            return self.__numberOfUnknownDNS

    def getNumberOfProcessedDNS(self) -> int:
        if not self.isAnalyticsRunning():
            return 0
        else:
            return self.__numberOfProcessedDNS