from datetime import datetime
from application import app, pandoreDB, pandoreException, utils
from application.pandore_analytics import PandoreAnalytics
from application.models import *
import requests, math, time, flask
from flask import redirect, url_for, render_template, json, request, Response

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
                if 'action' not in request.form: raise pandoreException.PandoreException("Action is missing")
                elif request.form['action'] == 'startCapture':
                    ipv4 = None
                    ipv6 = None
                    if 'capture_name' not in request.form: raise pandoreException.PandoreException("Capture name is missing")
                    elif 'capture_duration_hour' not in request.form: raise pandoreException.PandoreException("Capture duration hour is missing")
                    elif 'capture_duration_minute' not in request.form: raise pandoreException.PandoreException("Capture duration minute is missing")
                    elif 'capture_duration_second' not in request.form: raise pandoreException.PandoreException("Capture duration second is missing")
                    elif 'capture_description' not in request.form: raise pandoreException.PandoreException("Capture description is missing")
                    elif 'capture_connection_type' not in request.form: raise pandoreException.PandoreException("Connection type is missing")
                    elif 'capture_interface_name' not in request.form: raise pandoreException.PandoreException("Interface name is missing")
                    
                    if('switch_ipv4' in request.form and bool(request.form['switch_ipv4'])):
                        if 'ipv4_netmask' not in request.form: raise pandoreException.PandoreException("IPv4 netmask is missing")
                        elif int(request.form['ipv4_netmask']) < 0 or int(request.form['ipv4_netmask']) > 32: raise pandoreException.PandoreException("Invalid IPv4 netmask value")
                        for i in range(4):
                            if "ipv4_" + str(i+1) not in request.form: raise pandoreException.PandoreException("Capture IPv4 value missing at position " + str(i+1))
                            if len(request.form["ipv4_" + str(i+1)]) == 0: raise pandoreException.PandoreException("Capture IPv4 invalid value at position " + str(i+1))
                            if int(request.form["ipv4_" + str(i+1)]) < 0 or int(request.form["ipv4_" + str(i+1)]) > 255: raise pandoreException.PandoreException("Capture IPv4 invalid value at position " + str(i+1))
                        ipv4 = str(request.form["ipv4_1"]) + "." + str(request.form["ipv4_2"]) + "." + str(request.form["ipv4_3"]) + "." + str(request.form["ipv4_4"]) + "/" + str(request.form["ipv4_netmask"])
                    
                    if('switch_ipv6' in request.form and bool(request.form['switch_ipv6'])):
                        if 'ipv6_netmask' not in request.form: raise pandoreException.PandoreException("IPv6 netmask is missing")
                        elif int(request.form['ipv6_netmask']) < 0 or int(request.form['ipv6_netmask']) > 128: raise pandoreException.PandoreException("Invalid IPv6 netmask value")
                        for i in range(8):
                            if "ipv6_" + str(i+1) not in request.form: raise pandoreException.PandoreException("Capture IPv6 value missing at position " + str(i+1))
                            if(len(request.form["ipv6_" + str(i+1)]) != 4): raise pandoreException.PandoreException("Capture IPv6 invalid value at position " + str(i+1))
                            else:
                                for c in request.form["ipv6_" + str(i+1)]:
                                    if (not ((ord(c) >= 48 and ord(c) <= 57) or (ord(c) >= 97 and ord(c) <= 102))): raise pandoreException.PandoreException("Capture IPv6 invalid value at position " + str(i+1))
                        ipv6 = str(request.form["ipv6_1"]) + ":" + str(request.form["ipv6_2"]) + ":" + str(request.form["ipv6_3"]) + ":" + str(request.form["ipv6_4"]) + ":" + str(request.form["ipv6_5"]) + ":" + str(request.form["ipv6_6"]) + ":" + str(request.form["ipv6_7"]) + ":" + str(request.form["ipv6_8"]) + "/" + str(request.form["ipv6_netmask"])
                    
                    if ipv4 is None and ipv6 is None: raise pandoreException.PandoreException("IPv4 or IPv6 must be selected")

                    if len(request.form['capture_name']) <= 0 or len(request.form['capture_name']) > 255: raise pandoreException.PandoreException("Capture name must contain between 1 and 255 characters")
                    elif len(request.form['capture_description']) <= 0 or len(request.form['capture_description']) > 1000: raise pandoreException.PandoreException("Capture description must contain between 1 and 1000 characters")
                    elif len(request.form['capture_connection_type']) <= 0 or len(request.form['capture_connection_type']) > 255: raise pandoreException.PandoreException("Capture connection type must contain between 1 and 255 characters")
                    elif len(request.form['capture_interface_name']) <= 0 or len(request.form['capture_interface_name']) > 255: raise pandoreException.PandoreException("Interface name must contain between 1 and 255 characters")
                    elif int(request.form['capture_duration_hour']) < 0: raise pandoreException.PandoreException("Capture duration hour must be greater or equal to 0")
                    elif int(request.form['capture_duration_minute']) < 0 or int(request.form['capture_duration_minute']) > 59: raise pandoreException.PandoreException("Capture duration minute must be between 0 and 59")
                    elif int(request.form['capture_duration_second']) < 0 or int(request.form['capture_duration_second']) > 59: raise pandoreException.PandoreException("Capture duration second must be between 0 and 59")
                    elif int(request.form['capture_duration_hour']) == 0 and int(request.form['capture_duration_minute']) == 0 and int(request.form['capture_duration_second']) == 0: raise pandoreException.PandoreException("Capture duration must be greater than 0 second")

                    data = {
                        "capture": {
                            "CAPTURE_CNX_TYPE": request.form['capture_connection_type'],
                            "CAPTURE_DESCRIPTION": request.form['capture_description'],
                            "CAPTURE_DURATION": int(request.form['capture_duration_hour'])*3600 + int(request.form['capture_duration_minute'])*60 + int(request.form['capture_duration_second']),
                            "CAPTURE_NAME": request.form['capture_name']
                        },
                        "network": {
                            "AUDITED_INTERFACE": request.form['capture_interface_name'],
                            "DEVICE_NETWORK": ipv4 if ipv4 is not None else "null",
                            "DEVICE_NETWORK_IPv6": ipv6 if ipv6 is not None else "null"
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

@app.route('/export_database', methods= ['GET'])
def export_database():
    jsonSave = {}
    db = pandoreDB.PandoreDB()
    configuration = db.get_configuration()
    jsonSave["Configuration"] = {
                "NUTRISCORE_REFERENCE_FREQUENCY": configuration.NUTRISCORE_REFERENCE_FREQUENCY,
                "NUTRISCORE_REFERENCE_DEBIT": configuration.NUTRISCORE_REFERENCE_DEBIT,
                "NUTRISCORE_REFERENCE_DIVERSITY": configuration.NUTRISCORE_REFERENCE_DIVERSITY,
                "NUTRISCORE_WEIGHT_FREQUENCY": configuration.NUTRISCORE_WEIGHT_FREQUENCY,
                "NUTRISCORE_WEIGHT_DEBIT": configuration.NUTRISCORE_WEIGHT_DEBIT,
                "NUTRISCORE_WEIGHT_DIVERSITY": configuration.NUTRISCORE_WEIGHT_DIVERSITY,
                "NUTRISCORE_SIGMOIDE_SLOPE": configuration.NUTRISCORE_SIGMOIDE_SLOPE,
                "NUTRISCORE_AVERAGE_TYPE": configuration.NUTRISCORE_AVERAGE_TYPE,
                "SNIFFER_API_ADDRESS": configuration.SNIFFER_API_ADDRESS
            }
    servicesList = db.find_all_services()
    services = {}
    for service in servicesList:
        regexList = db.find_all_keyword_by_service(service.ID)
        regexs = []
        for regex in regexList:
            regexs.append(regex.Value)
        services[service.Name] = regexs
    jsonSave["Services"] = services
    db.close_db()
    return Response(json.dumps(jsonSave, indent = 4), mimetype="text/plain", headers={"Content-Disposition": "attachment;filename=Pandore_save_" + datetime.now().strftime("%d%m%Y%H%M%S") + ".psave"})

@app.route('/import_database', methods= ['POST'])
def import_database():
    try:
        if request.method == 'POST':
            if 'pandore_save_file' not in request.files:
                raise pandoreException.PandoreException("No pandore save file uploaded")
            elif request.files['pandore_save_file'].filename.split('.')[len(request.files['pandore_save_file'].filename.split('.'))-1] != "psave":
                raise pandoreException.PandoreException("Invalid pandore save file")
            else: 
                data = json.load(request.files['pandore_save_file'].stream)
                Configuration = PandoreConfiguration(
                        data["Configuration"]["NUTRISCORE_REFERENCE_FREQUENCY"],
                        data["Configuration"]["NUTRISCORE_REFERENCE_DEBIT"],
                        data["Configuration"]["NUTRISCORE_REFERENCE_DIVERSITY"],
                        data["Configuration"]["NUTRISCORE_WEIGHT_FREQUENCY"],
                        data["Configuration"]["NUTRISCORE_WEIGHT_DEBIT"],
                        data["Configuration"]["NUTRISCORE_WEIGHT_DIVERSITY"],
                        data["Configuration"]["NUTRISCORE_SIGMOIDE_SLOPE"],
                        data["Configuration"]["NUTRISCORE_AVERAGE_TYPE"],
                        data["Configuration"]["SNIFFER_API_ADDRESS"]
                    )
                db = pandoreDB.PandoreDB()
                db.update_configuration(Configuration)
                for service in data["Services"]:
                    ServiceInDB = db.find_service_by_name(service)
                    if ServiceInDB is None:
                        db.create_service(PandoreService(None, service))
                        ServiceInDB = db.find_service_by_name(service)
                    RegexsInDB = db.find_all_keyword_by_service(ServiceInDB.ID)
                    for regex in data["Services"][service]:
                        if not any(x.Value == regex for x in RegexsInDB):
                            db.create_service_keyword(PandoreServiceKeyword(None, regex, ServiceInDB))
                db.close_db()
                return redirect(url_for('configurations'))

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
                data["ttdown"] = utils.octet_to_string(total_trafic['Down'], 2)
                data["ttup"] = utils.octet_to_string(total_trafic['Up'], 2)
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
        dnsInfo = db.find_service_all_dns(id)
        keywordList = db.find_all_keyword_by_service(id)

        if(request.method == 'POST'):
            if(id == db.find_service_by_name("Intranet service").ID):
                raise pandoreException.PandoreException("You can't edit or delete this service")
            elif(request.form['actionType'] == 'removeDNS'):
                if(len(request.values) != 2): raise pandoreException.PandoreException("Invalid number of arguments");
                dns = db.find_dns_by_id(int(request.form['removeDNSID']))
                if dns is None:
                    raise pandoreException.PandoreException("Impossible to find the given DNS")
                else:
                    dns.Service = None
                    db.update_dns(dns)
                    dnsInfo = db.find_service_all_dns(id)
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
                return redirect(url_for('configurations'))
            elif(request.form['actionType'] == 'editService'):
                if(len(request.values) != 2): raise pandoreException.PandoreException("Invalid number of arguments");
                newService = PandoreService(int(id), str(request.form['editServiceName']))
                db.update_service(newService)
                serviceInfo = newService
        db.close_db()

        return render_template(
            "service.html",
            service=serviceInfo,
            dnsInfo=dnsInfo,
            keywords=keywordList
            )
    except pandoreException.PandoreException as e:
        if db :
            db.close_db()
        return render_template(
            "service.html",
            service=serviceInfo,
            keywords = keywordList,
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

@app.route('/saved_capture/<id>', methods = ['GET', 'POST'])
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
        if (flask.request.method == "POST"):
            if "action" in flask.request.form:
                if flask.request.form["action"] == "deleteCapture":
                    db.delete_capture_by_id(id)
                    db.close_db()
                    return redirect(url_for('saved_captures'))
        db.close_db()

        if not capture:
            return redirect(url_for('saved_captures'))

        string_duration = utils.second_to_duration((capture.EndTime - capture.StartTime).total_seconds())
        up_trafic = utils.octet_to_string(total_trafic["Up"], 2)
        down_trafic = utils.octet_to_string(total_trafic["Down"], 2)

        if(total_trafic["Up"] > 0):
            up_down_ratio = round(total_trafic["Down"]/total_trafic["Up"], 3)
        else:
            up_down_ratio = "-"

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
                mean_deconnection_time = str(round(sum(timeBetweenConnections)/len(timeBetweenConnections), 2)) + "s"
                nutriscoreFrequency =  1/(sum(timeBetweenConnections)/len(timeBetweenConnections))
            else:
                nutriscoreFrequency = 1
                mean_deconnection_time = "0s"

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

            score_details = {
                "Score": score,
                "Bandwidth": utils.octet_to_string(nutriscoreDebit, 2) + "/s",
                "Diversity": nutriscoreDiversity,
                "NumberOfDeconnection": len(timeBetweenConnections),
                "MeanDeconnectionTime": mean_deconnection_time
                }
        else :
            score_details = {
                "Score": "-",
                "Bandwidth": "-",
                "Diversity": 0,
                "NumberOfDeconnection": "-",
                "MeanDeconnectionTime": "-"
                }

        return render_template(
                "saved_capture.html",
                capture = capture,
                requests = captureRequests,
                duration = string_duration,
                up_trafic = up_trafic,
                down_trafic = down_trafic,
                ratio = up_down_ratio,
                stats = statistics,
                requests_history = dict(sorted(requests_history.items())),
                request_history_unit = request_history_unit,
                score_details = score_details
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
        response = app.response_class(response=json.dumps([str(PandoreAnalyticsRunner.getNumberOfProcessedDNS()), str(PandoreAnalyticsRunner.getNumberOfUnknownDNS())]),status=200,mimetype='application/json')
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
        incomplete_dns = db.find_incomplete_dns()
        services = db.find_all_services()
        config = db.get_configuration()
        if(request.method == 'POST'):
            if(request.form['actionType'] == 'addService'):
                if(len(request.values) != 2): raise pandoreException.PandoreException("Invalid number of arguments")
                db.create_service(PandoreService(None, request.form['addServiceName']))
                services = db.find_all_services()
            elif(request.form['actionType'] == 'assignDNSService'):
                if(len(request.values) != 3): raise pandoreException.PandoreException("Invalid number of arguments")
                dns = db.find_dns_by_id(int(request.form['assignDNSService_ID']))
                service = db.find_service_by_id(int(request.form['assignDNSService_Service']))
                if not dns:
                    raise pandoreException.PandoreException("Invalid domain name ID")
                elif not service:
                    raise pandoreException.PandoreException("Invalid domain name service")
                else:
                    dns.Service = service
                    db.update_dns(dns)
                    incomplete_dns = db.find_incomplete_dns()
            elif(request.form['actionType'] == 'autoDomainClassification'):
                global PandoreAnalyticsRunner
                if not PandoreAnalyticsRunner.isAnalyticsRunning():
                    PandoreAnalyticsRunner.run_analytics(incomplete_dns, db.find_all_service_keyword())
                    time.sleep(1)
                    incomplete_dns = db.find_incomplete_dns()
            elif(request.form['actionType'] == 'editApplicationConfiguration'):
                if(len(request.values) != 10): raise pandoreException.PandoreException("Invalid number of arguments")
                db.update_configuration(PandoreConfiguration(int(request.form['nutriscore_reference_frequency']), float(request.form['nutriscore_reference_debit']), int(request.form['nutriscore_reference_diversity']), int(request.form['nutriscore_weight_frequency']), int(request.form['nutriscore_weight_debit']), int(request.form['nutriscore_weight_diversity']), float(request.form['nutriscore_sigmoide_slope']), int(request.form['nutriscore_average_type']), request.form['sniffer_api_address']))
                config = db.get_configuration()
        db.close_db()

        return render_template(
            "configuration.html",
            incomplete_dns = incomplete_dns,
            allServices = services,
            config = config
        )
    except pandoreException.PandoreException as e:
        PandoreAnalyticsRunner.stop_analytics()
        if db :
            db.close_db()
        return render_template(
            "configuration.html",
            incomplete_dns = incomplete_dns,
            allServices = services,
            config = config,
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