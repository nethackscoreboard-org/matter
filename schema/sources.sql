-----------------------------------------------------------------------------
-- This file defines data sources NHS aggregates. Please note, that we define
-- all sources with oper = TRUE, even historical sources with static = TRUE.
-- The nhdf-feeder will read all operational sources in and if they are
-- static, it will toggle the 'oper' field to false.
-----------------------------------------------------------------------------


-----------------------------------------------------------------------------
-- nethack.alt org/NAO ------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  1, 'nethack.alt.org (3.4.3)', 'nao', 'nh',
  'http://alt.org/nethack/xlogfile.full.txt',
  'nao.nh.343.log',
  'https://s3.amazonaws.com/altorg/dumplog/%u/%s.nh343.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, options
) VALUES (
  20, 'nethack.alt.org (3.6.0)', 'nao', 'nh',
  'https://alt.org/nethack/xlogfile.nh360',
  'nao.nh.360.log',
  '{"bug360duration"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile
) VALUES (
  21, 'nethack.alt.org (3.6.1dev)', 'nao', 'nh',
  'https://alt.org/nethack/xlogfile.nh361dev',
  'nao.nh.361dev.log'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  50, 'nethack.alt.org (3.6.1)', 'nao', 'nh',
  'https://alt.org/nethack/xlogfile.nh361',
  'nao.nh.361.log',
  'https://s3.amazonaws.com/altorg/dumplog/%u/%s.nh361.txt'
);

-----------------------------------------------------------------------------
-- acehack.de/ADE (defunct) -------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  5, 'acehack.de', 'ade', 'ace',
  'https://ascension.run/history/ade/xlogfiles/acehack',
  'ade.ace.log',
  'https://ascension.run/history/ade/userdata/%u/acehack/dumplog/%s',
  TRUE
);

-----------------------------------------------------------------------------
-- eu.un.nethack.nu/UNE (defunct) -------------------------------------------
-----------------------------------------------------------------------------

-- Shut down in May 2018, archived on ascension.run

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  3, 'eu.un.nethack.nu', 'une', 'unh',
  'https://ascension.run/history/unn/eu/xlogfile'
  'une.unh.log',
  'https://ascension.run/history/unn/users/%u/dumps/eu/%u.%e.txt.html'
  TRUE
);

-----------------------------------------------------------------------------
-- us.un.nethack.nu/UNU (defunct) -------------------------------------------
-----------------------------------------------------------------------------

-- Shut down in May 2018, archived on ascension.run

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  10, 'us.un.nethack.nu', 'unu', 'unh',
  'https://ascension.run/history/unn/us/xlogfile'
  'unu.unh.log',
  'https://ascension.run/history/unn/users/%u/dumps/us/%u.%e.txt.html'
  TRUE
);

-----------------------------------------------------------------------------
-- nethack4.org/N4O ---------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  4, 'nethack4.org (4.3)', 'n4o', 'nh4',
  'http://nethack4.org/xlogfile.txt',
  'n4o.nh4-3.log',
  'http://nethack4.org/dumps/%D'
);

-- Discontinued sometime in 2014, apparently no game dumps available

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, static
) VALUES (
  8, 'nethack4.org (4.2)', 'n4o', 'nh4',
  'http://nethack4.org/4.2-xlogfile',
  'n4o.nh4-2.log',
  TRUE
);

-----------------------------------------------------------------------------
-- sporkhack.com/SHC (defunct) ----------------------------------------------
-----------------------------------------------------------------------------

-- Shut down in 2015, dump logs unavailable

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, static
) VALUES (
  6, 'sporkhack.com', 'shc', 'sh',
  'http://sporkhack.com/xlogfile',
  'shc.sh.log',
  TRUE
);

-----------------------------------------------------------------------------
-- grunthack.org/GHO --------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  7, 'grunthack.org', 'gho', 'gh',
  'http://grunthack.org/xlogfile',
  'gho.gh.log',
  'http://grunthack.org/userdata/%U/%u/dumplog/%s.gh020.txt'
);

