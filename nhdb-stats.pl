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
my $devnull = 0;
my $devnull_path;


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
# Pluralize noun
#============================================================================

sub pl
{
  my ($s, $n) = @_;

  return sprintf('%d %s', $n, $n != 1 ? $s . 's' : $s);
}


#============================================================================
# Format age received as years, months, days and hours.
#============================================================================

sub fmt_age
{
   my ($yr, $mo, $da, $hr) = @_;
   my @result;

   if($yr) {
     push(@result, pl('year', $yr));
   }
   if($mo) {
     push(@result, pl('month', $mo));
   }
   if($da) {
     push(@result, pl('day', $da));
   }
   if($hr && !$yr) {
     push(@result, pl('hour', $hr));
   }
   if(scalar(@result) == 0) {
     push(@result, 'recently');
   }

   return join(' ', @result);
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
# Some additional processing of a row of data from games table (formats
# fields into human readable format, mostly).
#============================================================================

sub row_fix
{
  my $row = shift;
  my $variant = shift;

  #--- convert realtime to human-readable form

  $row->{'realtime_raw'} = defined $row->{'realtime'} ? $row->{'realtime'} : 0;
  $row->{'realtime'} = format_duration($row->{'realtime'});

  #--- include conducts in the ascended message

  if($row->{'ascended'}) {
    my @c = nh_conduct($row->{'conduct'}, $variant);
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

  if($logfiles->{$row->{'logfiles_i'}}{'server'} eq 'dev') {
    $row->{'plrpage'} = url_substitute(
      sprintf("players/%%u.html", $variant),
      $row
    );
  } else {
    $row->{'plrpage'} = url_substitute(
      sprintf("players/%%U/%%u.%s.html", $variant),
      $row
    );
  }
}


#============================================================================
# Create structure for calendar view of ascensions (ie. ascensions by years/
# /months)
#============================================================================

sub ascensions_calendar_view
{
  my $data = shift;
  my %acc;
  my @result;

  #--- assert data received

  if(scalar(@$data) == 0) { die 'No data received by ascensions_calendar_view()'; }

  #--- create year/months counts in hash

  for my $ascension (@$data) {
    $ascension->{'endtime'} =~ /^(\d{4})-(\d{2})-\d{2}\s/;
    my ($year, $month) = ($1, $2+0);
    if(!exists($acc{$year}{$month})) { $acc{$year}{$month} = 0; }
    $acc{$year}{$month}++;
    if(!defined($acc{'year_low'}) || $year < $acc{'year_low'}) {
      $acc{'year_low'} = $year;
    }
    if(!defined($acc{'year_hi'}) || $year > $acc{'year_hi'}) {
      $acc{'year_hi'} = $year;
    }
  }

  #--- now turn the data into an array

  for(my $year = $acc{'year_low'}; $year <= $acc{'year_hi'}; $year++) {
    my @row = ($year);
    my $yearly_total = 0;
    for my $month (1..12) {
      my $value = exists($acc{$year}{$month}) ? $acc{$year}{$month} : 0;
      push(@row, $value);
      $yearly_total += $value;
    }
    push(@row, $yearly_total);
    push(@result, \@row);
  }

  #--- finish

  return \@result;
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
# Generate "Recent Games" and "Ascended Games" pages. This function is used
# for both regular and devnull pages. The arg #5 (filtering queries by
# logfiles_i field) is currently used as indication of devnull page
# generation; it's bit unsystematic and probably should be changed.
#============================================================================

sub gen_page_recent
{
  #--- arguments

  my (
    $page,         # 1. "recent"|"ascended"
    $variant,      # 2. variant filter
    $template,     # 3. TT template file
    $html,         # 4. target html file
    $logfiles_i    # 5. logfile source filter (optional)
  ) = @_;

  #--- other variables

  my @variants = ('all');
  my ($view, $sth, $r);
  my (@arg, @cond, $query_lst, $query_cnt, $result);
  my $cnt_start = 1;
  my $cnt_incr = 1;
  my %data;

  #--- init

  tty_message(
    'Creating %s page (%s): ', 
    $page, 
    $logfiles_i ? $logfiles->{$logfiles_i}{'server'} : $variant
  );
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

  $query_lst = qq{SELECT * FROM $view };
  if($variant && $variant ne 'all') {
    @cond = ('variant = ?');
    @arg = ($variant);
  }
  if($logfiles_i) {
    @cond = ('logfiles_i = ?');
    @arg = ($logfiles_i);
  }
  if(scalar(@cond)) {
    $query_lst .= 'WHERE ' . join(' AND ', @cond);
    $query_lst .= ' ';
  }
  $query_cnt = $query_lst;
  $query_lst .= 'LIMIT 100' unless ($page eq 'ascended' && $logfiles_i);
  $query_cnt =~ s/\*/count(*)/;

  #--- get count of games for /dev/null

  if($logfiles_i) {
    $result = sql_load($query_cnt, undef, undef, undef, @arg);
    return $result if !ref($result);
    $data{'games_count'} = $cnt_start = int($result->[0]{'count'});
    $cnt_incr = -1;
    tty_message('%d games, ', $data{'games_count'});
  }

  #--- pull data from database

  $result = sql_load(
    $query_lst, $cnt_start, $cnt_incr,
    sub { row_fix($_[0], $variant); },
    @arg
  );
  return sprintf('Failed to query database (%s)', $result) if !ref($result);
  tty_message('loaded from db (%d lines)', scalar(@$result));

  #--- supply additional data

  $data{'devnull'}  = $devnull if $devnull;
  $data{'result'}   = $result;
  $data{'cur_time'} = scalar(localtime());
  $data{'variants'} = [ 'all', @{$NetHack::nh_def->{nh_variants_ord}} ];
  $data{'vardef'}   = $NetHack::nh_def->{'nh_variants_def'};
  $data{'variant'}  = $variant;

  #--- process template

  $tt->process($template, \%data, $html)
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
  my %ascs_by_rowid;                # ascensions ref'd by rowid

  #--- info

  tty_message("Creating page for $name/$variant");

  #=== all ascended games ==================================================
  # load all player's ascension in ordered array of hashrefs; also we create
  # extra hashref %ascs_by_rowid that allows us to later reference the games
  # by their rowid fields

  $query = q{SELECT * FROM v_ascended WHERE name = ?};
  @arg = ($name);
  if($variant ne 'all') {
    $query .= ' AND variant = ?';
    push(@arg, $variant);
  }
  $result = sql_load(
    $query, 1, 1,
    sub { 
      row_fix($_[0], $variant);
      $ascs_by_rowid{$_[0]{'rowid'}} = $_[0];
    },
    @arg
  );
  return $result if !ref($result);
  $data{'result_ascended'} = $result;
  $data{'games_count_asc'} = scalar(@$result);

  #=== total number of games ================================================

  $query = q{SELECT count(*) FROM games WHERE scummed IS FALSE AND name = ?};
  @arg = ($name);
  if($variant ne 'all') {
    $query = q{SELECT count(*) FROM games LEFT JOIN logfiles USING (logfiles_i) WHERE scummed IS FALSE AND name = ? AND variant = ?};
    push(@arg, $variant);
  }
  $result = sql_load($query, undef, undef, undef, @arg);
  return $result if !ref($result);
  $data{'games_count_all'} = int($result->[0]{'count'});

  #=== number of scummed games =============================================

  $query = q{SELECT count(*) FROM games WHERE scummed IS TRUE AND name = ?};
  @arg = ($name);
  if($variant ne 'all') {
    $query = q{SELECT count(*) FROM games LEFT JOIN logfiles USING (logfiles_i) WHERE scummed IS TRUE AND name = ? AND variant = ?};
    push(@arg, $variant);
  }
  $result = sql_load($query, undef, undef, undef, @arg);
  return $result if !ref($result);
  $data{'games_count_scum'} = $result->[0]{'count'};

  #=== the first game ======================================================

  $query = q{SELECT * FROM v_games WHERE name = ?};
  @arg = ($name);
  if($variant ne 'all') {
    $query .= q{ AND variant = ?};
    push(@arg, $variant);
  }
  $query .= ' LIMIT 1';
  $result = sql_load(
    $query, undef, undef, sub { row_fix($_[0], $variant); }, @arg
  );
  $data{'games_first'} = $result->[0];

  #=== recent games ========================================================

  $query = q{SELECT * FROM v_games_recent WHERE name = ?};
  @arg = ($name);
  if($variant ne 'all') {
    $query .= ' AND variant = ?';
    push(@arg, $variant);
  }
  $query .= ' LIMIT 15';
  $result = sql_load(
    $query, $data{'games_count_all'}, -1,
    sub { row_fix($_[0], $variant); },
    @arg
  );
  return $result if !ref($result);
  $data{'result_recent'} = $result;
  $data{'games_last'} = $result->[0];

  #=== games by roles/all ==================================================

  $query = 'SELECT lower(role) AS role, count(*) ' .
           'FROM games LEFT JOIN logfiles USING (logfiles_i) ' .
           'WHERE scummed IS NOT TRUE AND %s GROUP BY role';
  my $where = 'name = ?';
  @arg = ($name);
  if($variant ne 'all') {
    $where .= ' AND variant = ?';
    push(@arg, $variant);
  }
  $query = sprintf($query, $where);
  $result = sql_load(
    $query, undef, undef, undef, @arg
  );
  return $result if !ref($result);
  my %roles_all;
  for my $r (@$result) {
    $roles_all{$r->{'role'}} = $r->{'count'};
  }
  $data{'result_roles_all'} = \%roles_all;

  #=== games by roles/ascended =============================================

  $query = 'SELECT lower(role) AS role, count(*) ' .
           'FROM games LEFT JOIN logfiles USING (logfiles_i) ' .
           'WHERE ascended IS TRUE AND %s GROUP BY role';
  $where = 'name = ?';
  @arg = ($name);
  if($variant ne 'all') {
    $where .= ' AND variant = ?';
    push(@arg, $variant);
  }
  $query = sprintf($query, $where);
  $result = sql_load(
    $query, undef, undef, undef, @arg
  );
  return $result if !ref($result);
  my %roles_asc;
  for my $r (@$result) {
    $roles_asc{$r->{'role'}} = $r->{'count'};
  }
  $data{'result_roles_asc'} = \%roles_asc;

  #=== games by races/all ==================================================

  $query = 'SELECT lower(race) AS race, count(*) ' .
           'FROM games LEFT JOIN logfiles USING (logfiles_i) ' .
           'WHERE scummed IS NOT TRUE AND %s GROUP BY race';
  $where = 'name = ?';
  @arg = ($name);
  if($variant ne 'all') {
    $where .= ' AND variant = ?';
    push(@arg, $variant);
  }
  $query = sprintf($query, $where);
  $result = sql_load(
    $query, undef, undef, undef, @arg
  );
  return $result if !ref($result);
  my %races_all;
  for my $r (@$result) {
    $races_all{$r->{'race'}} = $r->{'count'};
  }
  $data{'result_races_all'} = \%races_all;

  #=== games by races/ascended =============================================

  $query = 'SELECT lower(race) AS race, count(*) ' .
           'FROM games LEFT JOIN logfiles USING (logfiles_i) ' .
           'WHERE ascended IS TRUE AND %s GROUP BY race';
  $where = 'name = ?';
  @arg = ($name);
  if($variant ne 'all') {
    $where .= ' AND variant = ?';
    push(@arg, $variant);
  }
  $query = sprintf($query, $where);
  $result = sql_load(
    $query, undef, undef, undef, @arg
  );
  return $result if !ref($result);
  my %races_asc;
  for my $r (@$result) {
    $races_asc{$r->{'race'}} = $r->{'count'};
  }
  $data{'result_races_asc'} = \%races_asc;

  #=== games by alignments/all =============================================

  $query = 'SELECT lower(align) AS align, count(*) ' .
           'FROM games LEFT JOIN logfiles USING (logfiles_i) ' .
           'WHERE scummed IS NOT TRUE AND %s GROUP BY align';
  $where = 'name = ?';
  @arg = ($name);
  if($variant ne 'all') {
    $where .= ' AND variant = ?';
    push(@arg, $variant);
  }
  $query = sprintf($query, $where);
  $result = sql_load(
    $query, undef, undef, undef, @arg
  );
  return $result if !ref($result);
  my %align_all;
  for my $r (@$result) {
    $align_all{$r->{'align'}} = $r->{'count'};
  }
  $data{'result_aligns_all'} = \%align_all;

  #=== games by alignments/ascended ========================================

  $query = 'SELECT lower(align) AS align, count(*) ' .
           'FROM games LEFT JOIN logfiles USING (logfiles_i) ' .
           'WHERE ascended IS TRUE AND %s GROUP BY align';
  $where = 'name = ?';
  @arg = ($name);
  if($variant ne 'all') {
    $where .= ' AND variant = ?';
    push(@arg, $variant);
  }
  $query = sprintf($query, $where);
  $result = sql_load(
    $query, undef, undef, undef, @arg
  );
  return $result if !ref($result);
  my %align_asc;
  for my $r (@$result) {
    $align_asc{$r->{'align'}} = $r->{'count'};
  }
  $data{'result_aligns_asc'} = \%align_asc;

  #== streaks ==============================================================
  # get player's streaks; the data structure we load it in is ordered
  # array of following hashrefs:
  #
  # { 
  #   "streaks_i" : INTEGER,
  #   "open"      : BOOLEAN,
  #   "games"     : [ rowid1, ..., rowidN ]
  # }
  
  my (@streaks, $current_streak);
  $query = 
    'SELECT rowid, streaks_i, open ' .
    'FROM streaks ' .
    'JOIN logfiles USING ( logfiles_i ) ' .
    'JOIN games_set_map USING ( games_set_i ) ' .
    'JOIN games USING ( rowid ) ' .
    'WHERE %s ' .
    'ORDER BY num_games DESC, streaks_i, endtime ASC';
  $where = 'streaks.name = ?';
  @arg = ($name);
  if($variant ne 'all') {
    $where .= ' AND variant = ?';
    push(@arg, $variant);
  }
  $query = sprintf($query, $where);
  $result = sql_load(
    $query, undef, undef,
    sub {
      if(
        !ref($current_streak)
        || $current_streak->{'streaks_i'} != $_[0]->{'streaks_i'}
      ) {
        push(@streaks, $current_streak) if ref($current_streak);
        $current_streak = {
          'streaks_i' => $_[0]->{'streaks_i'},
          'open'      => $_[0]->{'open'},
          'games'     => []
        };
      }
      push(@{$current_streak->{'games'}}, $_[0]->{'rowid'});
    },
    @arg
  );
  push(@streaks, $current_streak) if ref($current_streak);
  return $result if !ref($result);
  $result = undef;

  #--- now some reprocessing for TT2
  # =1=
  # /dev/null streaks are (for now) always considered closed;
  # FIXME: This should really auto-switch after expiring
  # /dev/null tournament; let's have this fixed for /dev/null
  # =2=
  # On the player page, we display list of open (active) streaks on top,
  # this include potiential (num_games = 1) streaks as well
  # =3=
  # We make separate counts of the two streak counts: real streaks
  # (streaks.num games > 1) and open streaks (streaks.open = true)

  $data{'result_streak_cnt_open'} = 0;
  $data{'result_streak_cnt_all'} = 0;
  $data{'result_streaks'} = [];
  for(my $i = 0; $i < scalar(@streaks); $i++) {
    my $row = {};
    my $games_num = scalar(@{$streaks[$i]->{'games'}});
    my $game_first = $streaks[$i]->{'games'}[0];
    my $game_last = $streaks[$i]->{'games'}[$games_num - 1];
    @{$data{'result_streaks'}}[$i] = $row;
    $row->{'n'}          = $i + 1;
    $row->{'wins'}       = $games_num;
    $row->{'server'}     = $ascs_by_rowid{$game_first}{'server'};
    $row->{'open'}       = $streaks[$i]->{'open'};
    $row->{'open'}       = 0 if $row->{'server'} eq 'dev';
    $row->{'variant'}    = $ascs_by_rowid{$game_first}{'variant'};
    $row->{'start'}      = $ascs_by_rowid{$game_first}{'endtime'};
    $row->{'start_dump'} = $ascs_by_rowid{$game_first}{'dump'};
    $row->{'end'}        = $ascs_by_rowid{$game_last}{'endtime'};
    $row->{'end_dump'}   = $ascs_by_rowid{$game_last}{'dump'};
    $row->{'glist'}      = [];
    for my $game_rowid (@{$streaks[$i]->{'games'}}) {
      push(@{$row->{'glist'}}, $ascs_by_rowid{$game_rowid});
    }
    $data{'result_streak_cnt_open'}++ if($row->{'open'});
    $data{'result_streak_cnt_all'}++ if $games_num > 1;
  }

  #=== additional data =====================================================
  # nh_roles  -- all known roles for given variant
  # nh_races  -- all known races for given variant
  # nh_aligns -- all known aligments 
  # cur_time  -- current time (formatted)
  # name      -- player name
  # variant   -- variant (including 'all')
  # variants  -- all supported variants
  # vardef    -- contains variant full-names
  # result_*  -- various result tables/datasets

  $data{'nh_roles'} = $NetHack::nh_def->{'nh_variants'}{$variant}{'roles'};
  $data{'nh_races'} = $NetHack::nh_def->{'nh_variants'}{$variant}{'races'};
  $data{'nh_aligns'} = $NetHack::nh_def->{'nh_variants'}{$variant}{'aligns'};
  $data{'cur_time'} = scalar(localtime());
  $data{'name'} = $name;
  $data{'variant'} = $variant;
  $data{'variants'} = array_sort_by_reference(
    [ 'all', @{$NetHack::nh_def->{nh_variants_ord}} ],
    [ keys %{$player_combos->{$name}} ]
  );
  $data{'vardef'} = $NetHack::nh_def->{'nh_variants_def'};
  $data{'result_calendar'} = ascensions_calendar_view($data{'result_ascended'})
    if $data{'games_count_asc'};

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
# Generate page of top 100 streaks. The streaks are ordered by number of
# games and sum of turns in streak games (lower is better).
#
# The data structure built in memory here is following:
#
# --- this defines streak ordering and is just array of integeres - row ids
# --- into the 'streaks' table
# @streaks_ord = ( streak_i, streak_i, ..., streak_i );
#
# --- this contains all the data needed; the %ROW is one row from join
# --- query accross 'games', 'logfiles' and 'streaks' tables
# %streaks = (
#   streaks_i => {
#     'turncount' => TURNCOUNT,
#     'num_games' => NUMGAMES,
#     'games'     => [ %ROW, %ROW, ... , %ROW ]
#   },
#   ...
# )
#
#============================================================================

sub gen_page_streaks
{
  my $variant = shift;
  my @variants = ('all');
  my %data;
  my ($query, $sth, $r, @conds, @args);

  #--- init

  tty_message('Creating Streaks page (%s): ', $variant);
  push(@variants, @{$NetHack::nh_def->{nh_variants_ord}});

  #-------------------------------------------------------------------------
  #--- get ordered list of streaks with turncounts -------------------------
  #-------------------------------------------------------------------------

  # Unlike the player streak list, this is ordered by sum of streak turns,
  # this is why there are two queriest instead of one.

  #--- prepare query

  $query = 
  q{SELECT streaks_i, sum(turns) AS turns_sum, num_games, open } .
  q{FROM streaks } .
  q{JOIN logfiles USING ( logfiles_i ) } .
  q{JOIN games_set_map USING ( games_set_i ) } .
  q{JOIN games USING ( rowid ) } .
  q{WHERE %s } .
  q{GROUP BY games_set_i, num_games, streaks_i } .
  q{ORDER BY num_games DESC, turns_sum ASC LIMIT 100 };

  push(@conds, 'num_games > ?');
  push(@args, 1);

  if($variant ne 'all') {
    push(@conds, 'variant = ?');
    push(@args, $variant);
  }

  $query = sprintf($query, join(' AND ', @conds));

  #--- pull and store query result
  
  $sth = $dbh->prepare($query);
  $r = $sth->execute(@args);
  if(!$r) { return $sth->errstr(); }

  my @streaks_ord;  # ordered list of streaks_i
  my %streaks;      # streaks_i keyed hash with all info

  while(my $row = $sth->fetchrow_hashref()) {
    push(@streaks_ord, $row->{'streaks_i'});
    $streaks{$row->{'streaks_i'}} = {
      'turncount' => $row->{'turns_sum'},
      'num_games' => $row->{'num_games'},
      'open'      => $row->{'open'},
      'games'     => []
    };
  }

  tty_message('turncounts (%d lines)', scalar(@streaks_ord));

  #-------------------------------------------------------------------------
  #--- get list of streak games --------------------------------------------
  #-------------------------------------------------------------------------

  #--- prepare query
  # FIXME: this query pulls down too much data; the query above pulls down
  # first 100 streaks, but this query pulls down everything with streak length
  # 2 or more 

  @conds = (); @args = ();
  $query = 
  q{SELECT *, } .
  q{to_char(starttime,'YYYY-MM-DD HH24:MI') as starttime_fmt, } .
  q{to_char(endtime,'YYYY-MM-DD HH24:MI') as endtime_fmt } .
  q{FROM streaks } .
  q{JOIN logfiles USING ( logfiles_i ) } .
  q{JOIN games_set_map USING ( games_set_i ) } .
  q{JOIN games USING ( rowid ) } .
  q{WHERE %s };

  push(@conds, 'num_games > ?');
  push(@args, 1);

  if($variant ne 'all') {
    push(@conds, 'variant = ?');
    push(@args, $variant);
  }

  $query = sprintf($query, join(' AND ', @conds));

  #--- pull and store query result

  $sth = $dbh->prepare($query);
  $r = $sth->execute(@args);
  if(!$r) { return $sth->errstr(); }

  while(my $row = $sth->fetchrow_hashref()) {
 
    if(exists($streaks{$row->{'streaks_i'}})) {
      row_fix($row, $variant);
      push(
        @{$streaks{$row->{'streaks_i'}}{'games'}},
        $row
      );
    }
  }

  #--- reprocessing for TT2
  # see description for player streaks, format of data fed to TT2 is very
  # similar

  $data{'result'} = [];
  for(my $i = 0; $i < scalar(@streaks_ord); $i++) {
    my $streak = $streaks{$streaks_ord[$i]};
    my $games_num = scalar(@{$streak->{'games'}});
    my $game_first = $streak->{'games'}[0];
    my $game_last = $streak->{'games'}[$games_num - 1];
    @{$data{'result'}}[$i] = my $row = {};
    $row->{'n'}          = $i + 1;
    $row->{'wins'}       = $games_num;
    $row->{'server'}     = $game_first->{'server'};
    $row->{'open'}       = $streak->{'open'};
    $row->{'open'}       = 0 if $row->{'server'} eq 'dev';
    $row->{'variant'}    = $game_first->{'variant'};
    $row->{'start'}      = $game_first->{'endtime_fmt'};
    $row->{'start_dump'} = $game_first->{'dump'};
    $row->{'end'}        = $game_last->{'endtime_fmt'};
    $row->{'end_dump'}   = $game_last->{'dump'};
    $row->{'turns'}      = $streak->{'turncount'};
    $row->{'name'}       = $game_first->{'name'};
    $row->{'plrpage'}    = $game_first->{'plrpage'};
    $row->{'glist'}      = [];
    my $games_cnt = 1;
    for my $game (@{$streak->{'games'}}) {
      $game->{'n'} = $games_cnt++;
      push(@{$row->{'glist'}}, $game);
    }
  }

  #--- supply additional data

  $data{'variants'} = [ 'all', @{$NetHack::nh_def->{nh_variants_ord}} ];
  $data{'vardef'}   = $NetHack::nh_def->{'nh_variants_def'};
  $data{'variant'}  = $variant;
  $data{'cur_time'} = scalar(localtime());

  #--- process template

  $tt->process("streaks.tt", \%data, "streaks.$variant.html")
    or die $tt->error();

  #--- finish

  tty_message(", done\n");
  return undef;
}


#============================================================================
#============================================================================

sub gen_page_about
{
  my %data;

  #--- info

  tty_message('Creating About page');

  #--- pull data from db

  my $query = q{SELECT *, to_char(lastchk, 'YYYY-MM-DD HH24:MI') as lastchk_trunc FROM logfiles WHERE oper IS TRUE ORDER BY logfiles_i};
  my $result = sql_load($query);
  return $result if !ref($result);
  $data{'logfiles'} = $result;

  #--- generate page

  $data{'cur_time'} = scalar(localtime());
  $tt->process('about.tt', \%data, 'about.html')
    or die $tt->error();

  #--- finish

  tty_message(", done\n");
  return undef;
}


#============================================================================
#============================================================================

sub gen_page_front
{
  my %data;
  
  #--- info

  tty_message('Creating front page');

  #--- perform database pull

  for my $variant (@{$NetHack::nh_def->{nh_variants_ord}}) {

    #--- check if any games exist for given variant
    
    my $query = q{SELECT rowid FROM v_games_recent WHERE variant = ? LIMIT 1};
    my $sth = $dbh->prepare($query);
    my $r = $sth->execute($variant);
    if(!$r) {
      die $sth->errstr();
    }
    $sth->finish();
    next if $r == 0;
      
    #--- retrieve the last won game
    
    $query = q{SELECT * FROM v_ascended_recent WHERE variant = ? LIMIT 1};
    $sth = $dbh->prepare($query);
    $r = $sth->execute($variant);
    if(!$r) {
      die $sth->errstr();      
    } elsif($r > 0) {
      my $row = $sth->fetchrow_hashref();
      row_fix($row, $variant);
      $row->{'age'} = fmt_age(
        $row->{'age_years'}, 
        $row->{'age_months'}, 
        $row->{'age_days'}, 
        $row->{'age_hours'}
      );
      $data{'last_ascensions'}{$variant} = $row;
    } else {
      $data{'last_ascensions'}{$variant} = undef;
    }
  }

  #--- sort the results
  
  my @variants_ordered = sort {
    $data{'last_ascensions'}{$a}{'age_raw'} 
    <=> $data{'last_ascensions'}{$b}{'age_raw'}
  } keys %{$data{'last_ascensions'}};
  
  #--- generate page

  $data{'variants'} = \@variants_ordered;
  $data{'vardef'} = $NetHack::nh_def->{'nh_variants_def'};
  $data{'cur_time'} = scalar(localtime());
  $tt->process('front.tt', \%data, 'index.html')
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
#
# --dev, --nodev enable/disable processing for /dev/null/nethack tournament;
# "--dev" means forced processing of current year even if it's not November
# (this is meant for post-tournament reprocessing); "--nodev" will disable
# devnull processing no matter what; omitting the "--[no]dev" entirely will
# make for processing devnull if definition exists for current year and it
# is November.
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
  print "  --nodev        disable devnull processing\n";
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
my $cmd_devnull;

if(!GetOptions(
  'variant=s' => \@cmd_variant,
  'force'     => \$cmd_force,
  'player=s'  => \@cmd_player,
  'players!'  => \$cmd_players,
  'aggr!'     => \$cmd_aggr,
  'dev!'      => \$cmd_devnull
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

$dbh = dbconn('nhdbstats');
if(!ref($dbh)) {
  die sprintf('Failed to connect to the database (%s)', $dbh);
}
tty_message("Connected to database\n");

#--- load list of logfiles

sql_load_logfiles();
tty_message("Loaded list of logfiles\n");

#--- determine devnull processing

# do following block if not forced disable (--nodev)
if(!(defined($cmd_devnull) && !$cmd_devnull)) {
  # collect required information
  my @time = gmtime();
  my ($mo, $yr) = @time[4..5];
  $yr += 1900;
  my $def_ok =
    exists $NHdb::nhdb_def->{'devnull'}
    && exists $NHdb::nhdb_def->{'devnull'}{"$yr"};
  # enable devnull if the conditions are met
  if(
    ($mo == 10 && $def_ok && !defined($cmd_devnull))
    || ($def_ok && $cmd_devnull)
  ) {
    $devnull = $NHdb::nhdb_def->{'devnull'}{"$yr"} ;
    $devnull_path = $NHdb::nhdb_def->{'devnull'}{'http_path'};
    $devnull_path =~ s/%Y/$yr/;
  };
  if($devnull) {
    tty_message(
      "/dev/null/nethack %d processing enabled (path %s)\n", 
      $yr, $devnull_path
    );
  }
}

#--- read what is to be updated

if($cmd_aggr) {
  my $update_variants = update_schedule_variants($cmd_force, \@cmd_variant);
  tty_message(
    "Following variants scheduled to update: %s\n",
    join(',', @$update_variants)
  );

#--- generate aggregate pages

  for my $var (@$update_variants) {
    
    #--- regular stats
    gen_page_recent('recent', $var, 'recent.tt', "recent.$var.html");
    gen_page_recent('ascended', $var, 'ascended.tt', "ascended.$var.html");
    gen_page_streaks($var);

    #--- /dev/null stats
    if($devnull && $var eq 'nh') {
      gen_page_recent(
        'recent', $var, 'recent-dev.tt', 
        $devnull_path . '/recent.html', 
        $devnull
      );
      gen_page_recent(
        'ascended', $var, 'ascended-dev.tt', 
        $devnull_path . '/ascended.html', 
        $devnull
      );
    }

    #--- clear update flag
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

#--- front page

gen_page_front();

#--- about page

gen_page_about();

#--- disconnect from database

dbdone('nhdbstats');
tty_message("Disconnected from database\n");

#--- release lock file

unlink($lockfile);
tty_message("Removed lockfile\n");
