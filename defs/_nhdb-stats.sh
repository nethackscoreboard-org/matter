#!/usr/bin/env bash
set -x

pimg () {
    podman image $*
}

pcon () {
    podman container $*
}

stats-init () {
    podman run --pod nhdb-pod --name nhdb-stats --env $perl_lib \
        --rm -v $HOST_RUNDIR:$CONT_RUNDIR:rw -it \
        nhdb-stats:$LABEL ./nhdb-stats.pl $*
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

if pcon exists nhdb-stats; then
    podman kill nhdb-stats
    podman rm nhdb-stats
fi

stats-init $*
