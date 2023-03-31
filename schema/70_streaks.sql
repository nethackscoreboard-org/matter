----------------------------------------------------------------------------
--- clean-up
----------------------------------------------------------------------------

DROP TABLE IF EXISTS streaks;
DROP TABLE IF EXISTS map_games_streaks;
DROP SEQUENCE IF EXISTS streaks_seq;

----------------------------------------------------------------------------
--- sequences
----------------------------------------------------------------------------

CREATE SEQUENCE streaks_seq;
GRANT USAGE ON streaks_seq TO nhdbfeeder;


----------------------------------------------------------------------------
--- triggers
----------------------------------------------------------------------------

-- Following trigger function is bound to INSERT/DELETE on map_games_streaks
-- table that maps rows between "games" and "streaks" (N:1). It does two
-- things: 1) automatically increments/decrements streaks.num_games when
-- mapping is added/removed to/from map_games_streaks. 2) If
-- streaks.num_games reaches 0 on deleting; the streak itself is removed.
-- The latter functionality is here to make deleting games straightforward
-- but note that full consistency is still not guaranteed; if you delete
-- games from "games" table, you must delete all games with the same
-- logfiles_i to ensure integrity.

CREATE OR REPLACE FUNCTION trig_streak_adjust() RETURNS trigger AS $$

DECLARE
  _num_games int;

BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE streaks SET num_games = num_games + 1 WHERE streaks_i = NEW.streaks_i;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE streaks SET num_games = num_games - 1 WHERE streaks_i = OLD.streaks_i 
      RETURNING num_games INTO _num_games;
    IF _num_games = 0 THEN
      DELETE FROM streaks WHERE streaks_i = OLD.streaks_i;
    END IF;
    RETURN OLD; 
  END IF;
END;
$$ LANGUAGE plpgsql;

-- streaks after-update trigger; if open is FALSE and num_games is 1, the
-- streak is deleted (closed streaks with length 1 are no streaks)

CREATE OR REPLACE FUNCTION trig_streak_destroy() RETURNS trigger AS $$

BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW."open" IS FALSE AND NEW.num_games = 1 THEN
      DELETE FROM streaks WHERE streaks_i = NEW.streaks_i;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


----------------------------------------------------------------------------
--- tables
----------------------------------------------------------------------------

CREATE TABLE streaks (
  streaks_i     bigint DEFAULT nextval('streaks_seq') NOT NULL,
  logfiles_i    int REFERENCES logfiles ON DELETE RESTRICT,
  name          varchar(48) NOT NULL,
  name_orig     varchar(48) NOT NULL,
  open          boolean DEFAULT TRUE,
  num_games     int DEFAULT 0,
  PRIMARY KEY (streaks_i)
);

GRANT SELECT, INSERT, DELETE, UPDATE ON streaks TO nhdbfeeder;
GRANT SELECT ON streaks TO nhdbstats;

CREATE TRIGGER trig_streak_destroy
  AFTER UPDATE ON streaks
  FOR EACH ROW EXECUTE PROCEDURE trig_streak_destroy();


CREATE TABLE map_games_streaks (
  rowid         bigint REFERENCES games ON DELETE CASCADE,
  streaks_i     bigint REFERENCES streaks ON DELETE CASCADE,
  PRIMARY KEY (rowid, streaks_i)
);

GRANT SELECT, INSERT, DELETE ON map_games_streaks TO nhdbfeeder;
GRANT SELECT ON map_games_streaks TO nhdbstats;

CREATE TRIGGER trig_streak_adjust 
  AFTER INSERT OR DELETE ON map_games_streaks 
  FOR EACH ROW EXECUTE PROCEDURE trig_streak_adjust();

DROP TABLE IF EXISTS deathreason;

CREATE TABLE deathreason (
  name       character varying(53) NOT NULL,
  year       character (4) NOT NULL,
  variant      character varying(16) NOT NULL,
  death       character varying(128) NOT NULL,
  cnt		integer NOT NULL,
  PRIMARY KEY ( name, year, variant, death )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON deathreason TO nhdbfeeder;
GRANT SELECT ON deathreason TO nhdbstats;
CREATE INDEX deathreason_cnt on deathreason (cnt);

DROP TABLE IF EXISTS frillstats;

CREATE TABLE frillstats (
  name       character varying(53) NOT NULL,
  year       character (4) NOT NULL,
  variant      character varying(16) NOT NULL,
  role      character (3) NOT NULL,
  race      character (3) NOT NULL,
  align      character (1) NOT NULL,
  games	integer NOT NULL,
  ascended integer NOT NULL,
  points bigint NOT NULL,
  turns bigint NOT NULL,
  duration bigint NOT NULL,
  hp bigint NOT NULL,
  pointhigh bigint NOT NULL,
  pointlow bigint NOT NULL,
  turnlow bigint NOT NULL,
  durationlow bigint NOT NULL,
  hplow bigint NOT NULL,
  hphigh bigint NOT NULL,
  conductnum smallint NOT NULL,
  conducts character varying(500),
  PRIMARY KEY ( name, year, variant, role, race, align )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON frillstats TO nhdbfeeder;
GRANT SELECT ON frillstats TO nhdbstats;

DROP TABLE IF EXISTS multistreak;

CREATE TABLE multistreak (
  multikey bigint DEFAULT nextval('games_seq') NOT NULL,
  name       character varying(53) NOT NULL,
  name_orig character varying(53) NOT NULL,
  starttime       timestamp with time zone NOT NULL,
  endtime       timestamp with time zone NOT NULL,
  open boolean NOT NULL default FALSE, 
  primary key (multikey));

CREATE INDEX multistreak_name_orig on multistreak (name_orig);

GRANT SELECT, INSERT, UPDATE, DELETE ON multistreak TO nhdbfeeder;
GRANT SELECT ON multistreak TO nhdbstats;

DROP TABLE IF EXISTS multi_row;

CREATE TABLE multi_row (
  mrowkey bigint DEFAULT nextval('games_seq') NOT NULL,
  multikey bigint NOT NULL,
  variant      character varying(16) NOT NULL,
  server      character varying(16) NOT NULL,
  rowid bigint NOT NULL,
  primary key (mrowkey));

CREATE INDEX multi_row_multikey on multi_row (multikey);

GRANT SELECT, INSERT, UPDATE, DELETE ON multi_row TO nhdbfeeder;
GRANT SELECT ON multi_row TO nhdbstats;

CREATE TABLE ascendtypes (
  name       character varying(53) NOT NULL,
  variant      character varying(16) NOT NULL,
  role      character (3) NOT NULL,
  race      character (3) NOT NULL,
  align      character (1) NOT NULL,
  gameid  bigint NOT NULL,
  PRIMARY KEY ( name, variant, role, race, align )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON ascendtypes TO nhdbfeeder;
GRANT SELECT ON ascendtypes TO nhdbstats;
CREATE INDEX ascendtypes_gameid on ascendtypes (gameid);

CREATE TABLE comboease (
  variant      character varying(16) NOT NULL,
  role      character (3) NOT NULL,
  race      character (3) NOT NULL,
  align      character (1) NOT NULL,
  attempts int not NULL,
  ascend int not NULL,
  PRIMARY KEY ( variant, role, race, align )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON comboease TO nhdbfeeder;
GRANT SELECT ON comboease TO nhdbstats;
