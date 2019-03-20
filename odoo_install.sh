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

##fixed parameters
#odoo
OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
#The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
#Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
#Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
#Choose the Odoo version which you want to install. For example: 11.0, 10.0, 9.0 or saas-18. When using 'master' the master version will be installed.
#IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 11.0
OE_VERSION="11.0"
# Set this to True if you want to install Odoo 11 Enterprise!
IS_ENTERPRISE="False"
#set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}-server"
DOMAIN="codefish.com.eg"
OCA="True"
SAAS="True"

##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltox installed, for a danger note refer to 
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
WKHTMLTOX_X64=https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-amd64.deb
WKHTMLTOX_X32=https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-i386.deb


#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo add-apt-repository "deb http://mirrors.kernel.org/ubuntu/ xenial main"
sudo apt-get update
sudo apt-get upgrade -y

#----------------------------------------------------------
#  tools and libraries required to build Odoo dependencies
#----------------------------------------------------------
echo -e "\n---- install tools and libraries required ----"
sudo apt-get install libpng12-0
sudo apt install -y libxslt1-dev git python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less
sudo apt-get -y install python3-dev libmysqlclient-dev libxmlsec1-dev

#----------------------------------------------------------
#  install apache server and config proxy
#----------------------------------------------------------
echo -e "\n---- install apache server and config proxy ----"
sudo apt install apache2
sudo ufw allow 'Apache'
sudo systemctl status apache2
a2enmod proxy
a2enmod proxy_http

echo -e "\n---- install apache server and config proxy ----"
sudo touch /etc/apache2/sites-available/$DOMAIN.conf

echo -e "* Creating apache - domain config file"
sudo su root -c "printf '<VirtualHost *:80>\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '        ServerName codefish.com.eg\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '        ServerAlias *.codefish.com.eg\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf ' \n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '        ProxyRequests Off\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '        <Proxy *>\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '                Order deny,allow\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '                Allow from all\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '        </Proxy>\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf ' \n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '        ProxyPass / http://localhost:8069/\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '        ProxyPassReverse / http://localhost:8069/\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '        ProxyPass /longpolling/ http://localhost:8072/\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '        ProxyPassReverse /longpolling/ http://localhost:8072/\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '        <Location />\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '                Order allow,deny\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '                Allow from all]\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '        </Location>\n' >> /etc/apache2/sites-available/$DOMAIN.conf"
sudo su root -c "printf '</VirtualHost>\n' >> /etc/apache2/sites-available/$DOMAIN.conf"

echo -e "* Creating apache - ssl - domain config file"
sudo touch /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf

sudo su root -c "printf '<IfModule mod_ssl.c>\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '<VirtualHost *:443>\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	ServerName $DOMAIN\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	ServerAlias *.$DOMAIN\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	#Header set Access-Control-Allow-Origin "*"\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	#Header append Access-Control-Allow-Methods "OPTIONS"\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	ProxyRequests Off\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	SSLProxyEngine on\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	SSLEngine on\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	<Proxy *>\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '		Order deny,allow\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '		Allow from all\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '		</Proxy>\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	#RequestHeader set Access-Control-Allow-Origin "*"\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	#RequestHeader append Access-Control-Allow-Methods "OPTIONS"\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	ProxyPass / http://localhost:8069/\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	ProxyPassReverse / http://localhost:8069/\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	ProxyPass /longpolling/ http://localhost:8072/\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	ProxyPassReverse /longpolling/ http://localhost:8072/\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	<Location />\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '		Order allow,deny\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '		Allow from all\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	</Location>\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	Include /etc/letsencrypt/options-ssl-apache.conf\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	RequestHeader set "X-Forwarded-Proto""https"\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/fullchain.pem\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '	Include /etc/letsencrypt/options-ssl-apache.conf\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '</VirtualHost>\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"
sudo su root -c "printf '</IfModule>\n' >> /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf"

