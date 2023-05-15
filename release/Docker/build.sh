#!/bin/bash
set -ex
cd `dirname $0`
##########################################################
IMAGE="ghcr.io/lubinlew/geolite2_builder:latest"

if docker pull ${IMAGE} &> /dev/null ; then
  docker build -t ${IMAGE} .
  docker push ${IMAGE}
fi
