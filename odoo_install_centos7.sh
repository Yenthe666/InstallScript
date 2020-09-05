#!/usr/bin/env bash
################################################################################
# Script for installing Odoo on Centos 7
# Based on installation script by Yenthe Van Ginneken https://github.com/Yenthe666/InstallScript
# Author: Fco. Javier Clavero Álvarez
#-------------------------------------------------------------------------------
# This script will install Odoo on your Centos 7 server. It can install multiple Odoo instances
# in one Centos because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# nano odoo-install.sh
# Place this content in it and then make the file executable:
# chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
# The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
# Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
# Choose the Odoo version which you want to install. For example: 13.0, 12.0, 11.0 or saas-18. When using 'master' the master version will be installed.
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 13.0
OE_VERSION="13.0"
# Set this to True if you want to install the Odoo enterprise version!
IS_ENTERPRISE="False"
# Set this to True if you want to install Nginx!
INSTALL_NGINX="False"
# Set the superadmin password - if GENERATE_RANDOM_PASSWORD is set to "True" we will automatically generate a random password, otherwise we use this one
OE_SUPERADMIN="admin"
# Set to "True" to generate a random password, "False" to use the variable in OE_SUPERADMIN
GENERATE_RANDOM_PASSWORD="True"
OE_CONFIG="${OE_USER}-server"
# Set the website name
WEBSITE_NAME="_"
# Set the default Odoo longpolling port (you still have to use -c /etc/odoo-server.conf for example to use this.)
LONGPOLLING_PORT="8072"

##
###  WKHTMLTOPDF download links
## === Centos 7 x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltopdf installed, for a danger note refer to
## https://github.com/odoo/odoo/wiki/Wkhtmltopdf ):
## https://www.odoo.com/documentation/13.0/setup/install.html#debian-ubuntu

WKHTMLTOX_X64=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox-0.12.5-1.centos7.x86_64.rpm
WKHTMLTOX_X32=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox-0.12.5-1.centos7.i686.rpm

#--------------------------------------------------
# Check run script as root
#--------------------------------------------------
if [ $EUID != 0 ]; then
    echo -ne "\nPlease re-run this script with sudo or as root\n\n"
    exit 1
fi

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
yum update -y
yum upgrade -y

#--------------------------------------------------
# Install Dependencies & Tools
#--------------------------------------------------
echo -e "\n--- Dependencies & Tools --"
yum install -y centos-release-scl gcc epel-release
yum install -y wget git libxslt-devel bzip2-devel openldap-devel libjpeg-devel freetype-devel nodejs

