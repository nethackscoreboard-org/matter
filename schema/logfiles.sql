-- === logfiles table ===
--
-- logfiles_i
-- Integer used to reference the logfiles entry; note that it is
-- also referenced from nhdb configuration (nhdb-def.json)! Don't
-- change this, preferably.
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
  1, 'nao', 'nh', '3.4.3',
  'http://alt.org/nethack/xlogfile.full.txt',
  'log.nao',
  'http://alt.org/nethack/userdata/%U/%u/dumplog/%s.nh343.txt',
  'http://alt.org/nethack/userdata/%u/%u.nh343rc',
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2, 'ade', 'nh', '3.4.3',
  'http://acehack.de/nethackxlogfile',
  'log.ade-vanilla',
  'https://acehack.de/userdata/%u/nethack/dumplog/%s',
  NULL,
  TRUE, FALSE, TRUE,
  'Europe/Berlin', NULL, NULL
);

INSERT INTO logfiles VALUES (
  3, 'unn', 'unh', '5',
  'http://un.nethack.nu/logs/xlogfile',
  'log.unn',
  'http://un.nethack.nu/user/%u/dumps/%u.%e.txt.html',
  'http://un.nethack.nu/rcfiles/%u.nethackrc',
  TRUE, FALSE, TRUE,
  'Europe/Berlin', NULL, NULL
);

INSERT INTO logfiles VALUES (
  4, 'n4o', 'nh4', '4.3',
  'http://nethack4.org/xlogfile.txt',
  'log.n4o',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  5, 'ade', 'ace', NULL,
  'http://acehack.de/xlogfile',
  'log.ade-ace', 
  'https://acehack.de/userdata/%u/dumplog/%s',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  6, 'shc', 'sh', NULL,
  'http://sporkhack.com/xlogfile',
  'log.shc',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  7, 'gho', 'gh', NULL,
  'http://grunthack.org/xlogfile',
  'log.gho', 
  'http://grunthack.org/userdata/%U/%u/dumplog/%s.gh020.txt',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  8, 'n4o', 'nh4', '4.2',
  'http://nethack4.org/4.2-xlogfile',
  'log.4.2.n4o',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);
