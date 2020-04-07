\set VERBOSITY terse

-- predictability
SET synchronous_commit = on;

SELECT 'init' FROM pg_create_logical_replication_slot('regression_slot', 'wal2mongo');

-- xml data
CREATE TABLE tbl_xml (id serial primary key, a xml);
ALTER TABLE tbl_xml REPLICA IDENTITY FULL;

-- insert data simple SQL way
INSERT INTO tbl_xml(a) VALUES('<foo> xml-data </foo>'::xml);
-- using XMLPARSE and DOCUMENT syntaxes
INSERT INTO tbl_xml(a) VALUES(XMLPARSE (DOCUMENT'<foo> xml-data </foo>'));
-- xpath example simple SQL way
INSERT INTO tbl_xml(a) VALUES('
<dept
    xmlns:smpl="http://example.com" smpl:did="DPT011-IT">
    <name>IT</name>
    <persons>
        <person smpl:pid="111">
            <name>John Smith</name>
            <age>24</age>
        </person>
        <person smpl:pid="112">
            <name>Michael Black</name>
            <age>28</age>
        </person>
    </persons>
</dept>'::xml);
-- xpath example in minify way
INSERT INTO tbl_xml(a) VALUES('<dept xmlns:smpl="http://example.com" smpl:did="DPT011-IT"><name>IT</name><persons><person smpl:pid="111"><name>John Smith</name><age>24</age></person><person smpl:pid="112"><name>Michael Black</name><age>28</age></person></persons></dept>'::xml);
-- xpath example using XMLPARSE and DOCUMENT
INSERT INTO tbl_xml(a) VALUES(XMLPARSE (DOCUMENT'
<dept
    xmlns:smpl="http://example.com" smpl:did="DPT011-IT">
    <name>IT</name>
    <persons>
        <person smpl:pid="111">
            <name>John Smith</name>
            <age>24</age>
        </person>
        <person smpl:pid="112">
            <name>Michael Black</name>
            <age>28</age>
        </person>
    </persons>
</dept>'));

-- update using simple SQL way
UPDATE tbl_xml SET a = '                                                      
<dept                                                                           
    xmlns:smpl="http://example.com" smpl:did="DPT011-IT">                       
    <name>IT</name>                                                             
    <persons>                                                                   
        <person smpl:pid="111">                                                 
            <name>John Smith</name>                                             
            <age>24</age>                                                       
        </person>                                                               
        <person smpl:pid="112">                                                 
            <name>Michael Black</name>                                          
            <age>28</age>                                                       
        </person>                                                               
    </persons>                                                                  
</dept>'::xml WHERE id=1;

-- update using XMLPARSE and DOCUMENT syntaxes
UPDATE tbl_xml SET a = 
XMLPARSE (DOCUMENT'                               
<dept                                                                           
    xmlns:smpl="http://example.com" smpl:did="DPT011-IT">                       
    <name>IT</name>                                                             
    <persons>                                                                   
        <person smpl:pid="111">                                                 
            <name>John Smith</name>                                             
            <age>24</age>                                                       
        </person>                                                               
        <person smpl:pid="112">                                                 
            <name>Michael Black</name>                                          
            <age>28</age>                                                       
        </person>                                                               
    </persons>                                                                  
</dept>') WHERE id=2;

-- delete
DELETE FROM tbl_xml WHERE id = 1;
TRUNCATE TABLE tbl_xml;

-- peek changes 
SELECT data FROM pg_logical_slot_peek_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- get changes
SELECT data FROM pg_logical_slot_get_changes('regression_slot', NULL, NULL, 'regress', 'true');

-- drop table
DROP TABLE tbl_xml;

SELECT 'end' FROM pg_drop_replication_slot('regression_slot');
