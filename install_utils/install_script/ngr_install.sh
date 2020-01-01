#!/usr/bin/env bash
# Install dependencies
echo ''
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo 'Start to install dependencies'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo ''
yum install -y pcre-devel openssl-devel gcc

# Add yum repo
echo ''
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo 'Start to config yum repo'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo ''
yum -y install yum-utils
yum-config-manager --add-repo https://openresty.org/package/rhel/openresty.repo

# Install Openresty
echo ''
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo 'Start to install openresty'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo ''
yum -y install unzip
yum -y install openresty
yum -y install openresty-resty

ln -sf /usr/local/openresty/bin/resty /usr/local/bin/resty
ln -sf /usr/local/openresty/bin/openresty /usr/local/bin/openresty
ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/local/bin/nginx

# Verify Openresty Installation
nginx -v
resty -v
openresty -v

# Install luarock
echo ''
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo 'Start to install luarock'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo ''
wget http://luarocks.github.io/luarocks/releases/luarocks-3.2.1.tar.gz
tar -xzf luarocks-3.2.1.tar.gz
cd luarocks-3.2.1/
./configure --prefix="/usr/local/openresty/luajit" \
--with-lua="/usr/local/openresty/luajit" \
--lua-suffix=jit \
--with-lua-include="/usr/local/openresty/luajit/include/luajit-2.1" \
--with-lua-lib="/usr/local/openresty/luajit/lib/"
make build
make install
ln -sf /usr/local/openresty/luajit/bin/luarocks /usr/local/bin/luarocks
cd ..

# Install luafilesystem by luarocks
echo ''
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo 'Start to install luafilesystem'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo ''
luarocks install luafilesystem

# Install ngr
echo ''
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo 'Start to install ngr'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
echo ''
make install
