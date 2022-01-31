# PANDORE SNIFFER API - Functions

# IMPORTS======================================================================

import sys
import mysql.connector
from pandore_sniffer import PandoreSniffer
from pandore_config import PandoreConfig
import threading

# VARIABLES=====================================================================

SNIFFER = []
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
    if (SNIFFER and not SNIFFER[0].is_alive()) or len(SNIFFER) == 0:
        if len(SNIFFER) > 0:
            SNIFFER.clear()
        EXIT_FLAG = False
        start_sniffer_subfunction_thread()
    else:
        print("[INFO] Sniffer already in use")


def start_sniffer_subfunction_thread():
    try:
        th = threading.Thread(target=run_sniffer_capture)
        th.daemon = True
        SNIFFER.append(th)
        th.start()
    except Exception as e:
        print("An error occurred ! \n" + str(e))


def start_sniffer_subfunction_thread_V2():
    try:
        kth = KThread(target=run_sniffer_capture)
        SNIFFER.append(kth)
        SNIFFER[0].start()
    except Exception as e:
        print("An error occurred ! \n" + str(e))


def run_sniffer_capture():
    try:
        sniffer = PandoreSniffer()
        sniffer.run()
    except mysql.connector.ProgrammingError as err:
        pass
    except Exception as e:
        print("An error occurred ! \n" + str(e))


def stop_sniffer_subfunction():
    if len(SNIFFER) > 0:
        if SNIFFER[0].is_alive():
            SNIFFER[0].kill()
            print("Sniffer killed")
            SNIFFER.clear()
        else:
            SNIFFER.clear()
    else:
        print("No sniffer to kill ! Stop playing with the stop button !!")


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
    else:
        return 'sniffer is stopped'


class KThread(threading.Thread):
    """A subclass of threading.Thread, with a kill()method."""

    def __init__(self, *args, **keywords):
        threading.Thread.__init__(self, *args, **keywords)
        self.killed = False

    def start(self):
        """Start the thread."""
        self.__run_backup = self.run
        self.run = self.__run
        threading.Thread.start(self)

    def __run(self):
        """Hacked run function, which installs the trace."""
        sys.settrace(self.globaltrace)
        self.__run_backup()
        self.run = self.__run_backup

    def globaltrace(self, frame, why, arg):
        if why == 'call':
            return self.localtrace
        else:
            return None

    def localtrace(self, frame, why, arg):
        if self.killed:
            if why == 'line':
                raise SystemExit()
        return self.localtrace

    def kill(self):
        self.killed = True
