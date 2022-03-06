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
from pandore_config import PandoreConfig
import pandore_sender
import pyshark
import json
import datetime
import ipaddress
import math


# VARIABLES=====================================================================


# CLASS=========================================================================

class PandoreSniffer:
    def __init__(self, filename='pandore_config.ini', api=False):
        # Specifies the file for the config reader
        self.config = PandoreConfig(filename)
        # Use environment variables if used without API (Standalone)
        if not api:
            self.update_variable_docker()
        # Capture parameters
        self.name = self.config.get_parameter('capture', 'CAPTURE_NAME')
        self.duration = int(self.config.get_parameter('capture', 'CAPTURE_DURATION'))
        self.start_time = datetime.datetime.utcnow()
        self.end_time = None
        self.description = self.config.get_parameter('capture', 'CAPTURE_DESCRIPTION')
        # Network parameters
        self.device_network = self.config.get_parameter('network', 'DEVICE_NETWORK')
        if self.device_network not in [None, "None", "none", "null", "Null"]:
            self.device_network = str(check_network(self.config.get_parameter('network', 'DEVICE_NETWORK')))
        else:
            self.device_network = None
            print("[INFO] IPv4 disabled")
        self.device_network_ipv6 = self.config.get_parameter('network', 'DEVICE_NETWORK_IPv6')
        if self.device_network_ipv6 not in [None, "None", "none", "null", "Null"]:
            self.device_network_ipv6 = str(check_network(self.device_network_ipv6))
        else:
            self.device_network_ipv6 = None
            print("[INFO] IPv6 disabled")
        self.audited_interface = self.config.get_parameter('network', 'AUDITED_INTERFACE')
        self.cnx_type = self.config.get_parameter('capture', 'CAPTURE_CNX_TYPE')
        self.custom_filter = self.config.get_parameter('network', 'CUSTOM_FILTER')
        # Displays information in the terminal
        print_project_info()
        self.print_agent_config()
        # Initiates the connection to the db
        self.db = pandore_sender.PandoreSender(
            self.config.get_parameter('database', 'DB_HOST'),
            self.config.get_parameter('database', 'DB_PORT'),
            self.config.get_parameter('database', 'DB_USER'),
            self.config.get_parameter('database', 'DB_PASSWORD'),
            self.config.get_parameter('database', 'DB')
        )
        # Create a capture in the database and get the id
        self.capture_id = self.db.create_capture(
            self.name,
            self.start_time,
            self.end_time,
            self.description,
            self.audited_interface,
            self.cnx_type
        )
        # Create a buffer to avoid unnecessary requests to the db
        self.dns_buffer = {}

    def run(self):
        try:
            if self.capture_id is None:
                raise Exception("No able to get a capture ID")

            # Setting up the sniffer tool
            cap = pyshark.LiveCapture(
                interface=self.audited_interface,
                bpf_filter=self.generate_filter(),
                custom_parameters={"-B": "100"}
            )
            cap.apply_on_packets(self.pkt_to_db, timeout=self.duration)

        except asyncio.exceptions.TimeoutError:
            self.finish()
            print("\nEnd of the capture !")
        except Exception as e:
            try:
                self.finish()
            finally:
                pass
            print("An error occurred ! \n" + str(e))

    def finish(self):
        self.db.update_capture_end_time(datetime.datetime.utcnow(), self.capture_id)
        self.db.close_db()

    def get_id(self):
        return self.capture_id

    def generate_filter(self):
        net_filter = None
        # Only IPv4
        if self.device_network and not self.device_network_ipv6:
            net_filter = "( dst net " \
                         + str(self.device_network) \
                         + " or src net " \
                         + str(self.device_network) \
                         + " )"
        # Only IPv6
        elif not self.device_network and self.device_network_ipv6:
            net_filter = "( dst net " \
                         + str(self.device_network_ipv6) \
                         + " or src net " \
                         + str(self.device_network_ipv6) \
                         + " )"

        # Dual stack v4/v6
        elif self.device_network and self.device_network_ipv6:
            net_filter = "( ( dst net " \
                         + str(self.device_network) \
                         + " or src net " \
                         + str(self.device_network) \
                         + " ) or ( dst net " \
                         + str(self.device_network_ipv6) \
                         + " or src net " \
                         + str(self.device_network_ipv6) \
                         + " ) ) "

        else:
            raise Exception('Both IPv4 and IPv6 is None !')

        net_filter += " and ( " + str(self.custom_filter) + " )"

        print(net_filter)

        return net_filter

    def pkt_to_db(self, pkt):

        # console output
        print(pkt_to_json(pkt, self.device_network, self.device_network_ipv6))

        highest_layer_protocol = pkt.highest_layer

        try:
            # Sniff dns asw to get ip:domain_name assoc
            if hasattr(pkt, 'dns'):
                temp_dns, temp_ips = self.sniff_dns_info(pkt)
                self.dns_to_db(temp_dns, temp_ips)
            # Sniff tls.handshake.extensions_server_name to get ip:domain_name assoc
            if hasattr(pkt, 'tls'):
                if hasattr(pkt.tls, 'handshake_extensions_server_name'):
                    temp_sn, temp_ip = self.sniff_tls_info(pkt)
                    if temp_sn is not None and temp_ip is not None:
                        self.dns_to_db(temp_sn, temp_ip)
                if pkt[pkt.transport_layer].srcport == "443" or pkt[pkt.transport_layer].dstport == "443":
                    highest_layer_protocol = "HTTPS"

        except Exception as e:
            print("An error occurred checking protocol header) : \n" + str(e))

        # ADD packet in the DB
        try:
            if hasattr(pkt, 'ip'):
                self.db.create_request_string(
                    int(pkt.length),
                    determine_direction(pkt.ip.src, self.device_network),
                    highest_layer_protocol,
                    determine_ip_saved(pkt.ip.src.show, pkt.ip.dst.show, self.device_network),
                    self.check_dns_dictionary(pkt.ip.dst.show),
                    self.capture_id
                )
            elif hasattr(pkt, 'ipv6'):
                self.db.create_request_string(
                    int(pkt.length),
                    determine_direction(pkt.ipv6.src, self.device_network_ipv6),
                    highest_layer_protocol,
                    determine_ip_saved(pkt.ipv6.src.show, pkt.ipv6.dst.show, self.device_network_ipv6),
                    self.check_dns_dictionary(pkt.ipv6.dst.show),
                    self.capture_id
                )

            print(self.dns_buffer)

        except Exception as e:
            print("An error occurred (creating packet in db) : \n" + str(e))

    def dns_to_db(self, domain_name, ip_list):
        try:
            if domain_name is not None:
                # self.db.create_dns(domain_name)
                for ip in ip_list:
                    self.db.create_server_dns(str(ip.show), str(domain_name))
        except Exception as e:
            print("An error occurred (push dns to DB) : \n" + str(e))

    def check_dns_dictionary(self, ip):
        try:
            return self.dns_buffer[ip]
        except:
            return None

    def populate_dns_dictionary(self, name, ip_layer_field):
        for ip in ip_layer_field:
            self.dns_buffer[ip.show] = name

    def sniff_dns_info(self, pkt):
        try:
            if pkt.dns.resp_name:
                # print(pkt.dns)
                resp_name = pkt.dns.resp_name.show
                ip_list = pkt.dns.a.all_fields
                ip_list_out = out_dns_layer_field(ip_list, "line")
                # print("DNS - name : " + str(resp_name) + ", IP list : " + str(ip_list_out) + ")")
                self.populate_dns_dictionary(resp_name, ip_list)
                return resp_name, ip_list

        finally:
            pass

    def sniff_tls_info(self, pkt):
        try:
            handshake_extensions_server_name = pkt.tls.handshake_extensions_server_name.show
            # print(pkt.tls.handshake_extensions_server_name)
            if hasattr(pkt, 'ip'):
                if determine_direction(pkt.ip.src, self.device_network) == "1":
                    ip_assoc = [pkt.ip.dst]
                else:
                    ip_assoc = [pkt.ip.src]
            else:
                if determine_direction(pkt.ipv6.src, self.device_network_ipv6) == "1":
                    ip_assoc = [pkt.ipv6.dst]
                else:
                    ip_assoc = [pkt.ipv6.src]
            self.populate_dns_dictionary(handshake_extensions_server_name, ip_assoc)
            return handshake_extensions_server_name, ip_assoc
        except:
            pass

    def print_agent_config(self):
        print('# ' + '=' * 50)
        print(' CONFIG')
        print('# ' + '=' * 50)
        print('Audited interface: ' + str(self.audited_interface))
        if self.device_network:
            print('Device network IPv4: ' + str(self.device_network))
        if self.device_network_ipv6:
            print('Device network IPv6: ' + str(self.device_network_ipv6))
        start_time = datetime.datetime.now()
        end_time = start_time + datetime.timedelta(seconds=int(self.duration))
        print("Start time: " + str(start_time.strftime("%d/%m/%Y - %H:%M:%S")))
        print("Expected end time: " + str(end_time.strftime("%d/%m/%Y - %H:%M:%S")))
        print('# ' + '=' * 50)

    def update_variable_docker(self):
        if os.environ.get('PANDORE_AUDITED_INTERFACE') is not None:
            self.config.update_parameter('network', 'AUDITED_INTERFACE',
                                         str(os.environ.get('PANDORE_AUDITED_INTERFACE')))
        if os.environ.get('PANDORE_DEVICE_NETWORK') is not None:
            self.config.update_parameter('network', 'DEVICE_NETWORK', str(os.environ.get('PANDORE_DEVICE_NETWORK')))
        if os.environ.get('PANDORE_DEVICE_NETWORK_IPv6') is not None:
            self.config.update_parameter('network', 'DEVICE_NETWORK_IPv6', str(os.environ.get('PANDORE_DEVICE_NETWORK_IPv6')))
        if os.environ.get('PANDORE_CUSTOM_FILTER') is not None:
            self.config.update_parameter('network', 'CUSTOM_FILTER', str(os.environ.get('PANDORE_CUSTOM_FILTER')))
        if os.environ.get('PANDORE_DB_HOST') is not None:
            self.config.update_parameter('database', 'DB_HOST', str(os.environ.get('PANDORE_DB_HOST')))
        if os.environ.get('PANDORE_DB_PORT') is not None:
            self.config.update_parameter('database', 'DB_PORT', str(os.environ.get('PANDORE_DB_PORT')))
        if os.environ.get('PANDORE_DB_USER') is not None:
            self.config.update_parameter('database', 'DB_USER', str(os.environ.get('PANDORE_DB_USER')))
        if os.environ.get('PANDORE_DB_PASSWORD') is not None:
            self.config.update_parameter('database', 'DB_PASSWORD', str(os.environ.get('PANDORE_DB_PASSWORD')))
        if os.environ.get('PANDORE_DB') is not None:
            self.config.update_parameter('database', 'DB', str(os.environ.get('PANDORE_DB')))
        if os.environ.get('PANDORE_CAPTURE_NAME') is not None:
            self.config.update_parameter('capture', 'CAPTURE_NAME', str(os.environ.get('PANDORE_CAPTURE_NAME')))
        if os.environ.get('PANDORE_CAPTURE_DURATION') is not None:
            self.config.update_parameter('capture', 'CAPTURE_DURATION', str(os.environ.get('PANDORE_CAPTURE_DURATION')))
        if os.environ.get('PANDORE_CAPTURE_DESCRIPTION') is not None:
            self.config.update_parameter('capture', 'CAPTURE_DESCRIPTION',
                                         str(os.environ.get('PANDORE_CAPTURE_DESCRIPTION')))
        if os.environ.get('PANDORE_CAPTURE_CNX_TYPE') is not None:
            self.config.update_parameter('capture', 'CAPTURE_CNX_TYPE', str(os.environ.get('PANDORE_CAPTURE_CNX_TYPE')))
        if os.environ.get('PANDORE_SNIFFER_GUI') is not None:
            self.config.update_parameter('gui', 'SNIFFER_GUI', str(os.environ.get('PANDORE_SNIFFER_GUI')))


