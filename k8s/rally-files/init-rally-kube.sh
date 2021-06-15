#!/bin/bash
cd /artifacts

# Configure kubernetes
# Check and prepare kubespec file
if [ ! -f /artifacts/kubespec_generated.yaml ]; then
    sudo bash /opt/res-files/k8s/rally-files/gen_kubespec.sh /artifacts/mos-kubeconf.yaml
fi
# Create kubernetes env
rally env create --name kubernetes --spec /artifacts/kubespec_generated.yaml
rally env check
