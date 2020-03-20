\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');

-- create table with boolean type
CREATE TABLE tbl_boolean (a integer primary key, b BOOLEAN);

-- true
INSERT INTO tbl_boolean (a, b) VALUES(1, true);
UPDATE tbl_boolean SET b = false WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- 'true'
INSERT INTO tbl_boolean (a, b) VALUES(1, 'true');
UPDATE tbl_boolean SET b = 'false' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- 't'
INSERT INTO tbl_boolean (a, b) VALUES(1, 't');
UPDATE tbl_boolean SET b = 'f' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- TRUE
INSERT INTO tbl_boolean (a, b) VALUES(1, TRUE);
UPDATE tbl_boolean SET b = TRUE WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- 'TRUE'
INSERT INTO tbl_boolean (a, b) VALUES(1, 'TRUE');
UPDATE tbl_boolean SET b = 'TRUE' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- 'T'
INSERT INTO tbl_boolean (a, b) VALUES(1, 'T');
UPDATE tbl_boolean SET b = 'T' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- 'on'
INSERT INTO tbl_boolean (a, b) VALUES(1, 'on');
UPDATE tbl_boolean SET b = 'off' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- '1'
INSERT INTO tbl_boolean (a, b) VALUES(1, '1');
UPDATE tbl_boolean SET b = '0' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- false
INSERT INTO tbl_boolean (a, b) VALUES(1, false);
UPDATE tbl_boolean SET b = true WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- 'false'
INSERT INTO tbl_boolean (a, b) VALUES(1, 'false');
UPDATE tbl_boolean SET b = 'true' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- 'f'
INSERT INTO tbl_boolean (a, b) VALUES(1, 'f');
UPDATE tbl_boolean SET b = 't' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- FALSE
INSERT INTO tbl_boolean (a, b) VALUES(1, FALSE);
UPDATE tbl_boolean SET b = TRUE WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- 'FALSE'
INSERT INTO tbl_boolean (a, b) VALUES(1, 'FALSE');
UPDATE tbl_boolean SET b = 'TRUE' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- 'F'
INSERT INTO tbl_boolean (a, b) VALUES(1, 'F');
UPDATE tbl_boolean SET b = 'T' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- 'off'
INSERT INTO tbl_boolean (a, b) VALUES(1, 'off');
UPDATE tbl_boolean SET b = 'on' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- '0'
INSERT INTO tbl_boolean (a, b) VALUES(1, '0');
UPDATE tbl_boolean SET b = '1' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;


-- 'on' exception
INSERT INTO tbl_boolean (a, b) VALUES(1, on);
UPDATE tbl_boolean SET b = off WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- 'enable' exception
INSERT INTO tbl_boolean (a, b) VALUES(1, 'enable');
UPDATE tbl_boolean SET b = 'disable' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;

-- 'disable' exception
INSERT INTO tbl_boolean (a, b) VALUES(1, 'disable');
UPDATE tbl_boolean SET b = 'enable' WHERE a = 1;
DELETE FROM tbl_boolean WHERE a = 1;
TRUNCATE TABLE tbl_boolean;


-- peek changes according to action configuration
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- get changes according to action configuration
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- peek changes with invalid actions

DROP TABLE tbl_boolean;
SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
