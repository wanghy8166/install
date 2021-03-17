# PostgreSQL + Patroni + etcd 三节点部署  

## 架构图  
https://www.cybertec-postgresql.com/en/patroni-setting-up-a-highly-available-postgresql-cluster/  
https://www.pgcon.org/2019/schedule/attachments/515_Patroni-training.pdf 第20页  

## 用到的软件
https://github.com/etcd-io/etcd/releases/download/v3.4.15/etcd-v3.4.15-linux-amd64.tar  
PostgreSQL 13.2  
patroni 2.0.2 (支持pg9.3 to 13)  
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
172.17.10.87   pgvip 
EOF
cat /etc/hosts
```
### 软件路径
下载的软件放在该路径，等待用脚本安装  
`mkdir /soft`  

本例中，数据文件放在该路径  
`mkdir /data`  

================================================================================
### etcd部署
#### 防火墙配置
```
firewall-cmd --zone=public --add-port=2379/tcp --permanent  
firewall-cmd --zone=public --add-port=2380/tcp --permanent  
firewall-cmd --reload  
firewall-cmd --zone=public --list-ports  
```
#### 软件解压
```
tar xvf /soft/etcd-v3.4.15-linux-amd64.tar -C /data/
cd /data
ln -s etcd-v3.4.15-linux-amd64 etcd
mkdir -p etcd/logs
export PATH=/data/etcd:$PATH
echo export PATH=/data/etcd:\$PATH >>/root/.bash_profile
etcd --version
etcdctl version
```
#### etcd启动脚本etcd.sh
参考 https://etcd.io/docs/v3.4.0/demo/ 页面  
#### etcd服务脚本etcd.service
参考 http://play.etcd.io/install 中 systemd 页面  
节点1  
vi /data/etcd/etcd.sh,各节点不一样  
chmod +x /data/etcd/etcd.sh  

部署 etcd.service,各节点一样  

节点2...  
节点3...  

查看日志  
```
tail -f /data/etcd/logs/etcd-`date +%Y-%m-%d`.log  
```
#### etcd状态检查
```
cat >>/root/.bash_profile<<EOF
export ETCDCTL_API=3
export HOST_1=172.17.10.84
export HOST_2=172.17.10.85
export HOST_3=172.17.10.86
export ENDPOINTS=\$HOST_1:2379,\$HOST_2:2379,\$HOST_3:2379
EOF
cat /root/.bash_profile

etcdctl --write-out=table --endpoints=$ENDPOINTS member list  
etcdctl --write-out=table --endpoints=$ENDPOINTS endpoint status  
etcdctl --write-out=table --endpoints=$ENDPOINTS endpoint health  
```
备用命令  
```
curl 172.17.10.86:2379/version | python -m json.tool  
curl 172.17.10.86:2379/v2/keys/ | python -m json.tool  
curl 172.17.10.86:2379/v2/keys/service | python -m json.tool  
curl 172.17.10.86:2379/v2/keys/service/pg-cluster | python -m json.tool  
```
#### 强制删除etcd根目录service，重新部署时使用，慎重!!!  
https://etcd.io/docs/v2/api/#deleting-a-directory  
~~curl 172.17.10.86:2379/v2/keys/service?recursive=true -XDELETE~~  

#### etcd-browser，网页客户端，按需部署  
源 https://github.com/henszey/etcd-browser  
源对应的docker镜像 docker pull buddho/etcd-browser  
镜像已传到自有仓库  
```
docker rm -f etcd-browser
docker run -d \
  --name etcd-browser \
  -v /etc/timezone:/etc/timezone \
  -v /etc/localtime:/etc/localtime \
  --env ETCD_HOST=172.17.10.84 \
  --env ETCD_PORT=2379 \
  -p 8000:8000 \
  --restart=unless-stopped \
  registry.cn-hangzhou.aliyuncs.com/hd2020/ka:etcd-browser
