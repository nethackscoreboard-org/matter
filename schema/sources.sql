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
  'https://s3.amazonaws.com/altorg/dumplog/%u/%s.nh343.txt'
  'http://alt.org/nethack/userdata/%u/%u.nh343rc',
  NULL,
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
  '{"bug360duration"}',
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
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, version, logurl, localfile, dumpurl,
  oper, static, httpcont, tz
) VALUES (
  50, 'nethack.alt.org (3.6.1)',
  'nao', 'nh', '3.6.1',
  'https://alt.org/nethack/xlogfile.nh361',
  'nao.nh.361.log',
  'https://s3.amazonaws.com/altorg/dumplog/%u/%s.nh361.txt',
  TRUE, FALSE, TRUE, 'UTC'
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
  NULL,
  TRUE, TRUE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- eu.un.nethack.nu/UNE -----------------------------------------------------
-----------------------------------------------------------------------------

-- Shut down in May 2018, archived on ascension.run

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  3, 'eu.un.nethack.nu',
  'une', 'unh',
  'https://ascension.run/history/unn/eu/xlogfile'
  'une.unh.log',
  'https://ascension.run/history/unn/users/%u/dumps/eu/%u.%e.txt.html'
  TRUE, TRUE, TRUE, 'UTC'
);

-----------------------------------------------------------------------------
-- us.un.nethack.nu/UNU -----------------------------------------------------
-----------------------------------------------------------------------------

-- Shut down in May 2018, archived on ascension.run

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  10, 'us.un.nethack.nu',
  'unu', 'unh',
  'https://ascension.run/history/unn/us/xlogfile'
  'unu.unh.log',
  'https://ascension.run/history/unn/users/%u/dumps/us/%u.%e.txt.html'
  TRUE, TRUE, TRUE, 'UTC'
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
  NULL,
  TRUE, TRUE, TRUE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- grunthack.org/GHO --------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  7, 'grunthack.org',
  'gho', 'gh',
  'http://grunthack.org/xlogfile',
  'gho.gh.log',
  'http://grunthack.org/userdata/%U/%u/dumplog/%s.gh020.txt',
  TRUE, TRUE, TRUE, 'UTC'
);

-----------------------------------------------------------------------------
-- dnethack.ilbelkyr.de/DID (defunct) ---------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  9, 'dnethack.ilbelkyr.de',
  'did', 'dnh', NULL,
  'http://dnethack.ilbelkyr.de/xlogfile.txt',
  'did.dnh.log',
  'https://ascension.run/history/ilbelkyr/userdata/%u/dnethack/dumplog/%s',
  NULL,
  NULL,
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
  NULL,
  TRUE, TRUE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  16, 'ascension.run (UnNetHack)',
  'asc', 'unh', NULL,
  'https://ascension.run/xlogfiles/unnethack',
  'asc.unh.log',
  'https://ascension.run/userdata/%u/unnethack/dumplog/%s.html',
  NULL,
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
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  19, 'ascension.run (FIQHack)',
  'asc', 'fh', NULL,
  'https://ascension.run/xlogfiles/fiqhack',
  'asc.fh.log',
  'https://ascension.run/userdata/%u/fiqhack/dumplog/%D',
  NULL,
  '{"base64xlog"}',
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
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  25, 'hardfought.org (NetHack 3.6.1)',
  'hdf', 'nh', NULL,
  'https://www.hardfought.org/xlogfiles/nh361/xlogfile',
  'hdf.nh361.log',
  'https://www.hardfought.org/userdata/%U/%u/nh361/dumplog/%s.nh361.txt',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  29, 'hardfought.org (FIQHack)',
  'hdf', 'fh', NULL,
  'https://www.hardfought.org/xlogfiles/fh/xlogfile',
  'hdf.fh.log',
  'https://www.hardfought.org/userdata/%U/%u/fiqhack/dumplog/%D',
  NULL,
  '{"base64xlog"}',
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
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  31, 'hardfought.org (dNetHack)',
  'hdf', 'dnh', NULL,
  'https://www.hardfought.org/xlogfiles/dnethack/xlogfile',
  'hdf.dnh.log',
  'https://www.hardfought.org/userdata/%U/%u/dnethack/dumplog/%s.dnh.txt',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  32, 'hardfought.org (NetHack 4)',
  'hdf', 'nh4', NULL,
  'https://www.hardfought.org/xlogfiles/nethack4/xlogfile',
  'hdf.nh4.log',
  'https://www.hardfought.org/userdata/%U/%u/nethack4/dumplog/%D',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  33, 'hardfought.org (DynaHack)',
  'hdf', 'dyn', NULL,
  'https://www.hardfought.org/xlogfiles/dynahack/xlogfile',
  'hdf.dyn.log',
  'https://www.hardfought.org/userdata/%U/%u/dynahack/dumplog/%d',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles VALUES (
  34, 'hardfought.org (SporkHack)',
  'hdf', 'sh', NULL,
  'https://www.hardfought.org/xlogfiles/sporkhack/xlogfile',
  'hdf.sh.log',
  'https://www.hardfought.org/userdata/%U/%u/sporkhack/dumplog/%s.sp.txt',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  45, 'hardfought.org (xNetHack)',
  'hdf', 'xnh',
  'https://www.hardfought.org/xlogfiles/xnethack/xlogfile',
  'hdf.xnh.log',
  'https://www.hardfought.org/userdata/%U/%u/xnethack/dumplog/%s.xnh.txt',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  47, 'hardfought.org (SLASH''EM Extended)',
  'hdf', 'slx',
  'https://www.hardfought.org/xlogfiles/slex/xlogfile',
  'hdf.slx.log',
  'https://www.hardfought.org/userdata/%U/%u/slex/dumplog/%s.slex.txt',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  51, 'hardfought.org (SpliceHack)',
  'hdf', 'sph',
  'https://www.hardfought.org/xlogfiles/splicehack/xlogfile',
  'hdf.spl.log',
  NULL,
  TRUE, FALSE, TRUE, 'UTC'
);

