#!/bin/bash

#Setup for backup jobs for raspberry pi
#Part 1
#-Check if the basic ssh configuration was done
#-Exchange ssh keys between local host and backup target to enable rsync
#Part 2
#-create a backup folder in the home directory of the backup user
#-Exchange ssh keys with the backup target server
#-Set up the actual backu script and schedule cron jobs for it


configdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f $configdir/raspi-setup-functions.sh ];
then
	echo -e "\e[91mraspi-setup-user not found in $configdir/raspi-setup-functions, exiting script"; tput sgr0
	exit 2
fi

source "$configdir/raspi-setup-functions.sh"

echo ""
echo ""
echo -e "\e[95mBackup Setup"; tput sgr0
echo -e "\e[95mPart1 - enable exchange ssh keys with backup host"; tput sgr0

configfile="$configdir/config/backup.txt"
ExitIfFileIsMissing $configfile
source $configfile

backupsyncscript="$configdir/raspi-backup-syncfiles.sh"
ExitIfFileIsMissing $backupsyncscript

sshDirectory="/home/$backupUser/.ssh"
knownHostsFile="$sshDirectory/known_hosts"
sshIdFile="$sshDirectory/id_rsa"


echo -e "\e[94mCreating user $backupUser for the backup...";tput sgr0
CreateUser $backupUser false

if [ $? = 0 ]; then
	ConfigureSSH $backupUser
fi

if [ $? != 0 ]; then
	echo -e "\e[91mCould not create ssh keypairs for user, aborting script "; tput sgr0
	exit 2
fi

#Check if needed ssh keys exist

if [ ! -d $sshDirectory ]; then
	echo -e "\e[91m$sshDirectory was not found, aborting script"; tput sgr0
	exit 2
fi

ExitIfFileIsMissing "$sshIdFile"

echo -e "\e[94mGiving sudo permissions to $backupUser..."
tput sgr0

if [ "$(grep -c "^$backupUser " /etc/sudoers)" -gt 0 ]; then
	echo -e "\e[94m$backupUser was already present in /etc/sudoers, no actions were performed."
		tput sgr0
else
	sudo bash -c 'echo "$0 ALL=(ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)' $backupUser
fi


#Take ownership of the ssh directory to prevent permission errors
chown -R $USER:$USER $sshDirectory

#Add backup hosts to known_hosts to avoid confirmation promts when connecting via ssh/rsync

if [ -e $knownHostsFile ]; then
	#known_hosts exist, import ssh key
	echo -e "\e[94mFound known hosts file in $knownHostsFile"; tput sgr0
	echo -e "\e[94mImporting ssh keys for host $backupTargetHost..."; tput sgr0
	
	tmpKnownHosts="/tmp/raspi_setup_tmp_knownhosts"
	ssh-keyscan -t rsa,dsa,ecdsa -H $backupTargetHost 2>&1 | sort -u - $knownHostsFile > $tmpKnownHosts
	mv $tmpKnownHosts $knownHostsFile
else
	#known_hosts doesn't exist yet, create a new one
	echo -e "\e[94mCould not find existing known_hosts file, creating new one"; tput sgr0
	echo -e "\e[94mImporting ssh keys for host $backupTargetHost..."; tput sgr0
	
	ssh-keyscan -t rsa,dsa,ecdsa -H $backupTargetHost >> $knownHostsFile
fi

echo -e "\e[93mPlease enter the password for user $backupTargetUser when prompted"; tput sgr0
ssh-copy-id -i $sshIdFile $backupTargetUser@$backupTargetHost

chown -R $backupUser:$backupUser $sshDirectory

#******************
#It's possible to test if login works by running
#sudo ssh -i $sshIdFile "$backupUser@$backupTargetHost"
#If no password is requested ssh access is properly set up
#******************

echo -e "\e[92mCompleted ssh key exchange with backup target"; tput sgr0
echo -e "\e[95mPart2 - Setup backup"; tput sgr0


which rsync > /dev/null 2>&1

if [ $? != 0 ]; then
	echo -e "\e[94mInstalling rsync..."; tput sgr0
	apt-get -y install rsync
else
	echo -e "\e[94mrsync already installed"; tput sgr0
fi


if [ ! -d $backupDir ]; then
	echo -e "\e[94mCreating $backupDir..."; tput sgr0
	mkdir  $backupDir
	
	chmod 777 $backupScriptDir 
	chown $backupUser:$backupUser $backupDir 
fi

if [ ! -d $backupScriptDir ]; then
	echo -e "\e[94mCreating $backupScriptDir..."; tput sgr0
	mkdir  $backupScriptDir
	
	chmod 777 $backupScriptDir 
	chown $backupUser:$backupUser $backupScriptDir 
fi

if [ ! -d $logDirectory ]; then
	echo -e "\e[94mCreating $logDirectory..."; tput sgr0
	mkdir  $logDirectory
		
	chmod 777 $logDirectory 
	chown $backupUser:$backupUser $logDirectory 
fi

#both the backup list and backup config could contain userdate, don't overwrite if they already exist

if [ ! -f "$backupScriptDir/backup-config" ]; then
	echo -e "\e[94mCopy $configfile to $backupScriptDir/backup-config..."; tput sgr0
	cp $configfile "$backupScriptDir/backup-config"
	chown $backupUser:$backupUser "$backupScriptDir/backup-config"
fi

if [ ! -f "$backupList" ]; then
	echo -e "\e[94mCreating $backupList..."; tput sgr0
	touch $backupList
	chown -R $backupUser:$backupUser $backupList
	chmod 666 $backupList 
fi


#No userdata in the actual backup script, always overwrite
echo -e "\e[94mCopy $backupsyncscript to $backupScriptDir/raspi-backup-syncfiles.sh..."; tput sgr0
cp $backupsyncscript "$backupScriptDir/raspi-backup-syncfiles.sh"
chmod 777 "$backupScriptDir/raspi-backup-syncfiles.sh"
chown -R $backupUser:$backupUser "$backupScriptDir/raspi-backup-syncfiles.sh"


echo -e "\e[94mSetting up cronjob..."; tput sgr0


if [ "$(crontab -l -u $backupUser | grep -c "^no crontab for")" = 0 ]; then
	#Workaround to create new blank crontab for the backup user with the correct permissions
	crontab -l -u $backupUser |sed ""|crontab -u $backupUser -
fi

if [ "$(crontab -l -u $backupUser | grep -c "$backupScriptDir/raspi-backup-syncfiles.sh")" -gt 0 ]; then
	#Remove old cronjob if it already exists	
	crontab -l -u $backupUser | grep -v "$backupScriptDir/raspi-backup-syncfiles.sh" 2>/dev/null | { cat;} | crontab -u $backupUser -

fi

crontab -l -u $backupUser 2>/dev/null | { cat; echo "$cronSchedule bash $backupScriptDir/raspi-backup-syncfiles.sh >/dev/null 2>&1"; } |  crontab -u $backupUser -

echo -e "\e[92mAll files set up, please see $backupList for instructions on how to further set up backup"
echo ""
echo -e "\e[92mBackup setup complete!"
tput sgr0

