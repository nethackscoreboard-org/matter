FROM alpine:latest as skel
COPY ./binary-deps /tmp
RUN apk add `cat /tmp/binary-deps`

ARG LABEL=main
FROM cpan-env:$LABEL as cpan-deps
COPY ./cpanfile /tmp
RUN cpanm -l /cpan-mods --installdeps /tmp --notest

ARG LABEL=main
FROM feeder-skel:$LABEL as small
COPY --from=cpan-feeder /cpan-mods /cpan-mods
ARG RUN=run
WORKDIR $RUN
CMD ./nhdb-feeder.pl
