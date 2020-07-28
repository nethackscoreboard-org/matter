FROM cpan-moo:latest as install-cpan-mojo
COPY ./script/cpanfile /tmp
RUN cpanm --installdeps /tmp --notest

FROM cpan-mojo:latest as run-mojo
RUN mkdir -p /run/nhs
WORKDIR /run/nhs
CMD morbo --listen http://*:8082 script/nhs
