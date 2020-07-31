#!/usr/bin/env bash
$DOCKER build -t feeder-bin-libs --target install-bin-deps .
$DOCKER build -t feeder-cpan-mods --target build-cpan-deps .
$DOCKER build -t feeder-img --target build-small .
