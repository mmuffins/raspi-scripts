#!/bin/bash

#Setup torrent server for raspberry
#This will install rtorrent with flood

####
## debug settings
rtorrentUser="rtorrent"
#Please check https://github.com/Kerwood/Rtorrent-Auto-Install for the latest version of the script
installscriptloc="https://raw.githubusercontent.com/Kerwood/rtorrent.auto.install/master"
installscript="Rtorrent-Auto-Install-4.0.0-Debian-Jessie"
####

####
#Variables
####


# Function to check if running user is root
function CHECK_ROOT {
	if [ "$(id -u)" != "0" ]; then
		echo
		echo "This script must be run as root." 1>&2
		echo
		exit 1
	fi
}

# Checks for apache2-utils and unzip if it's installed. It's is needed to make the Web user
function APACHE_UTILS {
	AP_UT_CHECK="$(dpkg-query -W -f='${Status}' apache2-utils 2>/dev/null | grep -c "ok installed")"
	UNZIP_CHECK="$(dpkg-query -W -f='${Status}' unzip 2>/dev/null | grep -c "ok installed")"
	CURL_CHECK="$(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed")"

	if [ "$AP_UT_CHECK" -ne 1 ] || [ "$UNZIP_CHECK" -ne 1 ] || [ "CURL_CHECK" -ne 1 ]; then
		echo " One or more of the packages apache2-utils, unzip or curl is not installed and is needed for the setup."
		read -p " Do you want to install it? [y/n] " -n 1
		if [[ $REPLY =~ [Yy]$ ]]; then
			clear
			apt-get update
			apt-get -y install apache2-utils unzip curl
		else
			clear
			exit
		fi
	fi
}

# License
function LICENSE {
	clear
	echo "${BOLD}--------------------------------------------------------------------------------"
	echo " THE BEER-WARE LICENSE (Revision 42):"
	echo " <patrick@kerwood.dk> wrote this script. As long as you retain this notice you"
	echo " can do whatever you want with this stuff. If we meet some day, and you think"
	echo " this stuff is worth it, you can buy me a beer in return."
	echo
	echo " - ${LBLUE}Patrick Kerwood @ LinuxBloggen.dk${NORMAL}"
	echo "${BOLD}--------------------------------------------------------------------------------${NORMAL}"
	echo
	read -p " Press any key to continue..." -n 1
	echo
}

# Function to set the system user, rtorrent is going to run as
function SET_RTORRENT_USER {
	con=0
	while [ $con -eq 0 ]; do
		echo -n "Please type a valid system user: "
		read RTORRENT_USER

		if [[ -z $(cat /etc/passwd | grep "^$RTORRENT_USER:") ]]; then
			echo
			echo "This user does not exist!"
		elif [[ $(cat /etc/passwd | grep "^$RTORRENT_USER:" | cut -d: -f3) -lt 999 ]]; then
			echo
			echo "That user's UID is too low!"
		elif [[ $RTORRENT_USER == nobody ]]; then
			echo
			echo "You cant use 'nobody' as user!"
		else
			HOMEDIR=$(cat /etc/passwd | grep "$RTORRENT_USER": | cut -d: -f6)
			con=1
		fi
	done
}

# Function to  create users for the webinterface
function SET_WEB_USER {
	while true; do
		echo -n "Please type the username for the webinterface, system user not required: "
		read WEB_USER
		USER=$(htpasswd -n $WEB_USER 2>/dev/null)
		if [ $? = 0 ]; then
			WEB_USER_ARRAY+=($USER)
			break
		else
			echo
			echo "${RED}Something went wrong!"
			echo "You have entered an unusable username and/or different passwords.${NORMAL}"
			echo
		fi
	done
}

# Function to list WebUI users in the menu
function LIST_WEB_USERS {
	for i in ${WEB_USER_ARRAY[@]}; do
		USER_CUT=$(echo $i | cut -d \: -f 1)
		echo -n " $USER_CUT"
	done
}