# ODOO < 12 use less and ODOO >=12 use sass (libsass)
if [ ${OE_VERSION//./} -lt 120 ]; then
    echo -e "\n--- Install other required packages"
    npm install -g less
    npm install -g less-plugin-clean-css
fi

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
# CentOS 7 includes PostgreSQL 9.2 in its default repositories
# Install PostgreSQL 10 from Software Collections (SCL)
# https://wiki.centos.org/AdditionalResources/Repositories/SCL
# https://www.softwarecollections.org/en/scls/rhscl/rh-postgresql10/

echo -e "\n---- Install PostgreSQL Server from SCL ----"
yum -y install rh-postgresql10-postgresql-server rh-postgresql10-postgresql-devel
scl enable rh-postgresql10 "postgresql-setup --initdb --unit rh-postgresql10-postgresql"
pgdata_path=/var/opt/rh/rh-postgresql10/lib/pgsql/data
grep -q '^local\s' $pgdata_path/pg_hba.conf | echo -e "local all all trust" | tee -a $pgdata_path/pg_hba.conf
sed -i.bak 's/\(^local\s*\w*\s*\w*\s*\)\(peer$\)/\1trust/' $pgdata_path/pg_hba.conf
systemctl enable rh-postgresql10-postgresql
systemctl start rh-postgresql10-postgresql

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
su - postgres -c "scl enable rh-postgresql10 -- psql -c 'create user $OE_USER createdb'"

#--------------------------------------------------
# Install Python
#--------------------------------------------------
# https://wiki.centos.org/AdditionalResources/Repositories/SCL
# https://www.softwarecollections.org/en/scls/rhscl/rh-python36/

echo -e "\n--- Installing Python 3 from SCL --"
yum install -y rh-python36

echo -e "\n---- Install python packages/requirements ----"
scl enable rh-python36 -- pip3.6 install pip -U
scl enable rh-python36 -- pip3.6 install wheel
scl enable rh-python36 -- pip3.6 install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

echo -e "\n---- Installing rtlcss for LTR support ----"
npm install -g rtlcss

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 13 ----"
  #pick up correct one from x64 & x32 versions:
  if [ "$(getconf LONG_BIT)" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  yum localinstall -y $_url

else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

echo -e "\n---- Create ODOO system user ----"
adduser --system --shell=/bin/bash --home-dir=$OE_HOME --user-group $OE_USER

#The user should also be added to the wheel group.
usermod -aG wheel $OE_USER

echo -e "\n---- Create Log directory ----"
mkdir /var/log/$OE_USER
chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    su $OE_USER -c "mkdir $OE_HOME/enterprise"
    su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- Added Enterprise code under $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    scl enable rh-python36 -- pip3.6 install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
fi

echo -e "\n---- Create custom module directory ----"
mkdir -p $OE_HOME/custom/addons

echo -e "\n---- Setting permissions on home folder ----"
chown -R $OE_USER:$OE_USER $OE_HOME/

echo -e "* Create server config file"
touch /etc/${OE_CONFIG}.conf
echo -e "* Creating server config file"
su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "* Generating random admin password"
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi
su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
if [ ${OE_VERSION//./} -ge 120 ]; then
    su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
else
    su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
fi
su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"

if [ $IS_ENTERPRISE = "True" ]; then
    su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi
chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* Create startup file"
su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
su root -c "echo 'su - $OE_USER -c \"scl enable rh-python36 -- python3 $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf\"' >> $OE_HOME_EXT/start.sh"
chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------
echo -e "* Create init file"
cat > /etc/systemd/system/$OE_CONFIG.service << EOF
[Unit]
Description=$OE_CONFIG
Requires=rh-postgresql10
After=network.target rh-postgresql10

[Service]
Type=simple
SyslogIdentifier=$OE_CONFIG
PermissionsStartOnly=true
User=$OE_USER
Group=$OE_USER
ExecStart=/usr/bin/scl enable rh-python36 -- $OE_HOME_EXT/odoo-bin -c /etc/$OE_CONFIG.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $OE_CONFIG

#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
  echo -e "\n---- Installing and setting up Nginx ----"
  yum install nginx -y
  systemctl enable nginx
  systemctl start nginx

  mkdir /etc/nginx/sites-available

  cat <<EOF > ~/odoo.conf
  server {
  listen 80;

  # set proper server name after domain set
  server_name $WEBSITE_NAME;

  # Add Headers for odoo proxy mode
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Real-IP \$remote_addr;
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-XSS-Protection "1; mode=block";
  proxy_set_header X-Client-IP \$remote_addr;
  proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

  #   odoo    log files
  access_log  /var/log/nginx/$OE_USER-access.log;
  error_log       /var/log/nginx/$OE_USER-error.log;

  #   increase    proxy   buffer  size
  proxy_buffers   16  64k;
  proxy_buffer_size   128k;

  proxy_read_timeout 900s;
  proxy_connect_timeout 900s;
  proxy_send_timeout 900s;

  #   force   timeouts    if  the backend dies
  proxy_next_upstream error   timeout invalid_header  http_500    http_502
  http_503;

  types {
  text/less less;
  text/scss scss;
  }

  #   enable  data    compression
  gzip    on;
  gzip_min_length 1100;
  gzip_buffers    4   32k;
  gzip_types  text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
  gzip_vary   on;
  client_header_buffer_size 4k;
  large_client_header_buffers 4 64k;
  client_max_body_size 0;

  location / {
  proxy_pass    http://127.0.0.1:$OE_PORT;
  # by default, do not forward anything
  proxy_redirect off;
  }

  location /longpolling {
  proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
  }
  location ~* .(js|css|png|jpg|jpeg|gif|ico)$ {
  expires 2d;
  proxy_pass http://127.0.0.1:$OE_PORT;
  add_header Cache-Control "public, no-transform";
  }
  # cache some static data in memory for 60mins.
  location ~ /[a-zA-Z0-9_-]*/static/ {
  proxy_cache_valid 200 302 60m;
  proxy_cache_valid 404      1m;
  proxy_buffering    on;
  expires 864000;
  proxy_pass    http://127.0.0.1:$OE_PORT;
  }
  }
EOF

mv ~/odoo.conf /etc/nginx/sites-available/
ln -s /etc/nginx/sites-available/odoo.conf /etc/nginx/conf.d/odoo.conf
echo -e "* SELinux permission"
setsebool -P httpd_can_network_connect 1
restorecon /etc/nginx/conf.d/*
systemctl reload nginx
su root -c "printf 'proxy_mode = True\n' >> /etc/${OE_CONFIG}.conf"

# Firewalld by default and blocks access to ports 80 and 443
echo -e "* enables ports 80 and 443"
firewall-cmd --zone=public --permanent --add-service=http
firewall-cmd --zone=public --permanent --add-service=https
firewall-cmd --reload
echo "Done! The Nginx server is up and running. Configuration can be found at /etc/nginx/sites-available/odoo.conf"
else
  echo "Nginx isn't installed due to choice of the user!"
fi

echo -e "* Starting Odoo Service"
systemctl start $OE_CONFIG
echo -e "* Opening Odoo Port in firewalld"
firewall-cmd --permanent --zone=public --add-port=${OE_PORT}/tcp
firewall-cmd --reload
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "Configuraton file location: /etc/${OE_CONFIG}.conf"
echo "Logfile location: /var/log/$OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_USER"
echo "Addons folder: $OE_USER/$OE_CONFIG/addons/"
echo "Password superadmin (database): $OE_SUPERADMIN"
echo "Start Odoo service: sudo systemctl start $OE_CONFIG"
echo "Stop Odoo service: sudo systemctl stop $OE_CONFIG"
echo "Restart Odoo service: sudo systemctl restart $OE_CONFIG"
if [ $INSTALL_NGINX = "True" ]; then
  echo "Nginx configuration file: /etc/nginx/sites-available/odoo"
fi
echo "-----------------------------------------------------------"
