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
admin_uuid=$(kubectl exec toolset --stdin -n qa-space -- bash -c "openstack user show cvp.admin -c id -f value")
if [ ! -z admin_uuid ]; then
        echo "# Running check"
	echo " "
	kubectl exec toolset --stdin -n qa-space -- bash -c "cd /artifacts/cmp-check; bash /opt/cmp-check/cmp_check.sh -a"
else
        echo "# Consider creating resources using 'create-openstack-resources.sh'"
	exit 1
fi