# Function to list plugins, downloaded, in the menu
function LIST_PLUGINS {
	if [ ${#PLUGIN_ARRAY[@]} -eq 0 ]; then
		echo "   No plugins downloaded!"
	else
		for i in "${PLUGIN_ARRAY[@]}"; do
			echo "   - $i"
		done
	fi
}

# Header for the menu
function HEADER {
	clear
	echo "${BOLD}--------------------------------------------------------------------------------"
	echo "                       Rtorrent + Rutorrent Auto Install"
	echo "                       ${LBLUE}Patrick Kerwood @ LinuxBloggen.dk${NORMAL}"
	echo "${BOLD}--------------------------------------------------------------------------------${NORMAL}"
	echo
}


# Function for installing dependencies
function APT_DEPENDENCIES {
	apt-get update
	apt-get -y install openssl git apache2 apache2-utils build-essential libsigc++-2.0-dev \
	libcurl4-openssl-dev automake libtool libcppunit-dev libncurses5-dev libapache2-mod-scgi \
	php5 php5-curl php5-cli libapache2-mod-php5 tmux unzip libssl-dev curl
}

# Function for setting up xmlrpc, libtorrent and rtorrent
function INSTALL_RTORRENT {
	# Use the temp folder for compiling
	cd /tmp

	# Download and install xmlrpc-c super-stable
	curl -L http://sourceforge.net/projects/xmlrpc-c/files/Xmlrpc-c%20Super%20Stable/1.33.18/xmlrpc-c-1.33.18.tgz/download -o xmlrpc-c.tgz
	tar zxvf xmlrpc-c.tgz
	mv xmlrpc-c-1.* xmlrpc
	cd xmlrpc
	./configure --disable-cplusplus
	make
	make install

	cd ..
	rm -rv xmlrpc*

	mkdir rtorrent
	cd rtorrent

	# Download and install libtorrent
	curl -L http://rtorrent.net/downloads/libtorrent-0.13.6.tar.gz -o libtorrent.tar.gz
	tar -zxvf libtorrent.tar.gz
	cd libtorrent-0.13.6
	./autogen.sh
	./configure
	make
	make install

	cd ..

	# Download and install rtorrent
	curl -L http://rtorrent.net/downloads/rtorrent-0.9.6.tar.gz -o rtorrent.tar.gz
	tar -zxvf rtorrent.tar.gz
	cd rtorrent-0.9.6
	./autogen.sh
	./configure --with-xmlrpc-c
	make
	make install

	cd ../..
	rm -rv rtorrent

	ldconfig

	# Creating session directory
	if [ ! -d "$HOMEDIR"/.rtorrent-session ]; then
		mkdir "$HOMEDIR"/.rtorrent-session
		chown "$RTORRENT_USER"."$RTORRENT_USER" "$HOMEDIR"/.rtorrent-session
	else
		chown "$RTORRENT_USER"."$RTORRENT_USER" "$HOMEDIR"/.rtorrent-session
	fi

	# Creating downloads folder
	if [ ! -d "$HOMEDIR"/Downloads ]; then
		mkdir "$HOMEDIR"/Downloads
		chown "$RTORRENT_USER"."$RTORRENT_USER" "$HOMEDIR"/Downloads
	else
		chown "$RTORRENT_USER"."$RTORRENT_USER" "$HOMEDIR"/Downloads
	fi

	# Downloading rtorrent.rc file.
	wget -O $HOMEDIR/.rtorrent.rc https://raw.github.com/Kerwood/rtorrent.auto.install/master/Files/rtorrent.rc
	chown "$RTORRENT_USER"."$RTORRENT_USER" $HOMEDIR/.rtorrent.rc
	sed -i "s@HOMEDIRHERE@$HOMEDIR@g" $HOMEDIR/.rtorrent.rc
}

# Function for installing rutorrent and plugins
function INSTALL_RUTORRENT {
	# Installing rutorrent.
	git clone git://github.com/Novik/ruTorrent/
	mv ruTorrent rutorrent

	if [ -d /var/www/html/rutorrent ]; then
		rm -r /var/www/html/rutorrent
	fi

	# Changeing SCGI mount point in rutorrent config.
	sed -i "s/\/RPC2/\/rutorrent\/RPC2/g" ./rutorrent/conf/config.php

	mv -f rutorrent /var/www/html/

	# Changing permissions for rutorrent and plugins.
	chown -R www-data.www-data /var/www/html/rutorrent
	chmod -R 775 /var/www/html/rutorrent
}

# Function for configuring apache
function CONFIGURE_APACHE {
	# Creating symlink for scgi.load
	if [ ! -h /etc/apache2/mods-enabled/scgi.load ]; then
		ln -s /etc/apache2/mods-available/scgi.load /etc/apache2/mods-enabled/scgi.load
	fi

	# Check if apache2 has port 80 enabled
	if ! grep --quiet "^Listen 80$" /etc/apache2/ports.conf; then
		echo "Listen 80" >> /etc/apache2/ports.conf;
	fi

	# Adding ServerName localhost to apache2.conf
	if ! grep --quiet "^ServerName$" /etc/apache2/apache2.conf; then
		echo "ServerName localhost" >> /etc/apache2/apache2.conf;
	fi

	# Creating Apache virtual host
	if [ ! -f /etc/apache2/sites-available/001-default-rutorrent.conf ]; then

		cat > /etc/apache2/sites-available/001-default-rutorrent.conf << EOF
<VirtualHost *:80>
    #ServerName www.example.com
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

    CustomLog /var/log/apache2/rutorrent.log vhost_combined
    ErrorLog /var/log/apache2/rutorrent_error.log
    SCGIMount /rutorrent/RPC2 127.0.0.1:5000

    <Directory "/var/www/html/rutorrent">
        AuthName "Tits or GTFO"
        AuthType Basic
        Require valid-user
        AuthUserFile /var/www/html/rutorrent/.htpasswd
    </Directory>

</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF
		a2ensite 001-default-rutorrent.conf
		a2dissite 000-default.conf
		systemctl restart apache2.service
	fi

	# Creating .htaccess file
	printf "%s\n" "${WEB_USER_ARRAY[@]}" > /var/www/html/rutorrent/.htpasswd
}

function INSTALL_FFMPEG {
	printf "\n# ffpmeg mirror\ndeb http://www.deb-multimedia.org jessie main non-free\n" >> /etc/apt/sources.list
	apt-get update
	apt-get -y --force-yes install deb-multimedia-keyring
	apt-get update
	apt-get -y install ffmpeg
}

# Function for showing the end result when install is complete
function INSTALL_COMPLETE {
	rm -rf $TEMP_PLUGIN_DIR

	HEADER

	echo "${GREEN}Installation is complete.${NORMAL}"
	echo
	echo
	echo "${RED}Your default Apache2 vhost file has been disabled and replaced with a new one.${NORMAL}"
	echo "${RED}If you were using it, combine the default and rutorrent vhost file and enable it again.${NORMAL}"
	echo
	echo "${PURPLE}Your downloads folder is in ${LBLUE}$HOMEDIR/Downloads${NORMAL}"
	echo "${PURPLE}Sessions data is ${LBLUE}$HOMEDIR/.rtorrent-session${NORMAL}"
	echo "${PURPLE}rtorrent's configuration file is ${LBLUE}$HOMEDIR/.rtorrent.rc${NORMAL}"
	echo
	echo "${PURPLE}If you want to change settings for rtorrent, such as download folder, etc.,"
	echo "you need to edit the '.rtorrent.rc' file. E.g. 'nano $HOMEDIR/.rtorrent.rc'${NORMAL}"
	echo
	echo "Rtorrent can be started without rebooting with 'sudo systemctl start rtorrent.service'."

	# The IPv6 local address, is not very used for now, anyway if needed, just change 'inet' to 'inet6'
	lcl=$(ip addr | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | grep -v "127." | head -n 1)
	ext=$(curl -s http://icanhazip.com)

	if [[ ! -z "$lcl" ]] && [[ ! -z "$ext" ]]; then
		echo "${LBLUE}LOCAL IP:${NORMAL} http://$lcl/rutorrent"
		echo "${LBLUE}EXTERNAL IP:${NORMAL} http://$ext/rutorrent"
		echo
		echo "Visit rutorrent through the above address."
		echo
	else
		if [[ -z "$lcl" ]]; then
			echo "Can't detect the local IP address"
			echo "Try visit rutorrent at http://127.0.0.1/rutorrent"
			echo
		elif [[ -z "$ext" ]]; then
			echo "${LBLUE}LOCAL:${NORMAL} http://$lcl/rutorrent"
			echo "Visit rutorrent through your local network"
		else
			echo "Can't detect the IP address"
			echo "Try visit rutorrent at http://127.0.0.1/rutorrent"
			echo
		fi
	fi
}

function INSTALL_SYSTEMD_SERVICE {
	cat > "/etc/systemd/system/rtorrent.service" <<-EOF
	[Unit]
	Description=rtorrent (in tmux)
	[Service]
	Type=oneshot
	RemainAfterExit=yes
	User=$RTORRENT_USER
	ExecStart=/usr/bin/tmux -2 new-session -d -s rtorrent rtorrent
	ExecStop=/usr/bin/tmux kill-session -t rtorrent
	[Install]
	WantedBy=default.target
	EOF

	systemctl enable rtorrent.service
}

function START_RTORRENT {
	systemctl start rtorrent.service
}





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
#ExitIfFileIsMissing "$configdir/config/rtorrent.rc"
#ExitIfFileIsMissing "$configdir/config/rtorrent-init.txt"


SanitizeWindowsFileFormat "$configdir/config/torrentsettings.txt"
#SanitizeWindowsFileFormat "$configdir/config/rtorrent.rc"
#SanitizeWindowsFileFormat "$configdir/config/rtorrent-init.txt"

echo -e "${LBLUE}Creating user $rtorrentUser...${NORMAL}"
CreateUser $rtorrentUser false

mkdir -p /home/$rtorrentUser/torrents/{downloading,finished,watch}
chown -R $rtorrentUser:$rtorrentUser /home/$rtorrentUser/torrents
chmod -R 775 /home/$rtorrentUser/torrents

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
	echo "path = /home/$rtorrentUser/torrents" >> /etc/samba/smb.conf
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

echo -e "${LBLUE}Including configuration files in scheduled backup...${NORMAL}"

# Load backup location from the backup script configuration,
# revert to default values if none is found
backupList="/home/pibackup/backupscript/backup-list"

if [ -f "$configdir/config/backup.txt" ];
then
	source "$configdir/config/backup.txt"
fi

echo -e "${LBLUE}Using backup file $backupList ${NORMAL}"

if [ -f $backupList ];
then
	echo "#rtorrent" >> $backupList
	echo "/home/$rtorrentUser/.rtorrent.rc" >> $backupList
	echo "/home/$rtorrentUser/.rtorrent-session/*" >> $backupList
	echo "#apache" >> $backupList
	echo "/var/www/*" >> $backupList
	echo "/etc/apache2/*" >> $backupList
else
	echo -e "${RED}Could not locate backup at $backupList, backups were not scheduled {NORMAL}"
fi


echo -e "${LBLUE}Installing rutorrent...${NORMAL}"

cd /tmp
#wget "$installscriptloc/$installscript"
#chmod +x $installscript
#sudo ./$installscript



# Formatting variables
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
GREEN=$(tput setaf 2)
LBLUE=$(tput setaf 6)
RED=$(tput setaf 1)
PURPLE=$(tput setaf 5)

# The system user rtorrent is going to run as
RTORRENT_USER=""

# The user that is going to log into rutorrent (htaccess)
WEB_USER=""

# Array with webusers including their hashed paswords
WEB_USER_ARRAY=()

# Temporary download folder for plugins
TEMP_PLUGIN_DIR="/tmp/rutorrentPlugins"

# Array of downloaded plugins
PLUGIN_ARRAY=()

#rTorrent users home dir.
HOMEDIR=""




CHECK_ROOT
LICENSE
APACHE_UTILS
rm -rf $TEMP_PLUGIN_DIR
HEADER
SET_RTORRENT_USER
SET_WEB_USER

# NOTICE: Change lib, rtorrent, rutorrent versions on upgrades.
while true; do
	HEADER
	echo " ${BOLD}rTorrent version:${NORMAL} ${RED}0.9.4${NORMAL}"
	echo " ${BOLD}libTorrent version:${NORMAL} ${RED}0.13.4${NORMAL}"
	echo " ${BOLD}ruTorrent version:${NORMAL} ${RED}3.6${NORMAL}"
	echo
	echo " ${BOLD}rTorrent user:${NORMAL}${GREEN} $RTORRENT_USER${NORMAL}"
	echo
	echo -n " ${BOLD}ruTorrent user(s):${NORMAL}${GREEN}"
	LIST_WEB_USERS
	echo
	echo
	echo " ${NORMAL}${BOLD}ruTorrent plugins:${NORMAL}${GREEN}"
	LIST_PLUGINS
	echo
	echo " ${NORMAL}[1] - Change rTorrent user"
	echo " [2] - Add another ruTorrent user"
	echo
	echo " [0] - Start installation"
	echo " [q] - Quit"
	echo
	echo -n "${GREEN}>>${NORMAL} "
	read case

	case "$case" in
		1)
			SET_RTORRENT_USER
			;;
		2)
			SET_WEB_USER
			;;
		0)
			APT_DEPENDENCIES
			INSTALL_RTORRENT
			INSTALL_RUTORRENT
			CONFIGURE_APACHE
			INSTALL_SYSTEMD_SERVICE
			START_RTORRENT
			INSTALL_COMPLETE
			break
			;;
		q)
			break
			;;
	esac
done
