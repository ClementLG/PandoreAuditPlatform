# PANDORE SNIFFER
# -*- coding: utf-8 -*-
# INFO=========================================================================

__project__ = "Pandore"
__maintainer__ = "Clement LE GRUIEC"
__version__ = "1.0"
__Created__ = "09/10/2021"
__team__ = ["Clement LE GRUIEC", "Hugo HOUILLON", "Salma CHAHMI", "Nathan OLBORSKI"]
__school__ = "IMT Atlantique"
__course__ = "3rd year engineering project"
__subject__ = "Characterization of the sneaky traffic generated by mobile applications"
__description__ = "The agent is the application which allow to send the network traffic in a formatted manner " \
                  "in a second application which will carry out more specific and cumbersome processing."

# IMPORTS======================================================================
import asyncio
import os
from random import random

from pandore_config import PandoreConfig
import pandore_sender
import pyshark
import json
import datetime
import ipaddress
import math

# VARIABLES=====================================================================

CONFIG = PandoreConfig('pandore_config.ini')
# DNS sniffed dictionary
DNS = {}


# CONFIG.get_parameter('capture', 'CAPTURE_CNX_TYPE')

# CLASS=========================================================================

class PandoreSniffer:
    def __init__(self, filename='pandore_config.ini'):
        CONFIG = PandoreConfig(filename)
        update_variable_docker()
        print_project_info()
        print_agent_config()
        self.name = CONFIG.get_parameter('capture', 'CAPTURE_NAME') + str(int(random() * 1000000))
        self.duration = int(CONFIG.get_parameter('capture', 'CAPTURE_DURATION'))
        self.start_time = datetime.datetime.utcnow()
        self.end_time = None
        self.db = pandore_sender.PandoreSender(
            CONFIG.get_parameter('database', 'DB_HOST'),
            CONFIG.get_parameter('database', 'DB_PORT'),
            CONFIG.get_parameter('database', 'DB_USER'),
            CONFIG.get_parameter('database', 'DB_PASSWORD'),
            CONFIG.get_parameter('database', 'DB')
        )
        self.db.create_capture(
            self.name,
            self.start_time,
            self.end_time,
            CONFIG.get_parameter('capture', 'CAPTURE_DESCRIPTION'),
            CONFIG.get_parameter('network', 'AUDITED_INTERFACE'),
            CONFIG.get_parameter('capture', 'CAPTURE_CNX_TYPE')
        )
        self.capture_id = self.db.get_capture_id(self.name)
        self.cap = pyshark.LiveCapture(
            interface=CONFIG.get_parameter('network', 'AUDITED_INTERFACE'),
            bpf_filter="( dst net " +
                       str(CONFIG.get_parameter('network', 'DEVICE_NETWORK'))
                       + " or src net "
                       + str(CONFIG.get_parameter('network', 'DEVICE_NETWORK'))
                       + " ) and "
                       + "( " + CONFIG.get_parameter('network', 'CUSTOM_FILTER')
                       + " )")
        self.cap.sniff(packet_count=1)
        self.running = None

    def run(self):
        try:
            self.running = True
            self.cap.apply_on_packets(self.pkt_to_db, timeout=self.duration)
        except asyncio.exceptions.TimeoutError:
            self.finish()
            print("\nEnd of the capture !")
        except Exception as e:
            self.running = False
            try:
                self.finish()
            except:
                pass
            print("An error occurred ! \n" + e)

    def finish(self):
        self.running = False
        self.db.update_capture(
            self.capture_id,
            self.name,
            self.start_time,
            datetime.datetime.utcnow(),
            CONFIG.get_parameter('capture', 'CAPTURE_DESCRIPTION'),
            CONFIG.get_parameter('network', 'AUDITED_INTERFACE'),
            CONFIG.get_parameter('capture', 'CAPTURE_CNX_TYPE')
        )
        self.db.close_db()

    def pkt_to_db(self, pkt):
        try:
            # console output
            print(pkt_to_json(pkt))

            # refactor protocol name
            try:
                # Change protocol name. Ex : TLS:443 --> HTTPS
                highest_layer_protocol = refactor_protocol_name(pkt.highest_layer, pkt[pkt.transport_layer].srcport,
                                                                pkt[pkt.transport_layer].dstport)
            except:
                highest_layer_protocol = pkt.highest_layer

            # Sniff dns asw to get ip:domain_name assoc
            try:
                if pkt.dns:
                    temp_dns, temp_ips = sniff_dns_info(pkt)
                    self.dns_to_db(temp_dns, temp_ips)
            except:
                pass

            # ADD packet in the DB
            try:
                self.db.create_request_string(int(pkt.length), determine_direction(pkt.ip.src), highest_layer_protocol,
                                              determine_ip_saved(pkt.ip.src.show, pkt.ip.dst.show),
                                              check_dns_dictionary(pkt.ip.dst.show), self.capture_id)
                print(DNS)
            except Exception as e:
                print(e)

        except Exception as e:
            self.running = False
            print("A error occurred : \n" + e)

    def dns_to_db(self, domain_name, ip_list):
        try:
            if domain_name is not None:
                # self.db.create_dns(domain_name)
                for ip in ip_list:
                    self.db.create_server_dns(str(ip.show), str(domain_name))
        except Exception as e:
            print(e)
            pass

    def get_running_status(self):
        return self.running