-----------------------------------------------------------------------------
-- dnethack.ilbelkyr.de/DID (defunct) ---------------------------------------
-----------------------------------------------------------------------------

-- Shutdown in 2014, game dumps archived on ascension.run

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  9, 'dnethack.ilbelkyr.de', 'did', 'dnh',
  'http://dnethack.ilbelkyr.de/xlogfile.txt',
  'did.dnh.log',
  'https://ascension.run/history/ilbelkyr/userdata/%u/dnethack/dumplog/%s',
  TRUE
);

-----------------------------------------------------------------------------
-- acehack.eu/AEU (defunct) -------------------------------------------------
-----------------------------------------------------------------------------

-- Shutdown in 2012, game dumps archived on ascension.run

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
 11, 'acehack.eu', 'aeu', 'ace',
 'https://ascension.run/history/aeu/xlogfiles/acehack',
 'aeu.ace.log',
 'https://ascension.run/history/aeu/userdata/%u/acehack/dumplog/%s',
 TRUE
);

-----------------------------------------------------------------------------
--- ascension.run/ASC  ------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  2, 'ascension.run (NetHack 3.4.3)', 'asc', 'nh',
  'https://ascension.run/xlogfiles/nethack',
  'asc.nh.log',
  'https://ascension.run/userdata/%u/nethack/dumplog/%s'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  12, 'ascension.run (dNetHack)', 'asc', 'dnh',
  'https://ascension.run/xlogfiles/dnethack',
  'asc.dnh.log',
  'https://ascension.run/userdata/%u/dnethack/dumplog/%s'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  13, 'ascension.run (Fourk)', 'asc', 'nhf',
  'https://ascension.run/xlogfiles/nhfourk',
  'asc.nhf.log',
  'https://ascension.run/userdata/%u/nhfourk/dumplog/%D'
);

--- Junethack 2015 SporkHack

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  14, 'ascension.run (SporkHack 2015)', 'asc', 'sh',
  'https://ascension.run/history/junethack2015/xlogfiles/sporkhack',
  'asc.sh.2015.log',
  'https://ascension.run/history/junethack2015/userdata/%u/sporkhack/dumplog/%s',
  TRUE
);

--- Junethack 2015 GruntHack

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  15, 'ascension.run (GruntHack 2015)', 'asc', 'gh',
  'https://ascension.run/history/junethack2015/xlogfiles/grunthack',
  'asc.gh.2015.log',
  'https://ascension.run/history/junethack2015/userdata/%u/grunthack/dumplog/%s',
  TRUE
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  16, 'ascension.run (UnNetHack)', 'asc', 'unh',
  'https://ascension.run/xlogfiles/unnethack',
  'asc.unh.log',
  'https://ascension.run/userdata/%u/unnethack/dumplog/%s.html'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  17, 'ascension.run (DynaHack)', 'asc', 'dyn',
  'https://ascension.run/xlogfiles/dynahack',
  'asc.dyn.log',
  'https://ascension.run/userdata/%u/dynahack/dumplog/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  18, 'ascension.run (NetHack4)', 'asc', 'nh4',
  'https://ascension.run/xlogfiles/nethack4',
  'asc.nh4.log',
  'https://ascension.run/userdata/%u/nethack4/dumplog/%D'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, options
) VALUES (
  19, 'ascension.run (FIQHack)', 'asc', 'fh',
  'https://ascension.run/xlogfiles/fiqhack',
  'asc.fh.log',
  'https://ascension.run/userdata/%u/fiqhack/dumplog/%D',
  '{"base64xlog"}',
);

