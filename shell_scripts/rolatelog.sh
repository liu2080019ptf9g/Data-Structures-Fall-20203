#!/bin/sh  
# Auto cut nginx log script by dayly
# By Kevin.XU @ 2016/9/6

#crontab -e 
#0 0 * * * /bin/bash /usr/local/openresty/shell_scripts/rolatelog.sh /usr/local/openresty/nginx/logs /usr/local/openresty/nginx/logs /usr/local/openresty/nginx/logs/nginx.pid

LOGS_PATH=${1}
LOGS_BACKUP_PATH=${2}
PID_FILE_PATH=${3}
TODAY=$(date -d 'yesterday' +%Y-%m-%d-%H)

#rename log 
mv ${LOGS_PATH}/error.log ${LOGS_BACKUP_PATH}/error_${TODAY}.log
mv ${LOGS_PATH}/access.log ${LOGS_BACKUP_PATH}/access_${TODAY}.log  

#regenerate log file
kill -USR1 $(cat ${PID_FILE_PATH})

exit $?
