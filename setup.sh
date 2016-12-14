#!/bin/bash

volume_size=$db_size

function git_clone_with_retry () {
  local GIT_REPO=$1
  local DESTINATION=$2

  RETRIES=0
  until [ $RETRIES -ge 5 ]; do
    rm -rf $DESTINATION
    git clone $GIT_REPO $DESTINATION && return 0
    RETRIES=$[$RETRIES+1]
    sleep 5
  done
  return 1
}

apt-get -yqq update && apt-get -yqq install git golang go-md2man wget mongodb-clients
wget -qO- https://get.docker.com/ | sh

docker ps
if [[ $? != 0 ]]; then
  wc_notify --data-binary '{"status": "FAILURE", "reason": "Failed install docker."}'
  exit 1
fi

# setup docker lvm volume driver

git_clone_with_retry "https://github.com/projectatomic/docker-lvm-plugin" "/root/docker-lvm-driver"
if [[ $? != 0 ]]; then
  wc_notify --data-binary '{"status": "FAILURE", "reason": "Failed clone docker plugin repo."}'
  exit 1
fi

export GOPATH=/root/go; cd /root/docker-lvm-driver
go get github.com/Sirupsen/logrus
go get github.com/docker/docker/pkg/system
go get github.com/docker/go-plugins-helpers/volume
make && make install
if [[ $? != 0 ]]; then 
  wc_notify --data-binary '{"status": "FAILURE", "reason": "Failed install docker plugin."}'
  exit 1
fi

vgcreate vg-db /dev/xvdb
cat /etc/docker/docker-lvm-plugin | sed -e "s/^VOLUME_GROUP=/VOLUME_GROUP=vg-db/" > /tmp/jli-config
mv /tmp/jli-config /etc/docker/docker-lvm-plugin

service docker restart
service docker-lvm-plugin start
if [[ $? != 0 ]]; then 
  wc_notify --data-binary '{"status": "FAILURE", "reason": "Failed start docker plugin."}'
  exit 1
fi

docker volume create -d lvm --name primary --opt size=${volume_size}G
docker volume create -d lvm --name sec1 --opt size=${volume_size}G
docker volume create -d lvm --name sec2 --opt size=${volume_size}G
if [[ $? != 0 ]]; then
  wc_notify --data-binary '{"status": "FAILURE", "reason": "Failed create docker volumes."}'
  exit 1
fi

# setup mongo cluster

docker pull mongo:3.4
docker network create mongo-cluster

docker run --name mongo-pri -p 27017:27017 -v primary:/data/db --network mongo-cluster -d mongo mongod --replSet my-mongo-set
docker run --name mongo-sec1 -p 30001:27017 -v sec1:/data/db --network mongo-cluster -d mongo mongod --replSet my-mongo-set
docker run --name mongo-sec2 -p 30002:27017 -v sec2:/data/db --network mongo-cluster -d mongo mongod --replSet my-mongo-set

if [[ $? != 0 ]]; then
  wc_notify --data-binary '{"status": "FAILURE", "reason": "Failed run mongo."}'
  exit 1
fi

sleep 5

#mongo /root/mongo-cluster.js

if [[ $? != 0 ]]; then
  wc_notify --data-binary '{"status": "FAILURE", "reason": "Failed config mongo cluster."}'
else
  wc_notify --data-binary '{"status": "SUCCESS"}'
fi

