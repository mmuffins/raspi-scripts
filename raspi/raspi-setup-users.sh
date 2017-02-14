#!/bin/bash

#Create default users
#Check if all needed files exist
configdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f $configdir/raspi-setup-functions.sh ];
then
	echo -e "\e[91mraspi-setup-user not found in $configdir/raspi-setup-functions, exiting script"
	tput sgr0
	exit 2
fi

source "$configdir/raspi-setup-functions.sh"

echo ""
echo ""
echo -e "\e[95mUser setup"
tput sgr0

ExitIfFileIsMissing "$configdir/config/raspiusers.txt"
ExitIfFileIsMissing "$configdir/config/raspirootusers.txt"

#get userlist
userlist=($(GetSettings "$configdir/config/raspiusers.txt"))
rootlist=($(GetSettings "$configdir/config/raspirootusers.txt"))

#loop through userlist, create user and, if successful, setup ssh keypairs
for i in "${!userlist[@]}"; do 
	IFS=';' read -a splitarray <<< "${userlist[$i]}"
	CreateUser ${splitarray[0]} ${splitarray[1]} 
	
	if [ $? = 0 ]; then
		ConfigureSSH ${splitarray[0]}
	fi
done


#give root permissions to all users in the rootlist
for i in "${!rootlist[@]}"; do 
	lineuser=${rootlist[$i]}
	
	echo -e "\e[94mGiving sudo permissions to $lineuser..."
	tput sgr0
	
	if [ "$(grep -c "^$lineuser " /etc/sudoers)" -gt 0 ]; then
		echo -e "\e[94m$lineuser was already present in /etc/sudoers, no actions were performed."
			tput sgr0
	else
		sudo bash -c 'echo "$0 ALL=(ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)' $lineuser
	fi
done


echo ""
echo -e "\e[92mUser setup complete!"
#echo -e "\e[93mRemember to disable the default admin!"
tput sgr0














