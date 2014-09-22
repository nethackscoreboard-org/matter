-- === logfiles table ===
--
-- logfiles_i
-- Integer used to reference the logfiles entry; note that it is
-- also referenced from nhdb configuration (nhdb-def.json)! Don't
-- change this, preferably.
--
-- descr
-- Description of the entry; only shown on the About page
--
-- server
-- Three letter server acronym in lowercase (such as "nao" for
-- nethack.alt.org, "ade" for acehack.de etc.).
--
-- variant
-- Variant acronym in lowercase (such as "nh" for vanilla NetHack,
-- "ace" for AceHack, "nh4" for NetHack4 etc.)
--
-- version
-- Currently not used for anything of consequence, might simply hold
-- description or additional distinguisher string.
--
-- logurl
-- Fully qualified URL of xlogfile.
--
-- localfile
-- Filename of a logfile on local filesystem.
--
-- dumpurl
-- Determines location of the game dumps
--
-- rcfileurl
-- Determines location of player rc files
-- 
-- static
-- If true, the feeder will not try to download the file from logurl,
-- even if it is defined. This allows static logfiles to be part of the
-- dataset (such as devnull logfiles, logfiles from discontinued sites etc.)
--
-- httpcon
-- Site supports HTTP continuation, allowing incremental downloads.
-- If false, the whole file needs to be redownloaded every time.
--
-- tz
-- Time zone used for this logfile
--
-- fpos
-- Last file position; this is the file position the feeder will
-- read the file from on the next run. After the feeder has run and
-- processed the logfile, it is set to the log's filesize. By resetting
-- this field, one forces the whole logfile to be parsed and fed into
-- db again (but that won't erase the redundant db entries!)
--
-- lastchk
-- Time of last processing of the logfile.

DROP TABLE logfiles;

CREATE TABLE logfiles (
  logfiles_i  int,
  descr       varchar(32),
  server      varchar(3) NOT NULL,
  variant     varchar(3) NOT NULL,
  version     varchar(16),
  logurl      varchar(128),
  localfile   varchar(128) NOT NULL,
  dumpurl     varchar(128),
  rcfileurl   varchar(128),
  oper        boolean,
  static      boolean,
  httpcont    boolean,
  tz          varchar(32),
  fpos        bigint,
  lastchk     timestamp with time zone,
  PRIMARY KEY (logfiles_i)
);

GRANT SELECT, UPDATE ON logfiles TO nhdbfeeder;
GRANT SELECT ON logfiles TO nhdbstats;

INSERT INTO logfiles VALUES (
  1, 'nethack.alt.org', 
  'nao', 'nh', '3.4.3',
  'http://alt.org/nethack/xlogfile.full.txt',
  'log.nao',
  'http://alt.org/nethack/userdata/%U/%u/dumplog/%s.nh343.txt',
  'http://alt.org/nethack/userdata/%u/%u.nh343rc',
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2, 'acehack.de',
  'ade', 'nh', '3.4.3',
  'http://acehack.de/nethackxlogfile',
  'log.ade-vanilla',
  'https://acehack.de/userdata/%u/nethack/dumplog/%s',
  NULL,
  TRUE, FALSE, TRUE,
  'Europe/Berlin', NULL, NULL
);

INSERT INTO logfiles VALUES (
  3, 'eu.un.nethack.nu', 
  'une', 'unh', '5',
  'http://un.nethack.nu/logs/xlogfile-eu',
  'log.une',
  'http://un.nethack.nu/user/%u/dumps/eu/%u.%e.txt.html',
  'http://un.nethack.nu/rcfiles/%u.nethackrc',
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  10, 'us.un.nethack.nu',
  'unu', 'unh', '5',
  'http://un.nethack.nu/logs/xlogfile-us',
  'log.unu',
  'http://un.nethack.nu/user/%u/dumps/us/%u.%e.txt.html',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);


INSERT INTO logfiles VALUES (
  4, 'nethack4.org (4.3)', 
  'n4o', 'nh4', '4.3',
  'http://nethack4.org/xlogfile.txt',
  'log.n4o',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  5, 'acehack.de (AceHack)',
  'ade', 'ace', NULL,
  'http://acehack.de/xlogfile',
  'log.ade-ace', 
  'https://acehack.de/userdata/%u/dumplog/%s',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  6, 'sporkhack.com',
  'shc', 'sh', NULL,
  'http://sporkhack.com/xlogfile',
  'log.shc',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  7, 'grunthack.org',
  'gho', 'gh', NULL,
  'http://grunthack.org/xlogfile',
  'log.gho', 
  'http://grunthack.org/userdata/%U/%u/dumplog/%s.gh020.txt',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  8, 'nethack4.org (4.2)',
  'n4o', 'nh4', '4.2',
  'http://nethack4.org/4.2-xlogfile',
  'log.4.2.n4o',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  9, 'dnethack.ilbelkyr.de', 
  'did', 'dnh', NULL,
  'http://dnethack.ilbelkyr.de/xlogfile.txt',
  'log.dnh',
  'http://dnethack.ilbelkyr.de/userdata/%u/dumplog/%s.dnao.txt',
  NULL,
  FALSE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
 11, 'acehack.eu',
 'aeu', 'ace', NULL,
 NULL,
 'log.aeu',
 'https://acehack.de/aeu/%u/dumplog/%s',
 NULL,
 TRUE, TRUE, FALSE,
 'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2006, '/dev/null 2006',
  'dev', 'nh', NULL,
  NULL,
  'devnull-2006.log',
  NULL,
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2007, '/dev/null 2007',
  'dev', 'nh', NULL,
  NULL,
  'devnull-2007.log',
  NULL,
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2008, '/dev/null 2008',
  'dev', 'nh', NULL,
  NULL,
  'devnull-2008.log',
  NULL,
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2009, '/dev/null 2009',
  'dev', 'nh', NULL,
  NULL,
  'devnull-2009.log',
  NULL,
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2010, '/dev/null 2010',
  'dev', 'nh', NULL,
  NULL,
  'devnull-2010.log',
  NULL,
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2011, '/dev/null 2011',
  'dev', 'nh', NULL,
  NULL,
  'devnull-2011.log',
  NULL,
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2012, '/dev/null 2012',
  'dev', 'nh', NULL,
  NULL,
  'devnull-2012.log',
  NULL,
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2013, '/dev/null 2014',
  'dev', 'nh', NULL,
  NULL,
  'devnull-2013.log',
  NULL,
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);
