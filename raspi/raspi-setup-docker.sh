#!/bin/bash

#Setup docker
# Also see
# https://blog.docker.com/2019/03/happy-pi-day-docker-raspberry-pi/
# https://www.freecodecamp.org/news/the-easy-way-to-set-up-docker-on-a-raspberry-pi-7d24ced073ef/

####
## debug settings
####


configdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f $configdir/raspi-setup-functions.sh ];
then
	echo -e "\e[91mraspi-setup-functions not found in $configdir/raspi-setup-functions, exiting script"; tput sgr0
	exit 2
fi

source "$configdir/raspi-setup-functions.sh"

echo ""
echo ""
echo -e "${MAGENTA}Docker setup${NORMAL}"
echo -e "${LBLUE}Checking needed config files...${NORMAL}"

echo -e "${LBLUE}Installing dependencies...${NORMAL}"
sudo apt-get install apt-transport-https ca-certificates software-properties-common -y

echo -e "${LBLUE}Installing docker...${NORMAL}"
curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh

echo -e "${LBLUE}Setting user permissions...${NORMAL}"
sudo groupadd docker
sudo usermod -aG docker michael
sudo usermod -aG docker mmuffins

echo -e "${LBLUE}Importing Docker CPG key...${NORMAL}"
sudo curl https://download.docker.com/linux/raspbian/gpg

echo -e "${LBLUE}Setting up the docker repo...${NORMAL}"
echo "deb https://download.docker.com/linux/raspbian/ buster stable" | sudo tee -a /etc/apt/sources.list > /dev/null

echo -e "${LBLUE}Updating...${NORMAL}"
sudo apt-get update && sudo apt-get upgrade

echo -e "${LBLUE}Starting docker...${NORMAL}"
sudo systemctl enable docker
sudo systemctl start docker.service
docker info

echo -e "${LBLUE}Try running 'docker run hello-world' to see if everything is set up correctly${NORMAL}"