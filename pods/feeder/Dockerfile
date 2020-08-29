FROM alpine:latest as skel
COPY ./binary-deps /tmp
RUN apk add `cat /tmp/binary-deps`

FROM cpan-env:latest as cpan-deps
COPY ./cpanfile /tmp
RUN cpanm -l /cpan-mods --installdeps /tmp --notest

FROM feeder-skel:latest as small
COPY --from=cpan-feeder /cpan-mods /cpan-mods
WORKDIR /run/nhs
CMD ./nhdb-feeder.pl --server=hdf,hfa,hfe
