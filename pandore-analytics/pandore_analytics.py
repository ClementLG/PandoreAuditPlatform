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

        if dns is not None:
            # 1st try to parse the dns
            for key in SERVICES_DICTIONARY:
                # 1st try to parse the dns
                if any(srvc in dns for srvc in SERVICES_DICTIONARY[key]):
                    print("Service found for " + dns + " : " + key)
                    return key

            # 2nd to find the service using the DNS lookup
            try:
                dns_info = whois(dns)
                for key in SERVICES_DICTIONARY:
                    if any(srvc in dns_info["org"].lower() for srvc in SERVICES_DICTIONARY[key]):
                        print("Service found for " + dns + " : " + key)
                        return key
            except:
                pass

        # 3rd to find the service using the IP lookup
        try:
            ip_info = IPWhois(ip).lookup_rdap()
            for key in SERVICES_DICTIONARY:
                if any(srvc in ip_info['asn_description'].lower() for srvc in SERVICES_DICTIONARY[key]):
                    print("Service found for " + ip + " : " + key)
                    return key
        except:
            pass

        return None

    def list_services(self):
        for key in SERVICES_DICTIONARY:
            print(key)