----------------------------------------------------------------------------
--- tables 
----------------------------------------------------------------------------

DROP TABLE IF EXISTS translations;

CREATE TABLE translations (
  server    varchar(3) NOT NULL,
  name_from varchar(48) NOT NULL,
  name_to   varchar(48) NOT NULL
);

CREATE UNIQUE INDEX ON translations ( server, name_from );

GRANT SELECT, INSERT, UPDATE, DELETE ON translations TO nhdbfeeder;
GRANT SELECT ON translations TO nhdbstats;

INSERT INTO translations VALUES ( 'dev', 'mandevil', 'Mandevil');
INSERT INTO translations VALUES ( 'nao', 'stennop', 'stenno');
INSERT INTO translations VALUES ( 'nao', 'tufoop', 'stenno');
INSERT INTO translations VALUES ( 'nao', 'mrsoak', 'stenno');
INSERT INTO translations VALUES ( 'nao', 'stenno360', 'stenno');
INSERT INTO translations VALUES ( 'nao', '23', 'stenno');
INSERT INTO translations VALUES ( 'nao', 'PogChamp', 'stenno');
INSERT INTO translations VALUES ( 'dev', 'yeti', 'Yeti218');
INSERT INTO translations VALUES ( 'dev', 'tariru', 'Tariru' );
INSERT INTO translations VALUES ( 'dev', 'Offi', 'Corwinoid' );
INSERT INTO translations VALUES ( 'dev', 'Alaithia', 'Corwinoid' );
INSERT INTO translations VALUES ( 'dev', 'wooble', 'Wooble' );
INSERT INTO translations VALUES ( 'n4o', 'wooble', 'Wooble' );
INSERT INTO translations VALUES ( 'dev', 'elenmirie2', 'elenmirie' );
INSERT INTO translations VALUES ( 'asc', 'elenmirie1', 'elenmirie' );
INSERT INTO translations VALUES ( 'dev', 'tangles', 'Tangles' );
INSERT INTO translations VALUES ( 'dev', 'raisse', 'Raisse' );
INSERT INTO translations VALUES ( 'nao', 'Umeko', 'Raisse' );
INSERT INTO translations VALUES ( 'nao', 'Hildegard', 'Raisse' );
INSERT INTO translations VALUES ( 'nao', 'MissLucy', 'Raisse' );
INSERT INTO translations VALUES ( 'dev', 'blankman', '27B6' );
INSERT INTO translations VALUES ( 'hdf', 'Hanako', 'Raisse' );
INSERT INTO translations VALUES ( 'dev', 'lrr', 'nyarlatoteph' );
INSERT INTO translations VALUES ( 'nao', 'Hothraxxa', 'hothraxxa');
INSERT INTO translations VALUES ( 'dev', 'grasshopper', 'Grasshopper' );
INSERT INTO translations VALUES ( 'dev', 'fiq', 'FIQ' );
INSERT INTO translations VALUES ( 'dev', 'berry', 'Berry' );
INSERT INTO translations VALUES ( 'dev', 'ykstort', 'aoei' );
INSERT INTO translations VALUES ( 'nao', 'Ykstort', 'aoei' );
INSERT INTO translations VALUES ( 'nao', 'ykdrunk', 'aoei' );
INSERT INTO translations VALUES ( 'nao', 'ykscum', 'aoei' );
INSERT INTO translations VALUES ( 'nao', 'ykvalk', 'aoei' );
INSERT INTO translations VALUES ( 'nao', 'YkWiz', 'aoei' );
INSERT INTO translations VALUES ( 'nao', 'YkRNG', 'aoei' );
INSERT INTO translations VALUES ( 'ade', 'Ykstort', 'aoei' );
INSERT INTO translations VALUES ( 'aeu', 'Ykstort', 'aoei' );
INSERT INTO translations VALUES ( 'shc', 'Ykstort', 'aoei' );
