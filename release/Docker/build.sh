#!/bin/bash
set -ex
cd `dirname $0`
##########################################################

IMAGE="ghcr.io/lubinlew/geolite2_builder:v1"

docker build -t ${IMAGE} .

