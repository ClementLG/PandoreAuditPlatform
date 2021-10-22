# PANDORE SNIFFER

# IMPORTS======================================================================

from pandore_config import *
import pyshark
import json
import datetime
import ipaddress
import math

# VARIABLES=====================================================================
data_up = 0
data_down = 0


# FUNCTIONS=====================================================================
def capture():
    cap = pyshark.LiveCapture(interface=AUDITED_INTERFACE, use_json=True,
                              bpf_filter=f'dst net {DEVICE_NETWORK} or src net {DEVICE_NETWORK}')
    cap.sniff(packet_count=10)
    cap.apply_on_packets(print_formatted_infos, timeout=100)


# example
def print_dns_info(pkt):
    if pkt.dns.qry_name:
        print('DNS Request from %s: %s' % (pkt.ip.src, pkt.dns.qry_name))
    elif pkt.dns.resp_name:
        print('DNS Response from %s: %s' % (pkt.ip.src, pkt.dns.resp_name))


def count_data(pkt_length, direction):
    if direction is "up":
        global data_up
        data_up += pkt_length
    elif direction is "down":
        global data_down
        data_down += pkt_length
    return pkt_length


def determine_direction(src_ip):
    if ipaddress.ip_address(src_ip) in ipaddress.ip_network(DEVICE_NETWORK):
        return "up"
    else:
        return "down"


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
