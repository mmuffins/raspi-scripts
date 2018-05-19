#!/bin/bash

#Setup torrent server for raspberry
#This will install rtorrent with flood

####
## debug settings
torrentUser="rtorrent"
delugeAccessLevel="10"
####


configdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f $configdir/raspi-setup-functions.sh ];
then
	echo -e "\e[91mraspi-setup-functions not found in $configdir/raspi-setup-functions, exiting script"; tput sgr0
	exit 2
fi

source "$configdir/raspi-setup-functions.sh"

echo ""
echo ""
echo -e "${MAGENTA}Torrent Server setup${NORMAL}"

echo -e "${LBLUE}Checking needed config files...${NORMAL}"

ExitIfFileIsMissing "$configdir/config/torrentsettings.txt"
ExitIfFileIsMissing "$configdir/config/rtorrent.rc"
ExitIfFileIsMissing "$configdir/config/rtorrent-init.txt"


SanitizeWindowsFileFormat "$configdir/config/torrentsettings.txt"
SanitizeWindowsFileFormat "$configdir/config/rtorrent.rc"
SanitizeWindowsFileFormat "$configdir/config/rtorrent-init.txt"



echo -e "${LBLUE}Creating user $torrentUser for the backup...${NORMAL}"
CreateUser $torrentUser false

mkdir -p /home/$torrentUser/torrents/{downloading,finished,.session,watch}
chown -R $torrentUser:$torrentUser /home/$torrentUser/torrents
chmod -R 777 /home/$torrentUser/torrents

echo -e "${LBLUE}Setting up fileshare permissions...${NORMAL}"



if [ -f /etc/samba/smb.conf ];
then
	echo '' >> /etc/samba/smb.conf
	echo '[torrents]' >> /etc/samba/smb.conf
	echo 'comment = Torrents' >> /etc/samba/smb.conf
	echo 'read only = no' >> /etc/samba/smb.conf
	echo 'writeable = yes' >> /etc/samba/smb.conf
	echo 'browsable = yes' >> /etc/samba/smb.conf
	echo 'guest ok = yes' >> /etc/samba/smb.conf
	echo 'guest account = nobody' >> /etc/samba/smb.conf
	echo "path = /home/$torrentUser/torrents" >> /etc/samba/smb.conf
fi

echo -e "${LBLUE}Restarting samba service...${NORMAL}"
service smbd restart


echo -e "${LBLUE}Increasing somaxconn and tcp_max_syn_backlog for better compatibility with torrents...${NORMAL}"

echo "" >> /etc/sysctl.conf
echo "#The following increases the limit for concurrent connections," >> /etc/sysctl.conf
echo "#which is needed for running a torrent client" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog=2048" >> /etc/sysctl.conf
echo "net.core.somaxconn=2048" >> /etc/sysctl.conf

/sbin/sysctl -p

echo -e "${LBLUE}The next part will take some time!${NORMAL}"
echo -e "${LBLUE}Installing Dependencies for rtorrent...${NORMAL}"

sudo apt-get install -y build-essential subversion autoconf screen g++ gcc ntp curl comerr-dev pkg-config cfv libtool libssl-dev libncurses5-dev ncurses-term libsigc++-2.0-dev libcppunit-dev libcurl3 libcurl4-openssl-dev git

echo -e "${LBLUE}Installing XML-RPC...${NORMAL}"
./configure --disable-libwww-client --disable-wininet-client --disable-abyss-server --disable-cgi-server
make -j2
sudo make install

echo -e "${LBLUE}Installing libTorrent...${NORMAL}"
cd /tmp
curl http://rtorrent.net/downloads/libtorrent-0.13.6.tar.gz | tar xz
cd libtorrent-0.13.6
./autogen.sh
./configure
make -j2
sudo make install

if ! foobar_loc="$(type -p "rtorrent")" || [ -z "$foobar_loc" ]; then
	echo -e "${LBLUE}Installing rTorrent...${NORMAL}"
	cd /tmp
	curl -L http://rtorrent.net/downloads/rtorrent-0.9.6.tar.gz -o rtorrent.tar.gz
	tar -zxvf rtorrent.tar.gz
	cd rtorrent-0.9.6
	./autogen.sh
	./configure --with-xmlrpc-c
	make -j2
	sudo make install
	sudo ldconfig
else
	echo -e "${LBLUE}rTorrent already installed, skipping installation${NORMAL}"
fi


echo -e "${LBLUE}Setting up rTorrent...${NORMAL}"
cp "$configdir/config/rtorrent.rc" "/home/$torrentUser/.rtorrent.rc"

echo "" >> /home/$torrentUser/.rtorrent.rc
echo "# Default torrent directories" >> /home/$torrentUser/.rtorrent.rc
echo "directory = /home/$torrentUser/torrents/downloading" >> /home/$torrentUser/.rtorrent.rc
echo "session = /home/$torrentUser/torrents/.session" >> /home/$torrentUser/.rtorrent.rc
echo "" >> /home/$torrentUser/.rtorrent.rc
echo "# Watch a directory for new torrents, and stop those that have been" >> /home/$torrentUser/.rtorrent.rc
echo "# deleted." >> /home/$torrentUser/.rtorrent.rc
echo "schedule = watch_directory,5,5,load_start=/home/$torrentUser/torrents/watch/*.torrent" >> /home/$torrentUser/.rtorrent.rc
echo "schedule = untied_directory,5,5,stop_untied=" >> /home/$torrentUser/.rtorrent.rc

chown $torrentUser:$torrentUser /home/$torrentUser/.rtorrent.rc

cp "$configdir/config/rtorrent-init.txt" /etc/init.d/rtorrent
sudo chmod +x /etc/init.d/rtorrent
sudo update-rc.d rtorrent defaults 99


echo -e "${LBLUE}Installing flood...${NORMAL}"
CreateUser flood false
curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
sudo apt-get install -y nodejs

cd /srv
git clone https://github.com/jfurrow/flood.git
cd flood
cp config.template.js config.js
npm install --production

chown -R flood:flood /srv/flood/

echo -e "${LBLUE}Setting Flood to run on startup...${NORMAL}"
echo "[Service]" >> /etc/systemd/system/flood.service
echo "WorkingDirectory=/srv/torrent/flood" >> /etc/systemd/system/flood.service
echo "ExecStart=/usr/bin/npm start" >> /etc/systemd/system/flood.service
echo "StandardOutput=syslog" >> /etc/systemd/system/flood.service
echo "StandardError=syslog" >> /etc/systemd/system/flood.service
echo "SyslogIdentifier=notell" >> /etc/systemd/system/flood.service
echo "User=flood" >> /etc/systemd/system/flood.service
echo "Group=flood" >> /etc/systemd/system/flood.service
echo "Environment=NODE_ENV=production" >> /etc/systemd/system/flood.service
echo "" >> /etc/systemd/system/flood.service
echo "[Install]" >> /etc/systemd/system/flood.service
echo "WantedBy=multi-user.target" >> /etc/systemd/system/flood.service
