# MySQL8 + MGR + Keepalived 三节点部署

## 官方架构图
https://dev.mysql.com/doc/refman/8.0/en/mysql-innodb-cluster-introduction.html  
https://dev.mysql.com/doc/refman/8.0/en/group-replication-plugin-architecture.html  
https://dev.mysql.com/doc/mysql-router/8.0/en/mysql-router-general-using-deploying.html  

## 用到的软件
https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-8.0.23-linux-glibc2.12-x86_64.tar.xz  
https://cdn.mysql.com/Downloads/MySQL-Shell/mysql-shell-8.0.23-linux-glibc2.12-x86-64bit.tar.gz  
https://downloads.percona.com/downloads/percona-toolkit/3.3.0/binary/tarball/percona-toolkit-3.3.0_x86_64.tar.gz  
https://raw.githubusercontent.com/wanghy8166/nmon/master/nmon_x86_64_centos7  
根据mgr+Keepalived测试预研，不使用router即可满足要求，又可少用一个组件，所以不用router。  
3个节点，每个节点都要安装这些软件和配置，特别说明的按实际来。  

### 主机名修改
主机名按实际改    
```
cp /etc/hostname /etc/hostname-`date +%Y%m%d-%H%M%S`
echo mgr01 >/etc/hostname
hostname mgr01
cat >/etc/hosts<<EOF
127.0.0.1      localhost
172.17.10.84   mgr01 
172.17.10.85   mgr02 
172.17.10.86   mgr03 
172.17.10.93   mgrvip 
EOF
cat /etc/hosts
```
### 软件路径
下载的软件放在该路径，等待用脚本安装  
mkdir /soft  

本例中，数据文件放在该路径  
mkdir /data  

### 安装mysql
官方安装文档介绍 https://dev.mysql.com/doc/refman/8.0/en/binary-installation.html  
一键安装脚本:[install_mysql.sh](install_mysql.sh)  

### 安装mysql-shell
```
tar xvf /soft/mysql-shell-8.0.23-linux-glibc2.12-x86-64bit.tar.gz -C /data/
cd /data
ln -s mysql-shell-8.0.23-linux-glibc2.12-x86-64bit mysql-shell
export PATH=/data/mysql-shell/bin:$PATH
echo export PATH=/data/mysql-shell/bin:\$PATH >>/root/.bash_profile
```
================================================================================
### 配置集群
之前阅读过的文档 https://jeremyxu2010.github.io/2019/05/mysql-innodb-cluster%E5%AE%9E%E6%88%98/  

#### 配置本地实例，每个实例都执行
mysqlsh --uri root:heading@172.17.10.84:3306  
mysqlsh --uri root:heading@172.17.10.85:3306  
mysqlsh --uri root:heading@172.17.10.86:3306  
```
\status
\sql
GRANT BACKUP_ADMIN, CLONE_ADMIN, PERSIST_RO_VARIABLES_ADMIN, REPLICATION_APPLIER, SYSTEM_VARIABLES_ADMIN ON *.* TO 'root'@'%' WITH GRANT OPTION;
\js
dba.configureLocalInstance()
```
dba.checkInstanceConfiguration('root:heading@172.17.10.84:3306')  
dba.checkInstanceConfiguration('root:heading@172.17.10.85:3306')  
dba.checkInstanceConfiguration('root:heading@172.17.10.86:3306')  

备用检查命令
cluster.checkInstanceState('root:heading@172.17.10.84:3306')  
cluster.checkInstanceState('root:heading@172.17.10.85:3306')  
cluster.checkInstanceState('root:heading@172.17.10.86:3306')  

#### 修改3个实例的权限
chown mysql:mysql -R /data/mysql/lib  

#### 创建cluster，在其中一个实例操作，默认会成为当前主实例
```
var cluster = dba.createCluster('myCluster')
var cluster = dba.getCluster('myCluster')
```
如果这时主实例重启了，而其他实例未加入集群，则继续执行
```
dba.rebootClusterFromCompleteOutage()
```
#### 修改第2、3两个实例的server-id，不重复即可，并重启实例
```
cat /data/mysql/my.cnf|grep -i server-id 
systemctl stop mysql.server &&
systemctl start mysql.server &&
systemctl status mysql.server
```
#### 添加第2、3两个实例
```
cluster.addInstance('root:heading@172.17.10.85:3306')
cluster.addInstance('root:heading@172.17.10.86:3306')
```
到这里，mgr集群已经安装完成。