-----------------------------------------------------------------------------
--- hardfought.org/HDF  -----------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  22, 'hardfought.org (NetHack 3.4.3)', 'hdf', 'nh',
  'https://www.hardfought.org/xlogfiles/nh343/xlogfile',
  'hdf.nh.343.log',
  'https://www.hardfought.org/userdata/%U/%u/nh343/dumplog/%s.nh343.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  23, 'hardfought.org (GruntHack)', 'hdf', 'gh',
  'https://www.hardfought.org/xlogfiles/gh/xlogfile',
  'hdf.gh.log',
  'https://www.hardfought.org/userdata/%U/%u/gh/dumplog/%s.gh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  24, 'hardfought.org (UnNetHack)', 'hdf', 'unh',
  'https://www.hardfought.org/xlogfiles/un531/xlogfile',
  'hdf.unh.log',
  'https://www.hardfought.org/userdata/%U/%u/un531/dumplog/%s.un531.txt.html'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  25, 'hardfought.org (NetHack 3.6.1)', 'hdf', 'nh',
  'https://www.hardfought.org/xlogfiles/nh361/xlogfile',
  'hdf.nh361.log',
  'https://www.hardfought.org/userdata/%U/%u/nh361/dumplog/%s.nh361.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, options
) VALUES (
  29, 'hardfought.org (FIQHack)', 'hdf', 'fh',
  'https://www.hardfought.org/xlogfiles/fh/xlogfile',
  'hdf.fh.log',
  'https://www.hardfought.org/userdata/%U/%u/fiqhack/dumplog/%D',
  '{"base64xlog"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  30, 'hardfought.org (Fourk)', 'hdf', 'nhf',
  'https://www.hardfought.org/xlogfiles/4k/xlogfile',
  'hdf.nhf.log',
  'https://www.hardfought.org/userdata/%U/%u/nhfourk/dumps/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  31, 'hardfought.org (dNetHack)', 'hdf', 'dnh',
  'https://www.hardfought.org/xlogfiles/dnethack/xlogfile',
  'hdf.dnh.log',
  'https://www.hardfought.org/userdata/%U/%u/dnethack/dumplog/%s.dnh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  32, 'hardfought.org (NetHack 4)', 'hdf', 'nh4',
  'https://www.hardfought.org/xlogfiles/nethack4/xlogfile',
  'hdf.nh4.log',
  'https://www.hardfought.org/userdata/%U/%u/nethack4/dumplog/%D'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  33, 'hardfought.org (DynaHack)', 'hdf', 'dyn',
  'https://www.hardfought.org/xlogfiles/dynahack/xlogfile',
  'hdf.dyn.log',
  'https://www.hardfought.org/userdata/%U/%u/dynahack/dumplog/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  34, 'hardfought.org (SporkHack)', 'hdf', 'sh',
  'https://www.hardfought.org/xlogfiles/sporkhack/xlogfile',
  'hdf.sh.log',
  'https://www.hardfought.org/userdata/%U/%u/sporkhack/dumplog/%s.sp.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  45, 'hardfought.org (xNetHack)', 'hdf', 'xnh',
  'https://www.hardfought.org/xlogfiles/xnethack/xlogfile',
  'hdf.xnh.log',
  'https://www.hardfought.org/userdata/%U/%u/xnethack/dumplog/%s.xnh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  47, 'hardfought.org (SLASH''EM Extended)', 'hdf', 'slx',
  'https://www.hardfought.org/xlogfiles/slex/xlogfile',
  'hdf.slx.log',
  'https://www.hardfought.org/userdata/%U/%u/slex/dumplog/%s.slex.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  51, 'hardfought.org (SpliceHack)', 'hdf', 'sph',
  'https://www.hardfought.org/xlogfiles/splicehack/xlogfile',
  'hdf.spl.log',
  'https://www.hardfought.org/userdata/%U/%u/splicehack/dumplog/%s.splice.txt'
);

