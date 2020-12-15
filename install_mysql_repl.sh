# install_mysql_repl.sh
复制方式：
1、普通的master-slave异步复制(Async replication)
2、半同步复制(Semi-sync replication)
3、Group Replication(要求至少3个节点)

按协议：
1、非GTID模式
2、GTID模式，通过GTID信息来决定replication位点信息，auto_position=1，自动处理位点信息

简述 MySQL 5.7 重大改进:
1、基于组提交事务，多线程并发复制，解决单线程复制的延迟问题
2、无数据丢失、更快的双工模式半同步复制

MySQL 5.7 Replication新特性
http://mp.weixin.qq.com/s?__biz=MjM5NzAzMTY4NQ==&mid=2653928733&idx=1&sn=3988f37f77a32bd19bc7ec94889168cb&scene=0#wechat_redirect

综合考虑，选择：基于GTID的半同步复制、多线程复制

https://dev.mysql.com/doc/refman/5.6/en/replication-options-reference.html
https://dev.mysql.com/doc/refman/5.6/en/binary-log.html

####################################################################################################
soft_path="/soft" # mysql制品的存放路径
data_path="/home/data" # mysql的安装路径
mysql_version="mysql-5.7.21-linux-glibc2.12-x86_64" # Linux - Generic 压缩包
pt_version="percona-toolkit-3.0.8" # Linux - Generic 压缩包
mysql_password="heading"

local_ip=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
echo "本机ip:"${local_ip}

touch /etc/my.cnf.d/replication.cnf
cat  >/etc/my.cnf.d/replication.cnf<<EOF
[mysqld]
# 开启gtid
gtid_mode                      = on
enforce_gtid_consistency       = 1
log_slave_updates
# replication #
server-id                      = 1 # 主库改为1;从库改为2;
auto_increment_increment       = 2 
auto_increment_offset          = 1 # 主库改为1;从库改为2;
relay_log                      = ${data_path}/mysql/data/relay-bin
master_info_repository         = TABLE
relay_log_info_repository      = TABLE
binlog_format                  = row
relay_log_recovery             = 1
relay_log_purge                = 1
# read_only,主库为0,从库为1
read_only                      = 1
slave_net_timeout              = 60
# sync_relay_log值为1,表示mysql将每1个sync_relay_log事件写入到relay log中继日志(形如relay-bin.000135),
# 这是最安全的,因为如果发生掉电或崩溃,最多丢失1个事件,但这也是同步最慢的选择.
# 恢复默认值10000,加快从库同步速度,降低安全性.
sync_master_info               = 10000
sync_relay_log                 = 10000
sync_relay_log_info            = 10000
report_host                    = ${local_ip}
report_port                    = 3306
# 校验
binlog_checksum=CRC32
master_verify_checksum=1
slave_sql_verify_checksum=1
binlog_rows_query_log_events=1
# 半同步 #
plugin-load                    = "rpl_semi_sync_master=semisync_master.so;rpl_semi_sync_slave=semisync_slave.so"
rpl-semi-sync-master-enabled   = 1
rpl-semi-sync-slave-enabled    = 1
# 5.7.5 Multi-threaded Slave 多线程复制
slave-parallel-type            = LOGICAL_CLOCK
slave-parallel-workers         = 16
slave_preserve_commit_order    = 1
EOF
service mysql.server restart
####################################################################################################
主库建立复制帐号
mysql -h127.0.0.1    -uroot -pheading
CREATE USER 'repl'@'%' IDENTIFIED BY 'repl';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
主库观察
show master status\G
show processlist\G
SHOW SLAVE HOSTS;
查看相关参数
show variables like '%gtid%';
show variables like '%server_id%';
show variables like '%auto_increment%';
show variables like '%relay_log%';
show variables like '%master_info%';
show variables like '%sync%';
flush logs;

从库配置同步
stop slave;
reset slave;
change master to master_host='172.17.10.92',master_user='repl',master_password='repl',master_port=3306,master_auto_position=1;
# 告诉从库哪些Gtid事务已经执行过了,从xtrabackup_binlog_info文件获取
show variables like 'gtid_purged';
reset master;
SET @@GLOBAL.GTID_PURGED= 'e89c5c8f-c5b9-11ea-beb8-0050569a68f7:1-4972823';
show warnings;
start slave;
show slave status\G

从库提示
[ERROR] Slave I/O: error connecting to master 'repl@172.17.10.92:3306' - retry-time: 60  retries: 2, Error_code: 2003
原因：主库防火墙问题
处理：/sbin/iptables -I INPUT -p tcp --dport 3306 -j ACCEPT

从库提示
[ERROR] Slave I/O: Fatal error: The slave I/O thread stops because master and slave have equal MySQL server ids; these ids must be different for replication to work (or the --replicate-same-server-id option must be used on slave but this does not always make sense; please check the manual before using it). Error_code: 1593
原因：server_id相同
处理：查看并修改my.cnf，使主从不同
show variables like '%server_id%';

从库提示
[ERROR] Slave I/O for channel '': Fatal error: The slave I/O thread stops because master and slave have equal MySQL server UUIDs; these UUIDs must be different for replication to work. Error_code: 1593
原因：server_uuid相同
处理：删除auto.cnf，重启从库
show variables like '%server_uuid%';

从库提示
[ERROR] Slave SQL: Slave failed to initialize relay log info structure from the repository, Error_code: 1872
原因：relay_log被占用
处理：重新配置主从复制
stop slave;
reset slave;
change master to master_host='172.17.10.92',master_user='repl',master_password='repl',master_port=3306,master_auto_position=1;
show warnings;
start slave;
show slave status\G

主库操作，从库同步验证
主库操作:
use mysql;
create table sample (c int);
insert into sample (c) values (1);
select * from sample;
# drop table sample;

从库同步验证:
use mysql;
select * from sample;
####################################################################################################
半同步复制
https://www.cnblogs.com/ivictor/p/5735580.html
https://www.wenji8.com/p/105GRDe.html

主:
INSTALL PLUGIN rpl_semi_sync_master SONAME 'semisync_master.so';
SELECT PLUGIN_NAME, PLUGIN_STATUS FROM INFORMATION_SCHEMA.PLUGINS  WHERE PLUGIN_NAME LIKE '%semi%';
SET GLOBAL rpl_semi_sync_master_enabled = 1;
show variables like '%semi%';
show status like '%semi%';

从:
INSTALL PLUGIN rpl_semi_sync_slave SONAME 'semisync_slave.so';
SELECT PLUGIN_NAME, PLUGIN_STATUS FROM INFORMATION_SCHEMA.PLUGINS  WHERE PLUGIN_NAME LIKE '%semi%';
SET GLOBAL rpl_semi_sync_slave_enabled = 1;
STOP  SLAVE IO_THREAD;
START SLAVE IO_THREAD;
show variables like '%semi%';
show status like '%semi%';
####################################################################################################
Multi-threaded Slave 多线程复制
https://yq.aliyun.com/articles/59259

# Multi-threaded Slave 多线程复制
slave-parallel-type=LOGICAL_CLOCK
slave-parallel-workers=16
master_info_repository=TABLE
relay_log_info_repository=TABLE
relay_log_recovery=ON
####################################################################################################
