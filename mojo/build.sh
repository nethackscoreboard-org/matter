#!/usr/bin/env bash
$DOCKER build -t mojo-bin-libs --target install-bin-deps .
$DOCKER build -t mojo-cpan-mods --target build-cpan-deps .
$DOCKER build -t mojo-img --target build-small .
