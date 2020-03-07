#!/bin/bash
################################################################################
# Script for uninstalling Odoo on Ubuntu 14.04, 15.04, 16.04 and 18.04 (could be used for other version too)
# Author: Tony Benoy
#-------------------------------------------------------------------------------
# This script will uninstall Odoo from your Ubuntu 16.04 server. 
#------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-uninstall.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-uninstall.sh
# Execute the script to install Odoo:
# ./odoo-uninstall
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
#The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
#Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
#Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
#Choose the Odoo version which you want to install. For example: 12.0,11.0, 10.0 or saas-18. When using 'master' the master version will be installed.
#IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 12.0
OE_VERSION="12.0"
# Set this to True if you want to uninstall Odoo Enterprise version!
IS_ENTERPRISE="False"
# Set this to True if you want to uninstall Nginx!
INSTALL_NGINX="False"

OE_CONFIG="${OE_USER}-server"

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Uninstall PostgreSQL Server ----"
sudo apt-get remove --purge postgresql -y
#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt-get remove --purge python3 python3-pip -y

echo -e "\n---- Install tool packages ----"
sudo apt-get remove --purge wget git bzr python-pip gdebi-core -y

echo -e "\n---- Install python packages ----"
sudo apt-get remove --purge libxml2-dev libxslt1-dev zlib1g-dev libpng12-0 -y
sudo apt-get remove --purge libsasl2-dev libldap2-dev libssl-dev -y
sudo apt-get remove --purge python-pypdf2 python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil -y
sudo pip3 uninstall pypdf2 Babel passlib Werkzeug decorator python-dateutil pyyaml psycopg2 psutil html2text docutils lxml pillow reportlab ninja2 requests gdata XlsxWriter vobject python-openid pyparsing pydot mock mako Jinja2 ebaysdk feedparser xlwt psycogreen suds-jurko pytz pyusb greenlet xlrd chardet libsass

echo -e "\n---- Install python libraries ----"
# This is for compatibility with Ubuntu 16.04. Will work on 14.04, 15.04 and 16.04
sudo apt-get install python3-suds

echo -e "\n--- Install other required packages"
sudo apt-get remove --purge node-clean-css -y
sudo apt-get remove --purge node-less -y
sudo apt-get remove --purge python-gevent -y
sudo rm -rf /odoo
sudo apt-get remove --purge nginx
sudo rm /etc/init.d/$OE_CONFIG
sudo rm /etc/${OE_CONFIG}.conf