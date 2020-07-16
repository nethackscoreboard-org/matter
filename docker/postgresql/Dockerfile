FROM postgres:12.2-alpine

COPY ./docker/postgresql/initialize_users /docker-entrypoint-initdb.d/1_initialize_users.sh
RUN chmod a+x /docker-entrypoint-initdb.d/1_initialize_users.sh

COPY ./schema/translations.sql  /docker-entrypoint-initdb.d/2_translations.sql
COPY ./schema/update.sql        /docker-entrypoint-initdb.d/3_update.sql
COPY ./schema/logfiles.sql      /docker-entrypoint-initdb.d/4_logfiles.sql
COPY ./schema/sources.sql       /docker-entrypoint-initdb.d/5_sources.sql
COPY ./schema/games.sql         /docker-entrypoint-initdb.d/6_games.sql
COPY ./schema/source_view.sql   /docker-entrypoint-initdb.d/7_source_view.sql
COPY ./schema/streaks.sql       /docker-entrypoint-initdb.d/8_streaks.sql