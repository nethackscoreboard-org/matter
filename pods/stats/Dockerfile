FROM feeder-skel:latest as small
COPY --from=cpan-feeder /cpan-mods /cpan-mods
WORKDIR /run/nhs
CMD ./nhdb-stats.pl
