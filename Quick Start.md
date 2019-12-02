# Quick Start

## 1. 准备工作

### 1.1 MySQL

版本要求：>=5.6

### 1.2 Redis

使用standalone模式部署即可

### 1.3 库依赖

NgRouter依赖的库为：perl >= 5.6.1、libpcre、libssl

对于CentOS系统，可以使用yum方式安装：

```shell
sudo yum -y install perl pcre-devel openssl-devel
```

### 1.4 安装包准备

NgRouter的安装包分为：*源码包*、*离线RPM包*两种。如果您的部署环境可以连接公网，则推荐使用源码安装方式或在线环境RPM包，而对于无法连接公网的情况，则可以使用离线RPM包。由于NgRouter依赖Openresty，为解决在无法连接公网环境下Openresty依赖的问题，离线RPM中集成了Openresty-1.15.8.2。

[**下载地址**](https://github.com/gogo-easy/ngr/releases)

## 安装步骤

### 初始化MySQL数据库

用任意的MySQL客户端将[install_db_script/init.sql](https://github.com/gogo-easy/ngr/blob/master/install_db_script/release-1.0.sql)即可。

下面以MySQL原生客户端为例：

```mysql
source /localpath/sql/init.sql
```

### 安装NgRouter

根据部署环境不同，可选择以下三种方式的其中一种：

- 源码安装
- 离线RPM安装

#### 通过源码包安装

通过源码包安装要求安装环境可以连接公网，执行ngr_install.sh安装脚本即可：

```shell
sudo sh ngr_install.sh
```

#### 通过离线RPM包安装

通过rpm命令来安装离线RPM包：

```shell
sudo rpm -ivh ngr-1.0.0-1.el7.centos.x86_64.rpm
```

### 配置数据库连接信息

在/usr/local/ngr/conf/ngr.json中，找到**store_mysql**部分及**cache_redis**部分，并修改MySQL及Redis的正确配置信息。

## 启动NgRouter

### 执行启动命令

```shell
sudo ngr start
```

输出如下信息，说明启动成功：

```shell
$sudo ngr start
[INFO] NgrRouter: 1.0
[INFO] ngx_lua: 10008
[INFO] nginx: 1011002
[INFO] Lua: LuaJIT 2.1.0-beta2
[INFO] args:
[INFO] 	 ngx_conf:/usr/local/ngr/conf/nginx.conf
[INFO] 	 ngr_conf:/etc/ngr/ngr.json
[INFO] 	 prefix:/usr/local/ngr
[INFO] Reading config file at /etc/ngr/ngr.json
[INFO] Generating nginx.conf from /etc/ngr/ngr.json.
[INFO] Starting NgrRouter......
[INFO] Using Parameters: CONF=/etc/ngr/ngr.json PREFIX=/usr/local/ngr
[SUCCESS] NgrRouter started.
```
