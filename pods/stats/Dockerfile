ARG LABEL=main
FROM feeder-skel:$LABEL
COPY --from=cpan-feeder /cpan-mods /cpan-mods
ARG RUN=run
WORKDIR $RUN
CMD ./nhdb-stats.pl
