from flask import Flask, request, redirect, url_for, render_template, json
from datetime import datetime
from application import app, pandoreDB, pandoreException, configuration
from application.analytics.pandore_analytics import PandoreAnalytics
from application.models import *
import math

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
            captureInfo = db.find_capture_by_id(runningCapture.ID)
            stats = db.get_capture_service_stat(runningCapture.ID)
            total_trafic = db.get_capture_total_trafic(runningCapture.ID)
        db.close_db()

        if not runningCapture:
            return json.jsonify(running="0")

        duration_second = (datetime.now() - captureInfo.StartTime).total_seconds()
    
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

        return json.jsonify(running="1", stats=statistics, name=captureInfo.Name, startTime=captureInfo.StartTime, description=captureInfo.Description, downTrafic=down_trafic_nb, downTraficUnit=down_trafic_unit, upTrafic=up_trafic_nb, upTraficUnit=up_trafic_unit, duration=string_duration, ratio=up_down_ratio)
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
        keywordList = db.find_all_keyword_by_service(id)
        serviceList = db.find_all_services()
        serviceList.sort(key=lambda x: x.Priority)

        if(request.method == 'POST'):
            if(id == db.find_service_by_name("Intranet service").ID):
                raise pandoreException.PandoreException("You can't edit or delete this service")

            if(request.form['actionType'] == 'addServer'):
                if(len(request.values) < 2 or len(request.values) > 3): raise pandoreException.PandoreException("Invalid number of arguments");
                db.create_server_dns(db.find_service_by_id(id), request.form['addServerValue'], request.form['addServerDNS'] or None)
                serversInfo = db.find_service_all_servers(id, True)
            elif(request.form['actionType'] == 'removeServer'):
                if(len(request.values) != 2): raise pandoreException.PandoreException("Invalid number of arguments");
                db.remove_service_from_server(int(request.form['removeServerID']))
                serversInfo = db.find_service_all_servers(id, True)
            elif(request.form['actionType'] == 'addKeyword'):
                if(len(request.values) != 2): raise pandoreException.PandoreException("Invalid number of arguments");
                db.create_service_keyword(PandoreServiceKeyword(0, str(request.form['addKeywordValue']), db.find_service_by_id(id)))
                keywordList = db.find_all_keyword_by_service(id)
            elif(request.form['actionType'] == 'removeKeyword'):
                if(len(request.values) != 2): raise pandoreException.PandoreException("Invalid number of arguments");
                db.delete_keyword(PandoreServiceKeyword(int(request.form['removeKeywordID']), "", db.find_service_by_id(id)))
                keywordList = db.find_all_keyword_by_service(id)
            elif(request.form['actionType'] == 'removeService'):
                db.delete_service(db.find_service_by_id(id))
                return redirect(url_for('configuration'))
            elif(request.form['actionType'] == 'editService'):
                if(len(request.values) != 3): raise pandoreException.PandoreException("Invalid number of arguments");
                newService = PandoreService(int(id), str(request.form['editServiceName']), int(request.form['editServicePriority']))
                db.update_service(newService)
                serviceList = db.find_all_services()
                serviceList.sort(key=lambda x: x.Priority)
                serviceInfo = newService
        db.close_db()

        return render_template(
            "service.html",
            service=serviceInfo,
            servers=serversInfo,
            keywords=keywordList,
            services=serviceList
            )
    except pandoreException.PandoreException as e:
        if db :
            db.close_db()
        return render_template(
            "service.html",
            service=serviceInfo,
            servers=serversInfo,
            keywords = keywordList,
            services = serviceList,
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
        capture = db.find_capture_by_id(id)
        captureRequests = db.find_all_capture_request_not_detailed(id)
        statistics = db.get_capture_service_stat(id)
        total_trafic = db.get_capture_total_trafic(id)
        config = db.get_configuration()
        db.close_db()

        if not capture:
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

        duration_second = (capture.EndTime - capture.StartTime).total_seconds()
    
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

        requests_history = {}
        request_history_unit = "sec"

        if (capture.EndTime - capture.StartTime).total_seconds() > 3600:
            request_history_unit = "min"
            for request in captureRequests:
                minute = int((request.DateTime - capture.StartTime).total_seconds()/60)
                if minute in requests_history:
                    requests_history[minute] += 1
                else:
                    requests_history[minute] = 1

            for i in range(int((capture.EndTime - capture.StartTime).total_seconds()/60)):
                if i not in requests_history:
                    requests_history[i] = 0
        else:
            for request in captureRequests:
                second = int((request.DateTime - capture.StartTime).total_seconds())
                if second in requests_history:
                    requests_history[second] += 1
                else:
                    requests_history[second] = 1

            for i in range(int((capture.EndTime - capture.StartTime).total_seconds())):
                if i not in requests_history:
                    requests_history[i] = 0

        # NUTRISCORE
        if len(captureRequests) > 0 :
            timeBetweenConnections = []

            for i in range(len(captureRequests)-1):
                if ((captureRequests[i+1].DateTime - captureRequests[i].DateTime).total_seconds() >= capture.InactivityTimeout):
                    timeBetweenConnections.append((captureRequests[i+1].DateTime - captureRequests[i].DateTime).total_seconds())

            if len(timeBetweenConnections) > 0:
                nutriscoreFrequency =  1/(sum(timeBetweenConnections)/len(timeBetweenConnections))
            else:
                nutriscoreFrequency = 1   
            nutriscoreDebit = sum(req.PacketSize for req in captureRequests)/(capture.EndTime - capture.StartTime).total_seconds()
            nutriscoreDiversity = len({request.ServerValue for request in captureRequests})

            nutriscoreSigmoideFrequency = calculateSigmoide(config.NUTRISCORE_SIGMOIDE_SLOPE, (1/config.NUTRISCORE_REFERENCE_FREQUENCY), nutriscoreFrequency)
            nutriscoreSigmoideDebit = calculateSigmoide(config.NUTRISCORE_SIGMOIDE_SLOPE, config.NUTRISCORE_REFERENCE_DEBIT, nutriscoreDebit/(1024*1024))
            nutriscoreSigmoideDiversity = calculateSigmoide(config.NUTRISCORE_SIGMOIDE_SLOPE, config.NUTRISCORE_REFERENCE_DIVERSITY, nutriscoreDiversity)

            if(config.NUTRISCORE_AVERAGE_TYPE == 1):
                # Harmonic mean
                score = 1 - ((config.NUTRISCORE_WEIGHT_FREQUENCY+config.NUTRISCORE_WEIGHT_DEBIT+config.NUTRISCORE_WEIGHT_DIVERSITY)/((config.NUTRISCORE_WEIGHT_FREQUENCY/(1-nutriscoreSigmoideFrequency))+(config.NUTRISCORE_WEIGHT_DEBIT/(1-nutriscoreSigmoideDebit))+(config.NUTRISCORE_WEIGHT_DIVERSITY/(1-nutriscoreSigmoideDiversity))))
            else:
                # Arithmetic mean
                score = (config.NUTRISCORE_WEIGHT_FREQUENCY*nutriscoreSigmoideFrequency+config.NUTRISCORE_WEIGHT_DEBIT*nutriscoreSigmoideDebit+config.NUTRISCORE_WEIGHT_DIVERSITY*nutriscoreSigmoideDiversity)/(config.NUTRISCORE_WEIGHT_FREQUENCY+config.NUTRISCORE_WEIGHT_DEBIT+config.NUTRISCORE_WEIGHT_DIVERSITY)

            if (score >= 0 and score < 0.2):
                score = "A"
            elif (score >= 0.2 and score < 0.4):
                score = "B"
            elif (score >= 0.4 and score < 0.6):
                score = "C"
            elif (score >= 0.6 and score < 0.8):
                score = "D"
            elif (score >= 0.8):
                score = "E"
        else :
            score = "-"

        return render_template(
                "saved_capture.html",
                capture = capture,
                requests = captureRequests,
                duration = string_duration,
                up_trafic = up_trafic_nb,
                down_trafic = down_trafic_nb,
                up_unit = up_trafic_unit,
                down_unit = down_trafic_unit,
                ratio = up_down_ratio,
                stats = statistics,
                requests_history = dict(sorted(requests_history.items())),
                request_history_unit = request_history_unit,
                score = score
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
def configurations():
    try:
        db = pandoreDB.PandoreDB()
        servers = db.find_incomplete_servers()
        services = db.find_all_services()
        dns = db.find_all_dns()
        config = db.get_configuration()

        if(request.method == 'POST'):
            if(request.form['actionType'] == 'addService'):
                if(len(request.values) != 2): raise pandoreException.PandoreException("Invalid number of arguments")
                db.create_service(PandoreService(None, request.form['addServiceName']))
                services = db.find_all_services()
            elif(request.form['actionType'] == 'assignServerServiceDNS'):
                if(len(request.values) != 5): raise pandoreException.PandoreException("Invalid number of arguments")
                db.update_server(PandoreServer(int(request.form['assignServerID']), request.form['assignServerAddress'], db.find_dns_by_id(int(request.form['assignServerDNS'])), db.find_service_by_id(int(request.form['assignServerService']))))
                servers = db.find_incomplete_servers()
            elif(request.form['actionType'] == 'autoServerClassification'):
                serviceKeywords = []

                for service in services:
                    serviceKeywords.append(PandoreAnalyticsServiceKeywords(service, db.find_all_keyword_by_service(service.ID)))

                analytics = PandoreAnalytics(serviceKeywords)
                for server in servers:
                    service = analytics.analyse_ip_dns(config.ANALYTICS_TIMEOUT, server.Address, None if server.DNS is None else server.DNS.Value)
                    if service:
                        server.Service = service
                        db.update_server(server)
                servers = db.find_incomplete_servers()
            elif(request.form['actionType'] == 'editApplicationConfiguration'):
                if(len(request.values) != 10): raise pandoreException.PandoreException("Invalid number of arguments")
                db.update_configuration(PandoreConfiguration(int(request.form['analytics_timeout']), int(request.form['nutriscore_reference_frequency']), float(request.form['nutriscore_reference_debit']), int(request.form['nutriscore_reference_diversity']), int(request.form['nutriscore_weight_frequency']), int(request.form['nutriscore_weight_debit']), int(request.form['nutriscore_weight_diversity']), float(request.form['nutriscore_sigmoide_slope']), int(request.form['nutriscore_average_type'])))
                config = db.get_configuration()

        db.close_db()

        return render_template(
            "configuration.html",
            unknownServers = servers,
            allServices = services,
            allDNS = dns,
            config = config
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

def split_array(arr, size):
     arrs = []
     while len(arr) > size:
         pice = arr[:size]
         arrs.append(pice)
         arr   = arr[size:]
     arrs.append(arr)
     return arrs

def calculateSigmoide(slope: float, reference: float, value: float):
    if reference > 500:
        reference = 500
    return (1-math.exp(-slope*value))/(1+(math.exp(slope*reference)-2)*math.exp(-slope*value))