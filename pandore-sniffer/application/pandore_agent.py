#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# INFO=========================================================================
__project__ = "Pandore"
__maintainer__ = "Clement LE GRUIEC"
__version__ = "1.0"
__Created__ = "09/10/2021"
__team__ = ["Clement LE GRUIEC", "Hugo HOUILLON", "Salma CHAHMI", "Nathan OLBORSKI"]
__school__ = "IMT Atlantique"
__course__ = "3rd year engineering project"
__subject__ = "Characterization of the sneaky traffic generated by mobile applications"
__description__ = "The agent is the application which allow to send the network traffic in a formatted manner " \
                  "in a second application which will carry out more specific and cumbersome processing."

# IMPORTS======================================================================
import asyncio.exceptions
import os
from pandore_sniffer import PandoreSniffer
from pandore_config import PandoreConfig

# VARIABLES====================================================================

CONFIG = PandoreConfig('pandore_config.ini')

# MAIN=========================================================================

if os.environ.get('PANDORE_SNIFFER_GUI') is not None:
    CONFIG.update_parameter('gui', 'SNIFFER_GUI', str(os.environ.get('PANDORE_SNIFFER_GUI')))

if CONFIG.get_parameter('gui', 'sniffer_gui') == 'True':
    os.system('python pandore_api.py')
else:
    capture = PandoreSniffer()
    try:
        capture.run()
    except asyncio.exceptions.TimeoutError:
        capture.finish()
        print("\nEnd of the capture !")
    except Exception as e:
        print("An error occurred ! \n" + e)
