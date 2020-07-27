FROM postgres:12.2-alpine

COPY ./docker/postgresql/*.sh /docker-entrypoint-initdb.d/
COPY ./schema/*.sql /docker-entrypoint-initdb.d/
RUN chown postgres:postgres -R /docker-entrypoint-initdb.d/*
RUN rm -rf /var/lib/postgres/data/*
