#!/bin/bash
# 注意调整：当前节点名、ip、数据存放路径，日志路径。

# 公共定义，3个节点都一样。  
NAME_1=etcd01
NAME_2=etcd02
NAME_3=etcd03
HOST_1=172.17.10.84
HOST_2=172.17.10.85
HOST_3=172.17.10.86
CLUSTER=${NAME_1}=http://${HOST_1}:2380,${NAME_2}=http://${HOST_2}:2380,${NAME_3}=http://${HOST_3}:2380

# 节点1，其他节点请调整  
THIS_NAME=${NAME_1}
THIS_IP=${HOST_1}

/data/etcd/etcd \
  --name ${THIS_NAME} \
  --data-dir /data/etcd/etcd-data \
  --listen-client-urls http://${THIS_IP}:2379 \
  --advertise-client-urls http://${THIS_IP}:2379 \
  --listen-peer-urls http://${THIS_IP}:2380 \
  --initial-advertise-peer-urls http://${THIS_IP}:2380 \
  --initial-cluster ${CLUSTER} \
  --initial-cluster-token tkn \
  --initial-cluster-state new \
  --enable-v2 \
  --log-level info \
  --logger zap \
  --log-outputs stderr \
  1>/data/etcd/logs/etcd-`date +%Y-%m-%d`.log 2>&1
