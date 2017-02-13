#!/bin/bash

#Functions for other deployment scripts
#Colors:
#Header (magenta) echo -e "\e[95m
#Error (red) echo -e "\e[91m
#Success (green) echo -e "\e[92m
#Default verbose (blue) echo -e "\e[94m
#Prompt (yellow) echo -e "\e[93m
#tput sgr0


CreateUser() {
	#u - Username
	#b - set if the password should be blank for the user, otherwise it is promted during setup
	
	username=''
	setBlankPassword=false

	while getopts 'abf:v' flag; do
		case "${flag}" in
			u) username="${OPTARG}" ;;
			b) setBlankPassword='true' ;;
			*) error "Unexpected option ${flag}" ;;
		esac
	done
	
	if [ -z "$username" ]; then
		echo -e "\e[91mBlank username was provided"
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

	
	echo -e "\e[94mSetting up basic ssh settings for $username..."
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

SanitizeWindowsFileFormat(){

	#The format windows saves files is incompatible with some operations, 
	#they should be converted to a linux compatible format
	#To see the error, run the following command before sanitizing the files:
	#awk -F";" {'print $2,$1'} hostlist.txt
	
	awk '{ sub("\r$", ""); print }' $1 > /tmp/raspi-config-tempfile
	rm $1
	mv /tmp/raspi-config-tempfile $1

}

ReadSettings(){
	#Reads the settings file and returns
	#a hashtable with the results
	
	
#!/bin/ksh
file="/home/vivek/data.txt"
while IFS= read line
do
        # display $line or do somthing with $line
	echo "$line"
done <"$file"
}