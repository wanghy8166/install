#!/bin/bash
# 安装patroni 
yum install -y python-pip python-psycopg2 python-devel
# pip install --upgrade pip
# yum remove -y python-pip
# pypi 镜像
mkdir ~/.pip
touch ~/.pip/pip.conf
cat >~/.pip/pip.conf<<EOF
[global]
index-url = http://mirrors.aliyun.com/pypi/simple/
trusted-host = mirrors.aliyun.com
EOF
cat ~/.pip/pip.conf
# pip config set global.index-url https://mirrors.aliyun.com/pypi/simple
pip install --upgrade "pip < 21.0"
pip -V
pip install --upgrade setuptools
pip install six
pip install -I pyparsing>=2.0.2
cat >requirements.txt<<EOF
urllib3>=1.19.1,!=1.21
ipaddress; python_version=="2.7"
boto
PyYAML
six>=1.7
kazoo>=1.3.1
python-etcd>=0.4.3,<0.5
python-consul>=0.7.1
click>=4.1
prettytable>=0.7
python-dateutil
pysyncobj>=0.3.7
psutil>=2.0.0
ydiff>=1.2.0
EOF
cat >requirements.dev.txt<<EOF
psycopg2-binary
behave
coverage
flake8
mock
pytest-cov
pytest
setuptools
EOF
pip install -r requirements.txt
pip install -r requirements.dev.txt
pip install patroni[etcd]

patroni --version
# patroni 2.0.2
patronictl version
# patronictl version 2.0.2