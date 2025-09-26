#!/bin/bash

# Odoo Installation Script for Debian/Ubuntu
#
# This script automates the installation of Odoo on a Debian/Ubuntu based system.
#
# To run this script:
# 1. Download it: wget <raw_github_link_to_this_script> -O install_odoo.sh
# 2. Make it executable: chmod +x install_odoo.sh
# 3. Run it: ./install_odoo.sh
#
# IMPORTANT: Review this script before running it on your system.
# Some commands require sudo privileges and will modify your system.
# It is recommended to run this script on a fresh Debian/Ubuntu installation.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Starting Odoo installation script..."

# Step 1: Update and Upgrade System Packages
echo "Step 1: Updating and upgrading system packages..."
sudo apt-get update
sudo apt-get upgrade -y
echo "System packages updated and upgraded successfully."

# Step 2: Install Essential Dependencies
echo "Step 2: Installing essential dependencies..."
sudo apt-get install -y python3-pip
sudo apt-get install -y python3-dev libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev

# Create a symbolic link for nodejs if it doesn't exist
if [ ! -f /usr/bin/node ]; then
  echo "Creating symbolic link for nodejs..."
  sudo ln -s /usr/bin/nodejs /usr/bin/node
fi

sudo npm install -g less less-plugin-clean-css
sudo apt-get install -y node-less
echo "Essential dependencies installed successfully."

# Step 3: Install and Configure PostgreSQL
echo "Step 3: Installing and configuring PostgreSQL..."
sudo apt-get install -y postgresql

echo "Creating PostgreSQL user for Odoo..."
sudo su - postgres -c "createuser --createdb --username postgres --no-createrole --superuser odoo18"

# IMPORTANT: This script uses a default password '123456' for the PostgreSQL user 'odoo18'.
# It is STRONGLY recommended to change this password for security reasons.
# You will also need to update the 'db_password' in the Odoo configuration file (/etc/odoo18.conf) if you change it.
echo "Setting password for PostgreSQL user 'odoo18'. You might be prompted by PostgreSQL."
echo "Using default password '123456'. Please change this in a production environment."
sudo su - postgres -c "psql -c \"ALTER USER odoo18 WITH PASSWORD '123456';\""
echo "PostgreSQL installed and configured successfully."

# Step 4: Create Odoo System User
echo "Step 4: Creating Odoo system user..."
sudo adduser --system --home=/opt/odoo18 --group odoo18
echo "Odoo system user created successfully."

# Step 5: Download Odoo Source Code
echo "Step 5: Downloading Odoo source code..."
sudo apt-get install -y git
echo "Cloning Odoo repository (this may take some time)..."
# Create the directory /opt/odoo18 if it doesn't exist and set ownership
sudo mkdir -p /opt/odoo18
sudo chown odoo18:odoo18 /opt/odoo18
sudo su - odoo18 -s /bin/bash -c "git clone https://www.github.com/odoo/odoo --depth 1 --branch master --single-branch /opt/odoo18"
echo "Odoo source code downloaded successfully."

# Step 6: Set Up Python Virtual Environment
echo "Step 6: Setting up Python virtual environment..."
sudo apt-get install -y python3-venv
sudo python3 -m venv /opt/odoo18/venv
echo "Python virtual environment created. Installing Python dependencies..."
sudo /opt/odoo18/venv/bin/pip install -r /opt/odoo18/requirements.txt
echo "Python dependencies installed successfully."

# Step 7: Install wkhtmltopdf
echo "Step 7: Installing wkhtmltopdf..."
# Download libssl1.1 - necessary for wkhtmltopdf 0.12.5 on newer Ubuntu versions
echo "Downloading libssl1.1..."
sudo wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb -P /tmp/
echo "Installing libssl1.1..."
sudo dpkg -i /tmp/libssl1.1_1.1.1f-1ubuntu2_amd64.deb

echo "Downloading wkhtmltopdf..."
sudo wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb -P /tmp/
echo "Installing xfonts-75dpi..."
sudo apt-get install -y xfonts-75dpi
echo "Installing wkhtmltopdf..."
sudo dpkg -i /tmp/wkhtmltox_0.12.5-1.bionic_amd64.deb

echo "Fixing any potential dependency issues..."
sudo apt-get install -f -y

