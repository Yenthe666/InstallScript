#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 14.04, 15.04, 16.04 and 18.04 (could be used for other version too)
# Author: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 16.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
OE_CONFIG="${OE_USER}-server"

# Choose the Odoo version which you want to install. For example: 13.0, 12.0, 11.0 or saas-18. When using 'master' the master version will be installed.
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 13.0
OE_VERSION="13.0"
# Set this to True if you want to install the Odoo enterprise version!
IS_ENTERPRISE="False"
# Set to "True" to generate a random password, "False" to use the variable in OE_SUPERADMIN
GENERATE_RANDOM_PASSWORD="True"
# Set the superadmin password - if GENERATE_RANDOM_PASSWORD is set to "True" we will automatically generate a random password, otherwise we use this one
OE_SUPERADMIN="admin"
# Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
# The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
# Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
# Set the default Odoo longpolling port (you still have to use -c /etc/odoo-server.conf for example to use this.)
LONGPOLLING_PORT="8072"

# Set the reverse proxy mode to PROXY_NONE, PROXY_HTTP, PROXY_LETSENCRYPT
PROXY_MODE="PROXY_LETSENCRYPT"

# Set the website name
WEBSITE_NAME="_"
# Provide Email to register ssl certificate
ADMIN_EMAIL="odoo@example.com"

##
## WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltopdf installed, for a danger note refer to
## https://github.com/odoo/odoo/wiki/Wkhtmltopdf ):
## https://www.odoo.com/documentation/12.0/setup/install.html#debian-ubuntu

WKHTMLTOX_X64=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.trusty_amd64.deb
WKHTMLTOX_X32=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.trusty_i386.deb

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----\n"
# universe package is for Ubuntu 18.x
sudo add-apt-repository universe
# libpng12-0 dependency for wkhtmltopdf
sudo add-apt-repository "deb http://mirrors.kernel.org/ubuntu/ xenial main"
sudo apt-get update
sudo apt-get upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----\n"
sudo apt-get install postgresql postgresql-server-dev-all -y

echo -e "\n---- Creating the ODOO PostgreSQL User ----\n"
sudo su - postgres -c "createuser -s $OE_USER" 2>/dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 ----\n"
sudo apt-get install git python3 python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng12-0 gdebi-core -y

echo -e "\n---- Install python packages/requirements ----\n"
sudo -H pip3 install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

echo -e "\n---- Installing nodeJS NPM and rtlcss for LTR support ----\n"
sudo apt-get install nodejs npm -y
sudo npm install -g rtlcss

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 13 ----\n"
  #pick up correct one from x64 & x32 versions:
  if [ "$(getconf LONG_BIT)" == "64" ]; then
    _url=$WKHTMLTOX_X64
  else
    _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n "$(basename $_url)"
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo -e "\n---- Wkhtmltopdf isn't installed due to the choice of the user! ----\n"
fi

echo -e "\n---- Create ODOO system user ----\n"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

echo -e "\n---- Create Log directory ----\n"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n---- Installing ODOO Server ----\n"
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
  # Odoo Enterprise install!
  echo -e "\n---- Create symlink for node ----\n"
  sudo ln -s /usr/bin/nodejs /usr/bin/node
  sudo su $OE_USER -c "mkdir $OE_HOME/enterprise"
  sudo su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

  GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
  while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
    echo "------------------------WARNING------------------------------"
    echo "Your authentication with Github has failed! Please try again."
    printf "In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
    echo "TIP: Press ctrl+c to stop this script."
    echo "-------------------------------------------------------------"
    echo " "
    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
  done

  echo -e "\n---- Added Enterprise code under $OE_HOME/enterprise/addons ----\n"
  echo -e "\n---- Installing Enterprise specific libraries ----\n"
  sudo -H pip3 install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
  sudo npm install -g less
  sudo npm install -g less-plugin-clean-css
fi

echo -e "\n---- Create custom module directory ----\n"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "\n---- Setting permissions on home folder ----\n"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "\n---- Create server config file ----\n"

sudo touch /etc/${OE_CONFIG}.conf
echo -e "\n---- Creating server config file ----\n"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
  echo -e "\n---- Generating random admin password ----\n"
  OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi

sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"

if [ $OE_VERSION \> "11.0" ]; then
  sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
else
  sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
fi

sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"

