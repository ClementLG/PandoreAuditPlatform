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

# DNS sniffed dictionary
DNS = {}


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
        self.cap.sniff(packet_count=5)

    def run(self):
        self.cap.apply_on_packets(self.pkt_to_db, timeout=self.duration)

    def pkt_to_db(self, pkt):
        try:
            print(pkt_to_json(pkt))
            try:
                ptrcl = refactor_protocol_name(pkt.highest_layer, pkt[pkt.transport_layer].srcport,
                                               pkt[pkt.transport_layer].dstport)
                print("ok")
            except:
                ptrcl = pkt.highest_layer

            self.db.create_request(pkt.length, determine_direction(pkt.ip.src), ptrcl, 1, 3, self.capture_id)
        except Exception as e:
            print("A error occurred : \n" + e)


# FUNCTIONS=====================================================================

def pkt_to_json(pkt):
    try:
        try:
            ptrcl = refactor_protocol_name(pkt.highest_layer, pkt[pkt.transport_layer].srcport, pkt[pkt.transport_layer].dstport)
        except:
            ptrcl = pkt.highest_layer
        pck_to_json = {
            "timestamp": datetime.datetime.now().timestamp(),
            "IP_SRC": pkt.ip.src,
            "IP_DST": pkt.ip.dst,
            "DIRECTION": determine_direction(pkt.ip.src),
            "L4_PROT": pkt.transport_layer,
            "HIGHEST_LAYER": ptrcl,
            "PACKET_SIZE": pkt.length
        }
        json_dump = json.dumps(pck_to_json)
        return json_dump
    except Exception as e:
        print(f"Packet below L3 detected. Excluded from the output.({pkt.highest_layer})")
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
    if pkt.dns.qry_name:
        print('DNS Request from %s: %s' % (pkt.ip.src, pkt.dns.qry_name))
    elif pkt.dns.resp_name:
        print('DNS Response from %s: %s' % (pkt.ip.src, pkt.dns.resp_name))


def determine_direction(src_ip):
    if ipaddress.ip_address(src_ip) in ipaddress.ip_network(DEVICE_NETWORK):
        return "1"
    else:
        return "0"
