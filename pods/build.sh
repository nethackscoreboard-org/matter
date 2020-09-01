#!/usr/bin/env bash
export LABEL=${LABEL:-latest}

if [ -d pods ]; then
    cd pods
else
    echo "run from pods directory"
    exit 1
fi

envsubst < feeder/_Dockerfile > feeder/Dockerfile
envsubst < stats/_Dockerfile  > stats/Dockerfile

# build container images
podman build -t nhdb:$LABEL postgres || exit $?
podman build -t cpan-env:$LABEL cpan || exit $?
podman build -t feeder-skel:$LABEL --target feeder-skel:$LABEL \
    feeder || exit $?
podman build -t cpan-feeder:$LABEL --target cpan-feeder:$LABEL \
    feeder || exit $?
podman build -t nhdb-feeder:$LABEL --target nhdb-feeder:$LABEL \
    --build-arg RUN=$CONT_RUNDIR feeder || exit $?
podman build -t nhdb-stats:$LABEL \
    --build-arg RUN=$CONT_RUNDIR stats || exit $?
podman pull nginx:alpine || exit $?
