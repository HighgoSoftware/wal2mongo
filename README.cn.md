![License](https://img.shields.io/github/license/HighgoSoftware/wal2mongo)
![Build](https://travis-ci.com/HighgoSoftware/wal2mongo.svg?branch=release)
[![Release](https://img.shields.io/github/v/tag/HighgoSoftware/wal2mongo?label=Release)](https://github.com/HighgoSoftware/wal2mongo/releases)

### 介绍 
`wal2mongo` 是一个PostgreSQL逻辑解码输出插件，用来输出mongo能够接受JSON格式，使PostgreSQL到MongoDB的逻辑复制更加容易。

### 使用条件
要使用wal2mongo逻辑解码输出插件，需要安装以下PostgreSQL服务器之一，
* [PostgreSQL 12.x](https://www.postgresql.org/download)
* [HighGo PostgreSQL Server 1.x](https://www.highgo.ca/products/highgo-postgresql-server)

### 编译，测试和安装
`wal2mongo` 支持两种编译方式：一种是针对希望在PostgreSQL源代码树结构下管理 wal2mongo 代码的开发人员。 另一个是针对希望将wal2mongo集成到已编译好的PostgreSQL的开发人员或DBA。

#### 类似Linux的环境中
* 在PostgreSQL源代码树下构建
```
cd /path/to/postgres/contrib/
git clone https://github.com/HighgoSoftware/wal2mongo.git
cd wal2mongo
make
make install
make check
```

* 针对PostgreSQL二进制文件编译
```
mkdir sandbox
cd sandbox
git clone https://github.com/HighgoSoftware/wal2mongo.git
cd wal2mongo
```

将 “PATH” 指向现有的PostgreSQL二进制目录。 使用`PGHOST`和`PGPORT`指定一个PostgreSQL服务器和端口来运行installcheck-force测试。
```
$ export PATH=/path/to/postgres/bin:$PATH
USE_PGXS=1 make
USE_PGXS=1 make install
USE_PGXS=1 make installcheck-force
```

#### 在Windows 7、10和2019服务器上
* 在PostgreSQL源代码树下编译
1. 按照 [此处](https://www.postgresql.org/docs/12/install-windows-full.html) 的说明使用Microsoft Windows SDK设置编译环境. [Visual Studio 2019社区版](https://visualstudio.microsoft.com/downloads/) 足以编译Postgres 12.x和wal2mongo逻辑解码输出插件。 成功安装VS 2019之后，请下载 [`ActivePerl 5.28`](https://www.activestate.com/products/perl/downloads/), [`ActiveTcl 8.6`](https://www.activestate.com/products/tcl/downloads/) 和 [`GnuWin32 0.6.3`](https://sourceforge.net/projects/getgnuwin32/files/getgnuwin32/0.6.30/GetGnuWin32-0.6.3.exe/download) 然后使用默认设置安装即可。

2. 在环境变量管理面板中检查系统变量的 “ActivePerl”，“ActiveTcl” 和 “GnuWin32” 的二进制路径，如果不存在，请添加它们。

3. 编译并安装

```
cd \path\to\postgres\contrib\
git clone https://github.com/HighgoSoftware/wal2mongo.git
cd \path\to\postgres\src\tools\msvc\
build
install \path\to\install\foler\
```
4. 运行回归测试（注意，vcregress尚不支持单个扩展的回归测试）
```
vcregress contribcheck
```
* 针对PostgreSQL二进制文件编译

可以按照以下步骤使用Visual Studio 2019编译`wal2mongo`
1. 使用空项目 （empty project）模板创建一个新项目，例如，将项目名称设置为 `wal2mongo`
2. 右键单击 `wal2mongo` 项目->添加->新项目...，选择 `C ++ File`，但将其命名为`wal2mongo.c`。
3. 将来自github的所有c源代码粘贴到本地“ wal2mongo.c” 文件中。
4. 将 “PGDLLEXPORT” 添加到函数 “_PG_init” 和 “_PG_output_plugin_init”中，如下所示，
```
extern PGDLLEXPORT void _PG_init(void);
extern PGDLLEXPORT void _PG_output_plugin_init(OutputPluginCallbacks* cb);
```
5. 右键点击`wal2mongo`项目->属性，然后更改以下设置，
常规->配置类型“动态库（.dll）”

设置C / C++ ->代码生成->启用C++ exceptions 的设置改为`否`

设置C / C ++->高级->编译为`编译为C代码`

将链接器->清单文件->生成清单设置为“否”

将`postgres.lib`添加到链接器->输入->其他依赖项

根据PostgreSQL二进制文件的安装位置，按以下顺序将以下路径添加到 C / C++ ->常规->其他include目录

```
C:\Users\Administrator\Downloads\pg12.2\include\server\port\win32_msvc
C:\Users\Administrator\Downloads\pg12.2\include\server\port\win32
C:\Users\Administrator\Downloads\pg12.2\include\server
C:\Users\Administrator\Downloads\pg12.2\include
```
同样，根据PostgreSQL二进制文件的安装位置，在Linker-> General-> Additional Library Directories 中添加如下所示的库路径
```
C:\Users\Administrator\Downloads\pg12.2\lib
```
6. 右键点击`wal2mongo`，然后点击`build`。 如果一切正常，则应该显示以下消息。
```
1>wal2mongo.vcxproj -> C:\Users\Administrator\source\repos\wal2mongo\Debug\wal2mongo.dll
1>Done building project "wal2mongo.vcxproj".
========== Rebuild All: 1 succeeded, 0 failed, 0 skipped ==========
```
7. 手动将 “wal2mongo.dll” 复制到安装了PostgreaSQL的 “lib”中，然后按照示例部分进行测试。


### 设置和配置
编辑PostgreSQl配置文件 “postgresql.conf”，并确保将 “wal_level” 设置为 “logical”，并且将 “max_replication_slots” 设置为至少1（默认设置为10）。
重新启动postgres服务。

### 选件
有待确定...

### 样例
下面是两种使用wal2mongo将数据从PostgreSQL复制到MongoDB的简单方法：一种使用psql console；另一个使用pg_recvlogical工具。

#### 使用psql console
* 创建一个逻辑插槽
例如，使用输出插件 “wal2mongo” 创建一个名为 “w2m_slot”的逻辑插槽。
```
postgres=# SELECT * FROM pg_create_logical_replication_slot('w2m_slot', 'wal2mongo');
 slot_name |    lsn     
-----------+------------
 w2m_slot  | 1/3CB04148
(1 row)
```

* 检查刚创建的插槽
```
postgres=# SELECT slot_name, plugin, slot_type, database, active, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots;
 slot_name |  plugin   | slot_type | database | active | restart_lsn | confirmed_flush_lsn 
-----------+-----------+-----------+----------+--------+-------------+---------------------
 w2m_slot  | wal2mongo | logical   | postgres | f      | 1/3CB04110  | 1/3CB04148
(1 row)
```

* 创建一个表并插入数据
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

* 查看有无任何改动
```
postgres=# SELECT * FROM pg_logical_slot_peek_changes('w2m_slot', NULL, NULL);
    lsn     | xid  |                                  data                                  
------------+------+------------------------------------------------------------------------
 1/3CB247F8 | 1793 | db.books.insertOne( { id:123, title:"HG-PGSQL1.1", author:"Highgo" } )
(1 row)
```

* 取得改动
```
postgres=# SELECT * FROM pg_logical_slot_get_changes('w2m_slot', NULL, NULL);
    lsn     | xid  |                                  data                                  
------------+------+------------------------------------------------------------------------
 1/3CB247F8 | 1793 | db.books.insertOne( { id:123, title:"HG-PGSQL1.1", author:"Highgo" } )
(1 row)
```

* 使用 mongo 客户端中复制数据（选项1）

登录 mongoDB，然后复制数据部分中的所有字符串，然后粘贴到 mongo 客户端上
```
> db.books.insertOne( { id:123, title:"HG-PGSQL1.1", author:"Highgo" } )
{
	"acknowledged" : true,
	"insertedId" : ObjectId("5e5ea92be9684c562aae5b7a")
}
```

* 使用.js文件复制数据（选项2）

复制输出的所有字符串，然后将其粘贴到文件中，例如 test.js，然后使用mongo客户端导入文件
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

* 检查复制的数据
```
> db.books.find();
{ "_id" : ObjectId("5e5ea8f3bb2265ca8fa4b7ae"), "id" : 123, "title" : "HG-PGSQL1.1", "author" : "Highgo" }
> 
```

* 删除逻辑插槽如果不再使用的话
```
postgres=# SELECT pg_drop_replication_slot('w2m_slot');
 pg_drop_replication_slot 
--------------------------
 
(1 row)
```

#### 使用 pg_recvlogical
* 创建一个逻辑插槽
```
$ pg_recvlogical -d postgres --slot w2m_slot2 --create-slot --plugin=wal2mongo
```

* 在终端1上启动pg_recvlogical
```
$ pg_recvlogical -d postgres --slot w2m_slot2 --start -f -
```
或者让 pg_recvlogical 记录所有数据改动到一个文件，例如
```
$ pg_recvlogical -d postgres --slot w2m_slot2 --start -f test2.js
```

* 创建一个表并从终端2插入数据
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

* 切换回终端1来检查更改

如下所示的一条记录应该显示在终端1或文件 test2.js 中，
```
db.books.insertOne( { id:124, title:"HG-PGSQL1.2", author:"Highgo" } )
```

* 将数据复制到mongoDB

* 删除逻辑插槽如果不再使用的话
```
$ pg_recvlogical -d postgres --slot w2m_slot2 --drop-slot 
```

