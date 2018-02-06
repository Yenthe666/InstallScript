#!/bin/bash
################################################################################
# Script for installing Odoo 11 on OpenSUSE 42.2 (could be used for other version too)
# Author: Yenthe Van Ginneken
# Author: Aswa Paul
#-------------------------------------------------------------------------------
# This script will install Odoo on your OpenSUSE OS. It can install multiple Odoo instances
# in one OS because of the different xmlrpc_ports
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
OE_USER="openerp"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
#The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
#Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
#Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
#Choose the Odoo version which you want to install. For example: 11.0, 10.0, 9.0 or saas-18. When using 'master' the master version will be installed.
#IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 11.0
OE_VERSION="7.0"
# Set this to True if you want to install Odoo 11 Enterprise!
IS_ENTERPRISE="True"
#set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}-server"
OE_SERVICE="${OE_USER}.service"

##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltox installed, for a danger note refer to 
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
WKHTMLTOX_X64=https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-centos7-amd64.rpm
WKHTMLTOX_X32=https://downloads.wkhtmltopdf.org/0.12/0.12.1/wkhtmltox-0.12.1_linux-centos6-i386.rpm
#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo zypper update
sudo zypper up 

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
sudo zypper install -y postgresql 

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
sudo zypper install python3 python3-pip python-devel python3-devel bzr python-suds libxml2-devel libxslt-devel mc make gcc 

sudo zypper install -y libxslt

echo -e "\n---- Install tool packages ----"
sudo zypper install -y wget git bzr python-pip

echo -e "\n---- Install PyChart ----"
sudo zypper addrepo https://download.opensuse.org/repositories/spins:invis:common/openSUSE_Leap_42.3/spins:invis:common.repo
sudo zypper refresh
sudo zypper install -y python-PyChart

echo -e "\n---- Install python libraries ----"
sudo zypper install python3-suds

echo -e "\n---- Install python packages ----"
sudo pip3 install PyPDF2 PyWebDAV
sudo pip3 install python-dateutil docutils feedparser jinja2 ldap lxml mako mock
sudo pip3 install python-openid psycopg2 psutil babel pydot pyparsing reportlab simplejson pytz 
sudo pip3 install unittest2 vatnumber vobject pywebdav werkzeug xlwt pyyaml pypdf passlib decorator
sudo pip3 install markupsafe pyusb pyserial paramiko utils pdftools requests xlsxwriter
sudo pip3 install psycogreen ofxparse gevent argparse pyOpenSSL>=16.2.0 lessc
sudo pip3 install pypdf2 Babel Werkzeug html2text Pillow>=3.4.2 ninja2 gdata XlsxWriter ebaysdk suds-jurko greenlet xlrd 

echo -e "\n--- Install other required packages" 
sudo zypper install -y python-gevent 

sudo ln -s /usr/local/bin/lessc /usr/bin/lessc

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
  sudo zypper in `basename $_url`
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

echo -e "\n---- Create ODOO system user ----"
sudo groupadd $OE_USER
sudo useradd -r --shell /bin/bash -d $OE_HOME -m -g $OE_USER $OE_USER
#The user should also be added to the sudo'ers group.
sudo usermod -a -G root $OE_USER  # Edit appropriately

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo "$OE_HOME_EXT/"

if [ $IS_ENTERPRISE == "True" ]; then
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
    sudo zypper install nodejs npm
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "\n---- Create custom module directory ----"
sudo mkdir $OE_HOME/custom
sudo mkdir $OE_HOME/custom/addons

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"

sudo touch /etc/${OE_CONFIG}.conf
echo -e "* Creating server config file"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'db_host = False\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'db_port = False\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'db_user = ${OE_USER}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'db_password = False\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"
if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

#--------------------------------------------------
# Adding ODOO as a deamon (systemd)
#--------------------------------------------------

echo -e "* Create init file"

cat <<EOF > ~/$OE_SERVICE
[Unit]
Description=Odoo Server Service
Requires=postgresql.service
After=network.target

[Service]
Type=simple
User=$OE_USER
WorkingDirectory=$OE_HOME
ExecStart=$OE_HOME_EXT/$OE_CONFIG --config=/etc/openerp-server.conf

[Install]
WantedBy=multi-user.target
EOF

echo -e "* Systemd Service"
sudo mv ~/$OE_SERVICE /etc/systemd/system/$OE_SERVICE
sudo chmod 664 /etc/systemd/system/$OE_SERVICE
sudo chown root: /etc/systemd/system/$OE_SERVICE

echo -e "* Starting Odoo Service"
sudo systemctl start $OE_SERVICE
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_USER"
echo "Addons folder: $OE_USER/$OE_CONFIG/addons/"
echo "Start Odoo service: sudo systemctl start $OE_SERVICE"
echo "Stop Odoo service: sudo systemctl stop $OE_SERVICE"
echo "Restart Odoo service: sudo systemctl restart $OE_SERVICE"
echo "-----------------------------------------------------------"
