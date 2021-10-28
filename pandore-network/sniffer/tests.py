import datetime

import pandore_sender
from pandore_config import *

db = pandore_sender.PandoreSender(DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB)
#db.create_service("Michel5")
#db.create_service("Michel6")
#db.create_capture("test2", datetime.datetime.now(), None, "descrip", AUDITED_INTERFACE, None)
# a = db.get_capture_id("test")
# print(a)
db.create_request(10, 0, 'TCP', 1, 3, 1)