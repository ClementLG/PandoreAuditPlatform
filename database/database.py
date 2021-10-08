from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


def init_database():
    db.create_all()


class Server(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    adresse = db.Column(db.String(1000))


class Capture(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255))
    description = db.Column(db.String(1000))


class ServiceRequest(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    packetSize = db.Column(db.Float)
    direction = db.Column(db.Boolean)
    dateTime = db.Column(db.DateTime)
    server_id = db.Column(db.Integer,  db.ForeignKey('server.id'))
    capture_id = db.Column(db.Integer,  db.ForeignKey('capture.id'))


class Service(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(1000))


class Configuration(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    connection_Type = db.Column(db.String(255))
    interface = db.Column(db.String(255))


