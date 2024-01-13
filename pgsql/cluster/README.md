bitnami/postgresql-repmgr 是 PostgreSQL HA 对应的 docker 镜像，PostgreSQL HA 是 PostgreSQL 集群解决方案，其中包括 PostgreSQL 复制管理器，这是一个用于管理 PostgreSQL 集群上的复制和故障转移的开源工具。

bitnami/pgpool 是 Pgpool-II 对应的 docker 镜像，是 PostgreSQL 代理。它位于 PostgreSQL 服务器和它们的客户端之间，提供连接池、负载平衡、自动故障转移和复制。



试验环境
两台机器：server-0：192.168.30.141、server-1：192.168.30.134

pg-0、pg-1 代表 postgresql-repmgr 容器

pg-0 做主库，pg-1 做从库

系统：ubuntu20.04

docker 版本 20.10.12

docker-compose 版本 1.25.0

需要准备的镜像

bitnami/postgresql-repmgr:14 对应着 postgresql14

bitnami/pgpool:4

修改 hosts 文件
分别修改 server-0、server-1 上的 hosts 文件

sudo vim /etc/hosts 添加下面的内容

```vim
192.168.30.141 pg-0
192.168.30.134 pg-1
```

部署数据库服务器
在 server-0 的创建文件：touch ~/pgdb/docker-compose.yml

```yaml
version: '2'

services:
  pg-0:
    image: bitnami/postgresql-repmgr:14
    network_mode: "host"
    container_name: "pgrepmgr0"
    ports:
      - 5432
    volumes:
      - ./data:/bitnami/postgresql
    environment:
      - POSTGRESQL_POSTGRES_PASSWORD=adminpassword
      - POSTGRESQL_USERNAME=customuser
      - POSTGRESQL_PASSWORD=custompassword
      - POSTGRESQL_DATABASE=customdatabase
      - POSTGRESQL_NUM_SYNCHRONOUS_REPLICAS=1
      - REPMGR_USERNAME=repmgr
      - REPMGR_PASSWORD=repmgrpassword
      - REPMGR_PRIMARY_HOST=pg-0
      - REPMGR_PRIMARY_PORT=5432
      - REPMGR_PARTNER_NODES=pg-0,pg-1:5432
      - REPMGR_NODE_NAME=pg-0
      - REPMGR_NODE_NETWORK_NAME=pg-0
      - REPMGR_PORT_NUMBER=5432
    restart: always
      
```

在 server-1 的创建文件：touch ~/pgdb/docker-compose.yml

```yaml
version: '2'

services:
  pg-1:
    image: bitnami/postgresql-repmgr:14
    network_mode: "host"
    container_name: "pgrepmgr1"
    volumes:
      - ./data:/bitnami/postgresql
    environment:
      - POSTGRESQL_POSTGRES_PASSWORD=adminpassword
      - POSTGRESQL_USERNAME=customuser
      - POSTGRESQL_PASSWORD=custompassword
      - POSTGRESQL_DATABASE=customdatabase
      - POSTGRESQL_NUM_SYNCHRONOUS_REPLICAS=1
      - REPMGR_USERNAME=repmgr
      - REPMGR_PASSWORD=repmgrpassword
      - REPMGR_PRIMARY_HOST=pg-0
      - REPMGR_PRIMARY_PORT=5432
      - REPMGR_PARTNER_NODES=pg-0,pg-1:5432
      - REPMGR_NODE_NAME=pg-1
      - REPMGR_NODE_NETWORK_NAME=pg-1
      - REPMGR_PORT_NUMBER=5432
    restart: always

```


为了数据持久化，我们把 /bitnami/postgresql 目录挂载到当前的 data 目录中

docker-compose up 的时候应该会出现权限问题，这个时候我们给新建的 data 目录相应权限就行了，执行如下命令：

sudo chgrp -R root data

sudo chmod -R g+rwX data

再次 docker-compose up -d 应该就好了


部署 pgpool
server-0 中

为了后续方便修改配置文件，我们把配置文件挂载出来

首先在创建配置文件./conf/myconf.conf

然后在创建文件 touch ~/pgpool/docker-compose.yml：

```yaml

version: '2.1'
services:
  pgpool:
    image: bitnami/pgpool:4
    container_name: "pgpool"
    network_mode: "bridge"
    ports:
      - 9999:5432
    volumes:
      - ./conf/myconf.conf:/config/myconf.conf
    environment:
      - PGPOOL_USER_CONF_FILE=/config/myconf.conf
      - PGPOOL_BACKEND_NODES=0:pg-0:5432,1:pg-1:5432
      - PGPOOL_SR_CHECK_USER=repmgr
      - PGPOOL_SR_CHECK_PASSWORD=repmgrpassword
      - PGPOOL_ENABLE_LDAP=no
      - PGPOOL_POSTGRES_USERNAME=postgres
      - PGPOOL_POSTGRES_PASSWORD=adminpassword
      - PGPOOL_ADMIN_USERNAME=admin
      - PGPOOL_ADMIN_PASSWORD=adminpassword
      - PGPOOL_ENABLE_LOAD_BALANCING=yes
      - PGPOOL_POSTGRES_CUSTOM_USERS=customuser
      - PGPOOL_POSTGRES_CUSTOM_PASSWORDS=custompassword
    restart: always
    extra_hosts:
      - "pg-0:192.168.30.141"
      - "pg-1:192.168.30.134"
    healthcheck:
      test: ["CMD", "/opt/bitnami/scripts/pgpool/healthcheck.sh"]
      interval: 10s
      timeout: 5s
      retries: 5
```


docker-compose up 后看没有报错就好了，通过 pgpool 可以实现数据库的负载均衡和读写分离


