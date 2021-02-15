# NETHACK SCOREBOARD

This is the code used to run [NetHack Scoreboard](https://scoreboard.xd.cm/) web site. The code consists of two main components: *feeder* and *stats generator*. The feeder retrieves [xlogfiles](http://nethackwiki.com/wiki/Xlogfile) from public NetHack servers, parses them and stores the parsed log entries in a back-end database. The stats generator then uses this data to generate static HTML pages with various statistics, including personal pages.

The NetHack Scoreboard is written using:

* **perl** as the programming language
* **PostgreSQL** as backend database
* **Template Toolkit** as templating engine
* **Log4Perl** as logging system
* **Moo** as OOP framework

-----
other deps as either cpan modules or distro packages where available:
Moo
Template
Log::Log4perl
DBI
JSON (perl-JSON on fedora/dnf)
Path::Tiny (perl-Path-Tiny dnf)
MooX::Singleton (complete the pattern)
Ref::Util
Log::Dispatch::Screen (cpan)
DBD::Pg
[also Carp::Always is helpful for traceback]

-----
Mandevil is no longer maintaining nhs, the fork is now being maintained by elenmirië, aoei & mobileuser,
with hosting for the new site at https://nethackscoreboard.org/ provided by K2 & with Mandevil's blessing.

Currently work is ongoing to set up a Mojo Front-End, instead of generating static HTML pages.
-----

## To Do

This list is an implementation plan for the near future. Feel free to submit your own suggestions.

* **Searching By Player Name** //
Interactive searching for player name (req. *stenno*).

* **Add Average Realtime And Average Gametime To Per-Variant Stats** // Can't be done for aggregates since realtime is measured differently or completely unavailable in some variants and (min) turncount depends on variant (some variants have too different gameplay to be comparable)

* **Pseudovariant 'var'** // This would be pseudo-variant that would aggregate all variants but vanilla NetHack.

* **Switch everything to use starting alignment/gender** // Currently we use ending alignment/gender.

* **Use UTC Everywhere** // Currently we use local time which is plain wrong.

* **Per-Player Conduct Achievements** //
Simple table with all relevant conducts and info whether the player
has achieved them; optionally, make the table list number of times the
conducts were achieved (in a winning game)

* **Combos page** //
Combos page like the one we have in /dev/null, but generalized.  Use this
for per-player combo page, maybe some more later (but the code should be 
general); after this is done, convert devnull Combos page to this new base.

* **Experimental flag** //
Variant can be marked as experimental, which will exclude it from the 'all'
pseudovariant

* **Browsing All Player Games** //
For a given player, all games can be browsed in a paginated display (like on
NAO).

-----

## Setup

Create users nhdbfeeder and nhdbstats in postgresql with access to an empty nhdb database.
Initialise db with files in schema/ (some depend on others being run first, see schema/hint).
nhdb-feeder.pl aggregates xlogfiles from various sources and populates the database as local logs in logs/.
nhdb-stats.pl generates HTML content in the httpd directory to serve to the web.

Both scripts require the files cfg/nhdb_def.json and cfg/auth.json are present to run.
cfg/nhdb_def.json specifies e.g. httpd root, dbname, dbuser
cfg/nhdb_def.json.example is a sample configuration
auth.json contains only two entries, the keys are the dbusers for each script and the values are their passwords, md5 auth needs to be permitted in postgresql config for this to work.
nhdb-stats.pl will crash unless this file is present: templates/about_news.tt (included by templates/about.tt)

## Command-line parameters

All the options that suply variants, servers or player names can be either used multiple times on the command-line, or they can have aggregate multiple strings by joining them with commas. Example:

     nhdb-feeder --variant=all --variant=nh --variant=nh4
     nhdb-feeder --variant=all,nh,nh4

### nhdb-feeder.pl

**--logfiles**  
This will list all configured data sources and exit without doing anything else.

**--server**=*server*  
Only sources on specified server will be processed. "srv" is three letter
server acronym such as "nao", "nxc" etc. Using this option will override the
source server being defined as unoperational in the database (table
'logfiles'), but it will not override the server being defined as static. This
behaviour enables reloading inoperational servers without needing to go to the
database to temporarily switch their 'oper' field. Please note, that one
server can host multiple variants (and therefore have multiple logs associated
with it), use `--variant` to further limit processing to single source.

**--variant**=*variant*  
Limit processing only to variant specified by its short-code (such as "nh", "unh" etc.)

**--logid**=*id*  
Limit processing only to logfiles specified by their log ids. Log id is NHS's internal identification of a configured logfile. The `--logfiles` option will display these id's.

**--purge**  
Erase all database entries that match `--logid`, `--server` and `--variant` options. If used alone without any specification, all the entries are deleted.

**--oper**, **--nooper**  
Enable/disable all processing of selected sources.

**--static**, **--nostatic**  
Make selected sources static (or non-static), ie. never try to download the source's configured xlogfile, but still
process it if it grows or its database entries are purged.

**--pmap-list**  
Display list of current player name translations.

**--pmap-add**=*SRCNAME*/*SERVER*=*DSTNAME*  
Add new translation, playername *srcname* on server *server* will be considered
*dstname*. Multiple translations can be added at the same time and this can be combined with `--pmap-remove`.

**--pmap-remove**=*SRCNAME*/*SERVER*  
Remove existing translation. Multiple translations can be removed at the same time and this can be combined with `--pmap-add`.

### nhdb-stats.pl

**--noaggr**  
Disable generation of aggregate pages (such as list of recent ascensions, streak list and so on).

**--force**  
Force processing of all variants and players, even if they do not need updating. Note, that regenerating all players' pages takes very long time. If you just want force regenerating aggregate pages only, use the `--noplayers` option along with `--force`.

**--variant**=*variant*  
Limit processing only to specified variant. This can be used multiple times. Variant can also be "all".

**--noplayers**  
Disable generating player pages.

**--player**=*player*  
Use this to limit processing player pages to specific player or players.