ln -s /etc/apache2/sites-available/$DOMAIN.conf /etc/apache2/sites-enabled/$DOMAIN.conf
ln -s /etc/apache2/sites-available/000-$DOMAIN-le-ssl.conf /etc/apache2/sites-enabled/000-$DOMAIN-le-ssl.conf
sudo systemctl restart apache2
sudo systemctl status apache2


#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
sudo apt-get install postgresql -y

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt-get install python3 python3-pip

echo -e "\n---- Install tool packages ----"
sudo apt-get install wget git bzr python-pip gdebi-core -y

echo -e "\n---- Install python packages ----"
sudo apt-get install python-pypdf2 python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil -y
sudo pip3 install pypdf2 Babel passlib Werkzeug decorator python-dateutil pyyaml psycopg2 psutil html2text docutils lxml pillow reportlab ninja2 requests gdata XlsxWriter vobject python-openid pyparsing pydot mock mako Jinja2 ebaysdk feedparser xlwt psycogreen suds-jurko pytz pyusb greenlet xlrd 

echo -e "\n---- Install python libraries ----"
# This is for compatibility with Ubuntu 16.04. Will work on 14.04, 15.04 and 16.04
sudo apt-get install python3-suds

echo -e "\n--- Install other required packages"
sudo apt-get install node-clean-css -y
sudo apt-get install node-less -y
sudo apt-get install python-gevent -y

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 11 ----"
  #pick up correct one from x64 & x32 versions:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n `basename $_url`
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    echo -e "\n--- Create symlink for node"
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

    echo -e "\n---- Added Enterprise code under $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    sudo pip3 install num2words ofxparse
    apt-get install -y npm
    sudo apt-get install nodejs npm
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "\n---- Create custom module directory ----"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"

sudo touch /etc/${OE_CONFIG}.conf
echo -e "* Creating server config file"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"
if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* Create startup file"
sudo su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/openerp-server --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo -e "* Create init file"
cat <<EOF > ~/$OE_CONFIG
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
PATH=/bin:/sbin:/usr/bin
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

echo -e "* Security Init File"
sudo mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
sudo chmod 755 /etc/init.d/$OE_CONFIG
sudo chown root: /etc/init.d/$OE_CONFIG

echo -e "* Start ODOO on Startup"
sudo update-rc.d $OE_CONFIG defaults

