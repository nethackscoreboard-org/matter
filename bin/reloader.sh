#!/usr/bin/env bash
helpFunction()
{
    echo ""
    echo "Usage: $0 [ -CIRSbr ]"
    echo -e "\t-C Run git clean -fx to clear .env and old config files containing db pass info etc."
    echo -e "\t-I Rebuild all images."
    echo -e "\t-R Refresh persistent volumes. Necessary if db passwords change."
    echo -e "\t-S Fix SELinux tags on legacy/ and mojo/ bind-mounts (need sudo)."
    echo -e "\t-b Rebuild image on docker-compose up commands."
	echo -e "\t-r Refresh config files. This is default if the relevant files aren't found anyway."
    exit 1
}

while getopts "CIRSbd:f:rs:" opt
do
    case $opt in
		C ) gitclean="y" ;;		    # skip git clean - some may want this default
        I ) reload_img="y" ;;       # rebuild all docker images for project
        R ) refresh_vol="y" ;;      # refresh volumes for postgres etc.
		S ) selinux="y" ;; 		    # fix SELinux tags for bind mounts - sudo req.
		b ) build="y" ;;	        # force the build step on docker-compose up
        d ) database_pw="$OPTARG" ;;# set database password
        f ) feeder_pw="$OPTARG" ;;  # set feeder password
		r ) refresh_cfg="y" ;;	    # renew config files - running init scripts
								    # is anyway default if the configs are missing
        s ) stats_pw="$OPTARG" ;;   # set stats password
        ? ) helpFunction ;;
    esac
done

# set cli args for docker-compose based on init.sh flags
if [ "$build" == "y" ]; then
	dc_args="--build"
fi
if [ "$refresh_vol" == "y" ]; then
	dc_args="$dc_args -V"
fi

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

# dunno if this is really needed, user can always call it themself
if [ "$gitclean" == "y" ]; then
	git clean -fx
fi

# remove running web or feeder containers, if extant
containers=`docker container ls -a --format='{{json .Names}}' | sed s/\"//g | grep -E 'nhs-web-m|nhdb-feeder'`
if [ ! -z "$containers" ]; then
    echo "stopping containers $containers"
	docker rm -f $containers
fi

# if postgres is running and neither refresh_cfg or refresh_vol are set
# we can safely do nothing here, otherwise, kill nhs-db if it's running
# and start a new one
docker container ls | grep nhs-db >/dev/null
postgres_return=$?
if [ $postgres_return -eq 0 ] && [ "$refresh_cfg" != "y" ] && [ "$refresh_vol" != "y" ] && [ "$reload_img" != "y" ]; then 
    if [ -e ./postgres/env ]; then
	    echo "Skipping postgres restart, nhs-db still running."
    else
        # Postgres env file went missing, but otherwise it's running
        # and we don't want to refresh any config unnecessarily or
        # delete persistent volumes, attempt to fix config/passwords
        echo "Renew missing config without restarting postgres..."
        ./postgres/reset-pw.sh -f $feeder_pw -s $stats_pw -d $database_pw
        refresh_cfg="y"
    fi
else
	# postgres container still running - need to kill
	if [ $postgres_return -eq 0 ]; then
        echo "Stopping postgres container..."
		docker rm -f nhs-db
	fi
	if ! [ -e ./postgres/env ] || [ "$refresh_cfg" == "y" ]; then
        echo "Initialising Postgres config..."
		./postgres/init.sh -f $feeder_pw -s $stats_pw -d $database_pw
	fi

    echo "Removing db persistent volume..."
    docker volume rm -f nhs-fork_db_vol

    # reload images essentially implies we're going to remove persistent volumes
    if [ "$refresh_vol" == "y" ] || [ "$reload_img" == "y" ]; then
        echo "Removing xlog persistent volume..."
        docker volume rm -f nhs-fork_xlogs_vol
    fi

    # Remove images if -I flag set
    if [ "$reload_img" == "y" ]; then
        echo "Removing all docker images..."
        docker image rm -f nhs-fork_{mojo-web,database,feeder} cpan-{mojo,moo} perl-base
    fi

    echo "Starting postgres container..."
	docker-compose up $dc_args -d database

	# if we had to start a new database container, IP could change,
	# so config for other containers has to be refreshed anyway
    # passwords may have also changed
	refresh_cfg="y"

    # Sleep for a bit or postgres won't be ready for feeder
    sleep 30
fi

# update config for legacy feeder, should not actually mean full
# rebuild of images/containers is necessary, since config comes
# in through a bind mount
if [ ! -e ./legacy/cfg/auth.json ] || [ "$refresh_cfg" == "y" ]; then
    echo "Initialising feeder config..."
	./legacy/init.sh
fi

if [ "$selinux" == "y" ]; then
    echo "Attempting to fix SELinux flags"
	sudo chcon -Rt svirt_sandbox_file_t legacy
	sudo chcon -Rt svirt_sandbox_file_t mojo
fi

# check if we have the perl-base repository, build it otherwise
docker image ls | grep perl-base >/dev/null
if [ $? -ne 0 ]; then
    docker-compose build base
fi
# same for the cpan modules
docker image ls | grep cpan-moo >/dev/null
if [ $? -ne 0 ]; then
    docker-compose build libs-legacy
fi

# run the database feeder, attached, and wait for reading of
# some xlogs
echo "Start feeder container..."
docker-compose up $dc_args feeder

# update config for legacy feeder, should not actually mean full
# rebuild of images/containers is necessary, since config comes
# in through a bind mount
if [ ! -e ./mojo/cfg/nethackstats.json ] || [ "$refresh_cfg" == "y" ]; then
    echo "Initialise mojo-web config..."
	./mojo/init.sh
fi

# check for the cpan-mojo image
docker image ls | grep cpan-mojo >/dev/null
if [ $? -ne 0 ]; then
    docker-compose build libs-mojo
fi

echo "Start mojo-web container"
docker-compose up $dc_args mojo-web
