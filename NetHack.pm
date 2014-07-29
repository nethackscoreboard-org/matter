#!/usr/bin/perl

#===========================================================================
# This module contains NetHack related function.
#===========================================================================

package NetHack;
require Exporter;
use integer;
use strict;
use JSON;


our @ISA = qw(Exporter);
our @EXPORT = qw(
	nh_conduct
);


#=== this holds all defs

our $nh_def;


#===========================================================================
#=== BEGIN SECTION =========================================================
#===========================================================================

BEGIN
{
  local $/;
  my $fh;
  open($fh, '<', 'nethack_def.json');
  my $def_json = <$fh>;
  $nh_def = decode_json($def_json);
}


#===========================================================================
#=== FUNCTIONS =============================================================
#===========================================================================


#===========================================================================
# This function takes conduct bitmap and returns either number of conducts
# or list of conduct abbreviations, depending on context
#===========================================================================

sub nh_conduct
{
	my $conduct_bitfield = shift;
  my @conducts;

	#--- get ordered list of conducts

	for my $c (@{$nh_def->{'nh_conduct_bitmap_ord'}}) {
		if($conduct_bitfield & $c) {
      push(@conducts, $nh_def->{'nh_conduct_bitmap_def'}{$c});
		}
	}

  #--- return depending on context

  return wantarray ? @conducts : scalar(@conducts);
}


1;