```
http://172.17.10.83:8000/  

================================================================================
### pg部署  
#### 防火墙配置  
```
firewall-cmd --zone=public --add-port=5432/tcp --permanent  
firewall-cmd --reload  
```
#### pg下载准备  
```
# https://www.postgresql.org/download/linux/redhat/  
# yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm  
rpm -qa|grep -i pgdg  
yum remove -y pgdg-redhat-repo-42.0-14.noarch  
yum install -y https://mirrors.aliyun.com/postgresql/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm  
```
将源由  
download.postgresql.org/pub  
修改为  
mirrors.aliyun.com/postgresql  
修改方法  
```
oldstr='download.postgresql.org\/pub'  
newstr='mirrors.aliyun.com\/postgresql'  
sed -i "s#\$oldstr#\$newstr#g" /etc/yum.repos.d/pgdg-redhat-all.repo  
sed -i "s#$oldstr#$newstr#g" /etc/yum.repos.d/pgdg-redhat-all.repo  
```
`yum makecache`  

#### 安装pg软件  
```
yum list postgresql13-server* --showduplicates | sort -r  
yum install -y postgresql13-server  
```
pg装好软件即可，不需要手工初始化，patroni启动时会自动做初始化。  

#### pg归档目录创建  
```
export PGARCHIVE=/data/pgarchive  
mkdir -p $PGARCHIVE  
chown postgres.postgres $PGARCHIVE  
chmod 0700 $PGARCHIVE  
```
#### pg数据目录创建  
```
export PGDATA=/data/pgdata  
echo $PGDATA  
mkdir -p $PGDATA  
chown postgres:postgres -R $PGDATA  
chmod 0700 $PGDATA  
```
#### 环境修改
```
oldstr="Environment=PGDATA=/var/lib/pgsql/13/data/"  
newstr="Environment=PGDATA=$PGDATA"  
sed -i "s#$oldstr#$newstr#g" /usr/lib/systemd/system/postgresql-13.service  
cat /usr/lib/systemd/system/postgresql-13.service|grep -in pgdata=  
```
```
oldstr="PGDATA=/var/lib/pgsql/13/data"  
newstr="PGDATA=$PGDATA"  
sed -i "s#$oldstr#$newstr#g" /var/lib/pgsql/.bash_profile  
cat /var/lib/pgsql/.bash_profile|grep -in pgdata=  
```
```
echo export PATH=\$PATH:/usr/pgsql-13/bin>>/var/lib/pgsql/.bash_profile  
```
查看日志  
`tail -f /data/pgdata/log/postgresql-*.log`  

#### 如果要删除所有数据，重新部署时使用  
~~systemctl stop  patroni~~  
~~/usr/pgsql-13/bin/pg_ctl -D /data/pgdata -l logfile stop~~  
~~ps -ef|grep -i pat~~  
~~ps -ef|grep -i post~~  
~~rm /data/pgdata/* -rf~~  

================================================================================
### 安装patroni  
`sh install_patroni.sh`  

#### 防火墙配置  
```
firewall-cmd --zone=public --add-port=8008/tcp --permanent  
firewall-cmd --reload  
```

#### patroni相关目录创建  
```
mkdir -p /data/patroni/logs  
chown postgres:postgres -R /data/patroni  
```
#### 增加vip脚本  
`chmod +x /data/patroni/loadvip.sh`  

#### 授权postgres免密sudo执行
```
chmod +w /etc/sudoers  
echo "postgres        ALL=(ALL)       NOPASSWD: ALL" >>/etc/sudoers  
chmod -w /etc/sudoers  
```

#### patroni服务脚本  
节点1  
vi /data/patroni/pg.yml,各节点不一样  
部署 patroni.service,各节点一样  

节点2...  
节点3...  

#### 启动第1个patroni服务，作为主节点/读写节点  
`systemctl start patroni`  
再启动其他节点的patroni服务  



#### 查看集群状态  
```
cd /data/patroni/  
patronictl -c pg.yml list  
```
#### 重新加载patroni配置  
`patronictl -c pg.yml reload pg-cluster`  
#### 重启pg集群  
`patronictl -c pg.yml restart pg-cluster`  
#### 重启pg1节点  
`patronictl -c pg.yml restart pg-cluster pg1`  
#### 重新初始化pg2节点  
`patronictl -c pg.yml reinit pg-cluster pg2`  
#### 手动切换Leader，将Leader从pg3切换到pg2。  
`patronictl -c pg.yml switchover --master pg3 --candidate pg2`  

注意，重启节点时会有提示:  
Restart if the PostgreSQL version is less than provided (e.g. 9.5.2)  []:   
此处不填，直接回车。  

#### 修改集群中实例的参数  
```
cd /data/patroni/  
# 示例
patronictl -c pg.yml edit-config -p 'max_connections=2000'  
patronictl -c pg.yml edit-config -p 'tcp_keepalives_idle=60'  
patronictl -c pg.yml show-config  
```
#### pg参数
https://postgresqlco.nf/doc/zh/param/tcp_keepalives_idle/  

`psql -h mgr01 -p 5432 -U postgres -W`  
##### 查看参数    
`select name,setting,unit,source from pg_settings where name like '%max_connections%';`  
##### 查询数据库启动时间  
`select pg_postmaster_start_time();`  
##### 查询数据库启动时长  
`select current_timestamp-pg_postmaster_start_time() as uptime;`  

#### 查看Patroni节点状态  
```
yum install -y jq  
curl -s http://172.17.10.84:8008/cluster | jq  
curl -s http://172.17.10.85:8008/cluster | jq  
curl -s http://172.17.10.86:8008/cluster | jq  