if [ $IS_ENTERPRISE = "True" ]; then
  sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
  sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi

sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo -e "\n---- Create startup file ----\n"
sudo su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo -e "\n---- Create init file ----\n"
cat <<EOF >~/$OE_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: $OE_CONFIG
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Enterprise Business Applications
# Description: ODOO Business Applications
### END INIT INFO
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
DAEMON=$OE_HOME_EXT/odoo-bin
NAME=$OE_CONFIG
DESC=$OE_CONFIG
# Specify the user name (Default: odoo).
USER=$OE_USER
# Specify an alternate config file (Default: /etc/openerp-server.conf).
CONFIGFILE="/etc/${OE_CONFIG}.conf"
# pidfile
PIDFILE=/var/run/\${NAME}.pid
# Additional options that are passed to the Daemon.
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}
case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

echo -e "\n---- Security Init File ----\n"
sudo mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
sudo chmod 755 /etc/init.d/$OE_CONFIG
sudo chown root: /etc/init.d/$OE_CONFIG

echo -e "\n---- Start ODOO on Startup ----\n"
sudo update-rc.d $OE_CONFIG defaults

#-----------------------------------------------------------------------
# PROXY_MODE != PROXY_NONE (Nginx will be install to port 80 and/or 443)
#-----------------------------------------------------------------------
if [ $PROXY_MODE != "PROXY_NONE" ]; then
  echo -e "\n---- Installing and setting up Nginx ----\n"
  sudo apt install nginx -y

  cat <<EOF >~/odoo
  upstream odoo {
     server                                   127.0.0.1:$OE_PORT;
  }
  
  upstream odoochat {
     server                                   127.0.0.1:$LONGPOLLING_PORT;
  }
  
  $(
    if [ "$PROXY_MODE" = "PROXY_HTTP" ]; then
      echo "# PROXY MODE USES HTTP"
      echo "  server {"
      echo "     listen 80;"
      echo "     server_name "$WEBSITE_NAME";"
    fi

    if [ "$PROXY_MODE" = "PROXY_LETSENCRYPT" ]; then
      echo "# PROXY MODE USES LETSENCRYPT"
      echo "  server {"
      echo "     listen 80;"
      echo "     server_name "$WEBSITE_NAME";"
      echo "  "
      echo "     rewrite ^(.*) https://\$host\$1 permanent;"
      echo "  }"
      echo "  "
      echo "  server {"
      echo "     listen 443 ssl http2;"
      echo "     server_name "$WEBSITE_NAME";"
      echo "  "
      echo "     include                                  snippets/ssl.conf;"
      echo "     include                                  snippets/letsencrypt.conf;"
    fi
  )
  
     # Add Headers for odoo proxy mode
     proxy_set_header X-Forwarded-Host        \$host;
     proxy_set_header X-Forwarded-For         \$proxy_add_x_forwarded_for;
     proxy_set_header X-Forwarded-Proto       \$scheme;
     proxy_set_header X-Real-IP               \$remote_addr;
     proxy_set_header X-Client-IP             \$remote_addr;
     proxy_set_header HTTP_X_FORWARDED_HOST   \$remote_addr;
     
     # odoo log files
     access_log                               /var/log/nginx/$OE_USER-access.log;
     error_log                                /var/log/nginx/$OE_USER-error.log;
     
     # increase proxy buffer size
     proxy_buffers                            16 64k;
     proxy_buffer_size                        128k;
     
     proxy_read_timeout                       900s;
     proxy_connect_timeout                    900s;
     proxy_send_timeout                       900s;
     
     # force timeouts if the backend dies
     proxy_next_upstream                      error timeout invalid_header http_500 http_502 http_503;
     
     types {
        text/less                             less;
        text/scss                             scss;
     }
     
     # enable data compression
     gzip                                     on;
     gzip_min_length                          1100;
     gzip_buffers                             4 32k;
     gzip_types                               text/css text/scss text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
     gzip_vary                                on;
     client_header_buffer_size                4k;
     large_client_header_buffers              4 64k;
     client_max_body_size                     0;
     
     location / {
        proxy_pass                            http://odoo;
        proxy_redirect                        off; # by default, do not forward anything
     }
     
     location /longpolling {
        proxy_pass                            http://odoochat;
     }
     
     location ~* .(js|css|png|jpg|jpeg|gif|ico)$ {
        expires                               2d;
        proxy_pass                            http://odoo;
        add_header Cache-Control              "public, no-transform";
     }
     
     # cache some static data in memory for 60mins.
     location ~ /[a-zA-Z0-9_-]*/static/ {
        proxy_cache_valid                     200 302 60m;
        proxy_cache_valid                     404 1m;
        proxy_buffering                       on;
        expires                               864000;
        proxy_pass                            http://odoo;
     }
  }