-----------------------------------------------------------------------------
-- hardfought.org Europe/HFE ------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  35, 'eu.hardfought.org (NetHack 3.4.3)', 'hfe', 'nh',
  'https://eu.hardfought.org/xlogfiles/nh343/xlogfile',
  'hfe.nh.343.log',
  'https://eu.hardfought.org/userdata/%U/%u/nh343/dumplog/%s.nh343.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  36, 'eu.hardfought.org (NetHack 3.6.1)', 'hfe', 'nh',
  'https://eu.hardfought.org/xlogfiles/nh361/xlogfile',
  'hfe.nh.361.log',
  'https://eu.hardfought.org/userdata/%U/%u/nh361/dumplog/%s.nh361.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  37, 'eu.hardfought.org (NetHack Fourk)', 'hfe', 'nhf',
  'https://eu.hardfought.org/xlogfiles/4k/xlogfile',
  'hfe.nhf.log',
  'https://eu.hardfought.org/userdata/%U/%u/nhfourk/dumps/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  38, 'eu.hardfought.org (dNetHack)', 'hfe', 'dnh',
  'https://eu.hardfought.org/xlogfiles/dnethack/xlogfile',
  'hfe.dnh.log',
  'https://eu.hardfought.org/userdata/%U/%u/dnethack/dumplog/%s.dnh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, options
) VALUES (
  39, 'eu.hardfought.org (FIQHack)', 'hfe', 'fh',
  'https://eu.hardfought.org/xlogfiles/fh/xlogfile',
  'hfe.fh.log',
  'https://eu.hardfought.org/userdata/%U/%u/fiqhack/dumplog/%D',
  '{"base64xlog"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  40, 'eu.hardfought.org (GruntHack)', 'hfe', 'gh',
  'https://eu.hardfought.org/xlogfiles/gh/xlogfile',
  'hfe.gh.log',
  'https://eu.hardfought.org/userdata/%U/%u/gh/dumplog/%s.gh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  41, 'eu.hardfought.org (NetHack 4)', 'hfe', 'nh4',
  'https://eu.hardfought.org/xlogfiles/nethack4/xlogfile',
  'hfe.nh4.log',
  'https://eu.hardfought.org/userdata/%U/%u/nethack4/dumplog/%D'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  42, 'eu.hardfought.org (SporkHack)', 'hfe', 'sh',
  'https://eu.hardfought.org/xlogfiles/sporkhack/xlogfile',
  'hfe.sh.log',
  'https://eu.hardfought.org/userdata/%U/%u/sporkhack/dumplog/%s.sp.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  43, 'eu.hardfought.org (UnNetHack)', 'hfe', 'unh',
  'https://eu.hardfought.org/xlogfiles/un531/xlogfile',
  'hfe.unh.log',
  'https://eu.hardfought.org/userdata/%U/%u/un531/dumplog/%s.un531.txt.html'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  44, 'eu.hardfought.org (DynaHack)', 'hfe', 'dyn',
  'https://eu.hardfought.org/xlogfiles/dynahack/xlogfile',
  'hfe.dyn.log',
  'https://eu.hardfought.org/userdata/%U/%u/dynahack/dumplog/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  46, 'eu.hardfought.org (xNetHack)', 'hfe', 'xnh',
  'https://eu.hardfought.org/xlogfiles/xnethack/xlogfile',
  'hfe.xnh.log',
  'https://eu.hardfought.org/userdata/%U/%u/xnethack/dumplog/%s.xnh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  49, 'eu.hardfought.org (SLASH''EM Extended)', 'hfe', 'slx',
  'https://eu.hardfought.org/xlogfiles/slex/xlogfile',
  'hfe.slx.log',
  'https://eu.hardfought.org/userdata/%U/%u/slex/dumplog/%s.slex.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  52, 'eu.hardfought.org (SpliceHack)', 'hfe', 'sph',
  'https://eu.hardfought.org/xlogfiles/splicehack/xlogfile',
  'hfe.spl.log',
  'https://eu.hardfought.org/userdata/%U/%u/splicehack/dumplog/%s.splice.txt'
);

