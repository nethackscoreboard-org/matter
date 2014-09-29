#!/usr/bin/perl

#===========================================================================
# NetHack database project library
#===========================================================================

package NHdb;
require Exporter;
use NetHack;
use JSON;
use POSIX qw(strftime);
use integer;
use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw(
  format_duration
  url_substitute
);


#=== this holds all defs

our $nhdb_def;


#===========================================================================
#=== BEGIN SECTION =========================================================
#===========================================================================

BEGIN
{
  local $/;
  my $fh;
  open($fh, '<', 'cfg/nhdb_def.json') or die;
  my $def_json = <$fh>;
  $nhdb_def = decode_json($def_json);
}


#===========================================================================
#===========================================================================

sub format_duration
{
  my $realtime = shift;
  my ($d, $h, $m, $s) = (0,0,0,0);
  my $duration;
  
  $d = $realtime / 86400;
  $realtime %= 86400;
  
  $h = $realtime / 3600;
  $realtime %= 3600;
  
  $m = $realtime / 60;
  $realtime %= 60;
  
  $s = $realtime;
  
  $duration = sprintf("%s:%02s:%02s", $h, $m, $s);
  if($d) {
    $duration = sprintf("%s, %s:%02s:%02s", $d, $h, $m, $s);
  }

  return $duration;  
}


#===============================================================================
# Function to perform substitutions on an URL (or any string). The supported
# substitutions are:
#
# %u - username
# %U - first letter of username
# %s - start time
#===============================================================================

sub url_substitute
{
  my $strg = shift;
  my $data = shift;

  my $r_username = $data->{'name'};
  my $r_uinitial = substr($data->{'name'}, 0, 1);
  my $r_starttime = $data->{'starttime_raw'};
  my $r_endtime = $data->{'endtime_raw'};

  $strg =~ s/%u/$r_username/g;
  $strg =~ s/%U/$r_uinitial/g;
  $strg =~ s/%s/$r_starttime/g;
  $strg =~ s/%e/$r_endtime/g;

  return $strg;
}


1;

