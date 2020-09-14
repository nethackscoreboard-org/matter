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
if	! podman image exists nhdb:$LABEL; then
	if [[ -z "$PGDATA" ]]; then
		podman build --squash -t nhdb:$LABEL postgres || exit $?
	else
		podman build --squash -t nhdb:$LABEL --build-arg my_pgdata=$PGDATA postgres || exit $?
	fi
fi

# alpine-perl-cpanimus for building cpan deps
podman image exists cpan-env:$LABEL || \
	podman build --squash -t cpan-env:$LABEL --target cpan-env feeder || exit $?
podman image exists cpan-feeder:$LABEL || \
	podman build --squash -t cpan-feeder:$LABEL --target cpan-feeder feeder || exit $?

# nhdb-feeder.pl container
# possible --build-args for final target are listed below with defaults
# rundir, PERL5LIB, XLOGDIR
podman image exists feeder-skel:$LABEL || \
	podman build --squash -t feeder-skel:$LABEL --target feeder-skel feeder || exit $?
podman build --squash -t nhdb-feeder:$LABEL --target nhdb-feeder feeder || exit $?

# mojolicious web frontend container
# possible --build-args for final target are listed below with defaults
# --build-arg rundir=/nhs/run 
# --build-arg perl_lib=/cpan/lib/perl5
# --build-arg path=/cpan/bin:/usr/local/bin:/usr/bin:/bin
podman image exists cpan-mojo:$LABEL || \
	podman build --squash -t cpan-mojo:$LABEL --target cpan-mojo mojo || exit $?

if [[ -z "$mojo_path" ]]; then
	podman build --squash -t nhdb-mojo:$LABEL --target nhdb-mojo mojo || exit $?
else
	podman build --squash --build-arg my_path=$mojo_path -t nhdb-mojo:$LABEL \
		--target nhdb-mojo mojo || exit $?
fi
