# Raspi-Deployment
A simple set of scripts to automate the tedious baseline configuration when installing a new raspberry pi, including basic network settings, user accounts, samba and backup to a local fileserver.

## Usage
### First Setup
- Configure the needed network settings in the following files in the /config directory
     - dnsserver.txt => DNS servers
	 - gateway.txt => Local gateway
	 - subnet.txt => Subnet mask
	 - workgroup.txt => Current workgroup
	 - hostlist.txt => Entries will be copied to the hosts file
	 - maclist => Containing the physical address of all hosts in the local network to properly identify the current one
- Download the latest raspberry pi image and flash an SD card with it
- Open the SD card, create an empty file called 'ssh' in the root of the sd card to enable ssh when first booting the raspberry
- Create a new directory called 'deployment' in the root of the sd card
- Copy the deployment scripts to the SD card
     - /deployment/[scripts]
	 - /deployment/config/[config files]
### Baseline configuration
- Login with the defult pi/raspberry account
- Run the following commands
```
cd /home/pi
mkdir raspi
cd raspi
mkdir config
sudo mv /boot/deployment/* /home/pi/raspi
sudo rmdir /boot/deployment
```

### Users
- Configure required users and root user in /config/raspiusers.txt and /config/raspirootusers
- Run the following commands
```
cd /home/pi/raspi
sudo bash raspi-setup-network.sh
sudo bash raspi-setup-users.sh
sudo mv /home/pi/raspi /home/mmuffins/raspi
sudo reboot
```

- At this point, it's advisable to test logging in with one of the new users and remove the default admin account and double check if all sudo permissions were revoked
```
sudo deluser pi --remove-home
sudo visudo
#Remove the line 'pi ALL=(ALL) NOPASSWD: ALL' if it still exists
```

### Backup
- Configure the needed backup settings in the following files in the /config directory
     - backup.txt
- Run the following commands
```
cd /home/mmuffins/raspi
sudo bash raspi-setup-backup.sh
```

### Samba
- Run the following commands
```
cd /home/mmuffins/raspi
sudo bash raspi-setup-samba.sh
```
- Note that the steps above will take a while when they are executed on a raspberrz

- It is also advisable to upgrade all installed software via
```
sudo apt-get dist-upgrade -y && sudo apt-get autoremove -y && echo "dist upgrade completed"
sudo apt-get update -y && sudo apt-get upgrade -y && echo "upgrade and update completed"
```
- Note that the steps above will take a while when they are executed on a raspberrz

