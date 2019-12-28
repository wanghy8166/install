# Oracle/MySQL数据库审计日志

# Oracle数据库审计日志
https://docs.oracle.com/cd/E11882_01/server.112/e40402/initparams017.htm#REFRN10006

## 审计日志
始终打开,记录sysdba登入信息等,存放在*.aud文件
ls /opt/app/oracle/admin/orcl/adump/*.aud
审计日志-测试
connect / as sysdba
rman target /

## 审计日志表 与 审计os日志 (2选1)
## 审计日志表 (建议)
记录普通用户登入、登出信息等,存放在表中
alter system set AUDIT_TRAIL=db, extended scope=spfile;
重启实例生效
select * from SYS.AUD$;
注意:审计日志表打开后，会占用更多的表空间，应加强表空间监控。

## 审计os日志
记录普通用户登入、登出信息等,存放在*.aud文件
alter system set AUDIT_TRAIL=os scope=spfile;
重启实例生效
ls /opt/app/oracle/admin/orcl/adump/*.aud

## 监听日志
记录普通用户登入信息
```
tail -f /opt/app/oracle/diag/tnslsnr/`hostname`/listener/alert/log.xml
tail -f /opt/app/oracle/diag/tnslsnr/`hostname`/listener/trace/listener.log
```
监听日志-测试
lsnrctl status 
connect sysbench/123456@172.17.10.94:1521/orcl

## alert日志
记录oracle实例告警信息
tail -f /opt/app/oracle/diag/rdbms/orcl/orcl/alert/log.xml
tail -f /opt/app/oracle/diag/rdbms/orcl/orcl/trace/alert_orcl.log
alert日志-测试
alter system switch logfile;

# MySQL数据库审计日志
https://mariadb.com/kb/en/mariadb-audit-plugin/

从MariaDB的 https://downloads.mariadb.com/MariaDB/mariadb-10.4.11/yum/centos/7/x86_64/rpms/MariaDB-server-10.4.11-1.el7.centos.x86_64.rpm 包中提取server_audit.so插件实现

## 查看插件目录
SHOW VARIABLES LIKE 'plugin_dir';

## 先安装插件，再做my.cnf配置；顺序颠倒则无法启动
cp /soft/server_audit.so /db/data/mysql/lib/plugin/server_audit.so
chmod +rx /db/data/mysql/lib/plugin/server_audit.so

INSTALL PLUGIN server_audit SONAME 'server_audit.so';

## 配置、防止卸载、排除
```
[mysqld]
server_audit_logging=ON
server_audit_events=connect,query,table
server_audit=FORCE_PLUS_PERMANENT
server_audit_incl_users=root
# 包含和排除只能选一
# server_audit_excl_users=valerianus,rocky
```
## 重启服务
service mysql.server stop
service mysql.server start

## 查看配置
SHOW GLOBAL VARIABLES like '%audit%';
SHOW GLOBAL VARIABLES like '%audit%'\G
show VARIABLES like '%audit%';
