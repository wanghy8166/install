#!/bin/bash
# install_mysql.sh
# v0.1 支持 CentOS7.2 + mysql5.6
# v0.2 支持 CentOS6.9 + mysql5.6
# v0.3 完善支持 CentOS6|CentOS7 + mysql5.6
# v0.4 完善支持 CentOS6|CentOS7 + mysql5.6
# v0.5 完善支持 CentOS6|CentOS7 + mysql5.6|mysql5.7
# v0.6 CentOS6|7+mysql5.6|5.7,nmon,dump,rotate,pt
# v0.7 基于CentOS7.7 + pt3.1.0 + mysql-5.7.28 / mysql-5.6.46 测试 2019.12.28
# v0.8 基于CentOS7.6 + pt3.1.0 + mysql-5.7.29 2020.3.24

cat <<Download
# 不使用虚拟化的，可禁用libvirtd服务，重启主机
virsh net-destroy  default
virsh net-undefine default
systemctl disable libvirtd
systemctl stop    libvirtd
init 6

# 安装步骤
mkdir -p /soft
cd /soft
wget https://www.percona.com/downloads/percona-toolkit/3.0.13/binary/tarball/percona-toolkit-3.0.13_x86_64.tar.gz
wget  https://www.percona.com/downloads/percona-toolkit/3.1.0/binary/tarball/percona-toolkit-3.1.0_x86_64.tar.gz

wget https://dev.mysql.com/get/Downloads/MySQL-5.6/mysql-5.6.44-linux-glibc2.12-x86_64.tar.gz
wget https://dev.mysql.com/get/Downloads/MySQL-5.6/mysql-5.6.46-linux-glibc2.12-x86_64.tar.gz

wget https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-5.7.21-linux-glibc2.12-x86_64.tar.gz
wget     https://cdn.mysql.com/Downloads/MySQL-5.7/mysql-5.7.28-linux-glibc2.12-x86_64.tar.gz
wget https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-5.7.29-linux-glibc2.12-x86_64.tar.gz

wget https://raw.githubusercontent.com/wanghy8166/install/master/install_mysql.sh
sed -i 's/5.7.28/5.6.46/g' install_mysql.sh 
bash install_mysql.sh

异机mysqldump备份，需要的程序:
https://dev.mysql.com/get/Downloads/MySQL-5.6/mysql-5.6.44-winx64.zip
https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-5.7.21-winx64.zip
https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-5.7.29-winx64.zip
Download



# 依赖包 
yum install -y git wget rdate unzip net-tools deltarpm vim tree



clear
    count=`ps -ef |grep mysqld |grep -v "grep" |wc -l`
    echo -e "\n\e[1;33m mysqld进程个数:$count \e[0m"

    if [ $count -eq 0 ]; then 
        echo -e "\n\e[1;33m 不存在mysqld进程，继续安装！ \e[0m"
    else
        echo -e "\n\e[1;33m 已存在mysqld进程，终止安装！ \e[0m"
        exit
    fi

# clear
soft_path="/soft" # mysql制品的存放路径
data_path="/db/data" # mysql的安装路径
backup_path="/dbbak" # mysqldump的安装路径
mysql_version="mysql-5.7.29-linux-glibc2.12-x86_64" # Linux - Generic 压缩包
pt_version="percona-toolkit-3.1.0" # Linux - Generic 压缩包
mysql_password="heading"

local_ip=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
echo "本机ip:"${local_ip}

mem=`awk '($1 == "MemTotal:"){print $2/1048576*0.7}' /proc/meminfo`
mem7=${mem%.*}
echo -e "\n\e[1;33m 物理内存的70%约为:${mem7}G，请替换 my.cnf 配置参数（innodb-log-file-size，innodb-buffer-pool-size）! \e[0m"

echo -e "\n\e[1;33m 提前装好操作系统、配置好外网、准备好安装文件，一键安装脚本在虚拟机环境（1CPU,2G内存），整体耗时大约10分钟。 \e[0m"
echo -e "\n\e[1;33m mysql安装文件,请放在 ${soft_path} 下! \e[0m"
echo " ${mysql_version}.tar.gz"
echo " ${pt_version}_x86_64.tar.gz"
# echo " ${nmon_version}"
# 链接: https://pan.baidu.com/s/1PsR1z9kk3Gu_1j-IWtg82w 密码: qre4

