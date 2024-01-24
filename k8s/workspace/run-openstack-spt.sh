#!/bin/bash
tenv=mos
. $MY_PROJFOLDER/envs/${tenv}rc
##
echo "### Checking openstack resources"
status=$(kubectl -n qa-space get pod | grep toolset | tr -s " " | cut -d' ' -f3)
if [ ${status} != "Running" ]; then
	echo "# 'toolset' container is not Running"
	exit 1
fi

echo "# Copying mos-kubeconfig.yaml and node.key from /artifacts/envs/"
kubectl cp /artifacts/envs/mos-kubeconfig.yaml qa-space/toolset:/opt/mos-spt/mos-kubeconfig.yaml
kubectl cp /artifacts/envs/node.key qa-space/toolset:/opt/mos-spt/node.key

admin_uuid=$(kubectl exec toolset --stdin -n qa-space -- bash -c "openstack user show cvp.admin -c id -f value")
if [ ! -z ${TEMPEST_CUSTOM_PUBLIC_NET+x} ]; then
        echo "# Copying global_config.yaml"
        kubectl cp $MY_PROJFOLDER/yamls/global_config.yaml qa-space/toolset:/opt/mos-spt/global_config.yaml
    echo " "
    echo "# Running spt checks"
	echo " "
	kubectl exec toolset --stdin --tty -n qa-space -- bash -c "cd /opt/mos-spt; . .venv/bin/activate; pytest -rs -o log_cli=true --tb=short tests/"
else
        echo "# Public network not set: TEMPEST_CUSTOM_PUBLIC_NET=${TEMPEST_CUSTOM_PUBLIC_NET}"
	exit 1
fi
