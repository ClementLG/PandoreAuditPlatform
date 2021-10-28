from flask import Flask
from flask import render_template
from database.database import db, init_database
import json

app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///database/database.db"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
db.init_app(app)  # (1) flask prend en compte la base de donnee
with app.test_request_context():  # (2) bloc execute a l'initialisation de Flask
    init_database()


@app.route('/index', methods = ['POST', 'GET'])
@app.route('/', methods = ['POST', 'GET'])
def index():
    jsonfile = "{rice: 5, yam: 6, tomato: 0, potato: 0,beans: 0, maize: 0, oil: 3}"
    return render_template("index.html",jsonfile=jsonfile, test='jpp')


if __name__ == '__main__':
    app.run()
