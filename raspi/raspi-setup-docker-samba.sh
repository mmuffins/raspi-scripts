#!/bin/bash

#Samba setup via docker
sambaUser=mmuffins #user to take the PID and GID to give access to the local filesystem

configdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f $configdir/raspi-setup-functions.sh ];
then
	echo -e "\e[91mraspi-setup-functions not found in $configdir, exiting script";tput sgr0
	exit 2
fi

source "$configdir/raspi-setup-functions.sh"

echo ""
echo ""
echo -e "${MAGENTA}Samba setup${NORMAL}"

echo -e "${BLUE}Checking needed config files...${NORMAL}"

dockerComposeFile="$configdir/config/docker-compose-samba.yaml"
ExitIfFileIsMissing $dockerComposeFile

echo -e "${BLUE}Disabling samba daemon service if it's running...${NORMAL}"
systemctl stop smbd
systemctl disable smbd

dockerDir="/home/mmuffins/docker"
mkdir -p $dockerDir --verbose
cp $dockerComposeFile $dockerDir

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
	grep -qF "$dockerDir/*" "$backupList" || echo "$dockerDir/*" >> $backupList
else
	echo -e "${RED}Could not locate backup at $backupList, backups were not scheduled${NORMAL}"
fi

echo -e "${BLUE}Creating docker compose files...${NORMAL}"

mkdir -p $dockerDir --verbose
cp $dockerComposeFile "$dockerDir/docker-compose-samba.yaml"
dockerComposeFile="$dockerDir/docker-compose-samba.yaml"


sambaUID=$(id -u $sambaUser)
sed -i "s/USERID=<USERID>/USERID=$sambaUID/g" $dockerComposeFile

sambaGID=$(id -g $sambaUser)
sed -i "s/GROUPID=<GROUPID>/GROUPID=$sambaGID/g" $dockerComposeFile

echo -e "${GREEN}Docker samba setup complete. Run 'docker-compose -f $dockerComposeFile up --detach'to start docker${NORMAL}"