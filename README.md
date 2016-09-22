# NETHACK SCOREBOARD

This is the code used to run [NetHack Scoreboard](https://scoreboard.xd.cm/) web site. The code consists of two main components: *feeder* and *stats generator*. The feeder retrieves [xlogfiles](http://nethackwiki.com/wiki/Xlogfile) from public NetHack servers, parses them and stores the parsed log entries in a back-end database. The stats generator then uses this data to generate static HTML pages with various statistics, including personal pages.

The NetHack Scoreboard is written using:

* **perl** as the programming language
* **PostgreSQL** as backend database
* **Template Toolkit** as templating engine
* **Log4Perl** as logging system

-----

## To Do

This list is an implementation plan for the near future. Feel free to submit your own suggestions.

* **Searching By Player Name** //
Interactive searching for player name (req. *stenno*).

* **Add Average Realtime And Average Gametime To Per-Variant Stats** // Can't be done for aggregates since realtime is measured differently or completely unavailable in some variants and gametime depends on variant (some variants have too different gameplay to be comparable)

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

**--nodev**  
Disables devnull-specific processing even if other conditions are met (ie. it's November and devnull for that year is properly configured).

**--year=YYYY**  
Together with `--dev` generates devnull pages for given year. Year can be either single one like `--year=2015` or comma-delimited list like `--year=2008,2009,2010`. Also, all years that are configured can be generated with `--year=all`.
