from flask import Flask
from flask import render_template
from database.database import db, init_database
import os
from pprint import pprint
from ipwhois import IPWhois
import json
template_dir = os.path.abspath('../FrontEnd/source')
print(template_dir)
app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///database/database.db"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
db.init_app(app)  # (1) flask prend en compte la base de donnee
with app.test_request_context():  # (2) bloc execute a l'initialisation de Flask
    init_database()


#@app.route('/index', methods=['POST', 'GET'])
#@app.route('/', methods=['POST', 'GET'])
#def index():
#    jsonfile = "{rice: 5, yam: 6, tomato: 0, potato: 0,beans: 0, maize: 0, oil: 3}"
#    obj = IPWhois('74.125.225.229')
#    res = obj.lookup_rdap(root_ent_check=False)['network']['name']
#    pprint(res)
#    return render_template("index.html",jsonfile=jsonfile, test=res)

@app.route('/index', methods=['POST', 'GET'])
@app.route('/', methods=['POST', 'GET'])
def index():
    return render_template("index.html")


@app.route('/index2', methods=['POST', 'GET'])
def index2():
    return render_template("index2.html")


@app.route('/saved_capture', methods=['POST', 'GET'])
def saved_capture():
    return render_template("saved_capture.html")


@app.route('/saved_captures', methods=['POST', 'GET'])
def saved_captures():
    return render_template("saved_captures.html")


@app.route('/service', methods=['POST', 'GET'])
def service():
    return render_template("service.html")


@app.route('/services', methods=['POST', 'GET'])
def services():
    return render_template("services.html")

if __name__ == '__main__':
    app.run()
