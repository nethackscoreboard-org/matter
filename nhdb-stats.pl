#!/usr/bin/perl

#============================================================================
# NHDB Stat Generator
# """""""""""""""""""
# 2014 Mandevil
#============================================================================

use strict;
use warnings;
use DBI;
use Getopt::Long;
use NetHack;
use NHdb;
use Template;
use utf8;


#============================================================================
#=== globals ================================================================
#============================================================================

my $dbh;
my $logfiles;


#============================================================================
#=== definitions ============================================================
#============================================================================

my $lockfile = '/tmp/nhdb-stats.lock';
my $http_root = $NHdb::nhdb_def->{'http_root'};
my $tt = Template->new(
  'OUTPUT_PATH' => $http_root,
  'INCLUDE_PATH' => 'templates'
);

#--- page definitions

my %page = (
  
  'recent' => [ 
    "$http_root/recent.%s.html",
    'Recent Games',
    'games_recent', 
    [ qw(
      n
      server
      variant
      name
      character
      points
      turns
      duration
      dlvl
      hp
      time
      death
    ) ]
  ],
  
  'ascended' => [ 
    "$http_root/ascended.%s.html",
    'Ascended Games',
    'ascended_recent',
    [ qw(
      n
      server
      variant
      name
      character
      points
      turns
      duration
      dlvl
      hp
      time
      ncond%2
      conducts%0
    ) ]
  ]
);



#============================================================================
#===== __  ==============  _   _  ===========================================
#===  / _|_   _ _ __   ___| |_(_) ___  _ __  ___  ===========================
#=== | |_| | | | '_ \ / __| __| |/ _ \| '_ \/ __| ===========================
#=== |  _| |_| | | | | (__| |_| | (_) | | | \__ \ ===========================
#=== |_|  \__,_|_| |_|\___|\__|_|\___/|_| |_|___/ ===========================
#===                                              ===========================
#============================================================================


#============================================================================
# Output a message passed as argument if STDOUT is a tty.
#============================================================================

sub tty_message
{
  my $s = shift;

  return if ! -t STDOUT;
  if(!$s) {
    print "\n";  
  } else {
    printf $s, @_;
  }
}


#============================================================================
# Load data from SQL, store them as array of hashrefs.
#============================================================================

sub sql_load
{
  my $qry = shift;
  my @arg = shift;
  my @a;
  my $cnt = 1;

  my $sth = $dbh->prepare($qry);
  my $r;
  if(scalar(@a) == 0) {
    $r = $sth->execute();
  } else {
    $r = $sth->execute(@arg);
  }
  if(!$r) {
    return sprintf('Failed to query database (%s)', $sth->errstr());
  }
  while(my $row = $sth->fetchrow_hashref()) {
    $row->{n} = $cnt++;
    push(@a, $row);
  }
  return \@a;
}


#============================================================================
# Load logfiles configuration info from db
#============================================================================

sub sql_load_logfiles
{
  my $sth = $dbh->prepare('SELECT * FROM logfiles');
  my $r = $sth->execute();
  if(!$r) {
    return sprintf('Failed to query database (%s)', $sth->errstr());
  }
  while(my $row = $sth->fetchrow_hashref()) {
    my $logfiles_i  = $row->{'logfiles_i'};
    $logfiles->{$logfiles_i} = $row;
  }
}


#============================================================================
#============================================================================

sub gen_page_info
{
  my ($re, $sth);
  my %data;

  tty_message("Generating generic stats\n");

  #--- get database data

  $sth = $dbh->prepare(q{SELECT count(*) FROM games});
  $sth->execute() or die;
  ($data{'inf_games_total'}) = $sth->fetchrow_array();
  
  $sth = $dbh->prepare(q{SELECT count(*) FROM games WHERE scummed IS TRUE});
  $sth->execute() or die;
  ($data{'inf_games_scum'}) = $sth->fetchrow_array();

  $sth = $dbh->prepare(q{SELECT count(*) FROM games WHERE ascended IS TRUE});
  $sth->execute() or die;
  ($data{'inf_games_asc'}) = $sth->fetchrow_array();
  
  #--- generate page

  $data{'cur_time'} = scalar(localtime());
  $tt->process('general.tt', \%data, 'general.html')
    or die $tt->error();
}


#============================================================================
# Generate "Recent Games" and "Ascended Games" pages.
#============================================================================