备用命令
```
cluster.removeInstance()
cluster.rejoinInstance()
```
备用查看命令
```
var cluster = dba.getCluster()
cluster.status()
cluster.describe()
cluster.rescan()
cluster.listRouters()
```
================================================================================
### sql查看集群状态
```
export MYSQL_PWD=heading
mysql -u root -h 127.0.0.1 -P 3306
select @@hostname;
SELECT * FROM performance_schema.replication_group_members;
SELECT * FROM performance_schema.replication_group_member_stats\G
select * from performance_schema.processlist\G

select * from sys.processlist; # 信息更完整
select * from sys.x$processlist; # 信息更完整
select * from PERFORMANCE_SCHEMA.PROCESSLIST;
select * from INFORMATION_SCHEMA.PROCESSLIST; # 是SHOW PROCESSLIST的来源
SHOW PROCESSLIST; # 有global mutex全局互斥锁
```
================================================================================
### MGR单主模式，如何使客户端连接到读写实例呢？
答:使用keepalived直接绑定vip到读写实例上去实现。  

单主MGR会保证只有PRIMARY节点可写,SECONDARY节点是只读,所以只需要绑定vip到PRIMARY节点即可。  
假设出现脑裂，vip在多个节点同时出现，因为只有PRIMARY节点可写，所以也不会影响一致性。  
控制点:  
```
SHOW GLOBAL VARIABLES LIKE '%read_only%';
| read_only             | ON    |
| super_read_only       | ON    |
```


### Keepalived部署
配置keepalived，需要修改vip地址、网卡接口名如eth0、mysql的root密码，3个节点配置一致。  

#### 防火墙配置
```
systemctl enable firewalld
systemctl start firewalld
systemctl status firewalld
# 为keepalived配置防火墙
# 参考 https://www.cnblogs.com/lgh344902118/p/7737129.html
firewall-cmd --remove-rich-rule='rule protocol value="vrrp" accept' --permanent
firewall-cmd --add-rich-rule='rule protocol value="vrrp" accept' --permanent
# mysql端口
firewall-cmd --zone=public --remove-port=3306/tcp --permanent
firewall-cmd --zone=public --add-port=3306/tcp --permanent
# mysql mgr同步端口
firewall-cmd --zone=public --remove-port=33061/tcp --permanent
firewall-cmd --zone=public --add-port=33061/tcp --permanent
firewall-cmd --reload
firewall-cmd --zone=public --list-ports
/sbin/iptables -L | grep vrrp
```
#### keepalived 1.3.5-19.el7
```
yum install -y keepalived
systemctl enable keepalived
systemctl start keepalived
systemctl status keepalived

mv /etc/sysconfig/keepalived /etc/sysconfig/keepalived.bak-`date +%Y%m%d-%H%M%S`
echo 'KEEPALIVED_OPTIONS="-D -d -S 0"' > /etc/sysconfig/keepalived
echo 'local0.*    /var/log/keepalived.log' >> /etc/rsyslog.conf

# 说明:在约54行如下信息的第一列结尾加入" ;local0.none "
# *.info;mail.none;authpriv.none;cron.none;local0.none      /var/log/messages
# 上述配置表示来自local0设备的所有日志信息不再记录于/var/log/messages里
# 先注释包含/var/log/messages的行
sed -i 's/.*\/var\/log\/messages/#&/' /etc/rsyslog.conf
# 再增加行
echo '*.info;mail.none;authpriv.none;cron.none;local0.none                /var/log/messages' >> /etc/rsyslog.conf
cat /etc/rsyslog.conf|grep -in /var/log/messages

systemctl restart rsyslog
systemctl restart keepalived
# tail -f /var/log/keepalived.log

# keepliaved的配置，需要修改vip地址、网卡接口名如eth0
mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak-`date +%Y%m%d-%H%M%S`
touch /etc/keepalived/keepalived.conf

# mysql检查脚本，需要修改密码
touch /etc/keepalived/check_mysql8mgr.sh
chmod +x /etc/keepalived/check_mysql8mgr.sh

systemctl restart keepalived 
# tail -f /var/log/keepalived.log
```
================================================================================
### 选举新的主实例，有2种方法
https://www.percona.com/blog/2021/01/11/mysql-group-replication-how-to-elect-the-new-primary-node/  

