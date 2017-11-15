#!/usr/bin/env bash
################################################################################
# Script for installing Odoo on Ubuntu 14.04, 15.04 and 16.04 (could be used for other version too)
# Authors: Yenthe Van Ginneken, Chris Coleman (EspaceNetworks)
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
versiondate="2018-02-26a"

##fixed parameters
OE_USER="odoo"
OE_HOME="/home/${OE_USER}"
OE_HOME_EXT="${OE_HOME}/${OE_USER}-server"
#The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
#Set the default Odoo port (you still have to use -c /etc/odoo/odoo-server.conf for example to use this.)
OE_PORT="8069"
#Set to True if you want to install it, False if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
#Choose the Odoo version which you want to install. For example: 11.0, 10.0, 9.0 or saas-18. 
#When using 'master' the master version will be installed.
#IMPORTANT! This script installs packages and libraries that are needed by Odoo.
OE_VERSION="11.0"
# Set this to True to install Enterprise version (modules). 
# NOTE: To install Enterprise, your github login must be associated with an Odoo subscription, or with an Odoo Partnership!
IS_ENTERPRISE="False"
#set the superadmin password
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}-server"
OE_RUN_SERVICE_AS_SUPERADMIN="False"
INSTALL_LOG="./${OE_USER}_install.log"
INSTALL_LOG_REDIRECT="$INSTALL_LOG 2>&1"
OE_ENTERPRISE_ADDONS="${OE_HOME}/enterprise/addons"
OE_CUSTOM_ADDONS="${OE_HOME}/custom/addons"

###  WKHTMLTOPDF version
## Generic version (embeds libjpeg and libpng) for all distros.
## The generic linux binaries should work fine across all distributions 
## as they are built on CentOS 6 with statically-linked libpng and libjpeg . 
## However, in case of security vulnerabilities in either library a new release 
## will have to be done – similar to what was required for Windows earlier.
##
## We install directly and avoid distro package because the debian package 
## had a bug which made the PDF page headers and page footers fail. More info:
## https://www.odoo.com/documentation/11.0/setup/install.html#debian-ubuntu   ):
wk_version=0.12.4

#########################
### Command line options
#########################
uninstall="False"
update="False"
_self_update="False"
help="False"
delete_start_over="False"
_virtualenv="False"
nginx="False"
email=""  # email for let's encrypt https cert notifications.
domain="" # domain for let's encrypt https cert and nginx website.
_version="False"
_livechatport=8072	#default live chat port. possibly already in use by other odoo instance.
_upgrade_python_libraries="False"
_sysvinit="False" # default to False (therefore install systemd service). will be True (init.d service) if requested on command line.

#################################################################
##### Values calculated at runtime - no need to modify these ####
#################################################################
_superadmin=0
_domain_exists="False"
_cores=$(grep processor /proc/cpuinfo | wc -l)
### let "_workers= $_cores * 2 + 1 "
let "_workers= $_cores + 1 "
_totalkb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo);
let "_totalmb= $_totalkb / 1024 "
_diskfree=$(df -h $OE_HOME | tail -1 | tr -s ' ' | cut -d' ' -f4)

#############
### FUNCTIONS
#############

