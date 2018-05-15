----------------------------------------------------------------------------
--- sequences
----------------------------------------------------------------------------

DROP SEQUENCE IF EXISTS games_seq;

CREATE SEQUENCE games_seq;


----------------------------------------------------------------------------
--- tables 
----------------------------------------------------------------------------

DROP TABLE IF EXISTS games;

CREATE TABLE games (
  rowid         bigint DEFAULT nextval('games_seq') NOT NULL,
  logfiles_i    int REFERENCES logfiles,
  name          varchar(48) NOT NULL,
  name_orig     varchar(48) NOT NULL,
  role          char(3) NOT NULL,
  race          char(3) NOT NULL,
  gender        char(3) NOT NULL,
  gender0       char(3),
  align         char(3) NOT NULL,
  align0        char(3),
  starttime     timestamp with time zone NOT NULL,
  starttime_raw bigint,
  endtime       timestamp with time zone NOT NULL,
  endtime_raw   bigint,
  death         varchar(128),
  deathdnum     int,
  deathlev      int NOT NULL,
  deaths        int NOT NULL,
  hp            int NOT NULL,
  maxhp         int NOT NULL,
  maxlvl        int NOT NULL,
  points        bigint NOT NULL,
  conduct       integer NOT NULL,
  elbereths     integer,
  turns         bigint NOT NULL,
  achieve       integer,
  realtime      bigint,
  version       varchar(16) NOT NULL,
  ascended      boolean NOT NULL,
  quit          boolean NOT NULL,
  scummed       boolean NOT NULL,
  dumplog       varchar(128),
  PRIMARY KEY ( rowid )
);

CREATE INDEX idx_games_endtime ON games ( (endtime AT TIME ZONE 'UTC') DESC );
CREATE INDEX idx_games_name1 ON games ( name );
CREATE INDEX idx_games_name2 ON games ( name_orig );
GRANT SELECT, INSERT, UPDATE, DELETE ON games TO nhdbfeeder;
GRANT SELECT ON games TO nhdbstats;
GRANT USAGE ON games_seq TO nhdbfeeder;


