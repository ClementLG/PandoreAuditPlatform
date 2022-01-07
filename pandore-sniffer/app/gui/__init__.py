# PANDORE SNIFFER API - Flask app

# IMPORTS======================================================================
from time import sleep

from flask import Flask, jsonify, Request, render_template, Response
from flask_swagger import swagger
from app import pandore_sniffer
import datetime


# FLASK APP=====================================================================

app = Flask(__name__)


@app.route("/", methods=["GET"])
@app.route('/index', methods=["GET"])
def index():
    return render_template("logging/logging.html")

@app.route("/api/spec", methods=["GET"])
def spec():
    swag = swagger(app)
    swag['info']['version'] = "1.0"
    swag['info']['title'] = "Sniffer API"
    swag['info']['maintainer'] = "Clement LE GRUIEC"
    return jsonify(swag)

@app.route("/log_stream", methods=["GET"])
def stream():
    return Response(flask_logger(), mimetype="text/plain", content_type="text/event-stream")

# FUNCTIONS
def flask_logger():
    for i in range(100):
        current_time = datetime.datetime.now().strftime('%H:%M:%S') + "\n"
        yield current_time.encode()
        sleep(1)