function process_command_line {
	getopt --test > /dev/null
	if [[ $? -ne 4 ]]; then
	    echo "Sorry, cannot process command line, outdated version of getopt installed. Upgrade getopt and try again."
	    exit 1
	else
		OPTIND=1
		OPTIONS="EhuV"
		# Add single-letter options here. Uppercase lowercase is different. ":" means a parameter is expected with the option.
		LONGOPTIONS="enterprise,uninstall,self-update,update,upgrade,upgrade-python-libraries,help,delete-start-over,virtualenv,email:,domain:,nginx,version,livechatport:,sysvinit"
		# Add comma-separated "long options" here. For example "--help".  ":" means a parameter is expected with the option.
		PARSED="$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")"
		if [[ $? -ne 0 ]]; then
		    # e.g. $? == 1
		    #  then getopt has complained about wrong arguments to stdout
		    exit 2
		fi
		# read getopt's output this way to handle the quoting right:
		eval set -- "$PARSED"
	
		# now enjoy the options in order and nicely split until we see --
		while true; do
		    case "$1" in
		        -E|--enterprise)
		            IS_ENTERPRISE="True"
		            shift
		            ;;
		        --nginx)
		        		nginx="True"
		        		shift
		        		;;
		        --email)
	              email="$2"
		            shift 2
		            ;;
		        --domain)
	              domain="$2"
		            shift 2
		            ;;
		        -h|--help)
		        		help="True"
		        		shift
		        		;;
		        --delete-start-over)
		        		delete_start_over="True"
		        		shift
		        		;;
		        --livechatport)
		        		_livechatport="$2"
		        		shift 2
		        		;;
		        --self-update)
		            _self_update="True"
		            shift
		            ;;
		        --uninstall)
		        		uninstall="True"
		        		shift
		        		;;
		        -u|--update|--upgrade)
		        		update="True"
		        		shift
		        		;;
		        --upgrade-python-libraries)
		        		_upgrade_python_libraries="True"
		        		shift
		        		;;
		        -V|--version)
		        		_version="True"
		        		shift
		        		;;
		        --virtualenv)
		        		_virtualenv="True"
		        		shift
		        		;;
		        --sysvinit)
		        		_sysvinit="True"
		        		shift
		        		;;
		        --)
		            shift
		            break
		            ;;
		        *)  # This is a parameter which was supposed to be processed above in the option, 
		        		# but probably case where it's supposed to process the short or long version of the option,
		        		# is missing a "shift" or is catching either the option or the longoption.
		            echo "Option programming error. Missing OPTIONS, LONGOPTIONS, or case."
		            exit 3
		            ;;
		    esac
		done
		
		# handle non-option arguments
		# For example, for commandline "touch filename", this is where to handle "filename".
		#if [[ $# -ne 1 ]]; then
		#    echo "$0: A single input file is required."
		#    exit 4
		#fi
		#echo -e "uninstall: $uninstall \n update: $update \n help: $help \n delete-start-over: $delete_start_over \n virtualenv: $_virtualenv  \n nginx: $nginx  \n email: $email  \n domain: $domain"

	fi
}

function self_update () {
	wget -q --unlink --output-document=$0 https://github.com/chris001/InstallScript/raw/patch-2/odoo_install.sh
	chmod +x $0
}

function get_flavor_name {	# Needed to prevent these string constants from being copy pasted everywhere.
	flavor="Community"
	if [[ $IS_ENTERPRISE == "True" ]]; then
	  flavor="Enterprise"
	fi
}

function can_i_sudo {
	local _groups=$("groups")
	if [[ "$UID" == 0 ]]; then
		_superadmin=1
	fi
	if [[ "$_groups" == *" sudo"* ]]; then
		_superadmin=1
	fi
}

is_fqdn() {
  hostname=$1
  [[ $hostname == *"."* ]] || return 1
  host $hostname > /dev/null 2>&1 || return 1
}

function verify_domain_exists {
		is_fqdn $domain
    if [[ "$?" == 0 ]]
    then
        _domain_exists="True"
    else
        _domain_exists="False"
    fi
}

function remove_install_log {
  set +e
  rm -f $INSTALL_LOG
  set -e
}

function clear_install_log {
  remove_install_log
  set +e
  touch $INSTALL_LOG
}

function stop_odoo_server {
  set +e
  sudo service ${OE_CONFIG} stop
  set -e
}

function update_repo_in_current_dir {
 	git fetch --depth 1 >> $INSTALL_LOG
 	git reset --hard origin/$OE_VERSION >> $INSTALL_LOG
 	sudo chown -R $OE_USER. .
	#apply changes to database
 	sudo service $OE_CONFIG restart -u all >> $INSTALL_LOG
 	#sudo systemctl restart $OE_CONFIG
}

function update_odoo {
  set +e
  cd $OE_HOME_EXT
	update_repo_in_current_dir
  cd ~
  set -e
}

function download_odoo {
  set +e
  sudo rm -rf $OE_HOME_EXT
  sudo git clone --depth 1 --branch $OE_VERSION https://github.com/odoo/odoo $OE_HOME_EXT/
  sudo chown $OE_USER. $OE_HOME_EXT
  if [[ $update == "True" ]]; then
    cd $OE_HOME_EXT
		update_repo_in_current_dir
		stop_odoo_server
  fi
  cd ~
  set -e
}

