#!/bin/bash
cd /artifacts
# Installing prerequisites
#apt -y update
#apt -y install python3-pip vim git iperf3 mtr htop iputils-ping traceroute tcpdump wget iproute2 curl
#pip3 install rally-openstack python-neutronclient pyghmi

# Prepare Rally
rally db create

# Create openstack env
rally env create --from-sysenv --name openstack
rally env check

# Prepare rally for kubernetes
bash res-files/k8s/gen_kubespec.sh ./mos-kubeconf.yaml
git clone https://github.com/Mirantis/rally-plugins.git
cd rally-plugins/
pip3 install .
rally plugin list | grep kubernetes

# Configure kubernetes
rally env create --name kubernetes --spec /artifacts/kubespec_generated.yaml
rally env check
cd /artifacts
