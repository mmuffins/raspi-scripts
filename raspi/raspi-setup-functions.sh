#!/bin/bash

# Functions for other deployment scripts

# Formatting colors
BOLD="\e[94m"
NORMAL="\e[94m"
GREEN="\e[92m" # Success
BLUE="\e[94m" # Default verbose (light blue)
RED="\e[91m" # Error
YELLOW="\e[93m" # Prompt
MAGENTA="\e[95m" # Prompt


CreateUser() {
	#$1 - Username
	#$2 - set to false if the password should be blank for the user, otherwise it is promted during setup
	
	username=$1
	setBlankPassword=$2

	if [ -z "$username" ]; then
		echo -e "\e[91mBlank username was provided"
		tput sgr0
		return 2
	fi

	if [ $(id -u $username 2>/dev/null || echo -1) -ge 0 ]; then
		echo -e "\e[94m$username was already present in /etc/passwd, no actions were performed."
		tput sgr0
		return 2
	fi
	
	addUserParams='--gecos ""'
	
	if [ "$setBlankPassword" = false ]; then
		addUserParams=$addUserParams" --disabled-login"
	fi
	
	echo -e "\e[94mCreating user $username with parameters $addUserParams..."
	tput sgr0
	
	if [ "$setBlankPassword" = true ]; then
		echo -e "\e[93mWhen prompted, please enter a password for user $username"
		tput sgr0
	fi
	
	adduser $addUserParams $username
	
	if [ $? != 0 ]; then
		echo -e "\e[91mError while creating user $username"
		tput sgr0
		return 2
	fi
	
	return 0
}

ConfigureSSH() {
	#Sets up basic SSH configuration with private/public keys
	#$1 - Username

	username=$1
	sshDirectory="/home/$username/.ssh"
	sshIdFile="$sshDirectory/id_rsa"

	
	echo -e "\e[94mCreating ssh keypair for $username..."
	echo -e "\e[94mCreating $sshDirectory..."
	tput sgr0
	mkdir $sshDirectory
	chmod 700 $sshDirectory
	
	#Take ownership of the ssh Directory to prevent permission errors
	chown -R $USER:$USER $sshDirectory
	
	echo -e "\e[94mCreating ssh keypair..."
	ssh-keygen -t rsa -C "$username@$HOSTNAME" -f $sshIdFile -q -N ""
	tput sgr0
	
	if [ $? != 0 ]; then
		echo -e "\e[91mError while creating ssh keypair $sshIdFile for user $username"
		tput sgr0
		
		chown $username:$username $sshDirectory
		return 2
	fi
	
	chown $username:$username $sshDirectory
	
	return 0
}

ExitIfFileIsMissing() {
	#Completely exits script execution if the provided file was not found
	if [ ! -f $1 ];
	then
		echo -e "\e[91m$1 was not found, exiting script"
		tput sgr0
		exit 2
	fi
}

SanitizeWindowsFileFormat() {

	#The format windows saves files is incompatible with some operations, 
	#they should be converted to a linux compatible format
	#To see the error, run the following command before sanitizing the files:
	#awk -F";" {'print $2,$1'} hostlist.txt
	
	awk '{ sub("\r$", ""); print }' $1 > /tmp/raspi-config-tempfile
	rm $1
	mv /tmp/raspi-config-tempfile $1

}


GetSettings() {
	#Returns sanatized contents of a config file
	#$1 - Path of the config file

	configlocation=$1

	if [ -z "$configlocation" ]; then
		echo -e "\e[91mNo config file location was provided"
		tput sgr0
		return 2
	fi

	if [ ! -f $configlocation ];
	then
		echo -e "\e[91mCould not open file at $configlocation"
		tput sgr0
		exit 2
	fi

	sed 's/^[ \t]*//;s/[ \t]*$//' $configlocation | grep -v '^#'
	
}