#!/usr/bin/env sh
# this should not be something done regularly during development
# however, I want to test that the build system reliably produces
# something out of the box given a fresh git repo and no docker
# images/containers
docker rm -f `docker container ls -aq`
docker image rm `docker image ls -aq`
docker volume rm `docker volume ls -q`