echo -e "\n\e[1;33m mysql程序,安装在 ${data_path} 下,如有不同,请退出并手动修改脚本! \e[0m"
echo -e "\n\e[1;33m ================================================== \e[0m"
echo -e "\n\e[1;33m Continue? (y/n [n]): \e[0m"
    read singal
    if [ "$singal"x != "y"x ]; then
        exit
    else
        echo "God Bless you! Settings started."
        echo ""
        echo ""
    fi



# 判断安装文件是否存在
file_exists()
{
ls ${soft_path}/${mysql_version}.tar.gz > /dev/null 2>&1
if [ $? -eq 0 ];then echo -e "\n\e[1;36m 检查文件:${mysql_version}.tar.gz ... OK! \e[0m"
    else
        echo -e "\n\e[1;31m 检查文件:${mysql_version}.tar.gz ... 没找到! \e[0m"
        exit
fi

ls ${soft_path}/${pt_version}_x86_64.tar.gz > /dev/null 2>&1
if [ $? -eq 0 ];then echo -e "\n\e[1;36m 检查文件:${pt_version}_x86_64.tar.gz ... OK! \e[0m"
    else
        echo -e "\n\e[1;31m 检查文件:${pt_version}_x86_64.tar.gz ... 没找到! \e[0m"
        exit
fi

# ls ${soft_path}/${nmon_version} > /dev/null 2>&1
# if [ $? -eq 0 ];then echo -e "\n\e[1;36m 检查文件:${nmon_version} ... OK! \e[0m"
#     else
#         echo -e "\n\e[1;31m 检查文件:${nmon_version} ... 没找到! \e[0m"
#         exit
# fi
}



# 判断执行用户是否root
isroot()
{
    if [ $USER != "root" ];then
        echo -e "\n\e[1;31m the user must be root,and now you user is $USER,please su to root. \e[0m"
        exit
    else
        echo -e "\n\e[1;36m check root ... OK! \e[0m"
    fi
}



# 判断swap是否16G
swap()
{
	swap=`free -m|grep -i swap|awk '{print $2}'`
	if [ $swap -lt 16000 ];then
        echo -e "\n\e[1;31m 检查:swap ... 小于16G,请修改! \e[0m"
        exit
    else 
    	echo -e "\n\e[1;36m 检查:swap ... OK! \e[0m"
    fi
}



# 判断是否可以上网
check_internet()
{
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
}



# 更改时区、时间
change_date()
{
diff /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
if [ $? -eq 0 ];then
	echo -e "\n\e[1;36m 检查:时区为上海 ... OK! \e[0m"
else 
    mv /etc/localtime /etc/localtime-`date +%Y%m%d-%H%M%S`
    cp -i /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo -e "\n\e[1;31m 检查:时区 ... 已修改为上海! \e[0m"
fi

touch /var/spool/cron/root
grep -q "rdate" /var/spool/cron/root
if [ $? -eq 0 ];then
	echo -e "\n\e[1;36m 检查:时间同步已加入crontab ... OK! \e[0m"
else
	cp -i /var/spool/cron/root /var/spool/cron/root-`date +%Y%m%d-%H%M%S`
    echo "08 23 * * * /usr/bin/rdate -s time.nist.gov && /sbin/hwclock --systohc" >> /var/spool/cron/root
    echo -e "\n\e[1;31m 检查:时间同步 ... 配置已加入crontab! \e[0m"
fi

/usr/bin/rdate -s time.nist.gov && /sbin/hwclock --systohc    
echo -e "\n\e[1;31m 检查:时间同步 ... 已执行同步!`date -R` \e[0m"
}



log=/tmp/mysql-install-`date +%Y%m%d-%H%M%S`.log
touch $log
chmod 666 $log
echo -e "\n\e[1;33m   >>>>>>>>>>查看后台安装日志进度:$log \e[0m"



