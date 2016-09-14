#!/usr/bin/env perl

#============================================================================
# NHDB Stat Generator
# """""""""""""""""""
# 2014 Mandevil
#============================================================================

use strict;
use warnings;
use feature 'state';
use utf8;

use DBI;
use Getopt::Long;
use NetHack;
use NHdb;
use Template;
use Log::Log4perl qw(get_logger);

$| = 1;


#============================================================================
#=== globals ================================================================
#============================================================================

my $dbh;
my $logfiles;
my $logger;              # log4perl primary instance


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
# Return current month and year
#============================================================================

sub get_month_year
{
  my @time = gmtime();
  my ($mo, $yr) = @time[4..5];
  $yr += 1900;
  return ($mo, $yr);
}


#============================================================================
# Return duration in seconds formatted as years, months, days, hours, minutes
# and seconds. Used for total time spent playing in player statistic pages.
#============================================================================

sub format_duration_plr
{
  use integer;
  my $t = shift;
  my @a;

  return undef if !$t;
  
  my $years = $t / 31536000;
  $t %= 31536000;
  my $months = $t / 2592000;
  $t %= 2592000;
  my $days = $t / 86400;
  $t %= 86400;
  my $hours = $t / 3600;
  $t %= 3600;
  my $minutes = $t / 60;
  $t %= 60;
  my $seconds = $t;

  push(@a, sprintf('%d years', $years)) if $years;
  push(@a, sprintf('%d months', $months)) if $months;
  push(@a, sprintf('%d days', $days)) if $days;
  push(@a, sprintf('%02d:%02d:%02d', $hours, $minutes, $seconds));

  return join(', ', @a);
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
  #--- arguments

  my (
    $cmd_force,    # 1. --force specified
    $cmd_variant,  # 2. list of variants from --variant
    $cmd_player    # 3. list of players from --player
  ) = @_;

  #--- other variables

  my ($sth, $r);

  #--- display information

  $logger->info('Getting list of player pages to update');
  $logger->info('Forced processing enabled') if $cmd_force;
  $logger->info('Restricted to variants: ', join(',', @$cmd_variant)) 
    if scalar(@$cmd_variant);
  $logger->info('Restricted to players: ', join(',', @$cmd_player))
    if scalar(@$cmd_player);

  #--- get list of allowed variants
  # this is either all statically-defined variants or a list
  # of variants supplied through --variant cmdline option (checked
  # against the statically-defined list).

  my @variants_final;
  my @variants_known = ('all', nh_variants());
  if(scalar(@$cmd_variant)) {
    for my $var (@$cmd_variant) {
      if(grep { $var eq $_} @variants_known) {
        push(@variants_final, $var);
      }
    }
  } else {
    @variants_final = @variants_known;
  }
  $logger->info(
    'Variants that will be processed: ',
    join(',', @variants_final)
  );

  #--- get list of all known player names

  $logger->info('Loading list of all players');
  my @player_list;
  $sth = $dbh->prepare(q{SELECT name FROM games GROUP BY name});
  $r = $sth->execute();
  if(!$r) {
    my $errmsg = sprintf('Cannot get list of players (%s)', $sth->errstr());
    $logger->error($errmsg);
    die $errmsg;
  }
  while(my ($plr) = $sth->fetchrow_array()) {
    push(@player_list, $plr);
  }
  $logger->info(sprintf('Loaded %d players', scalar(@player_list)));

  #--- get list of existing (player, variant) combinations
  #--- that have non-zero number of games in db

  $logger->info('Loading list of (player,variant) combinations');
  my %player_combos;
  my $cnt_plrcombo = 0;
  $sth = $dbh->prepare(
    q{SELECT name, variant FROM update WHERE name <> ''}
  );
  $r = $sth->execute();
  if(!$r) { 
    my $errmsg = sprintf(
      'Cannot get list of player,variant combos (%s)', $sth->errstr()
    );
    $logger->error($errmsg);
    die $errmsg; 
  }
  while(my ($plr, $var) = $sth->fetchrow_array()) {
    $player_combos{$plr}{$var} = 1;
    $cnt_plrcombo++;
  }
  $logger->info(
    sprintf('Loaded %d (player,variant) combinations', $cnt_plrcombo)
  );

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
    $logger->info(sprintf('Forcing update of %d pages', scalar(@pages_forced)));
    return(\@pages_forced, \%player_combos);
  }

  #--- get list of updated players

  $logger->info('Loading list of player updates');
  my @pages_updated;
  my $cnt = 0;
  $sth = $dbh->prepare(q{SELECT * FROM update WHERE name <> '' AND upflag IS TRUE});
  $r = $sth->execute();
  if(!$r) { 
    my $errmsg = sprintf(
      'Cannot get list of player updates (%s)', $sth->errstr()
    );
    $logger->error($errmsg);
    die $errmsg;
  }
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
  $logger->info(
    sprintf(
      'Loaded %d player updates, %d rejected',
      scalar(@pages_updated),
      $cnt - scalar(@pages_updated)
    )
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
  my $logger = get_logger('Stats::update_schedule_variants');

  $logger->debug(
    sprintf(
      q{update_schedule_variants('%s',(%s)) started},
      $cmd_force ? 'on' : 'off',
      join(',', @$cmd_variant)
    )
  );

  #--- list of allowed variants targets; anything not in this array
  #--- is invalid

  my @variants_known = ('all', nh_variants());
  $logger->debug('Known variants: (', join(',', @variants_known), ')');

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
      my $errmsg = sprintf(
        "Failed to read from update table (%s)" . $sth->errstr()
      );
      $logger->error($errmsg);
      die $errmsg;
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

  $logger->debug('update_schedule_variants() finished');
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
# Load streak information from database. The streaks are ordered by number
# of games and sum of turns in streak games (lower is better).
#
# The data structure built in memory here is following:
#
# --- this defines streak ordering and is just array of integers - row ids
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
# Arguments:
# 1. variant id, 'all' or undef
# 2. logfiles_i value, used for selecting /dev/null games
# 3. player name, this is normally the 'name' field, but when logfiles_i is
#    true, then 'name_orig' is used instead (again this is for /dev/null
#    processing)
# 4. LIMIT value
# 5. list streaks with at least this many games (no value or value of 0-1
#    means listing even potential streaks)
# 6. select only open streaks
#============================================================================

sub sql_load_streaks
{
  #--- arguments

  my (
    $variant,         # 1. variant
    $logfiles_i,      # 2. logfiles id
    $name,            # 3. player name
    $limit,           # 4. limit the query
    $num_games,       # 5. games-in-a-streak cutoff value
    $open_only        # 6. select only open streaks
  ) = @_;

  #--- other variables

  my @streaks_ord;   # ordered list of streaks_i
  my %streaks;       # streaks_i-keyed hash with all info
  my ($query, $sth, $r, @conds, @args);

  #---------------------------------------------------------------------------
  #--- get ordered list of streaks with turncounts ---------------------------
  #---------------------------------------------------------------------------

  #--- the query -> ( streaks_i, turns_sum, num_games, open )

  $query = 
  q{SELECT streaks_i, sum(turns) AS turns_sum, num_games, open } .
  q{FROM streaks } .
  q{JOIN logfiles USING ( logfiles_i ) } .
  q{JOIN map_games_streaks USING ( streaks_i ) } .
  q{JOIN games USING ( rowid ) } .
  q{WHERE %s } .
  q{GROUP BY num_games, streaks_i } .
  q{ORDER BY num_games DESC, turns_sum ASC};

  #--- conditions

  if($num_games) {
    push(@conds, 'num_games >= ?');
    push(@args, $num_games);
  }

  if($variant && $variant ne 'all') {
    push(@conds, 'variant = ?');
    push(@args, $variant);
  }

  if($logfiles_i) {
    push(@conds, 'streaks.logfiles_i = ?');
    push(@args, $logfiles_i);
  }

  if($name) {
    if($logfiles_i) {
      push(@conds, 'games.name_orig = ?');
    } else {
      push(@conds, 'games.name = ?');
    }      
    push(@args, $name);
  }

  if($open_only) {
    push(@conds, 'open is true');
  }

  #--- assemble the query

  $query = sprintf($query, join(' AND ', @conds));

  #--- append query limit

  if($limit) {
    $query .= sprintf(' LIMIT %d', $limit);
  }

  #--- execute query

  $sth = $dbh->prepare($query);
  $r = $sth->execute(@args);
  if(!$r) { return $sth->errstr(); }

  while(my $row = $sth->fetchrow_hashref()) {
    push(@streaks_ord, $row->{'streaks_i'});
    $streaks{$row->{'streaks_i'}} = {
      'turncount' => $row->{'turns_sum'},
      'num_games' => $row->{'num_games'},
      'open'      => $row->{'open'},
      'games'     => []
    };
  }

  #-------------------------------------------------------------------------
  #--- get list of streak games --------------------------------------------
  #-------------------------------------------------------------------------

  #--- prepare query
  # FIXME: this query pulls down too much data; the query above pulls down
  # first 100 streaks, but this query pulls down everything with streak length
  # 2 or more 

  $query = 
  q{SELECT *, } .
  q{to_char(starttime,'YYYY-MM-DD HH24:MI') AS starttime_fmt, } .
  q{to_char(endtime,'YYYY-MM-DD HH24:MI') AS endtime_fmt, } .
  q{floor(extract(epoch from age(endtime))/86400) AS age_day } .
  q{FROM streaks } .
  q{JOIN logfiles USING ( logfiles_i ) } .
  q{JOIN map_games_streaks USING ( streaks_i ) } .
  q{JOIN games USING ( rowid ) } .
  q{WHERE %s };

  #--- conditions
  @conds = (); 
  @args = ();

  push(@conds, 'num_games > ?');
  push(@args, 1);

  if($variant && $variant ne 'all') {
    push(@conds, 'variant = ?');
    push(@args, $variant);
  }

  if($logfiles_i) {
    push(@conds, 'streaks.logfiles_i = ?');
    push(@args, $logfiles_i);
  }

  $query = sprintf($query, join(' AND ', @conds));

  #--- execute query

  $sth = $dbh->prepare($query);
  $r = $sth->execute(@args);
  if(!$r) { return $sth->errstr(); }

  while(my $row = $sth->fetchrow_hashref()) {

    if(exists($streaks{$row->{'streaks_i'}})) {
      row_fix($row, $logfiles_i);
      push(
        @{$streaks{$row->{'streaks_i'}}{'games'}},
        $row
      );
      #--- save streak age (days from last game's endtime)
      if(exists $streaks{$row->{'streaks_i'}}{'age'}) {
        $streaks{$row->{'streaks_i'}}{'age'} = $row->{'age_day'}
        if $streaks{$row->{'streaks_i'}}{'age'} > $row->{'age_day'};
      } else {
        $streaks{$row->{'streaks_i'}}{'age'} = $row->{'age_day'};
      }
    }
  }

  #--- finish

  return (\@streaks_ord, \%streaks);
}


#============================================================================
# Function takes streak information loaded from database using
# sql_load_streaks() and creates data structure that is used by templates
# to produce final HTML.
#============================================================================

sub process_streaks
{
  #--- arguments

  my (
    $streaks_ord,   # 1. (aref) list of streak_i's
    $streaks        # 2. (href) info about streaks (key is streak_i)
  ) = @_;

  #--- other variables

  my @result;

  #--- processing

  for(my $i = 0; $i < scalar(@$streaks_ord); $i++) {
    
    my $streak = $streaks->{$streaks_ord->[$i]};
    my $games_num = scalar(@{$streak->{'games'}});
    my $game_first = $streak->{'games'}[0];
    my $game_last = $streak->{'games'}[$games_num - 1];
    
    $result[$i] = my $row = {};
    
    $row->{'n'}          = $i + 1;
    $row->{'wins'}       = $games_num;
    $row->{'server'}     = $game_first->{'server'};
    $row->{'open'}       = $streak->{'open'};
    $row->{'variant'}    = $game_first->{'variant'};
    $row->{'version'}    = $game_first->{'version'};
    $row->{'start'}      = $game_first->{'endtime_fmt'};
    $row->{'start_dump'} = $game_first->{'dump'};
    $row->{'end'}        = $game_last->{'endtime_fmt'};
    $row->{'end_dump'}   = $game_last->{'dump'};
    $row->{'turns'}      = $streak->{'turncount'};
    $row->{'name'}       = $game_first->{'name'};
    $row->{'plrpage'}    = $game_first->{'plrpage'};
    $row->{'name_orig'}  = $game_first->{'name_orig'};
    $row->{'age'}        = $streak->{'age'};
    $row->{'glist'}      = [];
    my $games_cnt = 1;
    for my $game (@{$streak->{'games'}}) {
      $game->{'n'} = $games_cnt++;
      push(@{$row->{'glist'}}, $game);
    }

  #--- close open streaks for finished /dev/null tournaments
  # note, that this relies on logfile_i to be the year of the /dev/null
  # tournament! this should probably be changed so that there's extra
  # db field for this; also this means that devnull streaks cannot
  # span multiple tournaments
  # another thing to watch out for is that some devnull streaks will
  # be marked as 'open' in the database, but this processing will
  # mark them closed

    if($row->{'server'} eq 'dev') {
      my $date_game = $game_first->{'logfiles_i'} * 100 + 10;
      my ($mo, $yr) = get_month_year();
      my $date_current = $yr * 100 + $mo;
      if($date_current > $date_game) {
        $row->{'open'} = 0;    
      }
    }
  }

  #--- return

  return \@result;
}


#============================================================================
# Some additional processing of a row of data from games table (formats
# fields into human readable format, mostly).
#============================================================================

sub row_fix
{
  my $row = shift;
  my $devnull = shift;
  my $logfiles_i = $row->{'logfiles_i'};

  #--- convert realtime to human-readable form

  $row->{'realtime_raw'} = defined $row->{'realtime'} ? $row->{'realtime'} : 0;
  $row->{'realtime'} = format_duration($row->{'realtime'});

  #--- include conducts in the ascended message

  if($row->{'ascended'}) {
    my @c = nh_conduct($row->{'conduct'}, $row->{'variant'});
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

  if($logfiles->{$logfiles_i}{'dumpurl'}) {
    
    # NetHack4 dumplogs work differently than the rest of the variants,
    # this is what ais523 has to say about it (note, that "three underscores"
    # is a mistake, there are only two):
    #
    # The dumplog filename is listed in the xlogfile, in the "dumplog"
    # field. Replace the first three underscores with colons, all spaces
    # with %20, and prepend http://nethack4.org/dumps/ to produce a filename
    # you can link to.

    if(
      $logfiles->{$logfiles_i}{'variant'} =~ /^(nh4|nhf|dyn|fh)$/
    ) {
      if($row->{'dumplog'}) {
        my $dump_path = url_substitute($logfiles->{$logfiles_i}{'dumpurl'}, $row);
        my $dump_file = $row->{'dumplog'};
        # DynaHack saves time without the colons, doesn't avoid use of spaces
        if($logfiles->{$logfiles_i}{'variant'} ne 'dyn') {
          $dump_file =~ s/(\d{2})_(\d{2})_(\d{2})/$1:$2:$3/;
          $dump_file =~ s/ /%20/g;
        }
        $row->{'dump'} = $dump_path . $dump_file;
      }
    } 

    # everything else uses URL template

    else {
      $row->{'dump'} = url_substitute(
        $logfiles->{$logfiles_i}{'dumpurl'},
        $row
      );
    }
  }

  #--- realtime (aka duration)

  if(
    $row->{'variant'} eq 'ace' ||
    $row->{'variant'} eq 'nh4' ||
    $row->{'variant'} eq 'nhf' ||
    $row->{'variant'} eq 'dyn' ||
    $row->{'variant'} eq 'fh'  ||
    ($row->{'variant'} eq 'nh' && $row->{'version'} eq '3.6.0')
  ) {
    $row->{'realtime'} = '';
  }

  #--- player page

  if($devnull) {
    $row->{'plrpage'} = url_substitute(
      sprintf("players/%%x.html", $row->{'variant'}),
      $row
    );
  } else {
    $row->{'plrpage'} = url_substitute(
      sprintf("players/%%U/%%u.%s.html", $row->{'variant'}),
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
# Calculate partial sum of harmonic series for given number.
#============================================================================

sub harmonic_number
{
  my $n = shift;
  state %cache;

  #--- return cached result

  return $cache{$n} if exists $cache{$n};

  #--- calculation

  my $v = 0;
  for(my $i = 0; $i < $n; $i++) {
    $v += 1 / ($i+1);
  }
  $cache{$n} = $v;
  return $v;
}


#============================================================================
# Calculate zscore from list of all ascensions. This function builds the 
# complete %zscore structure that is reused for all pages displaying zscore.
#============================================================================

sub zscore
{
  #--- logging

  my $logger = get_logger('Stats::zscore');
  $logger->debug('zscore() entry');

  #--- zscore structure instantiation

  state %zscore;
  state $zscore_loaded;

  #--- just return current state if already processed

  if($zscore_loaded) {
    $logger->debug('zscore() finish (cached)');
    return \%zscore;
  }

  #--- zscore structure definition
  # val ... z-score values (player->variant->role)
  # max ... maximum values (variant->role)
  # ord ... ordering of player within variant (including 'all' pseudovariant)

  my $zval = $zscore{'val'} = {};
  my $zmax = $zscore{'max'} = {};
  my $zord = $zscore{'ord'} = {};

  #--- retrieve the data from database

  my $ascs = sql_load(q{SELECT * FROM v_ascended}, 1, 1);
  if(!ref($ascs)) {
    $logger->error('zscore() failed, ', $ascs);
    return $ascs;
  }
  $logger->debug(sprintf('zscore() data loaded from db, %d rows', scalar(@$ascs)));

  #--- get the counts
  # this creates hash with counts of (player, variant, role)
  # triples

  my %counts;
  my %variants;
  for my $row (@$ascs) {
    $counts{$row->{'name'}}{$row->{'variant'}}{lc($row->{'role'})}++;
    $variants{$row->{'variant'}} = 0;
  }
  $logger->debug(
    'zscore() counts completed, variants: ', join(',', (keys %variants))
  );
  $logger->debug(
    sprintf('zscore() players found: %d', scalar(keys %counts))
  );

  #--- get the z-numbers
  # this calculates z-scores from the counts and stores them
  # in hash of 'val'->PLAYER->VARIANT->ROLE; key 'all' contains
  # sum of z-scores per-role and per-variant; therefore
  # PLAYER->'all'->'all' is player's multi-variant z-score;
  # PLAYER->VARIANT->'all' is player's z-score in given variant

  for my $plr (keys %counts) {
    for my $var (keys %{$counts{$plr}}) {
      for my $role (keys %{$counts{$plr}{$var}}) {
        my $v = harmonic_number($counts{$plr}{$var}{$role});
        $zval->{$plr}{'all'}{'all'} += $v;
        $zval->{$plr}{$var}{$role}  += $v;
        $zval->{$plr}{$var}{'all'}  += $v;
        $zval->{$plr}{'all'}{$role} += $v;
      }
    }
  }

  #--- get the max z-values per (variant, role)
  # these are stored into $zscore{'max'} subtree

  for my $plr (keys %$zval) {
    for my $var (keys %{$zval->{$plr}}) {
      next if $var eq 'all';
      for my $role (keys %{$zval->{$plr}{$var}}) {
        next if $role eq 'all';
        # per-variant per-role max values
        $zmax->{$var}{$role} = $zval->{$plr}{$var}{$role}
          if ($zmax->{$var}{$role} // 0) < $zval->{$plr}{$var}{$role};
        # per-role all-variant max values
        $zmax->{'all'}{$role} = $zval->{$plr}{$var}{$role}
          if ($zmax->{'all'}{$role} // 0) < $zval->{$plr}{$var}{$role};
      }
      # per-variant max values
      $zmax->{$var}{'all'} = $zval->{$plr}{$var}{'all'}
        if ($zmax->{$var}{'all'} // 0) < $zval->{$plr}{$var}{'all'};
    }
    # multivariant max values
    $zmax->{'all'}{'all'} = $zval->{$plr}{'all'}{'all'}
      if ($zmax->{'all'}{'all'} // 0) < $zval->{$plr}{'all'}{'all'};
  }

  #--- sorting for use by player z-score ladders

  for my $var ('all', (keys %variants)) {
    my @sorted;

    #--- sort

    @sorted = sort {
      ($zval->{$b}{$var}{'all'} // 0) 
      <=> 
      ($zval->{$a}{$var}{'all'} // 0)
    } keys (%$zval);

    #--- winnow empty entries

    for my $plr (@sorted) {
      push(@{$zord->{$var}}, $plr) if exists $zval->{$plr}{$var}{'all'};
    }
  }

  #--- finish

  $logger->debug('zscore() finish (uncached)');
  $zscore_loaded = 1;
  return \%zscore;
}


#============================================================================
#============================================================================

sub gen_page_info
{
  my ($re, $sth);
  my %data;

  $logger->info('Creating page: Generic Stats');

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
  if(!$tt->process('general.tt', \%data, 'general.html')) {
    $logger->error(q{Failed to create page 'Generic Stats', }, $tt->error());
    die $tt->error();
  }

}


#============================================================================
# Generate "Recent Games" and "Ascended Games" pages. This function is used
# for both regular and devnull pages.
#============================================================================

sub gen_page_recent
{
  #--- arguments

  my (
    $page,         # 1. "recent"|"ascended"
    $variant,      # 2. variant filter
    $template,     # 3. TT template file
    $html,         # 4. target html file
    $devnull_year  # 5. devnull year (optional)
  ) = @_;

  #--- other variables

  my @variants = ('all');
  my ($view, $sth, $r, $logfiles_i);
  my (@arg, @cond, $query_lst, $query_cnt, $result);
  my $cnt_start = 1;
  my $cnt_incr = 1;
  my %data;
  my $loghdr;

  #--- init

  $logger = get_logger('Stats::gen_page_recent');
  if($devnull_year) {
    $logfiles_i = devnull_get_logfiles_i($devnull_year);
    $loghdr = "[nh/dev/$devnull_year]";
  } else {
    $loghdr = sprintf('[%s]', $variant);
  }

  $logger->info(
    sprintf("%s Creating list of %s games", $loghdr, $page)
  );
  push(@variants, nh_variants());

  #--- select source view

  if($page eq 'recent') {
    $view = 'v_games_recent';
  } elsif($page eq 'ascended') {
    $view = 'v_ascended_recent';
  } else {
    $logger->error("Undefined page '$page' in gen_page_recent()");
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
  }

  #--- pull data from database

  $logger->debug($query_lst);
  $result = sql_load(
    $query_lst, $cnt_start, $cnt_incr,
    sub { row_fix($_[0], $logfiles_i); },
    @arg
  );
  return sprintf('Failed to query database (%s)', $result) if !ref($result);

  #--- supply additional data

  $data{'devnull'}  = $devnull_year if $devnull_year;
  $data{'result'}   = $result;
  $data{'cur_time'} = scalar(localtime());
  $data{'variants'} = [ 'all', nh_variants() ];
  $data{'vardef'}   = nh_variants(1);
  $data{'variant'}  = $variant;

  #--- process template

  $tt->process(
    $template ? $template : "$page.tt",
    \%data,
    $html ? $html : sprintf('%s.%s.html', $page, $variant)
  ) or die $tt->error();
}


#============================================================================
# Generate individual player page for a single variant (including pseudo-
# variant 'all')
#============================================================================

sub gen_page_player
{
  #--- arguments

  my (
    $name,            # 1. player name
    $variant,         # 2. variant shortcode
    $player_combos    # 3. WHAT IS THIS?
  ) = @_;

  #--- other variables

  my @variants = ('all');
  my ($query, @arg, $sth, $r);
  my %data;                         # data fed to TT2
  my $result;                       # rows from db (aref)
  my %ascs_by_rowid;                # ascensions ref'd by rowid

  #--- info

  $logger->info(sprintf('Creating page: @%s/%s', $name, $variant));

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
      row_fix($_[0]);
      $ascs_by_rowid{$_[0]{'rowid'}} = $_[0];
    },
    @arg
  );
  return $result if !ref($result);
  $data{'result_ascended'} = $result;
  $data{'games_count_asc'} = scalar(@$result);

  #=== z-score ==============================================================

  $data{'zscore'} = zscore();

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
    $query, undef, undef, sub { row_fix($_[0]); }, @arg
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
    sub { row_fix($_[0]); },
    @arg
  );
  return $result if !ref($result);
  $data{'result_recent'} = $result;
  $data{'games_last'} = $result->[0];

  #=== total play-time =====================================================

  if($variant !~ /^(nh4|ace|nhf|dyn|fh)$/) {
    $query = q{SELECT sum(realtime) FROM v_games_all WHERE name = ?};
    @arg = ($name);
    if($variant ne 'all') {
      $query .= ' AND variant = ?';
      push(@arg, $variant);
    }
    $result = sql_load($query, undef, undef, undef, @arg);
    return $result if !ref($result);
    $data{'total_duration'} = format_duration_plr($result->[0]{'sum'});
  }

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
    'JOIN map_games_streaks USING ( streaks_i ) ' .
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

  #--- if variant is 'all', list only the canonical roles/races/alignments

  my $variant2 = $variant;
  if($variant2 eq 'all') { $variant2 = 'nh'; }

  #--- the rest

  $data{'nh_roles'} = nh_char($variant2, 'roles');
  $data{'nh_races'} = nh_char($variant2, 'races');
  $data{'nh_aligns'} = nh_char($variant2, 'aligns');
  $data{'cur_time'} = scalar(localtime());
  $data{'name'} = $name;
  $data{'variant'} = $variant;
  $data{'variants'} = array_sort_by_reference(
    [ 'all', nh_variants() ],
    [ keys %{$player_combos->{$name}} ]
  );
  $data{'vardef'} = nh_variants(1);
  $data{'result_calendar'} = ascensions_calendar_view($data{'result_ascended'})
    if $data{'games_count_asc'};

  #=========================================================================

  #--- determine filename

  my $initial = substr($name, 0, 1);
  my $file = sprintf("players/%s/%s.%s.html", $initial, $name, $variant);

  #--- process template

  if(!$tt->process('player.tt', \%data, $file)) {
    $logger->error(sprintf(q{Creating page '@%s/%s' failed, }, $name, $variant));
    die $tt->error();
  }

  #--- finish

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

  $logger->info('Creating page: Streaks/', $variant);
  push(@variants, nh_variants());

  #--- load streak list

  my ($streaks_ord, $streaks) = sql_load_streaks($variant, undef, undef, 100, 2);
  return $streaks_ord if !ref($streaks_ord);

  #--- reprocessing for TT2

  $data{'result'} = process_streaks($streaks_ord, $streaks);

  #--- supply additional data

  $data{'variants'} = [ 'all', nh_variants() ];
  $data{'vardef'}   = nh_variants(1);
  $data{'variant'}  = $variant;
  $data{'cur_time'} = scalar(localtime());

  #--- process template

  if(!$tt->process(
    'streaks.tt',
    \%data, 
    "streaks.$variant.html"
  )) {
    $logger->error("Failed to create page 'Streaks/$variant'");
    die $tt->error();
  }

  #--- finish

  return undef;
}


#============================================================================
#============================================================================

sub gen_page_about
{
  my %data;

  #--- info

  $logger->info('Creating page: About');

  #--- define query fields

  my @fields = (
    q{*},
    q{to_char(lastchk, 'YYYY-MM-DD HH24:MI') AS lastchk_trunc},
    q{current_timestamp - lastchk < interval '1 hour' AS lastchk_1h},
    q{current_timestamp - lastchk < interval '1 day' AS lastchk_1d},
    q{current_timestamp - lastchk < interval '30 days' AS lastchk_30d}
  );

  #--- pull data from db

  my $query = sprintf(
    q{SELECT %s FROM logfiles ORDER BY logfiles_i},
    join(', ', @fields)
  );
  my $result = sql_load($query);
  return $result if !ref($result);
  $data{'logfiles'} = $result;

  #--- URL to local logfiles
  # if this is not undef, it will cause the template to link to local
  # logfiles from the 'size' column

  $data{'urlpath'} = $NHdb::nhdb_def->{'logs'}{'urlpath'};

  #--- generate page

  $data{'cur_time'} = scalar(localtime());
  if(!$tt->process('about.tt', \%data, 'about.html')) {
    $logger->error(q{Failed to create page 'About', }, $tt->error());
    die $tt->error();
  }

  #--- finish

  return undef;
}


#============================================================================
#============================================================================

sub gen_page_front
{
  #--- arguments

  my $devlink = shift;

  #--- other variables

  my %data;
  my @variants = nh_variants();
  my $logger = get_logger("Stats::gen_page_front");

  #--- info

  $logger->info('Creating page: Front');

  #--- perform database pull

  for my $variant (@variants) {

    #--- check if any games exist for given variant
    
    my $query = q{SELECT rowid FROM v_games_recent WHERE variant = ? LIMIT 1};
    my $sth = $dbh->prepare($query);
    my $r = $sth->execute($variant);
    if(!$r) {
      $logger->error(q{Failed to create page 'Front' (1), }, $sth->errstr());
      die $sth->errstr();
    }
    $sth->finish();
    next if $r == 0;
      
    #--- retrieve the last won game
    
    $query = q{SELECT * FROM v_ascended_recent WHERE variant = ? LIMIT 1};
    $sth = $dbh->prepare($query);
    $r = $sth->execute($variant);
    if(!$r) {
      $logger->error(q{Failed to create page 'Front' (2), }, $sth->errstr());
      die $sth->errstr();
    } elsif($r > 0) {
      my $row = $sth->fetchrow_hashref();
      row_fix($row);
      $row->{'age'} = fmt_age(
        $row->{'age_years'}, 
        $row->{'age_months'}, 
        $row->{'age_days'}, 
        $row->{'age_hours'}
      );
      $data{'last_ascensions'}{$variant} = $row;
    }
  }

  #----------------------------------------------------------------------------
  #--- retrieve currently open streaks ----------------------------------------
  #----------------------------------------------------------------------------

  my $streaks_proc_1;
  my $streaks_proc_2;
  my ($streaks_ord, $streaks) = sql_load_streaks(
    'all', undef, undef, undef, 2, 1
  );
  if(!ref($streaks_ord)) {
    $logger->error(q{Could not load streaks: }, $streaks_ord);
    die $streaks_ord;
  }
  $logger->debug(
    sprintf(q{Loaded %d streaks}, scalar(@$streaks_ord))
  );
  $streaks_proc_1 = process_streaks($streaks_ord, $streaks);

  #--- streak reprocessing
  # 1. we remove closed streaks (these can appear here because
  #    process_streaks() closes devnull streaks itself
  # 2. streak older than cutoff age (to prevent old streaks littering the page)
  # 3. renumber the list
  # 4. shorten the dates

  my $i = 1;
  for my $entry (@$streaks_proc_1) {
    if($entry->{'open'} && $entry->{'age'} < 90) {
      $entry->{'n'} = $i++;
      $entry->{'start'} =~ s/\s\d{2}:\d{2}$//;
      $entry->{'end'} =~ s/\s\d{2}:\d{2}$//;
      push(@$streaks_proc_2, $entry);
    }
  }

  #--- save the result

  $data{'streaks'} = $streaks_proc_2;
  $logger->debug(
    sprintf(
      'Removed %d closed/old streaks',
      scalar(@$streaks_proc_1) - scalar(@$streaks_proc_2)
    )
  );

  #----------------------------------------------------------------------------
  #--- retrieve recent ascensions ---------------------------------------------
  #----------------------------------------------------------------------------

  $data{'ascensions_recent'} = sql_load(
    q{SELECT * FROM v_ascended_recent LIMIT 5},
    1, 1, sub { row_fix($_[0]); }
  );

  #----------------------------------------------------------------------------

  #--- sort the results
  
  my @variants_ordered = sort {
    $data{'last_ascensions'}{$a}{'age_raw'} 
    <=> $data{'last_ascensions'}{$b}{'age_raw'}
  } keys %{$data{'last_ascensions'}};
  
  #--- generate page

  $data{'variants'} = \@variants_ordered;
  $data{'vardef'} = nh_variants(1);
  $data{'cur_time'} = scalar(localtime());
  $data{'devlink'} = 1 if $devlink;
  if(!$tt->process('front.tt', \%data, 'index.html')) {
    $logger->error(q{Failed to create page 'Front' (3), }, $tt->error());
    die $tt->error();
  }

  #--- finish

  return undef;
}


#============================================================================
# This generates table of zscores for all players
#============================================================================

sub gen_page_zscores
{
  my $variant = shift;
  state $ascs;
  my $logger = get_logger("Stats::gen_page_zscores");
  my %data;

  #--- info

  $logger->info('Creating page: Z-scores/', $variant);

  #--- calc and sort z-scores

  $data{'zscore'} = zscore();

  #--- supply additional data

  $data{'cur_time'} = scalar(localtime());
  $data{'vardef'}   = nh_variants(1);
  $data{'variants'} = [ 'all', nh_variants() ];
  $data{'variant'}  = $variant;
  $data{'nh_roles'} = [ 'all', nh_char($variant, 'roles') ];

  #--- process template

  $tt->process(
    'zscore.tt',
    \%data,
    "zscore.$variant.html"
  ) or die $tt->error();
}


#============================================================================
# Generate page of best conduct games.
#============================================================================

sub gen_page_conducts
{
  #--- arguments

  my $variant = shift;

  #--- other variables

  my ($query, @args);
  my $ascs;
  my %data;

  #--- init

  if(!$variant) { $variant = 'all'; }
  $logger->info('Creating page: Conducts/', $variant);

  #--- query database
  
  $query = q{SELECT *, bitcount(conduct) AS ncond FROM v_ascended };
  if($variant ne 'all') {
    $query .= q{WHERE variant = ? };
    push(@args, $variant);
  }
  $query .= q{ORDER BY ncond DESC, turns ASC LIMIT 100};
  $ascs = sql_load(
    $query, 1, 1, 
    sub { row_fix($_[0]) }, 
    @args
  );
  if(!ref($ascs)) {
    $logger->error(
      sprintf(
        'gen_page_conducts(): Failed to query database (%s)',
        $ascs
      )
    );
    return $ascs;
  }
  $data{'result'} = $ascs;

  #--- supply additional data

  $data{'cur_time'} = scalar(localtime());
  $data{'variants'} = [ 'all', nh_variants() ];
  $data{'vardef'}   = nh_variants(1);
  $data{'variant'}  = $variant;

  #--- process template

  $tt->process(
    'conduct.tt',
    \%data,
    "conduct.$variant.html"
  ) or die $tt->error();
}


#============================================================================
# Generate page of lowest scoring games.
#============================================================================

sub gen_page_lowscore
{
  #--- arguments

  my $variant = shift;

  #--- other variables

  my (%data, $query, @args);

  #--- init

  if(!$variant) { $variant = 'all'; }
  $logger->info('Creating page: Lowscore/', $variant);

  #--- prepare query

  $query = 'SELECT * FROM v_ascended WHERE points > 0';
  if($variant ne 'all') {
    $query .= ' AND variant = ?';
    push(@args, $variant);
  }
  $query .= ' ORDER BY points ASC, turns ASC LIMIT 100';

  #--- perform query

  $data{'result'} = sql_load($query, 1, 1, sub { row_fix($_[0]) }, @args);
  if(!ref($data{'result'})) {
    $logger->error(
      sprintf(
        'gen_page_lowscore(): Failed to query database (%s)',
        $data{'result'}
      )
    );
    return $data{'result'};
  }

  #--- supply additional data

  $data{'cur_time'} = scalar(localtime());
  $data{'variants'} = [ 'all', nh_variants() ];
  $data{'vardef'}   = nh_variants(1);
  $data{'variant'}  = $variant;

  #--- process template

  $tt->process(
    'lowscore.tt',
    \%data,
    "lowscore.$variant.html",
  ) or die $tt->error();
}


#============================================================================
# Generate ordered list of players for /dev/null.
#============================================================================

sub gen_page_dev_player_list
{
  #--- arguments

  my (
    $devnull_year,  # 1. devnull year
    $template,      # 2. TT template file
    $html           # 3. target html file
  ) = @_;

  #--- other variables

  my $query;
  my %data;
  my $result;
  my $logfiles_i = devnull_get_logfiles_i($devnull_year);

  #--- init

  $logger->info("[nh/dev/$devnull_year] Generating player list");

  #--- database query

  $query = <<'EOHD';
    SELECT
      name_orig,
      count(*) AS all,
      sum(ascended::int) AS won,
      sum((not scummed)::int) AS valid,
      sum(points) AS score,
      max(maxlvl) AS maxlvl,
      max(case when ascended then bitcount(conduct) else 0 end) AS ncond
    FROM v_games_all
    WHERE logfiles_i = ?
    GROUP BY name_orig
    ORDER BY won DESC, "all" ASC
EOHD

  $result = sql_load($query, 1, 1, undef, $logfiles_i);
  return $result if !ref($result);
  $data{'result'} = $result;

  #--- supply additional data

  $data{'cur_time'} = scalar(localtime());

  #--- process template

  if(!$tt->process($template, \%data, $html)) {
    $logger->error(qq{[nh/dev/$devnull_year] Failed to create page 'Player List (devnull)'});
    die $tt->error();
  }
}


#============================================================================
# Generate per-player pages for /dev/null.
#============================================================================

sub gen_page_dev_player
{
  #--- arguments

  my (
    $devnull_year,   # 1. devnull year
    $template,       # 2. TT template file
  ) = @_;

  #--- other variables

  my $dbh = dbconn('nhdbstats');
  my $query;
  my $query_asc;
  my $query_all;
  my @plr;
  my $logfiles_i = devnull_get_logfiles_i($devnull_year);
  my $devnull_path = devnull_get_url_path($devnull_year);

  #--- init

  $logger->info("[nh/dev/$devnull_year] Generating player pages");

  #--- first get list of players

  die "Cannot connect to database\n" if !ref($dbh);
  $query = 'SELECT name_orig FROM games WHERE logfiles_i = ? GROUP BY name_orig';
  my $sth = $dbh->prepare($query);
  my $r = $sth->execute($logfiles_i);
  while(my ($p) = $sth->fetchrow_array()) {
    push(@plr, $p)
  }

  #--- database queries

  $query_asc = 
    'SELECT * FROM v_ascended ' .
    'WHERE logfiles_i = ? AND name_orig = ?';
  $query_all =
    'SELECT * FROM v_games ' .
    'WHERE logfiles_i = ? AND name_orig = ?';

  #--- iterate over the list of names ----------------------------------------

  for my $p (@plr) {
    my $result;
    my %data;

  #--- perform queries

    $result = sql_load(
      $query_asc, 1, 1, 
      sub { row_fix($_[0], $logfiles_i); },
      $logfiles_i, $p
    );
    return $result if !ref($result);
    $data{'result_asc'} = [ reverse(@$result) ];
    $result = sql_load(
      $query_all, 1, 1,
      sub { row_fix($_[0], $logfiles_i); },
      $logfiles_i, $p
    );
    return $result if !ref($result);
    $data{'result_all'} = [ reverse(@$result) ];

  #--- load streaks

    my ($streaks_ord, $streaks) = sql_load_streaks(
      undef, $logfiles_i, $p, undef, 2
    );
    return $streaks_ord if !ref($streaks_ord);
    $data{'result_streaks'} = process_streaks($streaks_ord, $streaks);

  #--- supply additional data

    $data{'devnull'} = $devnull_year;
    $data{'name'} = $p;
    $data{'cur_time'} = scalar(localtime());

  #--- process template

    if(!$tt->process($template, \%data, "$devnull_path/players/" . $p . '.html')) {
      $logger->error(
        "[nh/dev/$devnull_year] Failed to create page ",
        "$devnull_path/players/$p.html"
      );
      die $tt->error();
    }

  #--- end of loop -----------------------------------------------------------

  }
}


#============================================================================
# Generate /dev/null Roles page, that is page where ascensions are grouped
# by their role. This function includes redundant load of database data
# (already loaded once by gen_page_recent()); this should be optimized.
#============================================================================

sub gen_page_dev_roles
{
  #--- arguments

  my (
    $devnull_year
  ) = @_;

  #--- other variables

  my $query;
  my $result;
  my %data;
  my $logfiles_i = devnull_get_logfiles_i($devnull_year);
  my $devnull_path = devnull_get_url_path($devnull_year);

  #--- init

  $logger->info("[nh/dev/$devnull_year] Generating roles page");

  #--- database query

  $query = 
    q{SELECT * FROM v_ascended WHERE logfiles_i = ? } .
    q{ORDER BY role, endtime_raw ASC};

  $result = sql_load(
    $query, undef, undef,
    sub { row_fix($_[0], $logfiles_i); },
    $logfiles_i
  );
  return $result if !ref($result);

  #--- reprocessing

  my $cnt;
  my $role = '';
  for my $row (@$result) {
    if($role ne $row->{'role'}) {
      $role = $row->{'role'};
      $cnt = 1;
    }
    push(@{$data{'result'}{lc($role)}}, $row);
    $row->{'n'} = $cnt++;
  }

  #--- supply additional data

  $data{'devnull'} = $devnull_year;
  $data{'cur_time'} = scalar(localtime());

  #--- process template

  if(!$tt->process('roles-dev.tt', \%data, $devnull_path . '/roles.html')) {
    $logger->error("[nh/dev/$devnull_year] Failed to create page 'Roles'");
    die $tt->error();
  }

}


#============================================================================
# Generate /dev/null front page.
#============================================================================

sub gen_page_dev_front
{
  #--- arguments

  my (
    $devnull_year
  ) = @_;

  #--- other variables

  my %data;
  my $query;
  my $result;
  my $logfiles_i = devnull_get_logfiles_i($devnull_year);
  my $devnull_path = devnull_get_url_path($devnull_year);

  #--- init

  $logger->info("[nh/dev/$devnull_year] Generating front page");

  #---------------------------------------------------------------------------
  #--- "Best Players" --------------------------------------------------------
  #---------------------------------------------------------------------------

  $query = <<'EOHD';
    SELECT
      name_orig,
      count(*) AS all,
      sum(ascended::int) AS won,
      sum(points) AS score,
      max(case when ascended then bitcount(conduct) else 0 end) AS ncond
    FROM v_games_all
    WHERE logfiles_i = ?
    GROUP BY name_orig
    HAVING sum(ascended::int) > 0
    ORDER BY won DESC, "all" ASC
    LIMIT 5
EOHD
  
  $result = sql_load($query, 1, 1, undef, $logfiles_i);
  return $result if !ref($result);
  $data{'result_best_plr'} = $result;

  #---------------------------------------------------------------------------
  #--- "Recent Ascensions" ---------------------------------------------------
  #---------------------------------------------------------------------------

  #--- first get total number of ascensions

  $query = 'SELECT count(*) FROM v_ascended WHERE logfiles_i = ?';
  $result = sql_load($query, undef, undef, undef, $logfiles_i);
  return $result if !ref($result);
  $data{'result_total_ascended'} = $result->[0]{'count'};

  #--- now get the last 5 ascensions

  $query = <<'EOHD';
    SELECT *
    FROM v_ascended_recent
    WHERE logfiles_i = ?
    LIMIT 5
EOHD

  $result = sql_load(
    $query, 
    $result->[0]{'count'}, -1, 
    sub { row_fix($_[0], $logfiles_i); },
    $logfiles_i
  );
  return $result if !ref($result);
  $data{'result_recent_wins'} = $result;

  #---------------------------------------------------------------------------
  #-- "Fastest Games By Game Time" -------------------------------------------
  #---------------------------------------------------------------------------

  $query = <<'EOHD';
    SELECT *
    FROM v_ascended
    WHERE logfiles_i = ?
    ORDER BY turns ASC
    LIMIT 5
EOHD

  $result = sql_load(
    $query, 1, 1, 
    sub { row_fix($_[0], $logfiles_i); }, 
    $logfiles_i
  );
  return $result if !ref($result);
  $data{'result_top5_turns'} = $result;
  
  #---------------------------------------------------------------------------
  #-- "Fastest Games By Real Time" -------------------------------------------
  #---------------------------------------------------------------------------

  $query = <<'EOHD';
    SELECT *
    FROM v_ascended
    WHERE logfiles_i = ?
    ORDER BY realtime ASC
    LIMIT 5
EOHD

  $result = sql_load(
    $query, 1, 1, 
    sub { row_fix($_[0], $logfiles_i); },
    $logfiles_i
  );
  return $result if !ref($result);
  $data{'result_top5_rt'} = $result;

  #---------------------------------------------------------------------------
  #-- "Best Conduct Games" ---------------------------------------------------
  #---------------------------------------------------------------------------

  $query = <<'EOHD';
    SELECT *
    FROM v_ascended
    WHERE logfiles_i = ?
    ORDER BY bitcount(conduct) DESC, turns ASC
    LIMIT 5
EOHD

  $result = sql_load(
    $query, 1, 1,
    sub { row_fix($_[0], $logfiles_i); },
    $logfiles_i
  );
  return $result if !ref($result);
  $data{'result_top5_conduct'} = $result;

  #---------------------------------------------------------------------------
  #-- "Low Scored Games" -----------------------------------------------------
  #---------------------------------------------------------------------------

  $query = <<'EOHD';
    SELECT *
    FROM v_ascended
    WHERE logfiles_i = ?
    ORDER BY points ASC, turns ASC
    LIMIT 5
EOHD

  $result = sql_load(
    $query, 1, 1,
    sub { row_fix($_[0], $logfiles_i); },
    $logfiles_i
  );
  return $result if !ref($result);
  $data{'result_top5_lowscore'} = $result;

  #---------------------------------------------------------------------------
  #-- "Streaks" --------------------------------------------------------------
  #---------------------------------------------------------------------------

  my ($streaks_ord, $streaks) = sql_load_streaks(undef, $logfiles_i, undef, undef, 2);
  return $streaks_ord if !ref($streaks_ord);
  $data{'result_streaks'} = process_streaks($streaks_ord, $streaks);

  #---------------------------------------------------------------------------
  #-- "General Info" ---------------------------------------------------------
  #---------------------------------------------------------------------------

  $query = 'SELECT count(*) FROM games WHERE logfiles_i = ?';
  $result = sql_load($query, undef, undef, undef, $logfiles_i);
  die if !ref($result);
  $data{'result_total_games'} = $result->[0]{'count'};

  $query = 'SELECT count(*) FROM games WHERE logfiles_i = ? AND scummed IS NOT TRUE';
  $result = sql_load($query, undef, undef, undef, $logfiles_i);
  die if !ref($result);
  $data{'result_total_valid'} = $result->[0]{'count'};

  #---------------------------------------------------------------------------
  #---------------------------------------------------------------------------
  #---------------------------------------------------------------------------

  #--- supply additional data

  $data{'devnull'} = $devnull_year;
  $data{'cur_time'} = scalar(localtime());

  #--- process template

  if(!$tt->process('front-dev.tt', \%data, $devnull_path . '/index.html')) {
    $logger->error("Failed to create page 'Front (devnull)", $tt->error());
    die $tt->error();
  }
}


#============================================================================
# Generate Combos table for /dev/null
#============================================================================

sub gen_page_dev_combos
{
  #--- arguments

  my (
    $devnull_year
  ) = @_;

  #--- other variables

  my $query;
  my %data;
  my $logfiles_i = devnull_get_logfiles_i($devnull_year);
  my $devnull_path = devnull_get_url_path($devnull_year);

  #--- init

  $logger->info("[nh/dev/$devnull_year] Generating combos page");

  #--- query

  $query = <<'EOHD';
    SELECT * FROM games WHERE logfiles_i = ? AND scummed IS FALSE
EOHD
  my $result = sql_load($query, undef, undef, undef , $logfiles_i);
  return $result if !ref($result);

  #--- reprocessing

  my (%played_race, %won_race);
  my (%played_role, %won_role);
  my (%played_combo, %won_combo);
  my (%played_align, %won_align);
  my %combo;

  for my $row (@$result) {
    no warnings;
    if($row->{'ascended'}) {
      $won_race{$row->{'race'}}++;
      $won_role{$row->{'role'}}++;
      $won_align{$row->{'race'}}{$row->{'align0'}}++;
      $combo{$row->{'role'}}{$row->{'race'}}{$row->{'align0'}}{'won'}++;
    }
    $played_race{$row->{'race'}}++;
    $played_role{$row->{'role'}}++;
    $played_align{$row->{'race'}}{$row->{'align0'}}++;
    $combo{$row->{'role'}}{$row->{'race'}}{$row->{'align0'}}{'pld'}++;
  }

  $data{'p_race'} = \%played_race;
  $data{'p_role'} = \%played_role;
  $data{'p_align'} = \%played_align;
  $data{'w_race'} = \%won_race;
  $data{'w_role'} = \%won_role;
  $data{'w_align'} = \%won_align;
  $data{'combo'} = \%combo;

  #--- supply additional data

  $data{'devnull'} = $devnull_year if $devnull_year;
  $data{'cur_time'} = scalar(localtime());

  #--- process template

  if(!$tt->process('combos-dev.tt', \%data,  $devnull_path . '/combos.html')) {
    $logger->error(q{Failed to create page 'Combos (devnull)'}, $tt->error());
    die $tt->error();
  }
}


#============================================================================
# This page lists first ascensions for all combos and related information
# like unascended combos etc.
#============================================================================

sub gen_page_first_to_ascend
{
  #--- arguments

  my (
    $variant
  ) = @_;

  #--- other variables

  my (
    $ct,
    %data,
    $process,
    $query,
    $re
  );

  #--- processing of the database rows

  # remove 'r_' from hash keys (field names), row_fix();
  # the r_ prefix is added because otherwise there are problem with collsion
  # insde stored procedure in backend db; probably this could be done better

  $process = sub {
    my $row = shift;
    for my $k (keys %$row) {
      $k =~ /^r_(.*)$/ && do {
        $row->{$1} = $row->{$k};
        delete $row->{$k};
      };
    }
    row_fix($row);
  };

  #--- init

  $logger->info('Creating page: First-to-ascend/', $variant);

  #--- initialize combo table

  $ct = nh_combo_table_init($variant);
  $data{'table'} = $ct->{'table'};

  $data{'roles'} = nh_char($variant, 'roles');
  $data{'races'} = nh_char($variant, 'races');
  $data{'genders'} = nh_char($variant, 'genders');
  $data{'aligns'} = nh_char($variant, 'aligns');

  $data{'roles_def'} = $NetHack::nh_def->{'nh_roles_def'};
  $data{'races_def'} = $NetHack::nh_def->{'nh_races_def'};

  #--- query database

  $query = 'SELECT * FROM first_to_ascend(?)';
  $re = sql_load($query, 1, 1, $process, $variant);
  $data{'result'} = $re;

  #--- process the data

  for(my $i = 0; $i < scalar(@$re); $i++) {
    my $row = $re->[$i];

    #--- add the entries to combo table

    nh_combo_table_cell(
      $ct, $row->{'role'}, $row->{'race'}, $row->{'align'}, $row->{'name'}
    );
  }

  #--- unascended combos, combos by player

  $data{'unascend'} = [];
  $data{'byplayer'} = {};
  nh_combo_table_iterate($ct, sub {
    my ($val, $role, $race, $align) = @_;

    # unascended combos
    if(!defined($val)) {
      push(
        @{$data{'unascend'}},
        sprintf('%s-%s-%s', ucfirst($role), ucfirst($race), ucfirst($align))
      );
    }

    # combos by users
    if($val && $val ne '-1') {
      if(!exists $data{'byplayer'}{$val}) {
        $data{'byplayer'}{$val}{'cnt'} = 0;
        $data{'byplayer'}{$val}{'games'} = [];
      }
      $data{'byplayer'}{$val}{'cnt'}++;
      push(
        @{$data{'byplayer'}{$val}{'games'}},
        sprintf('%s-%s-%s', ucfirst($role), ucfirst($race), ucfirst($align))
      );
    }
  });

  #--- create sorted index for 'byplayer'

  # ordering by number of games (in 'cnt' key), in case of ties
  # we want to use the original order from database query

  $data{'byplayer_ord'} = [ sort {
    if($data{'byplayer'}{$b}{'cnt'} != $data{'byplayer'}{$a}{'cnt'}) {
      $data{'byplayer'}{$b}{'cnt'} <=> $data{'byplayer'}{$a}{'cnt'}
    } else {
      my ($plr_a) = grep { $_->{'name'} eq $a } @$re;
      my ($plr_b) = grep { $_->{'name'} eq $b } @$re;
      $plr_a->{'n'} <=> $plr_b->{'n'};
    }
  } keys %{$data{'byplayer'}} ];

  #--- auxiliary data

  $data{'variant'}  = $variant;
  $data{'cur_time'} = scalar(localtime());
  $data{'variants'} = $NHdb::nhdb_def->{'firsttoascend'};
  $data{'vardef'}   = nh_variants(1);
  $data{'variant'}  = $variant;

  #--- render template

  if(!$tt->process('firstasc.tt', \%data, "firstasc.$variant.html")) {
    $logger->error(q{Failed to render page firstasc.tt'}, $tt->error());
    die $tt->error();
  }
}


#============================================================================
# Generate Fastest Game-time page.
#============================================================================

sub gen_page_gametime
{
  #--- arguments

  my $variant = shift;
  if(!$variant) { $variant = 'all'; }

  #--- other variables

  my %data;

  #--- init

  $logger->info('Creating page: Game-time/', $variant);

  #----------------------------------------------------------------------------
  #--- top 100 lowest turncount games -----------------------------------------
  #----------------------------------------------------------------------------

  {
    my $qry;
    my @cond = ('turns > 0');
    my @arg;

    if($variant ne 'all') {
      push(@cond, 'variant = ?');
      push(@arg, $variant);
    }
    $qry = sprintf(
      'SELECT * FROM v_ascended WHERE %s ORDER BY turns ASC LIMIT 100',
      join(' AND ', @cond)
    );

    $data{'result'} = sql_load($qry, 1, 1, sub { row_fix($_[0]) }, @arg);
  }

  #----------------------------------------------------------------------------
  #--- per-player counts for sub-N turns games --------------------------------
  #----------------------------------------------------------------------------

  my $sub_games = sub {

    my $turns = shift;
    my $qry;
    my @cond = ('turns > 0');
    my @arg;
    my $re;

    push(@cond, 'turns < ?');
    push(@arg, $turns);

    if($variant ne 'all') {
      push(@cond, 'variant = ?');
      push(@arg, $variant);
    }

    $qry = sprintf(
      'SELECT name, count(*), sum(turns), round(avg(turns)) as avg ' .
      'FROM v_ascended ' .
      'WHERE %s GROUP BY name ORDER BY count DESC, sum ASC',
      join(' AND ', @cond)
    );

    return sql_load($qry, 1, 1, undef, @arg);
  };

  $data{'sub20'} = &$sub_games(20000);
  $data{'sub10'} = &$sub_games(10000);
  $data{'sub5'} = &$sub_games(5000);

  #--- auxiliary data

  $data{'variant'}  = $variant;
  $data{'cur_time'} = scalar(localtime());
  $data{'variants'} = [ 'all', nh_variants() ];
  $data{'vardef'}   = nh_variants(1);
  $data{'variant'}  = $variant;

  #--- render template

  if(!$tt->process('gametime.tt', \%data, "gametime.$variant.html")) {
    $logger->error(q{Failed to render page gametime.tt'}, $tt->error());
    die $tt->error();
  }
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
  print "  --player=NAME  update only given player\n";
  print "  --noplayers    disable generating player pages\n";
  print "  --noaggr       disable generating aggregate pages\n";
  print "  --nodev        disable devnull processing\n";
  print "  --year=YEAR    generate stats for devnull year\n";
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

#--- initialize logging

Log::Log4perl->init('cfg/logging.conf');
$logger = get_logger('Stats');

#--- title

$logger->info('NetHack Scoreboard / Stats');
$logger->info('(c) 2013-15 Borek Lupomesky');
$logger->info('---');

#--- process command-line

my $logger_cmd = get_logger("Stats::Cmdline");

my @cmd_variant;
my $cmd_force = 0;
my @cmd_player;
my $cmd_players = 1;
my $cmd_aggr = 1;
my $cmd_devnull;
my @cmd_dev_year;

if(!GetOptions(
  'variant=s' => \@cmd_variant,
  'force'     => \$cmd_force,
  'player=s'  => \@cmd_player,
  'players!'  => \$cmd_players,
  'aggr!'     => \$cmd_aggr,
  'dev!'      => \$cmd_devnull,     # three-state option (undefined/0/1)
  'year=s'    => \@cmd_dev_year
)) {
  help();
  exit(1);
}

# expand textual lists into actual perl arrays; this allows to specify lists
# on commandline in the form --option=EL1,EL2,EL3,..,ELn which is more
# convenient than --option EL1 --option EL2 --option EL3 etc.

cmd_option_array_expand(
  \@cmd_variant,
  \@cmd_player,
  \@cmd_dev_year
);

# debugging log of command-lines options as we parsed them

$logger_cmd->debug('cmd_variant = (', join(',', @cmd_variant), ')');
$logger_cmd->debug('cmd_force = ', cmd_option_state($cmd_force));
$logger_cmd->debug('cmd_players = ', cmd_option_state($cmd_players));
$logger_cmd->debug('cmd_player = (', join(',', @cmd_player), ')');
$logger_cmd->debug('cmd_aggr = ', $cmd_aggr ? 'on' : 'off');
$logger_cmd->debug('cmd_devnull = ', cmd_option_state($cmd_devnull));
$logger_cmd->debug('---');

#--- lock file check/open

if(-f $lockfile) {
  $logger->warn('Another instance running');
  die "Another instance running\n";
  exit(1);
}
open(F, "> $lockfile") || do {
  $logger->error("Cannot open lock file $lockfile");
  die "Cannot open lock file $lockfile\n";
};
print F $$, "\n";
close(F);
$logger->info('Created lockfile');

#--- connect to database

$dbh = dbconn('nhdbstats');
if(!ref($dbh)) {
  $logger->error("Failed to connect to the database ($dbh)");
  die "Failed to connect to the database ($dbh)";
}
$logger->info('Connected to database');

#--- load list of logfiles

sql_load_logfiles();
$logger->info('Loaded list of logfiles');

#-------------------------------------------------------------------------------
#--- determine devnull processing ----------------------------------------------
#-------------------------------------------------------------------------------

# /dev/null/nethack is a tournament run on dedicated servers every November;
# NHS has special code to generate devnull statistics to augment official web
# scoreboard. Devnull processing (that is generating devnull-specific pages)
# will be initiated automatically if it is November; this can be overriden using
# --nodev option; additionally, there's an option to regenerate stats for
# particular devnull year using --dev --year=YYYY Note, that devnull years must
# be defined in config file for this to work. Another requirement that devnull's
# logfile_i in logfiles table must be equal to the year number.

#--- this will contain list of years to process

my @dev_years;

#--- only do something if not blocked by --nodev

if(!defined($cmd_devnull) || $cmd_devnull) {

#--- some basic preparation

  my ($mo, $yr) = get_month_year();
  my $logger = get_logger("Stats::Devnull");
  $logger->debug('[nh/dev] Determining devnull processing');
  $logger->debug(sprintf('[nh/dev] Current date is %d/%d', $mo+1, $yr));

#--- year to process is specified on the command-line

  if($cmd_devnull && @cmd_dev_year) {
    if($cmd_dev_year[0] eq 'all') {
      @dev_years = sort keys $NHdb::nhdb_def->{'devnull'}{'years'};
    } else {
      @dev_years = sort @cmd_dev_year;
    }
  }

#--- year to process not specified, so is it November yet?

  else {
    @dev_years = ($yr) if $mo == 10;
  }

#--- remove undefined years

  {
    my @temp;
    for my $y (@dev_years) {
      if(
        exists $NHdb::nhdb_def->{'devnull'}
        && exists $NHdb::nhdb_def->{'devnull'}{'years'}{$y}
      ) {
        push(@temp, $y);
      }
    }
    @dev_years = @temp;
  }

#--- log some info

  if(@dev_years) {
    $logger->info(
      sprintf(
       '[nh/dev] Devnull processing enabled for %s',
       join(',', @dev_years)
      )
    );
  } else {
    $logger->debug('[nh/dev] Devnull processing inactive');
  }
}

#-------------------------------------------------------------------------------
#--- non-devnull processing ----------------------------------------------------
#-------------------------------------------------------------------------------

#--- The --years argument completely disables regular processing

if(!@dev_years) {

#--- read what is to be updated

  if($cmd_aggr) {
    my $update_variants = update_schedule_variants($cmd_force, \@cmd_variant);
    $logger->info(
      'Following variants scheduled to update: ',
      join(',', @$update_variants)
    );

#--- generate aggregate pages

    for my $var (@$update_variants) {

      #--- regular stats
      gen_page_recent('recent', $var);
      gen_page_recent('ascended', $var);
      gen_page_streaks($var);
      gen_page_zscores($var);
      gen_page_conducts($var);
      gen_page_lowscore($var);
      gen_page_gametime($var);

      #--- first to ascend page
      if(grep(/^$var$/, @{$NHdb::nhdb_def->{'firsttoascend'}})) {
        gen_page_first_to_ascend($var);
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
#--- front page

  gen_page_front() if $cmd_aggr;

#--- about page

  gen_page_about() if $cmd_aggr;

}

#-------------------------------------------------------------------------------
#--- generate devnull pages ----------------------------------------------------
#-------------------------------------------------------------------------------

for my $devnull_year (sort @dev_years) {

  #--- initialize

  my $devnull_path = devnull_get_url_path($devnull_year);
  if(!$devnull_path) {
    $logger->fatal(
      "[nh/dev] devnull/http_path not defined in nhdb_def.cfg for year "
      . "$devnull_year, aborting"
    );
    die 'Configuration error';
  }
  $logger->info("[nh/dev/$devnull_year] Processing devnull year $devnull_year");
  $logger->debug("[nh/dev/$devnull_year] Devnull http path is $devnull_path");

  #--- generate /dev/null ascended/recent pages

  if($cmd_aggr) {
    gen_page_recent(
      'recent', 'nh', 'recent-dev.tt',
      $devnull_path . '/recent.html',
      $devnull_year
    );
    gen_page_recent(
      'ascended', 'nh', 'ascended-dev.tt',
      $devnull_path . '/ascended.html',
      $devnull_year
    );
  }

  #--- generate /dev/null player list

  gen_page_dev_player_list(
    $devnull_year, 'playerlist-dev.tt',
    $devnull_path . '/players.html'
  );

  #--- generate /dev/null per-player pages
  # at this moment, all player pages are updated every time

  gen_page_dev_player($devnull_year, 'player-dev.tt') if $cmd_players;

  #--- generate /dev/null roles page

  gen_page_dev_roles($devnull_year) if $cmd_aggr;

  #--- generate /dev/null combos page

  gen_page_dev_combos($devnull_year) if $cmd_aggr;

  #--- generate /dev/null front page

  if($cmd_aggr) {
    gen_page_dev_front($devnull_year);
  }

}

#--- disconnect from database

dbdone('nhdbstats');
$logger->info('Disconnected from database');

#--- release lock file

unlink($lockfile);
$logger->info('Removed lockfile');
