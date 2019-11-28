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
yum -y install perl pcre-devel openssl-devel
```

### 1.4 安装包准备

NgRouter的安装包分为：*源码包*、*离线RPM包*、*在线RPM包*三种。如果您的部署环境可以连接公网，则推荐使用源码安装方式或在线环境RPM包，而对于无法连接公网的情况，则可以使用离线RPM包。由于NgRouter依赖Openresty，为解决在无法连接公网环境下Openresty依赖的问题，离线RPM中集成了Openresty-1.15.8.2。

[**下载地址**](https://github.com/gogo-easy/ngr/releases)

## 安装步骤

### 初始化MySQL数据库

用任意的MySQL客户端将[install_db_script/init.sql](https://github.com/gogo-easy/ngr/blob/master/install_db_script/release-1.0.sql)即可。

下面以MySQL原生客户端为例：

```mysql
source /localpath/sql/init.sql
```

### 安装NgRouter

根据部署环境不通，可选择以下三种方式的其中一种：

- 源码安装
- 离线RPM安装
- 在线RPM安装（暂不支持）

#### 通过源码包安装

通过源码包安装要求安装环境可以连接公网，执行ngr_install.sh安装脚本即可：

```shell
sh ngr_install.sh
```

#### 通过离线RPM包安装

通过rpm命令来安装离线RPM包：

```shell
rpm -ivh ngr-1.0.0-1.el7.centos.x86_64.rpm
```

#### 通过在线RPM包安装

暂未提供在线RPM包

### 配置数据库连接信息

## 启动NgRouter

### 创建日志目录

### 执行启动命令

```shell
ngr start
```

输出一下信息，说明启动成功：

```shell

```

