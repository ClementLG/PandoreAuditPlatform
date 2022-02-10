import multiprocessing, ipaddress, threading, socket, time, re
from multiprocessing import Queue, Value
from application import pandoreDB, configuration
from application.models import *
from application.pandore_analytics_running_configuration import PandoreAnalyticsRunningConfiguration
from threading import Event

class PandoreAnalytics:

    __runningConfiguration: PandoreAnalyticsRunningConfiguration

    def __init__(self):
        self.__runningConfiguration = None
        print("Pandore analytics is running")

    def run_analytics(self, unknownServers: list[PandoreServer], dictionary: list[PandoreServiceKeyword], analyticsTimeout: int):
        try:
            self.__runningConfiguration = PandoreAnalyticsRunningConfiguration(len(unknownServers), dictionary)
            #numberOfThreads = multiprocessing.cpu_count()
            numberOfThreads = 1
            splittedUnknownServers = list(self.__split_list(unknownServers, numberOfThreads))
            threads = []
            for i in range(numberOfThreads):
                t = threading.Thread(target=self.__analytics_worker_thread, args=(splittedUnknownServers[i], self.__runningConfiguration, analyticsTimeout,))
                threads.append(t)
                t.start()
            for thread in threads:
                thread.join()
            self.__runningConfiguration = None
        except Exception as e:
            print(str(e))
            self.stop_analytics()
            self.__runningConfiguration = None

    def stop_analytics(self):
        if self.isAnalyticsRunning():
            self.__runningConfiguration.setStopAnalytics()
            while self.isAnalyticsRunning(): 
                time.sleep(0.5)
            return None

    def isAnalyticsRunning(self) -> bool:
        return self.__runningConfiguration is not None

    def getNumberOfUnknownServers(self) -> int:
        if not self.isAnalyticsRunning():
            return 0
        else:
            return self.__runningConfiguration.getNumberOfUnknownServers()

    def getNumberOfProcessedServers(self) -> int:
        if not self.isAnalyticsRunning():
            return 0
        else:
            return self.__runningConfiguration.getNumberOfProcessedServers()

    def __analytics_worker_thread(self, unknownServers: list[PandoreServer], configuration: PandoreAnalyticsRunningConfiguration, analyticsTimeout: int):
        dictionnary_keywords = self.__runningConfiguration.getDicitonary()
        for server in unknownServers:
            try:
                if(configuration.getStopAnalytics()): break

                print("IP = " + server.Address)

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
                        for i in range(len(dictionnary_keywords)):
                            res = re.search(dictionnary_keywords[i].Value, domain_name)
                            if res:
                                if bestMatch is None:
                                    bestMatch = dictionnary_keywords[i]
                                else:
                                    if len(bestMatch.Value) < len(dictionnary_keywords[i].Value):
                                        bestMatch = dictionnary_keywords[i]
                        if bestMatch is not None:
                            server.Service = bestMatch.Service
                else:
                    print("no domain name")

                configuration.incrementNumberOfProcessedServers()
                if server.Service is not None:
                    db = pandoreDB.PandoreDB()
                    db.update_server(server)
                    db.close_db()
            except Exception as e:
                if 'db' in locals():
                    db.close_db()

    def __split_list(self, list, n):
        k, m = divmod(len(list), n)
        return (list[i*k+min(i, m):(i+1)*k+min(i+1, m)] for i in range(n))