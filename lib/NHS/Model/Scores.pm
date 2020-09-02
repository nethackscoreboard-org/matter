package NHS::Model::Scores;
use Mojo::Pg;
use Mojo::JSON qw(from_json);
use File::Slurp;
use NHdb::Utils qw(nhdb_version url_substitute format_duration);
use Log::Log4perl qw(get_logger);

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
  my (
        $db,                # 0. db pointer
        $query,             # 1. database query
        $cnt_start,         # 2. counter start (opt)
        $cnt_incr,          # 3. counter increment (opt)
        $preproc,           # 4. subroutine to pre-process row
        @args               # R. arguments to db query
    )      = @_;            

  my @result;
  my $logger = get_logger('NHS');
  if (@args) {
    $logger->debug("$query -- (" . join (', ', @args) . ")");
  } else {
    $logger->debug("$query");
  }
  my $r = $db->query($query, @args);
  if(!$r->rows) { $logger->debug("query failed: ".$r->sth->errstr()); return undef }
  while(my $row = $r->hash) {
    &$preproc($row) if $preproc;
    if(defined $cnt_start) {
      $row->{'n'} = $cnt_start;
      $cnt_start += $cnt_incr;
    }
    push(@result, $row);
  }
  my $n = scalar (@result);
  $logger->debug("returned $n rows, with keys ". join ', ', keys %{$result[0]});
  return \@result;
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

  for(my $i = 0; $i < @$streaks_ord; $i++) {

    my $streak = $streaks->{$streaks_ord->[$i]};
    my $games_num = $streak->{'num_games'};
    my $game_first = $streak->{'games'}[0];
    my $game_last = $streak->{'games'}[$games_num - 1];

    $result[$i] = my $row = {};

    $row->{'n'}          = $i + 1;
    $row->{'wins'}       = $games_num;
    $row->{'server'}     = $game_first->{'server'};
    $row->{'open'}       = $streak->{'open'};
    $row->{'variant'}    = $game_first->{'variant'};
    $row->{'version'}    = nhdb_version($game_first->{'version'});
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

    # version / if the version of the first and last game are not the same
    # we display version range
    $row->{'version'}    = $game_first->{'version'};
    if($game_first->{'version'} ne $game_last->{'version'}) {
      $row->{'version'} = sprintf(
        '%s-%s', $game_first->{'version'}, $game_last->{'version'}
      );
    }

    #--- truncate time for games without endtime field

    if($game_first->{'deathdate'}) {
      $row->{'start'} =~ s/\s.*$//;
    }
    if($game_last->{'deathdate'}) {
      $row->{'end'} =~ s/\s.*$//;
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
  my ($nh, $row) = @_;
  my $logfiles_i = $row->{'logfiles_i'};
  my $logfile = $logfiles->{$logfiles_i};
  my $variant = $nh->variant($row->{'variant'});

  #--- convert realtime to human-readable form

  if($row->{'realtime'}) {
    $row->{'realtime_raw'} = defined $row->{'realtime'} ? $row->{'realtime'} : 0;
    $row->{'realtime'} = format_duration($row->{'realtime'});
  }

  #--- format version string

  $row->{'version'} = nhdb_version($row->{'version'});

  #--- include conducts in the ascended message

  if($row->{'ascended'} && defined $row->{'conduct'}) {
    my @c = $variant->conduct(@{$row}{'conduct', 'elbereths', 'achieve'});
    $row->{'ncond'} = scalar(@c);
    $row->{'tcond'} = join(' ', @c);
    if(scalar(@c) == 0) {
      $row->{'death'} = 'ascended with all conducts broken';
    } else {
      $row->{'death'} = sprintf(
        qq{ascended with %d conduct%s intact (%s)},
        scalar(@c), (scalar(@c) == 1 ? '' : 's'), $row->{'tcond'}
      );
    }
  }

  #--- game dump URL

  # special case is NAO 3.4.3 xlogfile where it seems that dumplogs became
  # available on Mar 19, 2008 (the same time where xlogfile was significantly
  # extended). To accommodate this, we will not create the 'dump' key if
  # the 'endtime' field doesn't exist in the xlogfile (signalled by
  # endtime_raw being undefined).

  if($logfile->{'dumpurl'} && $row->{'endtime_raw'}) {
    $row->{'dump'} = url_substitute(
      $logfile->{'dumpurl'},
      $row
    );
  }

  #--- realtime (aka duration)

  if(
    $row->{'variant'} eq 'ace' ||
    $row->{'variant'} eq 'nh4' ||
    $row->{'variant'} eq 'nhf' ||
    $row->{'variant'} eq 'dyn' ||
    $row->{'variant'} eq 'fh'  ||
    grep(/^bug360duration$/, @{$logfile->{'options'}})
  ) {
    $row->{'realtime'} = '';
  }

  #--- player page

  $row->{'plrpage'} = url_substitute(
    sprintf("players/%%u.%s.html", $row->{'variant'}),
    $row
  );

  #--- truncate time if needed

  if($row->{'birthdate'}) {
    $row->{'endtime_fmt'} =~ s/\s.*$//;
  }
}

# accessor to the app object
sub app {
    my $self = shift;
    return $self->{app};
}

sub pg
{
    my $self = shift;
    return $self->{pg};
}

sub db
{
    my $self = shift;
    return $self->{pg}->db;
}

sub new
{
    my ($class, $app) = @_;

    my $contents = read_file('cfg/nhdb_def.json');
    my $dbconf = from_json $contents;
    $contents = read_file($dbconf->{'auth'});
    my $auth = from_json $contents;
    my $front_end = $dbconf->{'db'}->{'nhdbstats'};

    my $dbuser = $dbconf->{'dbuser'};
    my $dbhost = $dbconf->{'dbhost'};
    my $dbname = $dbconf->{'dbname'};
    my $dbpass = $dbconf->{'auth'}->{$dbname};
    my $pg = Mojo::Pg->new("postgresql://$dbuser:$dbpass\@$dbhost/$dbname");

    my $self = {
        app => $app,
        dbconf => $dbconf,
        pg => $pg,
    };

    bless $self, $class;
    return $self;
}

# this is our main function for fetching game rows from the DB
# various wrappers are provided for simplicity, but they all
# are just nice human-readable things that call the same function
# but with slightly different flags
sub lookup_games
{
    my ($self,      # model object
        $var,       # variant or 'all'
        $name,      # player name or omitted for all players
        $n,         # limit number of entries (0 = unlimited)
        $asc,       # bool: true for ascensions, otherwise normal games
        $recent,    # bool: if true, use v_ascended/games_recent view
        $counter,
        $increment
    ) = @_;
    my (@conds, @args, $view, @games);

    if ($asc) {
        $view = 'v_ascended';
    } else {
        $view = 'v_games';
    }
    if ($recent) {
        $view .= '_recent';
    }

    my $query = "select * from $view";

    # variant filter or no?
    if ($var ne 'all') {
        push @conds, 'variant = ?';
        push @args, $var;
    }

    # optional player filter
    if ($name) {
        push @conds, 'name = ?';
        push @args, $name;
    }

    if (@conds > 0) {
        $query .= ' where ' . join(' and ', @conds);
    }

    # limit? set absolute max 500, 'nh' and 'all' are throttled to 100 elsewhere
    if ($n < 1) {
        $n = 500;
    }
    $query .= sprintf(' limit %d', $n);
    
    # get results
    # need to add error handling and logging
    my $r = $self->db->query($query, @args);
    if (!$counter) {
        $counter = 1;
    }
    if (!$increment) {
        $increment = 1;
    }
    while (my $row = $r->hash) {
        $row->{n} = $counter;
        $counter += $increment;
        row_fix($self->app->nh, $row);
        push @games, $row;
    }
    return \@games;
}

# Lookup first game
sub lookup_first_game
{
    my ($self, $var, $name) = @_;
    my $rows = $self->lookup_games($var, $name, 1, 0, 0);
    return $rows->[0];
}

# Grabs the DB row corresonding to the most recent ascension for a given variant
sub lookup_most_recent_ascension
{
    my ($self, $var) = @_;
    my $rows = $self->lookup_games($var, undef, 1, 1, 1);
    my $row = $rows->[0];
    $row->{'age'} = fmt_age(
        $row->{'age_years'},
        $row->{'age_months'},
        $row->{'age_days'},
        $row->{'age_hours'});
    return $row;
}

# Grabs recent ascensions from everyone
sub lookup_recent_ascensions
{
    my ($self, $var, $n) = @_;
    return $self->lookup_games($var, undef, $n, 1, 1);
}

# Grabs recent games
sub lookup_recent_games
{
    my ($self, $var, $n) = @_;
    return $self->lookup_games($var, undef, $n, 0, 1);
}

# Grab recent games from player
sub lookup_recent_player_games
{
    my ($self, $var, $name, $n, $count, $incr) = @_;
    return $self->lookup_games($var, $name, $n, 0, 1, $count, $incr);
}

# fetch the most recent ascension in each variant
# ordered by age, returns the list of ascensions and
# the variants ordered as they appear in the asc list
sub lookup_latest_variant_ascensions
{
    my ($self, @vars) = @_;
    my %latest_ascs;
    for my $var (@vars) {
        my $row = $self->lookup_most_recent_ascension($var);
        $latest_ascs{$var} = $row;
    }
    my @vars_ordered = sort {
        $latest_ascs{$a}{'age_raw'}
        <=> $latest_ascs{$b}{'age_raw'}
    } keys %latest_ascs;
    # need to pass these as references or they won't pack nicely in a tuple
    return \%latest_ascs, \@vars_ordered;
}

# get games or ascensions for a given player
sub lookup_player_games
{
    my ($self, $var, $name, $n) = @_;

    # this will get more complicated with implementing aliases ... NOPE
    # I stand corrected, aliases are included in the games rows
    return $self->lookup_games($var, $name, $n, 0, 1);
}

# lookup player/all or player/variant ascensions
sub lookup_player_ascensions
{
    my ($self, $var, $name) = @_;

    return $self->lookup_games($var, $name, 0, 1, 0);
}

# lookup all ascensions (for a variant)
sub lookup_all_ascensions
{
    my ($self, $var) = @_;

    return $self->lookup_games($var, undef, undef, 1, 0);
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
# 2. player name (optional)
# 3. LIMIT value
# 4. list streaks with at least this many games (no value or value of 0-1
#    means listing even potential streaks)
# 5. select only open streaks
#============================================================================

sub sql_load_streaks
{
  #--- arguments

  my (
    $self,
    $variant,         # 1. variant
    $name,            # 2. player name
    $limit,           # 3. limit the query
    $num_games,       # 4. games-in-a-streak cutoff value
    $open_only        # 5. select only open streaks
  ) = @_;

  #--- other variables

  my $logger = get_logger('NHS');
  my @streaks_ord;   # ordered list of streaks_i
  my %streaks;       # streaks_i-keyed hash with all info
  my ($query, $r, @conds, @args);

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

  if($name) {
    push(@conds, 'games.name = ?');
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

  if (@args) {
    $logger->debug("$query -- " . join(', ', @args));
  } else {
    $logger->debug($query);
  }
  $r = $self->db->query($query, @args);
  while(my $row = $r->hash) {
    push(@streaks_ord, $row->{'streaks_i'});
    $streaks{$row->{'streaks_i'}} = {
      'turncount' => $row->{'turns_sum'},
      'num_games' => $row->{'num_games'},
      'open'      => $row->{'open'},
      'games'     => []
    };
  }
  my $n = scalar (@streaks_ord);
  $logger->debug("got $n rows");

  #-------------------------------------------------------------------------
  #--- get list of streak games --------------------------------------------
  #-------------------------------------------------------------------------

  #--- prepare query
  # FIXME: this query pulls down too much data; the query above pulls down
  # first 100 streaks, but this query pulls down everything with streak length
  # 2 or more

  $query =
  q{SELECT } .

  # direct fields
  q{g.name, g.name_orig, } .
  q{role, race, gender, gender0, align, align0, server, variant, } .
  q{g.version, elbereths, scummed, conduct, achieve, dumplog, turns, hp, } .
  q{maxhp, realtime, rowid, starttime_raw, endtime_raw, g.logfiles_i, } .
  q{streaks_i, deathdate, } .

  # computed fields
  q{to_char(starttime,'YYYY-MM-DD HH24:MI') AS starttime_fmt, } .
  q{to_char(endtime,'YYYY-MM-DD HH24:MI') AS endtime_fmt, } .
  q{floor(extract(epoch from age(endtime))/86400) AS age_day } .

  # the rest of the query
  q{FROM streaks } .
  q{JOIN logfiles USING ( logfiles_i ) } .
  q{JOIN map_games_streaks USING ( streaks_i ) } .
  q{JOIN games g USING ( rowid ) } .
  q{WHERE %s } .
  q{ORDER BY endtime};

  #--- conditions
  @conds = ();
  @args = ();

  if($num_games) {
    push(@conds, 'num_games >= ?');
    push(@args, $num_games);
  }

  if($variant && $variant ne 'all') {
    push(@conds, 'variant = ?');
    push(@args, $variant);
  }

  if($name) {
    push(@conds, 'streaks.name = ?');
    push(@args, $name);
  }

  if($open_only) {
    push(@conds, 'open is true');
  }

  $query = sprintf($query, join(' AND ', @conds));

  #--- execute query

  if (@args) {
    $logger->debug("$query -- " . join(', ', @args));
  } else {
    $logger->debug($query);
  }
  $r = $self->db->query($query, @args);
  while(my $row = $r->hash) {

    if(exists($streaks{$row->{'streaks_i'}})) {
      row_fix($self->app->nh, $row);
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

# wrapper to sql_load_streaks complete with streak reprocessing for removing
# too-old streaks etc. and renumbering the list
# fetches *current* streaks for the front-page
sub lookup_current_streaks
{
    my $self = shift;
    my $streaks_proc_1;
    my $streaks_proc_2;
    my ($streaks_ord, $streaks) = $self->sql_load_streaks('all', undef, undef, 2, 1);
    if (!ref($streaks_ord)) {
        # do something with error
        return undef;
    }
    $streaks_proc_1 = process_streaks($streaks_ord, $streaks); 

    #--- streak reprocessing
    # 1. streak older than cutoff age (to prevent old streaks littering the page)
    # 2. renumber the list
    # 3. shorten the dates
  
    my $i = 1;
    for my $entry (@$streaks_proc_1) {
        if($entry->{'open'} && $entry->{'age'} < 90) {
            $entry->{'n'} = $i++;
            $entry->{'start'} =~ s/\s\d{2}:\d{2}$//;
            $entry->{'end'} =~ s/\s\d{2}:\d{2}$//;
            push(@$streaks_proc_2, $entry);
        }
    }

    return $streaks_proc_2;
}

# for the main streaks page, get up to $lim streaks, for a given variant
sub lookup_streaks
{
    my ($self, $var, $name, $lim) = @_;

    my ($streaks_ord, $streaks) = $self->sql_load_streaks($var, $name, $lim, 2, 1);
    if (!ref($streaks_ord)) {
        return undef;
    }

    return process_streaks($streaks_ord, $streaks);
}

# wrapper - if you call this one you must specify
# $self, $var, $name and $lim
sub lookup_streaks_lim
{
    return lookup_streaks(@_);
}

# for the player streaks page, get all streaks, for all or a given variant
# no limit in this case
sub lookup_player_streaks
{
    my ($self, $var, $name) = @_;
    return $self->lookup_streaks($var, $name);
}

# fetch the fastest wins
sub lookup_fastest_gametime
{
    my ($self, $var, $lim) = @_;

    my $r;
    my $logger = get_logger('NHS');
    if ($var ne 'all') {
        my $query = sprintf('select * from v_ascended where variant = ? and turns > 0 order by turns asc limit %d', $lim);
        $r = $self->db->query($query, $var);
    } else {
        my $query = sprintf('select * from v_ascended where turns > 0 order by turns asc limit %d', $lim);
        $r = $self->db->query($query);
    }
    if (!$r->rows) { $logger->debug("lookup failed: ".$r->sth->errstr()); }

    my @games;
    my $i = 1;
    while (my $row = $r->hash) {
        row_fix($self->app->nh, $row);
        $row->{n} = $i;
        $i += 1;
        push @games, $row;
    }
    return \@games;
}

# fetch the fastest wins for a player
sub lookup_player_gametime
{
    my ($self, $var, $player) = @_;

    my $r;
    if ($var ne 'all') {
        my $query = sprintf('select * from v_ascended where variant = ? and turns > 0 and name = ? order by turns asc');
        $r = $self->db->query($query, $var, $player);
    } else {
        my $query = sprintf('select * from v_ascended where turns > 0 and name = ? order by turns asc');
        $r = $self->db->query($query, $player);
    }

    my @games;
    my $i = 1;
    while (my $row = $r->hash) {
        row_fix($self->app->nh, $row);
        $row->{n} = $i;
        $i += 1;
        push @games, $row;
    }
    return \@games;
}

# lookup linked accounts
sub lookup_linked_accounts
{
    my ($self, $name) = @_;
    my $query = 'SELECT * FROM translations WHERE name_to = ?';
    return sql_load($self->db, $query, 1, 1, undef, $name);
}

# count subn turncount wins
sub count_subn_ascensions
{
    my ($self, $var, $lim) = @_;
    my @cond = ('turns > 0');
    my @args = ($lim);
    push (@cond, 'turns < ?');

    if ($var ne 'all') {
        push(@cond, 'variant = ?');
        push(@args, $var);
    }

    my $query = sprintf(
        'select name, count(*), sum(turns), round(avg(turns)) as avg ' .
        'from v_ascended ' .
        'where %s group by name order by count desc, sum asc',
        join(' and ', @cond)
    );

    return sql_load($self->db, $query, 1, 1, undef, @args);
}

# count number of games by some parameters
sub _count_games
{
    my ($db,            # database obj
        $var,           # variant
        $name,          # player name
        $scum,          # count scums bool
        $good) = @_;    # count legit (non-scum) games bool

    my $logger = get_logger('NHS');
    my @args = ($name);
    my $query = 'SELECT count(*) FROM games';
    my @conds = ('name = ?');
    if (!$scum && !$good) {
        return 0;
    } elsif ($scum && !$good) {
        push @conds, 'scummed IS TRUE';
    } elsif (!$scum && $good) {
        push @conds, 'scummed IS FALSE';
    }

    if ($var ne 'all') {
        # not actually sure what this bit does, but it's in the original code
        # *when* a variant is specified
        $query .= ' LEFT JOIN logfiles USING (logfiles_i)';
        push @conds, 'variant = ?';
        push @args, $var;
    }
    $query .= ' WHERE ' . join ' AND ', @conds;
    print $query . "\n";
    my $count = sql_load($db, $query, undef, undef, undef, @args);
    if (!ref $count) {
        $logger->warn ("sql_load failed");
        return undef;
    } else {
        return $count->[0]{count};
    }
}

# count number of games (not including startscumming)
sub count_games
{
    my ($self, $var, $name) = @_;
    return _count_games($self->db, $var, $name, 0, 1);
}

# count number of scummed games
sub count_scums
{
    my ($self, $var, $name) = @_;
    return _count_games($self->db, $var, $name, 1, 0);
}

# count all games
sub count_all_games
{
    my ($self, $var, $name) = @_;
    return _count_games($self->db, $var, $name, 1, 1);
}

# sum play duration
sub sum_play_duration
{
    my ($self, $var, $name) = @_;
    my @args = ($name);
    my $query = 'SELECT sum(realtime) FROM v_games_all WHERE name = ?';
    if ($variant ne 'all') {
        $query .= ' AND variant = ?';
        push @args, $var;
    }
    # original code only returns the query if $var is not one of:
    # nh4, ace, nhf, dyn or fh
    my $result = sql_load($self->db, $query, undef, undef, undef, @args);
    return $reuslt->[0]{sum} ? $_ : undef;
}

# enumerate games
sub enumerate_by
{
    my ($db,        # database obj 
        $var,       # which variant
        $name,      # player name
        $key,       # 'role', 'race' or 'align'
        $asc) = @_; # bool ascended

    unless ($key eq 'role' || $key eq 'race' || $key eq 'align') {
        return undef;
    }

    my $query = "SELECT lower($key) AS $key, count(*) FROM games";
    $query .= ' LEFT JOIN logfiles USING (logfiles_i)';
    my @conds;
    if ($asc) {
        push @conds, 'ascended IS TRUE';
    } else {
        push @conds, 'scummed IS FALSE';
    }
    push @conds, 'name = ?';
    my @args = ($name);
    if ($var ne 'all') {
        push @conds, 'variant = ?';
        push @args, $var;
    }
    $query .= ' WHERE ' . join ' AND ', @conds;
    $query .= " GROUP BY $key";
    print "$query\n";
    my $result = sql_load($db, $query, undef, undef, undef, @args);
    if (!ref $result) { return undef; }
    my %roles;
    for my $row (@$result) {
        $roles{$row->{$key}} = $row->{count};
    }
    return \%roles;
}

sub enumerate_games_by
{
    my ($self, $var, $name, $key) = @_;
    return enumerate_by($self->db, $var, $name, $key, 0);
}

sub enumerate_ascensions_by
{
    my ($self, $var, $name, $key) = @_;
    return enumerate_by($self->db, $var, $name, $key, 1);
}

# lookup conducty games
sub lookup_most_conducts
{
    my ($self, $var, $name) = @_;
	my $logger = get_logger('NHS');
    my ($query, @conds, @args);

    $var = $var ? $var : 'all';
    $query = 'SELECT *, bitcount(conduct) AS ncond FROM v_ascended';
    if ($var ne 'all') {
        push @conds, 'variant = ?';
        push @args, $var;
    }
    if ($name) {
        push @conds, 'name = ?';
        push @args, $name;
    }
    push @conds, 'conduct IS NOT NULL';
    push @conds, 'turns IS NOT NULL';
    $query .= ' WHERE ' . join ' AND ', @conds;
    $query .= ' ORDER BY ncond DESC, turns ASC LIMIT 100';
    # original code uses a 'sub { row_fix($_[0]) }' instead of undef,
    # for processing the code. we can't currently pass that to sql_load(),
    # however, without a way to pass row_fix the $nh object
    my $ascs = sql_load($self->db, $query, 1, 1, undef, @args);
    if (!ref($ascs)) {
        $logger->error((sprintf('conducts: Failed to query database (%s)', $ascs)));
        return undef;
    }
    # loop row_fix() afterwards instead
    foreach my $row (@$ascs) {
        row_fix($self->app->nh, $row); # NB row fix breaks conduct rankings
    }
    # re-sort
    my @ascs_sorted = sort {$$b{'ncond'} <=> $$a{'ncond'}} @$ascs;
    my $i = 1;
    foreach my $row (@ascs_sorted) {
		$row->{n} = $i;
		$i += 1;
	}
	return \@ascs_sorted;
}

# low scoring ascensions
sub lookup_lowscore_ascensions
{
    my ($self, $var, $name, $lim) = @_;
    my ($query, @conds, @args);
    my $logger = get_logger('NHS');
    $var = $var ? $var : 'all';
    $lim = $lim ? $lim : 100;
    $query = 'SELECT * FROM v_ascended WHERE ';
    push @conds, 'points > 0';
    if ($var ne 'all') {
        push @conds, 'variant = ?';
        push @args, $var;
    }
    if ($name) {
        push @conds, 'name = ?';
        push @args, $name;
    }
    $query .= join ' AND ', @conds;
    $query .= sprintf(' order BY points ASC, turns ASC LIMIT %d', $lim);
    my $ascs = sql_load($self->db, $query, 1, 1, undef, @args);
    if (!ref($ascs)) {
        $logger->error('lowscore: failed to query database (%s)', $ascs);
    }
    foreach my $row (@$ascs) {
        row_fix($self->app->nh, $row);
    }
    return $ascs;
}

sub lookup_first_to_ascend
{
    my ($self, $var) = @_;
    my $logger = get_logger('NHS');
    my $query = 'SELECT * FROM first_to_ascend(?)';
    $logger->debug("first to ascend $var");
    my $data = sql_load($self->db, $query, 1, 1, undef, $var);
    if (!ref($data)) {
        $logger->error(sprintf('first-to-ascend lookup failed: %s', $data));
        return undef;
    }
    #--- processing of the database rows
    # remove 'r_' from hash keys (field names), row_fix();
    # the r_ prefix is added because otherwise there are problem with collision
    # inside stored procedure in backend db; probably this could be done better
    foreach my $row (@$data) {
        for my $k (keys %$row) {
            $k =~/^r_(.*$)/ && do {
                $row->{$1} = $row->{$k};
                delete $row->{$k};

            };
        }
        row_fix($self->app->nh, $row);
    }
    return $data;
}

sub lookup_sources
{
    my $self = shift;
    my $logger = get_logger('NHS');
    my $result = sql_load($self->db, 'SELECT * FROM v_sources');
    if (!ref($result)) {
        $logger->error('lookup sources failed');
        return undef;
    }
    return $result;
}

#============================================================================
# Calculate zscore from list of all ascensions. This function builds the
# complete %zscore structure that is reused for all pages displaying zscore.
#============================================================================

sub compute_zscore
{
  my ($self, $name) = @_;
  #--- logging

  my $logger = get_logger('NHS');
  $logger->debug('zscore() entry');

  #--- zscore structure instantiation

  my %zscore;
  my $zscore_loaded;

  #--- just return current state if already processed

  if($zscore_loaded) {
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
  #--- get the counts
  # this creates hash with counts of (player, variant, role)
  # triples

  my %counts;
  my %variants;
  my $query = 'select * from v_ascended';
  my $ascs;
  #if ($name) {
  #    $query .= ' WHERE name = ?';
  #    $ascs = sql_load($self->db, $query, undef, undef, undef, $name);
  #} else {
      $ascs = sql_load($self->db, $query, undef, undef, undef);
  #}
  if(!ref($ascs)) {
    $logger->error('zscore() failed, ', $ascs);
    return $ascs;
  }
  $logger->debug(sprintf('zscore() data loaded from db, %d rows', scalar(@$ascs)));
  for my $row (@$ascs) {
    $counts{$row->{'name'}}{$row->{'variant'}}{lc($row->{'role'})}++;
    $variants{$row->{'variant'}} = 0;
  }

  #--- get the z-numbers
  # this calculates z-scores from the counts and stores them
  # in hash of 'val'->PLAYER->VARIANT->ROLE; key 'all' contains
  # sum of z-scores per-role and per-variant; therefore
  # PLAYER->'all'->'all' is player's multi-variant z-score;
  # PLAYER->VARIANT->'all' is player's z-score in given variant

  my $cache = {};
  my $v;
  for my $plr (keys %counts) {
    for my $var (keys %{$counts{$plr}}) {
      for my $role (keys %{$counts{$plr}{$var}}) {
        ($v, $cache) = harmonic_number($counts{$plr}{$var}{$role}, $cache);
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
  return \%zscore;
}

#============================================================================
# Calculate partial sum of harmonic series for given number.
#============================================================================

sub harmonic_number
{
    my ($n, $cache) = @_; # cache is \%

    #--- return cached result

    return $cache->{$n} if exists $cache->{$n};

    #--- calculation

    my $v = 0;
    for(my $i = 0; $i < $n; $i++) {
        $v += 1 / ($i+1);
    }
    $cache->{$n} = $v;
    return $v, $cache;
}

1;
