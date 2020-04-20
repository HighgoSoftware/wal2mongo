\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');

CREATE TABLE testing (a integer primary key, 
					  j1 json, 
					  j2 jsonb,
					  j3 jsonpath,
					  j4 json[],
					  j5 jsonb[]);

-- JSON data type
INSERT INTO testing (a, j1) VALUES(1, '{"customer": "John", "items":{"product":"beer","qty":20}}');
INSERT INTO testing (a, j1) VALUES(2, '{"customer": "Michael", "items":[{"product":"vodka","qty":5},{"product":"whiskey","qty":10},{"product":"cooler","qty":10}]}');
INSERT INTO testing (a, j1) VALUES(3, '{"customer": "Joe", "items":{"product":"wine","qty":20}}');
UPDATE testing set j1='{"customer": "Michael", "items":[{"product":"vodka","qty":5},{"product":"whiskey","qty":10}]}' where a = 3;
DELETE FROM testing where a = 1;

-- JSONB data type
INSERT INTO testing (a, j2) VALUES(4, '{"customer": "John", "items":{"product":"beer","qty":20}}');
INSERT INTO testing (a, j2) VALUES(5, '{"customer": "Michael", "items":[{"product":"vodka","qty":5},{"product":"whiskey","qty":10},{"product":"cooler","qty":10}]}');
INSERT INTO testing (a, j2) VALUES(6, '{"customer": "Joe", "items":{"product":"wine","qty":20}}');
UPDATE testing set j2='{"customer": "Michael", "items":[{"product":"vodka","qty":5},{"product":"whiskey","qty":10}]}' where a = 3;
DELETE FROM testing where a = 1;

-- JSONPATH data type
INSERT INTO testing (a, j3) VALUES(7, '$.equipment.rings[*] ? (@.track.segments > 1)');
UPDATE testing set j3 = '$.equipment.rings[*]' where a = 7;
DELETE from testing where a = 7;

-- JSON[] data type
INSERT into testing (a, j4) VALUES 
( 
	8,
	array[ 
		'{"customer": "Cary", "items":{"product":"beer","qty":1000}}',
		'{"customer": "John", "items":{"product":"beer","qty":2000}}',
		'{"customer": "David", "items":{"product":"beer","qty":3000}}'
	]::json[] 
);
UPDATE testing set j4 = 
array[ 
		'{"customer": "Cary"}',
		'{"customer": "John"}',
		'{"customer": "David"}'
]::json[] where a = 8;
DELETE FROM testing where a = 8;

-- JSONB[] data type
INSERT into testing (a, j5) VALUES 
( 
	9,
	array[ 
		'{"customer": "Cary", "items":{"product":"beer","qty":1000}}',
		'{"customer": "John", "items":{"product":"beer","qty":2000}}',
		'{"customer": "David", "items":{"product":"beer","qty":3000}}'
	]::json[] 
);
UPDATE testing set j5 = 
array[ 
		'{"customer": "Cary"}',
		'{"customer": "John"}',
		'{"customer": "David"}'
]::json[] where a = 9;
DELETE FROM testing where a = 9;

-- get the changes
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'use_transaction', 'false', 'regress', 'true');

DROP TABLE testing;
SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
