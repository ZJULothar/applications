#!/bin/bash

. ${APP_ROOT}/toolset/setup/basic_cmd.sh

######################################################################################
# Notes:
#  To start Percona-Server 
#
#####################################################################################

BUILD_DIR="./"$(tool_get_build_dir $1)
SERVER_FILENAME=$1
TARGET_DIR=$(tool_get_first_dirname ${BUILD_DIR})
SUBBUILD_DIR="armbuild"

if [ "$(ps -aux | grep "/u01/my3306/bin/mysqld_safe" | grep -v "grep")" != "" ]; then
    echo "Percona server is running"
    exit 0
fi

###########################################################################################
# Begin to start percona server
###########################################################################################

#Run step 1: Add 'mysql' test user account and rights
$(tool_add_sudo) groupadd mysql
$(tool_add_sudo) useradd -g mysql mysql

#Run step 2: Prepare for configuration for mysql
#Backup existing conf if necessary
if [ $(tool_check_exists "/etc/my.conf") == 0 ]; then
    cur_day_str=`date +%Y-%m-%d`
    echo "Backup existing /etc/my.conf ......."
    if [ $(tool_check_exists "/etc/my.conf_${cur_day_str}") != 0 ]; then
        $(tool_add_sudo) cp /etc/my.conf /etc/my.conf_${cur_day_str}
    fi
fi

$(tool_add_sudo) cp -f ${APP_ROOT}/apps/mysql/percona_ali_test/config/my.conf /etc/my.conf

$(tool_add_sudo) mkdir -p /u01/mysql
$(tool_add_sudo) cp -fr /u01/my3306/share /u01/mysql
$(tool_add_sudo) mkdir -p /u01/my3306/tmp
$(tool_add_sudo) mkdir -p /u01/my3306/log
$(tool_add_sudo) mkdir -p /u01/my3306/run

cur_user=`whoami`
$(tool_add_sudo) chown -L -R mysql.${cur_user} /u01

#Run step 3: Initialize database
$(tool_add_sudo) /u01/my3306/scripts/mysql_install_db --basedir=/u01/my3306 \
                                     --datadir=/u01/my3306/data \
                                     --user=mysql \
                                     --defaults-file=/etc/my.conf

#Run step 4: Start mysql server
$(tool_add_sudo) /u01/my3306/bin/mysqld_safe --defaults-file=/etc/my.conf \
                            --basedir=/u01/my3306 \
                            --datadir=/u01/my3306/data &

#Run step 5: Check whether server has started successfully or not
max_retry_num=1000
cur_retry=0
has_started=0
while [[ ${cur_retry} -lt 1000 ]] ;
do
    echo "Check whether server has started yet or not ......"
    CHECK_STR=$($(tool_add_sudo) grep "ready for connection" /u01/my3306/log/alert.log)
    if [ "${CHECK_STR}" ] ; then
        let "has_started=1"
        echo "Percona Server has started successfully"
        break
    fi
    
    let "cur_retry++"
    sleep 30
done

if [ ${has_started} -eq 0 ]; then
    echo "Hmm...Please check alert.log manually to see why the server has not started yet"
fi


#Install Step 6:set root rights and create initial database
/u01/my3306/bin/mysql -uroot << EOF
SET PASSWORD=PASSWORD('123456');
UPDATE mysql.user SET password=PASSWORD('123456') WHERE user='mysql';
GRANT ALL PRIVILEGES ON *.* TO mysql@localhost IDENTIFIED BY '123456' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO mysql@"%" IDENTIFIED BY '123456' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO root@localhost IDENTIFIED BY '123456' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO root@"%" IDENTIFIED BY '123456' WITH GRANT OPTION;
create database sysbench;
EOF

echo "Pecora server build and install complete"
popd > /dev/null
