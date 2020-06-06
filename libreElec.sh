sudo apt-get update -y
## for performance
cat > /storage/.kodi/userdata/advancedsettings.xml <<EOF
<advancedsettings version="1.0">
    <gui>
        <algorithmdirtyregions>1</algorithmdirtyregions>
        <nofliptimeout>0</nofliptimeout>
    </gui>
</advancedsettings>
EOF
echo "Add autoexec.py to download latest iptv list from https://mxplayer.in"
cat > /storage/.kodi/userdata/autoexec.py <<EOF
import os, xbmc
import urllib2
import re, json

content = urllib2.urlopen("https://www.mxplayer.in/browse/live-tv").read()
#f = open("live-tv.html", "r")
#content = f.read()
obj = json.loads(re.match(r'^.*window.state = (.*)', content).groups()[0])
data = {}
for channel in obj["live"]["channels"]:
    toAdd = False
    for lang in channel["languages"]:
        if lang["id"] in ["en", "hi", "mr", "gu"]:
            toAdd = True
    if toAdd:
        if channel["category"] not in data:
            data[channel["category"]] = []
        data.get(channel["category"], []).append({
            "title":channel["title"], 
            "stream":channel["stream"]["mxplay"]["hls"]
        })

p = xbmc.translatePath(os.path.join('special://home', 'index.m3u8'))
f = open(p, "w+")
for cat in data:
    for channel in data[cat]:
        f.write("#EXTINF:0,{}\n{}\n".format(channel["title"], channel["stream"]["main"]))
f.close()
EOF

## download panasonic remote
echo "Downloading and configuring philips remote"
sudo curl 'https://git.krishnaconsultancy.co.in/?p=embedded/IR/lirc_remotes_code;a=blob_plain;f=remotes/panasonic/N2QAYB000976.conf' -H 'Authorization: Basic Z2l0OnJlcG9AMTIzNA==' --compressed > /storage/.config/lircd.conf

mount -o remount,rw /flash
printf "\n\ndtoverlay=gpio-ir,gpio_pin=5" >> /flash/config.txt
mount -o remount,ro /flash

cat > /storage/.config/autostart.sh <<EOF
setserial /dev/ttyS0 uart unknown
modprobe serial_ir
EOF

