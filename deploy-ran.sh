#!/bin/bash

AMF_IP_ADDR="10.10.1.2"

sudo apt update
sudo apt install -y make gcc g++ libsctp-dev lksctp-tools iproute2
UBUNTU_VERSION=$(lsb_release -r -s)
if (( $(echo "$UBUNTU_VERSION > 21" |bc -l) )); then
    sudo apt install -y cmake
else
    sudo apt install -y snapd
    sudo snap set system homedirs=/users
    sudo snap install cmake --classic
fi

cd ~
git clone https://github.com/aligungr/UERANSIM

cd UERANSIM
make -j 8

IP_ADDR=$(ifconfig | grep inet | grep "10.10" | awk -F ' ' '{ print $2 }')
sed -i "s/ngapIp: 127.0.0.1/ngapIp: $IP_ADDR/g" config/open5gs-gnb.yaml
sed -i "s/gtpIp: 127.0.0.1/gtpIp: $IP_ADDR/g" config/open5gs-gnb.yaml
sed -i "s/address: 127.0.0.5/address: $AMF_IP_ADDR/g" config/open5gs-gnb.yaml

echo "All done"