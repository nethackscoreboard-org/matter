#!/usr/bin/env perl

#============================================================================
# NHDB Feeder
# """""""""""
# (c) 2013-2018 Borek Lupomesky
#
# This program scrapes logs from pre-defined NetHack servers and inserts
# game entries into database.
#============================================================================

#--- pragmas ----------------------------------------------------------------

use strict;
use utf8;

#--- external modules -------------------------------------------------------

use DBI;
use Getopt::Long;
use POSIX qw(mktime);
use Log::Log4perl qw(get_logger);
use MIME::Base64 qw(decode_base64);
use Try::Tiny;

#--- internal modules -------------------------------------------------------

#use FindBin qw($Bin);
use lib "$ENV{HOME}/lib";
use NetHack::Config;
use NetHack::Variant;
use NHdb::Config;
use NHdb::Db;
use NHdb::Utils;
use NHdb::Feeder::Cmdline;


#--- additional perl runtime setup ------------------------------------------

$| = 1;


#============================================================================
#=== definitions ============================================================
#============================================================================

my $lockfile = '/tmp/nhdb-feeder.lock';


#============================================================================
#=== globals ================================================================
#============================================================================

my %translations;               # name-to-name translations
my $translations_cnt = 0;       # number of name translation
my $logger;                     # log4perl instance
my $nh = new NetHack::Config(config_file => 'cfg/nethack_def.json');
my $nhdb = NHdb::Config->instance;
my $db;                         # NHdb::Db instance


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
  my $xlog_line = shift;
  my %parsed_line;
  my (@a1, @a2, $a0);

  #--- there are two field separators in use: colon and horizontal tab;
  #--- we use simple heuristics to find out the one that is used for given
  #--- xlogfile row

  @a1 = split(/:/, $xlog_line);
  @a2 = split(/\t/, $xlog_line);
  $a0 = scalar(@a1) > scalar(@a2) ? \@a1 : \@a2;

  #--- split keys and values

  for my $field (@$a0) {
    $field =~ /^(.+?)=(.+)$/;
    $parsed_line{$1} = $2 unless exists $parsed_line{$1};
  }

  #--- if this is enabled for a source (through "logfiles.options"), check
  #--- whether base64 fields exist and decode them

  if(grep(/^base64xlog$/, @{$log->{'options'}})) {
    for my $field (keys %parsed_line) {
      next if $field !~ /^(.+)64$/;
      $parsed_line{$1} = decode_base64($parsed_line{$field});
    }
  }

  #--- finish returning hashref

  return \%parsed_line
}


#============================================================================
# This function returns the WHERE part of SQL query for given
# variants/servers/logid. The arguments are supposed to come from the
# --variant, --server and --logid command-line parameters.
#============================================================================

sub sql_log_select_cond
{
  #--- arguments

  my ($variants, $servers, $logids) = map {
    ref($_) ? $_ : ($_ ? [ $_ ] : []);
  } @_;

  #--- other variables

  my (@cond_var, @cond_srv, @cond_log, @cond, @arg);

  #--- variants

  if(@$variants) {
    push(@cond_var, ('variant = ?') x scalar(@$variants));
    push(@arg, @$variants);
  }

  #--- servers

  if(@$servers) {
    push(@cond_srv, ('server = ?') x scalar(@$servers));
    push(@arg, @$servers);
  }

  #--- logfile ids

  if(@$logids) {
    push(@cond_log, ('logfiles_i = ?') x scalar(@$logids));
    push(@arg, @$logids);
  }

  #--- assemble the final query

  if(@cond_var) {
    push(@cond, '(' . join(' OR ', @cond_var) . ')');
  }
  if(@cond_srv) {
    push(@cond, '(' . join(' OR ', @cond_srv) . ')');
  }
  if(@cond_log) {
    push(@cond, '(' . join(' OR ', @cond_log) . ')');
  }

  return (
    join(' AND ', @cond),
    @arg
  );
}


#============================================================================
# Function to set logfiles.oper and .static fields from command line using
# the --oper and --static options. This function assumes that at least one
# of the $cmd_oper or $cmd_static is defined.
#============================================================================

