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

if [ -z "$optionF" ] || [ -z "$optionS" ] || [ -z "$optionD" ]; then
	echo "Please choose three passwords."
    helpFunction
fi

FEEDER_PW=$optionF
STATS_PW=$optionS
DATABASE_PW=$optionD
POSTGRES_PASSWORD=$DATABASE_PW
        
for i in `cat ./postgres/default-env`; do
    export $i;
done

cp ./postgres/default-env ./postgres/env

# need this for docker-compose
echo PGDATA=$PGDATA >.env

cat <<- EOF >>./postgres/env
FEEDER_PW=$optionF
STATS_PW=$optionS
DATABASE_PW=$optionD
POSTGRES_PASSWORD=$optionD
EOF