EOF

  sudo mv ~/odoo /etc/nginx/sites-available/
  sudo ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
  sudo rm /etc/nginx/sites-enabled/default
  if [ $PROXY_MODE = "PROXY_HTTP" ]; then
  sudo service nginx reload
  fi
  sudo su root -c "printf 'proxy_mode = True\n' >> /etc/${OE_CONFIG}.conf"
  echo -e "\n---- Done! The Nginx server is up and running on "$PROXY_MODE" ----\n"
  echo -e "\n---- Configuration can be found at /etc/nginx/sites-available/odoo ----\n"
fi

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------

if [ $PROXY_MODE = "PROXY_LETSENCRYPT" ] && [ $ADMIN_EMAIL != "odoo@example.com" ] && [ $WEBSITE_NAME != "_" ]; then
  echo -e "\n---- Installing and setting up Cerbot ----\n"
  sudo add-apt-repository ppa:certbot/certbot -y && sudo apt-get update -y
  sudo apt-get install python-certbot-nginx -y

  echo -e "\n---- Generating dhparam ----\n"
  sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
  sudo mkdir -p /var/lib/letsencrypt/.well-known
  sudo chgrp www-data /var/lib/letsencrypt
  sudo chmod g+s /var/lib/letsencrypt

  echo -e "\n---- Wrting snippets: ssl.conf + letsencrypt.conf ----\n"

  cat <<EOF >/etc/nginx/snippets/ssl.conf
ssl_dhparam                                    /etc/ssl/certs/dhparam.pem;

ssl_session_timeout                            1d;
ssl_session_cache                              shared:SSL:50m;
ssl_session_tickets                            off;

ssl_protocols                                  TLSv1 TLSv1.1 TLSv1.2;
ssl_ciphers                                    'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS';
ssl_prefer_server_ciphers                      on;

ssl_stapling                                   on;
ssl_stapling_verify                            on;
resolver                                       8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout                               30s;

add_header Strict-Transport-Security           "max-age=15768000; includeSubdomains; preload" always;
add_header X-Frame-Options                     SAMEORIGIN;
add_header X-Content-Type-Options              nosniff;
add_header X-XSS-Protection                    "1; mode=block";
EOF

  cat <<EOF >/etc/nginx/snippets/letsencrypt.conf
location ^~ /.well-known/acme-challenge/ {
  allow                    all;
  root                     /var/lib/letsencrypt/;
  default_type             "text/plain";
  try_files                \$uri =404;
}
EOF

  echo -e "\n---- Generating and installing SSL certificates ----\n"
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  sudo service nginx reload

  echo -e "\n---- SSL/HTTPS is enabled! ----\n"
  echo -e "\n---- Updating cron job to renew certificate ----\n"
  sudo sed -i 's/43200/3600/g' /etc/cron.d/certbot
  sudo sed -i 's/-q renew/-q renew --renew-hook "systemctl reload nginx"/g' /etc/cron.d/certbot

else
  echo -e "\n---- SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ----\n"
fi

echo -e "\n---- Starting Odoo Service ----\n"
sudo su root -c "/etc/init.d/$OE_CONFIG start"
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_USER"
echo "Addons folder: $OE_USER/$OE_CONFIG/addons/"
echo "Password superadmin (database): $OE_SUPERADMIN"
echo "Start Odoo service: sudo service $OE_CONFIG start"
echo "Stop Odoo service: sudo service $OE_CONFIG stop"
echo "Restart Odoo service: sudo service $OE_CONFIG restart"
if [ $PROXY_MODE != "PROXY_NONE" ]; then
  echo -e "\n---- Nginx configuration file: /etc/nginx/sites-available/odoo ----\n"
else
  echo -e "\n---- Nginx was not installed because PROXY_MODE is PROXY_NONE ----\n"
fi
echo "-----------------------------------------------------------"
