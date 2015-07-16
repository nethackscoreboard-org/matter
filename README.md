# NETHACK SCOREBOARD

This is the code used to run [NetHack Scoreboard](https://scoreboard.xd.cm/) web site. The code consists of two main components: *feeder* and *stats generator*. The feeder retrieves [xlogfiles](http://nethackwiki.com/wiki/Xlogfile) from public NetHack servers, parses them and stores the parsed log entries in a back-end database. The stats generator then uses this data to generate static HTML pages with various statistics, including personal pages.

The NetHack Scoreboard is written using:

* **perl** as the programming language
* **PostgreSQL** as backend database
* **Template Toolkit** as templating engine
* **Log4Perl** as logging system

-----

## Command-line parameters

### nhdb-feeder.pl

**--logfiles**  
This will list all configured data sources and exit without doing anything else.

**--server**=*server*  
Only sources on specified server will be processed. "srv" is three letter server acronym such as "nao", "nxc" etc.

**--variant**=*variant*  
Limit processing only to variant specified by its short-code (such as "nh", "unn" etc.)

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
