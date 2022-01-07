# PANDORE SNIFFER API

# IMPORTS======================================================================

import os
from gui import app

# VARIABLES=====================================================================

# CODE==========================================================================
if __name__ == '__main__':
    HOST = os.environ.get('SERVER_HOST', '0.0.0.0')

    try:
        PORT = int(os.environ.get('SERVER_PORT', '5555'))
    except ValueError:
        PORT = 5555

    app.run(HOST, PORT)