# 更改yum配置
change_yum()
{
rpm -q centos-release-6 > /dev/null 2>&1
if [ $? -eq 0 ];then
ls /etc/yum.repos.d/Centos-6.repo > /dev/null 2>&1
if [ $? -eq 0 ];then
    echo -e "\n\e[1;36m 检查:yum ... OK! \e[0m"
    return
else 
    echo -e "\n\e[1;36m 检查:yum ... 开始下载、安装依赖包,大约5分钟,具体看当前网速!`date -R` \e[0m"
    echo -e "\n\e[1;36m 检查:yum ... 如果耗时长,请查看是否有多个 ps -ef|grep yumBackend.py 进程,请 kill -9 PID 杀掉! \e[0m"
    mv /etc/yum.repos.d /etc/yum.repos.d-`date +%Y%m%d-%H%M%S`
    mkdir -p /etc/yum.repos.d
    wget -O /etc/yum.repos.d/Centos-6.repo http://mirrors.aliyun.com/repo/Centos-6.repo  >> $log 2>&1
    wget -O /etc/yum.repos.d/epel-6.repo   http://mirrors.aliyun.com/repo/epel-6.repo    >> $log 2>&1
    yum clean all  >> $log 2>&1
    yum makecache  >> $log 2>&1
    yum install -y atop htop glances iftop vmtouch gcc tigervnc-server xterm xclock libaio libaio-devel sysstat xhost tree iotop dstat iptraf iptraf-ng  >> $log 2>&1
    yum install -y make sysstat libaio libaio-devel  >> $log 2>&1
    yum install -y libaio autoconf  >> $log 2>&1
    # yum install -y libXi libXtst make sysstat cpp mpfr binutils compat-libcap1 compat-libstdc++-33 elfutils-libelf elfutils-libelf-devel gcc gcc-c++ glibc glibc-common glibc-devel glibc-headers libaio libaio-devel libgcc libstdc++ libstdc++-devel compat-db compat-libstdc++ gnome-libs pdksh xscreensaver openmotif libXp compat-gcc-34 compat-gcc-34-c++ expat unixODBC unixODBC-devel kernel-headers libgomp psmisc  >> $log 2>&1
    echo -e "\n\e[1;31m 检查:yum ... 依赖包安装操作完成!`date -R` \e[0m"
fi
fi

rpm -q centos-release-7 > /dev/null 2>&1
if [ $? -eq 0 ];then
ls /etc/yum.repos.d/Centos-7.repo > /dev/null 2>&1
if [ $? -eq 0 ];then
    echo -e "\n\e[1;36m 检查:yum ... OK! \e[0m"
    return
else 
    echo -e "\n\e[1;36m 检查:yum ... 开始下载、安装依赖包,大约5分钟,具体看当前网速!`date -R` \e[0m"
    echo -e "\n\e[1;36m 检查:yum ... 如果耗时长,请查看是否有多个 ps -ef|grep yumBackend.py 进程,请 kill -9 PID 杀掉! \e[0m"
    mv /etc/yum.repos.d /etc/yum.repos.d-`date +%Y%m%d-%H%M%S`
    mkdir -p /etc/yum.repos.d
    wget -O /etc/yum.repos.d/Centos-7.repo http://mirrors.aliyun.com/repo/Centos-7.repo  >> $log 2>&1
    wget -O /etc/yum.repos.d/epel-7.repo   http://mirrors.aliyun.com/repo/epel-7.repo    >> $log 2>&1
    yum clean all  >> $log 2>&1
    yum makecache  >> $log 2>&1
    yum install -y atop htop glances iftop vmtouch gcc tigervnc-server xterm xclock libaio libaio-devel sysstat xhost tree iotop dstat iptraf iptraf-ng  >> $log 2>&1
    yum install -y make sysstat libaio libaio-devel  >> $log 2>&1
    yum install -y libaio autoconf  >> $log 2>&1
    # yum install -y libXi libXtst make sysstat cpp mpfr binutils compat-libcap1 compat-libstdc++-33 elfutils-libelf elfutils-libelf-devel gcc gcc-c++ glibc glibc-common glibc-devel glibc-headers libaio libaio-devel libgcc libstdc++ libstdc++-devel compat-db compat-libstdc++ gnome-libs pdksh xscreensaver openmotif libXp compat-gcc-34 compat-gcc-34-c++ expat unixODBC unixODBC-devel kernel-headers libgomp psmisc  >> $log 2>&1
    echo -e "\n\e[1;31m 检查:yum ... 依赖包安装操作完成!`date -R` \e[0m"
fi
fi
}



# 服务优化
service_Tuning()
{
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
    echo -e "\n\e[1;31m 检查:service ... Linux服务优化操作完成! \e[0m"
}



