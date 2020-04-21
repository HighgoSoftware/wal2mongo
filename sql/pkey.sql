\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');


CREATE TABLE testing_one_pkey (
a smallserial PRIMARY KEY,
b smallint,
c int,
d bigint,
e int,
f real,
g double precision,
h char(20),
i varchar(30),
j text
);

CREATE TABLE testing_multi_pkey (
a smallserial,
b smallint,
c int,
d bigint,
e int,
f real,
g double precision,
h char(20),
i varchar(30),
j text,
PRIMARY KEY(a, b, c)
);

CREATE TABLE testing_no_pkey (
a smallserial,
b smallint,
c int,
d bigint,
e int,
f real,
g double precision,
h char(20),
i varchar(30),
j text
);

CREATE TABLE testing_unique (
a smallserial,
b smallint,
c int,
d bigint,
e int,
f real,
g double precision,
h char(20),
i varchar(30),
j text,
UNIQUE(f, g)
);

INSERT INTO testing_one_pkey (b, c, d, e, f, g, h, i, j) VALUES (1, 2, 33, 555, 666.777777777, 3.33, 'testval1', 'testval2', 'testval3');
INSERT INTO testing_multi_pkey (b, c, d, e, f, g, h, i, j) VALUES (1, 2, 33, 555, 666.777777777, 3.33, 'testval1', 'testval2', 'testval3');
INSERT INTO testing_no_pkey (b, c, d, e, f, g, h, i, j) VALUES (1, 2, 33, 555, 666.777777777, 3.33, 'testval1', 'testval2', 'testval3');
INSERT INTO testing_unique (b, c, d, e, f, g, h, i, j) VALUES (1, 2, 33, 555, 666.777777777, 3.33, 'testval1', 'testval2', 'testval3');

-- non pkey change
UPDATE testing_one_pkey SET f = 777.888888888 WHERE b = 1;

-- pkey change
UPDATE testing_one_pkey SET a = 14 WHERE b = 1;  

-- non pkey change
UPDATE testing_multi_pkey SET f = 777.888888888 WHERE b = 1;

-- some pkeys change
UPDATE testing_multi_pkey SET a = 14, c = 14 WHERE b = 1; 

-- all pkeys change
UPDATE testing_multi_pkey SET a = 15, b = 15, c = 15 WHERE b = 1; 

-- no pkey
UPDATE testing_no_pkey SET h = 'changed' WHERE b = 1;

-- non unique change
UPDATE testing_unique SET h = 'changed' WHERE b = 1;

-- one unique val change
UPDATE testing_unique SET f = 888.888888888 WHERE b = 1;

-- all unique vals change
UPDATE testing_unique SET f = 888.888888888, g = 6.66 WHERE b = 1;

-- get changes
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'regress', 'true', 'skip_empty_xacts', 'true');

DROP TABLE testing_unique;
DROP TABLE testing_no_pkey;
DROP TABLE testing_multi_pkey;
DROP TABLE testing_one_pkey;

SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
