# Database

## A - description

The database is used to store all the data captured by the sniffer. It also makes it possible, by reading it, to display the data on the web GUI.

## B - Basic usage

Setup MariaDB using the following tutorial [here](https://www.digitalocean.com/community/tutorials/how-to-install-mariadb-on-ubuntu-20-04-quickstart-fr)

## C - Docker usage

#### Setup guide

1) setup docker using the following tutorial :
https://docs.docker.com/engine/install/debian/

2) Build the pandore network image (You have to be in the dockerfile directory) :
```
docker build --tag "pandore-db:latest" .
```

3) Run the container :

To run the container, use the following command :
```
docker run -p 3306:3306/tcp --name pandoredb pandore-db
```

4) _Optionnal_ - To bind the data from the database (in the container) to a directory on the host you can use the following command :

```
docker run -v /my/own/datadir:/var/lib/mysql -p 3306:3306/tcp --name pandoredb pandore-db
```

The -v /my/own/datadir:/var/lib/mysql part of the command mounts the /my/own/datadir directory from the underlying host system as /var/lib/mysql inside the container, where MariaDB by default will write its data files.

#### Default values

- User: root
- Password: pandore
- Database: Pandore
- Port: 3306

#### Environnement variable (-e option) :

| VARIABLE| VALUE|
| ------ | ------ |
| MARIADB_ROOT_PASSWORD | Custom password for the root user
| MARIADB_ALLOW_EMPTY_ROOT_PASSWORD | Use 'yes' if you want to disable password (not recommanded)
| MARIADB_RANDOM_ROOT_PASSWORD | Use 'yes' if you want to generate a random password. Printed in stdout. (not recommanded)
| MARIADB_USER | Create a custom user (default with all acess)
| MARIADB_PASSWORD | Password for the custom user


Example :
```
docker run -v /my/own/datadir:/var/lib/mysql -p 3306:3306/tcp --name pandoredb -e MARIADB_ROOT_PASSWORD="MyPassword" pandore-db
```

note : reuse '-e' behind each option.

---------------------------------------