-----------------------------------------------------------------------------
-- hardfought.org Australia/HFA ---------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  53, 'au.hardfought.org (NetHack 3.4.3)', 'hfa', 'nh',
  'https://au.hardfought.org/xlogfiles/nh343/xlogfile',
  'hfa.nh.343.log',
  'https://au.hardfought.org/userdata/%U/%u/nh343/dumplog/%s.nh343.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  54, 'au.hardfought.org (GruntHack)', 'hfa', 'gh',
  'https://au.hardfought.org/xlogfiles/gh/xlogfile',
  'hfa.gh.log',
  'https://au.hardfought.org/userdata/%U/%u/gh/dumplog/%s.gh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  55, 'au.hardfought.org (UnNetHack)', 'hfa', 'unh',
  'https://au.hardfought.org/xlogfiles/un531/xlogfile',
  'hfa.unh.log',
  'https://au.hardfought.org/userdata/%U/%u/un531/dumplog/%s.un531.txt.html'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  56, 'au.hardfought.org (NetHack 3.6.1)', 'hfa', 'nh',
  'https://au.hardfought.org/xlogfiles/nh361/xlogfile',
  'hfa.nh361.log',
  'https://au.hardfought.org/userdata/%U/%u/nh361/dumplog/%s.nh361.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, options
) VALUES (
  57, 'au.hardfought.org (FIQHack)', 'hfa', 'fh',
  'https://au.hardfought.org/xlogfiles/fh/xlogfile',
  'hfa.fh.log',
  'https://au.hardfought.org/userdata/%U/%u/fiqhack/dumplog/%D',
  '{"base64xlog"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  58, 'au.hardfought.org (Fourk)', 'hfa', 'nhf',
  'https://au.hardfought.org/xlogfiles/4k/xlogfile',
  'hfa.nhf.log',
  'https://au.hardfought.org/userdata/%U/%u/nhfourk/dumps/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  59, 'au.hardfought.org (dNetHack)', 'hfa', 'dnh',
  'https://au.hardfought.org/xlogfiles/dnethack/xlogfile',
  'hfa.dnh.log',
  'https://au.hardfought.org/userdata/%U/%u/dnethack/dumplog/%s.dnh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  60, 'au.hardfought.org (NetHack 4)', 'hfa', 'nh4',
  'https://au.hardfought.org/xlogfiles/nethack4/xlogfile',
  'hfa.nh4.log',
  'https://hfa.hardfought.org/userdata/%U/%u/nethack4/dumplog/%D'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  61, 'au.hardfought.org (DynaHack)', 'hfa', 'dyn',
  'https://au.hardfought.org/xlogfiles/dynahack/xlogfile',
  'hfa.dyn.log',
  'https://au.hardfought.org/userdata/%U/%u/dynahack/dumplog/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  62, 'au.hardfought.org (SporkHack)', 'hfa', 'sh',
  'https://au.hardfought.org/xlogfiles/sporkhack/xlogfile',
  'hfa.sh.log',
  'https://au.hardfought.org/userdata/%U/%u/sporkhack/dumplog/%s.sp.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  63, 'au.hardfought.org (xNetHack)', 'hfa', 'xnh',
  'https://au.hardfought.org/xlogfiles/xnethack/xlogfile',
  'hfa.xnh.log',
  'https://au.hardfought.org/userdata/%U/%u/xnethack/dumplog/%s.xnh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  64, 'au.hardfought.org (SLASH''EM Extended)', 'hfa', 'slx',
  'https://au.hardfought.org/xlogfiles/slex/xlogfile',
  'hfa.slx.log',
  'https://au.hardfought.org/userdata/%U/%u/slex/dumplog/%s.slex.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  65, 'au.hardfought.org (SpliceHack)', 'hfa', 'sph',
  'https://au.hardfought.org/xlogfiles/splicehack/xlogfile',
  'hfa.spl.log',
  'https://au.hardfought.org/userdata/%U/%u/splicehack/dumplog/%s.splice.txt'
);

-----------------------------------------------------------------------------
-- em.slashem.me/ESM --------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, options
) VALUES (
  26, 'em.slashem.me (NetHack 3.6.0)', 'esm', 'nh',
  'https://em.slashem.me/xlogfiles/nethack',
  'esm.nh.360.log',
  'https://em.slashem.me/userdata/%u/nethack/dumplog/%E.txt',
  '{"bug360duration"}'
);

--- xlogfile gratuitously discontinued on June 8, 2018

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  27, 'em.slashem.me (GruntHack)', 'esm', 'gh',
  'https://em.slashem.me/xlogfiles/grunthackold',
  'esm.gh.log',
  'https://em.slashem.me/userdata/%u/grunthack/dumplog/%s.txt',
  TRUE
);

