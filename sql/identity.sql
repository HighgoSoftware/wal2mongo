\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');

-- Replica identity nothing
CREATE TABLE testing (a varchar(30) primary key, b INT, c INT);
ALTER TABLE testing REPLICA IDENTITY NOTHING;
BEGIN;
INSERT INTO testing VALUES('aaa', 123, 456);
UPDATE testing set b = 789 where a = 'aaa';
UPDATE testing set a = 'bbb';
DELETE from testing where a = 'bbb';
COMMIT;

-- Replica identity default
BEGIN;
ALTER TABLE testing REPLICA IDENTITY DEFAULT;
INSERT INTO testing VALUES('aaa', 123, 456);
UPDATE testing set b = 789 where a = 'aaa';
UPDATE testing set a = 'bbb';
DELETE from testing where a = 'bbb';
COMMIT;

-- Replica identity full
BEGIN;
ALTER TABLE testing REPLICA IDENTITY FULL;
INSERT INTO testing VALUES('aaa', 123, 456);
UPDATE testing set b = 789 where a = 'aaa';
UPDATE testing set a = 'bbb';
DELETE from testing where a = 'bbb';
COMMIT;

-- Replica identity index
CREATE INDEX idx_test ON testing(b);
ALTER TABLE testing REPLICA IDENTITY INDEX;
INSERT INTO testing VALUES('aaa', 123, 456);
UPDATE testing set b = 789 where a = 'aaa';
UPDATE testing set a = 'bbb';
DELETE from testing where a = 'bbb';
COMMIT;

-- get changes
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'regress', 'true', 'skip_empty_xacts', 'true');

DROP TABLE testing;
SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
