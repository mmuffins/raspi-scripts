#!/bin/bash

#Setup for backup jobs for raspberry pi
#Part 1
#-Check if the basic ssh configuration was done
#-Exchange ssh keys between local host and backup target to enable rsync
#Part 2
#-create a backup folder in the home directory of the backup user
#-Exchange ssh keys with the backup target server
#-Set up the actual backu script and schedule cron jobs for it

CreateBackupDir() {
	#$1 - Path
	#$2 - owner user
	#$3 - permission mask
	mkdir -p  $1
	chown $2:$2 $1 
	chmod $3 $1 
}



configdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f $configdir/raspi-setup-functions.sh ];
then
	echo -e "\e[91mraspi-setup-functions not found in $configdir, exiting script"; tput sgr0
	exit 2
fi

source "$configdir/raspi-setup-functions.sh"

echo ""
echo ""
echo -e "${MAGENTA}Backup Setup${NORMAL}"

configfile="$configdir/config/backup.txt"
ExitIfFileIsMissing $configfile
source $configfile

backupsyncscript="$configdir/raspi-backup-syncfiles.sh"
ExitIfFileIsMissing $backupsyncscript

echo -e "${BLUE}Creating user $backupUser...${NORMAL}"
CreateUser $backupUser false

echo -e "${BLUE}Giving sudo permissions to $backupUser...${NORMAL}"

if [ "$(grep -c "^$backupUser " /etc/sudoers)" -gt 0 ]; then
	echo -e "${BLUE}$backupUser was already present in /etc/sudoers, no actions were performed.${NORMAL}"
else
	sudo bash -c 'echo "$0 ALL=(ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)' $backupUser
fi

echo -e "${BLUE}Creating $backupDir...${NORMAL}"
CreateBackupDir $backupDir $backupUser 777

echo -e "${BLUE}Creating $backupScriptDir...${NORMAL}"
CreateBackupDir $backupScriptDir $backupUser 777

echo -e "${BLUE}Creating $logDirectory...${NORMAL}"
CreateBackupDir $logDirectory $backupUser 777

echo -e "${BLUE}Creating $backupScriptDir/mnt...${NORMAL}"
CreateBackupDir "$backupScriptDir/mnt" $backupUser 777


backupCredFile="$backupScriptDir/.backupcreds"
echo -e "${BLUE}Creating samba/cifs credential file at $backupCredFile${NORMAL}"
echo -e "${YELLOW}Please enter the password for user $backupTargetUser on remote share $remoteshare${NORMAL}"

read -s -p "Enter Password: " pibackupPass
echo "username=$backupTargetUser" >> "$backupCredFile"
echo "password=$pibackupPass" >> "$backupCredFile"
chmod 0600 $backupCredFile
chown $backupUser:$backupUser $backupCredFile

#both the backup list and backup config could contain userdate, don't overwrite if they already exist

if [ ! -f "$backupScriptDir/backup-config" ]; then
	echo -e "${BLUE}Copy $configfile to $backupScriptDir/backup-config...${NORMAL}"
	cp $configfile "$backupScriptDir/backup-config"
	chown $backupUser:$backupUser "$backupScriptDir/backup-config"
fi

if [ ! -f "$backupList" ]; then
	echo -e "${BLUE}Creating $backupList...${NORMAL}"
	touch $backupList
	chown -R $backupUser:$backupUser $backupList
	chmod 666 $backupList 
fi

#No userdata in the actual backup script, always overwrite
echo -e "\e[94mCopy $backupsyncscript to $backupScriptDir/raspi-backup-syncfiles.sh..."; tput sgr0
cp $backupsyncscript "$backupScriptDir/raspi-backup-syncfiles.sh"
chmod 777 "$backupScriptDir/raspi-backup-syncfiles.sh"
chown -R $backupUser:$backupUser "$backupScriptDir/raspi-backup-syncfiles.sh"

echo -e "${BLUE}Installing cifs-utils...${NORMAL}"
apt-get -y install cifs-utils
# we want to run samba via docker, the samba daemon can interfere with that, disable it
systemctl stop smbd
systemctl disable smbd

echo -e "${BLUE}Updating /etc/fstab...${NORMAL}"
echo "$remoteshare   $backupScriptDir/mnt  cifs  noauto,users,credentials=$backupCredFile,vers=1.0  0  0" >> /etc/fstab


echo -e "${BLUE}Setting up cronjob...${NORMAL}"


if [ "$(crontab -l -u $backupUser | grep -c "^no crontab for")" = 0 ]; then
	#Workaround to create new blank crontab for the backup user with the correct permissions
	crontab -l -u $backupUser |sed ""|crontab -u $backupUser -
fi

if [ "$(crontab -l -u $backupUser | grep -c "$backupScriptDir/raspi-backup-syncfiles.sh")" -gt 0 ]; then
	#Remove old cronjob if it already exists	
	crontab -l -u $backupUser | grep -v "$backupScriptDir/raspi-backup-syncfiles.sh" 2>/dev/null | { cat;} | crontab -u $backupUser -
fi

crontab -l -u $backupUser 2>/dev/null | { cat; echo "$cronSchedule bash $backupScriptDir/raspi-backup-syncfiles.sh >/dev/null 2>&1"; } |  crontab -u $backupUser -

echo -e "${BLUE}All files set up, please see $backupList for instructions on how to configure what to back up.${NORMAL}"
echo ""
echo -e "${GREEN}Backup setup complete!${NORMAL}"


