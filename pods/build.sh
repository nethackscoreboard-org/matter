#!/usr/bin/env bash
export LABEL=${LABEL:-latest}

if [ -d pods ]; then
    cd pods
else
    echo "run from pods directory"
    exit 1
fi

envsubst < feeder/_Dockerfile > feeder/Dockerfile
envsubst < mojo/_Dockerfile  > mojo/Dockerfile

# build container images
# database
podman build -t nhdb:$LABEL postgres || exit $?

# alpine-perl-cpanimus for building cpan deps
podman build -t cpan-env:$LABEL --target cpan-env:$LABEL feeder || exit $?
podman build -t cpan-feeder:$LABEL --target cpan-feeder:$LABEL feeder || exit $?

# nhdb-feeder.pl container
podman build -t feeder-skel:$LABEL --target feeder-skel:$LABEL feeder || exit $?
podman build -t nhdb-feeder:$LABEL --target nhdb-feeder:$LABEL --build-arg RUN=$CONT_RUNDIR feeder || exit $?

# mojolicious web frontend container
podman build -t cpan-mojo:$LABEL --target cpan-mojo:$LABEL mojo || exit $?
podman build -t nhdb-mojo:$LABEL --target nhdb-mojo:$LABEL --build-arg RUN=$CONT_RUNDIR mojo || exit $?
