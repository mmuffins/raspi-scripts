#!/bin/bash

#Setup for backup jobs for raspberry pi
#Part 1
#-Check if the basic ssh configuration was done
#-Exchange ssh keys between local host and backup target to enable rsync
#Part 2
#-create a backup folder in the home directory of the backup user
#-create a backup config file
#-put the actual backup script into the backup folder
#-schedule cron jobs to backup data and copy the backups to another location
#
#Whenever new applications are set up, they should add all locations that
#need to be backed up to the backup config file

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
echo -e "\e[95mBackup Setup"; tput sgr0
echo -e "\e[95mPart1 - enable exchange ssh keys with backup host"; tput sgr0

configfile="$configdir/config/backup.txt"
ExitIfFileIsMissing $configfile
source $configfile

sshDirectory="/home/$backupUser/.ssh"
knownHostsFile="$sshDirectory/known_hosts"
sshIdFile="$sshDirectory/id_rsa"


echo -e "\e[94mCreating user $backupUser for the backup...";tput sgr0
CreateUser $backupUser false

if [ $? = 0 ]; then
	ConfigureSSH $backupUser
fi

if [ $? != 0 ]; then
	ConfigureSSH $backupUser
	echo -e "\e[91mCould not create ssh keypairs for user, aborting script "
	exit 2
fi

#Check if needed ssh keys exist

if [ ! -d $sshDirectory ]; then
	echo -e "\e[91m$sshDirectory was not found, aborting script"
	exit 2
fi

ExitIfFileIsMissing "$sshIdFile"

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

#Doesn't do anything if rsync is already installed, so no harm in trying
echo -e "\e[94mInstalling rsync..."; tput sgr0
apt-get -y install rsync


if [ ! -d $backupDir ]; then
	echo -e "\e[91m$Creating $backupDir..."
	mkdir  $backupDir
	chown -R $backupUser:$backupUser $backupDir 
fi

if [ ! -d $backupScriptDir ]; then
	echo -e "\e[91m$Creating $backupScriptDir..."
	mkdir  $backupScriptDir
	
	cp $configfile $backupScriptDir
	
	chown -R $backupUser:$backupUser $backupScriptDir 
fi

date=`date +%Y-%m-%d-%H-%M`
tarname="$backupDir/backup_$(hostname)_$date.tar.bz2"
OPTS="--force --ignore-errors --delete-excluded --delete --backup --backup-dir=/$BACKUPDIR -a"

exit 0

#zip files
tar -cjf $tarname $backupDir/

#export PATH=$PATH:/bin:/usr/bin:/usr/local/bin
rsync -av $tarname $backupTargetUser@$backupTargetHost:$backupTargetDirectory

rm $tarname

#Remove files older than cutoff time on the target host
ssh $backupTargetUser@$backupTargetHost find $backupTargetDirectory -mtime +1