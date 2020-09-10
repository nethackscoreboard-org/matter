FROM alpine:latest as feeder-skel
COPY ./binary-deps /tmp
RUN apk add `cat /tmp/binary-deps`

FROM alpine:latest as cpan-env
RUN apk update \
    && apk add ca-certificates wget \
    && update-ca-certificates
RUN apk add curl \
    build-base \
    make \
    perl-dev \
    perl-app-cpanminus \
    postgresql-dev

FROM cpan-env:testing as cpan-feeder
COPY ./cpanfile /tmp
RUN cpanm -l /cpan --installdeps /tmp --notest

# feeder-skel is our base OS image
FROM feeder-skel:testing as nhdb-feeder

# define buildtime-args
ARG rundir=/run/nhs
ARG xlogdir=/var/log/xlog
ARG PERL5LIB=/cpan/lib/perl5

# first copy cpan mods from cpan-builder image
# there they were staged
# then copy program scripts and initial data
# finally copy host aliases
COPY --from=cpan-feeder:testing /cpan /cpan
COPY ./run $RUNDIR
COPY 

# define runtime environment
ENV PERL5LIB=$PERL5LIB
WORKDIR $rundir
VOLUME $xlogdir 
ENTRYPOINT ["./nhdb-feeder.pl"]
CMD ["--server=hdf,hfa,hfe"]
