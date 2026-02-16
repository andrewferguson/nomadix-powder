#!/bin/bash

# Get the number of workers
if [ "$#" -ne "1" ]; then
    echo "Usage: ./install-k0s.sh <Number of Workers>"
    exit 1
fi
NUM_WORKERS=$1

# Install k0sctl
wget https://github.com/k0sproject/k0sctl/releases/download/v0.28.0/k0sctl-linux-amd64
chmod +x k0sctl-linux-amd64

# Generate the k0sctl config

# First boilerplate
cat > k0sctl.yaml<< EOF
apiVersion: k0sctl.k0sproject.io/v1beta1
kind: Cluster
metadata:
  name: k0s-cluster
  user: admin
spec:
  hosts:
  - ssh:
      address: 10.10.1.3
      user: root
      port: 22
      keyPath: null
    role: controller+worker
EOF

# Add any worker nodes
if [ "$NUM_WORKERS" -ge "1" ]; then
for i in $(seq 4 $(($NUM_WORKERS + 3))); do
cat >> k0sctl.yaml<< EOF
  - ssh:
      address: 10.10.1.$i
      user: root
      port: 22
      keyPath: null
    role: worker
EOF
done
fi

# Remaining boilerplate
cat >> k0sctl.yaml<< EOF
  options:
    wait:
      enabled: true
    drain:
      enabled: true
      gracePeriod: 2m0s
      timeout: 5m0s
      force: true
      ignoreDaemonSets: true
      deleteEmptyDirData: true
      podSelector: ""
      skipWaitForDeleteTimeout: 0s
    concurrency:
      limit: 30
      workerDisruptionPercent: 10
      uploads: 5
    evictTaint:
      enabled: false
      taint: k0sctl.k0sproject.io/evict=true
      effect: NoExecute
      controllerWorkers: false
EOF

# Wait for all nodes to be ready (ssh works)
if [ "$NUM_WORKERS" -ge "1" ]; then
    failed="yes"
    while [ "$failed" == "yes" ]; do
        failed="no"
        for i in $(seq 1 $(($NUM_WORKERS + 3))); do
            status=$(ssh -o "StrictHostKeyChecking no" -o ConnectTimeout=5 root@"10.10.1.$i" echo "ok" 2>&1)
            if [[ "$status" != "ok" ]] ; then
                echo "Failed to ssh to 10.10.1.$i, waiting 5 seconds..."
                sleep 5
                failed="yes"
            fi
        done
    done
fi

# Install the cluster
./k0sctl-linux-amd64 apply --config k0sctl.yaml


