#version_1.0
#!/bin/bash
source /etc/profile
ENV="xxx"
app_name=$2

function help() {
  echo "Usage: $0 start|reload|stop|restart"
}

#function port_check(){
#    status=`curl -o /dev/null -I  -s -w '%{http_code}' http://localhost:80`
#    if [[ $status == 200 || $status == 302 ]];then
#        echo "port:80 ok"
#        echo "SUCCESS"
#        exit 0
#    else
#        echo "port:80 check error"
#        exit 1
#    fi
#}

function start(){
    ngr start
    if [ $? != 0 ];then
        echo "ngr start error"
    else
        echo "ngr started"
        echo "SUCCESS"
        exit 0
    fi
}

function restart(){
    ngr restart
    if [ $? != 0 ];then
        echo "ngr restart error"
    else
        echo "ngr restarted"
        echo "SUCCESS"
        exit 0
    fi
}

function reload(){
    make install-gateway profile=$ENV app_name=$app_name
    if [ $? != 0 ];then
        echo "ngr install error"
    else
        echo "ngr installed"

        ngr reload
        if [ $? != 0 ];then
            echo "ngr reload error"
        else
            echo "ngr reloaded"
            echo "SUCCESS"
            exit 0
        fi
    fi
}

function stop(){
    ngr stop
    if [ $? != 0 ];then
       echo "ngr stop error"
    else
       echo "ngr stoped"
       echo "SUCCESS"
       exit 0

    fi
}

#输入提示
if [ "$1" == "" ]; then
  help
elif [ "$1" == "stop" ]; then
  stop
elif [ "$1" == "start" ]; then
  start
elif [ "$1" == "restart" ]; then
  restart
elif [ "$1" == "reload" ]; then
  reload
else
  help
fi