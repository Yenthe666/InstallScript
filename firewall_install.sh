#  set the defaults used by UFW
sudo ufw reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allowed protocols
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https

# Enable Firewall
sudo ufw enable

#Check active protocols
sudo ufw status
