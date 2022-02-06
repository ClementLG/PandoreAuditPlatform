import multiprocessing, ipaddress, threading, socket, time
from ipwhois import IPWhois
from whois import whois
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

    def run_analytics(self, unknownServers: list[PandoreServer], dictionary: list[PandoreAnalyticsServiceKeywords], analyticsTimeout: int):
        try:
            self.__runningConfiguration = PandoreAnalyticsRunningConfiguration(len(unknownServers), dictionary)
            numberOfThreads = multiprocessing.cpu_count()
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
        for server in unknownServers:
            try:
                if(configuration.getStopAnalytics()): break

                #domain_name = None

                #if (ipaddress.ip_address(server.Address).is_private):
                #    domain_name = "Intranet"
                #else:
                #    if server.DNS:
                #        domain_name = server.DNS.Value
                #    else:



                service = None

                #if (ipaddress.ip_address(server.Address).is_private):
                #    print("Str 0 - Service found for " + ip + " : Intranet service")
                #    for val in self.__runningConfiguration.getDicitonary():
                #        if val.Service.Name == "Intranet service":
                #            return val.Service
                #if server.DNS:
                #    for val in self.__runningConfiguration.getDicitonary():
                #        for keyword in val.Keywords:
                #            if(keyword.Value in server.DNS.Value):
                #                print("Str 1 - Service found for " + server.DNS.Value + " : " + val.Service.Name)
                #                service = val.Service

                #if(configuration.getStopAnalytics()): break

                #if server.DNS is not None:
                #    try:
                #        dns_info = whois(server.DNS.Value)
                #        for val in self.__runningConfiguration.getDicitonary():
                #            for keyword in val.Keywords:
                #                if(keyword.Value in dns_info["org"].lower()):
                #                    print("Str 2 - Service found for " + server.DNS.Value + " : " + val.Service.Name)
                #                    service = val.Service
                #    except Exception as e:
                #        pass

                #if(configuration.getStopAnalytics()): break

                try:
                    socket.setdefaulttimeout(3)
                    host_info = socket.gethostbyaddr(server.Address)
                    for val in self.__runningConfiguration.getDicitonary():
                        for keyword in val.Keywords:
                            if(keyword.Value in host_info[0].lower()):
                                print("Str 3 - Service found for " + ip + " : " +  val.Service.Name)
                                service = val.Service
                except Exception as e:
                    pass

                #if(configuration.getStopAnalytics()): break

                #try:
                #    ip_info = IPWhois(server.Address).lookup_rdap()
                #    for val in self.__runningConfiguration.getDicitonary():
                #        for keyword in val.Keywords:
                #            if(keyword.Value in ip_info['asn_description'].lower()):
                #                print("Str 4 - Service found for " + ip + " : " +  val.Service.Name)
                #                service = val.Service
                #except Exception as e:
                #    pass

                configuration.incrementNumberOfProcessedServers()
                if service:
                    db = pandoreDB.PandoreDB()
                    server.Service = service
                    db.update_server(server)
                    db.close_db()
            except Exception as e:
                if 'db' in locals():
                    db.close_db()

    def __split_list(self, list, n):
        k, m = divmod(len(list), n)
        return (list[i*k+min(i, m):(i+1)*k+min(i+1, m)] for i in range(n))
