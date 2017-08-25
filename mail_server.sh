#https://www.digitalocean.com/community/tutorials/how-to-configure-a-mail-server-using-postfix-dovecot-mysql-and-spamassassin
set -e
read -p "Enter MySql root password " MySql_PWD
while 
	echo "
	1) Install Mail Server.
	2) List domain.
	3) Add domain.
	4) Add email account.
	0) Exit"
    read -p "Enter your choice : " opt
	
	if (( $opt == 1 ));then
		yum install postfix dovecot dovecot-mysql -y
		cat > ./mail_server.sql <<EOF
drop database servermail;
create database servermail;
USE servermail;
/* We are going to create a table for the specific domains recognized as authorized domains. */
CREATE TABLE virtual_domains (
id  INT NOT NULL AUTO_INCREMENT,
name VARCHAR(50) NOT NULL,
PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

/* We are going to create a table to introduce the users. Here you will add the email address and passwords. It is necessary to associate each user with a domain. */
CREATE TABLE virtual_users (
id INT NOT NULL AUTO_INCREMENT,
domain_id INT NOT NULL,
password VARCHAR(106) NOT NULL,
email VARCHAR(120) NOT NULL,
PRIMARY KEY (id),
UNIQUE KEY email (email),
FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

/* create a virtual aliases table to specify all the emails that you are going to forward to the other email. */
CREATE TABLE virtual_aliases (
id INT NOT NULL AUTO_INCREMENT,
domain_id INT NOT NULL,
source varchar(100) NOT NULL,
destination varchar(100) NOT NULL,
PRIMARY KEY (id),
FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
EOF
		mysql -uroot -p$MySql_PWD < mail_server.sql
		rm -rf ./mail_server.sql

		#============Create certificates
		read -p "Want to use apache ssl cert (y) or create new (n) " RESP
		mkdir -p /etc/ssl/private
		mkdir -p /etc/ss/certs
		if [ "$RESP" = "y" ]; then
		 cp /etc/pki/tls/private/localhost.key /etc/ssl/private/mail.key
		 cp /etc/pki/tls/certs/localhost.crt /etc/ssl/certs/mailcert.pem
		else
		 sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/mail.key -out /etc/ssl/certs/mailcert.pem
		fi

		#============Configure Postfix============
		HOSTNAME=$(hostname -f)

		cp /etc/postfix/main.cf /etc/postfix/main.cf.orig
		cat > /etc/postfix/main.cf <<EOF
# Debian specific:  Specifying a file name will cause the first
# line of that file to be used as the name.  The Debian default
# is /etc/mailname.
#myorigin = /etc/mailname

smtpd_banner = $myhostname ESMTP $mail_name (Ubuntu)
biff = no

# appending .domain is the MUA's job.
append_dot_mydomain = no

# Uncomment the next line to generate "delayed mail" warnings
#delay_warning_time = 4h

readme_directory = no

# TLS parameters
smtpd_tls_cert_file=/etc/ssl/certs/mailcert.pem
smtpd_tls_key_file=/etc/ssl/private/mail.key
smtpd_use_tls=yes
#smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
#smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache 
smtpd_tls_auth_only = yes

smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination
mydestination = localhost
#myhostname = hostname.example.com
myhostname = $HOSTNAME

alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myorigin = /etc/mailname

relayhost =
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all

## Tells Postfix to use Dovecot's LMTP instead of its own LDA to save emails to the local mailboxes.
virtual_transport = lmtp:unix:private/dovecot-lmtp

## Tells Postfix you're using MySQL to store virtual domains, and gives the paths to the database connections.
virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf
virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf
EOF

		sed -i '/smtpd_tls_security_level/s/^#//g' /etc/postfix/master.cf
		sed -i '/smtpd_sasl_auth_enable/s/^#//g' /etc/postfix/master.cf
		sed -i '/smtpd_client_restrictions/s/^#//g' /etc/postfix/master.cf
		sed -i '/submission/s/^#//g' /etc/postfix/master.cf

		cat > /etc/postfix/mysql-virtual-mailbox-domains.cf <<EOF
user = root
password = $MySql_PWD
hosts = 127.0.0.1
dbname = servermail
query = SELECT 1 FROM virtual_domains WHERE name='%s'
EOF

		cat > /etc/postfix/mysql-virtual-mailbox-maps.cf <<EOF
user = root
password = $MySql_PWD
hosts = 127.0.0.1
dbname = servermail
query = SELECT 1 FROM virtual_users WHERE email='%s'
EOF

		cat > /etc/postfix/mysql-virtual-alias-maps.cf <<EOF
user = root
password = $MySql_PWD
hosts = 127.0.0.1
dbname = servermail
query = SELECT destination FROM virtual_aliases WHERE source='%s'
EOF

		service sendmail stop
		service postfix start

		rm -rf /var/mail
		mkdir /var/mail
		groupadd -g 5000 vmail
		useradd -g vmail -u 5000 --disabled-password vmail -d /home/vmail -m
		chown -R vmail:vmail /var/mail
		chmod 2775 /var/mail

		#===========Configure dovecot================
		cp /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.orig
		cp /etc/dovecot/conf.d/10-mail.conf /etc/dovecot/conf.d/10-mail.conf.orig
		cp /etc/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/10-auth.conf.orig
		cp /etc/dovecot/conf.d/10-master.conf /etc/dovecot/conf.d/10-master.conf.orig
		cp /etc/dovecot/conf.d/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf.orig
		cp /etc/dovecot/conf.d/auth-sql.conf.ext /etc/dovecot/conf.d/auth-sql.conf.ext.orig

		#=============Edit /etc/dovecot/dovecot.conf==========================
		sed -i '/!include conf.d\/\*.conf/s/^#//g' /etc/dovecot/dovecot.conf
		sed -i '/protocols =/s/^#//g' /etc/dovecot/dovecot.conf
		sed -i -e "\$a\!include_try \/usr\/share\/dovecot\/protocols.d\/\*.protocol" /etc/dovecot/dovecot.conf

		#=============Edit /etc/dovecot/conf.d/10-mail.conf===================
		sed -i '/^#mail_location =/s/^#//g' /etc/dovecot/conf.d/10-mail.conf
		sed -i 's/^mail_location =.*/mail_location = maildir:\/var\/mail\/vhosts\/%d\/%n/' /etc/dovecot/conf.d/10-mail.conf
		sed -i '/^#mail_privileged_group =/s/^#//g' /etc/dovecot/conf.d/10-mail.conf
		sed -i 's/^mail_privileged_group =.*/mail_privileged_group = mail/' /etc/dovecot/conf.d/10-mail.conf

		#=============Edit /etc/dovecot/conf.d/10-auth.conf===================
		sed -i '/disable_plaintext_auth =/s/^#//g' /etc/dovecot/conf.d/10-auth.conf
		sed -i 's/^auth_mechanisms =.*/auth_mechanisms = plain login/' /etc/dovecot/conf.d/10-auth.conf
		sed -i '/^\!include auth-system.conf.ext/s/^/#/g' /etc/dovecot/conf.d/10-auth.conf
		sed -i '/\!include auth-sql.conf.ext/s/^#//g' /etc/dovecot/conf.d/10-auth.conf

		#=============Create /etc/dovecot/dovecot-sql.conf.ext================
		cat > /etc/dovecot/dovecot-sql.conf.ext <<EOF
# This file is opened as root, so it should be owned by root and mode 0600.
#
# http://wiki2.dovecot.org/AuthDatabase/SQL
#
# For the sql passdb module, you'll need a database with a table that
# contains fields for at least the username and password. If you want to
# use the user@domain syntax, you might want to have a separate domain
# field as well.
#
# If your users all have the same uig/gid, and have predictable home
# directories, you can use the static userdb module to generate the home
# dir based on the username and domain. In this case, you won't need fields
# for home, uid, or gid in the database.
#
# If you prefer to use the sql userdb module, you'll want to add fields
# for home, uid, and gid. Here is an example table:
#
# CREATE TABLE users (
#     username VARCHAR(128) NOT NULL,
#     domain VARCHAR(128) NOT NULL,
#     password VARCHAR(64) NOT NULL,
#     home VARCHAR(255) NOT NULL,
#     uid INTEGER NOT NULL,
#     gid INTEGER NOT NULL,
#     active CHAR(1) DEFAULT 'Y' NOT NULL
# );

# Database driver: mysql, pgsql, sqlite
driver = mysql

# Database connection string. This is driver-specific setting.
#
# HA / round-robin load-balancing is supported by giving multiple host
# settings, like: host=sql1.host.org host=sql2.host.org
# 
# mysql:
#   Basic options emulate PostgreSQL option names:
#     host, port, user, password, dbname
#
#   But also adds some new settings:
#     client_flags        - See MySQL manual
#     ssl_ca, ssl_ca_path - Set either one or both to enable SSL
#     ssl_cert, ssl_key   - For sending client-side certificates to server
#     ssl_cipher          - Set minimum allowed cipher security (default: HIGH)
#     option_file         - Read options from the given file instead of
#                           the default my.cnf location
#     option_group        - Read options from the given group (default: client)
# 
#   You can connect to UNIX sockets by using host: host=/var/run/mysql.sock
#   Note that currently you can't use spaces in parameters.
#     
# sqlite:
#   The path to the database file.
#     
# Examples:
#   connect = host=192.168.1.1 dbname=users
#   connect = host=sql.example.com dbname=virtual user=virtual password=blarg
#   connect = /etc/dovecot/authdb.sqlite
#
connect = host=127.0.0.1 dbname=servermail user=root password=$MySql_PWD

# Default password scheme.
# 
# List of supported schemes is in
# http://wiki2.dovecot.org/Authentication/PasswordSchemes
# 
default_pass_scheme = SHA512-CRYPT
# passdb query to retrieve the password. It can return fields:
#   password - The user's password. This field must be returned.
#   user - user@domain from the database. Needed with case-insensitive lookups.
#   username and domain - An alternative way to represent the "user" field.
#   
# The "user" field is often necessary with case-insensitive lookups to avoid
# e.g. "name" and "nAme" logins creating two different mail directories. If
# your user and domain names are in separate fields, you can return "username"
# and "domain" fields instead of "user".
#     
# The query can also return other fields which have a special meaning, see
# http://wiki2.dovecot.org/PasswordDatabase/ExtraFields
#     
# Commonly used available substitutions (see http://wiki2.dovecot.org/Variables
# for full list):
#   %u = entire user@domain
#   %n = user part of user@domain
#   %d = domain part of user@domain
#     
# Note that these can be used only as input to SQL query. If the query outputs
# any of these substitutions, they're not touched. Otherwise it would be
# difficult to have eg. usernames containing '%' characters.
# 
# Example:
#   password_query = SELECT userid AS user, pw AS password \
#     FROM users WHERE userid = '%u' AND active = 'Y'
#
#password_query = \
#  SELECT username, domain, password \
#  FROM users WHERE username = '%n' AND domain = '%d'
password_query = SELECT email as user, password FROM virtual_users WHERE email='%u';

# userdb query to retrieve the user information. It can return fields:
#   uid - System UID (overrides mail_uid setting)
#   gid - System GID (overrides mail_gid setting)
#   home - Home directory
#   mail - Mail location (overrides mail_location setting)
#   
# None of these are strictly required. If you use a single UID and GID, and
# home or mail directory fits to a template string, you could use userdb static
# instead. For a list of all fields that can be returned, see
# http://wiki2.dovecot.org/UserDatabase/ExtraFields
# 
# Examples:
#   user_query = SELECT home, uid, gid FROM users WHERE userid = '%u'
#   user_query = SELECT dir AS home, user AS uid, group AS gid FROM users where userid = '%u'
#   user_query = SELECT home, 501 AS uid, 501 AS gid FROM users WHERE userid = '%u'
#
#user_query = \
#  SELECT home, uid, gid \
#  FROM users WHERE username = '%n' AND domain = '%d'

# If you wish to avoid two SQL lookups (passdb + userdb), you can use
# userdb prefetch instead of userdb sql in dovecot.conf. In that case you'll
# also have to return userdb fields in password_query prefixed with "userdb_"
# string. For example:
#password_query = \
#  SELECT userid AS user, password, \
#    home AS userdb_home, uid AS userdb_uid, gid AS userdb_gid \
#  FROM users WHERE userid = '%u'

# Query to get a list of all usernames.
#iterate_query = SELECT username AS user FROM users
EOF

		#=============Create /etc/dovecot/conf.d/10-master.conf================
		mv /etc/dovecot/conf.d/10-master.conf /etc/dovecot/conf.d/10-master.conf.orig
		cat > /etc/dovecot/conf.d/10-master.conf <<EOF
#default_process_limit = 100
#default_client_limit = 1000

# Default VSZ (virtual memory size) limit for service processes. This is mainly
# intended to catch and kill processes that leak memory before they eat up
# everything.
#default_vsz_limit = 256M

# Login user is internally used by login processes. This is the most untrusted
# user in Dovecot system. It shouldn't have access to anything at all.
#default_login_user = dovenull

# Internal user is used by unprivileged processes. It should be separate from
# login user, so that login processes can't disturb other processes.
#default_internal_user = dovecot

service imap-login {
  inet_listener imap {
	port = 0
  }
  inet_listener imaps {
	#port = 993
	#ssl = yes
  }

  # Number of connections to handle before starting a new process. Typically
  # the only useful values are 0 (unlimited) or 1. 1 is more secure, but 0
  # is faster. <doc/wiki/LoginProcess.txt>
  #service_count = 1

  # Number of processes to always keep waiting for more connections.
  #process_min_avail = 0

  # If you set service_count=0, you probably need to grow this.
  #vsz_limit = 64M
}
service pop3-login {
  inet_listener pop3 {
	#port = 110
  }
  inet_listener pop3s {
	#port = 995
	#ssl = yes
  }
}

service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
   mode = 0600
   user = postfix
   group = postfix
  }
  # Create inet listener only if you can't use the above UNIX socket
  #inet_listener lmtp {
	# Avoid making LMTP visible for the entire internet
	#address =
	#port = 
  #}
}

service imap {
  # Most of the memory goes to mmap()ing files. You may need to increase this
  # limit if you have huge mailboxes.
  #vsz_limit = 256M

  # Max. number of IMAP processes (connections)
  #process_limit = 1024
}

service pop3 {
  # Max. number of POP3 processes (connections)
  #process_limit = 1024
}

service auth {
  # auth_socket_path points to this userdb socket by default. It's typically
  # used by dovecot-lda, doveadm, possibly imap process, etc. Its default
  # permissions make it readable only by root, but you may need to relax these
  # permissions. Users that have access to this socket are able to get a list
  # of all usernames and get results of everyone's userdb lookups.
  unix_listener /var/spool/postfix/private/auth {
	mode = 0666
	user = postfix
	group = postfix
  }

  unix_listener auth-userdb {
   mode = 0600
   user = vmail
   #group =
  }

  # Postfix smtp-auth
  #unix_listener /var/spool/postfix/private/auth {
  #  mode = 0666
  #}

  # Auth process is run as this user.
  user = dovecot
}

service auth-worker {
  # Auth worker process is run as root by default, so that it can access
  # /etc/shadow. If this isn't necessary, the user should be changed to
  # $default_internal_user.
  user = vmail
}

service dict {
  # If dict proxy is used, mail processes should have access to its socket.
  # For example: mode=0660, group=vmail and global mail_access_groups=vmail
  unix_listener dict {
	#mode = 0600
	#user =
	#group =
  }
}
EOF

		#=============Edit /etc/dovecot/conf.d/10-logging.conf================
		sed -i '/log_path =/s/^#//g' /etc/dovecot/conf.d/10-logging.conf
		sed -i 's/^log_path =.*/log_path = \/var\/log\/dovecot.log/'  /etc/dovecot/conf.d/10-logging.conf

		chown -R vmail:dovecot /etc/dovecot
		chmod -R o-rwx /etc/dovecot

		#=============Edit /etc/dovecot/conf.d/10-ssl.conf
		sed -i '/ssl = /s/^#//g' /etc/dovecot/conf.d/10-ssl.conf
		sed -i '/ssl_cert =/s/^#//g' /etc/dovecot/conf.d/10-ssl.conf
		sed -i '/ssl_key =/s/^#//g' /etc/dovecot/conf.d/10-ssl.conf
		sed -i 's/^ssl_cert = .*/ssl_cert = <\/etc\/ssl\/certs\/mailcert.pem/' /etc/dovecot/conf.d/10-ssl.conf
		sed -i 's/^ssl_key = .*/ssl_key = <\/etc\/ssl\/private\/mail.key/' /etc/dovecot/conf.d/10-ssl.conf

		cat > /etc/dovecot/conf.d/auth-sql.conf.ext <<EOF
passdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf.ext
}
userdb {
  driver = static
  args = uid=vmail gid=vmail home=/var/vmail/%d/%n
}
EOF

		service dovecot restart

		#=============Install roundcubemail===================================
		sudo yum install php-pear -y
		sudo yum install --disablerepo='amzn-*' php-pear-Auth-SASL -y
		sudo yum install roundcubemail -y
		
		mysql -uroot -p$MySql_PWD -e "CREATE DATABASE RoundCube_db;"
		mysql -uroot -p$MySql_PWD RoundCube_db < /usr/share/roundcubemail/SQL/mysql.initial.sql
		cp -p /etc/roundcubemail/defaults.inc.php /etc/roundcubemail/config.inc.php
		sed -i "s/^\$config\['db_dsnw'\] =.*/\$config\['db_dsnw'\] = 'mysql:\/\/root:root@127.0.0.1\/RoundCube_db';/" /etc/roundcubemail/config.inc.php
		sed -i "s/^\$config\['default_host'\] =.*/\$config\['default_host'\] = 'ssl:\/\/127.0.0.1:993';/" /etc/roundcubemail/config.inc.php
		sed -i "s/^\$config\['default_port'\] =.*/\$config\['default_port'\] = 993;/" /etc/roundcubemail/config.inc.php
		sed -i "s/^\$config\['imap_auth_type'\] =.*/\$config\['imap_auth_type'\] = LOGIN;/" /etc/roundcubemail/config.inc.php
		sed -i "s/^\$config\['imap_conn_options'\] =.*/\$config\['imap_conn_options'\] = array('ssl'=>array('verify_peer'=>false, 'verify_peer_name'=>false));/" /etc/roundcubemail/config.inc.php
		sed -i "s/^\$config\['smtp_server'\] =.*/\$config\['smtp_server'\] = 'tls:\/\/127.0.0.1:587';/" /etc/roundcubemail/config.inc.php
		sed -i "s/^\$config\['smtp_port'\] =.*/\$config\['smtp_port'\] = 587;/" /etc/roundcubemail/config.inc.php
		sed -i "s/^\$config\['smtp_user'\] =.*/\$config\['smtp_user'\] = '%u';/" /etc/roundcubemail/config.inc.php
		sed -i "s/^\$config\['smtp_pass'\] =.*/\$config\['smtp_pass'\] = '%p';/" /etc/roundcubemail/config.inc.php
		sed -i "s/^\$config\['smtp_auth_type'\] =.*/\$config\['smtp_auth_type'\] = LOGIN;/" /etc/roundcubemail/config.inc.php
		sed -i "s/^\$config\['smtp_conn_options'\] =.*/\$config\['smtp_conn_options'\] = array('ssl'=>array('verify_peer'=>false, 'verify_peer_name'=>false));/" /etc/roundcubemail/config.inc.php
		sed -i "s/^\$config\['force_https'\] =.*/\$config\['force_https'\] = true;/" /etc/roundcubemail/config.inc.php

		sed -i '0,/Require local/s/Require local/Require all granted\nRewriteEngine On\nRewriteCond %{HTTPS} off\nRewriteRule (.*) https:\/\/%{HTTP_HOST}%{REQUEST_URI}/' /etc/httpd/conf.d/roundcubemail.conf
		
		service httpd restart
	elif (( $opt == 2 )); then
		mysql -uroot -p$MySql_PWD servermail -e "Select id, name as domain from virtual_domains;"
	elif (( $opt == 3 )); then
		read -p "Enter domain you want to add : " DOMAIN
		mysql -uroot -p$MySql_PWD servermail -e "INSERT INTO virtual_domains(name) VALUES ('$DOMAIN');"
	elif (( $opt == 4 )); then
		mysql -uroot -p$MySql_PWD servermail -e "Select id, name as domain from virtual_domains;"
		read -p "Enter domain id for which you want to add email : " DOMAIN_ID
		read -p "Enter email id with domain : " EMAIL_ID
		read -s -p "Enter password : " PASSWORD
		mysql -uroot -p$MySql_PWD servermail -e "INSERT INTO virtual_users (domain_id, password, email) VALUES ('$DOMAIN_ID', ENCRYPT('$PASSWORD', CONCAT('/$6/$', SUBSTRING(SHA(RAND()), -16))), '$EMAIL_ID');"
	fi
	(( $opt > 0 ))
do :; done
