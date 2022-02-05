# PANDORE SNIFFER API - Functions

# IMPORTS======================================================================
import datetime
import sys
import mysql.connector
from pandore_sniffer import PandoreSniffer
from pandore_config import PandoreConfig
from pandore_sender import PandoreSender
import threading
from random import random

# VARIABLES=====================================================================

MAX_THREAD = 2
SNIFFER = []
SNIFFERS_Thread = {}
SNIFFERS_ID = {}
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


def start_sniffer_subfunction_thread_v2():
    try:
        if len(SNIFFER) > 0:
            if not SNIFFER[0].is_alive():
                SNIFFER.clear()
            else:
                print("[INFO] A thread is already running !")
        if len(SNIFFER) == 0:
            kth = KThread(target=run_sniffer_capture)
            SNIFFER.append(kth)
            SNIFFER[0].start()
    except Exception as e:
        print("An error occurred ! \n" + str(e))


def start_sniffer_subfunction_thread_v3():
    try:
        # Check if there is some dead threads in the list
        clean_thread_v2()
        # Check if we are below the thread limit (configurable)
        if len(SNIFFERS_Thread) < MAX_THREAD:
            t_name = create_unique_thread_id()
            if t_name is None:
                raise Exception('Non unique ID')
            else:
                kth = KThread(target=run_sniffer_capture, args=(t_name,))
                kth.start()
                SNIFFERS_Thread[t_name] = kth
                print(SNIFFERS_Thread)
        else:
            print("[ERROR] More than " + str(MAX_THREAD) + " thread is already running")
    except Exception as e:
        print("An error occurred ! \n" + str(e))


# list_version
def clean_thread():
    dead_thread = []
    for s in SNIFFER:
        if not s.is_alive():
            dead_thread.append(s)
    for d in dead_thread:
        if d in SNIFFER:
            SNIFFER.remove(d)


# dictionary version
def clean_thread_v2():
    dead_thread = []
    # Check if thread is alive
    for s in SNIFFERS_Thread:
        if not SNIFFERS_Thread[s].is_alive():
            dead_thread.append(s)
    # Remove the dead thread from dictionaries
    for d in dead_thread:
        if d in SNIFFERS_Thread:
            del SNIFFERS_Thread[d]
        if d in SNIFFERS_ID:
            del SNIFFERS_ID[d]


def create_unique_thread_id():
    lim = 3
    i = 0
    while i < lim:
        r = int(random() * 10000000)
        if r in SNIFFERS_Thread:
            print("[INFO] No unique id found")
        else:
            return r
        i += 1
    return None


# TEST.append(sniffer.get_id())

def run_sniffer_capture(thread_id=None):
    try:
        sniffer = PandoreSniffer()
        if thread_id is not None:
            SNIFFERS_ID[thread_id] = sniffer.get_id()
            print(SNIFFERS_ID)
        sniffer.run()
    except mysql.connector.ProgrammingError as err:
        pass
    except Exception as e:
        print("An error occurred ! \n" + str(e))


def stop_sniffer_subfunction():
    if len(SNIFFER) > 0:
        if SNIFFER[0].is_alive():
            SNIFFER[0].kill()
            print("[INFO] Sniffer killed")
            db = PandoreSender(
                CONFIG.get_parameter('database', 'DB_HOST'),
                CONFIG.get_parameter('database', 'DB_PORT'),
                CONFIG.get_parameter('database', 'DB_USER'),
                CONFIG.get_parameter('database', 'DB_PASSWORD'),
                CONFIG.get_parameter('database', 'DB'))
            res = db.path_blank_end_time(datetime.datetime.utcnow())
            if res:
                print("[INFO] EndTime Blank patched")
            else:
                print("[INFO] No EndTime Blank patched or unable to patch")
            SNIFFER.clear()
        else:
            SNIFFER.clear()
    else:
        print("[INFO] No sniffer to kill ! Stop playing with the stop button !!")


def stop_sniffer_subfunction_by_id(capture_id=None):
    t_id = None
    for key in SNIFFERS_ID:
        if int(SNIFFERS_ID.get(key)) == int(capture_id):
            t_id = key

    if t_id is not None and capture_id is not None:
        db = PandoreSender(
            CONFIG.get_parameter('database', 'DB_HOST'),
            CONFIG.get_parameter('database', 'DB_PORT'),
            CONFIG.get_parameter('database', 'DB_USER'),
            CONFIG.get_parameter('database', 'DB_PASSWORD'),
            CONFIG.get_parameter('database', 'DB'))
        SNIFFERS_Thread[t_id].kill()
        db.path_blank_end_time_by_id(datetime.datetime.utcnow(), capture_id)
        db.close_db()
        print("[INFO] Thread " + str(t_id) + " Killed ! (Capture "+str(capture_id)+")")
        del SNIFFERS_Thread[t_id]
        del SNIFFERS_ID[t_id]
    elif len(SNIFFERS_Thread) == 1:
        t_id = None
        for t in SNIFFERS_Thread:
            t_id = t
            SNIFFERS_Thread[t].kill()
        db = PandoreSender(
            CONFIG.get_parameter('database', 'DB_HOST'),
            CONFIG.get_parameter('database', 'DB_PORT'),
            CONFIG.get_parameter('database', 'DB_USER'),
            CONFIG.get_parameter('database', 'DB_PASSWORD'),
            CONFIG.get_parameter('database', 'DB'))
        c_id = SNIFFERS_ID[t_id]
        db.path_blank_end_time_by_id(datetime.datetime.utcnow(), c_id)
        db.close_db()
        print("[INFO] Thread " + str(t_id) + " Killed ! (Capture "+str(c_id)+")")
        del SNIFFERS_Thread[t_id]
        del SNIFFERS_ID[t_id]
    else:
        print("[INFO] No sniffer to kill ! Stop playing with the stop button !!")


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
