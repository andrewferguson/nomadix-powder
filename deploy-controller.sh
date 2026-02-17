#!/bin/bash
set -e

# Get the github token
if [ "$#" -ne "1" ]; then
    echo "Usage: ./deploy_controller.sh <GitHub Token (username:password)>"
    exit 1
fi
GHT=$1

# Move to homedir
cd ~
pwd

# Compile Open5GS so that Nomadix can link to it

sudo apt update
sudo apt install -y gnupg python3-pip python3-setuptools python3-wheel ninja-build build-essential flex bison git cmake libsctp-dev libgnutls28-dev libgcrypt-dev libssl-dev libmongoc-dev libbson-dev libyaml-dev libnghttp2-dev libmicrohttpd-dev libcurl4-gnutls-dev libnghttp2-dev libtins-dev libtalloc-dev meson

if apt-cache show libidn-dev > /dev/null 2>&1; then
    sudo apt-get install -y --no-install-recommends libidn-dev
else
    sudo apt-get install -y --no-install-recommends libidn11-dev
fi

cd ~
git clone https://github.com/open5gs/open5gs

cd open5gs
meson build --prefix=`pwd`/install
ninja -C build

# Get the dependencies for building the controller
sudo apt install -y libcyaml-dev libcyaml1

# Download and build the controller
cd ~
git clone https://$GHT@github.com/andrewferguson/NOMADIX.git
cd NOMADIX/controller
make

# Configure the controller
CONTROLLER_IP_ADDR=$(ifconfig | grep inet | grep "10.10" | awk -F ' ' '{ print $2 }')
cat > controller.yaml <<EOL
controller:
  pfcp_bind_address: $CONTROLLER_IP_ADDR
  nomadix_bind_address: $CONTROLLER_IP_ADDR
  nomadix_bind_port: 1234
EOL
