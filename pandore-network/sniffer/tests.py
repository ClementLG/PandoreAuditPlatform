
import pandore_sender
from pandore_config import *

db = pandore_sender.PandoreSender(DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB)
#db.create_service("Michel5")
#db.create_service("Michel6")
db.create_capture("test", "2021-10-09 14:37:12", None, "descrip", AUDITED_INTERFACE, None)