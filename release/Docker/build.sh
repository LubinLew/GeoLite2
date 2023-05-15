#!/bin/bash
set -e
cd `dirname $0`
##########################################################
IMAGE="ghcr.io/lubinlew/geolite2_builder:latest"

if docker pull ${IMAGE} &> /dev/null ; then
  docker build -t ${IMAGE} .
fi
