FROM alpine:latest as install-bin-deps
COPY ./binary-deps /tmp/
RUN apk add `cat /tmp/binary-deps`

FROM feeder-cpan-mods:latest as build-cpan-deps
COPY ./script/cpanfile /tmp/
RUN cpanm -l /cpan-mods --installdeps /tmp --notest

FROM mojo-bin-libs:latest as build-small
COPY --from=mojo-cpan-mods /cpan-mods /cpan-mods
WORKDIR /run/nhs
CMD morbo --listen http://*:8085 script/nhs
