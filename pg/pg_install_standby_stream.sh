#!/bin/bash
# 测试环境:CentOS Linux release 7.6.1810 (Core) 



# 安装 PostgreSQL 10 备库(Streaming Replication流复制方式)
# https://www.postgresql.org/download/linux/redhat/



# 数据目录
export PGDATA=/pg/data
# 归档目录
export PGARCHIVE=/pg/archive
# 密码
export PASSWORD=passw0rd

primary_host=10.211.55.31
primary_port=5432
primary_pgdata=$PGDATA

standby_host=10.211.55.32
standby_port=5432
standby_pgdata=$PGDATA

cat >>/etc/hosts<<EOF

$primary_host   pg01
$standby_host   pg02

EOF



# 以root用户登录
if [ $USER != "root" ];then
    echo -e "\n\e[1;31m the user must be root,and now you user is $USER,please su to root. \e[0m"
    exit
else
    echo -e "\n\e[1;36m check root ... OK! \e[0m"
fi



# 记录部分安装日志
log=/tmp/install-pg-standby-`date +%Y%m%d-%H%M%S`.log
touch $log
chmod 666 $log
echo -e "\n\e[1;33m   >>>>>>>>>>查看后台安装日志进度:$log \e[0m"
echo -e "\n\e[1;33m 安装开始 <<<<<<<<<<! `date -R` \e[0m" >> $log 2>&1



ls /usr/pgsql-10/bin/postgres > /dev/null 2>&1
if [ $? -eq 0 ];then
    echo -e "\n\e[1;36m 检查:PostgreSQL 10已安装 ... OK! \e[0m"
else 
    echo -e "\n\e[1;36m 检查:yum ... 开始下载、安装依赖包,大约5分钟,具体看当前网速!`date -R` \e[0m"
    echo -e "\n\e[1;36m 检查:yum ... 如果耗时长,请查看是否有多个 ps -ef|grep yumBackend.py 进程,请 kill -9 PID 杀掉! \e[0m"

#rpm -e pgdg-centos10-10-2.noarch.rpm
#rpm -ivh https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-x86_64/pgdg-centos10-10-2.noarch.rpm
#yum makecache
#yum list postgresql10* --showduplicates | sort -r
#yum install -y zlib zlib-devel
#yum install -y postgresql10-libs postgresql10
#yum install -y postgresql10-server

#rpm -ivh https://github.com/wanghy8166/install/raw/master/pg10/postgresql10-libs-10.7-2PGDG.rhel7.x86_64.rpm
#rpm -ivh https://github.com/wanghy8166/install/raw/master/pg10/postgresql10-10.7-2PGDG.rhel7.x86_64.rpm
#rpm -ivh https://github.com/wanghy8166/install/raw/master/pg10/postgresql10-server-10.7-2PGDG.rhel7.x86_64.rpm

time svn checkout https://github.com/wanghy8166/install/trunk/pg10
yum -y install pg10/postgresql10-*

    echo -e "\n\e[1;31m 检查:yum ... PostgreSQL 10安装操作完成!`date -R` \e[0m"
fi



mkdir -p $PGDATA
chown postgres.postgres $PGDATA
chmod 0700 $PGDATA

mkdir -p $PGARCHIVE
chown postgres.postgres $PGARCHIVE
chmod 0700 $PGARCHIVE

oldstr="Environment=PGDATA=/var/lib/pgsql/10/data/"
newstr="Environment=PGDATA=$PGDATA"
sed -i "s#$oldstr#$newstr#g" /usr/lib/systemd/system/postgresql-10.service
cat /usr/lib/systemd/system/postgresql-10.service|grep -in pgdata=

oldstr="PGDATA=/var/lib/pgsql/10/data"
newstr="PGDATA=$PGDATA"
sed -i "s#$oldstr#$newstr#g" /var/lib/pgsql/.bash_profile
cat /var/lib/pgsql/.bash_profile|grep -in pgdata=
echo export PATH=\$PATH:/usr/pgsql-10/bin>>/var/lib/pgsql/.bash_profile

su - postgres <<EOF
echo ${primary_host}:5432:replication:replication:${PASSWORD} >> ~/.pgpass
echo ${standby_host}:5432:replication:replication:${PASSWORD} >> ~/.pgpass
chmod 0600 ~/.pgpass
pg_basebackup -h ${primary_host} -p ${primary_port} -U replication -D ${standby_pgdata} -X stream -R -v -P -w 
echo
EOF

cat >>$PGDATA/recovery.conf<<EOF

# add by wxf `date +%Y%m%d-%H%M%S`
trigger_file = '$PGDATA/pg_trigger'
# PostgreSQL 时间点恢复(PITR)时查找wal record的顺序 - loop(pg_wal, restore_command, stream)
restore_command = 'cp $PGARCHIVE/%f "%p"'
recovery_target_timeline = 'latest'

EOF

systemctl enable postgresql-10
systemctl start  postgresql-10

ps -ef|grep -v grep|grep -E 'sender|receiver'
