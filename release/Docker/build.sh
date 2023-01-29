#!/bin/bash
set -e
cd `dirname $0`
##########################################################
IMAGE="lubinlew/geolite2rebuild:latest"

docker build -t ${IMAGE} .
docker push     ${IMAGE}
