#!/usr/bin/env bash
pguser='POSTGRES_USER=nhdb'
pgdb='POSTGRES_DB=nhdb'
pgauth='POSTGRES_HOST_AUTH_METHOD=password'
pgpwd='POSTGRES_PASSWORD=dbpass'
perl_path='PERL5LIB=/cpan-mods/lib/perl5'
cpan_path='/cpan-mods/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin'
PGDATA=/var/lib/postgresql/data/pgdata
port=${NGINX_PORT:-8080}

podman build -t nhdb pods/postgres
podman build -t cpan-env pods/cpan
podman build -t feeder-skel --target skel pods/feeder
podman build -t cpan-feeder --target cpan-deps pods/feeder
podman build -t nhdb-feeder --target small pods/feeder
podman build -t nhdb-stats pods/stats
podman pull nginx:alpine

# have them all together in an isolated pod - this means
# they can talk to each other as if all on the same host,
# but we only access them via nginx on the port forwarded
# to the pod
podman pod create -n nhdb-pod -p $port:$port/tcp

podman run --pod nhdb-pod --name nhdb --env $pguser --env $pgdb \
    --env $pgauth --env $pgpwd --env PGDATA=$PGDATA \
    -v nhdb-vol:$PGDATA:rw -dt nhdb postgres -c log_statement=none \
    -c checkpoint_completion_target=0.9

podman run --pod nhdb-pod --name nhdb-web --env NGINX_PORT=$port \
    -v $PWD/www:/usr/share/nginx/html:ro -d nginx

podman run --pod nhdb-pod --name nhdb-feeder --env $perl_path \
       --env $cpan_path --rm -v $PWD:/run/nhs:rw -it nhdb-feeder

podman run --pod nhdb-pod --name nhdb-stats --env $perl_path \
        --env $cpan_path --rm -v $PWD:/run/nhs:rw -it nhdb-stats