curl -s http://172.17.10.84:8008/patroni | jq  
curl -s http://172.17.10.85:8008/patroni | jq  
curl -s http://172.17.10.86:8008/patroni | jq  
```

================================================================================
### FAQ:
#### 1、如何确认备库是只读的？  
查看数据库日志:  
```
cat /data/pgdata/log/postgresql-2021-03-16.log |grep -i "database system is ready"  
```
2021-03-16 23:33:59.796 CST [30244]: user=,db=,app=,client= LOG:  database system is ready to accept read only connections  

在数据库中新建表测试:  
```
postgres=# create table sbtest as select version();  
```
ERROR:  cannot execute CREATE TABLE AS in a read-only transaction  

#### 2、修改实例参数，是只在主节点修改，还是在每个节点都修改？  
找一个修改后可以立即生效的参数做测试  
http://www.postgres.cn/docs/9.3.4/view-pg-settings.html  
竖排显示 
```
\x  
select name from pg_settings where pending_restart='f' and context='user';  
patronictl -c pg.yml edit-config -p 'tcp_keepalives_idle=120'  
```
```
tail -f /data/patroni/logs/patroni.log  
```
2021-03-17 13:48:38,558 INFO: Changed tcp_keepalives_idle from 60 to 120  
2021-03-17 13:48:38,565 INFO: Reloading PostgreSQL configuration.  
```
tail -f /data/pgdata/log/postgresql-2021-03-17.log  
```
2021-03-17 13:48:38.573 CST [22022]: user=,db=,app=,client= LOG:  received SIGHUP, reloading configuration files  
2021-03-17 13:48:38.574 CST [22022]: user=,db=,app=,client= LOG:  parameter "tcp_keepalives_idle" changed to "120"  
```
cat /data/pgdata/postgresql.conf|grep -i tcp_keepalives_idle  
```
tcp_keepalives_idle = '120'

```
psql -h mgr03 -p 5432 -U postgres -W
postgres=# show tcp_keepalives_idle ;
```
 120  

通过查看以上日志和配置文件，在任一节点操作patronictl，3个节点都自动完成了修改并生效。  
之后，记得将参数还原  
```
patronictl -c pg.yml edit-config -p 'tcp_keepalives_idle=60'  
```
但是，我这里测试，发现改1次成功，改第2次就都不动了，有待继续研究。  



#### 3、开关机顺序。  
关机：先关备，最后关主！！！  
     若要先关主，建议先把该主切换成备，再关这个备！！！  
```
systemctl stop patroni  
```
开机：先开主，再开其他！！！  
```
systemctl start patroni  
```
说明:  
不能用systemctl stop postgresql-13关pg实例，因为不是用systemctl启动的；  
可以用/usr/pgsql-13/bin/pg_ctl -D /data/pgdata -l logfile stop关pg实例，但马上会被patroni服务拉起来；  
所以，要关pg实例，切换成备后，用systemctl stop patroni关。  

#### 4、patroni重启影响什么？  
patronictl -c pg.yml restart pg-cluster  
平稳运行的系统，利用patronictl重启pg集群，维持原样，不发生主备切换。  
patronictl -c pg.yml restart pg-cluster pg2  
平稳运行的系统，利用patronictl重启读写节点pg2，维持原样，不发生主备切换。  

================================================================================
### 参考链接:  
https://zhuanlan.zhihu.com/p/260958352  
https://postgres.fun/20200529182600.html  
https://postgres.docs.pivotal.io/12-5/bp-patroni-setup.html  
https://habr.com/en/post/527370/  
https://scalegrid.io/blog/managing-high-availability-in-postgresql-part-3/  
