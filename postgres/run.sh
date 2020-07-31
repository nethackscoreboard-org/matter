#!/usr/bin/env bash
if [ "$DOCKER" == "podman" ]; then
    networking="--pod nhs-pod"
    $DOCKER pod create -n nhs-pod -p 8085:8085/tcp
else
    $DOCKER network create -d bridge nhs-bridge
    networking="-p 5432:5432/tcp --network=nhs-bridge"
fi
$DOCKER run $networking --name nhs-db --env-file ./env -dt -v nhs-db-vol:$PGDATA:rw postgres-nhs postgres -c log_statement=none -c checkpoint_completion_target=0.9
