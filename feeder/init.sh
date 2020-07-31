#!/usr/bin/env bash
export `cat my-env`
cp ./cfg/nhdb_def.json.example ./cfg/nhdb_def.json
if [ "$DOCKER" == "docker" ]; then
    export DATABASE_HOST=`$DOCKER inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' nhs-db`
    if [ -n "DATABASE_HOST" ]; then
        sed -i "s/localhost/$DATABASE_HOST/g" ./cfg/nhdb_def.json
    fi
else
    export DATABASE_HOST='localhost'
fi
echo DATABASE_HOST=$DATABASE_HOST >>my-env
cat <<- EOF >./cfg/auth.json
  { 
    "$FEEDER":"$FEEDER_PW",
    "$STATS":"$STATS_PW" 
  }
EOF
