#!/usr/bin/env bash
set -x

pimg () {
    podman image $*
}

pcon () {
    podman container $*
}

feeder-init () {
    if [[ -n "$*" ]]; then
        cmd="./nhdb-feeder.pl $*"
    else
        cmd=""
    fi
    podman run --pod nhdb-pod --name nhdb-feeder --env $perl_lib \
       --rm -v $HOST_RUNDIR:$CONT_RUNDIR:rw -it \
       nhdb-feeder:$LABEL ${cmd:-$FEEDER_DEFAULT_CMD}
}

# pod with networking should be started by nhdb-init.sh
podman pod exists nhdb-pod
if [[ $? -ne 0 ]]; then
    echo "pod nhdb-pod doesn't exist, run nhdb-init.sh first" >&2
    exit 1
fi

# if images don't exist, setup.sh has to be run from
# the repository
pimg exists nhdb:$LABEL && pimg exists nhdb-feeder:$LABEL \
    && pimg exists nhdb-stats:$LABEL || fail=yes
if [[ "${fail:-}" == "yes" ]]; then
    echo "nhdb images aren't built, run setup.sh" >&2
    exit 1
fi

if pcon exists nhdb-feeder; then
    podman kill nhdb-feeder
    podman rm nhdb-feeder
fi

feeder-init $*