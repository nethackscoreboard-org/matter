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

* **--reload option for the feeder** // Reload the database according to --variant and --server.

-----

## Command-line parameters

All the options that suplly variants, servers or player names can be either used multiple times on the command-line, or they can have aggregate multiple strings by joining them with commas. Example:

     nhdb-feeder --variant=all --variant=nh --variant=nh4
     nhdb-feeder --variant=all,nh,nh4

### nhdb-feeder.pl

**--logfiles**  
This will list all configured data sources and exit without doing anything else.

**--server**=*server*  
Only sources on specified server will be processed. "srv" is three letter server acronym such as "nao", "nxc" etc. Using this option will override the source server being defined as unoperational in the
database (table 'logfiles'), but it will not override the server being defined as static. This
behaviour enables reloading inoperational servers without needing to go to the database to temporarily
switch their 'oper' field. Please note, that one server can host multiple variants (and therefore have
multiple logs associated with it), use --variant to further limit processing to single source.

**--variant**=*variant*  
Limit processing only to variant specified by its short-code (such as "nh", "unh" etc.)

### nhdb-stats.pl

**--noaggr**  
Disable generation of aggregate pages (such as list of recent ascensions, streak list and so on).

**--force**  
Force processing of all variants and players, even if they do not need updating. Note, that regenerating all players' pages takes very long time. If you just want force regenerating aggregate pages, use the --noplayers option along with --force.

**--variant**=*variant*  
Limit processin only to specified variant. This can be used multiple times. Variant can also be "all".

**--noplayers**  
Disable generating player pages.

**--player**=*player*  
Use this to limit processing player pages to specific player or players.

-----

## Configuration
Configuration is done through three JSON files in cfg subdirectory. *nhdb\_def.json* is the main config file; *nethack\_def.json* is file that contains facts about NetHack and its variants like what roles/races/alignments/genders, what are permitted combinations etc; *auth.json* contains credentials for the backend database

### nhdb_def.json

    "http_root" : "/home/httpd/nh",

Defines where the static HTML pages are generated.

    "db" : {
      "nhdbfeeder" : {
         "dbname" : "nhdb",
         "dbuser" : "nhdbfeeder"
      },
      "nhdbstats" : {
        "dbname" : "nhdb",
        "dbuser" : "nhdbstats"
      }
    }

Define database name and login for both feeder and stats generator components.

    "auth" : "auth.json",

Defines external configuration file to contain passwords for user used in the "db" section.

    "devnull" : {
      "http_path" : "devnull/%Y",
      "2014" : 2014
    },

Define path, relative to "http_root" above, where devnull stats will be stored; also define the paths for each year.

    "feeder" : {
      "require_fields" : [ "conduct", "starttime", "endtime" ]
    },

Fields list in "require_fields" must be present in a xlogfile line; if one or more of them are missing, the line will be rejected from processing.

    "feeder" : {
      "regular_fields" : [
        "role", "race", "gender", "gender0", "align", "align0", "deathdnum",
        "deathlev", "deaths", "hp", "maxhp", "maxlvl", "points", "turns",
        "realtime", "version", "dumplog"
      ],
    }

List of fields inserted into database without any particular processing. Do not change this unless you know what you are doing.

    "feeder" : {
      "reject_name" : [ "wizard", "paxedtest" ]
    }

Player names listed in "reject_name" will be excluded from processing.

    "logs" : {
      "localpath" : "logs",
      "urlpath" : null
    }

"localpath" is relative pathname where xlogfiles are locally stored;  
"urlpath" is optional value that contains URL of local xlogfiles (both relative and absolute URLs will work); if it is set, field "size" in About page will link to the local file (which must be served by the web server, of course)

### nethack_def.json

This configuration file defines facts about NetHack (role/race/alignment/gender names, allowed combinations etc.)

    "nh_roles_def" : {
      "arc" : "archeologist",
      "bar" : "barbarian",
      "brd" : "brd",
      "bin" : "binder",
      "cav" : "caveman",
      "con" : "convict",
      "hea" : "healer",
      "hlf" : "half-dragon",
      "kni" : "knight",
      "mon" : "monk",
      "nob" : "noble",
      "pir" : "pirate",
      "pri" : "priest",
      "ran" : "ranger",
      "rog" : "rogue",
      "sam" : "samurai",
      "tou" : "tourist",
      "val" : "valkyrie",
      "wiz" : "wizard"
    }

"nh\_roles\_def" assigns role's full name to three-letter shortcode. All roles that can appear in any of the processed variants must be listed here.

    "nh_races_def" : {
      "clk" : "clockwork automaton",
      "hum" : "human",
      "elf" : "elf",
      "dro" : "drow",
      "dwa" : "dwarf",
      "gno" : "gnome",
      "inc" : "incantifier",
      "orc" : "orc",
      "syl" : "sylph",
      "vam" : "vampire"
    }

"nh\_races\_def" assigns races' full name to three-letter shortcode. All races that can appear in any of the processed variants must be listed here.

    "nh_aligns_def" : {
      "law" : "lawful",
      "neu" : "neutral",
      "cha" : "chaotic",
      "non" : "non-aligned"
    }

