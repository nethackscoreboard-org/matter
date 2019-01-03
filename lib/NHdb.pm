#!/usr/bin/env perl

#===========================================================================
# NetHack database project library
#===========================================================================

package NHdb;
require Exporter;
use URI::Escape;
use Path::Tiny;
use JSON;
use DBI;
use POSIX qw(strftime);
use FindBin qw($Bin);
use lib "$Bin/lib";
use integer;
use strict;


#=== module exports ========================================================

our @ISA = qw(Exporter);
our @EXPORT = qw(
  dbconn
  dbdone
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

  my $def_json = path($Bin, 'cfg/nhdb_def.json')->slurp_raw();
  $nhdb_def = $js->decode($def_json);

  #--- read the file with db passwords (if defined)

  if(exists $nhdb_def->{'auth'}) {
    $def_json = path($Bin, 'cfg', $nhdb_def->{'auth'})->slurp_raw();
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


1;
