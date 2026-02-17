#!/bin/bash
set -e

# Log all output
exec > >(tee "/local/repository/deploy-core.log") 2>&1

# Move to homedir
cd ~
pwd

# MongoDB setup
curl -fsSL https://pgp.mongodb.com/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
sudo apt update
sudo apt install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod

# Install Open5GS from apt
sudo add-apt-repository -y ppa:open5gs/latest
sudo apt update
sudo apt install -y open5gs

# Edit the config files
CORE_IP_ADDR=$(ifconfig | grep inet | grep "10.10" | awk -F ' ' '{ print $2 }')
sudo sed -i -z "s/ngap:\n    server:\n      - address: 127.0.0.5/ngap:\n    server:\n      - address: $CORE_IP_ADDR/g" /etc/open5gs/amf.yaml
sudo sed -i -z "s/gtpu:\n    server:\n      - address: 127.0.0.7/gtpu:\n    server:\n      - address: $CORE_IP_ADDR/g" /etc/open5gs/upf.yaml

sudo systemctl restart open5gs-amfd
sudo systemctl restart open5gs-upfd

echo "All done"
