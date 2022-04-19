#!/bin/bash
echo "Updating permnimssions in rally pod"
kubectl -n qa-space exec --tty --stdin rally -- sudo chown -R rally /artifacts
echo "Copy mod kubeconfig to rally pod"
kubectl cp $MY_PROJFOLDER/envs/mos-kubeconfig.yaml qa-space/rally:/artifacts/mos-kubeconfig.yaml
echo "Copy scenarios to rally pod"
kubectl cp $MY_PROJFOLDER/res-files/k8s/rally-files qa-space/rally:/artifacts/
echo "Init rally pod"
kubectl -n qa-space exec --tty --stdin rally -- bash /artifacts/rally-files/init-rally.sh
echo "Done"
