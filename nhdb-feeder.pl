#!/usr/bin/env perl

#============================================================================
# NHDB Feeder
# """""""""""
# (c) 2013 Borek Lupomesky
#
# This program scrapes logs from pre-defined NetHack servers and inserts
# game entries into database.
#============================================================================

use strict;
use utf8;
use DBI;
use Getopt::Long;
use NHdb;
use NetHack;
use Log::Log4perl qw(get_logger);

$| = 1;


#============================================================================
#=== definitions ============================================================
#============================================================================

my $lockfile = '/tmp/nhdb-feeder.lock';


#============================================================================
#=== globals ================================================================
#============================================================================

my $dbh;
my %translations;               # name-to-name translations
my $translations_cnt = 0;       # number of name translation
my $logger;                     # log4perl instance


#============================================================================
#=== functions =============================================================
#============================================================================

#============================================================================
# Split a line along field separator, parse it into hash and return it as
# a hashref.
#============================================================================

sub parse_log
{
  my $log = shift;
  my $l = shift;
  my %l;
  my @a;

  #--- NetHack 3.6.0 uses tabs as field separator; all other variants/versions
  #--- use colon

  if($log->{'variant'} eq 'nh' && $log->{'version'} eq '3.6.0') {
    @a = split(/\t/, $l);
  } else {
    @a = split(/:/, $l);
  }

  #--- split keys and values

  for my $field (@a) {
    my ($key, $val) = split(/=/, $field);
    $l{$key} = $val;
  }

  #--- finish returning hashref

  return \%l
}


#============================================================================
# Create new streak entry, add one game to it and return [ streaks_i ] on
# success or error msg.
#============================================================================

sub sql_streak_create_new
{
  my $logfiles_i = shift;
  my $name = shift;
  my $rowid = shift;
  my $logger = get_logger('Streaks');

  #--- create new streak entry

  my $qry = q{INSERT INTO streaks (logfiles_i, name) VALUES (?, ?) };
  $qry .= q{RETURNING streaks_i};
  my $sth = $dbh->prepare($qry);
  my $r = $sth->execute($logfiles_i, $name);
  if(!$r) {
    $logger->fatal(
      sprintf(
        'sql_streak_create_new() failed to create new streak, dberr=%s',
        $sth->errstr()
      )
    );
    return $sth->errstr();
  }

  #--- retrieve streak id

  my ($streaks_i) = $sth->fetchrow_array();
  $sth->finish();
  $logger->debug(
    sprintf(
      'Started new streak %d (logfiles_i=%d, name=%s, rowid=%d)',
      $streaks_i, $logfiles_i, $name, $rowid
    )
  );

  #--- add the game to the new streak

  $r = sql_streak_append_game($streaks_i, $rowid);
  return $r if !ref($r);

  #--- return

  return [ $streaks_i ];
}


#============================================================================
# Add a game to a streak.
#============================================================================

sub sql_streak_append_game
{
  my $streaks_i = shift;     # 1. streak to be appended to
  my $rowid = shift;         # 2. the game to be appended
  my $logger = get_logger('Streaks');

  #--- create mapping entry

  my $qry = q{INSERT INTO map_games_streaks VALUES (?, ?)};
  my $r = $dbh->do($qry, undef, $rowid, $streaks_i);
  if(!$r) {
    $logger->fatal(
      sprintf(
        'sql_streak_append_game(%d, %d) failed to append game, errdb=%s',
        $streaks_i, $rowid, $dbh->errstr()
      )
    );
    return $dbh->errstr();
  }
  $logger->debug(
    sprintf(
      'Appended game %d to streak %d',
      $rowid, $streaks_i
    )
  );

  #--- finish

  return [];
}


#============================================================================
# This will close streak, ie. set streaks.open to FALSE. If the streak has
# num_games = 1; it will be deleted by database trigger.
#============================================================================

