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
use DBI;
use utf8;


#============================================================================
#=== definitions ============================================================
#============================================================================

my $logs = 'logs';
my $lockfile = '/tmp/nhdb-feeder.lock';


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
# Create SQL INSERT string from key=value pair has for one line
#============================================================================

sub sql_insert_games
{
  my $logfiles_i = shift;
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
  for my $k (qw(name role race gender gender0 align align0 deathdnum deathlev deaths hp maxhp maxlvl points turns realtime version)) {
    if(exists $l->{$k}) {
      push(@fields, $k);
      push(@values, sprintf(q{'%s'}, $l->{$k}));
    }
  }

  #--- logfiles_i
  push(@fields, 'logfiles_i');
  push(@values, sprintf(q{'%s'},$logfiles_i));
  
  #--- conduct
  push(@fields, 'conduct');
  push(@values, sprintf('%d::bit(16)', hex($l->{'conduct'})));

  #--- achieve
  push(@fields, 'achieve');
  push(@values, sprintf('%d::bit(16)', hex($l->{'achieve'})));
  
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
    'INSERT INTO games ( %s ) VALUES ( %s )', 
    join(', ', @fields), 
    join(', ', @values)
  );
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

#--- lock file check/open

if(-f $lockfile) {
  print "Another instance running\n";
  exit(1);
}
open(F, "> $lockfile") || die "Cannot open lock file $lockfile\n";
print F $$, "\n";
close(F);

#--- connect to database

my $dbh = DBI->connect(
  'dbi:Pg:dbname=nhdb', 
  'nhdbfeeder', 
  'tO0HYvQLdSG4Muah', 
  { AutoCommit => 1, pg_enable_utf => 1 }
);
if(!ref($dbh)) {
  die sprintf('Failed to connect to the database (%s)', $DBI::errstr);
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

#--- iterate over logfiles

for my $log (@logfiles) {

  next if ($ARGV[0] && ($log->{'server'} ne $ARGV[0]));

  my $transaction_in_progress = 0;
  
  eval { # <--- eval starts here -------------------------------------------
  
    #--- prepare, print info
      
    my $localfile = 'logs/' . $log->{'localfile'};
    my @fsize;
    my $fpos = $log->{'fpos'};
    $fsize[0] = -s $localfile;
    tty_message("Processing %s/%s started\n", $log->{'variant'}, $log->{'server'});
    tty_message("  Localfile is %s\n", $localfile);
    tty_message("  Logfile URL is %s\n", $log->{'logurl'});

    #--- retrieve file

    if($log->{'static'}) {
      tty_message("  Static logfile, skipping retrieval\n");
    } elsif(!$log->{'logurl'}) {
      tty_message("  Log URL not defined, skipping retrieval\n");
    } else {
      tty_message("  Getting file from the server");
      $r = system(sprintf('wget -c -q -O %s %s', $localfile, $log->{'logurl'}));
      if($r) { tty_message(", failed\n"); die; }
      $fsize[1] = -s $localfile;
      tty_message(", done (received %d bytes)\n", $fsize[1] - $fsize[0]);
      if(($fsize[1] - $fsize[0]) < 1 && $log->{'fpos'}) {
        tty_message("  No data received, skipping further processing\n");
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
    
    my $lc = 0;
    my $tm = time();
    my $ll = 0;
    tty_message("  Processing file %s\n", $localfile);
    while(my $l = <F>) {
      chomp($l);
      my $pl = parse_log($l);
      $qry = sql_insert_games($log->{'logfiles_i'}, $pl), "\n";
      if($qry) {
        $r = $dbh->do($qry);
        if(!$r) {
          tty_message("  Failure during inserting new records\n");
          die;
        }
      }
      if((time() - $tm) > 5) {
        $tm = time();
        tty_message("  Processing (%d lines, %d l/sec)\n", $lc, ($lc-$ll)/5 );
        $ll = $lc;
      }
      $lc++;
    }
    tty_message("  Finished reading (%d lines)\n", $lc);
    
    #--- update database with new position in the file
    
    $qry = 'UPDATE logfiles SET fpos = ? WHERE logfiles_i = ?';
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

$dbh->disconnect();

#--- release lock file

unlink($lockfile);
