-----------------------------------------------------------------------------
-- This file defines data sources NHS aggregates. Please note, that we define
-- all sources with oper = TRUE, even historical sources with static = TRUE.
-- The nhdb-feeder will read all operational sources in and if they are
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
  'https://s3.amazonaws.com/altorg/dumplog/%x/%s.nh343.txt'
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
  'https://s3.amazonaws.com/altorg/dumplog/%x/%s.nh361.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  75, 'nethack.alt.org (3.6.2)', 'nao', 'nh',
  'https://alt.org/nethack/xlogfile.nh362',
  'nao.nh.362.log',
  'https://s3.amazonaws.com/altorg/dumplog/%x/%s.nh362.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  79, 'nethack.alt.org (3.6.3-3.6.6)', 'nao', 'nh',
  'https://alt.org/nethack/xlogfile.nh363+',
  'nao.nh.363-6.log',
  'https://s3.amazonaws.com/altorg/dumplog/%x/%s.nh%V.txt'
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
  'https://ascension.run/history/ade/userdata/%x/acehack/dumplog/%s',
  TRUE
);

-----------------------------------------------------------------------------
-- eu.un.nethack.nu/UNE (defunct) -------------------------------------------
-----------------------------------------------------------------------------

-- Shut down in May 2018, archived on ascension.run

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  3, 'eu.un.nethack.nu', 'une', 'un',
  'https://ascension.run/history/unn/eu/xlogfile',
  'une.un.log',
  'https://ascension.run/history/unn/users/%x/dumps/eu/%x.%e.txt.html',
  TRUE
);

-----------------------------------------------------------------------------
-- us.un.nethack.nu/UNU (defunct) -------------------------------------------
-----------------------------------------------------------------------------

-- Shut down in May 2018, archived on ascension.run

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  10, 'us.un.nethack.nu', 'unu', 'un',
  'https://ascension.run/history/unn/us/xlogfile',
  'unu.un.log',
  'https://ascension.run/history/unn/users/%x/dumps/us/%x.%e.txt.html',
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
  6, 'sporkhack.com', 'shc', 'spork',
  'http://sporkhack.com/xlogfile',
  'shc.spork.log',
  TRUE
);

-----------------------------------------------------------------------------
-- grunthack.org/GHO --------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  7, 'grunthack.org', 'gho', 'grunt',
  'http://grunthack.org/xlogfile',
  'gho.grunt.log',
  'http://grunthack.org/userdata/%X/%x/dumplog/%s.gh020.txt'
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
  'https://ascension.run/history/ilbelkyr/userdata/%x/dnethack/dumplog/%s',
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
 'https://ascension.run/history/aeu/userdata/%x/acehack/dumplog/%s',
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
  'https://ascension.run/userdata/%x/nethack/dumplog/%s'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  12, 'ascension.run (dNetHack)', 'asc', 'dnh',
  'https://ascension.run/xlogfiles/dnethack',
  'asc.dnh.log',
  'https://ascension.run/userdata/%x/dnethack/dumplog/%s'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  13, 'ascension.run (Fourk)', 'asc', '4k',
  'https://ascension.run/xlogfiles/nhfourk',
  'asc.4k.log',
  'https://ascension.run/userdata/%x/nhfourk/dumplog/%D'
);

--- Junethack 2015 SporkHack

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  14, 'ascension.run (SporkHack 2015)', 'asc', 'spork',
  'https://ascension.run/history/junethack2015/xlogfiles/sporkhack',
  'asc.spork.2015.log',
  'https://ascension.run/history/junethack2015/userdata/%x/sporkhack/dumplog/%s',
  TRUE
);

