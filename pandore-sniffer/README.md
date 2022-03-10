# Sniffer Agent

## A - description

Pandore sniffer is the module that captures and sends traffic to the database. A second application (analytics) performs more specific and heavy processing.

In order to handle the sniffer more easily, a REST API has been created and can be used optionally.

## B - Basic usage
1) setup python (3.6 or earlier) :
```
apt install python3.8
apt install python3-pip
```

2) Install dependencies :

Install the necessary libraries using the requirements.txt and pip
```
pip install --user -r requirements.txt
```

3) Configure the agent using the file *pandore-config.ini*

_Note that you can enable the API by setting the Sniffer-GUI option on True_
_You should be able to update the configuration using the REST API (this avoids having to restart the program)_

4) Launch the application *pandore_agent.py*
```
python3 pandore_agent.py
```

## C - Docker usage

1) setup docker using the following tutorial :
https://docs.docker.com/engine/install/debian/

2) Build the pandore network image (You have to be in the dockerfile directory) :
```
docker build --tag "pandore-sniffer:latest" .
```

3) Run the container :

To run the container, use the following command :
```
docker run --rm -it --cap-add=NET_RAW --cap-add=NET_ADMIN --net=host pandore-sniffer

```
_The '--rm' option is not required. This only allows the container to be deleted when the sniffer operation is complete or on a CTRL+C_

You can send the config file from the directory to the container using the following command :
```
docker run --rm -it  -v $(pwd)/pandore_config.ini:/app/pandore_config.ini --cap-add=NET_RAW --cap-add=NET_ADMIN --net=host pandore-sniffer
```

Environnement variable (-e option) can be used :
| VARIABLE| VALUE|
| ------ | ------ |
| PANDORE_AUDITED_INTERFACE| Interface to sniff
| PANDORE_DEVICE_NETWORK| Audited device network (use in filter)
| PANDORE_DEVICE_NETWORK_IPv6| Audited device network (use in filter)
| PANDORE_CUSTOM_FILTER| [Custom Filter](https://biot.com/capstats/bpf.html)
| PANDORE_DB_HOST| DB server address
| PANDORE_DB_PORT| DB server port
| PANDORE_DB_USER| DB server user
| PANDORE_DB_PASSWORD| DB server password
| PANDORE_DB| DB name
| PANDORE_CAPTURE_NAME| A custom name for your capture
| PANDORE_CAPTURE_DURATION| A custom duration for your capture in seconds
| PANDORE_CAPTURE_DESCRIPTION| A custom description for your capture
| PANDORE_CAPTURE_CNX_TYPE| A tag to mention the connexion type
| TZ| To use a custom time zone. Default is 'Europe/Paris'
| PANDORE_SNIFFER_GUI | 'True' or 'False' Enable or disable the API

Exemple to change the audited interface using the environment variables :

```
docker run --rm -it --cap-add=NET_RAW --cap-add=NET_ADMIN --net=host -e PANDORE_AUDITED_INTERFACE="Ethernet X" pandore-sniffer
```

note: if you have multiple options, you have to reuse '-e' behind each option.

## D - API

In order to facilitate the use of the sniffer and allow remote control, here are the different API paths

- **[GET]** _/api_: Access the API documentation based on Swagger (Possitibilty to perform test) (Not configured at this time)

- **[GET]** _/api/configuration_: Return the last sniffer configuration as a JSON.

- **[POST]** _/api/configuration_: Allow the possibility to send a configuration.

Example of JSON to send:

```
{
    "capture": {
        "CAPTURE_CNX_TYPE": "Cable-pc",
        "CAPTURE_DESCRIPTION": "description test",
        "CAPTURE_DURATION": 10,
        "CAPTURE_NAME": "capture"
    },
    "database": {
        "DB": "Pandore",
        "DB_HOST": "192.168.100.10",
        "DB_PASSWORD": "my-secret-pw",
        "DB_PORT": 3306,
        "DB_USER": "root"
    },
    "network": {
        "AUDITED_INTERFACE": "Ethernet",
        "CUSTOM_FILTER": "not port 1194 and not port 3306",
        "DEVICE_NETWORK": "192.168.10.0/24"
    }
}
```

If you want, you can only update one or several field(s):
```
{
    "network": {
        "AUDITED_INTERFACE": "Ethernet2"
    }
}
```

IPv6 is supported. You are able tu use only Ipv6, Ipv4, or both :
```
{
    "network": {
        "DEVICE_NETWORK": "192.168.10.0/24"
        "DEVICE_NETWORK_IPv6": "2a01:cb08:8615:1100:19ec:d30b:d159:8595/128"
    }
}
```
note: To specify a host only, just use a /32 or /128.

- **[POST]** _/api/start_: Start a sniffer (no JSON to send, only use POST method). Multiple sniffer can be launched at the same time. Sniffer is launched using the last configuration (The config you get usinf /api/configuration)

- **[POST]** _/api/stop_: Stop the sniffer

Example to stop the capture with ID 109:
```
{
    "CaptureID":"109"
}
```
If there is only one sniffer, you can only send a stop command in POST, and sniffer will kill the alone running sniffer.

- **[GET]** _/api/status_: return the number of running thread. This command will evolve is a close future.

---------------------------------------
