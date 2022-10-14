#!/bin/bash
# Check vars
if [ -z ${MY_CLIENTNAME+x} ]; then
	echo "# Source ${MY_PROJFOLDER}/env.sh prior to running this script"
	exit 1
fi
# Prepare qa namespace and resources
echo "# Sourcing mosrc"
. ${MY_PROJFOLDER}/envs/mosrc
# check that kubeconfig present
if [ -z ${KUBECONFIG} ]; then
	exit 1
fi

# ns and storages
echo "# Creating resources"
kubectl apply -f ${MY_PROJFOLDER}/yamls/qa-res.yaml
# keystone
if [ -z $(kubectl -n qa-space get secret keystone-keystone-admin --no-headers | cut -d' ' -f1) ]; then
    echo "# Copy keystone vars"
    kubectl get secret keystone-keystone-admin -n openstack -o yaml | sed 's/namespace: openstack/namespace: qa-space/g' | kubectl apply -n qa-space -f -
fi
# start toolset
echo "# Starting toolset pod"
kubectl apply -f ${MY_PROJFOLDER}/yamls/qa-toolset.yaml
echo "# Starting rally pod"
kubectl apply -f ${MY_PROJFOLDER}/yamls/qa-rally.yaml