# 设置内核参数
sysctl()
{
grep -q "swappiness" /etc/sysctl.conf
if [ $? -eq 0 ];then
	echo -e "\n\e[1;36m 检查:设置内核参数 ... OK! \e[0m"
	return
else
cp -i /etc/sysctl.conf /etc/sysctl.conf-`date +%Y%m%d-%H%M%S`

#kernel.shmall = 2097152          --（物理内存G*1024*1024）
#kernel.shmmax = 536870912        --（物理内存G*1024*1024*1024）
#kernel.shmall = 2097152
#kernel.shmmax = 2147483648
# echo 'kernel.shmall = 2097152'                            >> /etc/sysctl.conf
# echo 'kernel.shmmax = 2147483648'                         >> /etc/sysctl.conf

echo 'vm.swappiness = 0'                         >> /etc/sysctl.conf
echo 'vm.dirty_background_ratio = 3'             >> /etc/sysctl.conf
echo 'vm.dirty_ratio = 80'                       >> /etc/sysctl.conf
echo 'vm.dirty_expire_centisecs = 500'           >> /etc/sysctl.conf
echo 'vm.dirty_writeback_centisecs = 100'        >> /etc/sysctl.conf

echo 'fs.aio-max-nr = 3145728'                   >> /etc/sysctl.conf
echo 'fs.file-max = 6815744'                     >> /etc/sysctl.conf
echo 'kernel.shmmni = 4096'                      >> /etc/sysctl.conf
echo 'kernel.sem = 250 32000 100 128'            >> /etc/sysctl.conf
echo 'net.ipv4.ip_local_port_range = 9000 65500' >> /etc/sysctl.conf
echo 'net.core.rmem_default = 262144'            >> /etc/sysctl.conf
echo 'net.core.rmem_max = 4194304'               >> /etc/sysctl.conf
echo 'net.core.wmem_default = 262144'            >> /etc/sysctl.conf
echo 'net.core.wmem_max = 1048586'               >> /etc/sysctl.conf

echo -e "\n\e[1;31m 检查:设置内核参数 ... 操作完成! \e[0m"
fi
/sbin/sysctl -p > /dev/null 2>&1
}



# 开放端口
iptables()
{
grep -q "CentOS release 6" /etc/issue
if [ $? -eq 0 ];then
    /sbin/iptables -I INPUT -p tcp --dport 3306 -j ACCEPT > /dev/null 2>&1
    /sbin/iptables -nvL > /dev/null 2>&1
    service iptables save > /dev/null 2>&1
    #service iptables restart > /dev/null 2>&1
    echo -e "\n\e[1;31m 检查:开放端口 ... 操作完成! \e[0m"
fi

# grep -q "CentOS release 7" /etc/issue
rpm -q centos-release-7 > /dev/null 2>&1
if [ $? -eq 0 ];then
    firewall-cmd --zone=public --add-port=3306/tcp --permanent > /dev/null 2>&1
    firewall-cmd --reload > /dev/null 2>&1
    # firewall-cmd --state 

    # centos 7 删除 virbr0 虚拟网卡
    virsh net-destroy  default > /dev/null 2>&1
    virsh net-undefine default > /dev/null 2>&1
    systemctl disable libvirtd > /dev/null 2>&1
    systemctl stop    libvirtd > /dev/null 2>&1

    echo -e "\n\e[1;31m 检查:开放端口 ... 操作完成! \e[0m"
fi
}



# 添加组和用户
useradd()
{
id mysql > /dev/null 2>&1
if [ $? -eq 0 ];then
	echo -e "\n\e[1;36m 检查:添加组和mysql用户 ... OK! \e[0m"
	return
else
    /usr/sbin/groupadd mysql
    /usr/sbin/useradd -r -g mysql -s /bin/false mysql
    echo -e "\n\e[1;31m 检查:添加组和mysql用户 ... 操作完成! \e[0m"
fi
}



# 安装目录
oraInventory()
{
mkdir -p                 ${data_path} 
# chown -R mysql:mysql     ${data_path}
# chmod -R 775             ${data_path}
mkdir -p                 ${backup_path} 
echo -e "\n\e[1;31m 检查:安装目录 ... 操作完成! \e[0m"
}



# 用户环境配置
bash_profile()
{
grep -q "mysql" /root/.bash_profile
if [ $? -eq 0 ];then
	echo -e "\n\e[1;36m 检查:用户环境配置 ... OK! \e[0m"
	return
else
cp -i /root/.bash_profile /root/.bash_profile-`date +%Y%m%d-%H%M%S` 
cat >>/root/.bash_profile<<EOF

export PATH=\$PATH:${data_path}/mysql/bin

EOF
source /root/.bash_profile
echo -e "\n\e[1;31m 检查:用户环境配置 ... 操作完成! \e[0m"
fi
}



