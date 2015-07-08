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