#--------------------------------------------------
# Adding ODOO as a Modules (initscript)
#--------------------------------------------------
echo -e "install odoo Modules"
cd  $OE_HOME/custom
if [ $OCA = "True" ]; then
  REPOS=( "${REPOS[@]}" "https://github.com/oca/account-analytic.git oca/account-analytic")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/account-budgeting.git oca/account-budgeting")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/account-closing.git oca/account-closing")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/account-consolidation.git oca/account-consolidation")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/account-financial-reporting.git oca/account-financial-reporting")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/account-financial-tools.git oca/account-financial-tools")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/account-fiscal-rule.git oca/account-fiscal-rule")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/account-invoice-reporting.git oca/account-invoice-reporting")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/account-invoicing.git oca/account-invoicing")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/account-payment.git oca/account-payment")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/account-reconcile.git oca/account-reconcile")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/bank-payment.git oca/bank-payment")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/bank-statement-import.git oca/bank-statement-import")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/commission.git oca/commission")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/community-data-files.git oca/community-data-files")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/connector.git oca/connector")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/connector-telephony.git oca/connector-telephony")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/contract.git oca/contract")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/credit-control.git oca/credit-control")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/crm.git oca/crm")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/currency.git oca/currency")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/data-protection.git oca/data-protection")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/ddmrp.git oca/ddmrp")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/delivery-carrier.git oca/delivery-carrier")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/e-commerce.git oca/e-commerce")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/edi.git oca/edi")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/event.git oca/event")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/field-service.git oca/field-service")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/geospatial.git oca/geospatial")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/hr.git oca/hr")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/hr-timesheet.git oca/hr-timesheet")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/iot.git oca/iot")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/knowledge.git oca/knowledge")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/management-system.git oca/management-system")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/manufacture.git oca/manufacture")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/manufacture-reporting.git oca/manufacture-reporting")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/margin-analysis.git oca/margin-analysis")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/mis-builder.git oca/mis-builder")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/multi-company.git oca/multi-company")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/operating-unit.git oca/operating-unit")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/partner-contact.git oca/partner-contact")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/pos.git oca/pos")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/product-attribute.git oca/product-attribute")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/product-kitting.git oca/product-kitting")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/product-variant.git oca/product-variant")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/project.git oca/project")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/project-reporting.git oca/project-reporting")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/purchase-reporting.git oca/purchase-reporting")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/purchase-workflow.git oca/purchase-workflow")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/queue.git oca/queue")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/reporting-engine.git oca/reporting-engine")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/report-print-send.git oca/report-print-send")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/sale-financial.git oca/sale-financial")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/sale-reporting.git oca/sale-reporting")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/sale-workflow.git oca/sale-workflow")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/server-auth.git oca/server-auth")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/server-backend.git oca/server-backend")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/server-brand.git oca/server-brand")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/server-env.git oca/server-env")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/server-tools.git oca/server-tools")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/server-ux.git oca/server-ux")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/social.git oca/social")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/stock-logistics-barcode.git oca/stock-logistics-barcode")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/stock-logistics-reporting.git oca/stock-logistics-reporting")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/stock-logistics-tracking.git oca/stock-logistics-tracking")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/stock-logistics-transport.git oca/stock-logistics-transport")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/stock-logistics-warehouse.git oca/stock-logistics-warehouse")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/stock-logistics-workflow.git oca/stock-logistics-workflow")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/vertical-community.git oca/vertical-community")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/vertical-construction.git oca/vertical-construction")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/vertical-edition.git oca/vertical-edition")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/vertical-hotel.git oca/vertical-hotel")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/vertical-isp.git oca/vertical-isp")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/vertical-ngo.git oca/vertical-ngo")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/vertical-travel.git oca/vertical-travel")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/web.git oca/web")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/webkit-tools.git oca/webkit-tools")
  REPOS=( "${REPOS[@]}" "https://github.com/oca/website.git oca/website")
fi
if [ $SAAS = "True" ]; then
  REPOS=( "${REPOS[@]}" "https://github.com/it-projects-llc/e-commerce.git it-projects-llc/e-commerce")
  REPOS=( "${REPOS[@]}" "https://github.com/it-projects-llc/pos-addons.git it-projects-llc/pos-addons")
  REPOS=( "${REPOS[@]}" "https://github.com/it-projects-llc/access-addons.git it-projects-llc/access-addons")
  REPOS=( "${REPOS[@]}" "https://github.com/it-projects-llc/website-addons.git it-projects-llc/website-addons")
  REPOS=( "${REPOS[@]}" "https://github.com/it-projects-llc/misc-addons.git it-projects-llc/misc-addons")
  REPOS=( "${REPOS[@]}" "https://github.com/it-projects-llc/mail-addons.git it-projects-llc/mail-addons")
  REPOS=( "${REPOS[@]}" "https://github.com/it-projects-llc/odoo-saas-tools.git it-projects-llc/odoo-saas-tools")
  REPOS=( "${REPOS[@]}" "https://github.com/it-projects-llc/odoo-telegram.git it-projects-llc/odoo-telegram")
