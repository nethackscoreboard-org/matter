#!/usr/bin/perl

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

$| = 1;


#============================================================================
#=== definitions ============================================================
#============================================================================

my $logs = 'logs';
my $lockfile = '/tmp/nhdb-feeder.lock';


#============================================================================
#=== globals ================================================================
#============================================================================

my $dbh;
my %translations;               # name-to-name translations
my $translations_cnt = 0;       # number of name translation


#============================================================================
#=== functions =============================================================
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
# Split a line along colons, parse it into hash and return it as hashref.
#============================================================================

sub parse_log
{
  my $l = shift;
  my %l;
  
  my @a = split(/:/, $l);
  for my $field (@a) {
    my ($key, $val) = split(/=/, $field);
    $l{$key} = $val;
  }
  return \%l
}


#============================================================================
# Create new streak entry and return [ streaks_i ] on success or error msg.
#============================================================================

sub sql_streak_create_new
{
  my $logfiles_i = shift;
  my $name = shift;
  my $rowid = shift;

  #--- create new game_set

  my $qry = q{INSERT INTO games_set VALUES (DEFAULT) RETURNING games_set_i};
  my $sth = $dbh->prepare($qry);
  my $r = $sth->execute();
  if(!$r) { return $sth->errstr(); }
  my ($games_set_i) = $sth->fetchrow_array();
  $sth->finish();

  #--- create mapping entry

  $qry = q{INSERT INTO games_set_map VALUES (?, ?)};
  $r = $dbh->do($qry, undef, $rowid, $games_set_i);
  if(!$r) { return $dbh->errstr(); }

  #--- create streak entry

  $qry = q{INSERT INTO streaks };
  $qry .= q{(games_set_i, logfiles_i, name, open, num_games) };
  $qry .= q{VALUES (?, ?, ?, TRUE, 1) };
  $qry .= q{RETURNING streaks_i};
  $sth = $dbh->prepare($qry);
  $r = $sth->execute($games_set_i, $logfiles_i, $name);
  if(!$r) { return $sth->errstr(); }
  my ($streaks_i) = $sth->fetchrow_array();
  $sth->finish();

  #--- return

  return [ $streaks_i ];
}


#============================================================================
#============================================================================

sub sql_streak_append_game
{
  my $streaks_i = shift;
  my $rowid = shift;

  #--- update streak entry

  my $qry = q{UPDATE streaks SET num_games = num_games + 1 };
  $qry .= q{WHERE streaks_i = ? RETURNING games_set_i};
  my $sth = $dbh->prepare($qry);
  my $r = $sth->execute($streaks_i);
  if(!$r) { return $sth->errstr(); }
  my ($games_set_i) = $sth->fetchrow_array();
  if(!$games_set_i) { return "sql_streak_append_game() assert failure"; }

  #--- create mapping entry

  $qry = q{INSERT INTO games_set_map VALUES (?, ?)};
  $r = $dbh->do($qry, undef, $rowid, $games_set_i);
  if(!$r) { return $dbh->errstr(); }

  #--- finish

  return [];
}


#============================================================================
# This will close streak; if the streak is one game long, it will be
# completely deleted (since it is not really a streak).
#============================================================================

sub sql_streak_close
{
  my $streaks_i = shift;

  #--- close streak entity and get its current state

  my $qry = q{UPDATE streaks SET open = FALSE };
  $qry .= q{WHERE streaks_i = ? RETURNING games_set_i, num_games};
  my $sth = $dbh->prepare($qry);
  my $r = $sth->execute($streaks_i);
  if(!$r) { return $sth->errstr(); }
  my ($games_set_i, $num_games) = $sth->fetchrow_array();
  if(!$games_set_i) { return "sql_streak_close() assert failure #1"; }

  #--- delete the streak if it only has one game

  if($num_games == 1) {
  
    # remove mapping entry
    $qry = q{DELETE FROM games_set_map WHERE games_set_i = ?};
    $r = $dbh->do($qry, undef, $games_set_i);
    if(!$r) { return $dbh->errstr(); }
    if($r != 1) { return "sql_streak_close() assert failure #2"; }

    # remove the streak entity
    $qry = q{DELETE FROM streaks WHERE streaks_i = ?};
    $r = $dbh->do($qry, undef, $streaks_i);
    if(!$r) { return $dbh->errstr(); }
    if($r != 1) { return "sql_streak_close() assert failure #4"; }

    # remove the game set
    $qry = q{DELETE FROM games_set WHERE games_set_i = ?};
    $r = $dbh->do($qry, undef, $games_set_i);
    if(!$r) { return $dbh->errstr(); }
    if($r != 1) { return "sql_streak_close() assert failure #3"; }
  
  }

  #--- finish

  return [];
}


