#!/usr/bin/env sh
# after envsubst this should go to pods/postgres/init.d/
set -e
feed_pass=`cat /run/secrets/nhdb/nhdbfeeder`
stats_pass=`cat /run/secrets/nhdb/nhdbstats`
postgres="psql -U ${POSTGRES_USER:-}"
${postgres:-} <<-EOSQL
  CREATE ROLE nhdbfeeder WITH PASSWORD '${feed_pass:-}' LOGIN;
EOSQL
${postgres:-} <<-EOSQL
  CREATE ROLE nhdbstats WITH PASSWORD '${stats_pass:-}' LOGIN;
EOSQL
${postgres:-} <<-EOSQL
  GRANT ALL ON DATABASE ${postgres_db:-} TO nhdbfeeder;
  GRANT CONNECT,SELECT ON ${postgres_db:-} TO nhdbstats;
EOSQL
