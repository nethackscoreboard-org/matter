FROM alpine:latest
RUN apk update && apk add ca-certificates wget && update-ca-certificates
RUN apk add curl
RUN apk add build-base
RUN apk add make
RUN apk add perl-dev
RUN apk add perl-app-cpanminus
RUN apk add postgresql-dev
RUN mkdir nhs

WORKDIR /nhs
COPY ./cpanfile .
COPY ./lib ./lib
COPY ./templates ./templates
RUN touch ./templates/about_news.tt
COPY ./logs ./logs
COPY ./cfg ./cfg
COPY ./css ./css
COPY nhdb-feeder.pl .
COPY nhdb-stats.pl .
RUN cpanm --installdeps . --notest

COPY ./docker/perl/create_config.sh .
RUN chmod a+x create_config.sh
COPY ./docker/perl/entrypoint.sh .
RUN chmod a+x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
