#!/usr/bin/env bash
export pguser='POSTGRES_USER=nhdb'
export pgdb='POSTGRES_DB=nhdb'
export pgauth='POSTGRES_HOST_AUTH_METHOD=password'
export pgpwd='POSTGRES_PASSWORD=dbpass'
export perl_path='PERL5LIB=/cpan-mods/lib/perl5'
export cpan_path='/cpan-mods/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin'
export PGDATA=/var/lib/postgresql/data/pgdata
export ext_port=${WEB_PORT:-8080}

pimg () {
    podman image $*
}

pcon () {
    podman container $*
}

nhdb-init () {
    podman run --pod nhdb-pod --name nhdb --env $pguser --env $pgdb \
        --env $pgauth --env $pgpwd --env PGDATA=$PGDATA \
        -v nhdb-vol:$PGDATA:rw -dt nhdb postgres -c log_statement=none \
        -c checkpoint_completion_target=0.9
}

web-init () {
    podman run --pod nhdb-pod --name nhdb-web \
        -v $PWD/www:/usr/share/nginx/html:ro -d nginx
}

do-builds () {
    podman build -t nhdb pods/postgres
    podman build -t cpan-env pods/cpan
    podman build -t feeder-skel --target skel pods/feeder
    podman build -t cpan-feeder --target cpan-deps pods/feeder
    podman build -t nhdb-feeder --target small pods/feeder
    podman build -t nhdb-stats pods/stats
    podman pull nginx:alpine
}

feeder-init () {
    if [[ -n "$*" ]]; then
        cmd=./nhdb-feeder.pl $*
    else
        cmd=""
    fi
    podman run --pod nhdb-pod --name nhdb-feeder --env $perl_path \
       --env $cpan_path --rm -v $PWD:/run/nhs:rw -it nhdb-feeder $cmd
}

stats-init () {
    podman run --pod nhdb-pod --name nhdb-stats --env $perl_path \
        --env $cpan_path --rm -v $PWD:/run/nhs:rw -it nhdb-stats \
        ./nhdb-stats.pl $*
}

# have them all together in an isolated pod - this means
# they can talk to each other as if all on the same host,
# but we only access them via nginx on the port forwarded
# to the pod
podman pod exists nhdb-pod || podman pod create -n nhdb-pod -p $port:80/tcp

pimg exists nhdb || do-builds
pimg exists nhdb-feeder || do-builds
pimg exists nhdb-stats || do-builds

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
