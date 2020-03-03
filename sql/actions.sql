\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');

-- actions
CREATE TABLE testing (a integer primary key);
INSERT INTO testing (a) VALUES(200);
UPDATE actions SET a = 500 WHERE a = 200;
DELETE FROM actions WHERE a = 500;
TRUNCATE TABLE actions;

-- peek changes according to action configuration
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'actions', 'insert');
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'actions', 'update');
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'actions', 'delete');
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'actions', 'truncate');
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'actions', 'insert, update, delete, truncate');

-- peek changes with default action configuraiton
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL);

-- peek changes with invalid actions
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'actions', 'insert, xxx, delete, xxx');

SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
