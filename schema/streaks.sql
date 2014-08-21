----------------------------------------------------------------------------
--- info
----------------------------------------------------------------------------

-- this set of tables is used for tracking streaks; we track streaks per
-- single server; normally, having games consequent would be enough of
-- a criteria, but devnull logs is actually assembled from multiple logs
-- so overlaps must be checked as well (and break streaks)
--
-- 'games_set' table holds sets of games, we will uses this for grouping
-- streak games into single entity
--
-- 'streaks' table represents actual streaks; there are two kinds of streaks:
--   1) closed streaks have open = false and num_games > 1
--   2) open streaks have open = true and num_games > 0
-- When open streak is broken at num_games = 1; the entry is deleted from
-- the table.
--
-- Description of the tracking logic
-- """""""""""""""""""""""""""""""""
-- 1) On the beginning of processing the logfile; have an empty hash
--    variable; the variable will be used as %var{logfiles_i}{name}; the
--    value will be boolean and will mean whether streak is open or not
--
-- 2) Start processing logfile; for each row do the following:
--
-- 3) If logfiles_i/name keys don't exist, initialize them with the
--    following query (it can only return 0 or 1:
--    SELECT count(*) FROM streaks WHERE logfiles_i AND name AND open = TRUE
--
-- 4.1) If current game is !ascended && streak is !open. NEXT LOOP
--
-- 4.2) If current game is ascended && streak is closed: add game to new
--      games_set; create new streak; set %var to open.
-- 
-- 4.3) If current game is ascended && streak is open: increase
--    streaks.num_games, add game to games_set. NEXT LOOP
--
-- 

----------------------------------------------------------------------------
--- clean-up
----------------------------------------------------------------------------

DROP TABLE streaks;
DROP TABLE games_set_map;
DROP TABLE games_set;


----------------------------------------------------------------------------
--- sequences
----------------------------------------------------------------------------

CREATE SEQUENCE games_set_seq;
CREATE SEQUENCE streaks_seq;
GRANT USAGE ON games_set_seq TO nhdbfeeder;
GRANT USAGE ON streaks_seq TO nhdbfeeder;


----------------------------------------------------------------------------
--- tables 
----------------------------------------------------------------------------

CREATE TABLE games_set (
  games_set_i    bigint DEFAULT nextval('games_set_seq') NOT NULL,
  PRIMARY KEY (games_set_i)
);

GRANT INSERT, SELECT, DELETE ON games_set TO nhdbfeeder;
GRANT SELECT ON games_set TO nhdbstats;


CREATE TABLE games_set_map (
  rowid         bigint REFERENCES games,
  games_set_i   bigint REFERENCES games_set,
  PRIMARY KEY (rowid, games_set_i)
);

GRANT INSERT, SELECT, DELETE ON games_set_map TO nhdbfeeder;
GRANT SELECT ON games_set_map TO nhdbstats;


CREATE TABLE streaks (
  streaks_i     bigint DEFAULT nextval('streaks_seq') NOT NULL,
  games_set_i   bigint REFERENCES games_set,
  logfiles_i    int REFERENCES logfiles,
  name          varchar(48) NOT NULL,
  open          boolean,
  num_games     int,
  PRIMARY KEY (streaks_i)
);

GRANT SELECT, INSERT, DELETE, UPDATE ON streaks TO nhdbfeeder;
GRANT SELECT ON streaks TO nhdbstats;
