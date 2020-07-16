#!/bin/sh

cat <<- EOF > cfg/auth.json
  { 
    "$FEEDER":"$FEEDER_PW",
    "$STATS":"$STATS_PW" 
  }
EOF

cat <<- EOF > cfg/nhdb_def.json
{
  "http_root" : "/var/www/html",
  "db" : {
  	"nhdbfeeder" : {
	    "dbname" : "$DATABASE_NAME",
	    "dbuser" : "$FEEDER",
      "dbhost": "database"
    },
  	"nhdbstats" : {
	    "dbname" : "$DATABASE_NAME",
	    "dbuser" : "$STATS",
      "dbhost": "database"
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
    "dnh", "nhf", "dyn"
  ]
}
EOF