(1). 提高权重
在SECONDARY提高权重
```
select @@hostname, @@group_replication_member_weight;
set global group_replication_member_weight = 70;
```
在PRIMARY停组复制
```
stop group_replication;
select * from performance_schema.replication_group_members;
```
主实例已切换

(2). 指定主实例
```
show global variables like 'server_uuid';
select group_replication_set_as_primary('dd1158f0-4dae-11eb-80e0-000c29b80c43');
```
================================================================================
### 其他说明
临时导出变量:
```
pager cat > /tmp/mgr01.txt;
show variables;
exit;
```
在部署MySQL 5.7两节点主从复制时采用了脚本[install_mysql_repl.sh](install_mysql_repl.sh)  
在MySQL 8.0 MGR部署时已自动包含了上述脚本内容。  

================================================================================
### 常见问题  

#### 问题1:
FATAL: error 2059: Authentication plugin 'caching_sha2_password' cannot be loaded: /usr/lib64/mysql/plugin/caching_sha2_password.so: cannot open shared object file: No such file or directory
处理:
```
SELECT Host, User, plugin from mysql.user;
# 新版本使用caching_sha2_password默认身份验证插件，要兼容老的客户端，需修改
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'heading';
FLUSH PRIVILEGES;
```
#### 问题2:
测试时，使用sysbench过度施加压力，强行断电重启主节点，重启后报错  
2021-03-03T21:53:16.722538+08:00 0 [ERROR] [MY-011735] [Repl] Plugin group_replication reported: '[GCS] The member was unable to join the group. Local port: 33061'  
2021-03-03T21:53:19.116454+08:00 42 [ERROR] [MY-011640] [Repl] Plugin group_replication reported: 'Timeout on wait for view after joining group'  
2021-03-03T21:53:19.116544+08:00 42 [ERROR] [MY-011735] [Repl] Plugin group_replication reported: '[GCS] The member is leaving a group without being on one.'  
每个节点都只能查到自己，且是OFFLINE状态  
处理:  
```
如何知道当前节点重启前是否是主节点？
分别查询各节点日志，看最后谁是主节点。
cat /data/mysql/data/mysql-error.log|grep -in "new primary"

知道主后，先启动主节点，再启动SECONDARY节点
由于group_replication_bootstrap_group参数 我们在配置文件中设为了OFF，所以需要手动打开设为ON.

show variables like 'group_replication_bootstrap_group';
set global group_replication_bootstrap_group=on;
select * from performance_schema.replication_group_members ;
start group_replication;
select * from performance_schema.replication_group_members ;
# 开启组复制之后记得将group_replication_bootstrap_group再设为off
set global group_replication_bootstrap_group=off;

再启动SECONDARY节点
start group_replication;

关机顺序:
先关SECONDARY节点，最后关PRIMARY节点。
如果先关PRIMARY节点，会产生新的选主。
```


#### 问题3：
2021-03-04T12:55:28.651183+08:00 630 [Warning] [MY-010956] [Server] Invalid replication timestamps: original commit timestamp is more recent than the immediate commit timestamp. This may be an issue if delayed replication is active. Make sure that servers have their clocks set to the correct time. No further message will be emitted until after timestamps become valid again.  
2021-03-04T12:55:28.664609+08:00 630 [Warning] [MY-010957] [Server] The replication timestamps have returned to normal values.  
处理：  
```
(1)忽略警告
(2)配置不让出现
set global log_error_suppression_list='MY-010956,MY-010957';
show variables like 'log_error%';
```
#### 问题4：
mysql-shell学习参考  
https://www.percona.com/blog/2021/02/25/mysql-monitoring-and-reporting-using-the-mysql-shell/  