--- Junethack 2015 GruntHack

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  15, 'ascension.run (GruntHack 2015)', 'asc', 'grunt',
  'https://ascension.run/history/junethack2015/xlogfiles/grunthack',
  'asc.grunt.2015.log',
  'https://ascension.run/history/junethack2015/userdata/%x/grunthack/dumplog/%s',
  TRUE
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  16, 'ascension.run (UnNetHack)', 'asc', 'un',
  'https://ascension.run/xlogfiles/unnethack',
  'asc.un.log',
  'https://ascension.run/userdata/%x/unnethack/dumplog/%s.html'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  17, 'ascension.run (DynaHack)', 'asc', 'dyn',
  'https://ascension.run/xlogfiles/dynahack',
  'asc.dyn.log',
  'https://ascension.run/userdata/%x/dynahack/dumplog/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  18, 'ascension.run (NetHack4)', 'asc', 'nh4',
  'https://ascension.run/xlogfiles/nethack4',
  'asc.nh4.log',
  'https://ascension.run/userdata/%x/nethack4/dumplog/%D'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, options
) VALUES (
  19, 'ascension.run (FIQHack)', 'asc', 'fiq',
  'https://ascension.run/xlogfiles/fiqhack',
  'asc.fiq.log',
  'https://ascension.run/userdata/%x/fiqhack/dumplog/%D',
  '{"base64xlog"}'
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
  'https://www.hardfought.org/userdata/%X/%x/nh343/dumplog/%s.nh343.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  23, 'hardfought.org (GruntHack)', 'hdf', 'grunt',
  'https://www.hardfought.org/xlogfiles/gh/xlogfile',
  'hdf.grunt.log',
  'https://www.hardfought.org/userdata/%X/%x/gh/dumplog/%s.gh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  24, 'hardfought.org (UnNetHack)', 'hdf', 'un',
  'https://www.hardfought.org/xlogfiles/unnethack/xlogfile',
  'hdf.un.log',
  'https://www.hardfought.org/userdata/%X/%x/unnethack/dumplog/%s.un.txt.html'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  25, 'hardfought.org (NetHack)', 'hdf', 'nh',
  'https://www.hardfought.org/xlogfiles/nethack/xlogfile',
  'hdf.nh.log',
  'https://www.hardfought.org/userdata/%X/%x/nethack/dumplog/%s.nh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  76, 'hardfought.org (NetHack 3.7.x)', 'hdf', 'nh',
  'https://www.hardfought.org/xlogfiles/nethack/xlogfile-370-hdf',
  'hdf.nh.37x.log',
  'https://www.hardfought.org/userdata/%X/%x/nethack/dumplog/%s.nh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, options
) VALUES (
  29, 'hardfought.org (FIQHack)', 'hdf', 'fiq',
  'https://www.hardfought.org/xlogfiles/fh/xlogfile',
  'hdf.fiq.log',
  'https://www.hardfought.org/userdata/%X/%x/fiqhack/dumplog/%D',
  '{"base64xlog"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  30, 'hardfought.org (Fourk)', 'hdf', '4k',
  'https://www.hardfought.org/xlogfiles/4k/xlogfile',
  'hdf.4k.log',
  'https://www.hardfought.org/userdata/%X/%x/nhfourk/dumps/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  31, 'hardfought.org (dNetHack)', 'hdf', 'dnh',
  'https://www.hardfought.org/xlogfiles/dnethack/xlogfile',
  'hdf.dnh.log',
  'https://www.hardfought.org/userdata/%X/%x/dnethack/dumplog/%s.dnh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  32, 'hardfought.org (NetHack 4)', 'hdf', 'nh4',
  'https://www.hardfought.org/xlogfiles/nethack4/xlogfile',
  'hdf.nh4.log',
  'https://www.hardfought.org/userdata/%X/%x/nethack4/dumplog/%D'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  33, 'hardfought.org (DynaHack)', 'hdf', 'dyn',
  'https://www.hardfought.org/xlogfiles/dynahack/xlogfile',
  'hdf.dyn.log',
  'https://www.hardfought.org/userdata/%X/%x/dynahack/dumplog/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  34, 'hardfought.org (SporkHack)', 'hdf', 'spork',
  'https://www.hardfought.org/xlogfiles/sporkhack/xlogfile',
  'hdf.spork.log',
  'https://www.hardfought.org/userdata/%X/%x/sporkhack/dumplog/%s.sp.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  45, 'hardfought.org (xNetHack)', 'hdf', 'xnh',
  'https://www.hardfought.org/xlogfiles/xnethack/xlogfile',
  'hdf.xnh.log',
  'https://www.hardfought.org/userdata/%X/%x/xnethack/dumplog/%s.xnh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  47, 'hardfought.org (SLASH''EM Extended)', 'hdf', 'slex',
  'https://www.hardfought.org/xlogfiles/slex/xlogfile',
  'hdf.slex.log',
  'https://www.hardfought.org/userdata/%X/%x/slex/dumplog/%s.slex.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  51, 'hardfought.org (SpliceHack)', 'hdf', 'spl',
  'https://www.hardfought.org/xlogfiles/splicehack/xlogfile',
  'hdf.spl.log',
  'https://www.hardfought.org/userdata/%X/%x/splicehack/dumplog/%s.splice.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  69, 'hardfought.org (SLASH''EM)', 'hdf', 'slashem',
  'https://www.hardfought.org/xlogfiles/slashem/xlogfile',
  'hdf.slashem.log',
  'https://www.hardfought.org/userdata/%X/%x/slashem/dumplog/%s.slashem.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  72, 'hardfought.org (EvilHack)', 'hdf', 'evil',
  'https://www.hardfought.org/xlogfiles/evilhack/xlogfile',
  'hdf.evil.log',
  'https://www.hardfought.org/userdata/%X/%x/evilhack/dumplog/%s.evil.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  82, 'hardfought.org (notdNetHack)', 'hdf', 'ndnh',
  'https://www.hardfought.org/xlogfiles/notdnethack/xlogfile',
  'hdf.ndnh.log',
  'https://www.hardfought.org/userdata/%X/%x/notdnethack/dumplog/%s.ndnh.txt'
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
  'https://eu.hardfought.org/userdata/%X/%x/nh343/dumplog/%s.nh343.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  36, 'eu.hardfought.org (NetHack)', 'hfe', 'nh',
  'https://eu.hardfought.org/xlogfiles/nethack/xlogfile',
  'hfe.nh.log',
  'https://eu.hardfought.org/userdata/%X/%x/nethack/dumplog/%s.nh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  77, 'eu.hardfought.org (NetHack 3.7.x)', 'hfe', 'nh',
  'https://eu.hardfought.org/xlogfiles/nethack/xlogfile-370-hdf',
  'hfe.nh.37x.log',
  'https://eu.hardfought.org/userdata/%X/%x/nethack/dumplog/%s.nh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  37, 'eu.hardfought.org (NetHack Fourk)', 'hfe', '4k',
  'https://eu.hardfought.org/xlogfiles/4k/xlogfile',
  'hfe.4k.log',
  'https://eu.hardfought.org/userdata/%X/%x/nhfourk/dumps/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  38, 'eu.hardfought.org (dNetHack)', 'hfe', 'dnh',
  'https://eu.hardfought.org/xlogfiles/dnethack/xlogfile',
  'hfe.dnh.log',
  'https://eu.hardfought.org/userdata/%X/%x/dnethack/dumplog/%s.dnh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, options
) VALUES (
  39, 'eu.hardfought.org (FIQHack)', 'hfe', 'fiq',
  'https://eu.hardfought.org/xlogfiles/fh/xlogfile',
  'hfe.fiq.log',
  'https://eu.hardfought.org/userdata/%X/%x/fiqhack/dumplog/%D',
  '{"base64xlog"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  40, 'eu.hardfought.org (GruntHack)', 'hfe', 'grunt',
  'https://eu.hardfought.org/xlogfiles/gh/xlogfile',
  'hfe.grunt.log',
  'https://eu.hardfought.org/userdata/%X/%x/gh/dumplog/%s.gh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  41, 'eu.hardfought.org (NetHack 4)', 'hfe', 'nh4',
  'https://eu.hardfought.org/xlogfiles/nethack4/xlogfile',
  'hfe.nh4.log',
  'https://eu.hardfought.org/userdata/%X/%x/nethack4/dumplog/%D'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  42, 'eu.hardfought.org (SporkHack)', 'hfe', 'spork',
  'https://eu.hardfought.org/xlogfiles/sporkhack/xlogfile',
  'hfe.spork.log',
  'https://eu.hardfought.org/userdata/%X/%x/sporkhack/dumplog/%s.sp.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  43, 'eu.hardfought.org (UnNetHack)', 'hfe', 'un',
  'https://eu.hardfought.org/xlogfiles/unnethack/xlogfile',
  'hfe.un.log',
  'https://eu.hardfought.org/userdata/%X/%x/unnethack/dumplog/%s.un.txt.html'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  44, 'eu.hardfought.org (DynaHack)', 'hfe', 'dyn',
  'https://eu.hardfought.org/xlogfiles/dynahack/xlogfile',
  'hfe.dyn.log',
  'https://eu.hardfought.org/userdata/%X/%x/dynahack/dumplog/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  46, 'eu.hardfought.org (xNetHack)', 'hfe', 'xnh',
  'https://eu.hardfought.org/xlogfiles/xnethack/xlogfile',
  'hfe.xnh.log',
  'https://eu.hardfought.org/userdata/%X/%x/xnethack/dumplog/%s.xnh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  49, 'eu.hardfought.org (SLASH''EM Extended)', 'hfe', 'slex',
  'https://eu.hardfought.org/xlogfiles/slex/xlogfile',
  'hfe.slex.log',
  'https://eu.hardfought.org/userdata/%X/%x/slex/dumplog/%s.slex.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  52, 'eu.hardfought.org (SpliceHack)', 'hfe', 'spl',
  'https://eu.hardfought.org/xlogfiles/splicehack/xlogfile',
  'hfe.spl.log',
  'https://eu.hardfought.org/userdata/%X/%x/splicehack/dumplog/%s.splice.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  70, 'eu.hardfought.org (SLASH''EM)', 'hfe', 'slashem',
  'https://eu.hardfought.org/xlogfiles/slashem/xlogfile',
  'hfe.slashem.log',
  'https://eu.hardfought.org/userdata/%X/%x/slashem/dumplog/%s.slashem.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  73, 'eu.hardfought.org (EvilHack)', 'hfe', 'evil',
  'https://eu.hardfought.org/xlogfiles/evilhack/xlogfile',
  'hfe.evil.log',
  'https://eu.hardfought.org/userdata/%X/%x/evilhack/dumplog/%s.evil.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  83, 'eu.hardfought.org (notdNetHack)', 'hfe', 'ndnh',
  'https://eu.hardfought.org/xlogfiles/notdnethack/xlogfile',
  'hfe.ndnh.log',
  'https://eu.hardfought.org/userdata/%X/%x/notdnethack/dumplog/%s.ndnh.txt'
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
  'https://au.hardfought.org/userdata/%X/%x/nh343/dumplog/%s.nh343.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  54, 'au.hardfought.org (GruntHack)', 'hfa', 'grunt',
  'https://au.hardfought.org/xlogfiles/gh/xlogfile',
  'hfa.grunt.log',
  'https://au.hardfought.org/userdata/%X/%x/gh/dumplog/%s.gh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  55, 'au.hardfought.org (UnNetHack)', 'hfa', 'un',
  'https://au.hardfought.org/xlogfiles/unnethack/xlogfile',
  'hfa.un.log',
  'https://au.hardfought.org/userdata/%X/%x/unnethack/dumplog/%s.un.txt.html'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  56, 'au.hardfought.org (NetHack)', 'hfa', 'nh',
  'https://au.hardfought.org/xlogfiles/nethack/xlogfile',
  'hfa.nh.log',
  'https://au.hardfought.org/userdata/%X/%x/nethack/dumplog/%s.nh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  78, 'au.hardfought.org (NetHack 3.7.x)', 'hfa', 'nh',
  'https://au.hardfought.org/xlogfiles/nethack/xlogfile-370-hdf',
  'hfa.nh.37x.log',
  'https://au.hardfought.org/userdata/%X/%x/nethack/dumplog/%s.nh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, options
) VALUES (
  57, 'au.hardfought.org (FIQHack)', 'hfa', 'fiq',
  'https://au.hardfought.org/xlogfiles/fh/xlogfile',
  'hfa.fiq.log',
  'https://au.hardfought.org/userdata/%X/%x/fiqhack/dumplog/%D',
  '{"base64xlog"}'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  58, 'au.hardfought.org (Fourk)', 'hfa', '4k',
  'https://au.hardfought.org/xlogfiles/4k/xlogfile',
  'hfa.4k.log',
  'https://au.hardfought.org/userdata/%X/%x/nhfourk/dumps/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  59, 'au.hardfought.org (dNetHack)', 'hfa', 'dnh',
  'https://au.hardfought.org/xlogfiles/dnethack/xlogfile',
  'hfa.dnh.log',
  'https://au.hardfought.org/userdata/%X/%x/dnethack/dumplog/%s.dnh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  60, 'au.hardfought.org (NetHack 4)', 'hfa', 'nh4',
  'https://au.hardfought.org/xlogfiles/nethack4/xlogfile',
  'hfa.nh4.log',
  'https://au.hardfought.org/userdata/%X/%x/nethack4/dumplog/%D'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  61, 'au.hardfought.org (DynaHack)', 'hfa', 'dyn',
  'https://au.hardfought.org/xlogfiles/dynahack/xlogfile',
  'hfa.dyn.log',
  'https://au.hardfought.org/userdata/%X/%x/dynahack/dumplog/%d'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  62, 'au.hardfought.org (SporkHack)', 'hfa', 'spork',
  'https://au.hardfought.org/xlogfiles/sporkhack/xlogfile',
  'hfa.spork.log',
  'https://au.hardfought.org/userdata/%X/%x/sporkhack/dumplog/%s.sp.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  63, 'au.hardfought.org (xNetHack)', 'hfa', 'xnh',
  'https://au.hardfought.org/xlogfiles/xnethack/xlogfile',
  'hfa.xnh.log',
  'https://au.hardfought.org/userdata/%X/%x/xnethack/dumplog/%s.xnh.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  64, 'au.hardfought.org (SLASH''EM Extended)', 'hfa', 'slex',
  'https://au.hardfought.org/xlogfiles/slex/xlogfile',
  'hfa.slex.log',
  'https://au.hardfought.org/userdata/%X/%x/slex/dumplog/%s.slex.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  65, 'au.hardfought.org (SpliceHack)', 'hfa', 'spl',
  'https://au.hardfought.org/xlogfiles/splicehack/xlogfile',
  'hfa.spl.log',
  'https://au.hardfought.org/userdata/%X/%x/splicehack/dumplog/%s.splice.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  71, 'au.hardfought.org (SLASH''EM)', 'hfa', 'slashem',
  'https://au.hardfought.org/xlogfiles/slashem/xlogfile',
  'hfa.slashem.log',
  'https://au.hardfought.org/userdata/%X/%x/slashem/dumplog/%s.slashem.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  74, 'au.hardfought.org (EvilHack)', 'hfa', 'evil',
  'https://au.hardfought.org/xlogfiles/evilhack/xlogfile',
  'hfa.evil.log',
  'https://au.hardfought.org/userdata/%X/%x/evilhack/dumplog/%s.evil.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  84, 'au.hardfought.org (notdNetHack)', 'hfa', 'ndnh',
  'https://au.hardfought.org/xlogfiles/notdnethack/xlogfile',
  'hfa.ndnh.log',
  'https://au.hardfought.org/userdata/%X/%x/notdnethack/dumplog/%s.ndnh.txt'
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
  'https://em.slashem.me/userdata/%x/nethack/dumplog/%E.txt',
  '{"bug360duration"}'
);

