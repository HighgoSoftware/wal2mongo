\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');

-- UUID
CREATE TABLE tbl_uuid ( id serial PRIMARY KEY, a_uuid UUID NOT NULL );
INSERT INTO tbl_uuid (a_uuid) VALUES('47deacb1-3ad0-4a0e-8254-9ad3f589c9f3') ;
UPDATE tbl_uuid SET a_uuid = 'e7d8e462-12cc-49dc-aac2-2b5dccdabeda' WHERE id=1;
DELETE FROM tbl_uuid WHERE id = 1;
TRUNCATE TABLE tbl_uuid;

-- BYTEA
CREATE TABLE tbl_bytea ( id serial PRIMARY KEY, a_bytea bytea NOT NULL );
ALTER TABLE tbl_bytea REPLICA IDENTITY FULL;
INSERT INTO tbl_bytea(a_bytea) SELECT 'abc \153\154\155 \052\251\124'::bytea RETURNING a_bytea;
UPDATE tbl_bytea SET a_bytea = SELECT '\134'::bytea RETURNING a_bytea;
DELETE FROM tbl_bytea WHERE id = 1;
TRUNCATE TABLE tbl_bytea;

-- peek changes according to action configuration
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- get changes according to action configuration
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'regress', 'true');


-- drop tables
DROP TABLE tbl_uuid;
DROP TABLE tbl_bytea;
SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
