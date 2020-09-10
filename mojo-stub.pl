#!/usr/bin/env perl
# this file becomes $RUNDIR/script/nhs on installation,
# or container build - per Mojo's requirements

use strict;
use warnings;

use Mojo::File qw(curfile);
use lib
curfile->dirname->sibling('lib')->to_string;
use Mojolicious::Commands;
use Log::Log4perl;
Log::Log4perl::init('./cfg/mojo-log.conf');
Mojolicious::Commands->start_app('NHS')
