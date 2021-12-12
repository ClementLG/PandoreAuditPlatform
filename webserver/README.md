# Sniffer Agent

## A - description

Pandore GUI allows to have a readable version of the captured data and to easily handle the data stored in the DB.

## B - Basic usage

1) setup python :

```
apt install python3.9
apt install python3-pip
```

2) Install dependencies :

```
pip install --user -r requirements.txt
```

3) Configure the GUI using the file *application/configuration.cfg* 

```
nano ./application/configuration.cfg
```

4) Launch the application *runserver.py*
```
python3 runserver.py.py
```

By default the server listens on port 5555. Locally you can access via [http://localhost:5555/](http://localhost:5555/) (Remotly using [http://*host_IP*:5555/](http://host_IP:5555/))

## C - Docker usage

1) setup docker using the following tutorial :
https://docs.docker.com/engine/install/debian/

2) Build the pandore network image (You have to be in the dockerfile directory) :
```
docker build --tag "pandore-gui:latest" .
```

3) Run the container :

To run the container, use the following command :
```
docker run -p 5555:5555/tcp --name pandoregui pandore-gui
```


Environnement variable (-e option) can be used (not develloped yet) :
| VARIABLE| VALUE|
| ------ | ------ |
| XXX | XXX
| XXX | XXX
| XXX | XXX

---------------------------------------
