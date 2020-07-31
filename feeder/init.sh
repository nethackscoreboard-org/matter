#!/usr/bin/env bash
export `cat env`
#export DATABASE_HOST=`$DOCKER inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' nhs-db`
cp ./cfg/nhdb_def.json.example ./cfg/nhdb_def.json
if [ -n "DATABASE_HOST" ]; then
    sed -i "s/localhost/$DATABASE_HOST/g" ./cfg/nhdb_def.json
fi

cat <<- EOF >./cfg/auth.json
  { 
    "$FEEDER":"$FEEDER_PW",
    "$STATS":"$STATS_PW" 
  }
EOF
