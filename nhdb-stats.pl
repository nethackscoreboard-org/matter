#!/usr/bin/perl

#============================================================================
# NHDB Stat Generator
# """""""""""""""""""
# 2014 Mandevil
#============================================================================

use strict;
use DBI;
use Getopt::Long;
use NetHack;
use NHdb;
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
my $http_root = '/home/httpd/nh';

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
  my @a;
  my $cnt = 1;

  my $sth = $dbh->prepare($qry);
  my $r = $sth->execute();
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
# Generate page(s) for recent games.
#============================================================================

sub gen_page_recent
{
  my $page = shift;
  my $variant = shift;
  my @variants = ('all');
  
  #--- init

  tty_message('Creating recent games page %s (%s): ', $page, $variant);
  my $view = $page{$page}[2];
  push(@variants, @{$NetHack::nh_def->{nh_variants_ord}});

  #--- pull data from database

  my $query = qq{SELECT * FROM $view LIMIT 100};
  if($variant ne 'all') {
    $query = qq{SELECT * FROM $view WHERE variant = '$variant' LIMIT 100};
  }
  my $a = sql_load($query);
  die "Failed to load data ($a)" if !ref($a);
  tty_message('loaded from db');

  #--- open page file

  my $page_file = sprintf($page{$page}[0], $variant);
  open(F, '> ' . $page_file)
    || die sprintf('Failed to open file %s', $page{recent});
  html_head(*F, $page{$page}[1]);
  print F '<p id="varmenu">';
  for my $tvar (@variants) {
    my $class = 'unselected';
    my $varname;
    my $link = sprintf($page{$page}[0], $tvar);
    $link =~ s{.*/}{};
    if($tvar eq $variant) { $class = 'selected'; }
    if($tvar eq 'all') {
      $varname = 'All';
    } else {
      $varname = $NetHack::nh_def->{'nh_variants_def'}{$tvar};
    }
    if($class eq 'selected') {
      print F html_span($varname, $class), ' ';
    } else {
      print F html_ahref($link, html_span($varname, $class)), "\n";
    }
  }
  print F '</p>';
  print F q{<table class="bordered">};

  #--- output page content

  html_table_head(*F, $page{$page}[3]);

  for my $row (@$a) {
    print F format_row(
      $row,
      $page{$page}[3],
      $logfiles->{$row->{'logfiles_i'}}
    );
  }

  #--- close page file

  print F q{</table>};
  html_close(*F);
  close(F);
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

if(!GetOptions(
  'variant=s' => \@cmd_variant
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

#--- generate pages

my @variants = ('all');
push(@variants, @{$NetHack::nh_def->{nh_variants_ord}});
for my $var (@variants) {
  if(scalar(@cmd_variant)) {
    next if scalar(@cmd_variant) && !grep { $var eq lc($_) } @cmd_variant;
  }
  gen_page_recent('recent', $var);
  gen_page_recent('ascended', $var);
}

#--- disconnect from database

$dbh->disconnect();
tty_message("Disconnected from database\n");

#--- release lock file

unlink($lockfile);
tty_message("Removed lockfile\n");