# FUNCTIONS=====================================================================

def pkt_to_json(pkt):
    try:
        # refactor protocol name
        try:
            highest_layer_protocol = refactor_protocol_name(pkt.highest_layer, pkt[pkt.transport_layer].srcport,
                                                            pkt[pkt.transport_layer].dstport)
        except:
            highest_layer_protocol = pkt.highest_layer

        # convert in JSON
        pck_to_json = {
            "timestamp": datetime.datetime.utcnow().timestamp(),
            "IP_SRC": pkt.ip.src,
            "IP_DST": pkt.ip.dst,
            "DIRECTION": determine_direction(pkt.ip.src),
            "L4_PROT": pkt.transport_layer,
            "HIGHEST_LAYER": highest_layer_protocol,
            "PACKET_SIZE": pkt.length
        }

        json_dump = json.dumps(pck_to_json)
        return json_dump

    except Exception as e:
        print("Packet below L3 detected. Excluded from the output.(" + str(pkt.highest_layer) + ")")
        # print(e)


def refactor_protocol_name(original_name, src_port, dst_port):
    if (original_name == 'TLS') and ((str(src_port) == "443") or (str(dst_port) == "443")):
        return "HTTPS"
    else:
        return original_name


def convert_size(size_bytes):
    if size_bytes == 0:
        return "0B"
    size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
    i = int(math.floor(math.log(size_bytes, 1024)))
    p = math.pow(1024, i)
    s = round(size_bytes / p, 2)
    return "%s %s" % (s, size_name[i])


def sniff_dns_info(pkt):
    try:
        if pkt.dns.resp_name:
            # print(pkt.dns)
            resp_name = pkt.dns.resp_name.show
            ip_list = pkt.dns.a.all_fields
            ip_list_out = out_dns_layer_field(ip_list, "line")
            print("DNS - name : " + str(resp_name) + ", IP list : " + str(ip_list_out) + ")")
            populate_dns_dictionary(resp_name, ip_list)
            return resp_name, ip_list

    except:
        pass


def populate_dns_dictionary(name, ip_layer_field):
    for ip in ip_layer_field:
        DNS[ip.show] = name


def check_dns_dictionary(ip):
    try:
        return DNS[ip]
    except:
        return None


def out_dns_layer_field(ip_layer_field, output_type):
    out = ""
    if output_type == "line":
        for ip in ip_layer_field:
            out += ip.show + ", "
    if output_type == "column":
        for ip in ip_layer_field:
            out += ip.show + "\n"
    return out


def determine_direction(src_ip):
    if ipaddress.ip_address(src_ip) in ipaddress.ip_network(CONFIG.get_parameter('network', 'DEVICE_NETWORK')):
        return "1"
    else:
        return "0"


