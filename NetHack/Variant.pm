#!/usr/bin/env perl

#===========================================================================
# This class is an interface for NetHack::Config that implements
# variant-specific queries.
#===========================================================================

package NetHack::Variant;
use NetHack::Config;

use Moo;

has variant => (
  is => 'ro',
  required => 1,
);

has config => (
  is => 'ro',
);


1;
