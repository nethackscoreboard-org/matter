-----------------------------------------------------------------------------
-- This file defines data sources NHS aggregates. Please note that some code
-- may still rely on logfiles_i for devnull games being their year.
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- nethack.alt org/NAO ------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  1, 'nethack.alt.org (3.4.3)',
  'nao', 'nh', '3.4.3',
  'http://alt.org/nethack/xlogfile.full.txt',
  'nao.nh.343.log',
  'http://alt.org/nethack/userdata/%U/%u/dumplog/%s.nh343.txt',
  'http://alt.org/nethack/userdata/%u/%u.nh343rc',
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  20, 'nethack.alt.org (3.6.0)',
  'nao', 'nh', '3.6.0',
  'https://alt.org/nethack/xlogfile.nh360',
  'nao.nh.360.log',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  21, 'nethack.alt.org (3.6.1dev)',
  'nao', 'nh', '3.6.1',
  'https://alt.org/nethack/xlogfile.nh361dev',
  'nao.nh.361dev.log',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- acehack.de/ADE (defunct) -------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  5, 'acehack.de',
  'ade', 'ace', NULL,
  'https://ascension.run/history/ade/xlogfiles/acehack',
  'ade.ace.log',
  'https://ascension.run/history/ade/userdata/%u/acehack/dumplog/%s',
  NULL,
  TRUE, TRUE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- eu.un.nethack.nu/UNE -----------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  3, 'eu.un.nethack.nu',
  'une', 'unh', '5',
  'http://un.nethack.nu/logs/xlogfile-eu',
  'une.unh.log',
  'http://un.nethack.nu/user/%u/dumps/eu/%u.%e.txt.html',
  'http://un.nethack.nu/rcfiles/%u.nethackrc',
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- us.un.nethack.nu/UNU -----------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  10, 'us.un.nethack.nu',
  'unu', 'unh', '5',
  'http://un.nethack.nu/logs/xlogfile-us',
  'unu.unh.log',
  'http://un.nethack.nu/user/%u/dumps/us/%u.%e.txt.html',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- nethack4.org/N4O ---------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  4, 'nethack4.org (4.3)',
  'n4o', 'nh4', '4.3',
  'http://nethack4.org/xlogfile.txt',
  'n4o.nh4-3.log',
  'http://nethack4.org/dumps/%D',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  8, 'nethack4.org (4.2)',
  'n4o', 'nh4', '4.2',
  'http://nethack4.org/4.2-xlogfile',
  'n4o.nh4-2.log',
  NULL,
  NULL,
  TRUE, TRUE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- sporkhack.com/SHC (defunct) ----------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  6, 'sporkhack.com',
  'shc', 'sh', NULL,
  'http://sporkhack.com/xlogfile',
  'shc.sh.log',
  NULL,
  NULL,
  TRUE, TRUE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- grunthack.org/GHO --------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  7, 'grunthack.org',
  'gho', 'gh', NULL,
  'http://grunthack.org/xlogfile',
  'gho.gh.log',
  'http://grunthack.org/userdata/%U/%u/dumplog/%s.gh020.txt',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- dnethack.ilbelkyr.de/DID (defunct) ---------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  9, 'dnethack.ilbelkyr.de',
  'did', 'dnh', NULL,
  'http://dnethack.ilbelkyr.de/xlogfile.txt',
  'did.dnh.log',
  NULL,
  'https://ascension.run/history/ilbelkyr/userdata/%u/dnethack/dumplog/%s',
  TRUE, TRUE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- acehack.eu/AEU (defunct) -------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
 11, 'acehack.eu',
 'aeu', 'ace', NULL,
 'https://ascension.run/history/aeu/xlogfiles/acehack',
 'aeu.ace.log',
 'https://ascension.run/history/aeu/userdata/%u/acehack/dumplog/%s',
 NULL,
 TRUE, TRUE, FALSE,
 'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
