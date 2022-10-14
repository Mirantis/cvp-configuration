#!/bin/bash
. /opt/cfg-checker/.checkervenv/bin/activate
mos-checker --ssh-direct --kube-config /artifacts/envs/mcc-kubeconfig.yaml --env-name $MY_CLIENTSHORTNAME-mcc --env-config /artifacts/envs/mcc-checker.env packages report --html $MY_CLIENTSHORTNAME-mcc-packages-01.html
deactivate
