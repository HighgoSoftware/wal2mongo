\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');

-- actions
CREATE TABLE testing (a varchar(30) primary key);
INSERT INTO testing (a) VALUES('cary');
INSERT INTO testing (a) VALUES('john');
INSERT INTO testing (a) VALUES('peter');

-- define a transaction containing sub transactions
BEGIN;
INSERT INTO testing (a) VALUES('david');
SAVEPOINT p1;
INSERT INTO testing (a) VALUES('grant');
SAVEPOINT p2;
INSERT INTO testing (a) VALUES('mike');
SAVEPOINT p3;
INSERT INTO testing (a) VALUES('allen');
SAVEPOINT p4;
INSERT INTO testing (a) VALUES('dan');
ROLLBACK TO SAVEPOINT p3;
RELEASE SAVEPOINT p1;
INSERT INTO testing (a) VALUES('cheese');
COMMIT;


-- peek and get changes with and without transaction mode
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'use_transaction', 'true', 'regress', 'true');
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'use_transaction', 'false', 'regress', 'true', 'skip_empty_xacts', 'false');

DROP TABLE testing;
SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
