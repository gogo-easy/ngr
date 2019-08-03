#version_1.0
#!/bin/bash
source /etc/profile
ENV="xxx"

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
    ngrAdmin start
    if [ $? != 0 ];then
        echo "ngrAdmin start error"
    else
        echo "ngrAdmin started"
        echo "SUCCESS"
        exit 0
    fi
}

function restart(){
    ngrAdmin restart
    if [ $? != 0 ];then
        echo "ngrAdmin restart error"
    else
        echo "ngrAdmin restarted"
        echo "SUCCESS"
        exit 0
    fi
}

function reload(){
    make install-config profile=$ENV
    if [ $? != 0 ];then
        echo "ngrAdmin install error"
    else
        echo "ngrAdmin installed"

        ngrAdmin reload
        if [ $? != 0 ];then
            echo "ngrAdmin reload error"
        else
            echo "ngrAdmin reloaded"
            echo "SUCCESS"
            exit 0
        fi
    fi
}

function stop(){
    ngrAdmin stop
    if [ $? != 0 ];then
       echo "ngrAdmin stop error"
    else
       echo "ngrAdmin stoped"
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