#============================================================================
# This function get last game's in a streak entry.
#============================================================================

sub sql_streak_get_tail
{
  my $streaks_i = shift;

  my $qry = q{SELECT * FROM streaks };
  $qry .= q{JOIN games_set_map USING (games_set_i) };
  $qry .= q{JOIN games USING (rowid) };
  $qry .= q{WHERE streaks_i = ? ORDER BY endtime DESC LIMIT 1};
  my $sth = $dbh->prepare($qry);
  my $r = $sth->execute($streaks_i);
  if(!$r) { return $sth->errstr(); }
  my $result = $sth->fetchrow_hashref();
  $sth->finish();

  #--- finish 
  
  return $result;
}


#============================================================================
# Create SQL INSERT string from key=value pair has for one line. Note: This
# function also does some modifications to the row of data (here $l) that
# are used later in the processing!
#============================================================================

sub sql_insert_games
{
  my $logfiles_i = shift;
  my $server = shift;
  my $l = shift;
  my @fields;
  my @values;

  #--- reject too old log entries without necessary info
  if(!exists $l->{'conduct'}) { return undef; }
  if(!exists $l->{'starttime'}) { return undef; }
  if(!exists $l->{'endtime'}) { return undef; }
  # NetHack4 has no "realtime" field
  #if(!exists $l->{'realtime'}) { return undef; }
  
  #--- reject wizmode games
  if($l->{'name'} eq 'wizard') { return undef; }

  #--- regular fields
  for my $k (qw(role race gender gender0 align align0 deathdnum deathlev deaths hp maxhp maxlvl points turns realtime version)) {
    if(exists $l->{$k}) {
      push(@fields, $k);
      push(@values, sprintf(q{'%s'}, $l->{$k}));
    }
  }

  #--- name
  push(@fields, 'name');
  if(exists($translations{$server}{$l->{'name'}})) {
    $l->{'name'} = $translations{$server}{$l->{'name'}};
  }
  push(@values, sprintf(q{'%s'}, $l->{'name'}));

  #--- logfiles_i
  push(@fields, 'logfiles_i');
  push(@values, sprintf(q{'%s'},$logfiles_i));
  
  #--- conduct
  push(@fields, 'conduct');
  push(@values, sprintf('%d::bit(16)', eval($l->{'conduct'})));

  #--- achieve
  push(@fields, 'achieve');
  push(@values, sprintf('%d::bit(16)', eval($l->{'achieve'})));
  
  #--- start time
  push(@fields, 'starttime');
  push(@values, sprintf(q{timestamp with time zone 'epoch' + %d * interval '1 second'}, $l->{'starttime'}));
  push(@fields, 'starttime_raw');
  push(@values, $l->{'starttime'});

  #--- end time
  push(@fields, 'endtime');
  push(@values, sprintf(q{timestamp with time zone 'epoch' + %d * interval '1 second'}, $l->{'endtime'}));
  push(@fields, 'endtime_raw');
  push(@values, $l->{'endtime'});

  #--- death (reason)
  my $death = $l->{'death'};
  $death =~ tr[\x{9}\x{A}\x{D}\x{20}-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}][]cd;
  push(@fields, 'death');
  push(@values, sprintf('$nhdb$%s$nhdb$',$death));
  
  #--- ascended flag
  $l->{'ascended'} = sprintf("%d", ($death =~ /^ascended\b/));
  my $flag_ascended = ($death =~ /^ascended\b/ ? 'TRUE' : 'FALSE');
  push(@fields, 'ascended');
  push(@values, $flag_ascended);

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
  return sprintf(
    'INSERT INTO games ( %s ) VALUES ( %s ) RETURNING rowid', 
    join(', ', @fields), 
    join(', ', @values)
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
# Display usage help.
#============================================================================

sub help
{
  print "Usage: nhdb-feeder.pl [options]\n\n";
  print "  --help         get this information text\n";
  print "  --logfiles     display configured logfiles, then exit\n";
  print "  --variant=VAR  limit processing to specified variant(s)\n";
  print "  --server=SRV   limit processing to specified server(s)\n";
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

#--- title

tty_message(
  "\n" .
  "NetHack Statistics Aggregator -- Feeder\n" .
  "=======================================\n" .
  "(c) 2013-14 Mandevil\n\n"
);

#--- process commandline options

my $cmd_logfiles;
my @cmd_variant;
my @cmd_server;

if(!GetOptions(
  'logfiles'  => \$cmd_logfiles,
  'variant=s' => \@cmd_variant,
  'server=s'  => \@cmd_server
)) {
  help();
  exit(1);
}

#--- lock file check/open

if(!$cmd_logfiles) {
  if(-f $lockfile) {
    print "Another instance running\n";
    exit(1);
  }
  open(F, "> $lockfile") || die "Cannot open lock file $lockfile\n";
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
my $qry = q{SELECT * FROM logfiles WHERE oper = 't' ORDER BY logfiles_i ASC};
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
tty_message(
  "Loaded %d configured logfile%s\n",
  scalar(@logfiles),
  (scalar(@logfiles) != 1 ? 's' : '')
);

#--- display logfiles, if requested

if($cmd_logfiles) {
  print "\n";
  for my $log (@logfiles) {
    printf(
      "%-3s  %-3s  %s\n",
      $log->{'server'},
      $log->{'variant'},
      $log->{'logurl'}
    );
  }
  print "\n";
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
tty_message(
  "Loaded %d name translation%s\n",
  $translations_cnt,
  ($translations_cnt != 1 ? 's' : '')
);

#--- check update table
# this code checks if update table has any rows in it;
# when finds none, it assumes it is uninitialized and
# initializes it

tty_message("Checking update table");
my $sth = $dbh->prepare('SELECT count(*) FROM update');
my $r = $sth->execute();
if(!$r) {
  die sprintf("Cannot count update table (%s)", $sth->errstr());
}
my ($cnt_update) = $sth->fetchrow_array();
$sth->finish();
if($cnt_update == 0) {
  tty_message(", failed (no entries)\n");
  tty_message("Initializing update table, step 1");
  $r = $dbh->do(
    'INSERT INTO update ' .
    'SELECT variant, name ' .
    'FROM games LEFT JOIN logfiles USING (logfiles_i) ' .
    'GROUP BY variant, name'
  );
  if(!$r) {
    die sprintf("Failed to initialize the update table (%s)", $sth->errstr());
  } else {
    tty_message(" (%d entries)", $r);
  }
  tty_message(", step 2");
  $r = $dbh->do(
    q{INSERT INTO update } .
    q{SELECT 'all', name, FALSE } .
    q{FROM games LEFT JOIN logfiles USING (logfiles_i) } .
    q{GROUP BY name}
  );
  if(!$r) {
    die sprintf("Failed to initialize the update table (%s)", $sth->errstr());
    } else {
      tty_message(" (%d entries)\n", $r)
    }
} else {
  tty_message(", OK (%d entries)\n", $cnt_update);
}

#--- iterate over logfiles

for my $log (@logfiles) {

  my $transaction_in_progress = 0;
  my $logfiles_i = $log->{'logfiles_i'};

  #--- user selection processing

  next if 
    scalar(@cmd_variant) &&
    !grep { $log->{'variant'} eq lc($_) } @cmd_variant;
  next if
    scalar(@cmd_server) &&
    !grep { $log->{'server'} eq lc($_) } @cmd_server;
  
  eval { # <--- eval starts here -------------------------------------------
  
    #--- prepare, print info
      
    my $localfile = 'logs/' . $log->{'localfile'};
    my @fsize;
    my $fpos = $log->{'fpos'};
    $fsize[0] = -s $localfile;
    tty_message("Processing %s/%s started\n", $log->{'variant'}, $log->{'server'});
    tty_message("  Localfile is %s\n", $localfile);
    tty_message("  Logfile URL is %s\n", $log->{'logurl'}) if $log->{'logurl'};

    #--- retrieve file

    if($log->{'static'}) {
      if($fpos) {
        tty_message("  Skipping already processed static logfile\n");
        die "OK\n";
      }
      tty_message("  Static logfile, skipping retrieval\n");
      $fsize[1] = $fsize[0];
    } elsif(!$log->{'logurl'}) {
      tty_message("  Log URL not defined, skipping retrieval\n");
    } else {
      tty_message("  Getting file from the server");
      $r = system(sprintf('wget -c -q -O %s %s', $localfile, $log->{'logurl'}));
      if($r) { tty_message(", failed\n"); die; }
      $fsize[1] = -s $localfile;
      tty_message(", done (received %d bytes)\n", $fsize[1] - $fsize[0]);
      if(
        $log->{'fpos'}
        && ($fsize[1] - $fsize[0] < 1)
        && ($fsize[0] - $log->{'fpos'} < 1)
      ) {
        tty_message("  No new data, skipping further processing\n");
        $dbh->do(
          'UPDATE logfiles SET lastchk = current_timestamp WHERE logfiles_i = ?',
          undef, $logfiles_i
        );
        die "OK\n";
      }
    }

    #--- open the file

    if(!open(F, $localfile)) {
      tty_message("  Failed to open local file $localfile\n");
      die;
    }

    #--- seek into the file (if position is known)
       
    if($fpos) {
      tty_message("  Seeking to %d\n", $fpos);
      $r = seek(F, $fpos, 0);
      if(!$r) {
        tty_message("Failed to seek to $fpos\n");
        die;
      }
    }
    
    #--- set timezone
    
    tty_message(sprintf("  Setting time zone to %s\n", $log->{'tz'}));
    $r = $dbh->do(sprintf(q{SET TIME ZONE '%s'}, $log->{'tz'})); 
    if(!$r) {
      tty_message("  Failed to set time zone\n");
      die;
    }

    #--- begin transaction
    
    tty_message("  Starting database transaction\n");
    $r = $dbh->begin_work();
    if(!$r) {
      tty_message("  Failed to start database transaction\n");
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

    tty_message("  Processing file %s\n", $localfile);
    
    while(my $l = <F>) { #<<< read loop beings here

      chomp($l);

    #--- devnull logs are special-cased here

      $l =~ s/^.*?\s// if $log->{'server'} eq 'dev';

    #--- parse log
    
      my $pl = parse_log($l);

    #--- insert row into database

      my $rowid;
      $qry = sql_insert_games($logfiles_i, $log->{'server'}, $pl), "\n";
      if($qry) {
        my $sth = $dbh->prepare($qry);
        $r = $sth->execute();
        if(!$r) {
          tty_message("  Failure during inserting new records\n");
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
    # this actually reads games_set_i (reference to game_set representing
    # the streaked games) into %streak_open; if no row is returned the
    # value returned by fetchrow_array() is undef.

        if(!exists($streak_open{$logfiles_i}{$pl->{'name'}})) {
          $qry = q{SELECT games_set_i FROM streaks };
          $qry .= q{WHERE logfiles_i = ? AND name = ? AND open IS TRUE};
          $sth = $dbh->prepare($qry);
          $r = $sth->execute($logfiles_i, $pl->{'name'});
          if(!$r) { die $sth->errstr(); }
          ($streak_open{$logfiles_i}{$pl->{'name'}}) = $sth->fetchrow_array();
          $sth->finish();
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
            die $last_game if !ref($last_game);
            if($last_game->{'endtime_raw'} >= $pl->{'starttime'}) {
              # close current streak
              tty_message("  Closing overlapping streak %d\n",
                $streak_open{$logfiles_i}{$pl->{'name'}}
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
        tty_message("  Processing (%d lines, %d l/sec)\n", $lc, ($lc-$ll)/5 );
        $ll = $lc;
      }
      $lc++;

    } #<<< read loop ends here

    tty_message("  Finished reading (%d lines)\n", $lc);
    
    #--- write update info

    my $re = sql_update_info(\%update_variant, \%update_name);
    if($re) { die $re; }

    #--- update database with new position in the file
    
    $qry = 'UPDATE logfiles SET fpos = ?, lastchk = current_timestamp WHERE logfiles_i = ?';
    $sth = $dbh->prepare($qry);
    $r = $sth->execute($fsize[1], $log->{'logfiles_i'});
    if(!$r) {
      tty_message("  Failed to update table 'servers'\n");
      die;
    }
    
    #--- commit transaction
    
    $r = $dbh->commit();
    $transaction_in_progress = 0;
    if(!$r) {
      tty_message("  Failed to commit transaction\n");
      die;
    }
    tty_message("  Transaction commited\n");
  
  }; # <--- eval ends here -------------------------------------------------
  
  #--- rollback if needed
  
  if($transaction_in_progress) {
    tty_message("  Transaction rollback\n");  
    $dbh->rollback();
  }

  #--- finish
  
  tty_message("  Processing %s/%s finished", $log->{'variant'}, $log->{'server'});
  tty_message(" (with a failure, %s)", $@) if $@ && $@ ne "OK\n";
  tty_message();
}

#--- disconnect from database

dbdone('nhdbfeeder');

#--- release lock file

unlink($lockfile);
