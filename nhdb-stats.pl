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

$| = 1;


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
  'INCLUDE_PATH' => 'templates',
  'RELATIVE' => 1
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
# Order an array by using reference array
#============================================================================

sub array_sort_by_reference
{
  my $ref = shift;
  my $ary = shift;
  my @result;

  for my $x (@$ref) {
    if(grep { $x eq $_ } @$ary) {
      push(@result, $x);
    }
  }
  return \@result;
}


#============================================================================
# Load SQL query into array of hashref with some additional processing.
#============================================================================

sub sql_load
{
  my $query     = shift;         # 1. database query
  my $cnt_start = shift;         # 2. counter start (opt)
  my $cnt_incr  = shift;         # 3. counter increment (opt)
  my $preproc   = shift;         # 4. subroutine to pre-process row
  my (@args)    = @_;            # R. arguments to db query
  my @result;

  my $sth = $dbh->prepare($query);
  my $r = $sth->execute(@args);
  if(!$r) { return $sth->errstr(); }
  while(my $row = $sth->fetchrow_hashref()) {
    &$preproc($row) if $preproc;
    if(defined $cnt_start) {
      $row->{'n'} = $cnt_start;
      $cnt_start += $cnt_incr;
    }
    push(@result, $row);
  }
  $sth->finish();
  return \@result;
}


#============================================================================
# Create list of player-variant pairs to be updated.
#============================================================================

sub update_schedule_players
{
  my $cmd_force = shift;
  my $cmd_variant = shift;
  my $cmd_player = shift;
  my ($sth, $r);

  #--- display information

  tty_message("Getting list of player pages to update\n");
  tty_message("  Forced processing enabled\n")
    if $cmd_force;
  tty_message("  Restricted to variants: %s\n", join(',', @$cmd_variant))
    if scalar(@$cmd_variant);
  tty_message("  Restricted to players: %s\n", join(',', @$cmd_player))
    if scalar(@$cmd_player);

  #--- get list of allowed variants
  # this is either all statically-defined variants or a list
  # of variants supplied through --variant cmdline option (checked
  # against the statically-defined list).

  my @variants_final;
  my @variants_known = ('all', @{$NetHack::nh_def->{nh_variants_ord}});
  if(scalar(@$cmd_variant)) {
    for my $var (@$cmd_variant) {
      if(grep { $var eq $_} @variants_known) {
        push(@variants_final, $var);
      }
    }
  } else {
    @variants_final = @variants_known;
  }
  tty_message(
    "  Variants that will be processed: %s\n",
    join(',', @variants_final)
  );

  #--- get list of all known player names

  tty_message("  Loading list of all players");
  my @player_list;
  $sth = $dbh->prepare(q{SELECT name FROM games GROUP BY name});
  $r = $sth->execute();
  if(!$r) { die sprintf('Cannot get list of players (%s)', $sth->errstr()); }
  while(my ($plr) = $sth->fetchrow_array()) {
    push(@player_list, $plr);
  }
  tty_message(", loaded %d players\n", scalar(@player_list));

  #--- get list of existing (player, variant) combinations
  #--- that have non-zero number of games in db

  tty_message('  Loading list of player,variant combinations');
  my %player_combos;
  my $cnt_plrcombo = 0;
  $sth = $dbh->prepare(
    q{SELECT name, variant FROM update WHERE name <> ''}
  );
  $r = $sth->execute();
  if(!$r) { die sprintf('Cannot get list of player,variant combos (%s)', $sth->errstr()); }
  while(my ($plr, $var) = $sth->fetchrow_array()) {
    $player_combos{$plr}{$var} = 1;
    $cnt_plrcombo++;
  }
  tty_message(", %d combinations exist\n", $cnt_plrcombo);

  #--- forced update enabled

  my @pages_forced;
  if($cmd_force) {
    for my $plr (@player_list) {

      #--- if list of players is specified on the cmdline, then
      #--- use it as filter here
      if(
        scalar(@$cmd_player) &&
        !(grep { lc($plr) eq lc($_)} @$cmd_player)
      ) {
        next;
      }

      #--- create cartesian product, but restricted
      #--- to existing player,variant combos
      for my $var (@variants_final) {
        if(exists $player_combos{$plr}{$var}) {
          push(@pages_forced, [$plr, $var]);
        }
      }
    }
    tty_message("  Forcing update of %d pages\n", scalar(@pages_forced));
    return(\@pages_forced, \%player_combos);
  }

  #--- get list of updated players

  tty_message("  Loading list of player updates");
  my @pages_updated;
  my $cnt = 0;
  $sth = $dbh->prepare(q{SELECT * FROM update WHERE name <> '' AND upflag IS TRUE});
  $r = $sth->execute();
  if(!$r) { die sprintf('Cannot get list of player updates (%s)', $sth->errstr()); }
  while(my ($var, $plr) = $sth->fetchrow_array()) {
    $cnt++;
    # skip entries with variants not in @variants_final
    if(!grep { $var eq $_ } @variants_final) { next; };
    # skip entries with players not in @player_list
    if(!grep { $plr eq $_ } @player_list) { next; }
    # skip list of players not specified in cmdline (if relevant)
    # NOTE: the matching is case-insensitive
    if(scalar(@$cmd_player)) {
      if(!grep { lc($plr) eq lc($_) } @$cmd_player) { next; }
    }
    #
    push(@pages_updated, [$plr, $var]);
  }
  tty_message(
    ", %d updates, %d rejected\n",
    scalar(@pages_updated),
    $cnt - scalar(@pages_updated)
  );
  return(\@pages_updated, \%player_combos);
}


