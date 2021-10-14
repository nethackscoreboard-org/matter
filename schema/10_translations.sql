----------------------------------------------------------------------------
--- tables 
----------------------------------------------------------------------------

DROP TABLE IF EXISTS translations;

CREATE TABLE translations (
  server    varchar(8) NOT NULL,
  name_from varchar(48) NOT NULL,
  name_to   varchar(48) NOT NULL
);

CREATE UNIQUE INDEX ON translations ( server, name_from );

GRANT SELECT, INSERT, UPDATE, DELETE ON translations TO nhdbfeeder;
GRANT SELECT ON translations TO nhdbstats;

INSERT INTO translations VALUES ('dev', 'blankman', '27B6');
INSERT INTO translations VALUES ('dev', 'berry', 'Berry');
INSERT INTO translations VALUES ('neu', 'Alice', 'Adeon');
INSERT INTO translations VALUES ('dev', 'adeon', 'Adeon');
INSERT INTO translations VALUES ('neu', 'alice', 'Adeon');
INSERT INTO translations VALUES ('neu', 'Sayo', 'Adeon');
INSERT INTO translations VALUES ('nao', 'SpeedyCat', 'BilldaCat');
INSERT INTO translations VALUES ('nao', 'SpeedyCat1', 'BilldaCat');
INSERT INTO translations VALUES ('nao', 'SpeedyCat2', 'BilldaCat');
INSERT INTO translations VALUES ('nao', 'SpeedyCat3', 'BilldaCat');
INSERT INTO translations VALUES ('nao', 'SpeedyCat4', 'BilldaCat');
INSERT INTO translations VALUES ('nao', 'SpeedyCat5', 'BilldaCat');
INSERT INTO translations VALUES ('nao', 'SpeedyCat6', 'BilldaCat');
INSERT INTO translations VALUES ('nao', 'SpeedyCat7', 'BilldaCat');
INSERT INTO translations VALUES ('nao', 'SpeedyCat8', 'BilldaCat');
INSERT INTO translations VALUES ('nao', 'SpeedyCat9', 'BilldaCat');
INSERT INTO translations VALUES ('asc', 'BH905cac4', 'BotHack');
INSERT INTO translations VALUES ('asc', 'BHec6b274', 'BotHack');
INSERT INTO translations VALUES ('asc', 'BH22c4e70', 'BotHack');
INSERT INTO translations VALUES ('asc', 'BHb73e0a1', 'BotHack');
INSERT INTO translations VALUES ('dev', 'Offi', 'Corwinoid');
INSERT INTO translations VALUES ('dev', 'Alaithia', 'Corwinoid');
INSERT INTO translations VALUES ('dev', 'eidolos2', 'Eidolos');
INSERT INTO translations VALUES ('dev', 'fiq', 'FIQ');
INSERT INTO translations VALUES ('dev', 'grasshopper', 'Grasshopper');
INSERT INTO translations VALUES ('nao', 'gdq', 'Luxidream');
INSERT INTO translations VALUES ('nao', 'luxidream2', 'Luxidream');
INSERT INTO translations VALUES ('nao', 'ValkGDQ', 'Luxidream');
INSERT INTO translations VALUES ('hdf', 'dalles', 'Luxidream');
INSERT INTO translations VALUES ('dev', 'mandevil', 'Mandevil');
INSERT INTO translations VALUES ('dev', 'maud', 'Maud');
INSERT INTO translations VALUES ('dev', 'raisse', 'Raisse');
INSERT INTO translations VALUES ('nao', 'Umeko', 'Raisse');
INSERT INTO translations VALUES ('nao', 'Hildegard', 'Raisse');
INSERT INTO translations VALUES ('nao', 'MissLucy', 'Raisse');
INSERT INTO translations VALUES ('hdf', 'Hanako', 'Raisse');
INSERT INTO translations VALUES ('dev', 'tangles', 'Tangles');
INSERT INTO translations VALUES ('dev', 'tariru', 'Tariru');
INSERT INTO translations VALUES ('dev', 'wooble', 'Wooble');
INSERT INTO translations VALUES ('n4o', 'wooble', 'Wooble');
INSERT INTO translations VALUES ('dev', 'yeti', 'Yeti218');
INSERT INTO translations VALUES ('dev', 'ykstort', 'aoei');
INSERT INTO translations VALUES ('nao', 'Ykstort', 'aoei');
INSERT INTO translations VALUES ('nao', 'ykdrunk', 'aoei');
INSERT INTO translations VALUES ('nao', 'ykscum', 'aoei');
INSERT INTO translations VALUES ('nao', 'ykvalk', 'aoei');
INSERT INTO translations VALUES ('nao', 'YkWiz', 'aoei');
INSERT INTO translations VALUES ('nao', 'YkRNG', 'aoei');
INSERT INTO translations VALUES ('ade', 'Ykstort', 'aoei');
INSERT INTO translations VALUES ('aeu', 'Ykstort', 'aoei');
INSERT INTO translations VALUES ('shc', 'Ykstort', 'aoei');
INSERT INTO translations VALUES ('shc', 'Ykstort', 'aoei');
INSERT INTO translations VALUES ('hdf', 'aosdictj', 'aosdict');
INSERT INTO translations VALUES ('dev', 'elenmirie2', 'elenmirie');
INSERT INTO translations VALUES ('asc', 'elenmirie1', 'elenmirie');
INSERT INTO translations VALUES ('nao', 'Hothraxxa', 'hothraxxa');
INSERT INTO translations VALUES ('dev', 'lrr', 'nyarlatoteph');
INSERT INTO translations VALUES ('hdf', 'flump', 'spicycat');
INSERT INTO translations VALUES ('hdf', 'flumpraxxadabIQ2', 'spicycat');
INSERT INTO translations VALUES ('nao', 'hoover', 'spleen');
INSERT INTO translations VALUES ('nao', 'stennop', 'stenno');
INSERT INTO translations VALUES ('nao', 'tufoop', 'stenno');
INSERT INTO translations VALUES ('nao', 'mrsoak', 'stenno');
INSERT INTO translations VALUES ('nao', 'stenno360', 'stenno');
INSERT INTO translations VALUES ('nao', '23', 'stenno');
INSERT INTO translations VALUES ('nao', 'PogChamp', 'stenno');
INSERT INTO translations VALUES ('asc', 'PogChamp', 'stenno');
INSERT INTO translations VALUES ('hdf', 'rikersan', 'rikerw');
INSERT INTO translations VALUES ('hdf', 'lynnwashere', 'rikerw');
INSERT INTO translations VALUES ('hdf', 'imsofuckingfast', 'rikerw');
INSERT INTO translations VALUES ('hdf', 'Demo2', 'Demo');
INSERT INTO translations VALUES ('hdf', 'Demo3', 'Demo');
INSERT INTO translations VALUES ('hdf', 'Demo4', 'Demo');
INSERT INTO translations VALUES ('hdf', 'Demo5', 'Demo');
INSERT INTO translations VALUES ('hdf', 'Demo6', 'Demo');

INSERT INTO translations VALUES ('nao', 'tjr1', 'tjr');
INSERT INTO translations VALUES ('nao', 'tjr2', 'tjr');
INSERT INTO translations VALUES ('nao', 'tjr3', 'tjr');
INSERT INTO translations VALUES ('nao', 'tjr4', 'tjr');
INSERT INTO translations VALUES ('nao', 'tjr5', 'tjr');
INSERT INTO translations VALUES ('nao', 'tjr6', 'tjr');
INSERT INTO translations VALUES ('nao', 'tjr7', 'tjr');
INSERT INTO translations VALUES ('nao', 'tjr8', 'tjr');
INSERT INTO translations VALUES ('nao', 'tjr9', 'tjr');
