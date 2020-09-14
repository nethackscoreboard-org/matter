#!/usr/bin/env sh
# after envsubst this should go to pods/postgres/init.d/
set -e
feed_pass=`cat /run/secrets/$FEEDER_DBUSER`
stats_pass=`cat /run/secrets/$STATS_DBUSER`
postgres="psql -U $POSTGRES_USER"
$postgres <<-EOSQL
  CREATE ROLE $FEEDER_DBUSER WITH PASSWORD '$feed_pass' LOGIN;
EOSQL
$postgres <<-EOSQL
  CREATE ROLE $STATS_DBUSER WITH PASSWORD '$stats_pass' LOGIN;
EOSQL
$postgres <<-EOSQL
  GRANT ALL ON DATABASE $POSTGRES_DB TO $FEEDER_DBUSER;
  GRANT CONNECT,SELECT ON $POSTGRES_DB TO $STATS_DBUSER;
EOSQL
