#!/usr/bin/env bash
export `cat my-env`
#export DATABASE_HOST=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' nhs-db`
cp ./cfg/nhdb_def.json.example ./cfg/nhdb_def.json
cp ../feeder/cfg/auth.json ./cfg/

cat <<- EOF >./mojo/cfg/nethackstats.json
{
    "dbuser" : "$STATS",
    "dbname" : "$DATABASE_NAME",
    "dbhost" : "$DATABASE_HOST",
    "dbpass" : "$STATS_PW",
    "dbport" : "$DATABASE_PORT"
}
EOF
