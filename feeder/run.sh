#!/usr/bin/env bash
if [ "$DOCKER" == "podman" ]; then
    networking="--pod nhs-pod"
else
    networking="--network nhs-bridge"
fi
PWD=`pwd`
$DOCKER run $networking --env-file env --name nhs-feeder -t -v $PWD:/run/nhs:ro,z -v nhs-xlog-vol:/var/log/xlogs:rw feeder-img
