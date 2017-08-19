#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 14.04, 15.04 and 16.04 (could be used for other version too)
# Author: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 14.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################
OE_USER=$(whiptail --inputbox "Odoo username?" 8 78 odoo --title "Odoo user" 3>&1 1>&2 2>&3)
exit_install=$?
if [ $exit_install = 0 ]; then
  echo "The system user will be named '$OE_USER'"
else
  echo "User cancelled installation script"
fi

OE_HOME=$(whiptail --inputbox "Home directory installation" 8 78 /$OE_USER --title "Home directory" 3>&1 1>&2 2>&3)
exit_home=$?
if [ $exit_home = 0 ]; then
  echo "Home directory will be '$OE_HOME'"
else
  echo "User cancelled installation script"
fi

if (whiptail --title "Wkhtmltopdf" --yesno "Install wkhtmltopdf on system?" 8 78) then
    echo "The user wants to install wkhtmltopdf"
    INSTALL_WKHTMLTOPDF="True"
else
    echo "The user does not want to install wkthmltopdf"
    INSTALL_WKHTMLTOPDF="False"
fi

OE_PORT=$(whiptail --inputbox "Odoo port" 8 78 8069 --title "Port to run Odoo on" 3>&1 1>&2 2>&3)
exit_oe_port=$?
if [ $exit_oe_port = 0 ]; then
  echo "Odoo will be installed on port '$OE_PORT'"
else
  echo "User cancelled installation script"
fi

OE_VERSION=$(whiptail --inputbox "Odoo version" 8 78 10.0 --title "Odoo version to install" 3>&1 1>&2 2>&3)
exit_oe_version=$?
if [ $exit_oe_version = 0 ]; then
  echo "Odoo version '$OE_VERSION' will be installed on your system."
else
  echo "User cancelled installation script"
fi

if (whiptail --title "Enterprise" --yesno "Install enterprise version?" 8 78) then
    echo "The user wants to install an enterprise version"
    IS_ENTERPRISE="True"
else
    echo "User selected no"
    IS_ENTERPRISE="False"
fi

OE_SUPERADMIN=$(whiptail --inputbox "Superadmin password" 8 78 admin --title "Master password for Odoo database" 3>&1 1>&2 2>&3)
exit_oe_superadmin=$?
if [ $exit_oe_superadmin = 0 ]; then
  echo "Master password for Odoo will be '$OE_SUPERADMIN'."
else
  echo "User cancelled installation script"
fi


##fixed parameters - please do not touch!
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
OE_CONFIG="${OE_USER}-server"


# Final warning
if (whiptail --title "Overview" --yesno "Is this configuration correct and do you wish to install your Odoo?\nOdoo username: $OE_USER \nInstall wkhtmltopdf: $INSTALL_WKHTMLTOPDF \nPort to run Odoo on: $OE_PORT\nOdoo version: $OE_VERSION \nInstall enterprise version: $IS_ENTERPRISE \nOdoo super admin password: $OE_SUPERADMIN" 20 100) then
    echo "The user wants to install Odoo"
    {
    for ((i = 0 ; i <= 100 ; i+=5)); do
        sleep 0.3
        echo $i
    done
    } | whiptail --gauge "Odoo would be installing now! :)" 6 50 0
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
else
    echo "The user does not want to install Odoo - aborted by user."
fi