sub sql_streak_close
{
  my $streaks_i = shift;
  my $logger = get_logger('Streaks');

  #--- close streak entity and get its current state

  my $qry = q{UPDATE streaks SET open = FALSE };
  $qry .= q{WHERE streaks_i = ?};
  my $sth = $dbh->prepare($qry);
  my $r = $sth->execute($streaks_i);
  if(!$r) {
    $logger->fatal(
      sprintf(
        'sql_streak_close(%d) failed to close streak, errdb=%s',
        $streaks_i, $dbh->errstr()
      )
    );
    return $sth->errstr();
  }
  $logger->debug(sprintf('Closed streak %d', $streaks_i));

  #--- finish

  return [];
}


#============================================================================
# This function gets last game in a streak entry.
#============================================================================

sub sql_streak_get_tail
{
  my $streaks_i = shift;
  my $logger = get_logger('Streaks');

  my $qry = q{SELECT * FROM streaks };
  $qry .= q{JOIN map_games_streaks USING (streaks_i) };
  $qry .= q{JOIN games USING (rowid) };
  $qry .= q{WHERE streaks_i = ? ORDER BY endtime DESC LIMIT 1};
  my $sth = $dbh->prepare($qry);
  my $r = $sth->execute($streaks_i);
  if(!$r) {
    $logger->fatal(
      sprintf(
        'sql_streak_get_tail(%d) failed, errdb=%s',
        $streaks_i, $dbh->errstr()
      )
    );
    return $sth->errstr();
  }
  my $result = $sth->fetchrow_hashref();
  $sth->finish();

  #--- finish 
  
  return $result;
}


#============================================================================
# Get streaks_i for given logfiles_i and name.
#============================================================================

sub sql_streak_find
{
  #--- arguments

  my $logfiles_i = shift;
  my $name = shift;

  #--- other init

  my $logger = get_logger('Streaks');

  #--- db query

  my $qry =
    q{SELECT streaks_i FROM streaks } .
    q{WHERE logfiles_i = ? AND name = ? AND open IS TRUE};
  my $sth = $dbh->prepare($qry);
  my $r = $sth->execute($logfiles_i, $name);
  if(!$r) {
    $logger->fatal(
      sprintf(
        'sql_streak_find(%d, %s) failed, errdb=%s',
        $logfiles_i, $name, $dbh->errstr()
      )
    );
    return $sth->errstr();
  }
  my $streaks_i = $sth->fetchrow_array();
  $sth->finish();
  $logger->debug(
    sprintf(
      'Pre-existing streak %d for (%d,%s) found',
      $streaks_i, $logfiles_i, $name
    )
  ) if $streaks_i;

  #--- finish

  return [ $streaks_i ];
}


#============================================================================
# Create SQL INSERT string from key=value pair has for one line. Note: This
# function also does some modifications to the row of data (here $l) that
# are used later in the processing!
#============================================================================

