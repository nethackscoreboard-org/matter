#!/usr/bin/env bash
helpFunction()
{
    echo ""
    echo "Usage: $0 [ -d db_pw ] [ -f feeder_pw ] [ -s stats_pw ]"
    exit 1
}

while getopts "Sd:f:s:" opt
do
    case $opt in
        d ) database_pw="$OPTARG" ;;# set database password
        f ) feeder_pw="$OPTARG" ;;  # set feeder password
								    # is anyway default if the configs are missing
        s ) stats_pw="$OPTARG" ;;   # set stats password
        ? ) helpFunction ;;
    esac
done

# allow setting of passwords -- requires db/cfg reload
if [ ! -z "$feeder_pw" ]; then
    refresh_cfg="y"
else
    feeder_pw=feeder
fi
if [ ! -z "$stats_pw" ]; then
    refresh_cfg="y"
else
    stats_pw=stats
fi
if [ ! -z "$database_pw" ]; then
    refresh_cfg="y"
else
    database_pw=data
fi 

if which docker >/dev/null 2>&1; then
    export DOCKER=docker
elif which podman >/dev/null 2>&1; then
    export DOCKER=podman
else
    echo "Need a container to run (docker or podman)"
    exit 1
fi

# quit if NHS containers exist already
containers=`$DOCKER container ls -a | grep -E 'nhs-mojo|nhs-feeder|nhs-db'`
if [ -n "$containers" ]; then
    echo "NHS containers already found! - $containers"
    exit 1
fi

# quit if any config files exist that shouldn't be there yet
if [ -e ./postgres/env ] || [ -e ./feeder/cfg/auth.json ] || [ -e ./mojo/cfg/nethackstats.json ]; then 
	echo "Not a clean directory tree! run git clean -fx and try again."
    exit 1
fi

    
echo "Initialise Postgres container..."
cd postgres
./init.sh -f $feeder_pw -s $stats_pw -d $database_pw
./build.sh
./run.sh
sleep 30

echo "Build cpan build-tools..."
cd ../cpan
./build.sh

echo "Initialise feeder config..."
cd ../feeder
cp ../postgres/env ./my-env
cp ../mojo/env ./env
./init.sh
./build.sh
./run.sh

echo "Initialise mojo-web config..."
cd ../mojo
cp ../feeder/my-env ./my-env
./init.sh
./build.sh
./run.sh
