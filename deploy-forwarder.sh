#!/bin/bash
set -e

# Move to homedir
cd ~
pwd

# Wait for k0s to become ready
until sudo k0s kubectl get nodes | grep "$HOSTNAME" | grep " Ready"; do sleep 3; done

# Apply the Forwarder YAML
sudo k0s kubectl create -f /local/repository/forwarder.yaml
