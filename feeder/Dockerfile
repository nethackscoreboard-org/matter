FROM alpine:latest as install-bin-deps
COPY ./binary-deps /tmp/
RUN apk add `cat /tmp/binary-deps`

FROM cpan-env:latest as build-cpan-deps
COPY ./cpanfile /tmp
RUN cpanm -l /cpan-mods --installdeps /tmp --notest

FROM feeder-bin-libs:latest as build-small
COPY --from=feeder-cpan-mods /cpan-mods /cpan-mods
WORKDIR /run/nhs
CMD ./nhdb-feeder.pl --server=hdf,hfa,hfe
