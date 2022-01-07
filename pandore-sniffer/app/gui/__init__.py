# PANDORE SNIFFER API - Flask app

# IMPORTS======================================================================
from time import sleep

from flask import Flask, jsonify, Request, render_template, Response
from flask_swagger_ui import get_swaggerui_blueprint
from app import pandore_sniffer
from app.pandore_config import *
import datetime

# FLASK APP=====================================================================

app = Flask(__name__)

# SWAGGER=======================================================================
SWAGGER_URL = '/api'
API_URL = '/static/swagger/swagger.json'
SWAGGERUI_BLUEPRINT = get_swaggerui_blueprint(
    SWAGGER_URL,
    API_URL,
    config={
        'app_name': "Pandore Sniffer API"
    }
)
app.register_blueprint(SWAGGERUI_BLUEPRINT, url_prefix=SWAGGER_URL)

# FLASK ROUTES===================================================================


@app.route("/", methods=["GET"])
@app.route('/index', methods=["GET"])
def index():
    return render_template("logging/logging.html")


@app.route("/log_stream", methods=["GET"])
def stream():
    return Response(flask_logger(), mimetype="text/plain", content_type="text/event-stream")


# Functions=========================================================================
def flask_logger():
    for i in range(100):
        current_time = datetime.datetime.now().strftime('%H:%M:%S') + "\n"
        yield current_time.encode()
        sleep(1)