--- xlogfile gratuitously discontinued on June 8, 2018

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  27, 'em.slashem.me (GruntHack)', 'esm', 'grunt',
  'https://em.slashem.me/xlogfiles/grunthackold',
  'esm.grunt.log',
  'https://em.slashem.me/userdata/%x/grunthack/dumplog/%s.txt',
  TRUE
);

--- xlogfile gratuitously discontinued on June 8, 2018

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  28, 'em.slashem.me (SporkHack)', 'esm', 'spork',
  'https://em.slashem.me/xlogfiles/sporkhackold',
  'esm.spork.log',
  'https://em.slashem.me/userdata/%x/sporkhack/dumplog/%s.txt',
  TRUE
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  48, 'em.slash.em (SLASH''EM Extended)', 'esm', 'slex',
  'https://em.slashem.me/xlogfiles/slex',
  'esm.slex.log',
  'https://em.slashem.me/userdata/%x/slex/dumplog/%s.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  66, 'em.slashem.me (GruntHack)', 'esm', 'grunt',
  'https://em.slashem.me/xlogfiles/grunthack',
  'esm.grunt.01.log',
  'https://em.slashem.me/userdata/%x/grunthack/dumplog/%s.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  67, 'em.slashem.me (SporkHack)', 'esm', 'spork',
  'https://em.slashem.me/xlogfiles/sporkhackold',
  'esm.spork.01.log',
  'https://em.slashem.me/userdata/%x/sporkhack/dumplog/%s.txt'
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  68, 'em.slashem.me (dnhslex)', 'esm', 'dnhslex',
  'https://em.slashem.me/xlogfiles/dnhslex',
  'esm.dnhslex.01.log',
  'https://em.slashem.me/userdata/%x/dnhslex/dumplog/%s'
);

