FROM perl-base:latest as install-cpan-legacy
COPY ./cpanfile /tmp
RUN cpanm --installdeps /tmp --notest

FROM cpan-moo:latest as run-feeder
RUN mkdir -p /run/nhs
WORKDIR /run/nhs
CMD ./nhdb-feeder.pl --server=hdf,hfa,hfe
