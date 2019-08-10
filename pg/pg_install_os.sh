#!/bin/bash
# 测试环境:CentOS Linux release 7.6.1810 (Core) 



# OS操作系统环境配置
# 依赖包 
yum install -y git wget rdate unzip net-tools deltarpm vim tree svn yum-utils 



# 以root用户登录
if [ $USER != "root" ];then
    echo -e "\n\e[1;31m the user must be root,and now you user is $USER,please su to root. \e[0m"
    exit
else
    echo -e "\n\e[1;36m check root ... OK! \e[0m"
fi



# 记录部分安装日志
log=/tmp/install-os-`date +%Y%m%d-%H%M%S`.log
touch $log
chmod 666 $log
echo -e "\n\e[1;33m   >>>>>>>>>>查看后台安装日志进度:$log \e[0m"
echo -e "\n\e[1;33m 安装开始 <<<<<<<<<<! `date -R` \e[0m" >> $log 2>&1



# 关闭SELINUX
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0



# 开放PostgreSQL 5432端口
rpm -q centos-release-6 > /dev/null 2>&1
if [ $? -eq 0 ];then
iptables -I INPUT -p tcp --dport 5432 -j ACCEPT
service iptables save
iptables -nvL
# service iptables status
fi
rpm -q centos-release-7 > /dev/null 2>&1
if [ $? -eq 0 ];then
firewall-cmd --zone=public --add-port=5432/tcp --permanent
firewall-cmd --permanent --zone=public --add-port=9999/tcp --add-port=9898/tcp --add-port=9000/tcp  --add-port=9694/tcp
firewall-cmd --permanent --zone=public --add-port=9999/udp --add-port=9898/udp --add-port=9000/udp  --add-port=9694/udp
firewall-cmd --reload
firewall-cmd --list-all
# systemctl status firewalld
# firewall-cmd --state 
# firewall-cmd --list-services
# firewall-cmd --zone=public --list-ports
fi



