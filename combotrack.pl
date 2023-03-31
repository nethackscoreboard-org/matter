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
  my $query = "select variant, server, logfiles_i from logfiles";
  print $query . "\n";
  my $re = sql_load($query, 1, 1);
  for(my $i = 0; $i < scalar(@$re); $i++) {
    my $row = $re->[$i];
	$varianti{$row->{'logfiles_i'}} = $row->{'variant'};
	$serveri{$row->{'logfiles_i'}} = $row->{'server'};
	}

	my %excludenames = (
'post163', 1,
'post164', 1,
);

my $finding = 1;
my $rotations = 0;
my %instreak = ();
my @streakrows = ();
my %streaknum = ();
my %streaktypes = ();

$query = "select multikey, name_orig from multistreak where open='t'";
print $query . "\n";
$re = sql_load($query, 1, 1);
for(my $i = 0; $i < scalar(@$re); $i++) {
    my $row = $re->[$i];
	my $multikey = $row->{'multikey'};
	my $name_orig = $row->{'name_orig'};
	$streaknum{$name_orig} = $multikey;
	my $query = "select variant from multi_row where multikey=$multikey";
	my $re2 = sql_load($query, 1, 1);
	for(my $j = 0; $j < scalar(@$re2); $j++) {
		my $row2 = $re2->[$i];
		my $variant = $row2->{'variant'};
		$streaktypes{$name_orig}{$variant} = 1;
	}
}
	if (-f $lockfile) {
		system("rm", $lockfile);
	}
	exit;

my %hasascended = ();
$query = "SELECT gameid, name, variant, role, race, align from ascendtypes";
$re = sql_load($query, 1, 1);
for(my $i = 0; $i < scalar(@$re); $i++) {
    my $row = $re->[$i];
	my $name = $row->{'name'};
	my $variant = $row->{'variant'};
	my $role = $row->{'role'};
	my $race = $row->{'race'};
	my $align = $row->{'align'};
	my $gameid = $row->{'gameid'};
	$hasascended{$name}{$variant}{$role}{$race}{$align} = $gameid;
}

