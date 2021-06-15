#!/bin/bash
# Set region for custom value
export CDN_REGION='public-offline'
# Path to image w/o host and version
export K8S_CONFORMANCE_IMAGE='lcm/kubernetes/k8s-conformance'
# image version w/o 'v'
export K8S_CONFORMANCE_IMAGE_VERSION='1.18.19-35'

# var for the k8s-conformance pod, host with local nexus/other storage
export REPO_PUBLIC='172.20.8.28.8082'
# openstackdeployment resource name for tempest
export OSH_DEPLOYMENT_NAME=openstack-cluster-ovs
