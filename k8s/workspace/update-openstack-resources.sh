#!/bin/bash
echo "Sourcing $MY_PROJFOLDER/env.sh"
. $MY_PROJFOLDER/env.sh
if [ -z ${TEMPEST_CUSTOM_PUBLIC_NET+x} ]; then
	echo "# WARNING: Public network is empty, please export its name to TEMPEST_CUSTOM_PUBLIC_NET environment variable to use some specific external net in case of several networks. Otherwise random external network will be used."
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
  kubectl exec toolset --tty --stdin -n qa-space -- bash -c "cd /artifacts/cmp-check; export CUSTOM_PUBLIC_NET_NAME="${TEMPEST_CUSTOM_PUBLIC_NET:-}"; bash /opt/cmp-check/prepare.sh -w \$(pwd)"
fi

#
echo " "
echo "# Filling tempest_custom.yaml"
# TODO: set the correct availability_zone in case nova is not used (now nova is default option)
cp -v /opt/res-files/k8s/yamls/tempest_custom.yaml.clean $MY_PROJFOLDER/yamls/tempest_custom.yaml
declare $(kubectl exec toolset --stdin -n qa-space -- bash -c "cat /artifacts/cmp-check/cvp.manifest")
echo "# Getting network details"
netid=$(kubectl exec toolset --stdin -n qa-space -- openstack network show ${TEMPEST_CUSTOM_PUBLIC_NET} -c id -f value)
subnetid=$(kubectl exec toolset --stdin -n qa-space -- openstack subnet list -f value | grep ${netid} | cut -d' ' -f1)
#echo "# image_ref_name -> ${cirros61_name}"
#sed -i "s/image_ref_name/${cirros61_name}/g" $MY_PROJFOLDER/yamls/tempest_custom.yaml
#echo "# image_ref_uuid -> ${cirros61_id}"
#sed -i "s/image_ref_uuid/${cirros61_id}/g" $MY_PROJFOLDER/yamls/tempest_custom.yaml
#echo "# image_ref_alt_uuid -> ${cirros62_id}"
#sed -i "s/image_ref_alt_uuid/${cirros62_id}/g" $MY_PROJFOLDER/yamls/tempest_custom.yaml
echo "# s/public_subnet_uuid/ -> ${subnetid}"
sed -i "s/public_subnet_uuid/${subnetid}/g" $MY_PROJFOLDER/yamls/tempest_custom.yaml
echo "# s/public_net_uuid/ -> ${netid}"
sed -i "s/public_net_uuid/${netid}/g" $MY_PROJFOLDER/yamls/tempest_custom.yaml
echo "# s/public_net_name/ -> ${TEMPEST_CUSTOM_PUBLIC_NET}"
sed -i "s/public_net_name/${TEMPEST_CUSTOM_PUBLIC_NET}/g" $MY_PROJFOLDER/yamls/tempest_custom.yaml
echo "# s/volume_type_name/ -> ${TEMPEST_CUSTOM_VOLUME_TYPE}"
sed -i "s/volume_type_name/${TEMPEST_CUSTOM_VOLUME_TYPE}/g" $MY_PROJFOLDER/yamls/tempest_custom.yaml
echo " "

echo "# Updating SPT global_config.yaml"
cp -v /opt/res-files/k8s/yamls/spt_global_config.yaml.clean $MY_PROJFOLDER/yamls/global_config.yaml
echo "# image_ref_name -> ${ubuntu20_name}"
sed -i "s/image_ref_name/${ubuntu20_name}/g" $MY_PROJFOLDER/yamls/global_config.yaml
echo "# s/public-network-name/ -> ${TEMPEST_CUSTOM_PUBLIC_NET}"
sed -i "s/public-network-name/${TEMPEST_CUSTOM_PUBLIC_NET}/g" $MY_PROJFOLDER/yamls/global_config.yaml
# 
echo "# Done!"
