FROM postgres:12.2-alpine

ARG PGDATA
COPY --chown=postgres:postgres ./init/* /docker-entrypoint-initdb.d/
RUN rm -rf $PGDATA/*
