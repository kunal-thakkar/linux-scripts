sudo apt-get update -y
## for performance
cat > /home/osmc/.kodi/userdata/advancedsettings.xml <<EOF
<advancedsettings version="1.0">
	<gui>
		<algorithmdirtyregions>1</algorithmdirtyregions>
		<nofliptimeout>0</nofliptimeout>
	</gui>
</advancedsettings>
EOF

## install vnc server
## step 1 install all the necessary packages first in order to compile the vnc server.
sudo apt-get install build-essential rbp-userland-dev-osmc libvncserver-dev libconfig++-dev unzip -y
cd /home/osmc
sudo wget https://github.com/patrikolausson/dispmanx_vnc/archive/master.zip
unzip master.zip -d  /home/osmc/
rm master.zip -y
cd dispmanx_vnc-master
make
## step 2 create a basic config file (password, fps etc) and copy the server to the /bin folder for easy execution.
sudo cp dispmanx_vncserver /usr/bin
sudo chmod +x /usr/bin/dispmanx_vncserver
sudo cp dispmanx_vncserver.conf.sample /etc/dispmanx_vncserver.conf
sudo cat > /etc/dispmanx_vncserver.conf <<EOF
relative = false;
port = 0;
screen = 0;
unsafe = false;
fullscreen = false;
multi-threaded = false;
password = "osmc";
frame-rate = 23;
downscale = false;
localhost = false;
vnc-params = "";
EOF

sudo cat > /etc/systemd/system/dispmanx_vncserver.service <<EOF
[Unit]
Description=VNC Server
After=network-online.target mediacenter.service
Requires=mediacenter.service

[Service]
Restart=on-failure
RestartSec=30
Nice=15
User=root
Group=root
Type=simple
ExecStartPre=/sbin/modprobe evdev
ExecStart=/usr/bin/dispmanx_vncserver
KillMode=process

[Install]
WantedBy=multi-user.target	
EOF

sudo systemctl start dispmanx_vncserver.service
sudo systemctl enable dispmanx_vncserver.service
sudo systemctl daemon-reload

## to remove vnc command are
## sudo systemctl stop dispmanx_vncserver.service
## sudo systemctl disable dispmanx_vncserver.service
## sudo systemctl daemon-reload

## install git
sudo apt-get install git -y

## download panasonic remote
sudo curl 'https://git.krishnaconsultancy.co.in/?p=embedded/IR/lirc_remotes_code;a=blob_plain;f=remotes/panasonic/N2QAYB000976.conf' -H 'Connection: keep-alive' -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' -H 'Authorization: Basic Z2l0OnJlcG9AMTIzNA==' -H 'Upgrade-Insecure-Requests: 1' -H 'User-Agent: Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.132 Safari/537.36' -H 'Sec-Fetch-Mode: navigate' -H 'Sec-Fetch-User: ?1' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3' -H 'Sec-Fetch-Site: none' -H 'Accept-Encoding: gzip, deflate, br' -H 'Accept-Language: en-IN,en-GB;q=0.9,en-US;q=0.8,en;q=0.7,hi;q=0.6,mr;q=0.5,gu;q=0.4' --compressed > /etc/lirc/panasonic.conf
sudo curl 'https://git.krishnaconsultancy.co.in/?p=embedded/IR/lirc_remotes_code;a=blob_plain;f=remotes/philips/26PFL5604H.lircd.conf' -H 'Connection: keep-alive' -H 'Pragma: no-cache' -H 'Cache-Control: no-cache' -H 'Authorization: Basic Z2l0OnJlcG9AMTIzNA==' -H 'Upgrade-Insecure-Requests: 1' -H 'User-Agent: Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.132 Safari/537.36' -H 'Sec-Fetch-Mode: navigate' -H 'Sec-Fetch-User: ?1' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3' -H 'Sec-Fetch-Site: none' -H 'Accept-Encoding: gzip, deflate, br' -H 'Accept-Language: en-IN,en-GB;q=0.9,en-US;q=0.8,en;q=0.7,hi;q=0.6,mr;q=0.5,gu;q=0.4' --compressed > /etc/lirc/philips.conf


echo "Installing amazon repository"
echo "Starting setup, this will only work on Kodi V18 or greater..."
echo " "
echo "Installing dependencies..."
apt-get install python-pip python-crypto build-essential -y
apt-get install python-all-dev python-setuptools python-wheel -y
apt-get install python-crypto-dbg python-crypto-doc python-pip-whl -y
echo "Complete."
echo " "
echo "Setting up Pycryptodome..."
pip install pycryptodomex
ln -s /usr/lib/python2.7/dist-packages/Crypto /usr/lib/python2.7/dist-packages/Cryptodome
echo "Complete."
echo " "
echo "Getting Netflix Repository..."
mkdir ~/addons
cd ~/addons
wget https://github.com/castagnait/repository.castagnait/raw/master/repository.castagnait-1.0.0.zip
echo "Complete."
echo " "
echo "Getting Amazon Reporitory..."
wget https://github.com/Sandmann79/xbmc/releases/download/v1.0.2/repository.sandmann79.plugins-1.0.2.zip
wget https://raw.githubusercontent.com/mani-coder/plugin.video.youngkbell.hotstar/master/plugin.video.youngkbell.hotstar-v5.0.0.zip

echo " "
echo "Complete."
echo " "
echo "Reboot in"
echo "5"
sleep 1
echo "4"
sleep 1
echo "3"
sleep 1
echo "2"
sleep 1
echo "1"
sleep 1
sudo reboot