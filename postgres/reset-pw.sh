#!/usr/bin/env bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -f feeder-pw -s stats-pw -d postgres-pw"
   echo -e "\t-f Feeder password is required by postgres and the legacy feeder/aggregator script."
   echo -e "\t-s The web front-end uses the stats user, requires this password."
   echo -e "\t-d Database password. Absolutely necessary that this is defined or postgres container won't start."
   echo -e "Yes I know this is not the most secure way of doing things."
   exit 1 # Exit script after printing help
}

while getopts "f:s:d:" opt
do
    case $opt in
        f ) optionF="$OPTARG" ;;
        s ) optionS="$OPTARG" ;;
        d ) optionD="$OPTARG" ;;
        ? ) helpFunction ;;
    esac
done

POSTGRES="psql -U $POSTGRES_USER"
if [ -e ./postgres/env ]; then
    # in the first case we just update a subset
    # of the passwords and not necessarily all
    for i in `cat ./postgres/env`; do
        export $i;
    done
    if [ -n "$optionF" ]; then
        export FEEDER_PW=$optionF
        docker exec -it nhs-db $POSTGRES <<- EOF
ALTER ROLE $FEEDER WITH PASSWORD '$FEEDER_PW';
EOF
    fi
    if [ -n "$optionS" ]; then
        export STATS_PW=$optionS
        docker exec -it nhs-db $POSTGRES <<- EOF
ALTER ROLE $STATS WITH PASSWORD '$STATS_PW';
EOF
    fi
    if [ -n "$optionD" ]; then
        export DATABASE_PW=$optionD
        export POSTGRES_PASSWORD=$optionD
        docker exec -it nhs-db $POSTGRES <<- EOF
ALTER ROLE $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';
EOF
    fi
else
    # in the case where ./postgres/env is not
    # there, non-supplied passwords fall back
    # to their defaults
    for i in `cat ./postgres/default-env`; do
        export $i;
    done
    if [ -n "$optionF" ]; then
        export FEEDER_PW=$optionF
    else
        export FEEDER_PW=feeder
    fi
    if [ -n "$optionS" ]; then
        export STATS_PW=$optionS
    else
        export STATS_PW=stats
    fi
    if [ -n "$optionD" ]; then
        export DATABASE_PW=$optionD
    else
        export DATABASE_PW=data
    fi
    export POSTGRES_PASSWORD=$DATABASE_PW
    docker exec -it nhs-db $POSTGRES <<- EOF
ALTER ROLE $FEEDER WITH PASSWORD '$FEEDER_PW';
ALTER ROLE $STATS WITH PASSWORD '$STATS_PW';
ALTER ROLE $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';
EOF
fi


# need this for docker-compose,
# fix if it's gone missing
if [ ! -e .env ]; then
    echo PGDATA=$PGDATA >.env
fi

cp ./postgres/default-env ./postgres/env
cat <<- EOF >>./postgres/env
FEEDER_PW=$FEEDER_PW
STATS_PW=$STATS_PW
DATABASE_PW=$DATABASE_PW
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
EOF

# after this we call a script to tell postgres the new passwords

