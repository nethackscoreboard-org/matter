FROM postgres:alpine

COPY --chown=postgres:postgres ./init/* /docker-entrypoint-initdb.d/
