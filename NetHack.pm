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
# or list of conduct abbreviations, depending on context. The list of
# conduct abbreviations is ordered according to ordering in
# "nh_conduct_ord".
#===========================================================================

sub nh_conduct
{
	my $conduct_bitfield = shift;    # 1. conduct field from xlogfile
  my $variant          = shift;    # 2. variant code
  my @conducts;

  #--- choose mapping to be used

  my $bitmap_def = $nh_def->{'nh_conduct_bitmap_def'};
  if(exists($nh_def->{nh_variants}{$variant}{conduct})) {
    $bitmap_def = $nh_def->{nh_variants}{$variant}{conduct};
  }

  #--- get reverse code-to-value mapping for conducts

  my %con_to_val;
  for my $v (keys %$bitmap_def) {
    $con_to_val{$bitmap_def->{$v}} = $v;
  }

	#--- get ordered list of conducts

	for my $c (@{$nh_def->{'nh_conduct_ord'}}) {
    my $v = $con_to_val{$c};
		if($conduct_bitfield & $v) {
      push(@conducts, $c);
		}
	}

  #--- return depending on context

  return wantarray ? @conducts : scalar(@conducts);
}


1;
