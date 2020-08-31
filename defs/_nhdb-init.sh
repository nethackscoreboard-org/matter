#!/usr/bin/env bash

pimg () {
    podman image $*
}

pcon () {
    podman container $*
}

nhdb-init () {
    podman run --pod nhdb-pod --name nhdb --env pguser \
        --env $pgdb --env $pgpwd --env PGDATA=$PGDATA \
        -v nhdb-vol:$PGDATA:rw -dt nhdb postgres -c log_statement=none \
        -c checkpoint_completion_target=0.9
}

web-init () {
    podman run --pod nhdb-pod --name nhdb-web \
        -v $HOST_WEBDIR:/usr/share/nginx/html:ro -d nginx
}

feeder-init () {
    if [[ -n "$*" ]]; then
        cmd=./nhdb-feeder.pl $*
    else
        cmd=""
    fi
    podman run --pod nhdb-pod --name nhdb-feeder --env $perl_path \
       --rm -v $HOST_RUNDIR:$CONT_RUNDIR:rw -it \
       nhdb-feeder ${cmd:-$FEEDER_DEFAULT_CMD}

stats-init () {
    podman run --pod nhdb-pod --name nhdb-stats --env $perl_path \
        --rm -v $HOST_RUNDIR:$CONT_RUNDIR:rw -it \
        nhdb-stats ./nhdb-stats.pl $*
}

# have them all together in an isolated pod - this means
# they can talk to each other as if all on the same host,
# but we only access them via nginx on the port forwarded
# to the pod
podman pod exists nhdb-pod || podman pod create \
    -n nhdb-pod -p $HOST_WEBPORT:$CONT_WEBPORT/tcp

# if images don't exist, setup.sh has to be run from
# the repository
pimg exists nhdb && pimg exists nhdb-feeder \
    && pimg exists nhdb-stats \
    || echo "nhdb images aren't built, run setup.sh"
    && exit 1

pcon exists nhdb && pcon start nhdb || nhdb-init
pcon exists nhdb-web && pcon start nhdb-web || web-init

# special case these
if [[ $# -ge 0 ]]; then
    if [[ "$1" == "stats" ]]; then
        shift
        stats-init $*
        exit $?
    elif [[ "$1" == "feeder" ]]; then
        shift
        feeder-init $*
        exit $?
    fi
fi

pcon exists nhdb-feeder && pcon start nhdb-feeder || feeder-init
pcon exists nhdb-stats && pcon start nhdb-stats || stats-init
