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

open(my $hand1, "<", "/root/nrepo/formatmulti.txt");
my $mainline = '';
foreach my $ln (<$hand1>) {
	$mainline .= $ln;
}
close($hand1);

open(my $hand2, "<", "/root/nrepo/multistreaks.html");
my $fullpage = '';
foreach my $ln (<$hand2>) {
	$fullpage .= $ln;
}
close($hand2);

open(my $hand, "<", "/root/nrepo/multistreak.txt");
my @liststreaks = <$hand>;
close($hand);
my $needlines = 0;
my $holdname = '';
my @rows = ();
my $lines = '';
my $turns = 0;
my $start = '';
my $end = '';

my @sortlist = ();

foreach my $l1 (@liststreaks) {
	if ($l1 =~ /\t/) {
		$l1 =~ s/\n//g;
		$l1 =~ s/\r//g;
		my @parts = split(/\t/, $l1);
		my $lpart = @parts;
		if ($lpart eq 2) {
			$holdname = $parts[0];
			$needlines = $parts[1];
			@rows = ();
			$turns = 0;
			$start = '';
			$end = '';
			print $l1 . "\n";
		} elsif ($needlines > 0) {
			my ($variant, $server, $combo, $points, $gameturns, $endtime, $conduct) = @parts;
			if (!$start) {
				$start = $endtime;
			}
			$turns += $gameturns;
			$needlines--;
			push(@rows, $l1);
			if ($needlines <= 0) {
				my $wins = @rows;
				$end = $endtime;
				my $dturns = $turns;
				print "d: $dturns\n";
				my $rett = '';
				while (length($dturns) > 3) {
					$rett = ',' . substr($dturns, -3) . $rett;
					$dturns = substr($dturns, 0, -3);
				}
				$dturns .= $rett;
				my $letter = substr($holdname, 0, 1);
				my $tline = $mainline;
				$tline =~ s/~wins~/$wins/g;
				$tline =~ s/~name~/$holdname/g;
				$tline =~ s/~letter~/$letter/g;
				$tline =~ s/~turns~/$dturns/g;
				$tline =~ s/~start~/$start/g;
				$tline =~ s/~end~/$end/g;
				my $combos = '';
				foreach my $row1 (@rows) {
					my ($variant, $server, $combo, $points, $gameturns, $endtime, $conduct) = split(/\t/, $row1);
					if ($combos) {
						$combos .= "<br>\n";
					}
					$combos .= $variant . ' played on ' . $server . ' combo: ' . $combo . ' Turns: ' . $gameturns;
				}
				$tline =~ s/~combos~/$combos/g;
				my $rturns = 9999999999;
				if ($rturns > $turns) {
					$rturns -= $turns;
				} else {
					$rturns = '0000000000';
				}
				my $wincnt = 9000 + $wins;
				push(@sortlist, $wincnt . $rturns . '|' . $tline);
			}
		}
	}
}

@sortlist = sort {$b cmp $a} @sortlist;

my $rank = 0;
foreach my $srt (@sortlist) {
	$rank++;
	my ($throw, $tline) = split(/\|/, $srt);
	$tline =~ s/~rank~/$rank/g;
	$lines .= $tline;
}

my $curtime = scalar(localtime());
$fullpage =~ s/~list~/$lines/g;
$fullpage =~ s/~updatetime~/$curtime/g;
open(my $hand3, ">", "/var/www/html/multistreaks.html");
print $hand3 $fullpage;
close($hand3);
