FROM postgres:alpine
COPY --chown=postgres:postgres ./init.d/* /docker-entrypoint-initdb.d/

# initialise buildtime default args
ARG POSTGRES_USER=nhdb
ARG POSTGRES_DB=nhdb
ARG POSTGRES_PASSWORD_FILE=/run/secrets/root
ARG FEEDER_DBUSER=nhdbfeeder
ARG STATS_DBUSER=nhdbstats
ARG PGDATA=/var/lib/postgresql/data/pgdata

# initialise container runtime env
ENV POSTGRES_USER=$POSTGRES_USER POSTGRES_DB=$POSTGRES_DB
ENV POSTGRES_PASSWORD_FILE=$POSTGRES_PASSWORD_FILE PGDATA=$PGDATA
ENV FEEDER_DBUSER=$FEEDER_DBUSER STATS_DBUSER=$STATS_DBUSER
VOLUME [ "$pgdata" ]
ENTRYPOINT ["postgres"]
CMD ["-c", "log_statement=none", "-c", "checkpoint_completion_target=0.9"]
