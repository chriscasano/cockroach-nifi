# cockroach-nifi
## Data flows for you and your roaches

This repo explains how to scale up your ingestion into CockroachDB using Apache Nifi.  You can run this demonstration using either Docker Compose or roachprod.  There are flow templates in ./nifi which you can run in your NiFi environment as well.

## Some Education...

Slides: https://www.slideshare.net/ChrisCasano/scaling-writes-on-cockroachdb-with-apache-nifi

Overview Videos here:

- Part I (CockroachDB): https://youtu.be/w3rMvzi2rEU
- Part II (Apache NiFi): https://youtu.be/PPUBXEUrGhc

And Demonstration Videos here:  https://youtu.be/Yw3i7og1RQ0

## Docker Deployment

##### To startup, clone the repository and cd into in.

`docker-compose up --build`

In another shell run the following...

`deploy-docker.sh`

##### To shutdown

`destory-docker.sh`

## Roachprod Deployment

##### To startup, clone the repository and cd into in.

`./deploy-roachprod.sh`

##### To shutdown

`./destroy-roachprod.sh`
