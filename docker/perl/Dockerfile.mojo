FROM nhs-fork_cpan:latest
WORKDIR /nhs
RUN mkdir -p /init
COPY ./docker/perl/* ./docker/environment/database.env ./nhdb-feeder.pl /init/
RUN /init/create_config.sh
COPY ./cfg/logging.conf ./cfg/nethack_def.json ./cfg/
ENTRYPOINT ["/init/entrypoint.sh"]
