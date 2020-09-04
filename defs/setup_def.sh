# not executable, to be sourced by setup.sh
# general installation defs
export VM_NAME=kizul
export HOST_PREFIX=/usr/local
export HOST_RUNDIR=/usr/local/run
export HOST_MOJDIR=/usr/local/run
# for non-containerised setups
export HOST_XLOGDIR=/var/log/nhdb-xlogs 
export CONT_RUNDIR=/nhs
export CONT_MOJDIR=/nhs
export CONT_XLOGDIR=/var/log/xlog
export HOST_BINDIR=/usr/local/bin
export SETUP_MODE=docker

# database related definitions
export DBUSER=nhdb
export DBNAME=nhdb
export DBHOST=localhost
export FEEDER_DBUSER=nhdbfeeder
export STATS_DBUSER=nhdbstats
export PGDATA=/var/lib/postgresql/data/pgdata

if [[ "$SETUP_MODE" == "host" ]]; then
    export XLOGDIR=$HOST_XLOGDIR
else
    export XLOGDIR=$CONT_XLOGDIR
fi

# web definitions
# should be a subdirectory of $HOST_MOJDIR, so that
# a single bind mount (-v flag) is sufficient
export HOST_WEBDIR=${HOST_MOJDIR}/public
export CONT_WEBDIR=${CONT_MOJDIR}/public
if [[ "$SETUP_MODE" == "host" ]]; then
    export WEBDIR=$HOST_WEBDIR
else
    export WEBDIR=$CONT_WEBDIR
fi
export HOST_WEBPORT=8080
export CONT_WEBPORT=8080

# general defs related to containers,
# some will be listed here as just a comment
# containers will all be named nhdb or nhdb-something,
# the postgres container will be named nhdb,
# nginx web container nhdb-web,
# nhdb-feeder.pl container nhdb-feeder and nhdb-stats.pl
# will run in a container named nhdb-stats
# nhdb will also be the root of some other names e.g.
# volume nhdb-vol will contain persistent db information
# nhdb-pod will be the pod holding all the containers
if [[ "$SETUP_MODE" == "podman" || "$SETUP_MODE" == "docker" ]]; then
    # these secrets will be mapped to /run/secrets/nhdb
    # inside containers, as a directory with root db pass,
    # and other passwords inside
    export secrets="${PREFIX}/var/secrets/"
    export LABEL="testing" # tag images with branch name label
    export AUTH_JSON_PATH="/run/secrets/auth.json"
    export FEEDER_DEFAULT_CMD="./nhdb-feeder.pl"
    export auth_json_host="${secrets}/auth.json"
    
    # env vars for postgres container
    export pguser="POSTGRES_USER=$DBUSER"
    export pgdb="POSTGRES_DB=$DBNAME"
    #export pgauth_env="POSTGRES_HOST_AUTH_METHOD=password"
    export pgpass="POSTGRES_PASSWORD_FILE=/run/secrets/root"
    
    # env vars for perl/cpan containers
    export perl_lib="PERL5LIB=/cpan/lib/perl5"
    export path="PATH=/cpan/bin:/usr/local/bin:/usr/bin:/bin"
fi
