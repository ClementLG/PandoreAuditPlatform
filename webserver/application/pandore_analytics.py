# PANDORE ANALYTICS


# IMPORTS======================================================================

from ipwhois import IPWhois  # IP
from whois import whois  # DomainName
import socket # DomainName
import multiprocessing # thread
import ipaddress
from multiprocessing import Queue
from application import configuration
from application.models import *


# VARIABLES=====================================================================

# CLASS=========================================================================

class PandoreAnalytics:

    dictionary: list[PandoreAnalyticsServiceKeywords]

    def __init__(self, dictionary = list[PandoreAnalyticsServiceKeywords]):
        self.dictionary = dictionary
        print("Pandore analytics is running")

    def analyse_ip_dns(self, timeout: int, ip, dns=None):

        # Check for private adresses
        if (ipaddress.ip_address(ip).is_private):
            print("Str 0 - Service found for " + ip + " : Intranet service")
            for val in self.dictionary:
                if val.Service.Name == "Intranet service":
                    return val.Service
            return None

        if dns:
            # 1st try to parse the dns
            for val in self.dictionary:
                for keyword in val.Keywords:
                    if(keyword.Value in dns):
                        print("Str 1 - Service found for " + dns + " : " + val.Service.Name)
                        return val.Service

        queue = Queue()
        thread = multiprocessing.Process(target=self.process_analyse_ip_dns, args=(queue, ip, dns,))
        thread.start()
        thread.join(timeout)

        if thread.is_alive():
            print("Timeout for ip = " + ip)
            thread.terminate()
            thread.join()
            return None
        
        return queue.get()

    def process_analyse_ip_dns(self, queue, ip, dns=None):
        if dns is not None:
            # 2nd to find the service using the DNS lookup
            try:
                dns_info = whois(dns)
                for val in self.dictionary:
                    for keyword in val.Keywords:
                        if(keyword.Value in dns_info["org"].lower()):
                            print("Str 2 - Service found for " + dns + " : " + val.Service.Name)
                            queue.put(val.Service)
            except:
                pass

        # 3rd try a reverse DNS lookup
        try:
            socket.setdefaulttimeout(3)
            host_info = socket.gethostbyaddr(ip)
            for val in self.dictionary:
                for keyword in val.Keywords:
                    if(keyword.Value in host_info[0].lower()):
                        print("Str 3 - Service found for " + ip + " : " +  val.Service.Name)
                        queue.put(val.Service)
        except:
            pass

        # 4th to find the service using the IP lookup
        try:
            ip_info = IPWhois(ip).lookup_rdap()
            for val in self.dictionary:
                for keyword in val.Keywords:
                    if(keyword.Value in ip_info['asn_description'].lower()):
                        print("Str 4 - Service found for " + ip + " : " +  val.Service.Name)
                        queue.put(val.Service)
        except:
            pass

        queue.put(None)