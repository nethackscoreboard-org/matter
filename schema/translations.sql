----------------------------------------------------------------------------
--- tables 
----------------------------------------------------------------------------

CREATE TABLE translations (
  server    varchar(3) NOT NULL,
  name_from varchar(48) NOT NULL,
  name_to   varchar(48) NOT NULL
);

GRANT SELECT ON translations TO nhdbfeeder;
GRANT SELECT ON translations TO nhdbstats;

INSERT INTO translations VALUES ( 'dev', 'mandevil', 'Mandevil');
INSERT INTO translations VALUES ( 'nao', 'stennop', 'stenno');
INSERT INTO translations VALUES ( 'nao', 'tufoop', 'stenno');
INSERT INTO translations VALUES ( 'nao', 'mrsoak', 'stenno');
INSERT INTO translations VALUES ( 'nao', '23', 'stenno');
INSERT INTO translations VALUES ( 'dev', 'yeti', 'Yeti218');
INSERT INTO translations VALUES ( 'dev', 'tariru', 'Tariru' );
