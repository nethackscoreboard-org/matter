# Precursor target
FROM cpan-feeder:testing as cpan-mojo
COPY ./cpanfile /tmp
RUN cpanm -l /cpan --installdeps /tmp --notest

# Main target starts from here
# feeder-skel works as our base system of binary
# pkgs - tho ideally we should make it more stripped
FROM feeder-skel:testing as nhdb-mojo

# define buildtime-args
# lowercase= buildtime only, uppercase= intended as runtime ENV var
ARG rundir=/run/nhs
ARG PERL5LIB=/cpan/lib/perl5
ARG PATH=/usr/local/bin:/usr/bin:/bin
ARG my_path=/cpan/bin

# copy the deps first
COPY --from=cpan-mojo:testing /cpan /cpan
RUN mkdir -pv $rundir
COPY ./run/ $rundir/

# then define runtime environment
ENV PERL5LIB=$PERL5LIB PATH=$my_path:$PATH
WORKDIR $rundir
EXPOSE 8080/tcp
ENTRYPOINT ["hypnotoad"]
CMD ["script/nhs"]
