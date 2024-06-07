#!/bin/bash

set -eu

# ==================================================================================== # 
# VARIABLES
# ==================================================================================== #

# Set the timezone for the server. A full list of available timezones can be found by 
# running timedatectl list-timezones.
TIMEZONE=Europe/Paris

# Set the name of the new user to create.
USERNAME=thebestdeal

# Set the name of the database to create.
DB_NAME=thebestdeal

# Set the name of the database user account to create.
DB_USER=web 

# Prompt to enter a password for the database user (rather than hard-coding 
# a password in this script).
read -p "Enter password for MySQL DB user: " DB_PASSWORD

# Force all output to be presented in en_US for the duration of this script. This avoids # any "setting locale failed" errors while this script is running, before we have
# installed support for all locales. Do not change this setting!
export LC_ALL=en_US.UTF-8

# ==================================================================================== # 
# SCRIPT LOGIC
# ==================================================================================== #

# Enable the "universe" repository.
dnf install dnf-plugins-core -y
dnf config-manager --set-enabled fedora
dnf config-manager --set-enabled updates

# Update all software packages. Using the --force-confnew flag means that configuration 
# files will be replaced if newer ones are available.
dnf upgrade --refresh -y

# Set the system timezone and install all locales.
timedatectl set-timezone ${TIMEZONE} 
# dnf -y install locales-all

# Add the new user (and give them sudo privileges).
useradd --create-home --shell "/bin/bash" --groups wheel "${USERNAME}"
# sudo adduser "${USERNAME}"
# sudo usermod -aG wheel "${USERNAME}"

# Force a password to be set for the new user the first time they log in.
passwd --delete "${USERNAME}" # Delete the current password (if any) to force a password set on first login
chage --lastday 0 "${USERNAME}" # Force password change on first login

# Copy the SSH keys from the root user to the new user.
rsync --archive --chown=${USERNAME}:${USERNAME} /root/.ssh /home/${USERNAME}

# Configure the firewall to allow SSH, HTTP and HTTPS traffic.
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# Install fail2ban (automatically temporarily ban an IP address if it makes too many 
# failed SSH login attempts).
dnf -y install fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# Install the migrate CLI tool.
curl -L https://github.com/golang-migrate/migrate/releases/download/v4.14.1/migrate.linux-amd64.tar.gz | tar xvz 
mv migrate.linux-amd64 /usr/local/bin/migrate

# Install MySQL.
dnf -y install community-mysql-server
systemctl enable mysqld
systemctl start mysqld

# Set up the thebestdeal DB and create a user account with the password entered earlier.
sudo -i mysql -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
sudo -i mysql -D thebestdeal -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}'"
sudo -i mysql -D thebestdeal -e "GRANT INDEX, CREATE, ALTER, SELECT, INSERT, UPDATE, DELETE, DROP ON thebestdeal.* TO '${DB_USER}'@'localhost'"

# Add a DSN for connecting to the thebestdeal database to the system-wide environment
# variables in the /etc/environment file.
echo "THEBESTDEAL_DB_NAME='${DB_NAME}'" >> /etc/environment
echo "THEBESTDEAL_DB_USER='${DB_USER}'" >> /etc/environment
echo "THEBESTDEAL_DB_PASSWORD='${DB_PASSWORD}'" >> /etc/environment
echo "THEBESTDEAL_DB_DSN='${DB_USER}:${DB_PASSWORD}@/${DB_NAME}?parseTime=true'" >> /etc/environment
echo "THEBESTDEAL_DB_URL='mysql://${DB_USER}:${DB_PASSWORD}@/${DB_NAME}'" >> /etc/environment

# Install Caddy (see https://caddyserver.com/docs/install#fedora-redhat-centos).
dnf -y install 'dnf-command(copr)'
dnf copr enable @caddy/caddy
dnf -y install caddy
systemctl enable caddy
systemctl start caddy

echo "Script complete! Rebooting..." 
reboot