sub gen_page_recent
{
  my $page = shift;
  my $variant = shift;
  my @variants = ('all');
  my ($view, $sth, $r);
  my %data;

  #--- init

  tty_message('Creating recent games page %s (%s): ', $page, $variant);
  push(@variants, @{$NetHack::nh_def->{nh_variants_ord}});

  #--- select source view

  if($page eq 'recent') {
    $view = 'games_recent';
  } elsif($page eq 'ascended') {
    $view = 'ascended_recent';
  } else {
    die "Undefined page";
  }
  #--- pull data from database

  if($variant eq 'all') {
    $sth = $dbh->prepare(qq{SELECT * FROM $view LIMIT 100});
    $r = $sth->execute();
  } else {
    $sth = $dbh->prepare(qq{SELECT * FROM $view WHERE variant = ? LIMIT 100});
    $r = $sth->execute($variant);
  }
  if(!$r) {
    die sprintf('Failed to query database (%s)', $sth->errstr());
  }

  #--- pull (and transform) data from database

  my $cnt = 1;
  my @a;
  while(my $row = $sth->fetchrow_hashref()) {

  #--- line numbers

    $row->{n} = $cnt++;

  #--- convert realtime to human-readable form

    $row->{'realtime'} = format_duration($row->{'realtime'});

  #--- include conducts in the ascended message

    if($row->{'ascended'}) {
      my @c = nh_conduct($row->{'conduct'});
      $row->{'ncond'} = scalar(@c);
      $row->{'tcond'} = join(' ', @c);
      if(scalar(@c) == 0) {
        $row->{death} = 'ascended with all conducts broken';
      } else {
        $row->{death} = sprintf(
          qq{ascended with %d conduct%s intact (%s)},
          scalar(@c), (scalar(@c) == 1 ? '' : 's'), $row->{'tcond'}
        );
      }
    }

  #--- game dump URL

    if($logfiles->{$row->{'logfiles_i'}}{'dumpurl'}) {
      $row->{'dump'} = url_substitute(
        $logfiles->{$row->{'logfiles_i'}}{'dumpurl'},
        $row
      );
    }

  #--- realtime (aka duration)

  if($row->{'variant'} eq 'ace' || $row->{'variant'} eq 'nh4') {
    $row->{'realtime'} = '';
  }

  #--- finish (push row into an array)

    push(@a, $row);
  }
  tty_message('loaded from db (%d lines)', scalar(@a));

  #--- supply additional data

  $data{'result'}   = \@a;
  $data{'cur_time'} = scalar(localtime());
  $data{'variants'} = [ 'all', @{$NetHack::nh_def->{nh_variants_ord}} ];
  $data{'vardef'}   = $NetHack::nh_def->{'nh_variants_def'};
  $data{'variant'}  = $variant;

  #--- process template

  $tt->process("$page.tt", \%data, "$page.$variant.html")
    or die $tt->error();

  tty_message(", done\n");
}


#============================================================================
# Display usage help.
#============================================================================

sub help
{
  print "Usage: nhdb-stats.pl [options]\n\n";
  print "  --help         get this information text\n";
  print "  --variant=VAR  limit processing to specified variant(s)\n";
  print "  --force        force processing of everything\n";
  print "\n";
}


#============================================================================
#===================  _  ====================================================     
#===  _ __ ___   __ _(_)_ __  ===============================================
#=== | '_ ` _ \ / _` | | '_ \  ==============================================
#=== | | | | | | (_| | | | | | ==============================================
#=== |_| |_| |_|\__,_|_|_| |_| ==============================================
#===                           ==============================================
#============================================================================

#--- title

tty_message(
  "\n" .
  "NetHack Statistics Aggregator -- Stats Generator\n" .
  "================================================\n" .
  "(c) 2013-14 Mandevil\n\n"
);

#--- process command-line

my @cmd_variant;
my $cmd_force;

if(!GetOptions(
  'variant=s' => \@cmd_variant,
  'force' => \$cmd_force
)) {
  help();
  exit(1);
}

#--- lock file check/open

if(-f $lockfile) {
  die "Another instance running\n";
  exit(1);
}
open(F, "> $lockfile") || die "Cannot open lock file $lockfile\n";
print F $$, "\n";
close(F);
tty_message("Created lockfile\n");

#--- connect to database

$dbh = DBI->connect(
  'dbi:Pg:dbname=nhdb', 
   'nhdbstats', 
   'zQaHOypOFyna2fm7', 
   { AutoCommit => 1, pg_enable_utf => 1 }
);
if(!ref($dbh)) {
  die sprintf('Failed to connect to the database (%s)', $DBI::errstr);
}
tty_message("Connected to database\n");

#--- load list of logfiles

sql_load_logfiles();
tty_message("Loaded list of logfiles\n");

#--- read what is to be updated

my @update_variants;
my $sth = $dbh->prepare(qq{SELECT variant FROM update WHERE name = ''});
my $re = $sth->execute();
if(!$re) {
  tty_message("Failed to read from update table (%s)\n", $sth->errstr());
  die;
} else {
  while(my ($a) = $sth->fetchrow_array()) {
    push(@update_variants, $a);
  }
}

#--- generate pages

my @variants;
if($cmd_force) {
  @variants = ('all');
  push(@variants, @{$NetHack::nh_def->{nh_variants_ord}});
} else {
  @variants = @update_variants;
}
if(scalar(@variants)) {
  tty_message("Following variants scheduled to update: %s\n", join(',', @variants));
} else {
  tty_message("No variants scheduled to update\n");
}
for my $var (@variants) {
  if(scalar(@cmd_variant)) {
    next if scalar(@cmd_variant) && !grep { $var eq lc($_) } @cmd_variant;
  }
  #gen_page_recent('recent', $var);
  #gen_page_recent('ascended', $var);
  gen_page_recent('recent', $var);
  gen_page_recent('ascended', $var);

#--- delete update flags

  $dbh->do(qq{DELETE FROM update WHERE variant = '$var' AND name = ''});

}

#--- generic info page

gen_page_info();

#--- disconnect from database

$dbh->disconnect();
tty_message("Disconnected from database\n");

#--- release lock file

unlink($lockfile);
tty_message("Removed lockfile\n");
