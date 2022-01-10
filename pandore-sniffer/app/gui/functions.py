# PANDORE SNIFFER API - Functions

# IMPORTS======================================================================

import asyncio
import datetime
from time import sleep
from app.pandore_sniffer import PandoreSniffer
from app.pandore_config import *
import threading
from multiprocessing import Process

# VARIABLES=====================================================================

SNIFFER = []
SNIFFER_v2 = []


# FUNCTIONS====================================================================

def flask_logger():
    for i in range(100):
        current_time = datetime.datetime.now().strftime('%H:%M:%S') + "\n"
        yield current_time.encode()
        sleep(1)


def update_variable_config(config_json):
    print(config_json)
    if 'network' in config_json:
        for conf in config_json['network']:
            if conf in locals():
                globals()[conf] = config_json['network'][conf]
            print(conf + "-->" + str(config_json['network'][conf]))
    if 'database' in config_json:
        for conf in config_json['database']:
            if conf in locals():
                print("exist")
                globals()[conf] = config_json['database'][conf]
            print(conf + "-->" + str(config_json['database'][conf]))
    if 'capture' in config_json:
        for conf in config_json['capture']:
            if conf in locals():
                globals()[conf] = config_json['capture'][conf]
            print(conf + "-->" + str(config_json['capture'][conf]))


def get_sniffer_config():
    config_json = {
        'network': {
            'AUDITED_INTERFACE': AUDITED_INTERFACE,
            'DEVICE_NETWORK': DEVICE_NETWORK,
            'CUSTOM_FILTER': CUSTOM_FILTER
        },
        'database': {
            'DB_HOST': DB_HOST,
            'DB_PORT': DB_PORT,
            'DB_USER': DB_USER,
            'DB_PASSWORD': DB_PASSWORD,
            'DB': DB
        },
        'capture': {
            'CAPTURE_NAME': CAPTURE_NAME,
            'CAPTURE_DURATION': CAPTURE_DURATION,
            'CAPTURE_DESCRIPTION': CAPTURE_DESCRIPTION,
            'CAPTURE_CNX_TYPE': CAPTURE_CNX_TYPE
        }

    }
    return config_json


def start_sniffer_subfunction():
    if len(SNIFFER) > 0:
        print("--------------------------------------------------ALREADY IN USE")
    else:
        try:
            SNIFFER.append(PandoreSniffer(CAPTURE_NAME, CAPTURE_DURATION, CAPTURE_DESCRIPTION, CAPTURE_CNX_TYPE))
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
                target=PandoreSniffer(CAPTURE_NAME, CAPTURE_DURATION, CAPTURE_DESCRIPTION, CAPTURE_CNX_TYPE).run()))
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
