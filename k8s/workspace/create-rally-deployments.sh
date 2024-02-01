#!/bin/bash
##
echo "### Checking rally environments"
status=$(kubectl -n qa-space get pod | grep rally | tr -s " " | cut -d' ' -f3)
if [ ${status} != "Running" ]; then
	echo "# 'rally' container is not Running"
	exit 1
fi

# Updating folder and file permissions
kubectl exec -n qa-space --stdin rally -- sudo chown rally -R /artifacts
kubectl exec -n qa-space --stdin rally -- sudo chown rally -R /rally/rally-files/
# Copy actual rally-files to the rally pod:
kubectl cp /opt/res-files/k8s/rally-files/ qa-space/rally:/rally/

###
if [ ! -z $(kubectl exec -n qa-space --stdin rally -- rally env list | grep openstack | cut -d' ' -f2) ]; then
        echo "# Openstack env already created"
	kubectl exec -n qa-space --stdin rally -- rally env list
else
        echo "# Creating openstack env"
	kubectl exec -n qa-space --stdin rally -- bash -c "bash /rally/rally-files/init-rally-openstack.sh"
fi
echo " "
###
if [ ! -z $(kubectl exec -n qa-space --stdin rally -- rally env list | grep kubernetes | cut -d' ' -f2) ]; then
        echo "# Kubernetes env already created"
        kubectl exec -n qa-space --stdin rally -- rally env list
else
        echo "# Creating kubernetes env"
        kubectl cp $MY_PROJFOLDER/envs/mos-kubeconfig.yaml qa-space/rally:/artifacts/mos-kubeconfig.yaml
        kubectl exec -n qa-space --stdin rally -- bash -c "bash /rally/rally-files/init-rally-kube.sh"
fi
