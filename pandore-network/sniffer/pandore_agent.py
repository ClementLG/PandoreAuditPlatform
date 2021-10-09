#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# INFO=========================================================================
__project__ = "Pandore"
__author__ = "Clement LE GRUIEC"
__version__ = "1.0"
__Created__ = "09/10/2021"
__team__ = ["Clement LE GRUIEC", "Hugo HOUILLON", "Salma CHAHMI", "Nathan OLBORSKI"]
__school__ = "IMT Atlantique"
__course__ = "3rd year engineering project"
__subject__ = "Characterization of the sneaky traffic generated by mobile applications"
__description__ = "The agent is the application which allow to send the network traffic in a formatted manner " \
                  "in a second application which will carry out more specific and cumbersome processing."

# IMPORTS======================================================================
from pandore_config import *
from datetime import time
import pyshark
import threading


# FUNCTIONS====================================================================
def print_project_info():
    print('# ' + '=' * 50)
    print(' INFOS')
    print('# ' + '=' * 50)
    print('Project : ' + __project__)
    print('Author: ' + __author__)
    print('Full team: ' + ', '.join(__team__))
    print('Realised with the school: ' + __school__ + "\n")


def print_agent_config():
    print('# ' + '=' * 50)
    print(' CONFIG')
    print('# ' + '=' * 50)
    print('Audited interface: ' + AUDITED_INTERFACE)


def print_dns_info(pkt):
    if pkt.dns.qry_name:
        print('DNS Request from %s: %s' % (pkt.ip.src, pkt.dns.qry_name))
    elif pkt.dns.resp_name:
        print('DNS Response from %s: %s' % (pkt.ip.src, pkt.dns.resp_name))


# MAIN=========================================================================
print_project_info()
print_agent_config()

capture = pyshark.LiveCapture(interface=AUDITED_INTERFACE, bpf_filter='udp port 53')
capture.sniff(packet_count=10)
capture.apply_on_packets(print_dns_info, timeout=100)