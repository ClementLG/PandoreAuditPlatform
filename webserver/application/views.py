from flask import Flask, request, redirect, url_for, render_template, json, session
from datetime import datetime
from application import app, pandoreDB, pandoreException, configuration, utils
from application.pandore_analytics import PandoreAnalytics
from application.models import *
import requests, time, math

analytics_running = False
current_analytic_number = 0
current_analytic_number_servers = 0
stop_analytics_running = False

PandoreAnalyticsRunner = PandoreAnalytics()

@app.errorhandler(404)
def page_not_found(e):
    return redirect(url_for('index'))

@app.route('/', methods = ['POST', 'GET'])
@app.route('/index', methods = ['POST', 'GET'])
def index():
    try:
        db = pandoreDB.PandoreDB()
        configuration = db.get_configuration()
        db.close_db()

        if request.method == "POST":
            if 'action' not in request.form: raise pandoreException.PandoreException("Action is missing")
            else:
                if request.form['action'] == 'startCapture':
                    if 'capture_name' not in request.form: raise pandoreException.PandoreException("Capture name is missing")
                    if 'capture_description' not in request.form: raise pandoreException.PandoreException("Capture description is missing")
                    if 'capture_connection_type' not in request.form: raise pandoreException.PandoreException("Connection type is missing")
                    if 'interface_name' not in request.form: raise pandoreException.PandoreException("Interface name is missing")
                    if 'capture_duration' not in request.form: raise pandoreException.PandoreException("Capture duration is missing")
                    if 'ip_w' not in request.form: raise pandoreException.PandoreException("IP is incomplete")
                    if 'ip_x' not in request.form: raise pandoreException.PandoreException("IP is incomplete")
                    if 'ip_y' not in request.form: raise pandoreException.PandoreException("IP is incomplete")
                    if 'ip_z' not in request.form: raise pandoreException.PandoreException("IP is incomplete")
                    if 'netmask_w' not in request.form: raise pandoreException.PandoreException("Netmask is incomplete")
                    if 'netmask_x' not in request.form: raise pandoreException.PandoreException("Netmask is incomplete")
                    if 'netmask_y' not in request.form: raise pandoreException.PandoreException("Netmask is incomplete")
                    if 'netmask_z' not in request.form: raise pandoreException.PandoreException("Netmask is incomplete")
                    elif len(request.form['capture_name']) <= 0 or len(request.form['capture_name']) > 255:
                        raise pandoreException.PandoreException("Capture name must contain between 1 and 255 characters")
                    elif len(request.form['capture_description']) <= 0 or len(request.form['capture_description']) > 1000:
                        raise pandoreException.PandoreException("Capture description must contain between 1 and 1000 characters")
                    elif len(request.form['capture_connection_type']) <= 0 or len(request.form['capture_connection_type']) > 255:
                        raise pandoreException.PandoreException("Capture connection type must contain between 1 and 255 characters")
                    elif len(request.form['interface_name']) <= 0 or len(request.form['interface_name']) > 255:
                        raise pandoreException.PandoreException("Interface name must contain between 1 and 255 characters")
                    elif not request.form['capture_duration'].isnumeric():
                        raise pandoreException.PandoreException("Capture duration must be a number")
                    elif int(request.form['capture_duration']) <= 0:
                        raise pandoreException.PandoreException("Capture duration must be greater than 0")
                    elif not request.form['ip_w'].isnumeric() or not request.form['ip_x'].isnumeric() or not request.form['ip_y'].isnumeric() or not request.form['ip_z'].isnumeric():
                        raise pandoreException.PandoreException("Audited device(s) IP must only contain numbers")
                    elif (int(request.form['ip_w']) < 0 or int(request.form['ip_w']) > 255) or (int(request.form['ip_x']) < 0 or int(request.form['ip_x']) > 255) or (int(request.form['ip_y']) < 0 or int(request.form['ip_y']) > 255) or (int(request.form['ip_z']) < 0 or int(request.form['ip_z']) > 255):
                        raise pandoreException.PandoreException("Invalid IP")
                    elif not request.form['netmask_w'].isnumeric() or not request.form['netmask_x'].isnumeric() or not request.form['netmask_y'].isnumeric() or not request.form['netmask_z'].isnumeric():
                        raise pandoreException.PandoreException("Audited device(s) netmask must only contain numbers")
                    elif (int(request.form['netmask_w']) < 0 or int(request.form['netmask_w']) > 255) or (int(request.form['netmask_x']) < 0 or int(request.form['netmask_x']) > 255) or (int(request.form['netmask_y']) < 0 or int(request.form['netmask_y']) > 255) or (int(request.form['netmask_z']) < 0 or int(request.form['netmask_z']) > 255):
                        raise pandoreException.PandoreException("Invalid netmask")
                    netmask = sum(bin(int(x)).count('1') for x in (request.form['netmask_w'] + "." + request.form['netmask_x'] + "." + request.form['netmask_y'] + "." + request.form['netmask_z']).split('.'))
                    ip = request.form['ip_w'] + "." + request.form['ip_x'] + "." + request.form['ip_y'] + "." + request.form['ip_z']
                    data = {
                        "capture": {
                            "CAPTURE_CNX_TYPE": request.form['capture_connection_type'],
                            "CAPTURE_DESCRIPTION": request.form['capture_description'],
                            "CAPTURE_DURATION": int(request.form['capture_duration']),
                            "CAPTURE_NAME": request.form['capture_name']
                        },
                        "network": {
                            "AUDITED_INTERFACE": request.form['interface_name'],
                            "DEVICE_NETWORK": ip + "/" + str(netmask)
                        }
                    }
                    requests.post(configuration.SNIFFER_API_ADDRESS + "/configuration", json=data, timeout=10)
                    requests.post(configuration.SNIFFER_API_ADDRESS + "/start", timeout=10)
                elif request.form['action'] == "stopCapture":
                    if 'capture_to_stop_id' not in request.form: raise pandoreException.PandoreException("Capture ID is missing")
                    else:
                        data={
                            "CaptureID": request.form['capture_to_stop_id']
                            }
                        requests.post(configuration.SNIFFER_API_ADDRESS + "/stop", json=data, timeout=10)
                elif request.form['action'] == "stopAllCaptures":
                    requests.post(configuration.SNIFFER_API_ADDRESS + "/stop", timeout=10)
                else:
                    raise pandoreException.PandoreException("Invalid or unknown action")
        return render_template("index.html")
    except pandoreException.PandoreException as e:
        if db :
            db.close_db()
        return render_template(
            "index.html",
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

@app.route('/get_running_captures', methods = ['POST', 'GET'])
def get_running_captures():
    if(request.method == 'GET'):
        return redirect(url_for('index'))
    try:
        captures = []
        db = pandoreDB.PandoreDB()
        runningCaptures = db.get_running_captures()
        if(len(runningCaptures) > 0):
            for capture in runningCaptures:
                data = {}
                total_trafic = db.get_capture_total_trafic(capture.ID)
                data["id"] = capture.ID
                data["name"] = capture.Name
                data["description"] = capture.Description + " | " + capture.ConnectionType + " | " + capture.Interface
                data["start_time"] = capture.StartTime.strftime("%d/%m/%Y %H:%M:%S")
                data["duration"] = utils.second_to_duration((datetime.utcnow() - capture.StartTime).total_seconds())
                data["ttdown"] = utils.octet_to_string(total_trafic[0])
                data["ttup"] = utils.octet_to_string(total_trafic[1])
                captures.append(data)
        db.close_db()
        response = app.response_class(response=json.dumps(captures),status=200,mimetype='application/json')
        return response
    except Exception as e:
        try:
            if db :
                db.close_db()
        except:
            pass
        return str(e), 500

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

        string_duration = utils.second_to_duration((capture.EndTime - capture.StartTime).total_seconds())

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

@app.route('/get_analytics_running_status', methods = ['POST', 'GET'])
def get_analytics_running_status():
    global PandoreAnalyticsRunner
    if PandoreAnalyticsRunner.isAnalyticsRunning():
        response = app.response_class(response=json.dumps([str(PandoreAnalyticsRunner.getNumberOfProcessedServers()), str(PandoreAnalyticsRunner.getNumberOfUnknownServers())]),status=200,mimetype='application/json')
    else:
        response = app.response_class(response=json.dumps([str(0)]),status=200,mimetype='application/json')
    return response

@app.route('/stop_analytics', methods = ['POST', 'GET'])
def stop_analytics():
    if(request.method == 'POST'):
        global PandoreAnalyticsRunner
        if PandoreAnalyticsRunner.isAnalyticsRunning():
            PandoreAnalyticsRunner.stop_analytics()
        response = app.response_class(response=json.dumps(0),status=200,mimetype='application/json')
        return response

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
                global PandoreAnalyticsRunner
                if not PandoreAnalyticsRunner.isAnalyticsRunning():
                    serviceKeywords = []
                    for service in services:
                        serviceKeywords.append(PandoreAnalyticsServiceKeywords(service, db.find_all_keyword_by_service(service.ID)))
                    PandoreAnalyticsRunner.run_analytics(servers, serviceKeywords, config.ANALYTICS_TIMEOUT)
            elif(request.form['actionType'] == 'editApplicationConfiguration'):
                if(len(request.values) != 11): raise pandoreException.PandoreException("Invalid number of arguments")
                db.update_configuration(PandoreConfiguration(int(request.form['analytics_timeout']), int(request.form['nutriscore_reference_frequency']), float(request.form['nutriscore_reference_debit']), int(request.form['nutriscore_reference_diversity']), int(request.form['nutriscore_weight_frequency']), int(request.form['nutriscore_weight_debit']), int(request.form['nutriscore_weight_diversity']), float(request.form['nutriscore_sigmoide_slope']), int(request.form['nutriscore_average_type']), request.form['sniffer_api_address']))
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
        PandoreAnalyticsRunner.stop_analytics()
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
            PandoreAnalyticsRunner.stop_analytics()
            if db :
                db.close_db()
        except:
            pass
        return render_template(
            "error.html",
            error=e
        )

@app.route('/sniffer_configuration', methods = ['POST', 'GET'])
def sniffer_configuration():
    try:
        success = None
        db = pandoreDB.PandoreDB()
        configuration = db.get_configuration()
        db.close_db()
        if request.method == "POST":
            if(len(request.values) != 5): raise pandoreException.PandoreException("Invalid number of arguments")
            data = {
                    "database": {
                        "DB": request.form['db_name'],
                        "DB_HOST": request.form['db_host'],
                        "DB_PASSWORD": request.form['db_password'],
                        "DB_PORT": int(request.form['db_port']),
                        "DB_USER": request.form['db_user']
                    }
                }
            requests.post(configuration.SNIFFER_API_ADDRESS + "/configuration", json=data, timeout=10)
            success = "Sniffer configuration edited successfully"
        snifferConf = requests.get(configuration.SNIFFER_API_ADDRESS + "/configuration", timeout=10)
        snifferConfiguration = snifferConf.json()
        return render_template(
            "sniffer_configuration.html",
            snifferConfiguration = snifferConfiguration,
            snifferAPIConfigurationURL = configuration.SNIFFER_API_ADDRESS + "/configuration",
            success=success
        )
    except pandoreException.PandoreException as e:
        if db :
            db.close_db()
        return render_template(
            "sniffer_configuration.html",
            snifferConfiguration = snifferConfiguration,
            snifferAPIConfigurationURL = configuration.SNIFFER_API_ADDRESS + "/configuration",
            success=success
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