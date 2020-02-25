#### Introduction 
`wal2mongo` is a PostgreSQL logical decoding output plugin designed to make the logical replication easier from PostgreSQL to MongoDB by formating the output to a JSON-like format accepted by mongo.

#### Prerequisites
PostgreSQL 12.x

### Build, test and install
`wal2mongo` is designed to support two typical ways for building PostgreSQL extension: one is for developers who want to manage `wal2mongo` source code under PostgreSQL source code tree structure; the other one is for developers or DBA who want to integrate `wal2mongo` to existing PostgreSQL binaries.

#### Build under PostgreSQL source code tree
cd /path/to/postgres/contrib/
git clone https://github.com/HighgoSoftware/wal2mongo.git
cd wal2mongo
make
make install
make check

#### Build against PostgreSQL binary install
mkdir sandbox
cd sandbox
git clone https://github.com/HighgoSoftware/wal2mongo.git
cd wal2mongo
# Set the right PATH to use existing `pg_config`
$ export PATH=/path/to/postgres/bin:$PATH
USE_PGXS=1 make
USE_PGXS=1 make install
USE_PGXS=1 make check

### Setup and configuration
Edit PostgreSQl configuration file `postgresql.conf` and make sure `wal_level` is set to `logical`, and `max_replication_slots` is set at least 1 (default settings is 10).
Restart postgres services.

### Options
TBD...

### Examples
Here are two simple ways to test `wal2mongo`.

#### using psql
##### Create a slot 
For example, create a slot nameed 'w2m_slot' using the output plugin `wal2mongo`.
postgres=# SELECT * FROM pg_create_logical_replication_slot('w2m_slot', 'wal2mongo');

##### Check the slot just created
postgres=# SELECT slot_name, plugin, slot_type, database, active, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots;

TBD...

#### using pg_recvlogical
TBD...
