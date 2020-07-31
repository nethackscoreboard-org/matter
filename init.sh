#!/usr/bin/env bash
helpFunction()
{
    echo ""
    echo "Usage: $0 [ -S ] [ -d db_pw ] [ -f feeder_pw ] [ -s stats_pw ]"
    echo -e "\t-S Fix SELinux tags on legacy/ and mojo/ bind-mounts (need sudo)."
    exit 1
}

while getopts "Sd:f:s:" opt
do
    case $opt in
		S ) selinux="y" ;; 		    # fix SELinux tags for bind mounts - sudo req.
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

# quit if NHS containers exist already
containers=`docker container ls -a --format='{{json .Names}}' | sed s/\"//g | grep -E 'nhs-web-m|nhdb-feeder|nhs-db'`
if [ ! -z "$containers" ]; then
    echo "NHS containers already found! - $containers"
    exit 1
fi

# quit if any config files exist that shouldn't be there yet
if [ -e ./postgres/env ] || [ -e ./legacy/cfg/auth.json ] || [ -e ./mojo/cfg/nethackstats.json ]; then 
	echo "Not a clean directory tree! run git clean -fx and try again."
    exit 1
fi

echo "Initialise Postgres config..."
./postgres/init.sh -f $feeder_pw -s $stats_pw -d $database_pw

echo "Start postgres container..."
docker-compose up $dc_args -d database

echo "Initialise feeder config..."
./legacy/init.sh

if [ "$selinux" == "y" ]; then
    echo "Attempt to fix SELinux flags..."
	sudo chcon -Rt svirt_sandbox_file_t legacy
	sudo chcon -Rt svirt_sandbox_file_t mojo
fi

echo "Build base images..."
docker-compose build base
docker-compose build libs-legacy
docker-compose build libs-mojo

echo "Start feeder container..."
docker-compose up $dc_args feeder

echo "Initialise mojo-web config..."
./mojo/init.sh

echo "Start mojo-web container"
docker-compose up $dc_args mojo-web