echo "Cleaning up downloaded .deb files..."
sudo rm /tmp/*.deb
echo "wkhtmltopdf installed successfully."

# Step 8: Configure Odoo
echo "Step 8: Configuring Odoo..."
sudo cp /opt/odoo18/debian/odoo.conf /etc/odoo18.conf

echo "Modifying Odoo configuration file (/etc/odoo18.conf)..."
sudo sed -i "s/^admin_passwd = .*/admin_passwd = admin/" /etc/odoo18.conf
# Ensure db_host, db_port, db_user, db_password are set or add them if not present
sudo sed -i "/^db_host = .*/c\db_host = localhost" /etc/odoo18.conf
sudo sed -i "/^db_port = .*/c\db_port = 5432" /etc/odoo18.conf
sudo sed -i "/^db_user = .*/c\db_user = odoo18" /etc/odoo18.conf
# IMPORTANT: The password '123456' below MUST match the password set for the PostgreSQL user 'odoo18'.
# If you changed the PostgreSQL password, update it here as well.
sudo sed -i "/^db_password = .*/c\db_password = 123456" /etc/odoo18.conf
# Add addons_path if it doesn't exist, or replace it
if grep -q "^addons_path =" /etc/odoo18.conf; then
    sudo sed -i "s|^addons_path = .*|addons_path = /opt/odoo18/addons,/opt/odoo18/odoo/addons|" /etc/odoo18.conf
else
    echo "addons_path = /opt/odoo18/addons,/opt/odoo18/odoo/addons" | sudo tee -a /etc/odoo18.conf
fi
# Add logfile if it doesn't exist, or replace it
if grep -q "^logfile =" /etc/odoo18.conf; then
    sudo sed -i "s|^logfile = .*|logfile = /var/log/odoo/odoo18.log|" /etc/odoo18.conf
else
    echo "logfile = /var/log/odoo/odoo18.log" | sudo tee -a /etc/odoo18.conf
fi
# Add default_productivity_apps if it doesn't exist, or replace it
if grep -q "^default_productivity_apps =" /etc/odoo18.conf; then
    sudo sed -i "s/^default_productivity_apps = .*/default_productivity_apps = True/" /etc/odoo18.conf
else
    echo "default_productivity_apps = True" | sudo tee -a /etc/odoo18.conf
fi

echo "Setting ownership and permissions for Odoo configuration file..."
sudo chown odoo18: /etc/odoo18.conf
sudo chmod 640 /etc/odoo18.conf
echo "Odoo configured successfully."

# Step 9: Set Up Logging
echo "Step 9: Setting up logging..."
sudo mkdir -p /var/log/odoo
sudo chown odoo18:root /var/log/odoo
echo "Logging setup successfully."

# Step 10: Create Systemd Service File
echo "Step 10: Creating Systemd service file..."
sudo tee /etc/systemd/system/odoo18.service <<EOF
[Unit]
Description=Odoo18
Documentation=http://www.odoo.com
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
User=odoo18
Group=odoo18
ExecStart=/opt/odoo18/venv/bin/python3 /opt/odoo18/odoo-bin -c /etc/odoo18.conf
StandardOutput=journal+console
StandardError=journal+console
SyslogIdentifier=odoo18

[Install]
WantedBy=multi-user.target
EOF

echo "Setting permissions and ownership for Systemd service file..."
sudo chmod 755 /etc/systemd/system/odoo18.service
sudo chown root: /etc/systemd/system/odoo18.service
echo "Systemd service file created successfully."

# Step 11: Enable and Start Odoo Service
echo "Step 11: Enabling and starting Odoo service..."
sudo systemctl daemon-reload
sudo systemctl enable odoo18.service
sudo systemctl start odoo18.service
echo "Odoo service enabled and started."

echo "Checking Odoo service status (optional)..."
sudo systemctl status odoo18.service

echo "----------------------------------------------------------------"
echo "Odoo installation script finished!"
echo " "
echo "Odoo should now be running."
echo "You can check its status with: sudo systemctl status odoo18.service"
echo "Access Odoo via your web browser: http://<your_server_ip>:8069"
echo " "
echo "Default Odoo admin password (master password for managing databases): admin"
echo "Default PostgreSQL user 'odoo18' password: '123456' (Change this!)"
echo "Odoo configuration file: /etc/odoo18.conf"
echo "Odoo log file: /var/log/odoo/odoo18.log"
echo "Odoo addons path: /opt/odoo18/addons, /opt/odoo18/odoo/addons"
echo "Odoo source code: /opt/odoo18"
echo "Odoo Python virtual environment: /opt/odoo18/venv"
echo "----------------------------------------------------------------"

exit 0
