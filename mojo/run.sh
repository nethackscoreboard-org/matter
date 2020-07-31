#!/usr/bin/env bash
if [ "$DOCKER" == "podman" ]; then
    networking="--pod nhs-pod -p 8085:8085/tcp"
else
    networking="--network nhs-bridge -p 8085:8085/tcp"
fi
PWD=`pwd`
$DOCKER run $networking --env-file env --name nhs-mojo -t -v $PWD:/run/nhs:ro,z mojo-img
