#!/usr/bin/env bash

current_path=`pwd`

ps -fe|grep nginx |grep -v grep
if [ $? -ne 0 ]
then
  sudo nginx  -p `pwd` -t -c conf_sample/nginx_example.conf
  sudo nginx  -p `pwd` -c conf_sample/nginx_example.conf
  echo "nginx start"
else
  sudo nginx  -p `pwd` -t -c conf_sample/nginx_example.conf
  sudo nginx  -p `pwd` -s reload -c conf_sample/nginx_example.conf
  echo "nginx reload"
fi
echo -e "===========================================\n\n"
tail -f $current_path/logs/error.log