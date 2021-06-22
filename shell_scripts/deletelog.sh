#!/bin/sh  
# Delete nginx log by dayly
# By Kevin.XU @ 2016/9/6

#crontab -e 
#0 0 * * * /bin/bash /usr/local/openresty/shell_scripts/deletelog.sh /usr/local/openresty/nginx/logs access_ 1
#0 0 * * * /bin/bash /usr/local/openresty/shell_scripts/deletelog.sh /usr/local/openresty/nginx/logs error_ 1


log_path=${1}
log_file_pattern=${2}
day_num=${3}
find ${log_path}/ -mtime ${day_num} -name ${log_file_pattern}"*" -exec rm -rf {} \;
find ${log_path}/ -daystart -mtime ${day_num} -name ${log_file_pattern}"*" -exec rm -rf {} \;

exit $?