--- ascension.run -----------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  2, 'ascension.run (NetHack)',
  'asc', 'nh', '3.4.3',
  'https://ascension.run/xlogfiles/nethack',
  'asc.nh.log',
  'https://ascension.run/userdata/%u/nethack/dumplog/%s',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  12, 'ascension.run (dNetHack)',
  'asc', 'dnh', NULL,
  'https://ascension.run/xlogfiles/dnethack',
  'asc.dnh.log',
  'https://ascension.run/userdata/%u/dnethack/dumplog/%s',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  13, 'ascension.run (Fourk)',
  'asc', 'nhf', NULL,
  'https://ascension.run/xlogfiles/nhfourk',
  'asc.nhf.log',
  'https://ascension.run/userdata/%u/nhfourk/dumplog/%D',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  14, 'ascension.run (SporkHack 2015)',
  'asc', 'sh', NULL,
  'https://ascension.run/history/junethack2015/xlogfiles/sporkhack',
  'asc.sh.2015.log',
  'https://ascension.run/history/junethack2015/userdata/%u/sporkhack/dumplog/%s',
  NULL,
  TRUE, TRUE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  15, 'ascension.run (GruntHack 2015)',
  'asc', 'gh', NULL,
  'https://ascension.run/history/junethack2015/xlogfiles/grunthack',
  'asc.gh.2015.log',
  'https://ascension.run/history/junethack2015/userdata/%u/grunthack/dumplog/%s',
  NULL,
  TRUE, TRUE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  16, 'ascension.run (UnNetHack)',
  'asc', 'unh', NULL,
  'https://ascension.run/xlogfiles/unnethack',
  'asc.unh.log',
  'https://ascension.run/userdata/%u/unnethack/dumplog/%s',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  17, 'ascension.run (DynaHack)',
  'asc', 'dyn', NULL,
  'https://ascension.run/xlogfiles/dynahack',
  'asc.dyn.log',
  'https://ascension.run/userdata/%u/dynahack/dumplog/%d',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  18, 'ascension.run (NetHack4)',
  'asc', 'nh4', '4.3',
  'https://ascension.run/xlogfiles/nethack4',
  'asc.nh4.log',
  'https://ascension.run/userdata/%u/nethack4/dumplog/%D',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  19, 'ascension.run (FiqHack)',
  'asc', 'fh', NULL,
  'https://ascension.run/xlogfiles/fiqhack',
  'asc.fh.log',
  'https://ascension.run/userdata/%u/fiqhack/dumplog/%D',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
--- hardfought.org ----------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  22, 'hardfought.org (NetHack 3.4.3)',
  'hdf', 'nh', NULL,
  'https://www.hardfought.org/xlogfiles/nh343/xlogfile',
  'hdf.nh.343.log',
  'https://www.hardfought.org/userdata/%U/%u/nh343/dumplog/%s.nh343.txt',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  23, 'hardfought.org (GruntHack)',
  'hdf', 'gh', NULL,
  'https://www.hardfought.org/xlogfiles/gh/xlogfile',
  'hdf.gh.log',
  'https://www.hardfought.org/userdata/%U/%u/gh/dumplog/%s.gh.txt',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  24, 'hardfought.org (UnNetHack)',
  'hdf', 'unh', NULL,
  'https://www.hardfought.org/xlogfiles/un531/xlogfile',
  'hdf.unh.log',
  'https://www.hardfought.org/userdata/%U/%u/un531/dumplog/%s.un531.txt.html',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  25, 'hardfought.org (NetHack 3.6.1dev)',
  'hdf', 'nh', NULL,
  'https://www.hardfought.org/xlogfiles/nhdev/xlogfile',
  'hdf.nhdev.log',
  'https://www.hardfought.org/userdata/%U/%u/nhdev/dumplog/%s.nhdev.txt',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  29, 'hardfought.org (FIQhack)',
  'hdf', 'fh', NULL,
  'https://www.hardfought.org/xlogfiles/fh/xlogfile',
  'hdf.fh.log',
  'https://www.hardfought.org/userdata/%U/%u/fiqhack/dumplog/%D',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  30, 'hardfought.org (Fourk)',
  'hdf', 'nhf', NULL,
  'https://www.hardfought.org/xlogfiles/4k/xlogfile',
  'hdf.nhf.log',
  'https://www.hardfought.org/userdata/%U/%u/nhfourk/dumps/%d',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- em.slashem.me ------------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  26, 'em.slashem.me (NetHack 3.6.0)',
  'esm', 'nh', NULL,
  'https://em.slashem.me/xlogfiles/nethack',
  'esm.nh.360.log',
  'https://em.slashem.me/userdata/%u/nethack/dumplog/%E.txt',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  27, 'em.slashem.me (GruntHack)',
  'esm', 'gh', NULL,
  'https://em.slashem.me/xlogfiles/grunthack',
  'esm.gh.log',
  'https://em.slashem.me/userdata/%u/grunthack/dumplog/%s.txt',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  28, 'em.slashem.me (SporkHack)',
  'esm', 'sh', NULL,
  'https://em.slashem.me/xlogfiles/sporkhack',
  'esm.sh.log',
  'https://em.slashem.me/userdata/%u/sporkhack/dumplog/%s.txt',
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- nethack.devnull.com/DEV --------------------------------------------------
-----------------------------------------------------------------------------

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
  2013, '/dev/null 2013',
  'dev', 'nh', NULL,
  NULL,
  'devnull-2013.log',
  NULL,
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2014, '/dev/null 2014',
  'dev', 'nh', NULL,
  NULL,
  'devnull-2014.log',
  NULL,
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2015, '/dev/null 2015',
  'dev', 'nh', NULL,
  NULL,
  'devnull-2015.log',
  NULL,
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  2016, '/dev/null 2016',
  'dev', 'nh', NULL,
  'http://nethack.devnull.net/tournament/scores.xlogfile',
  'devnull-2016.log',
  NULL,
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);
