#!/bin/bash
################################################################################
# Script for installing Odoo V10 on Ubuntu 16.04, 15.04, 14.04 (could be used for other version too)
# Author: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 14.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
#  nano odoo-install.sh
# Place this content in it and then make the file executable:
#  chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################

##fixed parameters


#Hostname
OE_HOST="scopea.fr"
OE_SUBDOMAIN="demo10"
OE_HOSTNAME="${OE_SUBDOMAIN}.${OE_HOST}"





#--------------------------------------------------
# Adding Caddy 
#-------------------------------------------------
echo -e "\n---- Update Server ----"
apt-get update >>  /dev/null 2>./install_log
echo -e "\n---- Upgrade Server ----"
apt-get upgrade -y >>  /dev/null 2>./install_log
echo -e "\n---- Install Curl ----"
apt-get install curl -y

mkdir /etc/caddy/ >>  /dev/null 2>./install_log
cat <<EOF > /etc/caddy/Caddyfile
$OE_HOSTNAME { # URL..
  proxy / http://127.0.0.1:8069 { # Port..
    header_upstream Host {host}
    }
  proxy /longpolling http://127.0.0.1:8072 { # On touche pas..
    header_upstream Host {host}
    }
  gzip
}

EOF

curl https://getcaddy.com | bash >>  /dev/null 2>./install_log
setcap cap_net_bind_service=+ep /usr/local/bin/caddy >>  /dev/null 2>./install_log

cat <<EOF > /etc/systemd/system/caddy.service
[Unit]
Description=Caddy webserver
Documentation=https://caddyserver.com/
After=network.target

[Service]
User=caddy
Group=caddy
WorkingDirectory=/etc/caddy
LimitNOFILE=8192
ExecStart=/usr/local/bin/caddy -agree -email contact@$OE_HOST -conf=/etc/caddy/Caddyfile
#Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start caddy.service 
systemctl enable caddy.service