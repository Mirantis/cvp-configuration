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
git clone https://github.com/Mirantis/rally-plugins.git
cd rally-plugins/
pip3 install .
rally plugin list | grep kubernetes

# Configure kubernetes
# Check and prepare kubespec file
if [ ! -f /artifacts/kubespec_generated.yaml ]; then
    sudo bash /artifacts/rally-files/gen_kubespec.sh /artifacts/mos-kubeconf.yaml
fi
# Create kubernetes env
rally env create --name kubernetes --spec /artifacts/kubespec_generated.yaml
rally env check
cd /artifacts
