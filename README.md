![License](https://img.shields.io/github/license/HighgoSoftware/wal2mongo)
![Build](https://travis-ci.com/HighgoSoftware/wal2mongo.svg?branch=release)
[![Release](https://img.shields.io/github/v/tag/HighgoSoftware/wal2mongo?label=Release)](https://github.com/HighgoSoftware/wal2mongo/releases)

### Introduction 
`wal2mongo` is a PostgreSQL logical decoding output plugin designed to make the logical replication easier from `PostgreSQL` to `MongoDB` by formating the output to a JSON-like format accepted by `mongo`.

### Prerequisites
To use wal2mongo logical decoding output plugin, either one of below PostgreSQL servers need to be installed,
* [PostgreSQL 12.x](https://www.postgresql.org/download)
* [HighGo PostgreSQL Server 1.x](https://www.highgo.ca/products/highgo-postgresql-server)

### Build, Test and Install
`wal2mongo` is designed to support two typical ways for building PostgreSQL extension: one is for developers who want to manage `wal2mongo` source code under PostgreSQL source code tree structure; the other one is for developers or DBA who want to integrate `wal2mongo` to existing PostgreSQL binaries.

#### On a Linux-like environment
* Build under PostgreSQL Source Code Tree
```
cd /path/to/postgres/contrib/
git clone https://github.com/HighgoSoftware/wal2mongo.git
cd wal2mongo
make
make install
make check
```

* Build against PostgreSQL binaries
```
mkdir sandbox
cd sandbox
git clone https://github.com/HighgoSoftware/wal2mongo.git
cd wal2mongo
```

Set the `PATH` to point to existing PostgreSQL binary directory. Use `PGHOST` and `PGPORT` to specify a PostgreSQL server and port to run the installcheck-force test against if different from default ones.
```
$ export PATH=/path/to/postgres/bin:$PATH
USE_PGXS=1 make
USE_PGXS=1 make install
USE_PGXS=1 make installcheck-force
```

#### On Windows7, 10 and 2019 Server
* Build under PostgreSQL Source Code Tree
1. Following the instruction [here](https://www.postgresql.org/docs/12/install-windows-full.html) to setup the build environment using Microsoft Windows SDK. The [Visual Studio 2019 Community](https://visualstudio.microsoft.com/downloads/) is enough for building Postgres 12.x and wal2mongo logical decoding output plugin. After VS 2019 has been installed successfully, download [`ActivePerl 5.28`](https://www.activestate.com/products/perl/downloads/), [`ActiveTcl 8.6`](https://www.activestate.com/products/tcl/downloads/) and [`GnuWin32 0.6.3`](https://sourceforge.net/projects/getgnuwin32/files/getgnuwin32/0.6.30/GetGnuWin32-0.6.3.exe/download) and install them with the default setting would be enough.

2. Check the binaries path for `ActivePerl`, `ActiveTcl` and `GnuWin32` for System variables in Environment variables management panel, if not exist then add them in.

3. Build and install

```
cd \path\to\postgres\contrib\
git clone https://github.com/HighgoSoftware/wal2mongo.git
cd \path\to\postgres\src\tools\msvc\
build
install \path\to\install\foler\
```
4. Run regress test (notes, regress test a single extension is not supported by vcregress yet)
```
vcregress contribcheck
```
* Build against PostgreSQL binaries

`wal2mongo` can be built in a separate project folder using Visual Studio 2019 by following the steps below:
1. Create a `new projec`t using `Empty Project` template, and set `Project name` to `wal2mong`, for example.
2. Right click `wal2mongo` project -> Add -> New items ..., select `C++ File` but name it as `wal2mongo.c`
3. Paste all the c source code from github to local `wal2mongo.c` file.
4. Add `PGDLLEXPORT` to function `_PG_init` and `_PG_output_plugin_init`, like below,
```
extern PGDLLEXPORT void _PG_init(void);
extern PGDLLEXPORT void _PG_output_plugin_init(OutputPluginCallbacks* cb);
```
5. Right click `wal2mongo` project -> Properties, then change below settings,
General -> Configuration Type `Dynamic Library (.dll)`

Set C/C++ -> Code Generation -> Enable C++ Exceptions to `NO`

Set C/C++ -> Advanced -> Compile As to `Compile As C Code`

Set Linker -> Manifest File -> Generate Manifest to `No`

Add `postgres.lib` to Linker -> Input -> Additional Dependencies 

Depends on where PostgreSQL binaries are installed, add below pathes in below order to C/C++ -> General -> Additional Include Directories
```
C:\Users\Administrator\Downloads\pg12.2\include\server\port\win32_msvc
C:\Users\Administrator\Downloads\pg12.2\include\server\port\win32
C:\Users\Administrator\Downloads\pg12.2\include\server
C:\Users\Administrator\Downloads\pg12.2\include
```
Again, depends on where PostgreSQL binaries are installed, add a path like below to Linker -> General -> Additional Library Directories
```
C:\Users\Administrator\Downloads\pg12.2\lib
```
6. Right click `wal2mongo1, then click `build`. If everything goes fine, then below message should show up.
```
1>wal2mongo.vcxproj -> C:\Users\Administrator\source\repos\wal2mongo\Debug\wal2mongo.dll
1>Done building project "wal2mongo.vcxproj".
========== Rebuild All: 1 succeeded, 0 failed, 0 skipped ==========
```
7. Manually copy `wal2mongo.dll` to the `lib` where PostgreaSQL is installed, then run test following `Examples` section.


### Setup and configuration
Edit PostgreSQl configuration file `postgresql.conf` and make sure `wal_level` is set to `logical`, and `max_replication_slots` is set at least 1 (default settings is 10).
Restart postgres services.

### Options
TBD...

### Examples
Below are two simple ways to replicate data from PostgreSQL to MongoDB using `wal2mongo`: one use psql console; the other one use pg_recvlogical tools.

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

Copy all the strings from data section, and paste it to a file, e.g. test.js, then import the file using mongo
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
Or let pg_recvlogical record all the changes to a file, e.g. 
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

One record like below should be showing up either in console or inside file test2.js,
```
db.books.insertOne( { id:124, title:"HG-PGSQL1.2", author:"Highgo" } )
```

* replcate data to mongoDB same as above

* Drop a slot if not used any more
```
$ pg_recvlogical -d postgres --slot w2m_slot2 --drop-slot 
```

