cat > /usr/lib/systemd/system/patroni.service <<EOF
[Unit]
Description=Runners to orchestrate a high-availability PostgreSQL
After=syslog.target network.target

[Service]
Type=simple
User=postgres
Group=postgres
ExecStart=/bin/patroni /data/patroni/pg.yml
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=process
TimeoutSec=30
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload  
systemctl disable patroni.service  
systemctl enable patroni.service  
systemctl stop patroni.service  
systemctl start patroni.service  
systemctl status patroni.service  

