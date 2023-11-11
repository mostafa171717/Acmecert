#!/bin/bash
git clone https://github.com/acmesh-official/acme.sh
cd acme.sh/
chmod +x acme.sh
./acme.sh --install --home /opt/acme --no-profile \
   --accountemail noreply@valeo.com --log /var/log/acme.sh.log
mkdir /opt/node_exporter
mkdir /opt/node_exporter/secret
touch /opt/node_exporter/secret/private.key
touch /opt/node_exporter/secret/server.cer
touch /opt/node_exporter/secret/fullchain.cer
chmod 600 /opt/node_exporter/secret/private.key
usermod -s /sbin/nologin node_exporter
echo '[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.config.file=/opt/node_exporter/web.yml

[Install]
WantedBy=multi-user.target
' > /etc/systemd/system/node_exporter.service
apt install socat -y
/opt/acme/acme.sh --home /opt/acme --set-default-ca  --server \
https://certms.vnet.valeo.com/acme/valeo/directory

/opt/acme/acme.sh --home /opt/acme --issue \
--domain `hostname` --standalone --insecure --force

echo 'tls_server_config:
  cert_file: /opt/node_exporter/secret/fullchain.cer
  key_file: /opt/node_exporter/secret/private.key
' > /opt/node_exporter/web.yml
cd /opt/node_exporter
chown -R node_exporter:node_exporter web.yml secret
chmod g+rx /opt/node_exporter/secret
chmod g+r /opt/node_exporter/secret/*
systemctl daemon-reload
systemctl restart node_exporter
systemctl status node_exporter