function install_odoo_python_requirements_virtualenv {
	#Install the tools required to build Odoo dependencies if needed
	# and virtualenvwrapper
	sudo apt-get -y install build-essential python3-dev libxslt-dev \
		libzip-dev libldap2-dev libsasl2-dev \
	  libxml2 libxslt1.1 libxml2-dev libxslt1-dev \
    python-libxml2 python-libxslt1 python-dev python-setuptools \
    libxml2-dev libssl-dev \
    virtualenvwrapper >> $INSTALL_LOG
  local _cmd="source /usr/share/virtualenvwrapper/virtualenvwrapper.sh ; mkvirtualenv -p /usr/bin/python3 ${OE_USER}-venv 2>&1 >> $INSTALL_LOG"
	sudo -i -u $OE_USER $_cmd >> $INSTALL_LOG
	#This will install virtualenvwrapper and activate it immediately. 
	## We are now INSIDE the odoo user's python virtual environment named "$OE_USER-venv".
	#Create an isolated environment
	#Now we can create a virtual environment for Odoo like this:
	# (Already done in above command.)
	#sudo su - $OE_USER -c "mkvirtualenv -p /usr/bin/python3 ${OE_USER}-venv"
	#With this command, we ask for an isolated Python3 environment that will be named "odoo-env". 
	#If the command works as expected, your shell is now using this environment. 
	#Your prompt should have changed to remind you that you are using an isolated environment. 
	#You can verify with this command:
	#$ which python3
	#This command should show you the path to the Python interpreter located in the isolated environment directory.
	#Now let's install the Odoo required python packages WHILE INSIDE THE VIRTUAL ENVIRONMENT:
	#pip install -r ${OE_HOME_EXT}/requirements.txt
	pip install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt
	#After a little while, you should be ready to run odoo from the command line as explained above.
	#When you you want to leave the virtual environment, just issue this command:
	#deactivate
	#Whenever you want to work again with your 'odoo-venv' environment:
	#$ workon odoo-venv
  cd ~

	# Previous method:
  #sudo apt-get install -y build-essential libxml2 libxslt1.1 libxml2-dev libxslt1-dev 
  #  python-libxml2 python-libxslt1 python-dev python-setuptools \
  #  libxml2-dev libxslt-dev libldap2-dev libsasl2-dev libssl-dev >> $INSTALL_LOG
  #pip3 install virtualenv >> $INSTALL_LOG
  #mkdir $OE_PYTHON_ENV >> $INSTALL_LOG
  #virtualenv $OE_PYTHON_ENV -p /usr/bin/python3 >> $INSTALL_LOG
  #source $OE_HOME/python_env/bin/activate && pip3 install -r $OE_HOME_EXT/requirements.txt >> $INSTALL_LOG
  #deactivate
}

function update_server {
  set +e
  #for ubuntu.
  #need software-properties-common for the apt-add-repository command.
  #also update-notifier-common to provide update notifications with the message of the day (MOTD).
  sudo apt-get update >> $INSTALL_LOG
  sudo apt-get install -y software-properties-common python-software-properties \
      update-notifier-common >> $INSTALL_LOG
  #some minimal ubuntu servers are lacking the popular yet optional universe repo which contains pip3 
  #so we must add universe to be sure we can install pip3.
  sudo add-apt-repository -y universe >> $INSTALL_LOG
  sudo apt-get update >> $INSTALL_LOG
  sudo apt-get -y upgrade >> $INSTALL_LOG
  set -e
}

function add_odoo_site_to_nginx {
	local _tmp_config="./${domain}.conf"
	local config="/etc/nginx/sites-available/${domain}.conf"
	# https://www.odoo.com/documentation/11.0/setup/deploy.html
	sudo rm -f $config
	sudo rm -f $_tmp_config
	set +e
	touch $_tmp_config
	set -e
	cat <<EOF > $_tmp_config
#odoo server
upstream odoo {
 server 127.0.0.1:$OE_PORT;
}
upstream odoochat {
 server 127.0.0.1:$_livechatport;
}

server {
 listen 443 ssl http2;
 listen [::]:443 ssl http2 ipv6only=on;
 server_name $domain;

 client_max_body_size 200m;

 ssl_stapling on;
 ssl_stapling_verify on;

 add_header Strict-Transport-Security "max-age=15768000; includeSubdomains; preload";
 add_header X-Frame-Options DENY;
 add_header X-Content-Type-Options nosniff;

 proxy_read_timeout 720s;
 proxy_connect_timeout 720s;
 proxy_send_timeout 720s;

 # Add Headers for odoo proxy mode
 proxy_set_header X-Forwarded-Host \$host;
 proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
 proxy_set_header X-Forwarded-Proto \$scheme;
 proxy_set_header X-Real-IP \$remote_addr;

 # log
 access_log /var/log/nginx/$domain.access.log;
 error_log /var/log/nginx/$domain.error.log;

 # Redirect requests to odoo backend server
 location / {
   proxy_redirect off;
   proxy_pass http://odoo;
 }
 location /longpolling {
     proxy_pass http://odoochat;
 }

 # common gzip
 gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript;
 gzip on;
}

# http -> https
server {
   listen 80;
   listen [::]:80 ipv6only=on;
   server_name $domain;
   rewrite ^(.*) https://\$host\$1 permanent;
}
EOF

	sudo mv $_tmp_config $config
	set +e
	sudo ln -s /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/$domain.conf >> $INSTALL_LOG
	sudo systemctl restart nginx
	set -e
}

