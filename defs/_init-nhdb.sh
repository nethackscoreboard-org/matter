#!/usr/bin/env bash
set -x

pimg () {
    podman image $*
}

pcon () {
    podman container $*
}

nhdb-init () {
    # best to run this with -it and have it run in tmux
    # or something like that so you can see the logs
    podman run --pod nhdb-pod --name nhdb --env $pguser \
        --env $pgdb --env $pgpass --env PGDATA=$PGDATA \
        -v nhdb-vol:$PGDATA:rw -it nhdb:$LABEL postgres \
        -c log_statement=none -c checkpoint_completion_target=0.9
}

# have them all together in an isolated pod - this means
# they can talk to each other as if all on the same host,
# but we only access them via nginx on the port forwarded
# to the pod
podman pod exists nhdb-pod || podman pod create \
    -n nhdb-pod -p $HOST_WEBPORT:$CONT_WEBPORT/tcp

# if images don't exist, setup.sh has to be run from
# the repository
pimg exists nhdb:$LABEL && pimg exists nhdb-feeder:$LABEL \
    && pimg exists nhdb-mojo:$LABEL || fail=yes
if [[ "${fail:-}" == "yes" ]]; then
    echo "nhdb images aren't built, run setup.sh"
    exit 1
fi

pcon exists nhdb && pcon start nhdb || nhdb-init
