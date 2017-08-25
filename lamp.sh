#!/bin/sh
set -e
sudo yum update -y
#Enable the Extra Packages for Enterprise Linux (EPEL) repository from the Fedora project on your instance.
sudo yum-config-manager --enable epel
read -p "Want to install Apache + MySQL + PHP? (y/n) " RESP
if [ "$RESP" = "y" ]; then
 sudo yum remove httpd* php* -y
 sudo yum install -y httpd24 php56 mysql56-server php56-mysqlnd
 #sudo yum install httpd24 httpd24-devel php56 php56-mysqlnd mysql56-server -y
 
 #Start the Apache web server.
 sudo service httpd start

 #Use the chkconfig command to configure the Apache web server to start at each system boot.
 sudo chkconfig httpd on

 #Add your user (in this case, ec2-user) to the apache group.
 sudo usermod -a -G apache ec2-user

 #Change the group ownership of /var/www and its contents to the apache group.
 sudo chown -R ec2-user:apache /var/www

 #Change the directory permissions of /var/www and its subdirectories to add group write permissions and to set the group ID on future subdirectories.
 sudo chmod 2775 /var/www
 find /var/www -type d -exec sudo chmod 2775 {} \;

 #Recursively change the file permissions of /var/www and its subdirectories to add group write permissions.
 find /var/www -type f -exec sudo chmod 0664 {} \;

 #add SSL/TLS support by installing the Apache module mod_ssl:
 sudo yum install -y mod24_ssl
 sudo service httpd restart

 #Start MySQL server to start at every boot, enter the following command.
 sudo chkconfig mysqld on

 #Start the MySQL server.
 sudo service mysqld start
  read -p "Want to configure MySQL security" RESP
  if [ "$RESP" = "y" ]; then
   #Run mysql_secure_installation.
   sudo mysql_secure_installation
  fi
fi

#==============Set date timezone
sed -i "s/;date.timezone =/date.timezone = 'Asia\/Kolkata'/" /etc/php.ini

read -p "Want to install phpMyAdmin? (y/n) " RESP
if [ "$RESP" = "y" ]; then
	sudo yum install phpMyAdmin -y
	sudo cp /etc/httpd/conf.d/phpMyAdmin.conf /etc/httpd/conf.d/phpMyAdmin.conf.orig
	sed -i '/Require/s/^/#/g' /etc/httpd/conf.d/phpMyAdmin.conf
	sed -i "/<\/RequireAny>/aRequire all granted\nRewriteEngine On\nRewriteCond %{HTTPS} off\nRewriteRule (.*) https:\/\/%{HTTP_HOST}%{REQUEST_URI}" /etc/httpd/conf.d/phpMyAdmin.conf
	sudo service httpd restart
fi
