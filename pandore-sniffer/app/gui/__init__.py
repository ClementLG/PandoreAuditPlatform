# PANDORE SNIFFER API - Flask app

# IMPORTS======================================================================
from time import sleep

from flask import Flask, jsonify, request, render_template, Response
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


@app.route("/", methods=["GET", "POST"])
@app.route('/index', methods=["GET", "POST"])
def index():
    if request.method == 'POST':
        if request.form['submit_button'] == 'Do Something':
            pass  # do something
        elif request.form['submit_button'] == 'Do Something Else':
            pass  # do something else
        else:
            print("passa kekchose")
            pass  # unknown
    elif request.method == 'GET':
        return render_template("logging/logging.html")



@app.route("/log_stream", methods=["GET"])
def stream():
    return Response(flask_logger(), mimetype="text/plain", content_type="text/event-stream")


@app.route("/api/configuration", methods=["GET"])
def config_get():
    config = {
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
    return jsonify(config)


@app.route("/api/configuration", methods=["POST"])
def config_post():
    request_data = request.get_json()
    update_variable_config(request_data)
    return config_get()


# Functions=========================================================================
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
            print(conf+"-->"+str(config_json['network'][conf]))
    if 'database' in config_json:
        for conf in config_json['database']:
            if conf in locals():
                print("exist")
                globals()[conf] = config_json['database'][conf]
            print(conf+"-->"+str(config_json['database'][conf]))
    if 'capture' in config_json:
        for conf in config_json['capture']:
            if conf in locals():
                globals()[conf] = config_json['capture'][conf]
            print(conf+"-->"+str(config_json['capture'][conf]))

