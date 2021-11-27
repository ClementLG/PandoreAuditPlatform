# Sniffer Agent

## A - description

The agent is the application which will make it possible to send the traffic in a formatted manner in a second application which will carry out more specific and cumbersome processing.

## B - Basic usage
1) setup python :
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
```
docker run --rm -it  --cap-add=NET_RAW --cap-add=NET_ADMIN --net=host pandorenetwork
```

2) Build the pandore network image (You have to be in the dockerfile directory) :
```
docker build --tag "pandore-sniffer:latest" .
```

3) Run the container :

To run the container, use the following command :
```
docker run --rm -it --cap-add=NET_RAW --cap-add=NET_ADMIN --net=host pandorenetwork

```
You can send the config file from the directory to the container using the following command :
```
docker run --rm -it  -v $(pwd)/pandore_config.py:/app/pandore_config.py --cap-add=NET_RAW --cap-add=NET_ADMIN --net=host pandorenetwork
```

Environnement variable (-e option) can be used (not develloped yet) :
| VARIABLE| VALUE|
| ------ | ------ |
| AUDITED_INTERFACE| Interface to sniff
| DEVICE_NETWORK| Audited device network (use in filter)
| CUSTOM_FILTER| [Custom Filter](https://biot.com/capstats/bpf.html)
| DB_HOST| DB server address
| DB_PORT| DB server port
| DB_USER| DB server user
| DB_PASSWORD| DB server password
| DB| DB name

---------------------------------------