function install_nginx_with_LE_https_cert {
	###sudo apt-get update >> $INSTALL_LOG  # Update was already done in update_server function.
	sudo apt-get -y install nginx software-properties-common >> $INSTALL_LOG
	sudo add-apt-repository -y ppa:certbot/certbot >> $INSTALL_LOG
	sudo apt-get update >> $INSTALL_LOG
	sudo apt-get -y install python-certbot-nginx >> $INSTALL_LOG

	add_odoo_site_to_nginx

	#Certbot has an Nginx plugin, which is supported on many platforms, and automates both obtaining and installing certs.
	#Running this command will get a certificate for you and have Certbot edit your Nginx configuration automatically to serve it. 
	#Please specify --domains, or --installer that will help in domain names autodiscovery.
	## Original method deprecated Jan 2018 because TLS SNI vulnerability requires SNI verification turned off.
	## sudo certbot run -n --nginx --agree-tos --no-eff-email -m $email -d $domain
	## Temporary workaround method January 2018 until ppa maintainers add certbot 0.21 to ppa:certbot/certbot.
	## https://github.com/certbot/certbot/issues/5405#issuecomment-356498627
	sudo certbot -n --authenticator standalone --installer nginx --agree-tos --no-eff-email -m $email -d $domain --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx" >> $INSTALL_LOG

	#Automating renewal
	#The Certbot packages on your system come with a cron job that will renew your certificates automatically before they expire. 
	#Since Let's Encrypt certificates last for 90 days, it's highly advisable to take advantage of this feature. 
	#You can test automatic renewal for your certificates by running this command:
	#sudo certbot renew --dry-run
	#If dry run appears to be working correctly, you can arrange for automatic renewal by adding a cron or systemd job 
	#which runs the following:
	#certbot renew
}

function install_postgresql {
	sudo apt-get install postgresql -y >> $INSTALL_LOG
	sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true
}

function update_postgresql_template {
	set -e
	sudo localedef -f UTF-8 -i en_US en_US.UTF-8 >> $INSTALL_LOG
	RUN_PSQL="sudo -i -u postgres psql -X --set AUTOCOMMIT=off --set ON_ERROR_STOP=on --single-transaction "
	${RUN_PSQL} <<SQL
UPDATE pg_database SET encoding = pg_char_to_encoding('UTF8') WHERE datname = 'postgres';
UPDATE pg_database SET encoding = pg_char_to_encoding('UTF8') WHERE datname = 'template0';
UPDATE pg_database SET encoding = pg_char_to_encoding('UTF8') WHERE datname = 'template1';
SQL
}

function install_dependencies {
	# suds is for compatibility with Ubuntu 16.04. Will work on 14.04, 15.04 and 16.04
	sudo apt-get install -y python3 python3-pip python-pip htop wget git bzr net-tools \
	        gcc python3-dev gdebi-core node-clean-css node-less \
	        build-essential libxml2 libxslt1.1 libxml2-dev libxslt1-dev \
	        python-dev python-setuptools python3-setuptools \
	        libxslt-dev libldap2-dev libsasl2-dev libssl-dev \
	        libgeoip-dev python-psycogreen libzip-dev \
	        python-reportlab-accel python-zsi \
	        python-openssl poppler-utils antiword >> $INSTALL_LOG
 	        # python-gevent python-dateutil python-feedparser python-ldap python-libxslt1 
	        # python-lxml python-mako python-openid 
	        # python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing 
	        # python-reportlab python-simplejson python-tz python-vatnumber 
	        # python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi 
	        # python-docutils python-psutil python-mock python-unittest2 
	        # python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil 
 	        # python-libxml2 python-libxslt1 
}

function upgrade_pip {
  sudo -H pip install --upgrade pip >> $INSTALL_LOG
  sudo -H pip3 install --upgrade pip >> $INSTALL_LOG
}

function install_python_libraries {
	local _upgrade_flag=""
	if [[ $_upgrade_python_libraries == "True" ]]; then
		_upgrade_flag="--upgrade"
	fi
	sudo -H pip3 install $_upgrade_flag gevent feedparser ldap lxml mako \
	                  https://launchpad.net/ubuntu/+archive/primary/+files/python-pychart_1.39.orig.tar.gz \
	                  pypdf2 Babel passlib Werkzeug decorator python-dateutil pyyaml psycopg2 \
	                  psutil html2text docutils pillow reportlab simplejson vatnumber pywebdav3 \
	                  ninja2 requests gdata XlsxWriter vobject python-openid pyparsing pydot \
	                  mock Jinja2 ebaysdk xlwt psycogreen suds-jurko pytz \
	                  pyusb greenlet xlrd unittest2 \
	                  num2words markupsafe ofxparse pyldap pyserial qrcode six \
	                  serial geoip python3-openid unicodecsv \
	                  launchpadtools paramiko >> $INSTALL_LOG
	set +e
	#sudo -H pip2 install ZSI >> $INSTALL_LOG
	#sudo -H pip2 install infi.ZSI >> $INSTALL_LOG
	sudo -H pip2 install testresources egenix-mx-base >> $INSTALL_LOG #required by launchpadlib. not auto installed.
	set -e
}

