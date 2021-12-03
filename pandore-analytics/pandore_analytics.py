# PANDORE ANALYTICS


# IMPORTS======================================================================

from ipwhois import IPWhois # IP
from whois import whois # DomainName

# VARIABLES=====================================================================

# CLASS=========================================================================

class PandoreAnalytics:

    def __init__(self):
        print("Pandore analytics is running")

    def analyse_ip_dns(self, ip, dns=None):
        obj = IPWhois(ip)
        results = obj.lookup_rdap(depth=1)
        print(results)
        info2 = whois("legruiec.fr")
        print(info2)