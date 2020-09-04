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
docker build -t nhdb:$LABEL postgres || exit $?

# alpine-perl-cpanimus for building cpan deps
docker build -t cpan-env:$LABEL --target cpan-env feeder || exit $?
docker build -t cpan-feeder:$LABEL --target cpan-feeder feeder || exit $?

# nhdb-feeder.pl container
docker build -t feeder-skel:$LABEL --target feeder-skel feeder || exit $?
docker build -t nhdb-feeder:$LABEL --target nhdb-feeder --build-arg RUN=$CONT_RUNDIR feeder || exit $?

# mojolicious web frontend container
docker build -t cpan-mojo:$LABEL --target cpan-mojo mojo || exit $?
docker build -t nhdb-mojo:$LABEL --target nhdb-mojo --build-arg RUN=$CONT_RUNDIR mojo || exit $?
