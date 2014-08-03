-- update table
-- """"""""""""
-- This table has dual purpose:
--
-- The first purpose is to track "objects" that need to be updated
-- to optimize stats generation; the feeder component sets the
-- update flag on when it inserts rows into games table; the
-- stats generator then uses the info to update relevant pages
-- and after doing so it clears the flags.
--
-- The second use is to track (name, variant) pairs' existence; this
-- optimizes individual player pages generation, since generating
-- all variants for all pages greatly increases the number of pages
-- generated, most of them being empty, since most players only play
-- one variant.
--
-- There are two classes of objects being tracked: variants (which
-- includes pseudovariant 'all') and names.
--
-- ('all'  , '')   -- combined stats need to be updated
-- (variant, '')   -- variant stats need to be update
-- ('all'  , name) -- all variants for player stats need to be updated
-- (variant, name) -- player/variant stats need to be updated
--
-- When nhdb-feeder detects, that this table has no rows in it, it will
-- initialize it with following two queries:
--
--    INSERT INTO update 
--    SELECT variant, name
--    FROM games LEFT JOIN logfiles USING (logfiles_i)
--    GROUP BY variant, name;
--    
--    INSERT INTO update 
--    SELECT 'all', name, FALSE
--    FROM games LEFT JOIN logfiles USING (logfiles_i)
--    GROUP BY name;
--
-- This initialization is critical for proper function of nhdb-stats!
-- Note, that currently this query takes over 100 seconds to complete.
--
-- This table only grows, no deletes are performed anywhere in the
-- nhdb. The only deletion necessary is when log source is removed
-- (from logfiles table); if that happens, this table should be completely
-- emptied by administrator;

DROP TABLE update;

CREATE TABLE update (
  variant varchar(3),
  name    varchar(48),
  upflag  boolean DEFAULT FALSE,
  UNIQUE (variant, name)
);

GRANT SELECT, INSERT, UPDATE ON update TO nhdbfeeder;
GRANT SELECT, UPDATE ON update TO nhdbstats;
