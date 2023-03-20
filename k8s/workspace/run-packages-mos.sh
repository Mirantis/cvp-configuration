#!/bin/bash
cd /artifacts
. env.sh
. /opt/cfg-checker/.checkervenv/bin/activate
mos-checker --ssh-direct --kube-config /artifacts/envs/mos-kubeconfig.yaml --env-name $MY_CLIENTSHORTNAME-mos --env-config /artifacts/envs/mos-checker.env packages report --html $MY_CLIENTSHORTNAME-mos-packages-01.html
deactivate