"nh\_aligns\_def" assigns alignment's full name to three-letter shortcode. All alignments that can appear in any of the processed variants must be listed here.

    "nh_genders_def" : {
      "mal" : "male",
      "fem" : "female",
      "ntr" : "neuter"
    }

"nh\_genders\_def" assigns genders' full name to three-letter shortcode. All genders that can appear in any of the processed variants must be listed here.

    "nh_conduct_bitmap_def" : {
      "1"    : "food",
      "2"    : "vegn",
      "4"    : "vegt",
      "8"    : "athe",
      "16"   : "weap",
      "32"   : "paci",
      "64"   : "illi",
      "128"  : "pile",
      "256"  : "self",
      "512"  : "wish",
      "1024" : "arti",
      "2048" : "geno"
    }

"nh\_conduct\_bitmap_def" defines semantics of the conduct xlogfile field. This is the default semantics, it's possible for a variant to have different one defined later in the config file.

    "nh_conduct_ord" : [
      "arti", "pile", "self", "pudd", "algn", "geno", "wish", "athe",
      "vegt", "vegn", "weap", "elbe", "illi", "paci", "food"
    ]

"nh\_conduct\_ord" defines ordering of conducts used for display; it's roughly easiest to hardest order.

    "nh_variants_def" : {
      "nh"  : "NetHack",
      "nh4" : "NetHack4",
      "ace" : "AceHack",
      "sh"  : "SporkHack",
      "gh"  : "GruntHack",
      "unh" : "UnNetHack",
      "dnh" : "dNetHack",
      "nhf" : "Fourk"
    }

"nh\_variants\_def" defines NetHack variants names and shortcodes.

    "nh_variants_ord" : [
      "nh", "ace", "nh4", "unh", "sh", "gh", "dnh", "nhf"
    ]

"nh\_variants\_ord" defines ordering of variants for display purposes

    "nh\_variants" : {
      "nh" : {
        "roles" : [ 
          "arc", "bar", "cav", "hea", "kni", "mon", "pri", "ran", "rog",
          "sam", "tou", "val", "wiz"
        ],
        "races" : [ "hum", "elf", "dwa", "gno", "orc" ],
        "aligns" : [ "law", "neu", "cha" ]
      }
    }

"nh\_variants" defines roles/races/aligns that given variant has. Genders are oddly missing since we are not using them for anything so far. Optionally, there can also be variant's own list of conducts.

    "nh_combo_rules_def" : {

       "nh" : [
         [ "$arc", "%hum", "%dwa", "%gno",         "#law", "#neu"         ],
         [ "$bar", "%hum", "%orc",                 "#neu", "#cha"         ],
         [ "$cav", "%hum", "%dwa", "%gno",         "#law", "#neu"         ],
         [ "$hea", "%hum", "%gno",                 "#neu"                 ],
         [ "$kni", "%hum",                         "#law"                 ],
         [ "$mon", "%hum"                                                 ],
         [ "$pri", "%hum", "%elf"                                         ],
         [ "$ran", "%hum", "%elf", "%gno",         "#neu", "#cha"         ],
         [ "$rog", "%hum", "%orc",                 "#cha"                 ],
         [ "$sam", "%hum",                         "#law"                 ],
         [ "$tou", "%hum",                         "#neu"                 ],
         [ "$val", "%hum", "%dwa",                 "#law", "#neu", "!fem" ],
         [ "$wiz", "%hum", "%elf", "%gno", "%orc", "#neu", "#cha"         ],

         [ "%elf", "#cha" ],
         [ "%dwa", "#law" ],
         [ "%gno", "#neu" ],
         [ "%orc", "#cha" ]
      ]
    }

"nh\_combo\_rules\_def" is used to determine if given combination of role/race/gender/alignment is valid. It's defined for each variant; if definition for a variant is ommited, "nh" is used as default (to avoid duplicate definitions for variants who keep the same rules as vanilla, such as NetHack4). Definition for "nh" (vanilla NetHack) is given as an example above. The definition is a list of rules. Each rule is in turn a list of rule matches. The first match in a rule is special: if it matches, then the rest of the matches must be satisfied, if it is not, the matching will immediately fail and no more rules are matched. The first special match can be single match (as in example above), or it can be list of matches, if triggering by more than one condition is required.

The matches themselves consist of standard three-letter short codes for role/race/gender/alignment with a special character prepended. The prepended character determines whether role ($), race (%), alignment (#) or gender (!) is matched. So "$arc" matches archeologist, "!fem" matches female etc.

Consider this example:

    [ "$arc", "%hum", "%dwa", "%gno", "#law", "#neu" ],

This rule will only apply to archeologists, since the first rule (trigger) is "$arc". Three races and two alignments are in the "require" rules. The character therefore must be one of them. Gender is not present in the matches at all, therefore it can be both male and female.

    [ [ "%dro", "!mal" ], "#neu" ],
    [ [ "%dro", "!fem" ], "#cha" ]

Above example shows the use of multiple trigger matches; it enforces Drows to be either neutral males or chaotic females (as is the rule in dNetHack).
