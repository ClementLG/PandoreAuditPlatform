# PANDORE SNIFFER API - Functions

# IMPORTS======================================================================

import asyncio
import datetime
from time import sleep
from app.pandore_sniffer import PandoreSniffer
from app.pandore_config import PandoreConfig
import threading
from multiprocessing import Process

# VARIABLES=====================================================================

SNIFFER = []
SNIFFER_v2 = []
CONFIG = PandoreConfig('pandore_config.ini')


# FUNCTIONS====================================================================

def update_variable_config(config_json):
    for section in config_json:
        for parameter in config_json[section]:
            CONFIG.update_parameter(section, parameter, config_json[section][parameter])
    CONFIG.save_config()



def get_sniffer_config():
    json = CONFIG.get_json_config()
    return json


def start_sniffer_subfunction():
    if len(SNIFFER) > 0:
        print("--------------------------------------------------ALREADY IN USE")
    else:
        try:
            SNIFFER.append(PandoreSniffer())
            SNIFFER[0].run()
        except asyncio.exceptions.TimeoutError:
            SNIFFER[0].finish()
            SNIFFER.clear()
            print("\nEnd of the capture !")
        except Exception as e:
            print("An error occurred ! \n" + e)


def start_sniffer_subfunction_v2():
    if SNIFFER_v2 and SNIFFER_v2[0].is_alive() == False:
        SNIFFER_v2.clear()

    if len(SNIFFER_v2) > 0:
        print("--------------------------------------------------ALREADY IN USE")
    else:
        try:
            SNIFFER_v2.append(Process(
                target=PandoreSniffer().run()))
            SNIFFER_v2[0].start()
        except Exception as e:
            print("An error occurred ! \n" + e)


def stop_sniffer_subfunction():
    if len(SNIFFER) > 0:
        SNIFFER[0].finish()
        SNIFFER.clear()


def stop_sniffer_subfunction_v2():
    if len(SNIFFER_v2) > 0:
        print("-----------------------stop")
        SNIFFER_v2[0].terminate()
        SNIFFER_v2.clear()
