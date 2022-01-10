# PANDORE SNIFFER API - Flask views

# IMPORTS======================================================================

from flask import Flask, jsonify, request, render_template, Response
from app.gui import sniffer_gui
from app.gui.functions import *


# FLASK ROUTES===================================================================

@sniffer_gui.route("/", methods=["GET"])
@sniffer_gui.route('/index', methods=["GET"])
def index():
    return render_template("logging/logging.html", configs=get_sniffer_config())


@sniffer_gui.route("/log_stream", methods=["GET"])
def stream():
    return Response(flask_logger(), mimetype='text/html', content_type="text/event-stream")


@sniffer_gui.route("/api/configuration", methods=["GET"])
def config_get():
    config = get_sniffer_config()
    return jsonify(config)


@sniffer_gui.route("/api/configuration", methods=["POST"])
def config_post():
    request_data = request.get_json()
    update_variable_config(request_data)
    return config_get()


@sniffer_gui.route("/api/start", methods=["POST"])
def start_sniffer():
    start_sniffer_subfunction_v2()
    return jsonify('Start OK')


@sniffer_gui.route("/api/stop", methods=["POST"])
def stop_sniffer():
    stop_sniffer_subfunction_v2()
    return jsonify('Stop OK')
