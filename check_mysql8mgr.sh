#!/bin/bash
# vi check_mysql8mgr.sh
# 如果当前主机名 = sql中取到的主库的主机名，则绑定vip。
host1=`hostname`
echo $host1
host2=`export MYSQL_PWD=heading;/data/mysql/bin/mysql -h127.0.0.1 -uroot -e "SELECT MEMBER_HOST FROM performance_schema.replication_group_members where MEMBER_ROLE='PRIMARY';"|awk 'NR==2{print}' `
echo $host2

if [ $host1 == $host2 ] ;then
  exit 0
else
  exit 1
fi
