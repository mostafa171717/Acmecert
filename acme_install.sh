#!/bin/bash

# Clone the acme.sh repository
git clone https://github.com/acmesh-official/acme.sh
cd acme.sh

# Make the script executable and install it
chmod +x acme.sh
./acme.sh --install --home /opt/acme --no-profile \
   --accountemail noreply@valeo.com --log /var/log/acme.sh.log

# Create directories and files
mkdir -p /opt/node_exporter/secret
touch /opt/node_exporter/secret/{private.key,server.cer,fullchain.cer}

# Change file permission
chmod 600 /opt/node_exporter/secret/private.key

# Modify the user shell
usermod -s /sbin/nologin node_exporter

# Create a systemd service for Node Exporter
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

# Install socat
apt install socat -y

# Set the default CA server and issue a certificate
/opt/acme/acme.sh --home /opt/acme --set-default-ca  --server \
https://certms.vnet.valeo.com/acme/valeo/directory
/opt/acme/acme.sh --home /opt/acme --issue --domain `hostname` --standalone --insecure --force

# Install the certificate
/opt/acme/acme.sh --home /opt/acme --install-cert -d `hostname` --cert-file /opt/node_exporter/secret/server.cer --key-file /opt/node_exporter/secret/private.key --fullchain-file /opt/node_exporter/secret/fullchain.cer

# Create a config file for the web server
echo 'tls_server_config:
  cert_file: /opt/node_exporter/secret/fullchain.cer
  key_file: /opt/node_exporter/secret/private.key
' > /opt/node_exporter/web.yml

# Change ownership and permissions
cd /opt/node_exporter
chown -R node_exporter:node_exporter web.yml secret
chmod g+rx /opt/node_exporter/secret
chmod g+r /opt/node_exporter/secret/*

# Reload systemd, restart the service and check its status
systemctl daemon-reload
systemctl restart node_exporter
systemctl status node_exporter