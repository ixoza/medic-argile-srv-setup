#!/bin/bash

##### Mise à jour du serveur #####
apt update && apt upgrade -y

##### Configuration IP fixe #####
read -p "Saisir la carte réseau : " cr
read -p "Saisir l'adresse IP : " adresseip
read -p "Saisir le network: " network
read -p "Saisir le mask : " mask
read -p "Saisir la gateway : " gateway
read -p "Saisir le DNS : " dns
bash -c "echo '
source /etc/network/interfaces.d/*
#The loopback network interface
auto lo
iface lo inet loopback
auto $cr
iface $cr inet static
 address $adresseip
 network $network
 netmask $mask
 gateway $gateway
 dns-nameservers $dns
'> /etc/network/interfaces"
systemctl restart networking

##### Installation LAMP (Mysql - Apache - php8.0) #####
apt -y install lsb-release apt-transport-https ca-certificates
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
apt -y update && apt -y upgrade
apt -y install php8.0
apt install -y php-json php8.0-gd php8.0-curl php8.0-mbstring php-cas php8.0-xml php8.0-cli php8.0-imap php8.0-ldap php8.0-xmlrpc php8.0-apcu 
php8.0-zip php8.0-bz2 php8.0-intl php8.0-mysql
apt install -y mariadb-server mariadb-client
apt install -y apache2 libapache2-mod-php8.0

##### Création de la BDD GLPI #####
read -p "Saisir le nom de la bdd : " nombddglpi
read -p "Saisir user : " userbddglpi
read -p "Saisir password bdd : " passwordbddglpi
mysql -e "CREATE DATABASE $nombddglpi CHARACTER SET UTF8 COLLATE UTF8_BIN"
mysql -e "CREATE USER '$userbddglpi'@'%' IDENTIFIED BY '$passwordbddglpi';"
mysql -e "GRANT ALL PRIVILEGES ON $nombddglpi.* TO '$userbddglpi'@'%';"
mysql -e "FLUSH PRIVILEGES;"

##### Installation de GLPI #####
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/10.0.5/glpi-10.0.5.tgz
tar -zxvf glpi-10.0.5.tgz
mv glpi /var/www/html/
chown -R www-data /var/www/html/glpi
sed -i "s/max_execution_time = 30/max_execution_time = 300/g" /etc/php/8.0/apache2/php.ini
sed -i "s/memory_limit = 128M/memory_limit = 256M/g" /etc/php/8.0/apache2/php.ini
sed -i "s/;max_input_vars = 1000/max_input_vars = 4440/g" /etc/php/8.0/apache2/php.ini
sed -i "s/post_max_size = 8M/post_max_size = 32M/g" /etc/php/8.0/apache2/php.ini
bash -c "echo 'ServerName localhost' >> /etc/apache2/apache2.conf"

##### Choix installation d'un certificat SSL #####
echo "Installer un certificat SSL pour GLPI ?"
echo "1 = Oui"
echo "2 = Non"
read choix
if [ "$choix" == "1" ]; then
 echo "Vous avez choisi d'installer GLPI avec certificat SSL"

##### Création d'un certificat SSL #####
read -p "Saisir le nom du certificat glpi : " nameglpicert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/${nameglpicert}.key -out /etc/ssl/certs/${nameglpicert}.crt
chown www-data:www-data /etc/ssl/private/${nameglpicert}.key
chown www-data:www-data /etc/ssl/certs/${nameglpicert}.crt

##### Configuration Apache pour redirection vers GLPI #####
read -p "Saisir le nom du serveur glpi (ex: glpi.example.com) : " servernameglpi
echo "<VirtualHost *:80>
 DocumentRoot /var/www/html/glpi
 ServerName ${servernameglpi}
 Redirect permanent / https://${servernameglpi}/
 ErrorLog /var/log/apache2/glpi_error.log
 CustomLog /var/log/apache2/glpi_access.log combined
</VirtualHost>
<VirtualHost *:443>
 ServerAdmin admin@example.com
 DocumentRoot /var/www/html/glpi
 ServerName ${servernameglpi}
 SSLEngine On
 SSLCertificateFile /etc/ssl/certs/${nameglpicert}.crt
 SSLCertificateKeyFile /etc/ssl/private/${nameglpicert}.key
 <Directory /var/www/html/glpi/>
 Options FollowSymlinks
 AllowOverride All
 Require all granted
 </Directory>
 <IfModule mod_headers.c>
 Header always set Strict-Transport-Security \"max-age=15768000; includeSubDomains\"
 </IfModule>
 ErrorLog /var/log/apache2/glpi_error.log
 CustomLog /var/log/apache2/glpi_access.log combined
</VirtualHost>" > /etc/apache2/sites-available/glpi.conf

##### Activer les modules Apache #####
a2ensite glpi.conf
a2enmod ssl
a2enmod rewrite
a2enmod headers

##### Redémarrer Apache #####
systemctl restart apache2
elif [ "$choix" == "2" ]; then
 echo "Vous avez choisi d'installer GLPI sans certificat SSL"
 
else
 echo "Choix invalide. Veuillez choisir une option valide."
fi
