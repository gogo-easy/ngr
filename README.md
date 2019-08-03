# NgRouter
NgRouter是基于OpenResty的强大的边缘网关中间件。

## 架构模块
1. NgRouter Gateway: 用于网关服务节点
2. NgRouter Admin：用于配置管理API服务
3. 架构图

## 代码结构
### 启动模块，负责编写NgRouter命令，动态生成配置,Gateway Service及Admin Service的启动都依赖与带模块
- bin：启动和关闭命令模块
- conf：配置模块

### core核心逻辑模块
- cache: 缓存访问层公共逻辑模块
- dao：数据访问模块 
- framework： 基础框架层模块
- store：数据存储模块
- utils: 工具集 

### plugins: API控制插件模块
### lualib：引入并改造lua公用库
### admin-api：API网关Admin模块Restful API定义
### lor: lor框架引入，用于实现admin-api接口暴露

## 依赖
- [OpenResty](http://openresty.org/cn/)
- [luafilesystem](http://keplerproject.github.io/luafilesystem/)
- redis
- mysql

## 贡献者
- [@Fijian](https://github.com/jacobslei)
- [@yearyeardiff](https://github.com/yearyeardiff)


## Wiki
- [分布式API网关中间件—NgRouter]

## OpenResty安装说明

### 安装前准备工作
安装前，必须将pcre, openssl, gcc安装到你的系统中

MacOSX：

```
brew update
brew install pcre openssl
```

CentOS：

```
yum install pcre-devel openssl-devel gcc
```

*注意事项： 如果不能访问外网的话，请配置内部yum repo。/etc/yum.repos.d/*

### Openresty安装
#### 编译安装

1. download openresty tar 建议openresty-1.11.2.3.tar.gz版本以上

```
wget https://openresty.org/download/openresty-1.11.2.3.tar.gz
```

2. unpack tar

```
tar -xzvf openresty-VERSION.tar.gz
```

其中VERSION替换成 OpenResty的版本号, 比如 1.11.2.3其中VERSION

3. cd unpack directory

```
cd openresty-VERSION/
```

4. configure
MacOSX：

```
./configure --prefix=/usr/local/openresty/ \
--with-cc-opt="-I/usr/local/opt/openssl/include/ -I/usr/local/opt/pcre/include/" \
--with-ld-opt="-L/usr/local/opt/openssl/lib/ -L/usr/local/opt/pcre/lib/" \
--with-luajit \
--without-http_redis2_module \
--with-http_iconv_module \
--with-pcre-jit \
--with-ipv6 \
--with-http_realip_module \
--with-http_ssl_module \
--with-http_stub_status_module \
--with-http_v2_module
```

CentOS：

```
./configure --prefix=/usr/local/openresty/ \
--with-luajit \
--without-http_redis2_module \
--with-http_iconv_module \
--with-pcre-jit \
--with-ipv6 \
--with-http_realip_module \
--with-http_ssl_module \
--with-http_stub_status_module \
--with-http_v2_module
```


5. make & make install

6. set environment path parameter

```
export path=$path:/usr/local/openresty/bin:/usr/local/openresty/nginx/sbin
```


7. 设置软链

```
ln -s /usr/local/openresty/bin/resty /usr/local/bin/resty
ln -s /usr/local/openresty/bin/openresty /usr/local/bin/openresty
ln -s /usr/local/openresty/nginx/sbin/nginx /usr/local/bin/nginx
```


8. testing nginx & openresty & resty

```
nginx -v
```
```
openresty -v
```

nginx version: openresty/1.11.2.3

```
resty -v
```

resty 0.17
nginx version: openresty/1.11.2.3
built by gcc 4.4.7 20120313 (Red Hat 4.4.7-18) (GCC) 
built with OpenSSL 1.0.1e-fips 11 Feb 2013
TLS SNI support enabled
configure arguments: --prefix=/usr/local/openresty//nginx --with-cc-opt=-O2 --add-module=../ngx_devel_kit-0.3.0 --add-module=../iconv-nginx-module-0.14 --add-module=../echo-nginx-module-0.60 --add-module=../xss-nginx-module-0.05 --add-module=../ngx_coolkit-0.2rc3 --add-module=../set-misc-nginx-module-0.31 --add-module=../form-input-nginx-module-0.12 --add-module=../encrypted-session-nginx-module-0.06 --add-module=../srcache-nginx-module-0.31 --add-module=../ngx_lua-0.10.8 --add-module=../ngx_lua_upstream-0.06 --add-module=../headers-more-nginx-module-0.32 --add-module=../array-var-nginx-module-0.05 --add-module=../memc-nginx-module-0.18 --add-module=../redis-nginx-module-0.3.7 --add-module=../rds-json-nginx-module-0.14 --add-module=../rds-csv-nginx-module-0.07 --with-ld-opt=-Wl,-rpath,/usr/local/openresty/luajit/lib --with-pcre-jit --with-ipv6 --with-http_realip_module --with-http_ssl_module --with-http_stub_status_module --with-http_v2_module

#### YUM安装(Centos)
1. 配置yum仓库
```
yum install yum-utils
yum-config-manager --add-repo https://openresty.org/package/rhel/openresty.repo
```
2. yum install openresty
3. yum install resty
4. 设置软链
```
ln -s /usr/local/openresty/bin/resty /usr/local/bin/resty
ln -s /usr/local/openresty/bin/openresty /usr/local/bin/openresty
ln -s /usr/local/openresty/nginx/sbin/nginx /usr/local/bin/nginx
```
5. testing nginx & openresty & resty

### 安装 Luaraocks
luarocks is lua package management tool just like maven for java

- Download luarocks 2.4.4(version < 3.0.0)
参见https://github.com/luarocks/luarocks/wiki/Release-history下载

`wget https://luarocks.org/releases/luarocks-2.4.4.tar.gz`

- tar zxpf luarocks-2.4.4.tar.gz
- cd 你的下载目录/luarocks-2.4.4
- configure， 将lua lib默认安装到Openresty luajit下


```
./configure --prefix="/usr/local/openresty/luajit" --with-lua="/usr/local/openresty/luajit" --lua-suffix=jit --with-lua-include="/usr/local/openresty/luajit/include/luajit-2.1" --with-lua-lib="/usr/local/openresty/luajit/lib/"
```
- build and install


```
make build
make install
```
-  ln -s /usr/local/openresty/luajit/bin/luarocks /usr/local/bin/luarocks

- testing luarocks


```
luarocks
```


### 通过luarocks安装 luafilesystem


```
luarocks install luafilesystem
```

测试 luafilesystem

```
resty -e "require 'lfs' "
```

*注意事项： 如果不能访问外网的话，请编译安装luafilesystem, 见luafilesystem github下载， 然后修改config文件， make && make install，这个时候就不需要按照luarocks，可省略Luarocks安装步骤。* 

## NgRouter安装说明
- NgRouter采用编译安装，非常简单
- 安装NgRouter网关模块： 使用命令make install
- 安装NgRouter管理配置模块： 使用命令 make install-admin

## NgRouter运行方式
### NgRouter Gateway
1. ngr start 启动
2. ngr stop 停止
3. ngr reload 重载配置
4. ngr restart 重新启动
5. 测试是否启动成功： `curl 127.0.0.1/health/ping`

### NgRouter Admin
1. ngrAdmin start 启动
2. ngrAdmin stop 停止
3. ngrAdmin reload 重载配置
4. ngrAdmin restart 重新启动
5. 测试是否启动成功：`curl 127.0.0.1:7777/health/ping`

### 启动可能失败的原因
1. 监听端口是否已经被占用
2. NgRouter日志路径是否存在,Gateway服务默认日志目录/var/log/ngr, Admin服务默认日志目录/var/log/ngrAdmin


## License
[MIT](./LICENSE)
