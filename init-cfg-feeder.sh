#!/usr/bin/env bash
for i in `cat ./postgres/env`; do
    export $i;
done

export DATABASE_HOST=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' nhs-db`
cp ./legacy/cfg/nhdb_def.json.example ./legacy/cfg/nhdb_def.json
sed -i "s/localhost/$DATABASE_HOST/g" ./legacy/cfg/nhdb_def.json

cat <<- EOF >./legacy/cfg/auth.json
  { 
    "$FEEDER":"$FEEDER_PW",
    "$STATS":"$STATS_PW" 
  }
EOF
