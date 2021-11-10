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
        self.cap = pyshark.LiveCapture(interface=AUDITED_INTERFACE, bpf_filter=f'( dst net {DEVICE_NETWORK} or src net {DEVICE_NETWORK} ) and not port 1194')

        self.cap.sniff(packet_count=10)

    def run(self):
        self.cap.apply_on_packets(self.pkt_to_db, timeout=self.duration)

    def pkt_to_db(self, pkt):
        try:
            # console output
            print(pkt_to_json(pkt))

            # refactor protocol name
            try:
                # Change protocol name. Ex : TLS:443 --> HTTPS
                highest_layer_protocol = refactor_protocol_name(pkt.highest_layer, pkt[pkt.transport_layer].srcport, pkt[pkt.transport_layer].dstport)
            except:
                highest_layer_protocol = pkt.highest_layer

            # Sniff dns asw to get ip:domain_name assoc
            try:
                if pkt.dns:
                    sniff_dns_info(pkt)
            except:
                pass

            # ADD packet in the DB
            try:
                #self.db.create_request_string(pkt.length, determine_direction(pkt.ip.src), highest_layer_protocol, str(pkt.ip.dst), check_dns_dictionary(pkt.ip.dst), self.capture_id)
                print(DNS)
            except Exception as exc:
                print(exc)

        except Exception as e:
            print("A error occurred : \n" + e)


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
            "timestamp": datetime.datetime.now().timestamp(),
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
    try:
        resp_name = None
        ip_list = None
        if pkt.dns.resp_name:
            # print(pkt.dns)
            resp_name = pkt.dns.resp_name
            ip_list = pkt.dns.a.all_fields
            ip_list_out = out_dns_layer_field(ip_list, "line")
        print(f"DNS - name : {resp_name}, IP list : {ip_list_out}")
        populate_dns_dictionary(resp_name, ip_list)

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
    if ipaddress.ip_address(src_ip) in ipaddress.ip_network(DEVICE_NETWORK):
        return "1"
    else:
        return "0"
