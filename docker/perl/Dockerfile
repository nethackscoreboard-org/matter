FROM alpine:latest as base-system
RUN apk update && apk add ca-certificates wget && update-ca-certificates
RUN apk add curl
RUN apk add build-base
RUN apk add make
RUN apk add perl-dev
RUN apk add perl-app-cpanminus
RUN apk add postgresql-dev
RUN apk add openssh-client
RUN apk add git

FROM base-system as init-cpan-env
RUN mkdir /init
COPY ./docker/perl/* /init/
COPY ./cpanfile /init/
RUN cpanm --installdeps /init/ --notest

FROM init-cpan-env as git-setup
RUN /init/git_setup.sh
RUN git clone docker-host:nhs-fork /nhs
WORKDIR /nhs

FROM git-setup as config-stage
COPY ./docker/environment/database.env /init/
RUN ./docker/perl/create_config.sh
RUN cp /init/feeder_cron.sh /etc/periodic/15min/ && rm -rf /init


ENTRYPOINT ["./docker/perl/entrypoint.sh"]
