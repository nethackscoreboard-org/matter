-- update table
-- this table tracks objects that need to be updated to optimize
-- stats generation (ie. not generating stats on objects that were
-- not modified); updateable objects are:
--
-- (ALL    , NULL) -- combined stats need to be updated
-- (variant, NULL) -- variant stats need to be update
-- (ALL    , name) -- all variants for player stats need to be updated
-- (variant, name) -- player/variant stats need to be updated
--
-- Therefore, receiving new entries on variant 'unn' should generate
-- (ALL, NULL) + ('unn', NULL) update rows and two per each player
-- name encountered in the log	

CREATE TABLE update (
  variant char(3),
  name varchar(48)
);

CREATE UNIQUE INDEX idx_update ON (variant, name);
