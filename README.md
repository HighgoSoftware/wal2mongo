### Introduction 
`wal2mongo` is a PostgreSQL logical decoding output plugin designed to make the logical replication easier from `PostgreSQL` to `MongoDB` by formating the output to a JSON-like format accepted by `mongo`.

### Prerequisites
PostgreSQL 12.x

### Build, test and install
`wal2mongo` is designed to support two typical ways for building PostgreSQL extension: one is for developers who want to manage `wal2mongo` source code under PostgreSQL source code tree structure; the other one is for developers or DBA who want to integrate `wal2mongo` to existing PostgreSQL binaries.

### Build under PostgreSQL source code tree
```
cd /path/to/postgres/contrib/
git clone https://github.com/HighgoSoftware/wal2mongo.git
cd wal2mongo
make
make install
make check
```

### Build against PostgreSQL binary install
```
mkdir sandbox
cd sandbox
git clone https://github.com/HighgoSoftware/wal2mongo.git
cd wal2mongo
```

Make sure set the right PATH to use existing `pg_config`
```
$ export PATH=/path/to/postgres/bin:$PATH
USE_PGXS=1 make
USE_PGXS=1 make install
USE_PGXS=1 make installcheck
```

### Setup and configuration
Edit PostgreSQl configuration file `postgresql.conf` and make sure `wal_level` is set to `logical`, and `max_replication_slots` is set at least 1 (default settings is 10).
Restart postgres services.

### Options
TBD...

### Examples
Here are two simple ways to test `wal2mongo`.

#### using psql
* Create a slot 
For example, create a slot nameed 'w2m_slot' using the output plugin `wal2mongo`.
```
postgres=# SELECT * FROM pg_create_logical_replication_slot('w2m_slot', 'wal2mongo');
 slot_name |    lsn     
-----------+------------
 w2m_slot  | 1/3CB04148
(1 row)
```

* Check the slot just created
```
postgres=# SELECT slot_name, plugin, slot_type, database, active, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots;
 slot_name |  plugin   | slot_type | database | active | restart_lsn | confirmed_flush_lsn 
-----------+-----------+-----------+----------+--------+-------------+---------------------
 w2m_slot  | wal2mongo | logical   | postgres | f      | 1/3CB04110  | 1/3CB04148
(1 row)
```

* Create a table and insert data
```
postgres=# CREATE TABLE books (
  id  	 SERIAL PRIMARY KEY,
  title	 VARCHAR(100) NOT NULL,
  author VARCHAR(100) NULL
);

postgres=# insert into books
(id, title, author) 
values
(123, 'HG-PGSQL1.1', 'Highgo');
```

* Peek if any changes
```
postgres=# SELECT * FROM pg_logical_slot_peek_changes('w2m_slot', NULL, NULL);
    lsn     | xid  |                                  data                                  
------------+------+------------------------------------------------------------------------
 1/3CB247F8 | 1793 | db.books.insertOne( { id:123, title:"HG-PGSQL1.1", author:"Highgo" } )
(1 row)
```

* Retrieve the changes
```
postgres=# SELECT * FROM pg_logical_slot_get_changes('w2m_slot', NULL, NULL);
    lsn     | xid  |                                  data                                  
------------+------+------------------------------------------------------------------------
 1/3CB247F8 | 1793 | db.books.insertOne( { id:123, title:"HG-PGSQL1.1", author:"Highgo" } )
(1 row)
```

* Replicate data within mongo console (option 1)
log into mongoDB, and copy all the strings from data section, and paste to mongo console
```
> db.books.insertOne( { id:123, title:"HG-PGSQL1.1", author:"Highgo" } )
{
	"acknowledged" : true,
	"insertedId" : ObjectId("5e5ea92be9684c562aae5b7a")
}
```

* Replicate data using .js file (option 2)
copy all the strings from data section, and paste it to a file, e.g. test.js, then import the file using mongo
```
$ mongo < test.js 
MongoDB shell version v4.0.16
connecting to: mongodb://127.0.0.1:27017/?gssapiServiceName=mongodb
Implicit session: session { "id" : UUID("86ddf177-9704-43f9-9f66-31ac1f9f89e0") }
MongoDB server version: 4.0.16
{
	"acknowledged" : true,
	"insertedId" : ObjectId("5e5ea8f3bb2265ca8fa4b7ae")
}
bye
```

* check the data replicated
```
> db.books.find();
{ "_id" : ObjectId("5e5ea8f3bb2265ca8fa4b7ae"), "id" : 123, "title" : "HG-PGSQL1.1", "author" : "Highgo" }
> 
```

* Drop a slot if not used any more
```
postgres=# SELECT pg_drop_replication_slot('w2m_slot');
 pg_drop_replication_slot 
--------------------------
 
(1 row)
```

#### using pg_recvlogical
* create a slot
```
$ pg_recvlogical -d postgres --slot w2m_slot2 --create-slot --plugin=wal2mongo
```

* start logical decoding stream on terminal 1
```
$ pg_recvlogical -d postgres --slot w2m_slot2 --start -f -
```
or let pg_recvlogical record all the changes to a file, e.g. 
```
$ pg_recvlogical -d postgres --slot w2m_slot2 --start -f test2.js
```

* Create a table and insert data from terminal 2
```
postgres=# CREATE TABLE books (
  id  	 SERIAL PRIMARY KEY,
  title	 VARCHAR(100) NOT NULL,
  author VARCHAR(100) NULL
);

postgres=# insert into books
(id, title, author) 
values
(124, 'HG-PGSQL1.2', 'Highgo');
```

* Check the changes by switching back to terminal 1
one record like below will be showing up or inside file test2.js,
```
db.books.insertOne( { id:124, title:"HG-PGSQL1.2", author:"Highgo" } )
```

* replcate data to mongoDB same as above

* Drop a slot if not used any more
```
$ pg_recvlogical -d postgres --slot w2m_slot2 --drop-slot 
```

