#!/bin/bash

# 安装要求:https://openbsd.hk/pub/OpenBSD/OpenSSH/portable/INSTALL
# 测试环境:CentOS release 6.9 (Final) OpenSSH_5.3p1, OpenSSL 1.0.1e-fips 11 Feb 2013
# 测试环境:CentOS release 6.10 (Final) OpenSSH_5.3p1, OpenSSL 1.0.1e-fips 11 Feb 2013
# 测试环境:CentOS Linux release 7.5.1804 (Core) OpenSSH_7.4p1, OpenSSL 1.0.2k-fips  26 Jan 2017
# 测试环境:CentOS Linux release 7.6.1810 (Core) OpenSSH_7.4p1, OpenSSL 1.0.2k-fips  26 Jan 2017
# 计划升级到:https://openbsd.hk/pub/OpenBSD/OpenSSH/portable/openssh-7.9p1.tar.gz
# Zlib 1.1.4 or 1.2.1.2 or greater
# OpenSSL >= 1.0.1 < 1.1.0

useradd admin2018
echo "wB5hFsKFGnghefTe0ic="|passwd --stdin admin2018
# userdel admin2018

#rm -rf openssh_update*.log
log=openssh_update-`date +%Y%m%d-%H%M%S`.log
echo $log
cat /etc/redhat-release >>$log
ssh -V &>>$log
rpm -qa|grep -i gcc >>$log
rpm -qa|grep -i zlib >>$log
rpm -qa|grep -i openssl >>$log

# 开放telnet 23端口
rpm -q centos-release-6 > /dev/null 2>&1
if [ $? -eq 0 ];then
iptables -I INPUT -p tcp --dport 23 -j ACCEPT
service iptables save
iptables -nvL
fi
rpm -q centos-release-7 > /dev/null 2>&1
if [ $? -eq 0 ];then
firewall-cmd --zone=public --add-port=23/tcp --permanent
firewall-cmd --reload
firewall-cmd --list-all
fi

#关闭iptables防火墙和selinux
service iptables status >>$log
service iptables stop
systemctl status firewalld >>$log
systemctl stop   firewalld 
cat /etc/sysconfig/selinux > /etc/sysconfig/selinux.bak-`date +%Y%m%d-%H%M%S`
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux 
setenforce 0 

# 备份ssh原来配置
cp -rf /etc/ssh /etc/ssh.bak-`date +%Y%m%d-%H%M%S`

# 安装配置telnet，暂时允许root用户远程telnet，以防ssh升级后远程登录不了
yum install -y telnet-server
yum install -y xinetd
yum install -y telnet

# centos7手工创建/etc/xinetd.d/telnet文件
ls /etc/xinetd.d/telnet > /dev/null 2>&1
if [ $? -eq 0 ];then echo -e "\n\e[1;36m centos7手工创建/etc/xinetd.d/telnet文件 ... 已存在! \e[0m"
    else
touch /etc/xinetd.d/telnet
cat >/etc/xinetd.d/telnet<<EOF
# default: on
# description: The telnet server serves telnet sessions; it uses \
#       unencrypted username/password pairs for authentication.
service telnet
{
        flags           = REUSE
        socket_type     = stream        
        wait            = no
        user            = root
        server          = /usr/sbin/in.telnetd
        log_on_failure  += USERID
        disable         = yes
}

EOF
echo -e "\n\e[1;31m centos7手工创建/etc/xinetd.d/telnet文件 ... 写入完成! \e[0m"
fi

sed -i 's/= yes/= no/g' /etc/xinetd.d/telnet

systemctl stop    telnet.socket
systemctl enable  xinetd.service
systemctl list-unit-files|grep -i telnet
systemctl list-unit-files|grep -i xinetd

service xinetd restart
service xinetd status

cp -rf /etc/securetty /etc/securetty.bak-`date +%Y%m%d-%H%M%S`
mv     /etc/securetty /etc/securetty.bak

#安装配置新版本openssh
yum install -y gcc
yum install -y openssl-devel
yum install -y pam-devel
yum install -y rpm-build
yum install -y wget
yum install -y tar

chmod 0600 /etc/ssh/ssh_host_rsa_key
chmod 0600 /etc/ssh/ssh_host_ecdsa_key
chmod 0600 /etc/ssh/ssh_host_ed25519_key

sed -i '/^#PermitRootLogin/s/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's_#PermitRootLogin yes_PermitRootLogin yes_g' /etc/ssh/sshd_config

sed -i '/^GSSAPICleanupCredentials/s/GSSAPICleanupCredentials yes/#GSSAPICleanupCredentials yes/' /etc/ssh/sshd_config
sed -i '/^GSSAPICleanupCredentials/s/GSSAPICleanupCredentials no/#GSSAPICleanupCredentials no/' /etc/ssh/sshd_config
sed -i '/^GSSAPIAuthentication/s/GSSAPIAuthentication yes/#GSSAPIAuthentication yes/' /etc/ssh/sshd_config
sed -i '/^GSSAPIAuthentication/s/GSSAPIAuthentication no/#GSSAPIAuthentication no/' /etc/ssh/sshd_config

cat /etc/ssh/sshd_config|grep -in PermitRootLogin
cat /etc/ssh/sshd_config|grep -in GSSAPI

cd /usr/local/src
wget https://openbsd.hk/pub/OpenBSD/OpenSSH/portable/openssh-7.9p1.tar.gz
tar -zvxf openssh-7.9p1.tar.gz
cd /usr/local/src/openssh-7.9p1
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-pam --with-zlib --with-md5-passwords
make && make install
 
service sshd restart
service sshd status

ssh -V

# 确认OpenSSH升级成功后，再恢复原配置
# 关闭telnet远程登录
# 关闭telnet远程root登录,普通用户还可以登录:mv /etc/securetty.bak /etc/securetty
# 删除普通用户:userdel admin2018
# chkconfig xinetd off
# service xinetd stop
# 开启iptables防火墙和selinux
# service iptables start
# systemctl start firewalld
# sed -i 's/SELINUX=disabled/SELINUX=enforcing/g' /etc/sysconfig/selinux
# setenforce 1
