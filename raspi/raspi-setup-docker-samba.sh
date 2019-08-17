#!/bin/bash

#Samba setup via docker
sambaUser=mmuffins #user to take the PID and GID to give access to the local filesystem

configdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f $configdir/raspi-setup-functions.sh ];
then
	echo -e "${RED}raspi-setup-functions not found in $configdir/raspi-setup-functions, exiting script${NORMAL}"
	exit 2
fi

source "$configdir/raspi-setup-functions.sh"

echo ""
echo ""
echo -e "${MAGENTA}mSamba setup${NORMAL}"

echo -e "${BLUE}Checking needed config files...${NORMAL}"

ExitIfFileIsMissing "$configdir/config/docker-compose-samba.yaml"



docker create --name samba2 --restart unless-stopped -p 139:139 -p 445:445 -e USERID=$(id -g $sambaUser) -e GROUPID=$(id -g $sambaUser) -e PERMISSION=0700 -e USER="samba;Smb12345" -v /home:/home -e SHARE="home;/home;yes;no;no;all;" -e SHARE2="torrents;/home/rtorrent/torrents;yes;no;no;all;"  dperson/samba:armhf
