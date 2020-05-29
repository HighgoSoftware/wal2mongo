\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');

-- network address
CREATE TABLE tbl_net (id serial PRIMARY KEY, a inet, b cidr, c macaddr, d macaddr8);

-- ipv4 in different format
INSERT INTO tbl_net(a,b,c,d) VALUES('192.168.100.128/25'::inet, '192.168.100.128/25'::cidr, '08:00:2b:01:02:03'::macaddr, '08:00:2b:01:02:03:04:05'::macaddr8);
INSERT INTO tbl_net(a,b,c,d) VALUES('192.168.0.1/24'::inet, '192.168/24'::cidr, '08-00-2b-01-02-03'::macaddr, '08-00-2b-01-02-03-04-05'::macaddr8);
INSERT INTO tbl_net(a,b,c,d) VALUES('192.168.0.0/16'::inet, '192.168'::cidr, '08002b:010203'::macaddr, '08002b:0102030405'::macaddr8);
INSERT INTO tbl_net(a,b,c,d) VALUES('10.0.0.1/8'::inet, '10'::cidr, '08002b-010203'::macaddr, '08002b-0102030405'::macaddr8);
INSERT INTO tbl_net(a,b,c,d) VALUES('10.1.2.3/32'::inet, '10.1.2.3/32'::cidr, '0800.2b01.0203'::macaddr, '0800.2b01.0203.0405'::macaddr8);
INSERT INTO tbl_net(a,b,c,d) VALUES('2001:4f8:3:ba::/64'::inet, '2001:4f8:3:ba::/64'::cidr, '0800-2b01-0203'::macaddr, '0800-2b01-0203-0405'::macaddr8);

-- ipv6 and mac in lower case
INSERT INTO tbl_net(a,b,c,d) VALUES('2001:4f8:3:ba:2e0:81ff:fe22:d1f1/128'::inet, '2001:4f8:3:ba:2e0:81ff:fe22:d1f1/128'::cidr, '08002b010203'::macaddr, '08002b01:02030405'::macaddr8);
-- ipv6 and mac in upper case
INSERT INTO tbl_net(a,b,c,d) VALUES('2001:4F8:3:BA:2E0:81FF:FE22:D1F1/128'::inet, '2001:4F8:3:BA:2E0:81FF:FE22:D1F1/128'::cidr, '08002B010203'::macaddr, '08002B0102030405'::macaddr8);

UPDATE tbl_net SET a='10.1.2.3/32'::inet, b='10.1.2.3/32'::cidr, c='0800-2b01-0203'::macaddr, d='0800-2b01-0203-0405'::macaddr8 WHERE id=1;
DELETE FROM tbl_net WHERE id = 1;
TRUNCATE TABLE tbl_net;

-- peek changes
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- get changes
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- drop table
DROP TABLE tbl_net;


-- geo data
CREATE TABLE tbl_geo (id serial PRIMARY KEY, a point, b line, c lseg, d box, e path, f path, g polygon, h circle);
ALTER TABLE tbl_geo REPLICA IDENTITY FULL;

-- geo different data types
INSERT INTO tbl_geo(a,b,c,d,e,f,g,h) VALUES('(1,1)'::point, '[(1,1),(2,2)]'::line, '[(3,3), (4,4)]'::lseg, '((1,1),(2,2))'::box, '[(1,1),(2,2),(3,3)]'::path, '((1,1),(2,2),(3,3))'::path, '((1,1),(2,2),(3,3),(4,4))'::polygon, '<(1,1),5>'::circle);

UPDATE tbl_geo SET a='11,11'::point, b='((11,11),(12,12))'::line, c='((13,13), (14,14))'::lseg, d='(11,11),(12,12)'::box, e='(11,11),(12,12),(13,13)'::path, f='(11,11,12,12,13,13)'::path, g='(11,11),(12,12),(13,13),(14,14)'::polygon, h='((11,11),15)'::circle WHERE id=1;

INSERT INTO tbl_geo(a,b,c,d,e,f,g,h) VALUES('(1,1)'::point, '(1,1),(2,2)'::line, '(3,3), (4,4)'::lseg, '1,1,2,2'::box, '1,1,2,2,3,3'::path, '1,1,2,2,3,3'::path, '(1,1,2,2,3,3,4,4)'::polygon, '1,1,5'::circle);

UPDATE tbl_geo SET a='21,21'::point, b='21,21,22,22'::line, c='23,23, 24,24'::lseg, d='21,21,22,22'::box, e='(21,21,22,22,23,23)'::path, f='21,21,22,22,23,23'::path, g='21,21,22,22,23,23,24,24'::polygon, h='21,21,25'::circle WHERE id=2;

DELETE FROM tbl_geo WHERE id = 1;
DELETE FROM tbl_geo WHERE id = 2;
TRUNCATE TABLE tbl_geo;

-- peek changes 
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- get changes
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- drop table
DROP TABLE tbl_geo;


SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
