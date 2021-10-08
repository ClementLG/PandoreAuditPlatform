from flask import Flask
from flask import render_template
from database.database import db, init_database


app = Flask(__name__)
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///database/database.db"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
db.init_app(app) # (1) flask prend en compte la base de donnee
with app.test_request_context(): # (2) bloc execute a l'initialisation de Flask
 init_database()



@app.route('/')
def index():
    return render_template("index.html")


@app.route('/view/a')
def view_a():
    return render_template("homepage.jinja2")


@app.route('/view/b')
def view_b():
    return render_template("template_b.html.jinja2")


@app.route('/view/c')
def view_c():
    return render_template("template_c.html.jinja2")


if __name__ == '__main__':
    app.run()