function install_wkhtmltopdf {
	#--------------------------------------------------
	# Install Wkhtmltopdf
	#--------------------------------------------------
	# First install dependencies.
	sudo apt-get install -y libxrender1 fontconfig xvfb >> $INSTALL_LOG
  #pick up correct one from x64 & x32 versions:
  local arch="i386"
  local bit=$(getconf LONG_BIT)
  if [ "$bit" == "64" ];then
    arch="amd64"
  fi
  local _url="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${wk_version}/wkhtmltox-${wk_version}_linux-generic-${arch}.tar.xz"
  wget -nc -q $_url >> $INSTALL_LOG
  tar xf $(basename $_url)
  sudo mv wkhtmltox/bin/* /usr/local/bin/
  rm -Rf wkhtmltox
  set +e
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin >> $INSTALL_LOG
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin >> $INSTALL_LOG
  set -e
}

function create_odoo_system_user {
	## For future option, if user already exists, to install under user home dir.
	#if [[ id -u "$OE_USER" >> $INSTALL_LOG_REDIRECT ]; then
	#  GET THE ALREADY EXISTING HOME DIR FOR THE USER.
	#  OE_HOME=$( getent passwd "$OE_USER" | cut -d: -f6 )
	#  echo "**** Skip create ODOO system user, user already exists! ****"
	#  echo "**** Using: User ${OE_USER} Home dir: ${OE_HOME} ****"
	#else
  set +e
  sudo mkdir -p $OE_HOME >> $INSTALL_LOG
  # FIX OWNERSHIP ON ODOO HOME DIR. BUG CAUSED NODE TO BREAK SO FRONT END HAD NO CSS, NO IMAGES.
  sudo chown -R $OE_USER:$OE_USER $OE_HOME  >> $INSTALL_LOG
  set -e
	sudo adduser --system --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER >> $INSTALL_LOG
	sudo chown $OE_USER. $OE_HOME >> $INSTALL_LOG
  set +e
	if [[ $OE_RUN_SERVICE_AS_SUPERADMIN == "True" ]]; then
	  #The user should also be added to the sudo'ers group.
	  sudo adduser $OE_USER sudo >> $INSTALL_LOG
	else
	  #Remove user from the sudo group, in case it was added on a previous install.
	  sudo deluser $OE_USER sudo >> $INSTALL_LOG
	fi
	set -e
}

function delete_odoo_system_user {
  sudo deluser $OE_USER sudo >> $INSTALL_LOG
  sudo deluser --remove-home $OE_USER >> $INSTALL_LOG
}

function create_user_only {
  # creates odoo system user, odoo group, AND odoo home dir with correct ownership. user password is empty.
  sudo adduser --system --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER >> $INSTALL_LOG
  sudo addgroup $OE_USER sudo
}

function create_log_directory {
	local logdir="/var/log/${OE_USER}"
	set +e
	sudo mkdir -p $logdir >> $INSTALL_LOG
	set -e
	sudo chown $OE_USER:$OE_USER $logdir >> $INSTALL_LOG
}

function install_odoo_enterprise_addons {
  sudo mkdir -p $OE_ENTERPRISE_ADDONS >> $INSTALL_LOG
  sudo chown -R ${OE_USER}. $OE_ENTERPRISE_ADDONS >> $INSTALL_LOG
  cd $OE_ENTERPRISE_ADDONS
  local OE_GITHUB_ENTERPRISE_URL="https://github.com/odoo/enterprise"
  local GITHUB_COMMAND="git clone --depth 1 --branch $OE_VERSION $OE_GITHUB_ENTERPRISE_URL ."
  local GITHUB_RESPONSE=$($GITHUB_COMMAND 2>&1)
  while [[ "$GITHUB_RESPONSE" == *"Authentication"* ]]; do
    echo "------------------------WARNING------------------------------"
    echo "Your authentication with Github has failed! Please try again."
    echo "In order to clone and install the Odoo enterprise version you" 
    echo "need to be an offical Odoo partner and you need access to"
    echo "http://github.com/odoo/enterprise."
    echo "TIP: Press ctrl+c to stop this script."
    echo "-------------------------------------------------------------"
    echo " "
    GITHUB_RESPONSE=$($GITHUB_COMMAND 2>&1)
  done
  cd ~
  if [[ $update == "True" ]]; then
  	cd $OE_ENTERPRISE_ADDONS
  	update_repo_in_current_dir
  	######stop_odoo_server
  	cd ~
  fi
}

function install_enterprise_libraries {
  set -e
  sudo apt-get install -y nodejs npm >> $INSTALL_LOG
  sudo npm install -g less less-plugin-clean-css >> $INSTALL_LOG
  set +e
  sudo ln -s /usr/bin/nodejs /usr/bin/node >> $INSTALL_LOG
  set -e
}

function create_custom_module_dir {
  set +e
  sudo su $OE_USER -c "mkdir -p $OE_CUSTOM_ADDONS" >> $INSTALL_LOG
  set -e
}

function set_permissions_home_dir {
  sudo chown -R $OE_USER:$OE_USER $OE_HOME  >> $INSTALL_LOG
}

function create_odoo_server_config_file {
  local config=~/${OE_CONFIG}.conf
  local community_addons_dirs="${OE_HOME_EXT}/addons,${OE_CUSTOM_ADDONS}"
  addons_dirs=$community_addons_dirs
  if [[ $IS_ENTERPRISE == "True" ]]; then
    addons_dirs="${OE_ENTERPRISE_ADDONS},${community_addons_dirs}"
  fi
  cat <<EOF > $config
[options]
; This is the password that allows database operations:
admin_passwd = ${OE_SUPERADMIN}
#db_host = localhost
#db_port = 5432
#db_user = odoo
#db_password = pwd
#dbfilter = ^$domain.*$
xmlrpc_port = ${OE_PORT}
proxy_mode = ${nginx}
; workers must be non-zero so that odoo will give LiveChat its own process so it can listen on its own port.
workers = $_workers
logfile = /var/log/${OE_USER}/${OE_CONFIG}
addons_path=${addons_dirs}
EOF
  sudo chown $OE_USER:$OE_USER $config  >> $INSTALL_LOG
  sudo chmod 640 $config  >> $INSTALL_LOG
  sudo mkdir -p /etc/odoo >> $INSTALL_LOG
  sudo mv $config /etc/odoo/${OE_CONFIG}.conf  >> $INSTALL_LOG
}

function create_startup_file {
  temp=~/temp0.sh
  rm -f $temp
  cat <<EOF > $temp
#!/bin/sh
sudo -u $OE_USER $OE_HOME_EXT/${OE_USER}-bin --config=/etc/odoo/${OE_CONFIG}.conf
EOF
  chmod 0755 $temp
  sudo chown $OE_USER. $temp
  sudo mv $temp $OE_HOME_EXT/start.sh
}

function create_odoo_init_file {
  cat <<EOF > ~/${OE_CONFIG}.tmp0
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
# Specify an alternate config file (Default: /etc/odoo/odoo-server.conf).
CONFIGFILE="/etc/odoo/${OE_CONFIG}.conf"
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
}

function security_init_file {
  sudo mv ~/$OE_CONFIG.tmp0 /etc/init.d/$OE_CONFIG  >> $INSTALL_LOG
  sudo chmod 0755 /etc/init.d/$OE_CONFIG  >> $INSTALL_LOG
  sudo chown root: /etc/init.d/$OE_CONFIG  >> $INSTALL_LOG
}

function start_odoo_on_startup {
  sudo update-rc.d $OE_CONFIG defaults >> $INSTALL_LOG
  sudo systemctl enable $OE_CONFIG >> $INSTALL_LOG
}

create_odoo_systemd_service () {
  cat <<EOF > ~/${OE_CONFIG}.service
[Unit]
Description=$OE_CONFIG (Odoo $OE_VERSION $flavor)
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=$OE_CONFIG
PermissionsStartOnly=true
User=$OE_USER
Group=$OE_USER
#ExecStart=/opt/odoo/odoo11-venv/bin/python3 /opt/odoo/odoo11/odoo-bin -c /etc/odoo11.conf
ExecStart=$(which python3) $OE_HOME_EXT/odoo-bin -c /etc/odoo/$OE_CONFIG.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF
  sudo chmod 0644 ~/${OE_CONFIG}.service >> $INSTALL_LOG
  sudo chown root:root ~/${OE_CONFIG}.service >> $INSTALL_LOG
  sudo mv ~/${OE_CONFIG}.service /etc/systemd/system/${OE_CONFIG}.service >> $INSTALL_LOG
  sudo systemctl enable ${OE_CONFIG} >> $INSTALL_LOG
}

function start_odoo {
  sudo service ${OE_CONFIG} restart -u all >> $INSTALL_LOG
}

function show_odoo_status {
  sudo service ${OE_CONFIG} status
}

function remove_sysvinit_service () {
	# 2. disable start odoo on startup.
	sudo update-rc.d ${OE_CONFIG} disable
	sudo update-rc.d ${OE_CONFIG} remove
	# 3. remove init file.
	sudo rm /etc/init.d/${OE_CONFIG}
	# 3b. clean up service daemon system settings.
	sudo systemctl daemon-reload
}

function uninstall_odoo () {
	# 1. Stop odoo-server "$OE_CONFIG" if running.
	sudo service ${OE_CONFIG} stop
	# 2-3. Remove SysV Init service.
	remove_sysvinit_service
	# 4. remove /home/odoo/odoo-server dir (odoo community from github).
	sudo rm -r ${OE_HOME_EXT}
	# 4a. Remove downloaded wkhtmltox*
	sudo rm ${OE_HOME}/wkhtmltox*
	# 5. remove enterprise addons dir?
	#sudo rm -r ${OE_ENTERPRISE_ADDONS}
	# 6. remove /home/odoo/custom/addons dir?
	#sudo rm -r ${OE_CUSTOM_ADDONS}
	# 7. remove /var/log/odoo ?
	sudo rm -r /var/log/${OE_USER}/${OE_CONFIG}
	# 8. delete odoo system user ?
	delete_odoo_system_user
	# 9. remove system packages ? Use autoremove. apt will remove only unused packages.
	sudo apt autoremove
	# 10. remove python dependencies ?
}

function show_help {
	echo "-h --help               Show help (this page)."
	echo "--delete-start-over     Uninstall $OE_CONFIG, delete odoo user $OE_USER + homedir $OE_HOME_EXT , create odoo user (as superadmin so this script can run) + homedir."
	echo "-E --enterprise         Install Odoo Enterprise $OE_VERSION"
	echo "--livechatport=8072     Livechat port number, must be different than other Odoo livechat instances running on same IP address."
	echo "--nginx --email=me@myemail.com --domain=mycompany.com    Install nginx support + free LE HTTPS cert"
	echo "--self-update           Update this script, $0"
	echo "--uninstall             Uninstall Odoo $OE_CONFIG from $OE_HOME_EXT"
	echo "-u --update --upgrade   Update Odoo instance $OE_CONFIG in $OE_HOME_EXT with the latest update."
	echo "--upgrade-python-libraries  Upgrade the python libraries, used by Odoo, to their latest versions."
	echo "-V --version            Show version of $0"
	echo "--virtualenv            Install libraries to isolated virtual environment in your user home dir."
}

################################

cd ~
#Clear previous odoo_install.log file to empty.
clear_install_log
echo "Odoo Installer version $versiondate"
echo "by Yenthe Van Ginneken and Chris Coleman (EspaceNetworks)."
echo "System Memory detected: $_totalmb MB"
echo "Free space on $OE_HOME : $_diskfree"

command_line_args="$@"
process_command_line $command_line_args
if [[ $_version == "True" ]]; then
	echo "For usage: $0 --help"
	exit	#just showed version (above).
fi
if [[ $help == "True" ]]; then
  show_help
  exit
fi
if [[ $_self_update == "True" ]]; then
	self_update
	echo "$0 updated OK."
	exit
fi
if [[ $update == "True" ]]; then
	echo "Update: $OE_HOME_EXT"
  cd $OE_HOME_EXT
  update_repo_in_current_dir
  cd ~
  exit
fi
if [[ $_upgrade_python_libraries == "True" ]]; then
	echo "Upgrade python libraries."
	echo "a. Update server"
	update_server
	echo "b. Install OS dependencies"
	install_dependencies
	echo "c. Upgrade pip"
	upgrade_pip
	echo "d. Install upgraded python libraries"
	install_python_libraries
	echo "e. Done, installed upgraded python libraries."
	exit
fi
can_i_sudo
if [[ "$_superadmin" == 0 ]]; then
	echo "You cannot sudo.  Next version will work for you.  Or run as user with sudo priviliges."
	exit
fi
get_flavor_name

if [[ "$uninstall" == "True" ]]; then
  echo "*** Uninstalling service: ${OE_CONFIG} Removing: ${OE_HOME_EXT} (Assuming Odoo ${OE_VERSION} ${flavor}) ****"
  uninstall_odoo
  exit
fi
if [[ "$delete_start_over" == "True" ]]; then
	echo "*** Deleting and starting over with fresh ordinary user to run this install script as. ****"
	uninstall_odoo
	echo "**** Creating user $OE_USER as superadmin, and home dir $OE_HOME ****"
	create_user_only
	exit
fi
if [[ "$_virtualenv" == "True" ]]; then
	install_odoo_python_requirements_virtualenv
	exit
fi

echo "Installing: Odoo $OE_VERSION $flavor to $OE_HOME_EXT"
echo "---- 1. Stop odoo server (if running) ----"
stop_odoo_server

echo "---- 2. Update operating system ----"
update_server

if [[ "$nginx" == "True" ]]; then
	if [[ $email == "" ]] || [[ $domain == "" ]]; then
		echo "ERROR: to install nginx + LE HTTPS, you must specify both --email= and --domain="
		exit 1
	else
		echo "---- 3. Installing Nginx + LE HTTPS cert (email: $email domain: $domain ) ----"
		verify_domain_exists
		if [[ "$_domain_exists" == "False" ]]; then
			echo "ERROR: domain $domain does not exist. Nginx + HTTPS requires domain. Check DNS and try again."
			exit 1
		fi
		if [[ "$email" == "" ]]; then
			echo "ERROR: provide your email address for Let's Encrypt HTTPS cert 90 day renewal notifications."
			echo "Example: $0 --nginx --domain=$domain --email=myname@myemail.com"
			exit 1
		fi
		install_nginx_with_LE_https_cert
	fi
fi

echo "---- 4. Install PostgreSQL Server + Create ODOO PostgreSQL User  ----"
install_postgresql

echo "---- 5. Update postgresql template1 for UTF-8 charset ----"
update_postgresql_template

echo "---- 6. Install Python 3 + pip3 + tool packages + python packages + other required--"
install_dependencies

echo "---- 7. Download ODOO Server ----"
download_odoo

echo "---- 8. Upgrade pip ----"
upgrade_pip

echo "---- 9. Install python libraries ----"
install_python_libraries

### INSTALL PYTHON PACKAGES FROM REQUIREMENTS.TXT AND VIRTUALENV
### THIS WILL HALT (OUT OF MEMORY) BUILDING LXML ON LOW FREE RAM SERVER, 
### USING PREBUILT DISTRO PYTHON PACKAGES ABOVE INSTEAD.
###echo -e "---- Install python packages and virtualenv ----"
###install_odoo_python_requirements_virtualenv

if [[ $INSTALL_WKHTMLTOPDF == "True" ]]; then
  echo "---- 10. Install wkhtml and create shortcuts ----"
  install_wkhtmltopdf
else
  echo "---- 10. Wkhtmltopdf isn't installed due to the choice of the user! ----"
fi

echo "---- 11. Create ODOO system user ----"
create_odoo_system_user
set_permissions_home_dir

echo "---- 12. Create Odoo Server Log directory ----"
create_log_directory

if [ $IS_ENTERPRISE == "True" ]; then
  # Odoo Enterprise install!
  echo "---- 13. Install ODOO Enterprise addons ----"
  set +e
  install_odoo_enterprise_addons
  echo "---- DONE. Added Enterprise addons in $OE_ENTERPRISE_ADDONS ----"
  set -e
fi

echo -e "---- 14. Install npm nodejs less less-plugin-clean-css + shortcut ----"
# These (npm nodejs less etc) are needed by enterprise AND community.
install_enterprise_libraries

echo "---- 15. Create custom module directory ----"
create_custom_module_dir

echo "---- 16. Set permissions on home dir $OE_HOME ----"
set_permissions_home_dir

echo "17. Create server config (settings) file"
create_odoo_server_config_file

echo "18. Create startup (shell command) file"
create_startup_file

if [[ $_sysvinit == "True" ]]; then
	#OLD SYSV INIT SERVICE.
	echo "19. Create init (service) file"
	create_odoo_init_file
	echo "20. Security Init File"
	security_init_file
	echo "21. Start ODOO on Startup"
	start_odoo_on_startup
else
	#NEW SYSTEMD SERVICE
	echo "18b. Remove old SysV Init service."
	set +e
	remove_sysvinit_service		#clean up old sysv init service if it's there and we're installing over it.
	set -e
	echo "19-21. Create systemd (service) file + Security systemd file + Start ODOO on startup"
	create_odoo_systemd_service
fi

echo "22. Starting Odoo Service"
start_odoo

echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_HOME_EXT/"
echo "Addons folders: $addons_dirs"
echo "Start Odoo service: sudo service $OE_CONFIG start"
echo "Stop Odoo service: sudo service $OE_CONFIG stop"
echo "Restart Odoo service: sudo service $OE_CONFIG restart"
echo "-----------------------------------------------------------"
show_odoo_status
