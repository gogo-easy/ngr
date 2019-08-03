#!/usr/bin/env bash

current_path=`pwd`

sudo nginx -p `pwd` -t -c conf_sample/nginx_example.conf
sudo nginx -p `pwd` -s quit -c conf_sample/nginx_example.conf

echo "nginx stop"
echo -e "===========================================\n\n"
tail -f $current_path/logs/error.log
tail -f $current_path/logs/access.log