----------------------------------------------------------------------------
--- views
----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_games_recent AS
  SELECT 
    rowid, logfiles_i, name, name_orig, server, variant, role, race,
    gender, gender0, align, align0, endtime,
    to_char(endtime AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') AS endtime_fmt,
    to_char(endtime AT TIME ZONE 'UTC', 'DD Mon') AS short_date,
    endtime_raw, starttime_raw, death, dumplog, deathlev,
    hp, maxhp, maxlvl, points, conduct, elbereths, achieve, turns, realtime,
    games.version, ascended
  FROM 
    games
    LEFT JOIN logfiles USING ( logfiles_i )
  WHERE scummed = FALSE
  ORDER BY endtime AT TIME ZONE 'UTC' DESC;

GRANT SELECT ON v_games_recent TO nhdbstats;


CREATE OR REPLACE VIEW v_games AS
  SELECT 
    rowid, logfiles_i, name, name_orig, server, variant, role, race,
    gender, gender0, align, align0, endtime,
    to_char(endtime AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') AS endtime_fmt,
    endtime_raw, starttime_raw, death, dumplog, deathlev,
    hp, maxhp, maxlvl, points, conduct, elbereths, achieve, turns, realtime,
    games.version, ascended
  FROM 
    games
    LEFT JOIN logfiles USING ( logfiles_i )
  WHERE scummed = FALSE
  ORDER BY endtime AT TIME ZONE 'UTC' ASC;

GRANT SELECT ON v_games TO nhdbstats;


CREATE OR REPLACE VIEW v_games_all AS
  SELECT 
    rowid, logfiles_i, name, name_orig, server, variant, role, race,
    gender, gender0, align, align0, endtime,
    to_char(endtime AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') AS endtime_fmt,
    endtime_raw, starttime_raw, death, dumplog, deathlev,
    hp, maxhp, maxlvl, points, conduct, elbereths, achieve, turns, realtime,
    games.version, ascended, scummed
  FROM 
    games
    LEFT JOIN logfiles USING ( logfiles_i )
  ORDER BY endtime AT TIME ZONE 'UTC' ASC;

GRANT SELECT ON v_games_all TO nhdbstats;


CREATE OR REPLACE VIEW v_ascended_recent AS
  SELECT
    rowid, logfiles_i, name, name_orig, server, variant, role, race,
    gender, gender0, align, align0, endtime,
    to_char(endtime AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') AS endtime_fmt,
    to_char(endtime AT TIME ZONE 'UTC', 'DD Mon') AS short_date,
    endtime_raw, starttime_raw, death, deathlev,
    hp, maxhp, maxlvl, points, conduct, elbereths, achieve, turns, realtime,
    games.version, ascended, dumplog,
    extract('year'  from age(
      current_timestamp AT TIME ZONE 'UTC', 
      endtime AT TIME ZONE 'UTC')
    ) AS age_years,
    extract('month' from age(
      current_timestamp AT TIME ZONE 'UTC',
      endtime AT TIME ZONE 'UTC')
    ) AS age_months,
    extract('day'   from age(
      current_timestamp AT TIME ZONE 'UTC',
      endtime AT TIME ZONE 'UTC')
    ) AS age_days,
    extract('hour'  from age(
      current_timestamp AT TIME ZONE 'UTC',
      endtime AT TIME ZONE 'UTC')
    ) AS age_hours,
    round(extract('epoch' from age(
      current_timestamp AT TIME ZONE 'UTC', 
      endtime AT TIME ZONE 'UTC')
    )) AS age_raw
  FROM
    games
    LEFT JOIN logfiles USING ( logfiles_i )
  WHERE ascended = TRUE
  ORDER BY endtime AT TIME ZONE 'UTC' DESC;

GRANT SELECT ON v_ascended_recent TO nhdbstats;


CREATE OR REPLACE VIEW v_ascended AS
  SELECT
    rowid, logfiles_i, name, name_orig, server, variant, role, race,
    gender, gender0, align, align0, endtime,
    to_char(endtime AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') AS endtime_fmt,
    endtime_raw, starttime_raw, death, dumplog,
    deathlev, hp, maxhp, maxlvl, points, conduct, achieve, turns, realtime,
    games.version, ascended
  FROM
    games
    LEFT JOIN logfiles USING ( logfiles_i )
  WHERE ascended = TRUE
  ORDER BY endtime AT TIME ZONE 'UTC' ASC;

GRANT SELECT ON v_ascended TO nhdbstats;


----------------------------------------------------------------------------
--- functions
----------------------------------------------------------------------------

-- Function that counts bit in an integer. Used to get number of conducts
-- as these are represented by bitfield.

CREATE OR REPLACE FUNCTION bitcount(i integer) RETURNS integer AS $$
DECLARE n integer;
DECLARE amount integer;
  BEGIN
    amount := 0;
    FOR n IN 1..16 LOOP
      amount := amount + ((i >> (n-1)) & 1);
    END LOOP;
    RETURN amount;
  END
$$ LANGUAGE plpgsql;

-- This function returns list of combos with info about player who
-- was the first to achieve a win for given combo. This function
-- is a wrapper for a query that can't be made into a view (because
-- we need to be able to supply a parameter to it)
--
-- IMPORTANT: The single-query solution given below is flawed;
-- it is possible that the wrong game is returned that has
-- the same (endtime, role, race, align0) as the correct one.

CREATE OR REPLACE FUNCTION first_to_ascend(_variant varchar)
RETURNS TABLE (
  r_server         varchar(3),
  r_variant        varchar(3),
  r_version        varchar(16),
  r_name           varchar(48),
  r_role           char(3),
  r_race           char(3),
  r_align          char(3),
  r_gender         char(3),
  r_starttime      timestamp with time zone,
  r_starttime_fmt  text,
  r_starttime_raw  bigint,
  r_endtime        timestamp with time zone,
  r_endtime_fmt    text,
  r_endtime_raw    bigint,
  r_deathlev       int,
  r_hp             int,
  r_maxhp          int,
  r_maxlvl         int,
  r_points         bigint,
  r_conduct        int,
  r_turns          bigint,
  r_logfiles_i     int,
  r_dumplog        varchar(128),
  r_ascended       boolean,
  r_realtime       bigint,
  r_elbereths      int,
  r_achieve        int
) AS $$

SELECT
  server, variant, g.version, g.name, g.role, g.race, g.align0, g.gender0,
  starttime,
  to_char(g.starttime AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') AS starttime_fmt,
  starttime_raw, endtime,
  to_char(g.endtime AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') AS endtime_fmt,
  endtime_raw,
  g.deathlev, g.hp, g.maxhp, g.maxlvl, g.points, g.conduct, g.turns,
  l.logfiles_i, g.dumplog, g.ascended, g.realtime, g.elbereths, g.achieve
FROM (
  SELECT
    min(h.endtime) AS endtime, h.role, h.race, h.align0
  FROM
    games h
    JOIN logfiles USING (logfiles_i)
  WHERE variant = _variant AND ascended IS TRUE
  GROUP BY role, race, align0
) i
INNER JOIN games g USING ( endtime, role, race, align0 )
JOIN logfiles l USING ( logfiles_i )
ORDER BY g.endtime ASC;

$$ LANGUAGE sql;
