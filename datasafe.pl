#!/usr/bin/env perl

#============================================================================
# NHDB Stat Generator
# """""""""""""""""""
# (c) 2013-2100 Borek Lupomesky
# (c) 2020-2100 Dr. Joanna Irina Zaitseva-Kinneberg
#============================================================================

BEGIN {
  my $srv = $ENV{NHS_SRV_HOME} // ".";
  unshift @INC, "$srv/lib";
}

use strict;
use warnings;
use bignum;
use feature 'state';
use utf8;

use Moo;
use Data::Dumper;
use DBI;
use JSON;
use Getopt::Long;
use List::MoreUtils qw(uniq);
use Try::Tiny;
use NetHack::Config;
use NetHack::Variant;
use NHdb::Config;
use NHdb::Db;
use NHdb::Stats::Cmdline;
use NHdb::Utils;
use Template;
use Log::Log4perl qw(get_logger);
use POSIX qw(strftime);


$| = 1;

my $tot = 0;

#============================================================================
#=== globals ================================================================
#============================================================================

my $prefix = $ENV{NHS_SRV_HOME} // ".";

#--- list of sources ('logfiles') loaded from database

my $logfiles;

#--- Log4Perl instance

my $logger;              # log4perl primary instance

#--- NetHack::Config instance

my $nh = new NetHack::Config(
  config_file => "$prefix/cfg/nethack_def.json"
);

#--- NHdb::Config instance

my $nhdb = NHdb::Config->instance;

#--- NHdb::Db instance (initalized later)

my $db;


#--- aggregate and summary pages generators

# this hash contains code references to code that generates aggregate pages;

#============================================================================
#=== definitions ============================================================
#============================================================================

my $lockfile = "/tmp/nhdb-combo.lock";

#--- process command-line

my $logger_cmd = get_logger("Stats::Cmdline");

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
  my $dbh = $db->handle();

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
# Some additional processing of a row of data from games table (formats
# fields into human readable format, mostly).
#============================================================================

sub row_fix
{
  my $row = shift;
  my $logfiles_i = $row->{'logfiles_i'};
  my $logfile = $logfiles->{$logfiles_i};
  my $variant = $nh->variant($row->{'variant'});

  $tot++;
  if ($tot =~ /000$/) {
	  print "t $tot\n";
  }
  #--- extract extra fields from misc_json
  my $json = JSON->new;
  if($row->{'misc'}) {
    my $data = $json->decode($row->{'misc'});
    foreach my $key (keys %$data)
    {
      if (!defined $row->{$key})
      {
	      print $key . "\t" . $data->{$key} . "\n";
        $row->{$key} = $data->{$key};
      }
      else
      {
	      print $key . "\t" . $data->{$key} . "\tSB\n";
        $row->{"_$key"} = $data->{$key};
      }
    }
  }

  #--- convert realtime to human-readable form

  if($row->{'realtime'}) {
    $row->{'realtime_raw'} = defined $row->{'realtime'} ? $row->{'realtime'} : 0;
    $row->{'realtime'} = format_duration($row->{'realtime'});
  }

  #--- convert wallclock to human-readable form

  if($row->{'wallclock'}) {
    $row->{'wallclock_raw'} = defined $row->{'wallclock'} ? $row->{'wallclock'} : 0;
    $row->{'wallclock'} = format_duration($row->{'wallclock'});
  }

  #--- format version string

  $row->{'version'} = nhdb_version($row->{'version'});

  #--- include conducts in the ascended message

  if($row->{'ascended'}) {
    if (defined $row->{'conduct'}) {
      my @c = $variant->conduct(@{$row}{'conduct', 'elbereths', 'achieve', 'conductX'});
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


  #--- player page

  $row->{'plrpage'} = url_substitute(
    sprintf("players/%%U/%%u.%s.html", $row->{'variant'}),
    $row
  );

  #--- truncate time if needed
  #--- this is not a perfect test, but if the start time and end time match
  #--- $date 00:00:00 and $date 23:59:59 (respectively), they were probably
  #--- upgraded from old xlogs with only birthdate and deathdate
  my @st = gmtime($row->{'starttime_raw'});
  my @et = gmtime($row->{'endtime_raw'});
  my $st_hhmmss = strftime("%H:%M:%S", @st);
  my $et_hhmmss = strftime("%H:%M:%S", @et);
  if($st_hhmmss eq '00:00:00' && $et_hhmmss eq '23:59:59') {
    $row->{'endtime_fmt'} =~ s/\s.*$//;
  }
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

Log::Log4perl->init("$prefix/cfg/logging.conf");
$logger = get_logger('Stats');

#--- connect to database

$db = NHdb::Db->new(id => 'nhdbfeeder', config => $nhdb);
my $dbh = $db->handle();
$logger->info('Connected to database');

#
my $process;

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

	print "BEGIN\n";
	my $time1 = time();
$db = NHdb::Db->new(id => 'nhdbfeeder', config => $nhdb);
  my $dbhup = $db->handle();


my %varianti = ();
my %serveri = ();
my $stayin = 1;
my $rowid = 0;
my %already = ();
my $total = 0;
my $dupe = 0;
my @dupes = ();
my $starttime = time();
while ($stayin) {
	$stayin = 0;
  my $query = "select rowid, starttime_raw, name, logfiles_i, endtime_raw, turns, death, points, role, hp, maxhp, ascended from games where rowid > $rowid order by rowid limit 40000";
  print $rowid . "\t" . $total . ' (' . $dupe . ') ' . $query . "\n";
  my $re = sql_load($query, 1, 1);
  for(my $i = 0; $i < scalar(@$re); $i++) {
	$total++;
	$stayin = 1;
    my $row = $re->[$i];
	$rowid = $row->{'rowid'};
	my $starttime_raw = $row->{'starttime_raw'} || '';
	my $name = $row->{'name'} || '';
	my $logfiles_i = $row->{'logfiles_i'} || '';
	my $endtime_raw = $row->{'endtime_raw'} || '';
	my $turns = $row->{'turns'} || '';
	my $death = $row->{'death'} || '';
	my $points = $row->{'points'} || '';
	my $role = $row->{'role'} || '';
	my $hp = $row->{'hp'} || '';
	my $maxhp = $row->{'maxhp'} || '';
	my $ascended = $row->{'ascended'};
	my $key = $starttime_raw . '|' . $name . '|' . $logfiles_i . '|' . $endtime_raw . '|' . $turns . '|' . $death . '|' . $points . '|' . $role . '|' . $hp . '|' . $maxhp . '|' . $ascended;
	if ($already{$key}) {
		if ($death ne 'escaped' && $death ne 'quit' && ($starttime_raw > 1289382399 || $turns > 0 || $ascended)) {
			print $key . "\n";
			my $stmt = "delete from games where rowid=$rowid";
			print $stmt . "\n";
			my $r = $dbh->do($stmt, undef);
			$dupe++;
			push(@dupes, $key);
		}
	}
	$already{$key} = 1;
	}
}

if (@dupes) {
	open(my $hand, ">$prefix/duplicategames-$starttime.txt");
	foreach my $dp (@dupes) {
		print $hand $dp . "\n";
	}
	close($hand);
}