# 主机名是否有小数点
# Shell脚本8种字符串截取方法总结 http://www.jb51.net/article/56563.htm 
# 2. ## 号截取，删除左边字符，保留右边字符。
# 4. %% 号截取，删除右边字符，保留左边字符
rpm -q centos-release-6 > /dev/null 2>&1
if [ $? -eq 0 ];then
var0=$(cat /etc/sysconfig/network|grep -i HOSTNAME)
var1=${var0##*=}
var2=${var1%%.*}
if [ $var1 = $var2 ];then
    echo -e "\n\e[1;36m 检查:hostname ...... 正常! \e[0m"
else
    echo -e "\n\e[1;31m 检查:hostname ...... 不正常! \e[0m"
    exit
fi
# cp /etc/sysconfig/network /etc/sysconfig/network-`date +%Y%m%d-%H%M%S`
# echo NETWORKING=yes >/etc/sysconfig/network
# echo HOSTNAME=pg01 >>/etc/sysconfig/network
fi

rpm -q centos-release-7 > /dev/null 2>&1
if [ $? -eq 0 ];then
var1=$(cat /etc/hostname)
var2=${var1%%.*}
if [ $var1 = $var2 ];then
    echo -e "\n\e[1;36m 检查:hostname ...... 正常! \e[0m"
else
    echo -e "\n\e[1;31m 检查:hostname ...... 不正常! \e[0m"
    exit
fi
# cp /etc/hostname /etc/hostname-`date +%Y%m%d-%H%M%S`
# echo pg02 >/etc/hostname
# echo pg01 >/etc/hostname
fi



# 判断是否可以上网
ping -c 4 www.baidu.com > /dev/null 2>&1
if [ $? -eq 0 ];then
	echo -e "\n\e[1;36m 检查:上公网 ... OK! \e[0m"
else
    echo -e "\n\e[1;31m 检查:上公网 ... 很遗憾!您不能上公网,请修改IP地址、网关、DNS配置! \e[0m"
    echo -e "\n\e[1;31m 检查:cat /etc/sysconfig/network-scripts/ifcfg- \e[0m"
    echo -e "\n\e[1;31m 检查:cat /etc/resolv.conf \e[0m"
    echo -e "\n\e[1;31m 检查:service iptables status \e[0m"
	exit
fi



# 更改时区、时间
    mv /etc/localtime /etc/localtime-`date +%Y%m%d-%H%M%S`
    cp -i /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo -e "\n\e[1;31m 检查:时区 ... 已修改为上海! \e[0m"

touch /var/spool/cron/root
grep -q "rdate" /var/spool/cron/root
if [ $? -eq 0 ];then
	echo -e "\n\e[1;36m 检查:时间同步已加入crontab ... OK! \e[0m"
else
	cp -i /var/spool/cron/root /var/spool/cron/root-`date +%Y%m%d-%H%M%S`-1
    echo "08 23 * * * /usr/bin/rdate -s time.nist.gov && /sbin/hwclock --systohc" >> /var/spool/cron/root
    echo -e "\n\e[1;31m 检查:时间同步 ... 配置已加入crontab! \e[0m"
fi

/usr/bin/rdate -s time.nist.gov && /sbin/hwclock --systohc    
echo -e "\n\e[1;31m 检查:时间同步 ... 已执行同步!`date -R` \e[0m"



# 更改yum配置
rm /var/cache/yum/* -rf
rpm -q centos-release-7 > /dev/null 2>&1
if [ $? -eq 0 ];then
ls /etc/yum.repos.d/Centos-7.repo > /dev/null 2>&1
if [ $? -eq 0 ];then
    echo -e "\n\e[1;36m 检查:yum ... OK! \e[0m"
else 
    echo -e "\n\e[1;36m 检查:yum ... 开始下载、安装依赖包,大约5分钟,具体看当前网速!`date -R` \e[0m"
    echo -e "\n\e[1;36m 检查:yum ... 如果耗时长,请查看是否有多个 ps -ef|grep yumBackend.py 进程,请 kill -9 PID 杀掉! \e[0m"
    mv /etc/yum.repos.d /etc/yum.repos.d-`date +%Y%m%d-%H%M%S`
    mkdir -p /etc/yum.repos.d
    wget -O /etc/yum.repos.d/Centos-7.repo http://mirrors.aliyun.com/repo/Centos-7.repo  >> $log 2>&1
    wget -O /etc/yum.repos.d/epel-7.repo   http://mirrors.aliyun.com/repo/epel-7.repo    >> $log 2>&1
    yum clean all  >> $log 2>&1
    yum makecache  >> $log 2>&1
    yum install -y atop htop glances iftop vmtouch gcc xterm xclock libaio libaio-devel sysstat xhost tree iotop dstat iptraf iptraf-ng unzip rdate git svn time zlib zlib-devel net-tools >> $log 2>&1
    echo -e "\n\e[1;31m 检查:yum ... 基础依赖包安装操作完成!`date -R` \e[0m"
fi
fi
rm /var/cache/yum/* -rf



# 服务优化
    chkconfig sendmail off       > /dev/null 2>&1
    chkconfig cups off           > /dev/null 2>&1
    chkconfig postfix off        > /dev/null 2>&1
    chkconfig avahi-dnsconfd off > /dev/null 2>&1
    chkconfig avahi-daemon off   > /dev/null 2>&1
    chkconfig NetworkManager off > /dev/null 2>&1

    service sendmail stop        > /dev/null 2>&1
    service cups stop            > /dev/null 2>&1
    service postfix stop         > /dev/null 2>&1
    service avahi-dnsconfd stop  > /dev/null 2>&1
    service avahi-daemon stop    > /dev/null 2>&1
    service NetworkManager stop  > /dev/null 2>&1

    systemctl stop avahi-dnsconfd    > /dev/null 2>&1
    systemctl stop avahi-daemon      > /dev/null 2>&1
    systemctl disable avahi-dnsconfd > /dev/null 2>&1
    systemctl disable avahi-daemon   > /dev/null 2>&1

    echo -e "\n\e[1;31m 检查:service ... Linux服务优化操作完成! \e[0m"



# 设置os内核参数
shmall=`awk '($1 == "MemTotal:"){print $2}' /proc/meminfo`
shmmax=`expr $shmall \* 1024`



myconf=/etc/sysctl.conf
mv $myconf $myconf-`date +%Y%m%d-%H%M%S`
cat >$myconf<<EOF

# add by wxf `date +%Y%m%d-%H%M%S`
# PostgreSQL on Linux 最佳部署手册 - 珍藏级
# https://github.com/digoal/blog/blob/master/201611/20161121_01.md

fs.aio-max-nr = 1048576
fs.file-max = 76724600
kernel.sem = 4096 2147483647 2147483646 512000    
# 信号量, ipcs -l 或 -u 查看，每16个进程一组，每组信号量需要17个信号量。
kernel.shmall = $shmall      
# 所有共享内存段相加大小限制(建议内存的80%)
kernel.shmmax = $shmmax   
# 最大单个共享内存段大小(建议为内存一半), >9.2的版本已大幅降低共享内存的使用
kernel.shmmni = 819200         
# 一共能生成多少共享内存段，每个PG数据库集群至少2个共享内存段
net.core.netdev_max_backlog = 10000
net.core.rmem_default = 262144       
# The default setting of the socket receive buffer in bytes.
net.core.rmem_max = 4194304          
# The maximum receive socket buffer size in bytes
net.core.wmem_default = 262144       
# The default setting (in bytes) of the socket send buffer.
net.core.wmem_max = 4194304          
# The maximum send socket buffer size in bytes.
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_keepalive_intvl = 20
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_mem = 8388608 12582912 16777216
net.ipv4.tcp_fin_timeout = 5
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syncookies = 1    
# 开启SYN Cookies。当出现SYN等待队列溢出时，启用cookie来处理，可防范少量的SYN攻击
net.ipv4.tcp_timestamps = 1    
# 减少time_wait
net.ipv4.tcp_tw_recycle = 0    
# 如果=1则开启TCP连接中TIME-WAIT套接字的快速回收，但是NAT环境可能导致连接失败，建议服务端关闭它
net.ipv4.tcp_tw_reuse = 1      
# 开启重用。允许将TIME-WAIT套接字重新用于新的TCP连接
net.ipv4.tcp_max_tw_buckets = 262144
net.ipv4.tcp_rmem = 8192 87380 16777216
net.ipv4.tcp_wmem = 8192 65536 16777216
net.nf_conntrack_max = 1200000
net.netfilter.nf_conntrack_max = 1200000
vm.dirty_background_bytes = 409600000       
#  系统脏页到达这个值，系统后台刷脏页调度进程 pdflush（或其他） 自动将(dirty_expire_centisecs/100）秒前的脏页刷到磁盘
vm.dirty_expire_centisecs = 3000             
#  比这个值老的脏页，将被刷到磁盘。3000表示30秒。
vm.dirty_ratio = 95                          
#  如果系统进程刷脏页太慢，使得系统脏页超过内存 95 % 时，则用户进程如果有写磁盘的操作（如fsync, fdatasync等调用），则需要主动把系统脏页刷出。
#  有效防止用户进程刷脏页，在单机多实例，并且使用CGROUP限制单实例IOPS的情况下非常有效。  
vm.dirty_writeback_centisecs = 100            
#  pdflush（或其他）后台刷脏页进程的唤醒间隔， 100表示1秒。
vm.mmap_min_addr = 65536
vm.overcommit_memory = 0     
#  在分配内存时，允许少量over malloc, 如果设置为 1, 则认为总是有足够的内存，内存较少的测试环境可以使用 1 .  
vm.overcommit_ratio = 90     
#  当overcommit_memory = 2 时，用于参与计算允许指派的内存大小。
vm.swappiness = 0            
#  关闭交换分区
vm.zone_reclaim_mode = 0     
# 禁用 numa, 或者在vmlinux中禁止. 
net.ipv4.ip_local_port_range = 40000 65535    
# 本地自动分配的TCP, UDP端口号范围
fs.nr_open=20480000
# 单个进程允许打开的文件句柄上限

EOF
/sbin/sysctl -p



myconf=/etc/security/limits.conf
mv $myconf $myconf-`date +%Y%m%d-%H%M%S`
cat >$myconf<<EOF

# add by wxf `date +%Y%m%d-%H%M%S`
# nofile超过1048576的话，一定要先将sysctl的fs.nr_open设置为更大的值，并生效后才能继续设置nofile.

* soft    nofile  1024000
* hard    nofile  1024000
* soft    nproc   unlimited
* hard    nproc   unlimited
* soft    core    unlimited
* hard    core    unlimited
* soft    memlock unlimited
* hard    memlock unlimited

EOF
oldstr="*          soft    nproc     4096"
newstr="*          soft    nproc     unlimited"
sed -i "s#$oldstr#$newstr#g" /etc/security/limits.d/20-nproc.conf



echo "alias ll='ls -lh'">>/etc/profile
echo "alias rm='rm -i'">>/etc/profile



# myconf=/root/.bash_profile
# cp $myconf $myconf-`date +%Y%m%d-%H%M%S`
# cat >>$myconf<<EOF
# add by wxf `date +%Y%m%d-%H%M%S`
# df -Th
# w
# EOF



# 配置nmon监控
rpm -q centos-release-6 > /dev/null 2>&1
if [ $? -eq 0 ];then
nmon_version="nmon_x86_64_centos6"
fi

rpm -q centos-release-7 > /dev/null 2>&1
if [ $? -eq 0 ];then
nmon_version="nmon_x86_64_centos7"
fi

ls /usr/local/sbin/${nmon_version} > /dev/null 2>&1
if [ $? -eq 0 ];then echo -e "\n\e[1;36m 检查:配置nmon监控 ... 已存在! \e[0m"
    else

wget -O /usr/local/sbin/${nmon_version}   https://raw.githubusercontent.com/wanghy8166/nmon/master/${nmon_version} >> $log 2>&1
chmod +x /usr/local/sbin/${nmon_version}

echo "/usr/local/sbin/${nmon_version} -ft -s 300 -c 288 -m /usr/local/lib64/" > /usr/local/lib64/nmon.sh
chmod +x /usr/local/lib64/nmon.sh
cp -i /var/spool/cron/root /var/spool/cron/root-`date +%Y%m%d-%H%M%S`-2
echo '0 0 * * * /usr/local/lib64/nmon.sh' >> /var/spool/cron/root

echo 'sh /usr/local/lib64/nmon.sh' >> /etc/rc.local
chmod +x /etc/rc.d/rc.local

sh /usr/local/lib64/nmon.sh
echo -e "\n\e[1;31m 检查:配置nmon监控 ... 已完成! \e[0m"
fi



systemctl list-unit-files|grep libvirtd|grep enabled > /dev/null 2>&1
if [ $? -eq 0 ];then
    echo -e "\n\e[1;31m CentOS 7 关闭服务:libvirtd.service - Virtualization daemon \e[0m"
    echo -e "\n\e[1;31m CentOS 7 删除 virbr0 虚拟网卡 \e[0m"
    echo -e "\n\e[1;31m 如有，强行重启!!!!!! \e[0m"
    virsh net-destroy  default > /dev/null 2>&1
    virsh net-undefine default > /dev/null 2>&1
    systemctl disable libvirtd > /dev/null 2>&1
    systemctl stop    libvirtd > /dev/null 2>&1
    # systemctl set-default graphical.target  #设置运行级别5
    systemctl set-default multi-user.target  #设置运行级别3
    init 6  # 重启
fi
# ip主机名是否存在于hosts
grep -q `hostname` /etc/hosts
if [ $? -eq 0 ];then
    echo -e "\n\e[1;36m 检查:ip主机名是否存在于hosts ... OK! \e[0m"
else
    echo `/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`  `hostname` >>/etc/hosts
    echo -e "\n\e[1;31m 检查:ip主机名是否存在于hosts ... 已加入! \e[0m"
fi



echo -e "\n\e[1;36m  OS操作系统环境配置完成... OK! \e[0m"
