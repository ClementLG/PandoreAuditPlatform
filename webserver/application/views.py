from flask import Flask, request, redirect, url_for, render_template, json
import datetime
from application import app, pandoreDB, pandoreException

@app.errorhandler(404)
def page_not_found(e):
    return redirect(url_for('index'))

@app.route('/')
@app.route('/index')
def index():
    try:
        db = pandoreDB.PandoreDB()
        running_capture = db.get_running_capture()
        db.close_db()

        if(running_capture):
            return render_template("index2.html")
        else:
            return render_template("index.html")
    except Exception as e:
        try:
            if db :
                db.close_db()
        except:
            pass
        return render_template(
            "error.html",
            error=e
        )

@app.route('/check_capture_running', methods = ['POST', 'GET'])
def check_capture_running():
    if(request.method == 'GET'):
        return redirect(url_for('index'))
    try:
        db = pandoreDB.PandoreDB()
        running_capture = db.get_running_capture()
        db.close_db()
        if(running_capture):
            data = '1'
        else:
            data = '0'
        response = app.response_class(response=json.dumps(data),status=200,mimetype='application/json')
        return response
    except Exception as e:
        try:
            if db :
                db.close_db()
        except:
            pass
        return render_template(
            "error.html",
            error=e
        )

@app.route('/get_running_capture', methods = ['POST', 'GET'])
def get_running_capture():
    if(request.method == 'GET'):
        return redirect(url_for('index'))
    try:
        db = pandoreDB.PandoreDB()
        runningCapture = db.get_running_capture()
        if(runningCapture):
            captureInfo = db.find_capture_by_id(runningCapture[0])
            stats = db.get_capture_service_stat(runningCapture[0])
            total_trafic = db.get_capture_total_trafic(runningCapture[0])
        db.close_db()

        if not runningCapture:
            return json.jsonify(running="0")

        duration_second = (datetime.datetime.now() - captureInfo[2]).total_seconds()
    
        minutes = 0
        hours = 0
        up_trafic_nb = total_trafic[1]
        down_trafic_nb = total_trafic[0]

        while(duration_second >= 3600):
            duration_second -= 3600
            hours += 1

        while(duration_second >= 60):
            duration_second -= 60
            minutes += 1
    
        if(hours < 10):
            hours = "0" + str(hours)
        else:
            hours = str(hours)

        if(minutes < 10):
            minutes = "0" + str(minutes)
        else:
            minutes = str(minutes)

        if(int(duration_second) < 10):
            duration_second = "0" + str(int(duration_second))
        else:
            duration_second = str(int(duration_second))

        string_duration = hours + ":" + minutes + ":" + str(duration_second)

        up_trafic_unit = "B"
        down_trafic_unit = "B"

        if not up_trafic_nb:
            up_trafic_nb = 0
        if not down_trafic_nb:
            down_trafic_nb = 0

        if(up_trafic_nb > 0):
            up_down_ratio = round(down_trafic_nb/up_trafic_nb, 3)
        else:
            up_down_ratio = "-"

        # convert to good unit
        if(up_trafic_nb < 1024):
            up_trafic_unit = "B"
        elif(total_trafic[1] < (1024*1024)):
            up_trafic_nb = str(int(up_trafic_nb/1024))
            up_trafic_unit = "kB"
        else:
            up_trafic_nb = str(int(up_trafic_nb/(1024*1024)))
            up_trafic_unit = "MB"

        if(down_trafic_nb < 1024):
            down_trafic_unit = "B"
        elif(total_trafic[0] < (1024*1024)):
            down_trafic_nb = str(int(down_trafic_nb/1024))
            down_trafic_unit = "kB"
        else:
            down_trafic_nb = str(int(down_trafic_nb/(1024*1024)))
            down_trafic_unit = "MB"

        statistics = []

        for stat in stats:
            if stat[0]:
                name = stat[0]
            else:
                name = "Unknown"
            statistics.append([name, str(stat[1]), str(stat[2])])

        return json.jsonify(running="1", stats=statistics, name=captureInfo[1], startTime=captureInfo[2], description=captureInfo[4], downTrafic=down_trafic_nb, downTraficUnit=down_trafic_unit, upTrafic=up_trafic_nb, upTraficUnit=up_trafic_unit, duration=string_duration, ratio=up_down_ratio)
    except Exception as e:
        try:
            if db :
                db.close_db()
        except:
            pass
        return render_template(
            "error.html",
            error=e
        )

@app.route('/saved_captures')
def saved_captures():
    try:
        db = pandoreDB.PandoreDB()
        saved_captures = db.find_saved_captures()
        db.close_db()
        return render_template(
            "saved_captures.html",
            captures = saved_captures
            )
    except Exception as e:
        try:
            if db :
                db.close_db()
        except:
            pass
        return render_template(
            "error.html",
            error=e
        )

