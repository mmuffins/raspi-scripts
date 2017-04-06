#!/bin/bash

#pi network setup

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
echo -e "\e[95mNetwork setup"; tput sgr0

echo -e "\e[94mChecking needed config files..."; tput sgr0

ExitIfFileIsMissing "$configdir/config/maclist.txt"
ExitIfFileIsMissing "$configdir/config/gateway.txt"
ExitIfFileIsMissing "$configdir/config/hostlist.txt"
ExitIfFileIsMissing "$configdir/config/dnsserver.txt"
ExitIfFileIsMissing "$configdir/config/workgroup.txt"
ExitIfFileIsMissing "$configdir/config/subnet.txt"

echo -e "\e[94mGetting MAC address..."; tput sgr0
mac=$(cat /sys/class/net/eth0/address | sed 's/:/-/g')

echo -e "\e[94mFound MAC address $mac"; tput sgr0
echo -e "\e[94mGetting hostname for mac $mac..."; tput sgr0

hostname=$(grep "$mac" $configdir/config/maclist.txt | awk -F';' {'print $1'})

if [ -z "$hostname" ];
then
	echo -e "\e[91mCould not determine hostname, aborting script"; tput sgr0
	exit 2
fi

echo -e "\e[94mFound hostname $hostname"; tput sgr0

echo -e "\e[94mGetting ip address..."; tput sgr0
ipaddr=$(grep "$hostname" $configdir/config/hostlist.txt | awk -F';' {'print $2'})

if [ -z "$ipaddr" ];
then
	echo -e "\e[91mCould not determine ip address, aborting script"; tput sgr0
	exit 2
fi

echo -e "\e[94mNew local IP Address is $ipaddr"; tput sgr0

echo -e "\e[94mGetting gateway address..."; tput sgr0
gatewayaddr=$(grep -v -e '^$' $configdir/config/gateway.txt)
echo -e "\e[94mFound gateway address $gatewayaddr"; tput sgr0

echo -e "\e[94mGetting subnet data..."; tput sgr0
subnetaddr=$(grep "subnet" $configdir/config/subnet.txt | awk -F';' {'print $2'})
echo -e "\e[94mFound subnet $subnetaddr"; tput sgr0

netmaskaddr=$(grep "netmask" $configdir/config/subnet.txt | awk -F';' {'print $2'})
echo -e "\e[94mFound subnet mask $netmaskaddr"; tput sgr0

broadcastaddr=$(grep "broadcast" $configdir/config/subnet.txt | awk -F';' {'print $2'})
echo -e "\e[94mFound broadcast IP $broadcastaddr"; tput sgr0

echo -e "\e[94mGetting DNS hosts..."; tput sgr0
dnslist=$(tr '\n' ' ' < $configdir/config/dnsserver.txt)
echo -e "\e[94mFound DNS hosts: $dnslist"; tput sgr0

echo -e "\e[94mSetting local hostname to $hostname..."; tput sgr0
sudo echo $hostname > /etc/hostname

echo -e "\e[94mAdding hosts to hosts file..."; tput sgr0
#Replace old hostname with new one
#and add new hostnames from hostname.txt

head -n -1 /etc/hosts > $configdir/tmp
echo -e "127.0.1.1\t$hostname" >> $configdir/tmp
awk -F";" {'print $2"\t"$1'} $configdir/config/hostlist.txt >> $configdir/tmp

sudo cat $configdir/tmp > /etc/hosts
sudo chown root:root /etc/hosts
rm $configdir/tmp

echo -e "\e[94mConfiguring IP, DNS and gateway..."; tput sgr0

sudo echo "" >> /etc/dhcpcd.conf
sudo echo "#Define static IP Address" >> /etc/dhcpcd.conf
sudo echo "interface eth0" >> /etc/dhcpcd.conf
sudo echo "static ip_address=$ipaddr/24" >> /etc/dhcpcd.conf
sudo echo "static routers=$gatewayaddr" >> /etc/dhcpcd.conf
sudo echo "static domain_name_servers=$dnslist" >> /etc/dhcpcd.conf
sudo echo "" >> /etc/dhcpcd.conf
sudo echo "#Disable arp for speed increased connection performance," >> /etc/dhcpcd.conf
sudo echo "#see https://wiki.archlinux.org/index.php/Dhcpcd" >> /etc/dhcpcd.conf
sudo echo "noarp" >> /etc/dhcpcd.conf

echo -e "\e[92mCompleted network setup"; tput sgr0
echo -e "\e[93mPlease restart using the following command:"; tput sgr0
echo -e "\e[93msudo reboot"; tput sgr0
