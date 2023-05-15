#!/bin/bash
set -ex
cd `dirname $0`
##########################################################

IMAGE="ghcr.io/lubinlew/geolite2_builder:latest"

docker build -t ${IMAGE} .

