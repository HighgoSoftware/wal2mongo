\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');

-- timestamptz
CREATE TABLE tbl_tstz ( id serial PRIMARY KEY, tstz TIMESTAMPTZ NOT NULL );
INSERT INTO tbl_tstz (tstz) VALUES('2020-03-24 16:00:30-07') ;
UPDATE tbl_tstz SET tstz = '2020-03-24 16:30:00-07' WHERE id=1;
DELETE FROM tbl_tstz WHERE id = 1;
TRUNCATE TABLE tbl_tstz;

-- peek changes according to action configuration
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- get changes according to action configuration
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'regress', 'true');


-- drop tables
DROP TABLE tbl_tstz;
SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
