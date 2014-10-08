#!/usr/bin/perl

#===========================================================================
# NetHack database project library
#===========================================================================

package NHdb;
require Exporter;
use NetHack;
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
  my $fh;
  open($fh, '<', 'cfg/nhdb_def.json') or die;
  my $def_json = <$fh>;
  $nhdb_def = decode_json($def_json);
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

  if(exists $dbconn{$id}{'conn'} && $dbconn{$id}{'conn'}) {
    return $dbconn{$id}{'conn'};
  }

  #--- if the id doesn't exist, initialize it

  if(!exists $dbconn{$id}) {
    if(exists $nhdb_def->{'db'}{$id}) {
      my $db = $nhdb_def->{'db'}{$id};
      dbinit(
        $id,
        $db->{'dbname'},
        $db->{'dbuser'},
        $db->{'dbpass'},
        exists $db->{'dbhost'} ? $db->{'dbhost'} : undef
      );
    } else {
      return "Database id '$id' not configured";
    }
  }

  #--- otherwise, try to open the handle

  my $src;
  $src = sprintf('dbi:Pg:dbname=%s', $nhdb_def->{'db'}{$id}{'dbname'});
  $src .= sprintf(';host=%s', $nhdb_def->{'db'}{$id}{'dbhost'})
    if $nhdb_def->{'db'}{$id}{'dbhost'};
  $dbh = DBI->connect(
    $src,
    $nhdb_def->{'db'}{$id}{'dbuser'},
    $nhdb_def->{'db'}{$id}{'dbpass'},
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