sub sql_insert_games
{
  #--- arguments

  my (
    $logfiles_i,       # 1. logfile id
    $server,           # 2. server id
    $variant,          # 3. variant id
    $l                 # 4. line to be parsed, transformed into SQL
  ) = @_;

  #--- other variables
  # @fields is just a list of database fields in table 'games'; values
  # is an array whose elements can appear in two forms: a) simple scalar
  # value; b) sub-array of 1. SQL expression that contains single placeholder
  # 2. simple scalar value. -- this is needed to be able to use placeholders
  # together with SQL expressions as values.

  my @fields;
  my @values;

  #--- reject too old log entries without necessary info
  return undef unless logfile_require_fields($l);

  #--- reject wizmode games, paxed test games
  #if($l->{'name'} eq 'wizard') { return undef; }
  #if($l->{'name'} eq 'paxedtest' && $server eq 'nao') { return undef; }
  return undef
    if grep 
      { $l->{'name'} eq $_ } 
      @{$NHdb::nhdb_def->{'feeder'}{'reject_name'}};
  
  #--- reject "special" modes of NH4 and its kin
  #--- Fourk challenge mode is okay, though
  if(
    exists $l->{'mode'} &&
    !($l->{'mode'} eq 'normal' || $l->{'mode'} eq 'challenge')
  ) {
    return undef;
  }

  #--- reject entries with empty name
  if(!exists $l->{'name'} || !$l->{'name'}) { return undef; }

  #--- death (reason)
  my $death = $l->{'death'};
  $death =~ tr[\x{9}\x{A}\x{D}\x{20}-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}][]cd;
  push(@fields, 'death');
  push(@values, $death);

  #--- ascended flag
  $l->{'ascended'} = sprintf("%d", ($death =~ /^ascended\b/));
  my $flag_ascended = ($death =~ /^ascended\b/ ? 'TRUE' : 'FALSE');
  push(@fields, 'ascended');
  push(@values, $flag_ascended);

  #--- dNetHack combo mangling workaround
  # please refer to comment in NetHack.pm; this is only done to two specific
  # winning games!
  if($variant eq 'dnh' && $l->{'ascended'}) {
    ($l->{'role'}, $l->{'race'}) = nh_dnethack_map($l->{'role'}, $l->{'race'});
  }

  #--- NetHack 3.6.0 bogus realtime workaround
  # According to paxed, NH 3.6.0 sometimes saves bogus realtime; he recommended
  # to discard any realtime that is larger than endttime - starttime.
  if(
    $l->{'variant'} eq 'nh' && $l->{'version'} eq '3.6.0' &&
    $l->{'endttime'} - $l->{'starttime'} < $l->{'realtime'}
  ) {
    $l->{'realtime'} = undef;
  }

  #--- regular fields
  for my $k (@{$NHdb::nhdb_def->{'feeder'}{'regular_fields'}}) {
    if(exists $l->{$k}) {
      push(@fields, $k);
      push(@values, $l->{$k});
    }
  }

  #--- name (before translation)
  push(@fields, 'name_orig');
  push(@values, $l->{'name'});
  
  #--- name
  push(@fields, 'name');
  if(exists($translations{$server}{$l->{'name'}})) {
    $l->{'name'} = $translations{$server}{$l->{'name'}};
  }
  push(@values, $l->{'name'});

  #--- logfiles_i
  push(@fields, 'logfiles_i');
  push(@values, $logfiles_i);
  
  #--- conduct
  push(@fields, 'conduct');
  push(@values, eval($l->{'conduct'}));

  #--- achieve
  if(exists $l->{'achieve'}) {
    push(@fields, 'achieve');
    push(@values, eval($l->{'achieve'}));
  }
  
  #--- start time
  push(@fields, 'starttime');
  push(@values, [ q{timestamp with time zone 'epoch' + ? * interval '1 second'}, $l->{'starttime'} ]) ;
  push(@fields, 'starttime_raw');
  push(@values, $l->{'starttime'});

  #--- end time
  push(@fields, 'endtime');
  push(@values, [ q{timestamp with time zone 'epoch' + ? * interval '1 second'}, $l->{'endtime'} ]);
  push(@fields, 'endtime_raw');
  push(@values, $l->{'endtime'});

  #--- quit flag (escaped also counts)
  my $flag_quit = 'FALSE';
  $flag_quit = 'TRUE' if $death =~ /^quit\b/;
  $flag_quit = 'TRUE' if $death =~ /^escaped\b/;
  push(@fields, 'quit');
  push(@values, $flag_quit);

  #--- scummed flag
  my $flag_scummed = 'FALSE';
  if($flag_quit eq 'TRUE' && $l->{'points'} < 1000) {
    $flag_scummed = 'TRUE'
  }
  push(@fields, 'scummed');
  push(@values, $flag_scummed);

  #--- finish

  return (
    sprintf(
      'INSERT INTO games ( %s ) VALUES ( %s ) RETURNING rowid',
      join(', ', @fields),
      join(',', map { ref() ? $_->[0] : '?' } @values)
    ),
    [ map { ref() ? $_->[1] : $_ } @values ]
  );
}


#============================================================================
# Write update info into "update" table.
#============================================================================

