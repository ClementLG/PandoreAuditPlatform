# Sniffer Agent

## A - description

The agent is the application which will make it possible to send the traffic in a formatted manner in a second application which will carry out more specific and cumbersome processing.

## B - Basic usage
1) setup python (3.6 or earlier) :
```
apt install python3.8
apt install python3-pip
```

2) Install dependencies :
```
pip 3 install pyshark
pip 3 install mysql-connector-python
```

or install using the requirements.txt
```
pip install --user -r requirements.txt
```

3) Configure the agent using the file *pandore-config.cfg* 

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
You can send the config file from the directory to the container using the following command :
```
docker run --rm -it  -v $(pwd)/pandore_config.py:/app/pandore_config.py --cap-add=NET_RAW --cap-add=NET_ADMIN --net=host pandore-sniffer
```

Environnement variable (-e option) can be used :
| VARIABLE| VALUE|
| ------ | ------ |
| PANDORE_AUDITED_INTERFACE| Interface to sniff
| PANDORE_DEVICE_NETWORK| Audited device network (use in filter)
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

---------------------------------------
