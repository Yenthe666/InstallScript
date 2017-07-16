This script is based on the install script from André Schenkels (https://github.com/aschenkels-ictstudio/openerp-install-scripts)
but goes a bit further. This script will also give you the ability to define an xmlrpc_port in the .conf file that is generated under /etc/
This script can be safely used in a multi-odoo code base server because the default Odoo port is changed BEFORE the Odoo is started.

<h3>Installation procedure</h3>
- 1. Download the script:
```
sudo wget https://raw.githubusercontent.com/Yenthe666/InstallScript/All/odoo_install.sh
```
- 2. Modify the parameters as you wish.
There are a few things you can configure, this is the most used list:<br/>
```OE_USER``` will be the username for the system user.<br/>
```INSTALL_WKHTMLTOPDF``` set to ```False``` if you do not want to install it, if you want to install it you should set it to ```True```.<br/>
```OE_PORT``` is the port where Odoo should run on, for example 8069.<br/>
```OE_VERSION``` is the Odoo version to install, for example ```9.0``` for Odoo V9.<br/>
```IS_ENTERPRISE``` will install the Enterprise version on top of ```9.0``` if you set it to ```True```, set it to ```False``` if you want the community version of Odoo 9.<br/>
```OE_SUPERADMIN``` is the master password for this Odoo installation.<br/>
- 3. Make the script executable
```
sudo chmod +x odoo_install.sh
```
- 4. Execute the script:
```
sudo ./odoo_install.sh
```
