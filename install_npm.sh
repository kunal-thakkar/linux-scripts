#Install nvm in /opt/nvm as root.

git clone git@github.com:creationix/nvm.git /opt/nvm

#Created the directory /usr/local/nvm. This is where the downloads will go ($NVM_DIR)
mkdir /usr/local/nvm

#Create the directory /usr/local/node. This is where the NPM global stuff will go:
mkdir /usr/local/node

#Created a file called nvm.sh in /etc/profile.d with the following contents:

export NVM_DIR=/usr/local/nvm
source /opt/nvm/nvm.sh

export NPM_CONFIG_PREFIX=/usr/local/node
export PATH="/usr/local/node/bin:$PATH"

echo "Re-login to a shell session, then install node by using command"
echo "nvm install <latest version>"
#nvm alias default 0.10