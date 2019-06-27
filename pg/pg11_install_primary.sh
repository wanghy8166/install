#!/bin/bash
# 测试环境:CentOS Linux release 7.6.1810 (Core) 



# 安装 PostgreSQL 11 主库(或仅单机)
# https://www.postgresql.org/download/linux/redhat/
# https://yum.postgresql.org/11/redhat/rhel-7-x86_64/



# 环境配置
# 数据目录
export PGDATA=/pg/data
# 归档目录
export PGARCHIVE=/pg/archive
# 密码
export PASSWORD=passw0rd
# pg_dump备份目录
export PGDUMP=/pg/pg_dump
# pg_rman备份目录
export PGRMAN=/pg/pg_rman

primary_host=172.17.10.85
primary_port=5432
primary_pgdata=$PGDATA

# 如果部署仅单机,那这个standby就不用填
standby_host=172.17.10.86
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
log=/tmp/install-pg-primary-`date +%Y%m%d-%H%M%S`.log
touch $log
chmod 666 $log
echo -e "\n\e[1;33m   >>>>>>>>>>查看后台安装日志进度:$log \e[0m"
echo -e "\n\e[1;33m 安装开始 <<<<<<<<<<! `date -R` \e[0m" >> $log 2>&1



ls /usr/pgsql-11/bin/postgres > /dev/null 2>&1
if [ $? -eq 0 ];then
    echo -e "\n\e[1;36m 检查:PostgreSQL 11已安装 ... OK! \e[0m"
else 
    echo -e "\n\e[1;36m 检查:yum ... 开始下载、安装依赖包,大约5分钟,具体看当前网速!`date -R` \e[0m"
    echo -e "\n\e[1;36m 检查:yum ... 如果耗时长,请查看是否有多个 ps -ef|grep yumBackend.py 进程,请 kill -9 PID 杀掉! \e[0m"

# 安装rpm仓库源
rpm -ivh https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
# 安装客户端
yum -y install postgresql11
# 安装服务端
yum -y install postgresql11-server
yum -y install postgresql11-contrib
yum -y install postgresql11-devel

#yum makecache
#yum list postgresql10* --showduplicates | sort -r
#yum install -y zlib zlib-devel
#yum install -y postgresql10-libs postgresql10
#yum install -y postgresql10-server

#rpm -ivh https://github.com/wanghy8166/install/raw/master/pg10/postgresql10-libs-10.7-2PGDG.rhel7.x86_64.rpm
#rpm -ivh https://github.com/wanghy8166/install/raw/master/pg10/postgresql10-10.7-2PGDG.rhel7.x86_64.rpm
#rpm -ivh https://github.com/wanghy8166/install/raw/master/pg10/postgresql10-server-10.7-2PGDG.rhel7.x86_64.rpm

# time svn checkout https://github.com/wanghy8166/install/trunk/pg11
# yum -y install pg11/postgresql11-*
# yum -y install pg11/pg_rman-*

wget https://github.com/ossc-db/pg_rman/releases/download/V1.3.8/pg_rman-1.3.8-1.pg11.rhel7.x86_64.rpm
rpm -ivh pg_rman-1.3.8-1.pg11.rhel7.x86_64.rpm

    echo -e "\n\e[1;31m 检查:yum ... PostgreSQL 11安装操作完成!`date -R` \e[0m"
fi



mkdir -p $PGDATA
chown postgres.postgres $PGDATA
chmod 0700 $PGDATA

mkdir -p $PGARCHIVE
chown postgres.postgres $PGARCHIVE
chmod 0700 $PGARCHIVE

mkdir -p $PGDUMP
chown postgres.postgres $PGDUMP
chmod 0700 $PGDUMP

mkdir -p $PGRMAN
chown postgres.postgres $PGRMAN
chmod 0700 $PGRMAN

oldstr="Environment=PGDATA=/var/lib/pgsql/11/data/"
newstr="Environment=PGDATA=$PGDATA"
sed -i "s#$oldstr#$newstr#g" /usr/lib/systemd/system/postgresql-11.service
cat /usr/lib/systemd/system/postgresql-11.service|grep -in pgdata=

oldstr="PGDATA=/var/lib/pgsql/11/data"
newstr="PGDATA=$PGDATA"
sed -i "s#$oldstr#$newstr#g" /var/lib/pgsql/.bash_profile
cat /var/lib/pgsql/.bash_profile|grep -in pgdata=
echo export PATH=\$PATH:/usr/pgsql-11/bin>>/var/lib/pgsql/.bash_profile

su - postgres <<EOF
echo ${primary_host}:5432:replication:replication:${PASSWORD} >> ~/.pgpass
echo ${standby_host}:5432:replication:replication:${PASSWORD} >> ~/.pgpass
chmod 0600 ~/.pgpass
initdb -E UTF8 --locale=C --data-checksums -D \$PGDATA >initdb-`date +%Y%m%d-%H%M%S`.log 2>&1 
EOF

sleep 3

# PostgreSQL on Linux 最佳部署手册 - 珍藏级
# https://github.com/digoal/blog/blob/master/201611/20161121_01.md

MEM1=`free -m|awk '($1 == "Mem:"){print $2}'`
MEM2=`expr $MEM1 / 4`
#echo ${MEM2}

export pgconf=$PGDATA/postgresql.conf
cat >>$pgconf<<EOF