# 执行以上函数
file_exists
isroot
# swap
check_internet
change_date
change_yum
# pdksh
service_Tuning
sysctl
# limits
# pam_limits
# selinux
iptables



useradd
# profile
oraInventory
bash_profile

echo -e "\n\e[1;36m 检查:操作系统环境准备结束 ... OK! \e[0m"



# ip主机名是否存在于hosts
grep -q `hostname` /etc/hosts
if [ $? -eq 0 ];then
    echo -e "\n\e[1;36m 检查:ip主机名是否存在于hosts ... OK! \e[0m"
else
    echo `/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`  `hostname` >>/etc/hosts
    echo -e "\n\e[1;31m 检查:ip主机名是否存在于hosts ... 已加入! \e[0m"
fi



# 解压安装文件
ls ${data_path}/${mysql_version}/bin/mysqld > /dev/null 2>&1
if [ $? -eq 0 ];then echo -e "\n\e[1;36m 解压安装文件:${mysql_version} ... 已存在! \e[0m"
    else
echo -e "\n\e[1;36m 解压安装文件:${mysql_version} ... 开始解压! \e[0m"

tar zxvf ${soft_path}/${mysql_version}.tar.gz -C ${data_path} >> $log

echo -e "\n\e[1;31m 解压安装文件:${mysql_version} ... 解压完成! \e[0m"
fi



# 安装、配置mysql
ls ${data_path}/mysql/data/mysql/user.* > /dev/null 2>&1
if [ $? -eq 0 ];then echo -e "\n\e[1;36m 检查:安装、配置mysql ... 已存在! \e[0m"
    else

touch /etc/my.cnf
mv /etc/my.cnf /etc/my.cnf-`date +%Y%m%d-%H%M%S`

cd ${data_path}
ln -s ${mysql_version} mysql
cd mysql
cat >my.cnf<<EOF
[mysql]
# CLIENT #
port                           = 3306
socket                         = ${data_path}/mysql/data/mysql.sock
default-character-set          = utf8

[mysqld]
# GENERAL #
lc-messages-dir                = ${data_path}/mysql/share
character-set-server           = utf8
lower_case_table_names         = 1
user                           = mysql
default-storage-engine         = InnoDB
socket                         = ${data_path}/mysql/data/mysql.sock
pid-file                       = ${data_path}/mysql/data/mysql.pid

# MyISAM #
key-buffer-size                = 32M
myisam-recover-options         = FORCE,BACKUP

# SAFETY #
max-allowed-packet             = 32M
max-connect-errors             = 1000000
skip-name-resolve
sql-mode                       = STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION,NO_ZERO_DATE,NO_ZERO_IN_DATE
sysdate-is-now                 = 1
explicit_defaults_for_timestamp=true
innodb                         = FORCE
symbolic-links                 = 0

# DATA STORAGE #
datadir                        = ${data_path}/mysql/data/

# BINARY LOGGING #
server-id                      = 1
log-bin                        = ${data_path}/mysql/data/mysql-bin
expire-logs-days               = 2
sync-binlog                    = 1
log_bin_trust_function_creators= 1

# CACHES AND LIMITS #
tmp-table-size                 = 32M
max-heap-table-size            = 32M
query-cache-type               = 0
query-cache-size               = 0
max-connections                = 2000
thread-cache-size              = 100
open-files-limit               = 65535
table-definition-cache         = 1024
table-open-cache               = 2048

# INNODB #
innodb-flush-method            = O_DIRECT
innodb-log-files-in-group      = 8
# innodb-log-file-size 根据磁盘mbps能力,改为128M~512M
innodb-log-file-size           = 128M
innodb-flush-log-at-trx-commit = 1
innodb-file-per-table          = 1
# innodb-buffer-pool-size 改为物理内存的70%
innodb-buffer-pool-size        = ${mem7}G

# LOGGING #
log-error                      = ${data_path}/mysql/data/mysql-error.log
# log-queries-not-using-indexes  = 1
slow-query-log                 = 1
slow-query-log-file            = ${data_path}/mysql/data/mysql-slow.log
long_query_time                = 1

[mysqld_safe]
!includedir                    /etc/my.cnf.d

