FROM openresty/openresty:centos-lfs
MAINTAINER Jacobs jacobs.lei@163.com
WORKDIR /opt
ADD wk/ ./wk
RUN CD wk && make install
EXPOSE 80