# PANDORE SNIFFER

# IMPORTS======================================================================

from pandore_config import *
import pandore_sender
import pyshark
import json
import datetime
import ipaddress
import math

# VARIABLES=====================================================================

data_up = 0
data_down = 0


# CLASS=========================================================================

class PandoreSniffer:
    def __init__(self, name, duration, description, cnx_type):
        self.name = name
        self.duration = duration
        self.db = pandore_sender.PandoreSender(DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB)
        self.db.create_capture(name, datetime.datetime.now(), None, description, AUDITED_INTERFACE, cnx_type)
        self.capture_id = self.db.get_capture_id(name)
        self.cap = pyshark.LiveCapture(interface=AUDITED_INTERFACE, use_json=True,
                                       bpf_filter=f'dst net {DEVICE_NETWORK} or src net {DEVICE_NETWORK}')
        self.cap.sniff(packet_count=10)

    def run(self):
        self.cap.apply_on_packets(self.pkt_to_db, timeout=self.duration)

    def pkt_to_db(self, pkt):

        try:
            pck_to_json = {
                "timestamp": datetime.datetime.now().timestamp(),
                "IP_SRC": pkt.ip.src,
                "IP_DST": pkt.ip.dst,
                "DIRECTION": determine_direction(pkt.ip.src),
                "L4_PROT": pkt.transport_layer,
                "HIGHEST_LAYER": pkt.highest_layer,
                "PACKET_SIZE": count_data(pkt.length, determine_direction(pkt.ip.src))
            }
            json_dump = json.dumps(pck_to_json)
            print(json_dump)
            print("UP :" + convert_size(data_up) + " | " + "DOWN :" + convert_size(data_down))
            self.db.create_request(pkt.length, determine_direction(pkt.ip.src), pkt.highest_layer, 1, 3,
                                   self.capture_id)
        except:
            print("non l3 packet")


# FUNCTIONS=====================================================================

def print_dns_info(pkt):
    if pkt.dns.qry_name:
        print('DNS Request from %s: %s' % (pkt.ip.src, pkt.dns.qry_name))
    elif pkt.dns.resp_name:
        print('DNS Response from %s: %s' % (pkt.ip.src, pkt.dns.resp_name))


def count_data(pkt_length, direction):
    if direction is "1":
        global data_up
        data_up += pkt_length
    elif direction is "0":
        global data_down
        data_down += pkt_length
    return pkt_length


def determine_direction(src_ip):
    if ipaddress.ip_address(src_ip) in ipaddress.ip_network(DEVICE_NETWORK):
        return "1"
    else:
        return "0"


def convert_size(size_bytes):
    if size_bytes == 0:
        return "0B"
    size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
    i = int(math.floor(math.log(size_bytes, 1024)))
    p = math.pow(1024, i)
    s = round(size_bytes / p, 2)
    return "%s %s" % (s, size_name[i])


def print_formatted_infos(pkt):
    try:
        pck_to_json = {
            "timestamp": datetime.datetime.now().timestamp(),
            "IP_SRC": pkt.ip.src,
            "IP_DST": pkt.ip.dst,
            "DIRECTION": determine_direction(pkt.ip.src),
            "L4_PROT": pkt.transport_layer,
            "HIGHEST_LAYER": pkt.highest_layer,
            "PACKET_SIZE": count_data(pkt.length, determine_direction(pkt.ip.src))
        }
        json_dump = json.dumps(pck_to_json)
        print(json_dump)
        print("UP :" + convert_size(data_up) + " | " + "DOWN :" + convert_size(data_down))
    except:
        print("non l3 packet")
