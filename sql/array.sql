\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');

-- create table with different numeric type
CREATE TABLE tbl_array(id serial primary key, a bool[], c char[], d name[], e int2[], f int4[], g text[], h varchar[], i int8[], j float4[], k float8[], l timestamptz[], m numeric[], n uuid[] );

-- different data types for array
INSERT INTO tbl_array (a, c, d, e, f, g, h, i, j, k, l, m, n) VALUES(
ARRAY[true, false], 
ARRAY['c'::char,'h'::char], 
ARRAY['student'::name, 'teacher'::name], 
ARRAY['123'::int2, '456'::int2],
ARRAY['123456789'::int4,'987654321'::int4],
ARRAY['abc'::text, '123'::text],
ARRAY['ABCD'::varchar, '1234'::varchar],
ARRAY['112233445566778899'::int8, '998877665544332211'::int8],
ARRAY['123.456'::float4, '2222.3333'::float4],
ARRAY['123456.123'::float8, '654321.123'::float8],
ARRAY['2020-03-30 10:18:40.12-07'::timestamptz, '2020-03-30 20:28:40.12-07'::timestamptz],
ARRAY['123456789'::numeric, '987654321'::numeric],
ARRAY['40e6215d-b5c6-4896-987c-f30f3678f608'::uuid, '3f333df6-90a4-4fda-8dd3-9485d27cee36'::uuid]
);
UPDATE tbl_array SET
a=ARRAY[false, true], 
c=ARRAY['h'::char, 'c'::char], 
d=ARRAY['teacher'::name, 'student'::name], 
e=ARRAY['456'::int2, '123'::int2],
f=ARRAY['987654321'::int4, '123456789'::int4],
g=ARRAY['123'::text, 'abc'::text],
h=ARRAY['1234'::varchar, 'ABCD'::varchar],
i=ARRAY['998877665544332211'::int8, '112233445566778899'::int8],
j=ARRAY['2222.3333'::float4, '123.456'::float4],
k=ARRAY['654321.123'::float8, '123456.123'::float8],
l=ARRAY['2020-03-30 20:28:40.12-07'::timestamptz, '2020-03-30 10:18:40.12-07'::timestamptz],
m=ARRAY['987654321'::numeric, '123456789'::numeric],
n=ARRAY['3f333df6-90a4-4fda-8dd3-9485d27cee36'::uuid, '40e6215d-b5c6-4896-987c-f30f3678f608'::uuid]
WHERE id=1;
DELETE FROM tbl_array WHERE id = 1;
TRUNCATE TABLE tbl_array;


-- peek changes according to action configuration
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- get changes according to action configuration
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- drop table
DROP TABLE tbl_array;
SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
