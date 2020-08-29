FROM alpine:latest
RUN apk update \
    && apk add ca-certificates wget \
    && update-ca-certificates
RUN apk add curl \
    build-base \
    make \
    perl-dev \
    perl-app-cpanminus \
    postgresql-dev