# FUNCTIONS=====================================================================

def pkt_to_json(pkt, network_v4, network_v6=None):
    try:

        highest_layer_protocol = pkt.highest_layer

        pck_to_json = None

        if hasattr(pkt, 'ipv6'):
            # convert in JSON
            pck_to_json = {
                "timestamp": datetime.datetime.utcnow().timestamp(),
                "IP_SRC": pkt.ipv6.src,
                "IP_DST": pkt.ipv6.dst,
                "DIRECTION": determine_direction(pkt.ipv6.src, network_v6),
                "L4_PROT": pkt.transport_layer,
                "HIGHEST_LAYER": highest_layer_protocol,
                "PACKET_SIZE": pkt.length
            }
        elif hasattr(pkt, 'ip'):
            # convert in JSON
            pck_to_json = {
                "timestamp": datetime.datetime.utcnow().timestamp(),
                "IP_SRC": pkt.ip.src,
                "IP_DST": pkt.ip.dst,
                "DIRECTION": determine_direction(pkt.ip.src, network_v4),
                "L4_PROT": pkt.transport_layer,
                "HIGHEST_LAYER": highest_layer_protocol,
                "PACKET_SIZE": pkt.length
            }

        json_dump = json.dumps(pck_to_json)
        return json_dump

    except Exception as e:
        print("Packet below L3 detected. Excluded from the output.(" + str(pkt.highest_layer) + ")")
        # print(e)

