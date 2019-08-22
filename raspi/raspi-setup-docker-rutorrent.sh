#!/bin/bash

# rutorrent setup via docker

rtorrentUser="rutorrent" # user will be created to run rutorrent
dockerDir="/home/mmuffins/docker"

configdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ ! -f $configdir/raspi-setup-functions.sh ];
then
	echo -e "\e[91mraspi-setup-functions not found in $configdir, exiting script";tput sgr0
	exit 2
fi
source "$configdir/raspi-setup-functions.sh"

if [ "$(id -u)" != "0" ]; then
	echo -e "${RED}This script must be run as root.${NORMAL}"
	exit 2
fi

echo ""
echo ""
echo -e "${MAGENTA}ruTorrent setup${NORMAL}"

echo -e "${BLUE}Checking needed config files...${NORMAL}"
$dockerComposeFile = "$configdir/config/docker-compose-rutorrent.yaml"
ExitIfFileIsMissing $dockerComposeFile

echo -e "${BLUE}Increasing somaxconn and tcp_max_syn_backlog for better compatibility with torrents...${NORMAL}"

echo "" >> /etc/sysctl.conf
echo "#The following increases the limit for concurrent connections," >> /etc/sysctl.conf
echo "#which is needed for running a torrent client" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog=4096" >> /etc/sysctl.conf
echo "net.core.somaxconn=4096" >> /etc/sysctl.conf
/sbin/sysctl -p

if [ $(cat /etc/sysctl.conf | grep -c net.ipv4.tcp_max_syn_backlog) -gt 1 ];
then
	echo -e "${YELLOW}Setting net.ipv4.tcp_max_syn_backlog was found multiple times in /etc/sysctl.conf, please check the file and remove all duplicate entries${NORMAL}"
fi

if [ $(cat /etc/sysctl.conf | grep -c net.core.somaxconn) -gt 1 ];
then
	echo -e "${YELLOW}Setting net.core.somaxconn was found multiple times in /etc/sysctl.conf, please check the file and remove all duplicate entries${NORMAL}"
fi

echo -e "${BLUE}Creating user...${NORMAL}"
CreateUser $rtorrentUser false

echo -e "${BLUE}Including configuration files in scheduled backup...${NORMAL}"

# Load backup location from the backup script configuration,
# revert to default values if none is found
backupList="/home/pibackup/backupscript/backup-list"

if [ -f "$configdir/config/backup.txt" ];
then
	source "$configdir/config/backup.txt"
fi

echo -e "${BLUE}Using backup file $backupList${NORMAL}"

if [ -f $backupList ];
then
	echo "#rtorrent" >> $backupList
	echo "/home/$rtorrentUser/config/*" >> $backupList
	grep -qF "$dockerDir/*" "$backupList" || echo "$dockerDir/*" >> $backupList
else
	echo -e "${RED}Could not locate backup at $backupList, backups were not scheduled${NORMAL}"
fi

echo -e "${BLUE}Setting up cronjob to cleanup old torrent files...${NORMAL}"
if [ "$(crontab -l -u $rtorrentUser | grep -c "^no crontab for")" = 0 ]; then
	#Workaround to create new blank crontab for the user with the correct permissions
	crontab -l -u $rtorrentUser |sed ""|crontab -u $rtorrentUser -
fi

if [ "$(crontab -l -u $rtorrentUser | grep -c ".torrent' -execdir rm --")" -gt 0 ]; then
	#Remove old cronjob if it already exists	
	crontab -l -u $rtorrentUser | grep -v ".torrent' -execdir rm --" 2>/dev/null | { cat;} | crontab -u $rtorrentUser -
fi

crontab -l -u $rtorrentUser 2>/dev/null | { cat; echo "0 3 * * * bash find /home/$rtorrentUser/config/rutorrent/profiles/torrents/ -type f -mtime +60 -name '*).torrent' -execdir rm -- '{}' \;"; } |  crontab -u $rtorrentUser -

echo -e "${BLUE}Creating docker compose files...${NORMAL}"

mkdir -p $dockerDir --verbose
cp $dockerComposeFile "$dockerDir/docker-compose-rutorrent.yaml"

dockerComposeFile="$dockerDir/docker-compose-rutorrent.yaml"

dockerPUID=$(id -u $rtorrentUser)
sed -i "s/PUID=<PUID>/PUID=$dockerPUID/g" $dockerComposeFile

dockerPGID=$(id -g $rtorrentUser)
sed -i "s/PGID=<PGID>/PGID=$dockerPGID/g" $dockerComposeFile

sed -i "s/<dockerConfigPath>:/\/home\/$rtorrentUser\/config:/g" $dockerComposeFile
sed -i "s/<dockerDownloadPath>:/\/home\/$rtorrentUser\/torrents:/g" $dockerComposeFile

echo -e "${GREEN}Docker ruTorrent setup complete. Run 'docker-compose -f $dockerComposeFile up --detach'to start docker${NORMAL}"
