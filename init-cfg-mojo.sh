#!/usr/bin/env bash

for i in `cat ./postgres/env`; do
    export $i;
done

export DATABASE_HOST=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' nhs-db`

cp ./mojo/cfg/nhdb_def.json.example ./mojo/cfg/nhdb_def.json

cat <<- EOF >./mojo/cfg/nethackstats.json
{
    "dbuser" : "$STATS",
    "dbname" : "$DATABASE_NAME",
    "dbhost" : "$DATABASE_HOST",
    "dbpass" : "$STATS_PW",
    "dbport" : "$DATABASE_PORT"
}
EOF
