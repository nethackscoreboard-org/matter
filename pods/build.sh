#!/usr/bin/env bash
export LABEL=${LABEL:-testing}

if [ -d pods ]; then
    cd pods
else
    echo "run from repository toplevel"
    exit 1
fi

# build container images
# database
# optional --build-args are POSTGRES_USER, POSTGRES_DB,
# POSTGRES_PASSWORD_FILE, PGDATA, FEEDER_DBUSER and STATS_DBUSER
# defaults are in pods/postgres/Dockerfile
podman build -t nhdb:$LABEL postgres || exit $?

# alpine-perl-cpanimus for building cpan deps
podman build -t cpan-env:$LABEL --target cpan-env feeder || exit $?
podman build -t cpan-feeder:$LABEL --target cpan-feeder feeder || exit $?

# nhdb-feeder.pl container
# possible --build-args for final target are listed below with defaults
# rundir, PERL5LIB, XLOGDIR
podman build -t feeder-skel:$LABEL --target feeder-skel feeder || exit $?
podman build -t nhdb-feeder:$LABEL --target nhdb-feeder feeder || exit $?

# mojolicious web frontend container
# possible --build-args for final target are listed below with defaults
# --build-arg rundir=/nhs/run 
# --build-arg perl_lib=/cpan/lib/perl5
# --build-arg path=/cpan/bin:/usr/local/bin:/usr/bin:/bin
podman build -t cpan-mojo:$LABEL --target cpan-mojo mojo || exit $?
podman build -t nhdb-mojo:$LABEL --target nhdb-mojo mojo || exit $?
