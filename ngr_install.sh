# Install dependencies
echo 'Start to install dependencies'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
yum install -y pcre-devel openssl-devel gcc

# Add yum repo
echo 'Start to config yum repo'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
yum -y install yum-utils
yum-config-manager --add-repo https://openresty.org/package/rhel/openresty.repo

# Install Openresty
echo 'Start to install openresty'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
yum -y install unzip
yum -y install openresty
yum -y install openresty-resty

ln -s /usr/local/openresty/bin/resty /usr/local/bin/resty
ln -s /usr/local/openresty/bin/openresty /usr/local/bin/openresty
ln -s /usr/local/openresty/nginx/sbin/nginx /usr/local/bin/nginx

# Verify Openresty Installation
nginx -v
resty -v
openresty -v

# Install luarock
echo 'Start to install luarock'
echo '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
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
ln -s /usr/local/openresty/luajit/bin/luarocks /usr/local/bin/luarocks

# Install luafilesystem by luarocks
luarocks install luafilesystem

# Install ngr
#wget 
