import datetime

import pandore_sender
from pandore_config import *

db = pandore_sender.PandoreSender(DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB)
# db.create_service("Michel5")
# db.create_service("Michel6")
# db.create_capture("test2", datetime.datetime.now(), None, "descrip", AUDITED_INTERFACE, None)
# a = db.get_capture_id("test")
# print(a)
# db.create_request(10, 0, 'TCP', 1, 3, 1)


## BROUILLONS

# self.cap = pyshark.LiveCapture(interface=AUDITED_INTERFACE, use_json=True, bpf_filter=f'( src net {DEVICE_NETWORK} or udp port 53 ) and not port 1194')
# self.cap = pyshark.LiveCapture(interface=AUDITED_INTERFACE, use_json=True, bpf_filter=f'udp port 53')
# self.cap = pyshark.LiveCapture(interface=AUDITED_INTERFACE, bpf_filter=f'udp port 53') # debug dns sniff
# self.cap = pyshark.LiveCapture(interface=AUDITED_INTERFACE, use_json=True, bpf_filter=f'dst net {DEVICE_NETWORK} or src net {DEVICE_NETWORK}')