@app.route('/service/<id>', methods = ['POST', 'GET'])
def service(id):
    try:
        db = pandoreDB.PandoreDB()
        serviceInfo = db.find_service_by_id(id)
        serversInfo = db.find_service_all_servers(id, True)

        if(request.method == 'POST'):
                if(request.form['actionType'] == 'addServer'):
                    if(len(request.values) < 3 or len(request.values) > 4): raise pandoreException.PandoreException("Invalid number of arguments");
                    db.create_server_dns(request.form['addServerService'], request.form['addServerValue'], request.form['addServerDNS'] or None)
                    serversInfo = db.find_service_all_servers(id)
                elif(request.form['actionType'] == 'removeServer'):
                    if(len(request.values) != 2): raise pandoreException.PandoreException("Invalid number of arguments");
                    db.remove_service_from_server(request.form['removeServerID'])
                    serversInfo = db.find_service_all_servers(id, True)

        db.close_db()
        return render_template(
            "service.html",
            service=serviceInfo,
            servers=serversInfo
            )
    except pandoreException.PandoreException as e:
        if db :
            db.close_db()
        return render_template(
            "service.html",
            service=serviceInfo,
            servers=serversInfo,
            error=e
            )
    except Exception as e:
        try:
            if db :
                db.close_db()
        except:
            pass
        return render_template(
            "error.html",
            error=e
        )

@app.route('/saved_capture/<id>')
def saved_capture(id):
    try:
        if not id or not id.isnumeric():
            return redirect(url_for('index'))

        db = pandoreDB.PandoreDB()
        captureInfo = db.find_capture_by_id(id)
        captureRequests = db.find_all_capture_request(id, 1)
        statistics = db.get_capture_service_stat(id)
        total_trafic = db.get_capture_total_trafic(id)
        db.close_db()

        if not captureInfo:
            return redirect(url_for('saved_captures'))

        minutes = 0
        hours = 0
        up_trafic_nb = total_trafic[1]
        down_trafic_nb = total_trafic[0]
        up_trafic_unit = "B"
        down_trafic_unit = "B"

        if not up_trafic_nb:
            up_trafic_nb = 0
        if not down_trafic_nb:
            down_trafic_nb = 0

        if(up_trafic_nb > 0):
            up_down_ratio = round(down_trafic_nb/up_trafic_nb, 3)
        else:
            up_down_ratio = "-"

        # convert to good unit
        if(up_trafic_nb < 1024):
            up_trafic_unit = "B"
        elif(up_trafic_nb < (1024*1024)):
            up_trafic_nb = str(int(up_trafic_nb/1024))
            up_trafic_unit = "kB"
        else:
            up_trafic_nb = str(int(up_trafic_nb/(1024*1024)))
            up_trafic_unit = "MB"

        if(down_trafic_nb < 1024):
            down_trafic_unit = "B"
        elif(down_trafic_nb < (1024*1024)):
            down_trafic_nb = str(int(down_trafic_nb/1024))
            down_trafic_unit = "kB"
        else:
            down_trafic_nb = str(int(down_trafic_nb/(1024*1024)))
            down_trafic_unit = "MB"

        duration_second = (captureInfo[3] - captureInfo[2]).seconds
    
        while(duration_second >= 3600):
            duration_second -= 3600
            hours += 1

        while(duration_second >= 60):
            duration_second -= 60
            minutes += 1
    
        if(hours < 10):
            hours = "0" + str(hours)
        else:
            hours = str(hours)

        if(minutes < 10):
            minutes = "0" + str(minutes)
        else:
            minutes = str(minutes)

        if(duration_second < 10):
            duration_second = "0" + str(duration_second)
        else:
            duration_second = str(duration_second)

        string_duration = hours + ":" + minutes + ":" + duration_second

        return render_template(
                "saved_capture.html",
                capture = captureInfo,
                requests = captureRequests,
                duration = string_duration,
                up_trafic = up_trafic_nb,
                down_trafic = down_trafic_nb,
                up_unit = up_trafic_unit,
                down_unit = down_trafic_unit,
                ratio = up_down_ratio,
                stats = statistics
            )
    except Exception as e:
        try:
            if db :
                db.close_db()
        except:
            pass
        return render_template(
            "error.html",
            error=e
        )

@app.route('/configuration', methods = ['POST', 'GET'])
def services():
    try:
        db = pandoreDB.PandoreDB()

        servers = db.find_incomplete_servers()
        services = db.find_all_services()
        dns = db.find_all_dns()

        if(request.method == 'POST'):
            if(request.form['actionType'] == 'addService'):
                if(len(request.values) != 2): raise pandoreException.PandoreException("Invalid number of arguments");
                db.create_service(request.form['addServiceName'])
                services = db.find_all_services()
            elif(request.form['actionType'] == 'assignServerServiceDNS'):
                if(len(request.values) != 5): raise pandoreException.PandoreException("Invalid number of arguments");
                db.update_server(
                        request.form['assignServerID'],
                        request.form['assignServerAddress'],
                        request.form['assignServerService'],
                        request.form['assignServerDNS']
                    )
                servers = db.find_incomplete_servers()

        db.close_db()

        return render_template(
            "configuration.html",
            unknownServers = servers,
            allServices = services,
            allDNS = dns
        )
    except pandoreException.PandoreException as e:
        if db :
            db.close_db()
        return render_template(
            "configuration.html",
            unknownServers = servers,
            allServices = services,
            allDNS = dns,
            error = e
        )
    except Exception as e:
        try:
            if db :
                db.close_db()
        except:
            pass
        return render_template(
            "error.html",
            error=e
        )