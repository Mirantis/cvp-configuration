#!/bin/bash
if [ -z ${TEMPEST_CUSTOM_PUBLIC_NET+x} ]; then
	echo "# WARNING: Public network is empty"
fi
# mosrc
. $MY_PROJFOLDER/envs/mosrc

##
echo "### Checking openstack resources"
status=$(kubectl -n qa-space get pod | grep toolset | tr -s " " | cut -d' ' -f3)
if [ ${status} != "Running" ]; then
	echo "# 'toolset' container is not Running"
	exit 1
fi
if [ ! -z $(kubectl exec toolset --stdin -n qa-space -- bash -c "openstack user show cvp.admin -c id -f value") ]; then
        echo "# Resources already created"
	echo " "
	kubectl exec toolset --stdin -n qa-space -- bash -c "cat /artifacts/cmp-check/cvp.manifest"
else
        echo "# Creating openstack resources"
	echo " "
	kubectl exec toolset --stdin -n qa-space -- bash -c "mkdir /artifacts/cmp-check"
        kubectl exec toolset --stdin -n qa-space -- bash -c "cd /artifacts/cmp-check; bash /opt/cmp-check/prepare.sh"
fi

#
echo " "
echo "# Filling tempest_custom.yaml"
cp -v /opt/res-files/k8s/yamls/tempest_custom.yaml.clean $MY_PROJFOLDER/yamls/tempest_custom.yaml
declare $(kubectl exec toolset --stdin -n qa-space -- bash -c "cat /artifacts/cmp-check/cvp.manifest")
echo "# Getting network details"
netid=$(kubectl exec toolset --stdin -n qa-space -- openstack network show ${TEMPEST_CUSTOM_PUBLIC_NET} -c id -f value)
subnetid=$(kubectl exec toolset --stdin -n qa-space -- openstack subnet list -f value | grep ${TEMPEST_CUSTOM_PUBLIC_NET} | cut -d' ' -f1)
echo "# image_ref_uuid -> ${cirros51_id}"
sed -i "s/image_ref_uuid/${cirros51_id}/g" $MY_PROJFOLDER/yamls/tempest_custom.yaml
echo "# image_ref_alt_uuid -> ${cirros52_id}"
sed -i "s/image_ref_alt_uuid/${cirros52_id}/g" $MY_PROJFOLDER/yamls/tempest_custom.yaml
echo "# s/public_subnet_uuid/ -> ${subnetid}"
sed -i "s/public_subnet_uuid/${subnetid}/g" $MY_PROJFOLDER/yamls/tempest_custom.yaml
echo "# s/public_net_uuid/ -> ${netid}"
sed -i "s/public_net_uuid/${netid}/g" $MY_PROJFOLDER/yamls/tempest_custom.yaml
echo "# s/public_net_name/ -> ${TEMPEST_CUSTOM_PUBLIC_NET}"
sed -i "s/public_net_name/${TEMPEST_CUSTOM_PUBLIC_NET}/g" $MY_PROJFOLDER/yamls/tempest_custom.yaml

# 
echo "# Done!"
