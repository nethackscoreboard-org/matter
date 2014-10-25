----------------------------------------------------------------------------
--- sequences
----------------------------------------------------------------------------

CREATE SEQUENCE games_seq;


----------------------------------------------------------------------------
--- tables 
----------------------------------------------------------------------------

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
  conduct       bit(16) NOT NULL,
  turns         bigint NOT NULL,
  achieve       bit(16),
  realtime      bigint,
  version       varchar(16) NOT NULL,
  ascended      boolean NOT NULL,
  quit          boolean NOT NULL,
  scummed       boolean NOT NULL,
  PRIMARY KEY ( rowid )
);

CREATE INDEX idx_games_endtime ON games ( (endtime AT TIME ZONE 'UTC') DESC );
CREATE INDEX idx_games_name1 ON games ( name );
CREATE INDEX idx_games_name2 ON games ( name_orig );
GRANT SELECT, INSERT ON games TO nhdbfeeder;
GRANT SELECT ON games TO nhdbstats;
GRANT USAGE ON games_seq TO nhdbfeeder;


----------------------------------------------------------------------------
--- views
----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_games_recent AS
  SELECT 
    rowid, logfiles_i, name, name_orig, server, variant, role, race, gender, align,
    to_char(endtime AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') AS endtime,
    endtime_raw, starttime_raw, death,
    deathlev, hp, maxhp, maxlvl, points, conduct::int, turns, realtime, 
    games.version, ascended
  FROM 
    games
    LEFT JOIN logfiles USING ( logfiles_i )
  WHERE scummed = FALSE
  ORDER BY endtime AT TIME ZONE 'UTC' DESC;

GRANT SELECT ON v_games_recent TO nhdbstats;


CREATE OR REPLACE VIEW v_games AS
  SELECT 
    rowid, logfiles_i, name, name_orig, server, variant, role, race, gender, align,
    to_char(endtime AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') AS endtime,
    endtime_raw, starttime_raw, death,
    deathlev, hp, maxhp, maxlvl, points, conduct::int, turns, realtime, 
    games.version, ascended
  FROM 
    games
    LEFT JOIN logfiles USING ( logfiles_i )
  WHERE scummed = FALSE
  ORDER BY endtime AT TIME ZONE 'UTC' ASC;

GRANT SELECT ON v_games TO nhdbstats;


CREATE OR REPLACE VIEW v_games_all AS
  SELECT 
    rowid, logfiles_i, name, name_orig, server, variant, role, race, gender, align,
    to_char(endtime AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') AS endtime,
    endtime_raw, starttime_raw, death,
    deathlev, hp, maxhp, maxlvl, points, conduct::int, turns, realtime, 
    games.version, ascended
  FROM 
    games
    LEFT JOIN logfiles USING ( logfiles_i )
  ORDER BY endtime AT TIME ZONE 'UTC' ASC;

GRANT SELECT ON v_games TO nhdbstats;


CREATE OR REPLACE VIEW v_ascended_recent AS
  SELECT
    rowid, logfiles_i, name, name_orig, server, variant, role, race, gender, align,
    to_char(endtime AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') AS endtime,
    endtime_raw, starttime_raw, death,
    deathlev, hp, maxhp, maxlvl, points, conduct::int, turns, realtime,
    games.version, ascended,
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
    rowid, logfiles_i, name, name_orig, server, variant, role, race, gender, align,
    endtime AT TIME ZONE 'UTC' AS endtime, endtime_raw, starttime_raw, death,
    deathlev, hp, maxhp, maxlvl, points, conduct::int, turns, realtime,
    games.version, ascended
  FROM
    games
    LEFT JOIN logfiles USING ( logfiles_i )
  WHERE ascended = TRUE
  ORDER BY endtime AT TIME ZONE 'UTC' ASC;

GRANT SELECT ON v_ascended TO nhdbstats;
