\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');

CREATE TABLE testing (
	a serial PRIMARY KEY,
	b varchar(80),
	c bool,
	d real
);

BEGIN;
INSERT INTO testing (b, c, d) VALUES( E'valid: '' " \\ / \d \f \r \t \u447F \u967F invalid: \\g \\k end', FALSE, 123.456);
INSERT INTO testing (b, c, d) VALUES('aaa', 't', '+inf');
INSERT INTO testing (b, c, d) VALUES('aaa', 'f', 'nan');
INSERT INTO testing (b, c, d) VALUES('null', NULL, '-inf');
COMMIT;

-- get changes
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'regress', 'true', 'skip_empty_xacts', 'true');

DROP TABLE testing;

SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