sub sql_update_info
{
  my $update_variant = shift;
  my $update_name    = shift;
  my ($qry, $re);

  #--- write updated variants

  if(scalar(keys %$update_variant)) {
    for my $var (keys %$update_variant, 'all') {
      $re = $dbh->do(
        q{UPDATE update SET upflag = TRUE WHERE variant = ? AND name = ''},
        undef, $var
      );
      if(!$re) {
        return $dbh->errstr();
      }
      
      # if no entry was updated, we have to create one instead
      elsif($re == 0) {
        $re = $dbh->do(
          q{INSERT INTO update VALUES (?,'',TRUE)},
          undef, $var
        );
        if(!$re) { return $dbh->errstr(); }
      }
    }
  }

  #--- write update player names

  for my $name (keys %$update_name) {
    for my $var (keys %{$update_name->{$name}}, 'all') {
      $re = $dbh->do(
        q{UPDATE update SET upflag = TRUE WHERE variant = ? AND name = ?},
        undef, $var, $name
      );
      if(!$re) { return $dbh->errstr(); }
      if($re == 0) { 
        $re = $dbh->do(
          q{INSERT INTO update VALUES (?, ?, TRUE)},
          undef, $var, $name
        );
        if(!$re) {
          return $dbh->errstr();
        }
      }
    }
  }

  #--- finish successfully

  return undef;
}


#============================================================================
# This function performs database purge for given servers/variants (or all
# of them if none are specified).
#============================================================================

sub sql_purge_database
{
  #--- arguments

  my ($variants, $servers, $logid) = @_;

  #--- init logging

  my $logger = get_logger('Feeder::Purge_db');
  $logger->info('Requested database purge');
  if(@$variants) {
    $logger->info('Variants: ' . join(',', @$variants));
  }

  if(@$servers) {
    $logger->info('Servers: ' . join(',', @$servers));
  }

  #--- get list of logfiles we will be operating on

  my $qry = 'SELECT * FROM logfiles';
  my (@cond, @cond_var, @cond_srv, @arg, @logfiles);

  if(@$variants) {
    push(@cond_var, ('variant = ?') x scalar(@$variants));
    push(@arg, @$variants);
  }

  if(@$servers) {
    push(@cond_srv, ('server = ?') x scalar(@$servers));
    push(@arg, @$servers);
  }

  if(@cond_var) {
    push(@cond, '(' . join(' OR ', @cond_var) . ')');
  }
  if(@cond_srv) {
    push(@cond, '(' . join(' OR ', @cond_srv) . ')');
  }

  if($logid) {
    push(@cond, 'logfiles_i = ?');
    push(@arg, $logid);
  }

  my $where = join(' AND ', @cond);
  if(@cond) {
    $qry .= ' WHERE ' . $where;
  }

  my $sth = $dbh->prepare($qry);
  my $r = $sth->execute(@arg);

  if(!$r) {
    $logger->fatal(
      sprintf('Failed to get list of logfiles (%s)', $sth->errstr())
    );
  }
  while(my $s = $sth->fetchrow_hashref()) {
    push(@logfiles, $s);
  }
  if(scalar(@logfiles) == 0) {
    $logger->fatal("No matching logfiles");
    return;
  } else {
    $logger->info(sprintf('%d logfiles to be purged', scalar(@logfiles)));
  }

  #--- iterate over logfiles

  for my $log (@logfiles) {
    my ($srv, $var) = ($log->{'server'}, $log->{'variant'});
    my $logfiles_i = $log->{'logfiles_i'};
    $logger->info("[$srv/$var] ", $log->{'descr'});

  #--- eval begin

    eval {

  #--- start transaction

      $r = $dbh->begin_work();
      if(!$r) {
        $logger->fatal(
          sprintf(
            "[%s/%s] Transaction begin failed (%s), aborting batch",
            $srv, $var, $dbh->errstr()
          )
        );
        die "TRFAIL\n";
      }

  #--- delete the games

      $logger->info("[$srv/$var] Deleting from games");
      $r = $dbh->do('DELETE FROM games WHERE logfiles_i = ?', undef, $logfiles_i);
      if(!$r) {
        $logger->fatal(
          sprintf(
            '[%s/%s] Deleting from games failed (%s)',
            $srv, $var, $dbh->errstr()
          )
        );
        die "ABORT\n";
      } else {
        $logger->info(
          sprintf('[%s/%s] Deleted %d entries', $srv, $var, $r)
        );
      }

  #--- reset 'fpos' field in 'logfiles' table

      $r = $dbh->do(
        'UPDATE logfiles SET fpos = NULL WHERE logfiles_i = ?', undef, $logfiles_i
      );
      if(!$r) {
        $logger->fatal(
          sprintf(
            '[%s/%s] Failed to reset the fpos field',
            $srv, $var
          )
        );
        die "ABORT\n";
      }

  #--- eval end

    };
    chomp $@;
    if(!$@) {
      $r = $dbh->commit();
      if(!$r) {
        $logger->fatal(
          sprintf(
            "[%s/%s] Failed to commit transaction (%s)",
            $srv, $var, $dbh->errstr()
          )
        );
      } else {
        $logger->info("[$srv/$var] Transaction commited");
      }
    } elsif($@ eq 'ABORT') {
      $r = $dbh->rollback();
      if(!$r) {
        $logger->fatal(
          sprintf(
            "[%s/%s] Failed to abort transaction (%s)",
            $srv, $var, $dbh->errstr()
          )
        );
      } else {
        $logger->info("[$srv/$var] Transaction aborted");
      }
    }

  #--- end of iteration over logfiles

  }

}