sub sql_logfile_set_state
{
  #--- arguments

  my (
    $cmd_variant,
    $cmd_server,
    $cmd_logid,
    $cmd_oper,
    $cmd_static
  ) = @_;

  #--- other init

  ($cmd_variant, $cmd_server, $cmd_logid)
  = referentize($cmd_variant, $cmd_server, $cmd_logid);

  my $logger = get_logger('Feeder::Admin');
  $logger->info('Requested oper/static flag change');
  if(@$cmd_variant) {
    $logger->info('Variants: ' . join(',', @$cmd_variant));
  }

  if(@$cmd_server) {
    $logger->info('Servers: ' . join(',', @$cmd_server));
  }

  if(@$cmd_logid) {
    $logger->info('Log ids: ' . join(',', @$cmd_logid));
  }

  #--- on what entries we are going to operate

  my ($cond, @arg) = sql_log_select_cond(
    $cmd_variant, $cmd_server, $cmd_logid
  );

  #--- what are we going to do

  my @set;
  if(defined($cmd_oper)) {
    push(@set, 'oper = ' . ($cmd_oper ? 'TRUE' : 'FALSE'));
  }
  if(defined($cmd_static)) {
    push(@set, 'static = ' . ($cmd_static ? 'TRUE' : 'FALSE'));
  }
  $logger->info('Operation: ', join(', ', @set));

  #--- assemble the query

  my $qry = 'UPDATE logfiles SET ' . join(', ', @set);
  if($cond) {
    $qry .= ' WHERE ' . $cond;
  }

  #--- perform the query

  my $dbh = $db->handle();
  my $r = $dbh->do($qry, undef, @arg);
  if(!$r) {
    $logger->fatal('Database error occured');
    $logger->fatal($dbh->errstr());
    return;
  }
  $logger->info(sprintf('%d rows affected', $r));
}


#============================================================================
# Create new streak entry, add one game to it and return [ streaks_i ] on
# success or error msg.
#============================================================================