-----------------------------------------------------------------------------
-- hardfought.org EU --------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  35, 'eu.hardfought.org (NetHack 3.4.3)',
  'hfe', 'nh',
  'https://eu.hardfought.org/xlogfiles/nh343/xlogfile',
  'hfe.nh.343.log',
  'https://eu.hardfought.org/userdata/%U/%u/nh343/dumplog/%s.nh343.txt',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  36, 'eu.hardfought.org (NetHack 3.6.1)',
  'hfe', 'nh',
  'https://eu.hardfought.org/xlogfiles/nh361/xlogfile',
  'hfe.nh.361.log',
  'https://eu.hardfought.org/userdata/%U/%u/nh361/dumplog/%s.nh361.txt',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  37, 'eu.hardfought.org (NetHack Fourk)',
  'hfe', 'nhf',
  'https://eu.hardfought.org/xlogfiles/4k/xlogfile',
  'hfe.nhf.log',
  'https://eu.hardfought.org/userdata/%U/%u/nhfourk/dumps/%d',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  38, 'eu.hardfought.org (dNetHack)',
  'hfe', 'dnh',
  'https://eu.hardfought.org/xlogfiles/dnethack/xlogfile',
  'hfe.dnh.log',
  'https://eu.hardfought.org/userdata/%U/%u/dnethack/dumplog/%s.dnh.txt',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz, options
) VALUES (
  39, 'eu.hardfought.org (FIQHack)',
  'hfe', 'fh',
  'https://eu.hardfought.org/xlogfiles/fh/xlogfile',
  'hfe.fh.log',
  'https://eu.hardfought.org/userdata/%U/%u/fiqhack/dumplog/%D',
  TRUE, FALSE, TRUE, 'UTC', '{"base64xlog"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  40, 'eu.hardfought.org (GruntHack)',
  'hfe', 'gh',
  'https://eu.hardfought.org/xlogfiles/gh/xlogfile',
  'hfe.gh.log',
  'https://eu.hardfought.org/userdata/%U/%u/gh/dumplog/%s.gh.txt',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  41, 'eu.hardfought.org (NetHack 4)',
  'hfe', 'nh4',
  'https://eu.hardfought.org/xlogfiles/nethack4/xlogfile',
  'hfe.nh4.log',
  'https://eu.hardfought.org/userdata/%U/%u/nethack4/dumplog/%D',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  42, 'eu.hardfought.org (SporkHack)',
  'hfe', 'sh',
  'https://eu.hardfought.org/xlogfiles/sporkhack/xlogfile',
  'hfe.sh.log',
  'https://eu.hardfought.org/userdata/%U/%u/sporkhack/dumplog/%s.sp.txt',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  43, 'eu.hardfought.org (UnNetHack)',
  'hfe', 'unh',
  'https://eu.hardfought.org/xlogfiles/un531/xlogfile',
  'hfe.unh.log',
  'https://eu.hardfought.org/userdata/%U/%u/un531/dumplog/%s.un531.txt.html',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  44, 'eu.hardfought.org (DynaHack)',
  'hfe', 'dyn',
  'https://eu.hardfought.org/xlogfiles/dynahack/xlogfile',
  'hfe.dyn.log',
  'https://eu.hardfought.org/userdata/%U/%u/dynahack/dumplog/%d',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  46, 'eu.hardfought.org (xNetHack)',
  'hfe', 'xnh',
  'https://eu.hardfought.org/xlogfiles/xnethack/xlogfile',
  'hfe.xnh.log',
  'https://eu.hardfought.org/userdata/%U/%u/xnethack/dumplog/%s.xnh.txt',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  49, 'eu.hardfought.org (SLASH''EM Extended)',
  'hfe', 'slx',
  'https://eu.hardfought.org/xlogfiles/slex/xlogfile',
  'hfe.slx.log',
  'https://eu.hardfought.org/userdata/%U/%u/slex/dumplog/%s.slex.txt',
  TRUE, FALSE, TRUE, 'UTC'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  52, 'eu.hardfought.org (SpliceHack)',
  'hfe', 'sph',
  'https://eu.hardfought.org/xlogfiles/splicehack/xlogfile',
  'hfe.spl.log',
  NULL,
  TRUE, FALSE, TRUE, 'UTC'
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
  '{"bug360duration"}',
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
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, oper,
  static, httpcont, tz
) VALUES (
  48, 'em.slash.em (SLASH''EM Extended)',
  'esm', 'slx',
  'https://em.slashem.me/xlogfiles/slex',
  'esm.slx.log',
  'https://em.slashem.me/userdata/%u/slex/dumplog/%s.txt',
  TRUE, FALSE, TRUE, 'UTC'
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
  NULL,
  TRUE, TRUE, FALSE,
  'UTC', NULL, NULL
);

-----------------------------------------------------------------------------
-- /dev/null/nethack Tribute 2017 -------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles VALUES (
  2017, '/dev/null Tribute 2017',
  'dnt', 'nh', NULL,
  'https://hardfought.org/devnull/xlogfiles.dnt',
  'devnull-2017.log',
  'https://www.hardfought.org/userdata/%U/%u/dn36/dumplog/%s.dn36.txt',
  NULL,
  NULL,
  TRUE, FALSE, TRUE,
  'UTC', NULL, NULL
);
