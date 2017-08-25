#!/bin/bash
REPO_PATH=/var/www/gitrepos
GITWEB_PATH=/usr/share/git
APACHE_PWD_PATH=/opt/git
APACHE_PWD_FILE=.htpasswd
set -e
while 
	echo "
	1) Install Git.
	2) Create User.
	3) Create Repository.
	0) Exit"
    read -p "Enter your choice : " opt
	if (( $opt == 1)); then
		#http://sharadchhetri.com/2013/06/01/how-to-install-own-git-server-with-ssh-and-http-access-by-using-gitolite-and-gitweb-in-centos/
		#http://blog.coffeebeans.at/archives/734
		#https://www.kernel.org/pub/software/scm/git/docs/git-http-backend.html
		#http://brakkee.org/site/2011/08/06/git-server-setup-on-linux-using-smart-http/
		yum install httpd24 git gitweb -y
		mv /var/www/git $GITWEB_PATH
		chown -R apache:apache $GITWEB_PATH

		T=${REPO_PATH//\//\\/}
		sed -i "s/^our \$projectroot =.*/our \$projectroot = '$T';/" $GITWEB_PATH/gitweb.cgi

cat > /etc/httpd/conf.d/git.conf <<EOF
<VirtualHost *:80>
 SetEnv GIT_PROJECT_ROOT $REPO_PATH
 SetEnv GIT_HTTP_EXPORT_ALL
 SetEnv REMOTE_USER=\$REDIRECT_REMOTE_USER

 AliasMatch ^/git/(.*/objects/[0-9a-f]{2}/[0-9a-f]{38})$ $REPO_PATH/\$1
 AliasMatch ^/git/(.*/objects/pack/pack-[0-9a-f]{40}.(pack|idx))$ $REPO_PATH/\$1
 ScriptAliasMatch "(?x)^/git/(.*/(HEAD | info/refs | objects/info/[^/]+ | git-(upload|receive)-pack))$" /usr/libexec/git-core/git-http-backend/\$1

 Alias /git $GITWEB_PATH
 <Directory $GITWEB_PATH>
  Options +ExecCGI
  AddHandler cgi-script .cgi
  DirectoryIndex gitweb.cgi

  AuthType Basic
  AuthName "Git Access"
  AuthUserFile $APACHE_PWD_PATH/$APACHE_PWD_FILE
  Require valid-user
 </Directory>

 <Directory /usr/libexec/git-core>
  Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
  AllowOverride None
  AuthType Basic
  AuthName "Git Access"
  AuthUserFile $APACHE_PWD_PATH/$APACHE_PWD_FILE
  Require valid-user
 </Directory>

 <Directory $REPO_PATH>
  Options FollowSymLinks
  AllowOverride None

  AuthType Basic
  AuthName "Git Access"
  AuthUserFile $APACHE_PWD_PATH/$APACHE_PWD_FILE
  Require valid-user
 </Directory>
 ErrorLog /var/log/httpd/error.log
 LogLevel warn
 CustomLog /var/log/httpd/access.log combined
</VirtualHost>
EOF
		service httpd restart
	elif (( $opt == 2)); then
		read -p "Enter desired username : " username
		mkdir -p $APACHE_PWD_PATH
		htpasswd -c $APACHE_PWD_PATH/$APACHE_PWD_FILE $username
		chown -R apache:apache $APACHE_PWD_PATH
	elif (( $opt == 3)); then #http://blog.coffeebeans.at/archives/734
		WORKDIR=`pwd`
		read -p "Enter repository name : " REPO
		# create dir
		mkdir -p $REPO_PATH/$REPO
		cd $REPO_PATH/$REPO
		git init --bare	# init repo
		touch git-daemon-export-ok
		cp hooks/post-update.sample hooks/post-update
		#git config http.receivepack true
		git update-server-info
		chown -R apache:apache .
		cd $WORKDIR
	fi
	(( $opt > 0 ))
do :; done