while ($finding) {
	$rotations++;
	$finding = 0;
	my %countlist = ();
	my %gamelist = ();
	my %asclist = ();
	my %pointlist = ();
	my %turnlist = ();
	my %timelist = ();
	my %hplist = ();
	my $uplist = '';
	my %pointhigh = ();
	my %pointlow = ();
	my %turnlow = ();
	my %timelow = ();
	my %hphigh = ();
	my %hplow = ();
	my %conductlist = ();
	my @newasctype = ();
	my %newattempts = ();
	my %newsuccess = ();
  my $query = "SELECT games.rowid, games.logfiles_i, games.death, games.name, games.endtime, games.points, games.realtime, games.ascended, games.turns, games.maxhp, games.role, games.race, games.align0, games.align, games.conduct, games.elbereths, games.achieve, games.name_orig from games where combo is null order by endtime limit 10000";
  print $rotations . "\t" . $query . "\n";
  my %streakcount = ();
  my $re = sql_load($query, 1, 1);
  for(my $i = 0; $i < scalar(@$re); $i++) {
    my $row = $re->[$i];
    my $yr = substr($row->{'endtime'}, 0, 4);
	my $rowid = $row->{'rowid'};
	$uplist .= $rowid . ',';
	if (length($yr) ne 4) {
		next;
	}
	my $name = $row->{'name'};
	if ($excludenames{$name}) {
		next;
	}
	my $ascended = $row->{'ascended'};
	my $turns = $row->{'turns'};
	my $name_orig = $row->{'name_orig'};
    my $variant = $varianti{$row->{'logfiles_i'}};
    my $server = $serveri{$row->{'logfiles_i'}};
    my $death = $row->{'death'};
	my $role = uc($row->{'role'});
	my $race = uc($row->{'race'});
	my $basealign = $row->{'align0'} || $row->{'align'} || 'E';
	my $align = uc(substr($basealign, 0, 1));
	if ($basealign eq 'Non') {
		$align = 'M';
	}
	if (!$align) {
		$align = 'E';
	}
    if ($death =~ / called /) {
	    	my @parts = split(/ called /, $death);
		my $plen = @parts;
		if ($plen eq 2) {
			$death = $parts[0];
		}
    }
	$newattempts{$variant}{$role}{$race}{$align}++;
	$countlist{$name}{$yr}{$variant}{$death}++;
	$countlist{'-'}{$yr}{$variant}{$death}++;

	$gamelist{$name}{$yr}{$variant}{$role}{$race}{$align}++;
	$gamelist{'-'}{$yr}{$variant}{$role}{$race}{$align}++;
	if ($ascended) {
		$newsuccess{$variant}{$role}{$race}{$align}++;
		if (!$hasascended{$name}{$variant}{$role}{$race}{$align}) {
			$hasascended{$name}{$variant}{$role}{$race}{$align} = $rowid;
			push(@newasctype, qq($name|$variant|$role|$race|$align|$rowid));
		}
			  if ($row->{'conduct'}) {
			  	my $variant1 = $nh->variant($variant);
			  	my @c = $variant1->conduct(@{$row}{'conduct', 'elbereths', 'achieve', 'conductX'});
				foreach my $c1 (@c) {
					$conductlist{$name}{$yr}{$variant}{$role}{$race}{$align}{$c1} = 1;
					$conductlist{'-'}{$yr}{$variant}{$role}{$race}{$align}{$c1} = 1;
				}
			}
		$asclist{$name}{$yr}{$variant}{$role}{$race}{$align}++;
		$asclist{'-'}{$yr}{$variant}{$role}{$race}{$align}++;

		my $points = $row->{'points'};
		if ($points > 1) {
			$pointlist{$name}{$yr}{$variant}{$role}{$race}{$align} += $points;
			$pointlist{'-'}{$yr}{$variant}{$role}{$race}{$align} += $points;
			if (!$pointhigh{$name}{$yr}{$variant}{$role}{$race}{$align} || $points > $pointhigh{$name}{$yr}{$variant}{$role}{$race}{$align}) {
				$pointhigh{$name}{$yr}{$variant}{$role}{$race}{$align} = $points;
			}
			if (!$pointhigh{'-'}{$yr}{$variant}{$role}{$race}{$align} || $points > $pointhigh{'-'}{$yr}{$variant}{$role}{$race}{$align}) {
				$pointhigh{'-'}{$yr}{$variant}{$role}{$race}{$align} = $points;
			}
			if (!$pointlow{$name}{$yr}{$variant}{$role}{$race}{$align} || $points < $pointlow{$name}{$yr}{$variant}{$role}{$race}{$align}) {
				$pointlow{$name}{$yr}{$variant}{$role}{$race}{$align} = $points;
			}
			if (!$pointlow{'-'}{$yr}{$variant}{$role}{$race}{$align} || $points < $pointlow{'-'}{$yr}{$variant}{$role}{$race}{$align}) {
				$pointlow{'-'}{$yr}{$variant}{$role}{$race}{$align} = $points;
			}
		}

		if ($turns > 1) {
			#possible multi streak also
			if (!$streaktypes{$name_orig}{$variant}) {
				if (!$streaknum{$name_orig}) {
					$streaknum{$name_orig} = 'pending' . $rowid;
				} else {
					if ($streaknum{$name_orig} =~ /^pending/) {
						my $wasst = $streaknum{$name_orig};
						my $newcount = @streakrows;
						$streaknum{$name_orig} = "new" . $newcount;
						push(@streakrows, $wasst . '|' . $variant . '|' . $server . '|' . $streaknum{$name_orig});
					}
					push(@streakrows, $rowid . '|' . $variant . '|' . $server . '|' . $streaknum{$name_orig});
				}
				$streaktypes{$name_orig}{$variant} = 1;
				$instreak{$name_orig}++;
			}
			#end multi streak logic
			if (!$turnlow{$name}{$yr}{$variant}{$role}{$race}{$align} || $turns < $turnlow{$name}{$yr}{$variant}{$role}{$race}{$align}) {
				$turnlow{$name}{$yr}{$variant}{$role}{$race}{$align} = $turns;
			}
			if (!$turnlow{'-'}{$yr}{$variant}{$role}{$race}{$align} || $turns < $turnlow{'-'}{$yr}{$variant}{$role}{$race}{$align}) {
				$turnlow{'-'}{$yr}{$variant}{$role}{$race}{$align} = $turns;
			}
			$turnlist{$name}{$yr}{$variant}{$role}{$race}{$align} += $turns;
			$turnlist{'-'}{$yr}{$variant}{$role}{$race}{$align} += $turns;
		}

		my $maxhp = $row->{'maxhp'};
		if ($maxhp > 1) {
			if (!$hphigh{$name}{$yr}{$variant}{$role}{$race}{$align} || $maxhp > $hphigh{$name}{$yr}{$variant}{$role}{$race}{$align}) {
				$hphigh{$name}{$yr}{$variant}{$role}{$race}{$align} = $maxhp;
			}
			if (!$hphigh{'-'}{$yr}{$variant}{$role}{$race}{$align} || $maxhp > $hphigh{'-'}{$yr}{$variant}{$role}{$race}{$align}) {
				$hphigh{'-'}{$yr}{$variant}{$role}{$race}{$align} = $maxhp;
			}
			if (!$hplow{$name}{$yr}{$variant}{$role}{$race}{$align} || $maxhp < $hplow{$name}{$yr}{$variant}{$role}{$race}{$align}) {
				$hplow{$name}{$yr}{$variant}{$role}{$race}{$align} = $maxhp;
			}
			if (!$hplow{'-'}{$yr}{$variant}{$role}{$race}{$align} || $maxhp < $hplow{'-'}{$yr}{$variant}{$role}{$race}{$align}) {
				$hplow{'-'}{$yr}{$variant}{$role}{$race}{$align} = $maxhp;
			}
			$hplist{$name}{$yr}{$variant}{$role}{$race}{$align} += $maxhp;
			$hplist{'-'}{$yr}{$variant}{$role}{$race}{$align} += $maxhp;
		}

		my $realtime = $row->{'realtime'};
		if ($realtime > 1) {
			if (!$timelow{$name}{$yr}{$variant}{$role}{$race}{$align} || $realtime < $timelow{$name}{$yr}{$variant}{$role}{$race}{$align}) {
				$timelow{$name}{$yr}{$variant}{$role}{$race}{$align} = $realtime;
			}
			if (!$timelow{'-'}{$yr}{$variant}{$role}{$race}{$align} || $realtime < $timelow{'-'}{$yr}{$variant}{$role}{$race}{$align}) {
				$timelow{'-'}{$yr}{$variant}{$role}{$race}{$align} = $realtime;
			}
			$timelist{$name}{$yr}{$variant}{$role}{$race}{$align} += $realtime;
			$timelist{'-'}{$yr}{$variant}{$role}{$race}{$align} += $realtime;
		}
	} else { #end multistreak
		if ($instreak{$name_orig}) {
			if ($instreak{$name_orig} > 1) {
				push(@streakrows, 'OUT|||' . $streaknum{$name_orig});
			}
			$instreak{$name_orig} = 0;
			delete $streaktypes{$name_orig};
		}
	}
  }

	if (-f $lockfile) {
		system("rm", $lockfile);
	}

  if ($uplist) {
	  $finding = 1;

  #--- eval begin

    eval {

  #--- start transaction

      my $r = $dbh->begin_work();
      if(!$r) {
        $logger->fatal(
          sprintf(
            "Transaction begin failed (%s), aborting batch",
            , $dbh->errstr()
          )
        );
        die "TRFAIL\n";
      }

  #--- run updates
  my $upstmt = "update games set combo='t' WHERE rowid in (" . substr($uplist, 0, -1) . ")";
  $r = $dbh->do($upstmt, undef);
      if(!$r) {
        $logger->fatal(
          sprintf(
            'Failed to update combo in games',
          )
        );
        die "ABORT\n";
      }

	my %multikey1 = ();
	foreach my $st (@streakrows) {
		my ($vari, $variant, $server, $stnum) = split(/\|/, $st);
		if ($vari =~ /^pending/) {
			my $rowid = substr($vari, 7);
			my $query = "select name, name_orig, starttime, endtime from games where rowid=$rowid";
			my $re = sql_load($query, 1, 1);
			my $row = $re->[0];
			my $name = $row->{'name'};
			my $name_orig = $row->{'name_orig'};
			my $starttime = $row->{'starttime'};
			my $endtime = $row->{'endtime'};
			my $upstmt = "insert into multistreak (name, name_orig, starttime, endtime, open) values (?, ?, ?, ?, 't')  RETURNING multikey";
			my $r = $dbh->do($upstmt, undef, $name, $name_orig, $starttime, $endtime);
      if(!$r) {
        $logger->fatal(
          sprintf(
            'Failed to update/insert into multistreak',
          )
        );
        die "ABORT\n";
      }
		$multikey1{$stnum} = $r;
			$upstmt = "insert into multi_row (multikey, variant, server, rowid) values (?, ?, ?, ?)";
			my $r2 = $dbh->do($upstmt, undef, $r, $variant, $server, $rowid);
      if(!$r) {
        $logger->fatal(
          sprintf(
            'Failed to update/insert into multi_row',
          )
        );
        die "ABORT\n";
      }
		} elsif ($vari eq 'OUT') {
			my $upstmt = "update multistreak set open='f' where multikey=?";
			my $r = $dbh->do($upstmt, undef, $multikey1{$stnum});
      if(!$r) {
        $logger->fatal(
          sprintf(
            'Failed to update multistreak',
          )
        );
        die "ABORT\n";
      }
		} else {
			my $multikey = $multikey1{$stnum} || $stnum;
			$upstmt = "insert into multi_row (multikey, variant, server, rowid) values (?, ?, ?, ?)";
			my $r2 = $dbh->do($upstmt, undef, $multikey, $variant, $server, $vari);
      if(!$r) {
        $logger->fatal(
          sprintf(
            'Failed to insert into multi_row',
          )
        );
        die "ABORT\n";
      }
		}
	}

	foreach my $st (@newasctype) {
		my ($name, $variant, $role, $race, $align, $rowid) = split(/\|/, $st);
		my $upstmt = "insert into ascendtypes (gameid, name, variant, role, race, align) values (?, ?, ?, ?, ?, ?)";
		my $r = $dbh->do($upstmt, undef, $rowid, $name, $variant, $role, $race, $align);
      if(!$r) {
        $logger->fatal(
          sprintf(
            'Failed to insert into ascendtypes',
          )
        );
        die "ABORT\n";
      }
	}
  foreach my $variant (keys %newattempts) {
		my $attemptvariant = 0;
		my $successvariant = 0;
	foreach my $role (keys %{$newattempts{$variant}}) {
		my $attemptrole = 0;
		my $successrole = 0;
		foreach my $race (keys %{$newattempts{$variant}{$role}}) {
			my $attemptrace = 0;
			my $successrace = 0;
			foreach my $align (keys %{$newattempts{$variant}{$role}{$race}}) {
				my $attempt = $newattempts{$variant}{$role}{$race}{$align};
				my $success = $newsuccess{$variant}{$role}{$race}{$align} || 0;
				$attemptrace += $attempt;
				$successrace += $success;

  my $query = "SELECT variant from comboease where variant=? and role=? and race=? and align=?";
  my $re = sql_load($query, 1, 1, undef, $variant, $role, $race, $align);
  my $upstmt = '';
  if (scalar(@$re)) {
	$upstmt = "update comboease set attempts=attempts+?, ascend=ascend+? where variant=? and role=? and race=? and align=?";
} else {
	$upstmt = "insert into comboease (attempts, ascend, variant, role, race, align) values (?, ?, ?, ?, ?, ?)";
  }
  $r = $dbh->do($upstmt, undef, $attempt, $success, $variant, $role, $race, $align);
      if(!$r) {
        $logger->fatal(
          sprintf(
            'Failed to update/insert into comboease',
          )
        );
        die "ABORT\n";
      }
			}
			$attemptrole += $attemptrace;
			$successrole += $successrace;
  my $query = "SELECT variant from comboease where variant=? and role=? and race=? and align=?";
  my $re = sql_load($query, 1, 1, undef, $variant, $role, $race, '-');
  my $upstmt = '';
  if (scalar(@$re)) {
	$upstmt = "update comboease set attempts=attempts+?, ascend=ascend+? where variant=? and role=? and race=? and align=?";
} else {
	$upstmt = "insert into comboease (attempts, ascend, variant, role, race, align) values (?, ?, ?, ?, ?, ?)";
  }
  $r = $dbh->do($upstmt, undef, $attemptrace, $successrace, $variant, $role, $race, '-');
      if(!$r) {
        $logger->fatal(
          sprintf(
            'Failed to update/insert into comboease',
          )
        );
        die "ABORT\n";
      }

		}
			$attemptvariant += $attemptrole;
			$successvariant += $successrole;
  my $query = "SELECT variant from comboease where variant=? and role=? and race=? and align=?";
  my $re = sql_load($query, 1, 1, undef, $variant, $role, '-', '-');
  my $upstmt = '';
  if (scalar(@$re)) {
	$upstmt = "update comboease set attempts=attempts+?, ascend=ascend+? where variant=? and role=? and race=? and align=?";
} else {
	$upstmt = "insert into comboease (attempts, ascend, variant, role, race, align) values (?, ?, ?, ?, ?, ?)";
  }
  $r = $dbh->do($upstmt, undef, $attemptrole, $successrole, $variant, $role, '-', '-');
      if(!$r) {
        $logger->fatal(
          sprintf(
            'Failed to update/insert into comboease',
          )
        );
        die "ABORT\n";
      }
	}
  my $query = "SELECT variant from comboease where variant=? and role=? and race=? and align=?";
  my $re = sql_load($query, 1, 1, undef, $variant, '-', '-', '-');
  my $upstmt = '';
  if (scalar(@$re)) {
	$upstmt = "update comboease set attempts=attempts+?, ascend=ascend+? where variant=? and role=? and race=? and align=?";
} else {
	$upstmt = "insert into comboease (attempts, ascend, variant, role, race, align) values (?, ?, ?, ?, ?, ?)";
  }
  $r = $dbh->do($upstmt, undef, $attemptvariant, $successvariant, $variant, '-', '-', '-');
      if(!$r) {
        $logger->fatal(
          sprintf(
            'Failed to update/insert into comboease',
          )
        );
        die "ABORT\n";
      }
}

  foreach my $name (keys %countlist) {
	foreach my $yr (keys %{$countlist{$name}}) {
		foreach my $variant (keys %{$countlist{$name}{$yr}}) {
			foreach my $death (keys %{$countlist{$name}{$yr}{$variant}}) {
  my $query = "SELECT name from deathreason where name=? and year=? and variant=? and death=?";
  my $re = sql_load($query, 1, 1, undef, $name, $yr, $variant, $death);
  my $upstmt = '';
  if (scalar(@$re)) {
	$upstmt = "update deathreason set cnt=cnt+? where name=? and year=? and variant=? and death=?";
} else {
	$upstmt = "insert into deathreason (cnt, name, year, variant, death) values (?, ?, ?, ?, ?)";
  }
  $r = $dbh->do($upstmt, undef, $countlist{$name}{$yr}{$variant}{$death}, $name, $yr, $variant, $death);
      if(!$r) {
        $logger->fatal(
          sprintf(
            'Failed to update/insert into deathreason',
          )
        );
        die "ABORT\n";
      }
  }
  }
  }
  }

#	$gamelist{'-'}{$yr}{$variant}{$role}{$race}{$align}++;
  foreach my $name (keys %gamelist) {
	foreach my $yr (keys %{$gamelist{$name}}) {
		foreach my $variant (keys %{$gamelist{$name}{$yr}}) {
			foreach my $role (keys %{$gamelist{$name}{$yr}{$variant}}) {
				foreach my $race (keys %{$gamelist{$name}{$yr}{$variant}{$role}}) {
					foreach my $align (keys %{$gamelist{$name}{$yr}{$variant}{$role}{$race}}) {
		my $ascended = $asclist{$name}{$yr}{$variant}{$role}{$race}{$align} || 0;
		my $points = $pointlist{$name}{$yr}{$variant}{$role}{$race}{$align} || 0;
		if ($points > 10000000000) {
			$points = 0;
		}
		my $turns = $turnlist{$name}{$yr}{$variant}{$role}{$race}{$align} || 0;
		my $duration = $timelist{$name}{$yr}{$variant}{$role}{$race}{$align} || 0;
		my $hp = $hplist{$name}{$yr}{$variant}{$role}{$race}{$align} || 0;
		my $pointhigh1 = $pointhigh{$name}{$yr}{$variant}{$role}{$race}{$align} || 0;
		my $pointlow1 = $pointlow{$name}{$yr}{$variant}{$role}{$race}{$align} || 0;
		my $turnlow1 = $turnlow{$name}{$yr}{$variant}{$role}{$race}{$align} || 0;
		my $durationlow1 = $timelow{$name}{$yr}{$variant}{$role}{$race}{$align} || 0;
		my $hplow1 = $hplow{$name}{$yr}{$variant}{$role}{$race}{$align} || 0;
		my $hphigh1 = $hphigh{$name}{$yr}{$variant}{$role}{$race}{$align} || 0;
						my @conductsort = ();
						foreach my $cond (keys %{$conductlist{$name}{$yr}{$variant}{$role}{$race}{$align}}) {
							push(@conductsort, $cond);
						}

  my $query = "SELECT name, pointhigh, pointlow, turnlow, durationlow, hplow, hphigh, conducts from frillstats where name=? and year=? and variant=? and role=? and race=? and align=?";
  my $re = sql_load($query, 1, 1, undef, $name, $yr, $variant, $role, $race, $align);
  my $upstmt = '';
  my @addup = ($gamelist{$name}{$yr}{$variant}{$role}{$race}{$align}, $ascended, $points, $turns, $duration, $hp);
  if (scalar(@$re)) {
    my $row = $re->[0];
	my $pointhigh2 = $row->{'pointhigh'};
	my $pointlow2 = $row->{'pointlow'};
	my $turnlow2 = $row->{'turnlow'};
	my $durationlow2 = $row->{'durationlow'};
	my $hplow2 = $row->{'hplow'};
	my $hphigh2 = $row->{'hphigh'};
	my $moreup = '';
	if ($pointhigh1 && $pointhigh1 > $pointhigh2) {
		$moreup .= ", pointhigh=?";
		push(@addup, $pointhigh1);
	}
	if ($pointlow1 && ($pointlow1 < $pointlow2 || !$pointlow2)) {
		$moreup .= ", pointlow=?";
		push(@addup, $pointlow1);
	}
	if ($turnlow1 && ($turnlow1 < $turnlow2 || !$turnlow2)) {
		$moreup .= ", turnlow=?";
		push(@addup, $turnlow1);
	}
	if ($durationlow1 && ($durationlow1 < $durationlow2 || !$durationlow2)) {
		$moreup .= ", durationlow=?";
		push(@addup, $durationlow1);
	}
	if ($hplow1 && ($hplow1 < $hplow2 || !$hplow2)) {
		$moreup .= ", hplow=?";
		push(@addup, $hplow1);
	}
	if ($hphigh1 && $hphigh1 > $hphigh2) {
		$moreup .= ", hphigh=?";
		push(@addup, $hphigh1);
	}
	if (@conductsort) {
		my $conductnum = 0;
		if ($row->{'conducts'}) {
			push(@conductsort, split(/ /, $row->{'conducts'}));
		}
		@conductsort = sort(@conductsort);
		my %iscon = ();
		my $fullconducts = '';
		foreach my $c1 (@conductsort) {
			if (!$iscon{$c1}) {
				$iscon{$c1} = 1;
				$fullconducts .= ' ' . $c1;
				$conductnum++;
			}
		}
		$moreup .= ", conducts=?, conductnum=?";
		push(@addup, substr($fullconducts, 1), $conductnum);
		#print $fullconducts . "\n";
	}

	$upstmt = "update frillstats set games=games+?, ascended=ascended+?, points=points+?, turns=turns+?, duration=duration+?, hp=hp+?$moreup where name=? and year=? and variant=? and role=? and race=? and align=?";
	push(@addup, $name, $yr, $variant, $role, $race, $align);
} else {
	push(@addup, $name, $yr, $variant, $role, $race, $align);
	my $moreup = '';
		$moreup .= ", pointhigh";
		$moreup .= ", pointlow";
		$moreup .= ", turnlow";
		$moreup .= ", durationlow";
		$moreup .= ", hplow";
		$moreup .= ", hphigh";
	if ($pointhigh1) {
		push(@addup, $pointhigh1);
	} else {
		push(@addup, 0);
	}
	if ($pointlow1) {
		push(@addup, $pointlow1);
	} else {
		push(@addup, 0);
	}
	if ($turnlow1) {
		push(@addup, $turnlow1);
	} else {
		push(@addup, 0);
	}
	if ($durationlow1) {
		push(@addup, $durationlow1);
	} else {
		push(@addup, 0);
	}
	if ($hplow1) {
		push(@addup, $hplow1);
	} else {
		push(@addup, 0);
	}
	if ($hphigh1) {
		push(@addup, $hphigh1);
	} else {
		push(@addup, 0);
	}
	my $hasconduct = '';
	my $conductnum = 0;
	if (@conductsort) {
		@conductsort = sort(@conductsort);
		my %iscon = ();
		my $fullconducts = '';
		foreach my $c1 (@conductsort) {
			if (!$iscon{$c1}) {
				$conductnum++;
				$iscon{$c1} = 1;
				$fullconducts .= ' ' . $c1;
			}
		}
		$hasconduct = ', ?';
		$moreup .= ", conducts";
		push(@addup, substr($fullconducts, 1));
		#print $fullconducts . "\n";
	}
	$moreup .= ", conductnum";
	push(@addup, $conductnum);
	$upstmt = "insert into frillstats (games, ascended, points, turns, duration, hp, name, year, variant, role, race, align$moreup) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?$hasconduct)";
  }
  #print $upstmt . "\n";
  #foreach my $ad (@addup) {
  #	  	print $ad . "\t,";
  #	}
 #print "\n";
  $r = $dbh->do($upstmt, undef, @addup);
      if(!$r) {
        $logger->fatal(
          sprintf(
            'Failed to update/insert into frillstats',
          )
        );
        die "ABORT\n";
		exit;
      }
  }
  }
  }
  }
  }
  }


  #--- eval end

    };
    chomp $@;
    if(!$@) {
      my $r = $dbh->commit();
      if(!$r) {
        $logger->fatal(
          sprintf(
            "Failed to commit transaction (%s)",
            $dbh->errstr()
          )
        );
      } else {
        $logger->info("Transaction commited");
      }
    } elsif($@ eq 'ABORT') {
      my $r = $dbh->rollback();
      if(!$r) {
        $logger->fatal(
          sprintf(
            "Failed to abort transaction (%s)",
            $dbh->errstr()
          )
        );
      } else {
        $logger->info("Transaction aborted");
      }
    }
	}
}