--- xlogfile gratuitously discontinued on June 8, 2018

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  28, 'em.slashem.me (SporkHack)', 'esm', 'sh',
  'https://em.slashem.me/xlogfiles/sporkhackold',
  'esm.sh.log',
  'https://em.slashem.me/userdata/%u/sporkhack/dumplog/%s.txt',
  TRUE
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  48, 'em.slash.em (SLASH''EM Extended)', 'esm', 'slx',
  'https://em.slashem.me/xlogfiles/slex',
  'esm.slx.log',
  'https://em.slashem.me/userdata/%u/slex/dumplog/%s.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  66, 'em.slashem.me (GruntHack)', 'esm', 'gh',
  'https://em.slashem.me/xlogfiles/grunthack',
  'esm.gh.01.log',
  'https://em.slashem.me/userdata/%u/grunthack/dumplog/%s.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  67, 'em.slashem.me (SporkHack)', 'esm', 'sh',
  'https://em.slashem.me/xlogfiles/sporkhackold',
  'esm.sh.01.log',
  'https://em.slashem.me/userdata/%u/sporkhack/dumplog/%s.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  68, 'em.slashem.me (dnhslex)', 'esm', 'dns',
  'https://em.slashem.me/xlogfiles/dnhslex',
  'esm.dns.01.log',
  'https://em.slashem.me/userdata/%u/dnhslex/dumplog/%s'
);

-----------------------------------------------------------------------------
-- nethack.devnull.com/DEV --------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, localfile, logurl, static, options
) VALUES (
  2006, '/dev/null 2006', 'dev', 'nh',
  'devnull-2006.log',
  NULL,
  TRUE, '{"devnull"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, localfile, logurl, static, options
) VALUES (
  2007, '/dev/null 2007', 'dev', 'nh',
  'devnull-2007.log',
  NULL,
  TRUE, '{"devnull"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, localfile, logurl, static, options
) VALUES (
  2008, '/dev/null 2008', 'dev', 'nh',
  'devnull-2008.log',
  NULL,
  TRUE, '{"devnull"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, localfile, logurl, static, options
) VALUES (
  2009, '/dev/null 2009', 'dev', 'nh',
  'devnull-2009.log',
  NULL,
  TRUE, '{"devnull"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, localfile, logurl, static, options
) VALUES (
  2010, '/dev/null 2010', 'dev', 'nh',
  'devnull-2010.log',
  NULL,
  TRUE, '{"devnull"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, localfile, logurl, static, options
) VALUES (
  2011, '/dev/null 2011', 'dev', 'nh',
  'devnull-2011.log',
  NULL,
  TRUE, '{"devnull"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, localfile, logurl, static, options
) VALUES (
  2012, '/dev/null 2012', 'dev', 'nh',
  'devnull-2012.log',
  NULL,
  TRUE, '{"devnull"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, localfile, logurl, static, options
) VALUES (
  2013, '/dev/null 2013', 'dev', 'nh',
  'devnull-2013.log',
  NULL,
  TRUE, '{"devnull"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, localfile, logurl, static, options
) VALUES (
  2014, '/dev/null 2014', 'dev', 'nh',
  'devnull-2014.log',
  NULL,
  TRUE, '{"devnull"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, localfile, logurl, static, options
) VALUES (
  2015, '/dev/null 2015', 'dev', 'nh',
  'devnull-2015.log',
  NULL,
  TRUE, '{"devnull"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, localfile, logurl, static, options
) VALUES (
  2016, '/dev/null 2016', 'dev', 'nh',
  'devnull-2016.log',
  NULL,
  TRUE, '{"devnull"}'
);

-----------------------------------------------------------------------------
-- /dev/null/nethack Tribute 2017/DNT ---------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  2017, '/dev/null Tribute 2017', 'dnt', 'nh',
  'https://hardfought.org/devnull/xlogfiles.dnt',
  'devnull-2017.log',
  'https://www.hardfought.org/userdata/%U/%u/dn36/dumplog/%s.dn36.txt',
  TRUE
);
