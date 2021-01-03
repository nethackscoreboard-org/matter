#!/usr/bin/env perl

#=============================================================================
# Utility functions.
#=============================================================================

package NHdb::Utils;

require Exporter;
use URI::Escape;
use DBI;
use POSIX qw(strftime);

use integer;
use strict;


#=== module exports ========================================================

our @ISA = qw(Exporter);
our @EXPORT = qw(
  format_duration
  url_substitute
  sql_show_query
  referentize
  nhdb_version
);


#===========================================================================
# Unix epoch time formatting function.
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
# %s - start time (unix epoch)
# %e - end time (unix epoch)
# %E - end time (as YYYYMMDDHHMMSS)
# %x - username before translation (as it appears in xlogfile)
# %v - version number
# %V - version number stripped of dots (ie 3.6.3 becomes 363)
# %d - dumpfile (content of the 'dumpfile' xlogfile field)
# %D - dumpfile processed for NH4 (_ replaced with :)
# %S - contents of the src field (workaround for TNNT, FIXME: this needs
#      a better solution - format is either hdf-us, hdf-eu or hdf-au
#===============================================================================

sub url_substitute
{
  my $strg = shift;
  my $data = shift;

  my $r_username = $data->{'name'};
  my $r_uinitial = substr($data->{'name'}, 0, 1);
  my $r_starttime = $data->{'starttime_raw'};
  my $r_endtime = $data->{'endtime_raw'};
  my $r_username_orig = $data->{'name_orig'};
  my $r_uinitial_orig = $r_username_orig;
  $r_uinitial_orig =~ s/^(\w).*$/$1/;
  my $r_version = $data->{'version'};
  my $r_version_dotless = $data->{'version'} =~ s/\.//gr;
  my $r_dumpfile = uri_escape($data->{'dumplog'});
  
  # this needs additional processing, as src is hdf-eu, hdf-us or hdf-au
  my $r_src = $data->{'src'} // '';
  if ($r_src =~ /^hdf-us$/) {
    $r_src = 'www';
  } else {
    $r_src =~ s/^hdf-(\w+)$/$1/;
  }

  my @et = gmtime($data->{'endtime_raw'});
  my $r_endtime2 = sprintf(
    '%04d%02d%02d%02d%02d%02d',
    $et[5]+1900, $et[4]+1, $et[3], $et[2], $et[1], $et[0]
  );

  # NetHack4 dumplogs work differently than the rest of the variants,
  # this is what ais523 has to say about it (note, that "three underscores"
  # is a mistake, there are only two):
  #
  # The dumplog filename is listed in the xlogfile, in the "dumplog"
  # field. Replace the first three underscores with colons, all spaces
  # with %20, and prepend http://nethack4.org/dumps/ to produce a filename
  # you can link to.

  my $r_dumpfile_nh4 = $data->{'dumplog'};
  $r_dumpfile_nh4 =~ s/(\d{2})_(\d{2})_(\d{2})/$1:$2:$3/;
  $r_dumpfile_nh4 = uri_escape($r_dumpfile_nh4);

  # perform the token replacement

  $strg =~ s/%u/$r_username/g;
  $strg =~ s/%U/$r_uinitial/g;
  $strg =~ s/%s/$r_starttime/g;
  $strg =~ s/%e/$r_endtime/g;
  $strg =~ s/%E/$r_endtime2/g;
  $strg =~ s/%x/$r_username_orig/g;
  $strg =~ s/%X/$r_uinitial_orig/g;
  $strg =~ s/%v/$r_version/g;
  $strg =~ s/%V/$r_version_dotless/g;
  $strg =~ s/%d/$r_dumpfile/g;
  $strg =~ s/%D/$r_dumpfile_nh4/g;
  $strg =~ s/%S/$r_src/g;

  return $strg;
}


#===============================================================================
# Receives SQL query with ? placeholders and an array values and replaces
# the placeholders with the values and returns the result. This is used to
# pretty display the queries for debug purposes.
#===============================================================================

sub sql_show_query
{
  my ($qry, $vals) = @_;

  for(my $i = 0; $i < scalar(@$vals); $i++) {
    my $val = $vals->[$i];
    $val = "'$val'" if $val !~ /^\d+$/;
    $qry =~ s/\?/$val/;
  }

  return $qry;
}


#===============================================================================
# Get an array of values and turn them into arrayrefs if they already aren't.
# undefs will turn into arrayrefs to empty arrays, scalars will turn into
# arrayrefs to one-element arrays.
#===============================================================================

sub referentize
{
  return map {
    ref($_) ? $_ : ($_ ? [ $_ ] : []);
  } @_;
}


#===============================================================================
# Version string mangling (cutting off the prefix, so "UNH-5.2" becomes "5.2"
# etc.).
#===============================================================================

sub nhdb_version
{
  my $ver = shift;

  $ver =~ s/^.*-//;
  return $ver
}


#===============================================================================

1;
