#!/usr/bin/env sh

if [ -e /init/database.env ]; then
    export `cat /init/database.env`
fi

mkdir /nhs/cfg

cat <<- EOF > /nhs/cfg/auth.json
  { 
    "$FEEDER":"$FEEDER_PW",
    "$STATS":"$STATS_PW" 
  }
EOF

cat <<- EOF > /nhs/cfg/nhdb_def.json
{
  "http_root" : "/nhs/public",
  "db" : {
  	"nhdbfeeder" : {
	    "dbname" : "$DATABASE_NAME",
	    "dbuser" : "$FEEDER",
      "dbhost": "database",
      "dbport": "$DATABASE_PORT"
    },
  	"nhdbstats" : {
	    "dbname" : "$DATABASE_NAME",
	    "dbuser" : "$STATS",
      "dbhost": "database",
      "dbport": "$DATABASE_PORT"
    }
  },
  "auth" : "auth.json",
  "wget" : "wget --connect-timeout=10 --dns-timeout=5 --read-timeout=60 -t 1 -c -q -O %s %s",
  "feeder" : {
    "require_fields" : [ "conduct", "starttime", "endtime" ],
    "regular_fields" : [
      "role", "race", "gender", "gender0", "align", "align0", "deathdnum", "deathlev", "deaths", "hp", "maxhp",
      "maxlvl", "points", "turns", "realtime", "version", "dumplog", "elbereths"
    ],
    "reject_name" : [ "wizard", "paxedtest" ]
  },
  "logs" : {
    "localpath" : "logs",
    "urlpath" : null
  },  
  "firsttoascend" : [
    "gh", "dnh", "nhf", "dyn", "fh", "sh", "nh4", "unh", "xnh", "eh"
  ],
}
EOF

cat <<- EOF > /nhs/cfg/nethackstats.json
{
    "dbuser" : "$STATS",
    "dbname" : "$DATABASE_NAME",
    "dbhost" : "database",
    "dbpass" : "$STATS_PW",
    "dbport" : "$DATABASE_PORT"
}
EOF
