#!/bin/bash
# 修复runc漏洞CVE-2019-5736的公告
# https://help.aliyun.com/document_detail/107320.html
# https://mp.weixin.qq.com/s/fJyrLxR4EtPuqOt18LAINA

clear
log=docker_upgrade-`date +%Y%m%d-%H%M%S`.log
echo $log
docker -v >>$log
# < 18.09.2
docker-runc -v >>$log
# <= 1.0-rc6

# 升级Docker。升级已有集群的Docker到18.09.2或以上版本。该方案会导致容器和业务中断。
mv /etc/yum.repos.d /etc/yum.repos.d-`date +%Y%m%d-%H%M%S`
mkdir -p /etc/yum.repos.d
wget -O /etc/yum.repos.d/Centos-7.repo http://mirrors.aliyun.com/repo/Centos-7.repo
wget -O /etc/yum.repos.d/epel-7.repo   http://mirrors.aliyun.com/repo/epel-7.repo
sudo yum-config-manager \
    --add-repo \
    http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    # https://download.docker.com/linux/centos/docker-ce.repo
    # http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

sudo yum clean all
sudo yum makecache
sudo yum list docker-ce --showduplicates | sort -r
sudo yum install docker-ce

# 升级成功后,docker-runc,docker-containerd,docker-containerd-ctr,docker-containerd-shim,这4个命令都被替换了。
echo >>$log
docker -v >>$log
runc -v >>$log
