#!/bin/bash
set -e

# Config
NUM_UES=100

# Move to homedir
cd ~
pwd

# Install k0s (for MongoDB without AVX)
curl -sSf https://get.k0s.sh | sudo sh
sudo k0s install controller --single
sudo k0s start

# Wait for k0s to become ready
until sudo k0s kubectl get nodes | grep "$HOSTNAME" | grep " Ready"; do sleep 3; done

# Deploy MongoDB
cat > mongodb.yaml <<EOL
apiVersion: v1
kind: Pod
metadata:
  name: mongo
  labels:
    app.kubernetes.io/name: mongo
spec:
  containers:
  - name: mongo
    image: mongo:4.4
    command:
    - mongod
  hostNetwork: true
EOL
sudo k0s kubectl create -f mongodb.yaml

# Install Open5GS from apt
sudo add-apt-repository -y ppa:open5gs/latest
sudo apt update
sudo apt install -y open5gs

# Edit the config files
CORE_IP_ADDR=$(ifconfig | grep inet | grep "10.10" | awk -F ' ' '{ print $2 }')
sudo sed -i -z "s/ngap:\n    server:\n      - address: 127.0.0.5/ngap:\n    server:\n      - address: $CORE_IP_ADDR/g" /etc/open5gs/amf.yaml
sudo sed -i -z "s/gtpu:\n    server:\n      - address: 127.0.0.7/gtpu:\n    server:\n      - address: $CORE_IP_ADDR/g" /etc/open5gs/upf.yaml

sudo systemctl restart open5gs-amfd

# Disable the UPF, we don't want it
sudo systemctl stop open5gs-upfd
sudo systemctl disable open5gs-upfd

# Populate the core DB with UEs
cd ~
wget https://raw.githubusercontent.com/open5gs/open5gs/refs/heads/main/misc/db/open5gs-dbctl
chmod +x ./open5gs-dbctl
for i in $(seq -f "%010g" 1 $NUM_UES)
do
    ./open5gs-dbctl add_ue_with_apn "99970$i" "465B5CE8B199B49FAA5F0A2EE238A6BC" "E8ED289DEBA952E4283B54E88E6183CA" "internet"
done

echo "All done"

