# PANDORE SNIFFER API - Functions

# IMPORTS======================================================================

import asyncio
import datetime
from time import sleep
from pandore_sniffer import PandoreSniffer
from pandore_config import PandoreConfig
import threading
from multiprocessing import Process

# VARIABLES=====================================================================

SNIFFER = []
CONFIG = PandoreConfig('pandore_config.ini')
EXIT_FLAG = False


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
    if (SNIFFER and not SNIFFER[0].is_alive()) or len(SNIFFER) == 0:
        if len(SNIFFER) > 0:
            SNIFFER.clear()
        EXIT_FLAG = False
        start_sniffer_subfunction_thread()
    else:
        print("[INFO] Sniffer already in use")


def start_sniffer_subfunction_thread():
    try:
        th = threading.Thread(target=run_sniffer_capture, args=(lambda: EXIT_FLAG,))
        th.daemon = True
        SNIFFER.append(th)
        SNIFFER[0].start()
    except Exception as e:
        print("An error occurred ! \n" + str(e))


def run_sniffer_capture(exit_flag):
    sniffer = PandoreSniffer()
    sniffer.run()
    while True:
        if exit_flag:
            sniffer.finish(True)


def start_sniffer_subfunction_old():
    if SNIFFER and not SNIFFER[0].is_alive():
        SNIFFER.clear()

    elif len(SNIFFER) > 0:
        print("[INFO] Sniffer already in use")
    else:
        try:
            SNIFFER.append(Process(target=PandoreSniffer().run()))
            SNIFFER[0].start()
        except Exception as e:
            print("An error occurred ! \n" + str(e))


def stop_sniffer_subfunction():
    EXIT_FLAG = False
    print("--------------------------------------------------------------------okokokoko")


def stop_sniffer_subfunction_old():
    if len(SNIFFER) > 0:
        if SNIFFER[0].is_alive():
            print("[INFO] Trying to stop sniffer")
            SNIFFER[0].terminate()
    else:
        print("[INFO] Sniffer is already stop")
    SNIFFER.clear()


def get_status():
    if SNIFFER and len(SNIFFER) > 0:
        if SNIFFER[0].is_alive():
            return 'sniffer is running'
    else:
        return 'sniffer is stopped'
