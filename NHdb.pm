#!/usr/bin/env perl

#===========================================================================
# NetHack database project library
#===========================================================================

package NHdb;
require Exporter;
use URI::Escape;
use Dir::Self;
use JSON;
use DBI;
use POSIX qw(strftime);
use integer;
use strict;


#=== module exports ========================================================

our @ISA = qw(Exporter);
our @EXPORT = qw(
  dbconn
  dbdone
  format_duration
  url_substitute
  logfile_require_fields
  sql_show_query
  cmd_option_array_expand
  cmd_option_state
  referentize
  nhdb_show_version
);


#=== module variables ======================================================

our $nhdb_def;     # this holds configuration info (from "nhdb_def.json")
my %dbconn;        # database connection paramters and handle(s)


#===========================================================================
#=== BEGIN SECTION =========================================================
#===========================================================================

BEGIN
{
  local $/;
  my $js = new JSON->relaxed(1);

  #--- read the main config file

  open(my $fh, '<', __DIR__ . '/cfg/nhdb_def.json') or die;
  my $def_json = <$fh>;
  close($fh);
  $nhdb_def = $js->decode($def_json);

  #--- read the file with db passwords (if defined)

  if(exists $nhdb_def->{'auth'}) {
    open($fh, '<', __DIR__ . '/cfg/' . $nhdb_def->{'auth'}) or die;
    $def_json = <$fh>;
    close($fh);
    $nhdb_def->{'auth'} = $js->decode($def_json);
  }
}


#===========================================================================
# Initialize database connection parameters.
#===========================================================================

sub dbinit
{
  my (
    $id,       # 1. connection id
    $dbname,   # 2. database name
    $dbuser,   # 3. user name
    $dbpass,   # 4. password
    $hostname  # 5. database host (optional)
  ) = @_;

  $dbconn{$id} = {
    'dbname' => $dbname,
    'dbuser' => $dbuser,
    'dbpass' => $dbpass,
    'dbhost' => $hostname,
    'conn'   => undef
  };
}


#===========================================================================
# Close database handle.
#===========================================================================

sub dbdone
{
  my ($id) = @_;
  my $dbh;
  
  $dbh = $dbconn{$id}{conn};
  if(!ref($dbh)) { return undef; }
  $dbh->disconnect;
  $dbconn{$id}{conn} = undef;
}


#===========================================================================
# This function returns database handle associated with given id. If the
# handle is not open, it opens it according to the parameters in the
# configuration (that is in %nhdb_def). If opening the handle fails, the
# error text is returned as scalar string value (ie. if the returned value
# is a ref, it's the db handle, if it is not a ref, it's an error).
#===========================================================================

sub dbconn
{
  my $id = shift;
  my $dbh;

  #--- if the handle is open, just return it

  if(exists $dbconn{$id} && $dbconn{$id}{'conn'}) {
    return $dbconn{$id}{'conn'};
  }

  #--- if the id doesn't exist, initialize it

  if(!exists $dbconn{$id}) {
    if(exists $nhdb_def->{'db'}{$id}) {
      my $db = $nhdb_def->{'db'}{$id};
      my $dbuser = $db->{'dbuser'};
      my $dbpass;

      if(exists $nhdb_def->{'auth'}) {
        $dbpass = $nhdb_def->{'auth'}{$dbuser};
      } else {
        $dbpass = $db->{'dbpass'};
      }

      dbinit(
        $id,
        $db->{'dbname'},
        $dbuser,
        $dbpass,
        exists $db->{'dbhost'} ? $db->{'dbhost'} : undef
      );
    } else {
      return "Database id '$id' not configured";
    }
  }

  #--- and try to open the handle

  my $src;
  $src = sprintf('dbi:Pg:dbname=%s', $dbconn{$id}{'dbname'});
  $src .= sprintf(';host=%s', $dbconn{$id}{'dbhost'})
    if $dbconn{$id}{'dbhost'};
  $dbh = DBI->connect(
    $src,
    $dbconn{$id}{'dbuser'},
    $dbconn{$id}{'dbpass'},
    {
      AutoCommit => 1,
      pg_enable_utf => 1
    }
  );
  if(!ref($dbh)) { return DBI::errstr; }
  $dbconn{$id}{'conn'} = $dbh;
  return $dbh;
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
# %s - start time (unix epoch)
# %e - end time (unix epoch)
# %E - end time (as YYYYMMDDHHMMSS)
# %x - username before translation (as it appears in xlogfile)
# %v - version number
# %d - dumpfile (content of the 'dumpfile' xlogfile field)
# %D - dumpfile processed for NH4 (_ replaced with :)
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
  my $r_version = $data->{'version'};
  my $r_dumpfile = uri_escape($data->{'dumplog'});

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
  $strg =~ s/%v/$r_version/g;
  $strg =~ s/%d/$r_dumpfile/g;
  $strg =~ s/%D/$r_dumpfile_nh4/g;

  return $strg;
}


#===============================================================================
# Returns true if the log row, passed as hashref as the argument contains
# all required fields
#===============================================================================

sub logfile_require_fields
{
  my $row = shift;

  for my $required_field (@{$nhdb_def->{'feeder'}{'require_fields'}}) {
    if(!exists $row->{$required_field}) { return undef; }
  }
  return 1;
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
# Function to help parse multiple-value command-line arguments. The arrayref
# passed in contains strings, that can have form "aaa,bbb,ccc". These strings
# are expanded to a list ("aaa","bbb","ccc") that replaces the source array
# element.
#===============================================================================

sub cmd_option_array_expand
{
  for my $ary (@_) {
    for(my $i = 0; $i < scalar(@$ary); $i++) {
      splice(@$ary, $i, 1, grep { $_ } split(/,/, $ary->[$i]));
    }
  }
}


#===============================================================================
# Get argument and return 'on', 'off' or 'undefined' depending on the state of
# the argument.
#===============================================================================

sub cmd_option_state
{
  my $option = shift;

  if($option) {
    return 'on';
  } elsif(defined $option) {
    return 'off';
  } else {
    return 'undefined';
  }
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
# Function returns true when supplied variant should be presenting version
# number to the user.
#===============================================================================

sub nhdb_show_version
{
  my $var = shift;

  return (grep { $_ eq $var; } @{$nhdb_def->{'showversion'}}) ? 1 : 0;
}


1;