-----------------------------------------------------------------------------
-- nethack.eu/NEU -----------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl
) VALUES (
  81, 'nethack.eu (nh343)', 'neu', 'nh',
  'https://lilith.gnuffy.net/neu/xlogfile',
  'neu.nh343.02.log',
  'https://nethackscoreboard.org/neu_dumplogs/%x/nethack/dumplog/%s'
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
  'https://www.hardfought.org/userdata/%X/%x/dn36/dumplog/%s.dn36.txt',
  TRUE
);

-----------------------------------------------------------------------------
-- TNNT ---------------------------------------------------------------------
-----------------------------------------------------------------------------

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  2018, 'The November NetHack Tournament 2018', 'nnt', 'nh',
  'https://www.hardfought.org/tnnt/archives/2018/xlogfiles/xlogfile.tnnt.2018',
  'tnnt-2018.log',
  'https://%S.hardfought.org/userdata/%X/%x/tnnt/dumplog/%s.tnnt.txt',
  TRUE
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  2019, 'The November NetHack Tournament 2019', 'nnt', 'nh',
  'https://www.hardfought.org/tnnt/archives/2019/xlogfiles/xlogfile.tnnt.2019',
  'tnnt-2019.log',
  'https://%S.hardfought.org/userdata/%X/%x/tnnt/dumplog/%s.tnnt.html',
  TRUE
);

INSERT INTO logfiles (
  logfiles_i, descr, server, variant, logurl, localfile, dumpurl, static
) VALUES (
  2020, 'The November NetHack Tournament 2020', 'nnt', 'nh',
  'https://www.hardfought.org/tnnt/archives/2020/xlogfiles/xlogfile.tnnt.2020',
  'tnnt-2020.log',
  'https://%S.hardfought.org/userdata/%X/%x/tnnt/dumplog/%s.tnnt.html',
  TRUE
);