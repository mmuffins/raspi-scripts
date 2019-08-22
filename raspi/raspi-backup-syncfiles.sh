#!/bin/bash

#Script synchronizes local backups with remote backup server
#
#-Read backup settings file
#-Test ssh connection to the backup server
#-tar all files in the backup directory
#-Sync tar file to the remote server
#-Delete backups that are older than the cutoff on the remote server
#-Delete all local backups
#
#Whenever new applications are set up, they should add all locations that
#need to be backed up to the backup config file


#Functions

ExitIfFileIsMissing() {
	#Completely exits script execution if the provided file was not found
	if [ ! -f $1 ];
	then
		echo "$(date +%Y-%m-%d_%H:%M:%S) - $1 was not found, exiting script" >> $logFile
		exit 2
	fi
}

GetSettings() {
	#Returns sanatized contents of a config file
	#$1 - Path of the config file

	configlocation=$1

	if [ -z "$configlocation" ]; then
		echo "$(date +%Y-%m-%d_%H:%M:%S) - No config file location was provided" >> $logFile
		return 2
	fi

	if [ ! -f $configlocation ];
	then
		echo "$(date +%Y-%m-%d_%H:%M:%S) - Could not open file at $configlocation" >> $logFile
		exit 2
	fi

	sed 's/^[ \t]*//;s/[ \t]*$//' $configlocation | grep -v '^#'
	
}

######################

configdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#Use temporary log location before the actual user log location is
#read from the config file to log startup issues

backupStartDate=`date +%Y-%m-%d-%H-%M`
logFile="$configdir/backup_$backupStartDate.log"

configfile="$configdir/backup-config"
ExitIfFileIsMissing $configfile

source $configfile
logFile="$logDirectory/backup_$backupStartDate.log"
touch $logFile

echo "$(date +%Y-%m-%d_%H:%M:%S) - Starting backup" >> $logFile
echo "$(date +%Y-%m-%d_%H:%M:%S) - Using config file at $configfile" >> $logFile

#Check prerequisites

ExitIfFileIsMissing $backupList >> $logFile
backupFiles=($(GetSettings "$backupList"))

if [ ${#backupFiles[@]}  -lt 1 ]; then
	echo "$(date +%Y-%m-%d_%H:%M:%S) - Nothing found to backup in $backupList" >> $logFile
	exit 2
fi

if [ ! -d $backupDir ]; then
	echo "$(date +%Y-%m-%d_%H:%M:%S) - Could not find $backupDir" >> $logFile
	exit 2
fi

tarname="$backupDir/backup_$(hostname)_$backupStartDate.tar"
echo "$(date +%Y-%m-%d_%H:%M:%S) - Archiving files to $tarname" >> $logFile

#backup backupsettings and backuplist for reference
tar -cpf $tarname $configfile >> $logFile 2>&1
tar -rpf $tarname $backupList >> $logFile 2>&1

for i in "${!backupFiles[@]}"; do 
	backupentry=${backupFiles[$i]}
	sudo tar -rpf $tarname $backupList $backupentry >> $logFile 2>&1
	
	if [ $? != 0 ]; then
		echo "$(date +%Y-%m-%d_%H:%M:%S) - Error while executing sudo tar -rpf $tarname $backupList $backupentry - continuing with next entry" >> $logFile
	fi
done

echo "$(date +%Y-%m-%d_%H:%M:%S) - Finished creating backup archive" >> $logFile
echo "$(date +%Y-%m-%d_%H:%M:%S) - Compressing backup archive" >> $logFile

bzip2 -f $tarname >> $logFile 2>&1

if [ $? != 0 ]; then
	echo "$(date +%Y-%m-%d_%H:%M:%S) - Error while  compressing archive, attempting to sync uncompressed archive" >> $logFile
fi

#Just in case, check if either the compressed or uncompressed archive exists and just continue with whatever is available
if [ -f "$backupDir/backup_$(hostname)_$backupStartDate.tar.bz2" ]; then
	tarname="$backupDir/backup_$(hostname)_$backupStartDate.tar.bz2"
else
	if [ ! -f "$backupDir/backup_$(hostname)_$backupStartDate.tar" ]; then
		echo "$(date +%Y-%m-%d_%H:%M:%S) - Could not find $tarname or $backupDir/backup_$(hostname)_$backupStartDate.tar.bz2, aborting script" >> $logFile
		exit 2
	fi
fi

mountPoint="$configdir/mnt"
mkdir -p $mountPoint --verbose >> $logFile 2>&1

echo "$(date +%Y-%m-%d_%H:%M:%S) - Mounting remote share $remoteshare to local mount point $mountPoint:" >> $logFile
mount $mountPoint >> $logFile 2>&1

if [ $? != 0 ]; then
	echo "$(date +%Y-%m-%d_%H:%M:%S) - Error while mounting remote share $remoteshare to local mountpoint $mountPoint with user $smbUser, check /etc/fstab" >> $logFile
	exit 2
fi

echo "$(date +%Y-%m-%d_%H:%M:%S) - Copy files to remote share:" >> $logFile
cp --verbose $tarname $mountPoint >> $logFile 2>&1

if [ $? != 0 ]; then
	echo "$(date +%Y-%m-%d_%H:%M:%S) - Error while executing command 'cp --verbose $tarname $mountPoint'" >> $logFile
	exit 2
fi

#Remove files older than cutoff time on the target host
echo "$(date +%Y-%m-%d_%H:%M:%S) - Removing files older than $backupcutoff days in remote share" >> $logFile
find $mountPoint -mindepth 1 -mtime +$backupcutoff -delete >> $logFile 2>&1

echo "$(date +%Y-%m-%d_%H:%M:%S) - Removing mounted share" >> $logFile
umount $mountPoint >> $logFile 2>&1

if [ $? != 0 ]; then
	echo "$(date +%Y-%m-%d_%H:%M:%S) - Error while unmounting remote share $remoteshare on local mountpoint $mountPoint, check /etc/fstab" >> $logFile
	exit 2
fi

echo "$(date +%Y-%m-%d_%H:%M:%S) - Backup complete, removing all files in $backupDir " >> $logFile
sudo rm -rf $backupDir/* >> $logFile 2>&1

echo "$(date +%Y-%m-%d_%H:%M:%S) - Cleaning up the log directory" >> $logFile
find $logDirectory -mindepth 1 -mtime +30 -delete >> $logFile 2>&1

echo "$(date +%Y-%m-%d_%H:%M:%S) - Backup complete" >> $logFile