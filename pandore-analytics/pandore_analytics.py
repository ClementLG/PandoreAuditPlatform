# PANDORE ANALYTICS


# IMPORTS======================================================================

from ipwhois import IPWhois  # IP
from whois import whois  # DomainName
from services_dictionary import SERVICES_DICTIONARY


# VARIABLES=====================================================================

# CLASS=========================================================================

class PandoreAnalytics:

    def __init__(self):
        print("Pandore analytics is running")

    def analyse_ip_dns(self, ip, dns=None):
        service = None
        # 1st try to parse the dns
        if dns is not None:
            dns_info = whois(dns)
            for key in SERVICES_DICTIONARY:
                # 1st try to parse the dns
                if any(srvc in dns for srvc in SERVICES_DICTIONARY[key]):
                    print("Service found for "+dns+" : "+key)
                    return key

        # 2nd to find the service using the DNS lookup
        if dns is not None:
            dns_info = whois(dns)
            for key in SERVICES_DICTIONARY:
                if any(srvc in dns_info["org"].lower() for srvc in SERVICES_DICTIONARY[key]):
                    print("Service found for "+dns+" : "+key)
                    return key

        # 3rd to find the service using the IP lookup
        ip_info = IPWhois(ip).lookup_rdap()
        for key in SERVICES_DICTIONARY:
            if any(srvc in ip_info['asn_description'].lower() for srvc in SERVICES_DICTIONARY[key]):
                print("Service found for "+ip+" : "+key)
                return key


    def list_services(self):
        for key in SERVICES_DICTIONARY:
            print(key)

        # obj = IPWhois(ip)
        # results = obj.lookup_rdap(depth=1)
        # print(results)
        # info2 = whois("legruiec.fr")
        # print(info2)