#============================================================================
# Display usage help.
#============================================================================

sub help
{
  print "Usage: nhdb-feeder.pl [options]\n\n";
  print "  --help         get this information text\n";
  print "  --logfiles     display configured logfiles, then exit\n";
  print "  --variant=VAR  limit processing to specified variant(s)\n";
  print "  --server=SRV   limit processing to specified server(s)\n";
  print "  --logid=ID     limit processing to specified logid\n";
  print "  --purge        delete database content\n";
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
#============================================================================

#--- initialize logging

Log::Log4perl->init('cfg/logging.conf');
$logger = get_logger('Feeder');

#--- title

$logger->info('NetHack Scoreboard / Feeder');
$logger->info('(c) 2013-15 Borek Lupomesky');
$logger->info('---');

#--- process commandline options

my $cmd_logfiles;
my @cmd_variant;
my @cmd_server;
my $cmd_purge;
my $cmd_logid;

if(!GetOptions(
  'logfiles'  => \$cmd_logfiles,
  'variant=s' => \@cmd_variant,
  'server=s'  => \@cmd_server,
  'logid=s'   => \$cmd_logid,
  'purge'    => \$cmd_purge
)) {
  help();
  exit(1);
}

cmd_option_array_expand(\@cmd_variant);
cmd_option_array_expand(\@cmd_server);

#--- lock file check/open

if(!$cmd_logfiles && !$cmd_purge) {
  if(-f $lockfile) {
    $logger->warn('Another instance running, exiting');
    exit(1);
  }
  open(F, "> $lockfile") || $logger->error("Cannot open lock file $lockfile");
  print F $$, "\n";
  close(F);
}

#--- connect to database

$dbh = dbconn('nhdbfeeder');
if(!ref($dbh)) {
  die sprintf('Failed to connect to the database (%s)', $dbh);
}

#--- get list of logfiles to process

my @logfiles;
my @qry;

push(@qry, q{SELECT * FROM logfiles});
push(@qry, q{WHERE oper = 't'}) if !scalar(@cmd_server);
push(@qry, q{ORDER BY logfiles_i ASC});
my $qry = join(' ', @qry);
my $sth = $dbh->prepare($qry);
my $r = $sth->execute();
if(!$r) {
  die 'Database query failed (' . $sth->errstr() . ')';
}
while(my $s = $sth->fetchrow_hashref()) {
  push(@logfiles, $s);
}
if(scalar(@logfiles) == 0) {
  die "No operational logfiles configured\n";
}

$logger->info(
  sprintf("Loaded %d configured logfile%s",
    scalar(@logfiles),
    (scalar(@logfiles) != 1 ? 's' : '')
  )
);

#--- display logfiles, if requested

if($cmd_logfiles) {
  $logger->info('Displaying configured logfiles (--logfiles option)');
  $logger->info('');
  $logger->info('rowid srv var descr');
  $logger->info('----- --- --- ' . '-' x 42);
  for my $log (@logfiles) {
    $logger->info(
      sprintf(
        "%5d %-3s %-3s %s\n",
        $log->{'logfiles_i'},
        $log->{'server'},
        $log->{'variant'},
        substr($log->{'descr'}, 0, 48)
      )
    );
  }
  exit(0);
}

#--- database purge

if($cmd_purge) {
  sql_purge_database(\@cmd_variant, \@cmd_server, $cmd_logid);
  exit(0);
}

#--- load list of translations

$qry = q{SELECT server, name_from, name_to FROM translations};
$sth = $dbh->prepare($qry);
$r = $sth->execute();
if(!$r) {
  die 'Database query failed (' . $sth->errstr() . ')';
}
while(my @a = $sth->fetchrow_array()) {
  $translations{$a[0]}{$a[1]} = $a[2];
  $translations_cnt++;
}
$logger->info(
  sprintf(
    "Loaded %d name translation%s\n",
    $translations_cnt,
    ($translations_cnt != 1 ? 's' : '')
  )
);

#--- check update table
# this code checks if update table has any rows in it;
# when finds none, it assumes it is uninitialized and
# initializes it

$logger->info('Checking update table');
my $sth = $dbh->prepare('SELECT count(*) FROM update');
my $r = $sth->execute();
if(!$r) {
  die sprintf("Cannot count update table (%s)", $sth->errstr());
}
my ($cnt_update) = $sth->fetchrow_array();
$sth->finish();
if($cnt_update == 0) {
  $logger->info('No entries in the update table');
  $logger->info('Initializing update table, step 1');
  $r = $dbh->do(
    'INSERT INTO update ' .
    'SELECT variant, name ' .
    'FROM games LEFT JOIN logfiles USING (logfiles_i) ' .
    'GROUP BY variant, name'
  );
  if(!$r) {
    die sprintf("Failed to initialize the update table (%s)", $sth->errstr());
  } else {
    $logger->info(sprintf('Update table initialized with %d entries (step 1)', $r));
  }
  $logger->info('Initializing update table, step 2');
  $r = $dbh->do(
    q{INSERT INTO update } .
    q{SELECT 'all', name, FALSE } .
    q{FROM games LEFT JOIN logfiles USING (logfiles_i) } .
    q{GROUP BY name}
  );
  if(!$r) {
    die sprintf("Failed to initialize the update table (%s)", $sth->errstr());
    } else {
      $logger->info(sprintf('Update table initialized with %d entries (step 2)', $r));
    }
} else {
  $logger->info(sprintf('Update table has %d entries', $cnt_update));
}

#--- iterate over logfiles

for my $log (@logfiles) {

  my $transaction_in_progress = 0;
  my $logfiles_i = $log->{'logfiles_i'};
  my $lbl = sprintf('[%s/%s] ', $log->{'variant'}, $log->{'server'});

  #--- user selection processing

  next if 
    scalar(@cmd_variant) &&
    !grep { $log->{'variant'} eq lc($_) } @cmd_variant;
  next if
    scalar(@cmd_server) &&
    !grep { $log->{'server'} eq lc($_) } @cmd_server;
  next if
    $cmd_logid &&
    $log->{'logfiles_i'} != $cmd_logid;
  
  eval { # <--- eval starts here -------------------------------------------
  
    #--- prepare, print info
      
    my $localfile = sprintf(
      '%s/%s',
      $NHdb::nhdb_def->{'logs'}{'localpath'},
      $log->{'localfile'}
    );
    my @fsize;
    my $fpos = $log->{'fpos'};
    $fsize[0] = -s $localfile;
    $logger->info('---');
    $logger->info($lbl, 'Processing started');
    $logger->info($lbl, 'Local file is ', $localfile);
    $logger->info($lbl, 'Logfile URL is ', $log->{'logurl'} ? $log->{'logurl'} : 'N/A');

    #--- retrieve file

    if($log->{'static'}) {
      if($fpos) {
        $logger->info($lbl, 'Skipping already processed static logfile');
        die "OK\n";
      }
      $logger->info($lbl, 'Static logfile, skipping retrieval');
      $fsize[1] = $fsize[0];
    } elsif(!$log->{'logurl'}) {
      $logger->warn($lbl, 'Log URL not defined, skipping retrieval');
    } else {
      $logger->info($lbl, 'Getting logfile from the server');
      $r = system(sprintf($NHdb::nhdb_def->{'wget'}, $localfile, $log->{'logurl'}));
      if($r) { $logger->warn($lbl, 'Failed to get the logfile'); die; }
      $fsize[1] = -s $localfile;
      $logger->info($lbl, sprintf('Logfile retrieved successfully, got %d bytes', $fsize[1] - $fsize[0]));
      if(
        $log->{'fpos'}
        && ($fsize[1] - $fsize[0] < 1)
        && ($fsize[0] - $log->{'fpos'} < 1)
      ) {
        $logger->info($lbl, 'No new data, skipping further processing');
        $dbh->do(
          'UPDATE logfiles SET lastchk = current_timestamp WHERE logfiles_i = ?',
          undef, $logfiles_i
        );
        die "OK\n";
      }
    }

    #--- open the file

    if(!open(F, $localfile)) {
      $logger->error($lbl, 'Failed to open local file ', $localfile);
      die;
    }

    #--- seek into the file (if position is known)
       
    if($fpos) {
      $logger->info($lbl, sprintf('Seeking to %d', $fpos));
      $r = seek(F, $fpos, 0);
      if(!$r) {
        $logger->error($lbl, sprintf('Failed to seek to $fpos', $fpos));
        die;
      }
    }
    
    #--- set timezone
    
    $logger->info($lbl, 'Setting time zone to ', $log->{'tz'});
    $r = $dbh->do(sprintf(q{SET TIME ZONE '%s'}, $log->{'tz'})); 
    if(!$r) {
      $logger->error($lbl, 'Failed to set time zone');
      die;
    }

    #--- begin transaction
    
    $logger->info($lbl, 'Starting database transaction');
    $r = $dbh->begin_work();
    if(!$r) {
      $logger->info($lbl, 'Failed to start database transaction');
      die;
    }
    $transaction_in_progress = 1;
    
    #--- now read content of the file
    
    my $lc = 0;           # line counter
    my $tm = time();      # timer
    my $ll = 0;           # time of last info
    my %update_name;      # updated names
    my %update_variant;   # updated variants
    my %streak_open;      # indicates open streak for

    $logger->info($lbl, 'Processing file ', $localfile);

    while(my $l = <F>) { #<<< read loop beings here

      chomp($l);

    #--- devnull logs are special-cased here
    # devnull logs have server id prepended to each log entry (since their
    # xlogfile is synthesized from individual server xlogfiles); the id is
    # removed from the entry here

      $l =~ s/^.*?\s// if $log->{'server'} eq 'dev';

    #--- parse log
    
      my $pl = parse_log($log, $l);

    #--- insert row into database

      my ($rowid, $values);
      ($qry, $values) = sql_insert_games(
        $logfiles_i,
        $log->{'server'},
        $log->{'variant'},
        $pl
      );
      if($qry) {
        my $sth = $dbh->prepare($qry);
        $r = $sth->execute(@$values);
        if(!$r) {
          $logger->error($lbl, 'Failure during inserting new records');
          $logger->error($lbl, sql_show_query($qry, $values));
          die;
        }
        ($rowid) = $sth->fetchrow_array();
        $sth->finish();

    #--- mark updates
    # FIXME: There's subtle potential issue with this, since
    # scummed games do trigger these updates; I haven't decided
    # if we want this or not.
    
        $update_variant{$log->{'variant'}} = 1;
        $update_name{$pl->{'name'}}{$log->{'variant'}} = 1;

    #-------------------------------------------------------------------------
    #--- streak processing starts here ---------------------------------------
    #-------------------------------------------------------------------------

    #--- initialize streak status for name

    # if the streak status is not yet stored in memory, which happens when
    # we first encounter (logfiles_i, name) pair, it is loaded from database
    # (table "streaks")

        if(!exists($streak_open{$logfiles_i}{$pl->{'name'}})) {
          $r = sql_streak_find($logfiles_i, $pl->{'name'});
          die $r if !ref($r);
          $streak_open{$logfiles_i}{$pl->{'name'}} = $r->[0];
        }

    #--- game is ASCENDED

        if($pl->{'ascended'}) {

    #--- game is ASCENDED / streak is NOT OPEN

          if(!$streak_open{$logfiles_i}{$pl->{'name'}}) {
            my $streaks_i = sql_streak_create_new(
              $logfiles_i, 
              $pl->{'name'}, 
              $rowid
            );
            die $streaks_i if !ref($streaks_i);
            $streak_open{$logfiles_i}{$pl->{'name'}} = $streaks_i->[0]
          }

    #--- game is ASCENDED / streak is OPEN
    # we are checking for overlap between the last game of the streak
    # and the current game; if there is overlap, the streak is broken

          else {
            my $last_game = sql_streak_get_tail(
              $streak_open{$logfiles_i}{$pl->{'name'}}
            );
            if(!ref($last_game)) {
              die sprintf(
                'sql_streak_get_tail(%s) failed with msg "%s"',
                $streak_open{$logfiles_i}{$pl->{'name'}}, $last_game
              );
            }
            if($last_game->{'endtime_raw'} >= $pl->{'starttime'}) {
              # close current streak
              $logger->info($lbl,
                sprintf('Closing overlapping streak %d', $streak_open{$logfiles_i}{$pl->{'name'}})
              );
              $r = sql_streak_close(
                $streak_open{$logfiles_i}{$pl->{'name'}}
              );
              die $r if !ref($r);
              # open new
              $r = sql_streak_create_new(
                $logfiles_i, 
                $pl->{'name'},
                $rowid
              );
              die $r if !ref($r);
              $streak_open{$logfiles_i}{$pl->{'name'}} = $r->[0];
            } else {
              $r = sql_streak_append_game(
                $streak_open{$logfiles_i}{$pl->{'name'}},
                $rowid
              );
              die $r if !ref($r);
            }
          }
        }

    #--- game is not ASCENDED

        else {

    #--- game is not ASCENDED / streak is OPEN

          if($streak_open{$logfiles_i}{$pl->{'name'}}) {
            $r = sql_streak_close(
              $streak_open{$logfiles_i}{$pl->{'name'}}
            );
            die $r if !ref($r);
            $streak_open{$logfiles_i}{$pl->{'name'}} = undef;  
          }

        }

      }

    #--- display progress info

      if((time() - $tm) > 5) {
        $tm = time();
        $logger->info($lbl, 
          sprintf('Processing (%d lines, %d l/sec)', $lc, ($lc-$ll)/5 )
        );
        $ll = $lc;
      }
      $lc++;

    } #<<< read loop ends here

    $logger->info($lbl,
      sprintf('Finished reading %d lines', $lc)
    );
    
    #--- write update info

    my $re = sql_update_info(\%update_variant, \%update_name);
    if($re) { die $re; }

    #--- update database with new position in the file
    
    $qry = 'UPDATE logfiles SET fpos = ?, lastchk = current_timestamp WHERE logfiles_i = ?';
    $sth = $dbh->prepare($qry);
    $r = $sth->execute($fsize[1], $log->{'logfiles_i'});
    if(!$r) {
      $logger->error($lbl, q{Failed to update table 'servers'});
      die;
    }
    
    #--- commit transaction
    
    $r = $dbh->commit();
    $transaction_in_progress = 0;
    if(!$r) {
      $logger->error($lbl, 'Failed to commit transaction');
      die;
    }
    $logger->info($lbl, 'Transaction commited');
  
  }; # <--- eval ends here -------------------------------------------------

  #--- log exception message, if any

  if($@ && $@ ne "OK\n") {
    $logger->warn($lbl, 'Eval ended with error: ', $@);
  }

  #--- rollback if needed
  
  if($transaction_in_progress) {
    $logger->warn($lbl, 'Transaction rollback');
    $dbh->rollback();
  }

  #--- finish
  
  $logger->info($lbl, 'Processing finished');
}

#--- disconnect from database

dbdone('nhdbfeeder');

#--- release lock file

unlink($lockfile);