#============================================================================
# Create list of variants to be updated. Sources of the info about what
# should be update are:
#  1) --force command-line option
#  2) --variant command-line option
#  3) nethack_def.json statically defined variants
#  4) update table in the database
#============================================================================

sub update_schedule_variants
{
  my $cmd_force = shift;
  my $cmd_variant = shift;

  #--- list of allowed variants targets; anything not in this array
  #--- is invalid

  my @variants_known = ('all', @{$NetHack::nh_def->{nh_variants_ord}});

  #--- forced processing

  my @candidates;
  if($cmd_force) {
    if(scalar(@$cmd_variant)) {
      @candidates = @$cmd_variant;
    } else {
      @candidates = @variants_known;
    }
  } else {

  #--- no forcing, using database

    my $sth = $dbh->prepare(
      q{SELECT variant FROM update WHERE name = '' AND upflag IS TRUE}
    );
    my $re = $sth->execute();
    if(!$re) { 
      die sprintf("Failed to read from update table (%s)" . $sth->errstr());
    }
    while(my ($a) = $sth->fetchrow_array()) {
      if(scalar(@$cmd_variant)) {
        if(!grep { lc($_) eq $a } @$cmd_variant) {
          next;
        }
      }
      push(@candidates, $a);
    }
  }

  #--- validation

  my @final;
  for my $x (@candidates) {
    if(grep {$_ eq $x} @variants_known) {
      push(@final, $x);
    }
  }

  #--- finish

  return \@final;
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

sub row_fix
{
  my $row = shift;
  my $variant = shift;

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

  #--- player page

  $row->{'plrpage'} = url_substitute(
    sprintf("players/%%U/%%u.%s.html", $variant),
    $row
  );
}


#============================================================================
#============================================================================

sub gen_page_info
{
  my ($re, $sth);
  my %data;

  tty_message('Generating generic stats');

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
  tty_message(", done\n");
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
  my (@arg, $query, $result);
  my %data;

  #--- init

  tty_message('Creating recent games page %s (%s): ', $page, $variant);
  push(@variants, @{$NetHack::nh_def->{nh_variants_ord}});

  #--- select source view

  if($page eq 'recent') {
    $view = 'v_games_recent';
  } elsif($page eq 'ascended') {
    $view = 'v_ascended_recent';
  } else {
    die "Undefined page";
  }

  #--- prepare query;

  $query = qq{SELECT * FROM $view LIMIT 100};
  if($variant ne 'all') {
    $query = qq{SELECT * FROM $view WHERE variant = ? LIMIT 100};
    @arg = ($variant);
  }

  #--- pull data from database

  $result = sql_load(
    $query, 1, 1,
    sub { row_fix($_[0], $variant); },
    @arg
  );
  return sprintf('Failed to query database (%s)', $sth->errstr) if !ref($result);
  tty_message('loaded from db (%d lines)', scalar(@$result));

  #--- supply additional data

  $data{'result'}   = $result;
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
#============================================================================

sub gen_page_player
{
  my $name          = shift;
  my $variant       = shift;
  my $player_combos = shift;
  my @variants = ('all');
  my ($query, @arg, $sth, $r);
  my %data;                         # data fed to TT2
  my $result;                       # rows from db (aref)

  #--- info

  tty_message("Creating page for $name/$variant");

  #=== all ascended games ==================================================

  $query = q{SELECT * FROM v_ascended WHERE name = ?};
  @arg = ($name);
  if($variant ne 'all') {
    $query .= ' AND variant = ?';
    push(@arg, $variant);
  }
  $result = sql_load(
    $query, 1, 1,
    sub { row_fix($_[0], $variant); },
    @arg
  );
  return $result if !ref($result);
  $data{'result_ascended'} = $result;

  #=== number of matching games ============================================

  $query = q{SELECT count(*) FROM games WHERE scummed IS FALSE AND name = ?};
  @arg = ($name);
  if($variant ne 'all') {
    $query = q{SELECT count(*) FROM games LEFT JOIN logfiles USING (logfiles_i) WHERE scummed IS FALSE AND name = ? AND variant = ?};
    push(@arg, $variant);
  }
  $result = sql_load($query, undef, undef, undef, @arg);
  return $result if !ref($result);
  $data{'games_count'} = $result->[0]{'count'};

  #=== recent ascensions ===================================================

  $query = q{SELECT * FROM v_games_recent WHERE name = ?};
  @arg = ($name);
  if($variant ne 'all') {
    $query .= ' AND variant = ?';
    push(@arg, $variant);
  }
  $query .= ' LIMIT 15';
  $result = sql_load(
    $query, $data{'games_count'}, -1,
    sub { row_fix($_[0], $variant); },
    @arg
  );
  return $result if !ref($result);
  $data{'result_recent'} = $result;

  #=== additional data =====================================================

  $data{'cur_time'} = scalar(localtime());
  $data{'name'} = $name;
  $data{'variant'} = $variant;
  $data{'variants'} = array_sort_by_reference(
    [ 'all', @{$NetHack::nh_def->{nh_variants_ord}} ],
    [ keys %{$player_combos->{$name}} ]
  );
  $data{'vardef'}   = $NetHack::nh_def->{'nh_variants_def'};

  #=========================================================================

  #--- determine filename

  my $initial = substr($name, 0, 1);
  my $file = sprintf("players/%s/%s.%s.html", $initial, $name, $variant);

  #--- process template

  $tt->process('player.tt', \%data, $file)
    or die $tt->error();

  #--- finish

  tty_message(", done\n");
  return undef;
}


#============================================================================
# Display usage help.
#
# Semantics description, this should be moved into some other text, but for
# now:
#
# Note: in this description "variant" means either one of the known
# NetHack variants or 'all' pseudo-variant, that aggregates data from all
# variants.
#
# --force makes the program ignore what is in the update table; in other
# words, it will process even pages that are unaffected by new information;
# when forcing processing of everything, the program takes the list of
# known, statically defined variants (in file nethack_def.json, key
# nh_variants_ord).
#
# --variant can be used multiple times and it limits processing to
# specified variant(s) (specified by their short-code); this does not make
# the program ignore the update table, though! if one wants to enforce
# updating only certain variants, combine this option with --force
#
# --player will only generate pages for given player name; aggregate pages
# (such as "Recent Games", "Ascended Games" etc.) will not be processed;
# again, combine with --force to update player page even in the absence of
# new information; combine this with --variant to limit processing to only
# certain variant.
#
# --players, --noplayers enable/disable generating player pages; processing
# players is enabled by default; explicitly disabling is very useful when
# using --force, as this otherwise makes the program refresh all user pages
# which is very time consuming
#
# --aggr, --noaggr enable/disable generating aggregate pages
#============================================================================

sub help
{
  print "Usage: nhdb-stats.pl [options]\n\n";
  print "  --help         get this information text\n";
  print "  --variant=VAR  limit processing to specified variant(s)\n";
  print "  --force        force processing of everything\n";
  print "  --player=NAME  update only given player\n";
  print "  --noplayers    disable generating player pages\n";
  print "  --noaggr       disable generating aggregate pages\n";
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
my @cmd_player;
my $cmd_players = 1;
my $cmd_aggr = 1;

if(!GetOptions(
  'variant=s' => \@cmd_variant,
  'force'     => \$cmd_force,
  'player=s'  => \@cmd_player,
  'players!'  => \$cmd_players,
  'aggr!'     => \$cmd_aggr
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

if($cmd_aggr) {
  my $update_variants = update_schedule_variants($cmd_force, \@cmd_variant);
  tty_message(
    "Following variants scheduled to update: %s\n",
    join(',', @$update_variants)
  );

#--- generate aggregate pages

  for my $var (@$update_variants) {
    gen_page_recent('recent', $var);
    gen_page_recent('ascended', $var);
    $dbh->do(
      q{UPDATE update SET upflag = FALSE WHERE variant = ? AND name = ''},
      undef, $var
    );
  }
}

#--- generate per-player pages

if($cmd_players) {
  my ($pages_update, $player_combos) = update_schedule_players(
    $cmd_force, \@cmd_variant, \@cmd_player
  );
  for my $pg (@$pages_update) {
    gen_page_player(@$pg, $player_combos);
    $dbh->do(
      q{UPDATE update SET upflag = FALSE WHERE variant = ? AND name = ?},
      undef, $pg->[1], $pg->[0]
    );
  }
}

#--- generic info page

#if(grep('all', @$update_variants)) {
#  gen_page_info();
#}

#--- disconnect from database

$dbh->disconnect();
tty_message("Disconnected from database\n");

#--- release lock file

unlink($lockfile);
tty_message("Removed lockfile\n");