def determine_ip_saved(src_ip, dst_ip):
    if ipaddress.ip_address(src_ip) in ipaddress.ip_network(CONFIG.get_parameter('network', 'DEVICE_NETWORK')):
        return str(dst_ip)
    else:
        return str(src_ip)


def print_project_info():
    print('# ' + '=' * 50)
    print(' INFOS')
    print('# ' + '=' * 50)
    print('Project : ' + __project__)
    print('Maintainer : ' + __maintainer__)
    print('Full team: ' + ', '.join(__team__))
    print('Realised with the school: ' + __school__)
    print('# ' + '=' * 50)


def print_agent_config():
    print('# ' + '=' * 50)
    print(' CONFIG')
    print('# ' + '=' * 50)
    print('Audited interface: ' + CONFIG.get_parameter('network', 'AUDITED_INTERFACE'))
    print('Device network: ' + CONFIG.get_parameter('network', 'DEVICE_NETWORK'))
    start_time = datetime.datetime.now()
    end_time = start_time + datetime.timedelta(seconds=int(CONFIG.get_parameter('capture', 'CAPTURE_DURATION')))
    print("Start time: " + str(start_time.strftime("%d/%m/%Y - %H:%M:%S")))
    print("Expected end time: " + str(end_time.strftime("%d/%m/%Y - %H:%M:%S")))
    print('# ' + '=' * 50)


def update_variable_docker():
    if os.environ.get('PANDORE_AUDITED_INTERFACE') is not None:
        CONFIG.update_parameter('network', 'AUDITED_INTERFACE', str(os.environ.get('PANDORE_AUDITED_INTERFACE')))
    if os.environ.get('PANDORE_DEVICE_NETWORK') is not None:
        CONFIG.update_parameter('network', 'DEVICE_NETWORK', str(os.environ.get('PANDORE_DEVICE_NETWORK')))
    if os.environ.get('PANDORE_CUSTOM_FILTER') is not None:
        CONFIG.update_parameter('network', 'CUSTOM_FILTER', str(os.environ.get('PANDORE_CUSTOM_FILTER')))
    if os.environ.get('PANDORE_DB_HOST') is not None:
        CONFIG.update_parameter('database', 'DB_HOST', str(os.environ.get('PANDORE_DB_HOST')))
    if os.environ.get('PANDORE_DB_PORT') is not None:
        CONFIG.update_parameter('database', 'DB_PORT', str(os.environ.get('PANDORE_DB_PORT')))
    if os.environ.get('PANDORE_DB_USER') is not None:
        CONFIG.update_parameter('database', 'DB_USER', str(os.environ.get('PANDORE_DB_USER')))
    if os.environ.get('PANDORE_DB_PASSWORD') is not None:
        CONFIG.update_parameter('database', 'DB_PASSWORD', str(os.environ.get('PANDORE_DB_PASSWORD')))
    if os.environ.get('PANDORE_DB') is not None:
        CONFIG.update_parameter('database', 'DB', str(os.environ.get('PANDORE_DB')))
    if os.environ.get('PANDORE_CAPTURE_NAME') is not None:
        CONFIG.update_parameter('capture', 'CAPTURE_NAME', str(os.environ.get('PANDORE_CAPTURE_NAME')))
    if os.environ.get('PANDORE_CAPTURE_DURATION') is not None:
        CONFIG.update_parameter('capture', 'CAPTURE_DURATION', str(os.environ.get('PANDORE_CAPTURE_DURATION')))
    if os.environ.get('PANDORE_CAPTURE_DESCRIPTION') is not None:
        CONFIG.update_parameter('capture', 'CAPTURE_DESCRIPTION', str(os.environ.get('PANDORE_CAPTURE_DESCRIPTION')))
    if os.environ.get('PANDORE_CAPTURE_CNX_TYPE') is not None:
        CONFIG.update_parameter('capture', 'CAPTURE_CNX_TYPE', str(os.environ.get('PANDORE_CAPTURE_CNX_TYPE')))
    if os.environ.get('PANDORE_SNIFFER_GUI') is not None:
        CONFIG.update_parameter('gui', 'SNIFFER_GUI', str(os.environ.get('PANDORE_SNIFFER_GUI')))
