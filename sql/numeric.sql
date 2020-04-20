\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');

-- create table with different numeric type
CREATE TABLE tbl_int(id serial primary key, a smallint, b integer, c serial, d real, e bigint, f bigserial, g double precision, h decimal, i numeric);

-- minumum values
INSERT INTO tbl_int values(1, -32768, -2147483648, 1, -0.123456, -9223372036854775808, 1, -1.123456789123456, -1234567890.1234567891, -9876543210.0987654321);
UPDATE tbl_int SET a=a+1, b=b+1, c=c+1, d=d+1, e=e+1, f=f+1, g=g+1, h=h+1, i=i+1 WHERE id=1;
DELETE FROM tbl_int WHERE id = 1;
TRUNCATE TABLE tbl_int;

-- maximum values
INSERT INTO tbl_int values(1, 32767, 2147483647, 2147483647, 0.123456, 9223372036854775807, 9223372036854775807, 1.123456789123456, 1234567890.1234567891, 9876543210.0987654321);
UPDATE tbl_int SET a=a-1, b=b-1, c=c-1, d=d-1, e=e-1, f=f-1, g=g-1, h=h-1, i=i-1 WHERE id=1;
DELETE FROM tbl_int WHERE id = 1;
TRUNCATE TABLE tbl_int;


-- peek changes according to action configuration
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- get changes according to action configuration
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- drop table
DROP TABLE tbl_int;
SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