def convert_size(size_bytes):
    if size_bytes == 0:
        return "0B"
    size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
    i = int(math.floor(math.log(size_bytes, 1024)))
    p = math.pow(1024, i)
    s = round(size_bytes / p, 2)
    return "%s %s" % (s, size_name[i])


def out_dns_layer_field(ip_layer_field, output_type):
    out = ""
    if output_type == "line":
        for ip in ip_layer_field:
            out += ip.show + ", "
    if output_type == "column":
        for ip in ip_layer_field:
            out += ip.show + "\n"
    return out


def determine_direction(src_ip, network):
    if ipaddress.ip_address(src_ip) in ipaddress.ip_network(network):
        # upload
        return "1"
    else:
        # download
        return "0"


# Return the correct network address
# Example: 192.168.10.1/24 --> 192.168.10.0/24
def check_network(network):
    ipn = ipaddress.ip_network(network)
    if isinstance(ipn, ipaddress.IPv4Network):
        return ipaddress.IPv4Network(network, strict=False)
    elif isinstance(ipn, ipaddress.IPv6Network):
        return ipaddress.IPv6Network(network, strict=False)
    else:
        raise Exception("Not a correct ip nework !")


# Only the IP different to the host is send to the DB
def determine_ip_saved(src_ip, dst_ip, network):
    if ipaddress.ip_address(src_ip) in ipaddress.ip_network(network):
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