EOF
mkdir -p /etc/my.cnf.d

# 这是一种尝试，!includedir /etc/my.cnf.d可以添加自定义配置信息，而不用修改原my.cnf
# 并且可以在不同配置文件里放相同的参数，按照从上往下的顺序读取配置文件和参数，以最后读到的参数为准
# 虽然可以这么用，但是生产环境并不建议配置多个相同的参数而值不同，这里仅仅是为了测试方便

echo ${mysql_version}|grep 5.6
if [ $? -eq 0 ];then
    echo -e "\n    初始化5.6数据库:"${mysql_version} >> $log 2>&1
    echo -e "\n    scripts/mysql_install_db --user=mysql 开始执行............................................................" >> $log 2>&1
    scripts/mysql_install_db --user=mysql >> $log 2>&1
fi

echo ${mysql_version}|grep 5.7
if [ $? -eq 0 ];then
    echo -e "\n    初始化5.7数据库:"${mysql_version} >> $log 2>&1
    mkdir mysql-files
    chown mysql:mysql mysql-files
    chmod 750 mysql-files

    echo '[mysqld]'                                 > /etc/my.cnf.d/my001-log.cnf
    echo 'log_timestamps                 = SYSTEM' >> /etc/my.cnf.d/my001-log.cnf
    
    echo -e "\n    bin/mysqld --defaults-file=./my.cnf --initialize-insecure --user=mysql 开始执行............................................................" >> $log 2>&1
    bin/mysqld --defaults-file=./my.cnf --initialize-insecure --user=mysql >> $log 2>&1
    echo -e "\n    bin/mysql_ssl_rsa_setup --defaults-file=./my.cnf 开始执行............................................................" >> $log 2>&1
    bin/mysql_ssl_rsa_setup --defaults-file=./my.cnf >> $log 2>&1
    chmod 0644 data/*.pem
fi

echo -e "\n    bin/mysqld_safe --user=mysql & 开始执行............................................................" >> $log 2>&1
bin/mysqld_safe --user=mysql & >> $log 2>&1

# 等待mysql第一次启动
count=`ps -ef |grep mysqld |grep -v "grep" |wc -l`
echo $count >> $log 2>&1
echo "sleep 3" >> $log 2>&1
sleep 3
until [ $count = 2 ] 
do
    echo "sleep 3" >> $log 2>&1
    sleep 3
    count=`ps -ef |grep mysqld |grep -v "grep" |wc -l`
    echo $count >> $log 2>&1

    if [ $count != 2 ]; then 
        echo "等待mysql第一次启动,大约2分钟,请等待..."`date -R` >> $log
    else
        echo "等待mysql第一次启动,已启动..."`date -R` >> $log
        #exit
    fi
done

echo "sleep 30,等待mysql第一次启动:初始化logfile,配置差的机器需要时间" >> $log 2>&1
sleep 30

echo -e "\n    bin/mysqladmin设置密码 开始执行............................................................" >> $log 2>&1
bin/mysqladmin -S ${data_path}/mysql/data/mysql.sock -h localhost -u root password ${mysql_password} >> $log 2>&1

echo -e "\n    bin/mysql修改用户权限 开始执行............................................................" >> $log 2>&1
echo ${mysql_version}|grep 5.6
if [ $? -eq 0 ];then
bin/mysql -S ${data_path}/mysql/data/mysql.sock -h localhost -uroot -p${mysql_password} -e "delete from mysql.user where Password = '';  commit;  FLUSH PRIVILEGES;"
fi

bin/mysql -S ${data_path}/mysql/data/mysql.sock -h localhost -uroot -p${mysql_password} -e "update mysql.user set Host='%' where user='root' and Host<>'%';  commit;  FLUSH PRIVILEGES;"

echo -e "\n\e[1;31m 检查:安装、配置mysql ... 已完成! \e[0m"
fi



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

wget -O ${soft_path}/${nmon_version}   https://raw.githubusercontent.com/wanghy8166/nmon/master/${nmon_version} >> $log 2>&1

cp -i ${soft_path}/${nmon_version} /usr/local/sbin/${nmon_version}
chmod +x /usr/local/sbin/${nmon_version}

echo "/usr/local/sbin/${nmon_version} -ft -s 300 -c 288 -m /usr/local/lib64/" > /usr/local/lib64/nmon.sh
chmod +x /usr/local/lib64/nmon.sh
cp -i /var/spool/cron/root /var/spool/cron/root-`date +%Y%m%d-%H%M%S`
echo '0 0 * * * /usr/local/lib64/nmon.sh' >> /var/spool/cron/root

echo 'sh /usr/local/lib64/nmon.sh' >> /etc/rc.local
chmod +x /etc/rc.d/rc.local

sh /usr/local/lib64/nmon.sh
echo -e "\n\e[1;31m 检查:配置nmon监控 ... 已完成! \e[0m"
fi



# 配置服务，自动启动
ls /etc/init.d/mysql.server > /dev/null 2>&1
if [ $? -eq 0 ];then echo -e "\n\e[1;36m 检查:配置服务，自动启动 ... 已存在! \e[0m"
    else

cd ${data_path}/mysql
\cp support-files/mysql.server /etc/init.d/mysql.server
/sbin/chkconfig mysql.server on
# service mysql.server stop
# service mysql.server start
# service mysql.server status

oldstr="basedir="  
newstr="basedir=${data_path}/mysql"  
sed -i "46s#$oldstr#$newstr#g" /etc/init.d/mysql.server

oldstr="datadir="  
newstr="datadir=${data_path}/mysql/data"  
sed -i "47s#$oldstr#$newstr#g" /etc/init.d/mysql.server

cat /etc/init.d/mysql.server|grep -in basedir=  >> $log 2>&1
cat /etc/init.d/mysql.server|grep -in datadir=  >> $log 2>&1

echo -e "\n\e[1;31m 检查:配置mysql实例自动启动 ... 已完成! \e[0m"
fi



# 配置mysqldump备份
ls ${backup_path}/backup/mysqldump-backup.sh > /dev/null 2>&1
if [ $? -eq 0 ];then echo -e "\n\e[1;36m 检查:配置mysqldump备份 ... 已存在! \e[0m"
    else

mkdir -p ${backup_path}/backup/
cat >${backup_path}/backup/mysqldump-backup.sh<<EOF
#!/bin/sh
rq=\`date +%Y%m%d\`
echo \$rq
date 

PATH=\$PATH:${data_path}/mysql/bin
export PATH

cd ${backup_path}/backup/

time mysqldump -S${data_path}/mysql/data/mysql.sock --port=3306 -uroot -p${mysql_password} --opt --single-transaction --flush-logs --master-data=2 --routines --all-databases | gzip > \$rq-mysqldump.sql.gz 

# bash显示前几天,并删除
rqt=\`date -d "7 days ago" +%Y%m%d\`
echo \$rqt
date 

if  [ -f \$rq-mysqldump.sql.gz ]; then
cat /dev/null
rm -f \$rqt-mysqldump.sql.gz
rm -f \$rqt-mysqldump.sql.gz.log
else
cat /dev/null
fi
EOF
echo "01 02 * * *   sh ${backup_path}/backup/mysqldump-backup.sh  >${backup_path}/backup/\`date +\%Y\%m\%d\`-mysqldump.sql.gz.log 2>&1 " >> /var/spool/cron/root

echo -e "\n\e[1;31m 检查:配置mysqldump备份 ... 已完成! \e[0m"

fi



# 配置本机mysql的insert，update，delete监控脚本
ls ${data_path}/mysql/monitor_iud.sh > /dev/null 2>&1
if [ $? -eq 0 ];then echo -e "\n\e[1;36m 检查:配置本机mysql的insert，update，delete监控脚本 ... 已存在! \e[0m"
    else

cat >${data_path}/mysql/monitor_iud.sh<<EOF 
#!/bin/sh
clear
${data_path}/mysql/bin/mysqladmin -P3306 -uroot -p${mysql_password} -h127.0.0.1 -r -i 1 ext |\\
awk -F"|" \\
"BEGIN{ count=0; }"\\
'{ if(\$2 ~ /Variable_name/ && ((++count)%20 == 1)){\\
    print "----------|---------|--- mysql Command Status --|----- Innodb row operation ----|-- Buffer Pool Read --";\\
    print "---Time---|---QPS---|select insert update delete|  read inserted updated deleted|   logical    physical";\\
}\\
else if (\$2 ~ /Queries/){queries=\$3;}\\
else if (\$2 ~ /Com_select /){com_select=\$3;}\\
else if (\$2 ~ /Com_insert /){com_insert=\$3;}\\
else if (\$2 ~ /Com_update /){com_update=\$3;}\\
else if (\$2 ~ /Com_delete /){com_delete=\$3;}\\
else if (\$2 ~ /Innodb_rows_read/){innodb_rows_read=\$3;}\\
else if (\$2 ~ /Innodb_rows_deleted/){innodb_rows_deleted=\$3;}\\
else if (\$2 ~ /Innodb_rows_inserted/){innodb_rows_inserted=\$3;}\\
else if (\$2 ~ /Innodb_rows_updated/){innodb_rows_updated=\$3;}\\
else if (\$2 ~ /Innodb_buffer_pool_read_requests/){innodb_lor=\$3;}\\
else if (\$2 ~ /Innodb_buffer_pool_reads/){innodb_phr=\$3;}\\
else if (\$2 ~ /Uptime / && count >= 2){\\
  printf(" %s |%9d",strftime("%H:%M:%S"),queries);\\
  printf("|%6d %6d %6d %6d",com_select,com_insert,com_update,com_delete);\\
  printf("|%6d %8d %7d %7d",innodb_rows_read,innodb_rows_inserted,innodb_rows_updated,innodb_rows_deleted);\\
  printf("|%10d %11d\\n",innodb_lor,innodb_phr);\\
}}'
EOF

echo -e "\n\e[1;31m 检查:配置本机mysql的insert，update，delete监控脚本 ... 已完成! \e[0m"

fi



# 配置mysql-log-rotate
ls /etc/logrotate.d/mysql-log-rotate > /dev/null 2>&1
if [ $? -eq 0 ];then echo -e "\n\e[1;36m 检查:配置mysql-log-rotate ... 已存在! \e[0m"
    else

cat >/etc/logrotate.d/mysql-log-rotate<<EOF
${data_path}/mysql/data/mysql-slow.log {
        nocompress
        create 600 mysql mysql
        dateext
        notifempty
        sharedscripts
        daily
        maxage 15
        rotate 15
        missingok
    postrotate
        if test -x ${data_path}/mysql/bin/mysqladmin && \
            ${data_path}/mysql/bin/mysqladmin ping -h127.0.0.1 -uroot -p${mysql_password} > /dev/null 2>&1 
        then
            ${data_path}/mysql/bin/mysqladmin flush-logs -h127.0.0.1 -uroot -p${mysql_password} > /dev/null 2>&1 
        fi
    endscript
}
EOF
echo "59 23 * * * /usr/sbin/logrotate -f /etc/logrotate.d/mysql-log-rotate" >> /var/spool/cron/root

echo -e "\n\e[1;31m 检查:配置mysql-log-rotate ... 已完成! \e[0m"
fi



# 配置percona-toolkit
ls ${data_path}/pt/bin/pt-query-digest > /dev/null 2>&1
if [ $? -eq 0 ];then echo -e "\n\e[1;36m 检查:配置percona-toolkit ... 已存在! \e[0m"
    else

yum install -y perl-Time-HiRes perl-DBD-MySQL perl-devel perl-Digest-MD5 >> $log 2>&1
mkdir -p ${data_path}/pt >> $log 2>&1
tar zxvf ${soft_path}/${pt_version}_x86_64.tar.gz -C ${soft_path} >> $log 2>&1
cd ${soft_path}/${pt_version} >> $log 2>&1

perl Makefile.PL PREFIX=${data_path}/pt >> $log 2>&1
make         >> $log 2>&1
make test    >> $log 2>&1
make install >> $log 2>&1

echo -e "\n\e[1;31m 检查:配置percona-toolkit ... 已完成! \e[0m"
fi



echo -e "\n\e[1;33m 安装结束 <<<<<<<<<<! `date -R` \e[0m" >> $log 2>&1
echo -e "\n\e[1;33m 安装结束 <<<<<<<<<<! `date -R` \e[0m"
echo -e "\n\e[1;33m >>>>>>>>>> 为了防止意外事件发生,请在安装完成后手动删除该脚本! <<<<<<<<<< `date -R` \e[0m"
echo -e "\n\e[1;33m >>>>>>>>>> 为了防止意外事件发生,请在安装完成后手动删除该脚本! <<<<<<<<<< `date -R` \e[0m"
echo -e "\n\e[1;33m >>>>>>>>>> 为了防止意外事件发生,请在安装完成后手动删除该脚本! <<<<<<<<<< `date -R` \e[0m"