sub sql_streak_create_new
{
  my $logfiles_i = shift;
  my $name = shift;
  my $name_orig = shift;
  my $rowid = shift;
  my $logger = get_logger('Streaks');
  my $dbh = $db->handle();

  #--- create new streak entry

  my $qry =
    q{INSERT INTO streaks (logfiles_i, name, name_orig) VALUES (?, ?, ?) };
  $qry .= q{RETURNING streaks_i};
  my $sth = $dbh->prepare($qry);
  my $r = $sth->execute($logfiles_i, $name, $name_orig);
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
  my $dbh = $db->handle();

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
  my $dbh = $db->handle();

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
# This will close all streaks for a given source.
#============================================================================

sub sql_streak_close_all
{
  my $logfiles_i = shift;
  my $logger = get_logger('Streaks');
  my $dbh = $db->handle();

  my $qry = q{UPDATE streaks SET open = FALSE WHERE logfiles_i = ?};
  my $sth = $dbh->prepare($qry);
  my $r = $sth->execute($logfiles_i);
  if(!$r) {
    $logger->error(
      sprintf(
        'sql_streak_close_all(%d) failed to close streaks, errdb=%s',
        $logfiles_i, $dbh->errstr()
      )
    );
    return $sth->errstr();
  }

  #--- finish

  return [ $r ];
}


#============================================================================
# This function gets last game in a streak entry.
#============================================================================

sub sql_streak_get_tail
{
  my $streaks_i = shift;
  my $logger = get_logger('Streaks');
  my $dbh = $db->handle();

  my $qry = q{SELECT * FROM streaks };
  $qry .= q{JOIN map_games_streaks USING (streaks_i) };
  $qry .= q{JOIN games USING (rowid) };
  $qry .= q{WHERE streaks_i = ? ORDER BY endtime DESC, line DESC LIMIT 1};
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

  return $result ? $result : "Last game in streak $streaks_i not found";
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
  my $dbh = $db->handle();

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
    $line_no,          # 2. line number
    $server,           # 3. server id
    $variant,          # 4. variant id
    $xlog_ref         # 5. parsed xlog data to be transformed into SQL
  ) = @_;

  # make a working copy so we can remove some keys, so that we know
  # not to include them as JSON under misc. We do however need to be
  # causing side-effects in the original ref that other parts of code expect
  my %data_hash = %{$xlog_ref};
  my $xlog_data = \%data_hash;

  # by deleting keys from $xlog_data as each one is explicitly processed,
  # any remaining fields in the xlog entry not explicitly recognised can
  # be converted to json, and added to the "misc" field

  #--- other variables
  # @fields is just a list of database fields in table 'games'; values
  # is an array whose elements can appear in two forms: a) simple scalar
  # value; b) sub-array of 1. SQL expression that contains single placeholder
  # 2. simple scalar value. -- this is needed to be able to use placeholders
  # together with SQL expressions as values.

  my @fields;
  my @values;
  my $dbh = $db->handle();

  #--- reject too old log entries without necessary info
  return undef unless $nhdb->require_fields(keys %$xlog_data);

  #--- reject entries with no/empty name, or wizmode/banned paxed test names
  #--- previously the check to reject_name() came before the
  #--- check if a name was defined, this bug is now fixed
  if(!$xlog_data->{'name'} || $nhdb->reject_name($xlog_data->{'name'})) { return undef; }

  if (exists $xlog_data->{'flags'})
  {
    if($xlog_data->{'flags'} =~ s/^0x//)
    {
      $xlog_data->{'flags'} = hex $xlog_data->{'flags'};
    }

    # 0x1 is the flag for WIZARD MODE, 0x2 is EXPLORE (vanilla nethack)
    # 0x4 is the polylinit flag in xNetHack
    if($xlog_data->{'flags'} & 0x1 || $xlog_data->{'flags'} & 0x2)
    {
      return undef;
    }
  }

  #--- reject "special" modes of NH4 and its kin
  #--- Fourk challenge mode is okay, though
  #--- AceHack solo mode is also absolutely *fine*, allow
  if(exists $xlog_data->{'mode'})
  {
    if(!($xlog_data->{'mode'} eq 'normal' || $xlog_data->{'mode'} eq 'challenge' || $xlog_data->{'mode'} eq 'solo')) {
      return undef;
    }
  }

  #--- death (reason)
  my $death = $xlog_data->{'death'};
  $death =~ tr[\x{9}\x{A}\x{D}\x{20}-\x{D7FF}\x{E000}-\x{FFFD}\x{10000}-\x{10FFFF}][]cd;
  push(@fields, 'death');
  push(@values, substr($death, 0, 128));
  delete($xlog_data->{'death'});

  #--- ascended flag
  # this one needs to go to the outer function as a side-effect in order
  # for streaks to work correctly. sweet.
  $xlog_data->{'ascended'} = $death =~ /^(ascended|defied the gods)\b/ ? 1 : 0;
  $xlog_ref->{'ascended'} = $xlog_data->{'ascended'};
  push(@fields, 'ascended');
  push(@values, $xlog_data->{'ascended'} ? 'TRUE' : 'FALSE');
  delete($xlog_data->{'ascended'});

  #--- dNetHack combo mangling workaround
  # please refer to comment in NetHack.pm; this is only done to two specific
  # winning games!
  if($variant eq 'dnh' && $xlog_data->{'ascended'}) {
    ($xlog_data->{'role'}, $xlog_data->{'race'})
    = $nh->variant('dnh')->dnethack_map($xlog_data->{'role'}, $xlog_data->{'race'});
  }

  #--- quit flag (escaped also counts)
  my $flag_quit = 'FALSE';
  $flag_quit = 'TRUE' if $death =~ /^quit\b/;
  $flag_quit = 'TRUE' if $death =~ /^escaped\b/;
  push(@fields, 'quit');
  push(@values, $flag_quit);

  #--- scummed flag
  # need to do this before going through regular fields,
  # otherwise $xlog_data->{'points'} will be deleted
  my $flag_scummed = 'FALSE';
  if($flag_quit eq 'TRUE' && $xlog_data->{'points'} < 1000) {
    $flag_scummed = 'TRUE'
  }
  push(@fields, 'scummed');
  push(@values, $flag_scummed);

  #--- user-set seed flag
  push(@fields, 'user_seed');
  if(exists $xlog_data->{'user_seed'}) {
    # afaik variants with setseed set this field to either 1 or 0
    # TODO: double-check this for UnNetHack
    if ($xlog_data->{'user_seed'} eq '0') {
      push(@values, 'FALSE');
    } else {
      push(@values, 'TRUE');
    }
    delete($xlog_data->{'user_seed'});
  } else {
    push(@values, 'FALSE');
  }

  #--- regular fields
  for my $k ($nhdb->regular_fields()) {
    if(exists $xlog_data->{$k}) {
      push(@fields, $k);
      push(@values, $xlog_data->{$k});
      delete($xlog_data->{$k});
    }
  }

  #--- name (before translation)
  push(@fields, 'name_orig');
  push(@values, $xlog_data->{'name'});
  $xlog_ref->{'name_orig'} = $xlog_data->{'name'};

  #--- name
  push(@fields, 'name');
  if(exists($translations{$server}{$xlog_data->{'name'}})) {
    $xlog_data->{'name'} = $translations{$server}{$xlog_data->{'name'}};
    $xlog_ref->{'name'} = $xlog_data->{'name'};
  }
  push(@values, $xlog_data->{'name'});
  delete($xlog_data->{'name'});

  #--- logfiles_i
  push(@fields, 'logfiles_i');
  push(@values, $logfiles_i);

  #--- line number
  push(@fields, 'line');
  push(@values, $line_no);

  #--- conduct
  if($xlog_data->{'conduct'}) {
    push(@fields, 'conduct');
    push(@values, eval($xlog_data->{'conduct'}));
    delete($xlog_data->{'conduct'});
  }

  #--- achieve
  if(exists $xlog_data->{'achieve'}) {
    push(@fields, 'achieve');
    push(@values, eval($xlog_data->{'achieve'}));
    delete($xlog_data->{'achieve'});
  }

  #--- start time
  if(exists $xlog_data->{'starttime'})
  {
    push(@fields, 'starttime');
    push(@values, [ q{timestamp with time zone 'epoch' + ? * interval '1 second'}, $xlog_data->{'starttime'} ]);
    push(@fields, 'starttime_raw');
    push(@values, $xlog_data->{'starttime'});
    delete($xlog_data->{'starttime'});
    delete($xlog_data->{'birthdate'});
  }
  #--- birth date
  elsif(exists $xlog_data->{'birthdate'} && $xlog_data->{'birthdate'} =~ /^(\d{4})(\d{2})(\d{2})$/) {
    my $timestamp = mktime($1, $2, $3, '00', '00');
    push(@fields, 'starttime');
    push(@values, [ q{timestamp with time zone 'epoch' + ? * interval '1 second'}, $timestamp ]);
    push(@fields, 'starttime_raw');
    push(@values, $timestamp);
    delete($xlog_data->{'birthdate'});
  }
  #--- else impossible/panic/error?

  #--- end time
  if(exists $xlog_data->{'endtime'}) {
    push(@fields, 'endtime');
    push(@values, [ q{timestamp with time zone 'epoch' + ? * interval '1 second'}, $xlog_data->{'endtime'} ]);
    push(@fields, 'endtime_raw');
    push(@values, $xlog_data->{'endtime'});
    delete($xlog_data->{'endtime'});
    delete($xlog_data->{'deathdate'});
  }
  #--- death date
  elsif(exists $xlog_data->{'deathdate'} && $xlog_data->{'birthdate'} =~ /^(\d{4})(\d{2})(\d{2})$/) {
    my $timestamp = mktime($1, $2, $3, '23', '59');
    push(@fields, 'endtime');
    push(@values, [ q{timestamp with time zone 'epoch' + ? * interval '1 second'}, $timestamp ]);
    push(@fields, 'endtime_raw');
    push(@values, $timestamp);
    delete($xlog_data->{'deathdate'});
  }
  #--- else impossible/panic/error?
  

  # encode misc fields as JSON
  # uid is irrelevant however
  delete($xlog_data->{'uid'});
  my $json = JSON->new;
  my $json_text = $json->encode($xlog_data);
  push(@fields, 'misc');
  push(@values, $json_text);

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
  my $dbh = $db->handle();

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

  my ($variants, $servers, $logids) = referentize(@_);

  #--- other variables

  my $dbh = $db->handle();

  #--- init logging

  my $logger = get_logger('Feeder::Purge_db');
  $logger->info('Requested database purge');
  if(@$variants) {
    $logger->info('Variants: ' . join(',', @$variants));
  }

  if(@$servers) {
    $logger->info('Servers: ' . join(',', @$servers));
  }

  if(@$logids) {
    $logger->info('Log ids: ' . join(',', @$logids));
  }

  #--- get list of logfiles we will be operating on

  my @logfiles;
  my ($cond, @arg) = sql_log_select_cond(@_);
  my $qry = 'SELECT * FROM logfiles' . ($cond ? (' WHERE ' . $cond) : '');
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
        'UPDATE logfiles SET fpos = NULL, lines = 0 WHERE logfiles_i = ?',
        undef, $logfiles_i
      );
      if(!$r) {
        $logger->fatal(
          sprintf(
            '[%s/%s] Failed to reset the fpos/lines fields',
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
# Function for listing/adding/removing player name mappings using the --pmap
# options (--pmap-list, --pmap-add, --pmap-remove).
#
# If no argument is given, existing mappings are listed.
# Otherwise, the arguments have the form: SRCNAME/SRV=DSTNAME. When DSTNAME
# is present, a mapping is added. If DSTNAME is missing, a mapping is
# removed. The removes are performed before the additions.
#
# Returns undef on success of error message.
#============================================================================

sub sql_player_name_map
{
  #--- init

  my $logger = get_logger('Feeder::Admin');
  my $dbh = $db->handle();
  my $in_transaction = 0;
  my $r;

  #--- eval loop

  eval {

  #--- listing all configured mappings

    if(!@_) {
      $logger->info('Listing configured player name mappings');
      my $cnt = 0;
      my $sth = $dbh->prepare('SELECT * FROM translations ORDER BY name_to');
      $r = $sth->execute();
      if(!$r) {
        die 'Failed to query database (' . $sth->errstr() . ") \n";
      } else {
        $logger->info('source               | destination');
        $logger->info('-' x (20+16+3));
        while(my $row = $sth->fetchrow_hashref()) {
          $logger->info(
            sprintf(
              "%-20s | %-16s\n",
              $row->{'server'} . '/' . $row->{'name_from'},
              $row->{'name_to'}
            )
          );
          $cnt++;
        }
        $logger->info('-' x (20+16+3));
        $logger->info(
          sprintf('%d mappings configured', $cnt)
        );
      }
      return undef;
    }

  #--- start transaction

    $r = $dbh->begin_work();
    if(!$r) {
      die sprintf("Cannot begin database transaction (%s)\n", $dbh->errstr());
    }
    $in_transaction = 1;

  #--- loop over arguments and create update plan

  # We are creating separate plans for adding and removing so that removing
  # can go before adding.

    my (@plan_add, @plan_remove);
    for my $arg (@_) {
      if($arg =~ /
        ^
        (?<src>[a-zA-Z0-9]+)         # 1. source (server-specific) name
        \/                           #    slash (separator)
        (?<srv>[a-zA-Z0-9]{3})       # 2. server id
        (?:
          =                          #    = sign (separator)
          (?<dst>[a-zA-Z0-9]+)       # 3. destination (aggregate) name
        )?
        $
      /x) {
        if($+{'dst'}) {
          push(@plan_add, {
            src => $+{'src'}, srv => $+{'srv'}, dst => $+{'dst'}
          });
        } else {
          push(@plan_remove, {
            src => $+{'src'}, srv => $+{'srv'}
          });
        }
      }
    }

  #--- perform removals

    for my $row (@plan_remove) {
      my $s;
      $r = $dbh->do(
        'DELETE FROM translations WHERE server = ? AND name_from = ?',
        undef, $row->{'srv'}, $row->{'src'}
      );
      if($r) {
        $r = $dbh->do(
          'UPDATE games g SET name = name_orig FROM logfiles l ' .
          'WHERE g.logfiles_i = l.logfiles_i AND name_orig = ? AND server = ?',
          undef, $row->{'src'}, $row->{'srv'}
        );
        if($r) {
          $s = $dbh->do(
            'UPDATE streaks s SET name = name_orig FROM logfiles l ' .
            'WHERE s.logfiles_i = l.logfiles_i AND name_orig = ? AND server = ?',
            undef, $row->{'src'}, $row->{'srv'}
          );
        }
      }
      if(!$r || !$s) {
        die sprintf "Failed to update database (%s)\n", $dbh->errstr();
      }
      $logger->info(sprintf(
        'Removed mapping %s/%s, updated %d games, %d streaks',
        $row->{'srv'}, $row->{'src'}, $r, $s
      ));
    }

  #--- perform additions

    for my $row (@plan_add) {
      my $s;
      $r = $dbh->do(
        'INSERT INTO translations ( server,name_from,name_to ) ' .
        'VALUES ( ?,?,? )',
        undef, $row->{'srv'}, $row->{'src'}, $row->{'dst'}
      );
      if($r) {
        $r = $dbh->do(
          'UPDATE games g SET name = ? FROM logfiles l ' .
          'WHERE g.logfiles_i = l.logfiles_i AND name_orig = ? AND server = ?',
          undef, $row->{'dst'}, $row->{'src'}, $row->{'srv'}
        );
        if($r) {
          $s = $dbh->do(
            'UPDATE streaks s SET name = ? FROM logfiles l ' .
            'WHERE s.logfiles_i = l.logfiles_i AND name_orig = ? AND server = ?',
            undef, $row->{'dst'}, $row->{'src'}, $row->{'srv'}
          );
        }
      }
      if(!$r || !$s) {
        die sprintf "Failed to update database (%s)\n", $dbh->errstr();
      }
      $logger->info(sprintf(
        'Added mapping %s/%s to %s, updated %d games, %d streaks',
        $row->{'srv'}, $row->{'src'}, $row->{'dst'}, $r, $s
      ));
    }

  #--- eval end

  };
  if($@) {
    my $err = $@;
    chomp($err);
    $logger->error($err);
    if($in_transaction) {
      $r = $dbh->rollback();
      if(!$r) {
        $logger->error(
          sprintf('Failed to abort transaction (%s)', $dbh->errstr())
        );
        $err = $err . sprintf(', transaction not aborted (%s)', $dbh->errstr());
      } else {
        $logger->error('Transaction aborted, no changes made');
        $err = $err . ', transaction aborted';
      }
    }
    return $err;
  }

  #--- commit transaction

  if($in_transaction) {
    $r = $dbh->commit();
    if(!$r) {
      return sprintf(
        'Failed to commit database transaction (%s)', $dbh->errstr()
      );
    }
    $logger->info('Changes commited');
  }

  #--- finish successfully

  return undef;
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

Log::Log4perl->init("$ENV{HOME}/cfg/logging.conf");
$logger = get_logger('Feeder');

#--- title

$logger->info('NetHack Scoreboard / Feeder');
$logger->info('(c) 2013-2020 Borek Lupomesky');
$logger->info('(c) 2020-2100 Dr. Joanna Irina Zaitseva-Kinneberg');
$logger->info('---');

#--- process commandline options

my $cmd = NHdb::Feeder::Cmdline->instance(lockfile => $lockfile);

#--- lock file check/open

try {
  $cmd->lock;
} catch {
  chomp;
  $logger->warn($_);
  exit(1);
};

#--- connect to database

$db = NHdb::Db->new(id => 'nhdbfeeder', config => $nhdb);
my $dbh = $db->handle();
die "Undefined database handle" if !$dbh;

#--- process --oper and --static options

if(defined($cmd->operational()) || defined($cmd->static())) {
  sql_logfile_set_state(
    $cmd->variants(),
    $cmd->servers(),
    $cmd->logid(),
    $cmd->operational(),
    $cmd->static()
  );
  exit(0);
}

#--- process --pmap options

my (@cmd_pmap_add, @cmd_pmap_remove);

if($cmd->pmap_list()) {
  my $r = sql_player_name_map();
  exit($r ? 1 : 0);
}

if($cmd->pmap_add() || $cmd->pmap_remove()) {
  @cmd_pmap_add =
    grep { /^[a-zA-Z0-9]+\/[a-zA-Z0-9]+=[a-zA-Z0-9]+$/ } @{$cmd->pmap_add()}
    if $cmd->pmap_add();
  @cmd_pmap_remove =
    grep { /^[a-zA-Z0-9]+\/[a-zA-Z0-9]+$/ } @{$cmd->pmap_remove()}
    if $cmd->pmap_remove();
  my $r = 1;
  if(scalar(@cmd_pmap_add) + scalar(@cmd_pmap_remove)) {
    $r = sql_player_name_map(@cmd_pmap_add, @cmd_pmap_remove);
  } else {
    $logger->fatal('No valid maps');
  }
  exit($r ? 1 : 0);
}

#--- get list of logfiles to process

my @logfiles;
my @qry;

push(@qry, q{SELECT * FROM logfiles});
push(@qry, q{WHERE oper = 't'}) unless $cmd->show_logfiles();
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

if($cmd->show_logfiles()) {
  $logger->info('Displaying configured logfiles (--logfiles option)');
  $logger->info('');
  $logger->info('* disabled sources, + static sources');
  $logger->info('');
  $logger->info('rowid  srv var descr');
  $logger->info('------ --- --- ' . '-' x 42);
  for my $log (@logfiles) {

    my $s = ' ';
    if($log->{'static'}) { $s = '+'; }
    if(!$log->{'oper'}) { $s = '*'; }

    $logger->info(
      sprintf(
        "%5d%1s %-3s %-3s %s\n",
        $log->{'logfiles_i'},
        $s,
        $log->{'server'},
        $log->{'variant'},
        substr($log->{'descr'}, 0, 48)
      )
    );
  }
  exit(0);
}

#--- database purge

if($cmd->purge()) {
  sql_purge_database($cmd->variants(), $cmd->servers(), $cmd->logid());
  unlink($lockfile);
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
    @{$cmd->variants()} &&
    !grep { $log->{'variant'} eq lc($_) } @{$cmd->variants()};
  next if
    scalar(@{$cmd->servers()}) &&
    !grep { $log->{'server'} eq lc($_) } @{$cmd->servers()};
  next if
    $cmd->logid() &&
    $log->{'logfiles_i'} != $cmd->logid();

  eval { # <--- eval starts here -------------------------------------------

    #--- prepare, print info

    my $localfile = sprintf(
      '%s/%s',
      $nhdb->config()->{'logs'}{'localpath'},
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
      $logger->info($lbl, 'Static logfile, skipping retrieval');
      $fsize[1] = $fsize[0];
    } elsif(!$log->{'logurl'}) {
      $logger->warn($lbl, 'Log URL not defined, skipping retrieval');
    } else {
      $logger->info($lbl, 'Getting logfile from the server');
      $r = system(
        sprintf($nhdb->config()->{'wget'}, $localfile, $log->{'logurl'})
      );
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
    my $devnull;          # devnull xlogfile option

    $devnull = grep(/^devnull$/, @{$log->{'options'}});

    $logger->info($lbl, 'Processing file ', $localfile);

    while(my $xlog_line = <F>) { #<<< read loop beings here

      chomp($xlog_line);

    #--- devnull logfiles are slightly modified by having a server id
    #--- prepended to the usual xlogfile line

      if($devnull) {
        $xlog_line =~ s/^\S+\s(.*)$/$1/;
      }

    #--- parse log

      my $parsed_line = parse_log($log, $xlog_line);

    #--- insert row into database

      my ($rowid, $values);
      ($qry, $values) = sql_insert_games(
        $logfiles_i,
        $log->{'lines'} + $lc,
        $log->{'server'},
        $log->{'variant'},
        $parsed_line
      );
      if($qry) {
        my $sth = $dbh->prepare($qry);
        $r = $sth->execute(@$values);
        if(!$r) {
          $logger->error($lbl, 'Failure during inserting new records');
          $logger->error($lbl, sql_show_query($qry, $values));
          $logger->error($lbl, $sth->errstr());
          die;
        }
        ($rowid) = $sth->fetchrow_array();
        $sth->finish();

    #--- mark updates
    # FIXME: There's subtle potential issue with this, since
    # scummed games do trigger these updates; I haven't decided
    # if we want this or not.

        $update_variant{$log->{'variant'}} = 1;
        $update_name{$parsed_line->{'name'}}{$log->{'variant'}} = 1;

    #-------------------------------------------------------------------------
    #--- streak processing starts here ---------------------------------------
    #-------------------------------------------------------------------------

    #--- initialize streak status for name

    # if the streak status is not yet stored in memory, which happens when
    # we first encounter (logfiles_i, name) pair, it is loaded from database
    # (table "streaks")

        if(!exists($streak_open{$logfiles_i}{$parsed_line->{'name'}})) {
          $r = sql_streak_find($logfiles_i, $parsed_line->{'name'});
          die $r if !ref($r);
          $streak_open{$logfiles_i}{$parsed_line->{'name'}} = $r->[0];
        }

    #--- game is ASCENDED

        if($parsed_line->{'ascended'}) {

    #--- game is ASCENDED / streak is NOT OPEN

          if(!$streak_open{$logfiles_i}{$parsed_line->{'name'}}) {
            my $streaks_i = sql_streak_create_new(
              $logfiles_i,
              $parsed_line->{'name'},
              $parsed_line->{'name_orig'},
              $rowid
            );
            die $streaks_i if !ref($streaks_i);
            $streak_open{$logfiles_i}{$parsed_line->{'name'}} = $streaks_i->[0]
          }

    #--- game is ASCENDED / streak is OPEN
    # we are checking for overlap between the last game of the streak
    # and the current game; if there is overlap, the streak is broken;
    # NOTE: overlap can only be checked when starttime/endtime fields
    # actually exist! This is not fulfilled for NAO games before
    # March 19, 2018.

          else {
            my $last_game = sql_streak_get_tail(
              $streak_open{$logfiles_i}{$parsed_line->{'name'}}
            );
            if(!ref($last_game)) {
              die sprintf(
                'sql_streak_get_tail(%s) failed with msg "%s"',
                $streak_open{$logfiles_i}{$parsed_line->{'name'}}, $last_game
              );
            }
            if(
              $last_game->{'endtime_raw'}
              && $parsed_line->{'starttime'}
              && $last_game->{'endtime_raw'} >= $parsed_line->{'starttime'}
            ) {
              # close current streak
              $logger->info($lbl,
                sprintf('Closing overlapping streak %d', $streak_open{$logfiles_i}{$parsed_line->{'name'}})
              );
              $r = sql_streak_close(
                $streak_open{$logfiles_i}{$parsed_line->{'name'}}
              );
              die $r if !ref($r);
              # open new
              $r = sql_streak_create_new(
                $logfiles_i,
                $parsed_line->{'name'},
                $parsed_line->{'name_orig'},
                $rowid
              );
              die $r if !ref($r);
              $streak_open{$logfiles_i}{$parsed_line->{'name'}} = $r->[0];
            } else {
              $r = sql_streak_append_game(
                $streak_open{$logfiles_i}{$parsed_line->{'name'}},
                $rowid
              );
              die $r if !ref($r);
            }
          }
        }

    #--- game is not ASCENDED

        else {

    #--- game is not ASCENDED / streak is OPEN

          if($streak_open{$logfiles_i}{$parsed_line->{'name'}}) {
            $r = sql_streak_close(
              $streak_open{$logfiles_i}{$parsed_line->{'name'}}
            );
            die $r if !ref($r);
            $streak_open{$logfiles_i}{$parsed_line->{'name'}} = undef;
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

    #--- close streak for 'static' sources

    if($log->{'static'}) {
      my $re = sql_streak_close_all($logfiles_i);
      if(!ref($re)) {
        $logger->error($lbl, q{Failed to close all streaks});
        die;
      }
      if($re->[0]) {
        $logger->info($lbl, sprintf('Closed %d streak(s)', $re->[0]));
      }
    }

    #--- write update info

    my $re = sql_update_info(\%update_variant, \%update_name);
    if($re) { die $re; }

    #--- update database with new position in the file

    my @logupdate = (
      'fpos = ?',
      'lastchk = current_timestamp',
      'lines = ?'
    );

    if($log->{'static'}) { push(@logupdate, 'oper = false'); }
    $qry = sprintf(
      'UPDATE logfiles SET %s WHERE logfiles_i = ?', join(', ', @logupdate)
    );
    $sth = $dbh->prepare($qry);
    $r = $sth->execute(
      $fsize[1],
      $log->{'lines'} + $lc,
      $log->{'logfiles_i'}
    );
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

#--- release lock file

$cmd->unlock;