fi

     
          if [[ "${REPOS}" != "" ]]
 then
     apt-get install -y git
 fi

 for r in "${REPOS[@]}"
 do
     eval "git clone --depth=1 -b ${OE_VERSION} $r" || echo "Cannot clone: git clone -b ${OE_VERSION} $r"
 done
 
 if [[ "${REPOS}" != "" ]]
 then
     chown -R ${OE_USER}:${OE_USER} $OE_HOME/custom || true
 fi
      ADDONS_PATH=`ls -d1 /odoo/custom/*/* | tr '\n' ','`
      ADDONS_PATH=`echo /odoo/odoo-server/addons,/odoo/custom/addons,$ADDONS_PATH | sed "s,//,/,g" | sed "s,/,\\\\\/,g" | sed "s,.$,,g" `
     sed -ibak "s/addons_path.*/addons_path = $ADDONS_PATH/" /etc/odoo-server.conf
echo -e "install odoo requirements"
 sudo pip3 install -r /$OE_USER/$OE_CONFIG/requirements.txt
 sudo pip3 install configparser
 sudo pip3 install future
 pip3 install PyXB
 pip3 install MySQL-python
 pip3 install -r oca/account-analytic/requirements.txt
 pip3 install -r oca/account-budgeting/requirements.txt
 pip3 install -r oca/account-closing/requirements.txt
 pip3 install -r oca/account-consolidation/requirements.txt
 pip3 install -r oca/account-financial-reporting/requirements.txt
 pip3 install -r oca/account-financial-tools/requirements.txt
 pip3 install -r oca/account-fiscal-rule/requirements.txt
 pip3 install -r oca/account-invoice-reporting/requirements.txt
 pip3 install -r oca/account-invoicing/requirements.txt
 pip3 install -r oca/account-payment/requirements.txt
 pip3 install -r oca/account-reconcile/requirements.txt
 pip3 install -r oca/bank-payment/requirements.txt
 pip3 install -r oca/bank-statement-import/requirements.txt
 pip3 install -r oca/commission/requirements.txt
 pip3 install -r oca/community-data-files/requirements.txt
 pip3 install -r oca/connector/requirements.txt
 pip3 install -r oca/connector-accountedge/requirements.txt
 pip3 install -r oca/connector-cmis/requirements.txt
 pip3 install -r oca/connector-ecommerce/requirements.txt
 pip3 install -r oca/connector-interfaces/requirements.txt
 pip3 install -r oca/connector-lims/requirements.txt
 pip3 install -r oca/connector-magento/requirements.txt
 pip3 install -r oca/connector-prestashop/requirements.txt
 pip3 install -r oca/connector-redmine/requirements.txt
 pip3 install -r oca/connector-sage/requirements.txt
 pip3 install -r oca/connector-salesforce/requirements.txt
 pip3 install -r oca/connector-telephony/requirements.txt
 pip3 install -r oca/contract/requirements.txt
 pip3 install -r oca/credit-control/requirements.txt
 pip3 install -r oca/crm/requirements.txt
 pip3 install -r oca/currency/requirements.txt
 pip3 install -r oca/data-protection/requirements.txt
 pip3 install -r oca/ddmrp/requirements.txt
 pip3 install -r oca/delivery-carrier/requirements.txt
 pip3 install -r oca/e-commerce/requirements.txt
 pip3 install -r oca/edi/requirements.txt
 pip3 install -r oca/event/requirements.txt
 pip3 install -r oca/field-service/requirements.txt
 pip3 install -r oca/geospatial/requirements.txt
 pip3 install -r oca/hr/requirements.txt
 pip3 install -r oca/hr-timesheet/requirements.txt
 pip3 install -r oca/iot/requirements.txt
 pip3 install -r oca/knowledge/requirements.txt
 pip3 install -r oca/l10n-argentina/requirements.txt
 pip3 install -r oca/l10n-belgium/requirements.txt
 pip3 install -r oca/l10n-brazil/requirements.txt
 pip3 install -r oca/l10n-canada/requirements.txt
 pip3 install -r oca/l10n-colombia/requirements.txt
 pip3 install -r oca/l10n-costa-rica/requirements.txt
 pip3 install -r oca/l10n-finland/requirements.txt
 pip3 install -r oca/l10n-france/requirements.txt
 pip3 install -r oca/l10n-germany/requirements.txt
 pip3 install -r oca/l10n-luxemburg/requirements.txt
 pip3 install -r oca/l10n-mexico/requirements.txt
 pip3 install -r oca/l10n-netherlands/requirements.txt
 pip3 install -r oca/l10n-spain/requirements.txt
 pip3 install -r oca/l10n-switzerland/requirements.txt
 pip3 install -r oca/l10n-venezuela/requirements.txt
 pip3 install -r oca/management-system/requirements.txt
 pip3 install -r oca/manufacture/requirements.txt
 pip3 install -r oca/manufacture-reporting/requirements.txt
 pip3 install -r oca/margin-analysis/requirements.txt
 pip3 install -r oca/mis-builder/requirements.txt
 pip3 install -r oca/multi-company/requirements.txt
 pip3 install -r oca/node_modules/requirements.txt
 pip3 install -r oca/operating-unit/requirements.txt
 pip3 install -r oca/partner-contact/requirements.txt
 pip3 install -r oca/pos/requirements.txt
 pip3 install -r oca/product-attribute/requirements.txt
 pip3 install -r oca/product-kitting/requirements.txt
 pip3 install -r oca/product-variant/requirements.txt
 pip3 install -r oca/project/requirements.txt
 pip3 install -r oca/project-reporting/requirements.txt
 pip3 install -r oca/purchase-reporting/requirements.txt
 pip3 install -r oca/purchase-workflow/requirements.txt
 pip3 install -r oca/queue/requirements.txt
 pip3 install -r oca/reporting-engine/requirements.txt
 pip3 install -r oca/report-print-send/requirements.txt
 pip3 install -r oca/rma/requirements.txt
 pip3 install -r oca/sale-financial/requirements.txt
 pip3 install -r oca/sale-reporting/requirements.txt
 pip3 install -r oca/sale-workflow/requirements.txt
 pip3 install -r oca/server-auth/requirements.txt
 pip3 install -r oca/server-backend/requirements.txt
 pip3 install -r oca/server-brand/requirements.txt
 pip3 install -r oca/server-env/requirements.txt
 pip3 install -r oca/server-tools/requirements.txt
 pip3 install -r oca/server-ux/requirements.txt
 pip3 install -r oca/social/requirements.txt
 pip3 install -r oca/stock-logistics-barcode/requirements.txt
 pip3 install -r oca/stock-logistics-reporting/requirements.txt
 pip3 install -r oca/stock-logistics-tracking/requirements.txt
 pip3 install -r oca/stock-logistics-transport/requirements.txt
 pip3 install -r oca/stock-logistics-warehouse/requirements.txt
 pip3 install -r oca/stock-logistics-workflow/requirements.txt
 pip3 install -r oca/vertical-community/requirements.txt
 pip3 install -r oca/vertical-construction/requirements.txt
 pip3 install -r oca/vertical-edition/requirements.txt
 pip3 install -r oca/vertical-hotel/requirements.txt
 pip3 install -r oca/vertical-isp/requirements.txt
 pip3 install -r oca/vertical-ngo/requirements.txt
 pip3 install -r oca/vertical-travel/requirements.txt
 pip3 install -r oca/web/requirements.txt
 pip3 install -r oca/webkit-tools/requirements.txt
 pip3 install -r oca/website/requirements.txt

echo -e "* Starting Odoo Service"
sudo su root -c "/etc/init.d/$OE_CONFIG start"
#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_USER"
echo "Addons folder: $OE_USER/$OE_CONFIG/addons/"
echo "Start Odoo service: sudo service $OE_CONFIG start"
echo "Stop Odoo service: sudo service $OE_CONFIG stop"
echo "Restart Odoo service: sudo service $OE_CONFIG restart"
echo "-----------------------------------------------------------"
