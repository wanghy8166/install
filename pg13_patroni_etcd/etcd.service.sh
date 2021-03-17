cat > /usr/lib/systemd/system/etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd
Conflicts=etcd.service

[Service]
Type=simple
Restart=always
RestartSec=5s
LimitNOFILE=40000
TimeoutStartSec=0

ExecStart=/data/etcd/etcd.sh

[Install]
WantedBy=multi-user.target
EOF

# 配置计划任务，0点停、启服务，好处:1应对日志文件命名变化；2减少内存占用；
echo "00 00 * * * systemctl stop etcd && systemctl start etcd" >> /var/spool/cron/root

systemctl daemon-reload
systemctl disable etcd.service
systemctl enable etcd.service
systemctl stop etcd.service
systemctl start etcd.service
systemctl status etcd.service