# add by wxf `date +%Y%m%d-%H%M%S`
listen_addresses = '0.0.0.0'
max_connections = 1000
# 1/4 主机内存
shared_buffers = ${MEM2}MB
log_filename = 'postgresql-%Y-%m-%d.log'
# 单位:ms毫秒
log_min_duration_statement = 5000
wal_level = replica
wal_log_hints = on
archive_mode = on
archive_command = 'cp %p $PGARCHIVE/%f'
# 设置来自备库的并发连接的最大数目
max_wal_senders = 10
# 为备库保留的wal个数
wal_keep_segments = 256
# 防止远程程序与PG连接中断
tcp_keepalives_idle = 60  
tcp_keepalives_interval = 10  
tcp_keepalives_count = 10

EOF
#grep "^[a-z]" postgresql.conf

export pghba=$PGDATA/pg_hba.conf
cat >>$pghba<<EOF

# add by wxf `date +%Y%m%d-%H%M%S`
# 拒绝超级用户从网络登录
host    all             postgres        0.0.0.0/0               reject
host    all             all             0.0.0.0/0               md5
host    replication     replication     ${primary_host}/32         md5
host    replication     replication     ${standby_host}/32         md5

EOF

systemctl enable postgresql-11
systemctl start  postgresql-11

# 用户
su - postgres <<EOF
psql -c "CREATE user replication WITH REPLICATION PASSWORD '${PASSWORD}'"
psql -c "alter user postgres with password '${PASSWORD}'"
EOF

ps -ef|grep -v grep|grep -E 'sender|receiver'

# 异机测试登录:强制输入验证密码
# psql -h 172.17.10.85 -p 5432 -U postgres -W

# 本机登录:
# psql



# 备份:pg_dump
wget -O $PGDUMP/pg_dump.sh https://raw.githubusercontent.com/wanghy8166/install/master/pg/pg_dump.sh
oldstr="/pg/pg_dump"
newstr="$PGDUMP"
sed -i "s#$oldstr#$newstr#g" $PGDUMP/pg_dump.sh
cat $PGDUMP/pg_dump.sh|grep -in BAKBASEDIR=

oldstr="/usr/pgsql-10"
newstr="/usr/pgsql-11"
sed -i "s#$oldstr#$newstr#g" $PGDUMP/pg_dump.sh
cat $PGDUMP/pg_dump.sh|grep -in PGHOME=

mkdir -p $PGDUMP
chown -R postgres.postgres $PGDUMP
chmod 0700 $PGDUMP

grep -q pg_dump /var/spool/cron/root
if [ $? -eq 0 ];then
    echo -e "\n\e[1;36m 检查:已存在pg_dump备份任务 ... OK! \e[0m"
else
    cp /var/spool/cron/root /var/spool/cron/root-`date +%Y%m%d-%H%M%S`-3
    echo "05 18 * * * su - postgres -c '/bin/bash $PGDUMP/pg_dump.sh > $PGDUMP/pg_dump-\`date +%Y%m%d\`.log 2>&1 '" >> /var/spool/cron/root
    echo -e "\n\e[1;31m 检查:将pg_dump加入备份任务 ... 已加入! \e[0m"
fi



# 备份:pg_rman
export BACKUP_PATH=$PGRMAN
/usr/pgsql-11/bin/pg_rman init
cat >>$BACKUP_PATH/pg_rman.ini<<EOF
BACKUP_MODE = FULL
COMPRESS_DATA = true
# 单位:个数
KEEP_ARCLOG_FILES = 256
KEEP_DATA_GENERATIONS = 2
KEEP_SRVLOG_FILES = 50
WITH_SERVERLOG = true
SMOOTH_CHECKPOINT = true
FULL_BACKUP_ON_ERROR = true

EOF
echo

wget -O $PGRMAN/pg_rman.sh https://raw.githubusercontent.com/wanghy8166/install/master/pg/pg_rman.sh
oldstr="/pg/data"
newstr="$PGDATA"
sed -i "s#$oldstr#$newstr#g" $PGRMAN/pg_rman.sh
cat $PGRMAN/pg_rman.sh|grep -in PGDATA=

oldstr="/pg/pg_rman"
newstr="$PGRMAN"
sed -i "s#$oldstr#$newstr#g" $PGRMAN/pg_rman.sh
cat $PGRMAN/pg_rman.sh|grep -in BACKUP_PATH=

mkdir -p $PGRMAN
chown -R postgres.postgres $PGRMAN
chmod 0700 $PGRMAN

grep -q pg_rman /var/spool/cron/root
if [ $? -eq 0 ];then
    echo -e "\n\e[1;36m 检查:已存在pg_rman备份任务 ... OK! \e[0m"
else
    cp /var/spool/cron/root /var/spool/cron/root-`date +%Y%m%d-%H%M%S`-4
    echo "05 02 * * * su - postgres -c '/bin/bash $PGRMAN/pg_rman.sh > $PGRMAN/pg_rman-\`date +%Y%m%d\`.log 2>&1 '" >> /var/spool/cron/root
    echo -e "\n\e[1;31m 检查:将pg_rman加入备份任务 ... 已加入! \e[0m"
fi



# 工具:pgcenter,pg_top,pgstatspack,pg_statsinfo,pgbadger,,,,,,


