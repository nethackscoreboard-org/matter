package NetHackStats::Model::DB;
use Mojo::Pg;
use Mojo::JSON qw(from_json);
use File::Slurp;
use NHdb::Utils qw(nhdb_version url_substitute format_duration);

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
    sprintf("players/%%U/%%u.%s.html", $row->{'variant'}),
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

    my $contents = read_file('cfg/nethackstats.json');
    my $dbconf = from_json $contents;

    my $dbuser = $dbconf->{'dbuser'};
    my $dbhost = $dbconf->{'dbhost'};
    my $dbpass = $dbconf->{'dbpass'};
    my $dbname = $dbconf->{'dbname'};
    my $pg = Mojo::Pg->new("postgresql://$dbuser:$dbpass\@$dbhost/$dbname");

    my $self = {
        app => $app,
        dbconf => $dbconf,
        pg => $pg,
    };

    bless $self, $class;
    return $self;
}

#sub recent_asc_exists
#{
#    my ($self, $var) = @_;
#
#    my $r = $self->db->query('select rowid from v_ascended_recent where variant = ? limit 1', $var);
#    if (!$r) {
#        # do something about error
#    }
#    if ($r > 0) {
#        return $r->array->[0]; # return rowid
#    } else {
#        return 0;
#    }
#}
#
#sub get_recent_asc_by_row
#{
#    my ($self, $rowid) = @_;
#
#    my $r = $self->db->query('select * from v_ascended_recent where rowid = ? limit 1', $rowid);
#    if (!$r) {
#        # do something about error
#    }
#    my $row = $r->hash;
#    row_fix($self->app->nh, $row);
#    $row->{'age'} = fmt_age(
#        $row->{'age_years'},
#        $row->{'age_months'},
#        $row->{'age_days'},
#        $row->{'age_hours'});
#    return $row;
#}

sub _get_recent_games
{
    my ($self, $var, $n, $asc) = @_;
    my (@args, $view, @games);

    # won or died?
    if ($asc == 1) {
        $view = 'v_ascended_recent';
    } else {
        $view = 'v_games_recent';
    }

    my $q_string = "select * from $view ";

    # variant filter or no?
    if ($var ne 'all') {
        $q_string .= 'where variant = ? ';
        push @args, $var;
    }

    # limit? set absolute max 500, 'nh' and 'all' are throttled to 100 elsewhere
    if ($n < 1) {
        $n = 500;
    }
    $q_string .= sprintf('limit %d', $n);
    
    # get results
    # need to add error handling and logging
    $r = $self->db->query($q_string, @args);
    my @games;
    while (my $row = $r->hash) {
        row_fix($self->app->nh, $row);
        push @games, $row;
    }
    return @games;
}


# Grabs the DB row corresonding to the most recent ascension for a given variant
sub get_most_recent_asc
{
    my ($self, $var) = @_;
    my @rows = $self->_get_recent_games($var, 1, 1);
    my $row = $rows[0];
    $row->{'age'} = fmt_age(
        $row->{'age_years'},
        $row->{'age_months'},
        $row->{'age_days'},
        $row->{'age_hours'});
    return $row;
}

# Grabs n recent ascensions
sub get_n_recent_ascs
{
    my ($self, $var, $n) = @_;
    return $self->_get_recent_games($var, $n, 1);
}

# Grabs n recent games
sub get_n_recent_games
{
    my ($self, $var, $n) = @_;
    return $self->_get_recent_games($var, $n, 0);
}

# Grabs recent ascensions
sub get_all_ascs
{
    my ($self, $var) = @_;
    return $self->_get_recent_games($var, 0, 1);
}

# Grabs recent games
sub get_recent_games
{
    my ($self, $var) = @_;
    return $self->_get_recent_games($var, 0, 0);
}

# fetch the most recent ascension in each variant
# ordered by age, returns the list of ascensions and
# the variants ordered as they appear in the asc list
sub get_last_asc_per_var
{
    my ($self, @vars) = @_;
    my %latest_ascs;
    for my $var (@vars) {
        my $row = $self->get_most_recent_asc($var);
        $latest_ascs{$var} = $row;
    }
    my @vars_ordered = sort {
        $latest_ascs{$a}{'age_raw'}
        <=> $latest_ascs{$b}{'age_raw'}
    } keys %latest_ascs;
    # need to pass these as references or they won't pack nicely in a tuple
    return \%latest_ascs, \@vars_ordered;
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

  $r = $self->db->query($query, @args);
  if(!$r) { return $r->sth->errstr(); }

  while(my $row = $r->hash) {
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

  $r = $self->db->query($query, @args);
  if(!$r) { return $r->$sth->errstr(); }

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
sub get_current_streaks
{
    my $self = shift;
    my $streaks_proc_1;
    my $streaks_proc_2;
    my ($streaks_ord, $streaks) = $self->sql_load_streaks('all', undef, undef, 2, 1);
    if (!ref($streaks_ord)) {
        # do something with error
        die $streaks_ord;
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

# fetch the fastest wins
sub get_n_lowest_gametime
{
    my ($self, $var, $lim) = @_;

    my $r;
    if ($var ne 'all') {
        my $q_string = sprintf('select * from v_ascended where variant = ? and turns > 0 order by turns asc limit %d', $lim);
        $r = $self->db->query($q_string, $var);
    } else {
        my $q_string = sprintf('select * from v_ascended where turns > 0 order by turns asc limit %d', $lim);
        $r = $self->db->query($q_string);
    }

    my @games;
    my $i = 1;
    while (my $row = $r->hash) {
        row_fix($self->app->nh, $row);
        $row->{n} = $i;
        $i += 1;
        push @games, $row;
    }
    return @games;
}

# count subn turncount wins
sub count_subn_games
{
    my ($self, $var, $lim) = @_;
    my @cond = ('turns > 0');
    my @arg = ($lim);
    push (@cond, 'turns < ?');

    if ($var ne 'all') {
        push(@cond, 'variant = ?');
        push(@arg, $var);
    }

    my $q_string = sprintf(
        'select name, count(*), sum(turns), round(avg(turns)) as avg ' .
        'from v_ascended ' .
        'where %s group by name order by count desc, sum asc',
        join(' and ', @cond)
    );

    my $r = $self->db->query($q_string, @arg);
    my @rows;
    my $i = 1;
    while (my $row = $r->hash) {
        $row->{n} = $i;
        $i += 1;
        push @rows, $row;
    }
    return @rows;
}

1;
