#!/bin/bash
cd /artifacts
. env.sh
. /opt/cfg-checker/.checkervenv/bin/activate

mos-checker --env-name $MY_CLIENTSHORTNAME-mcc --env-config /artifacts/envs/mcc-checker.env --kube-config /artifacts/envs/mcc-kubeconfig.yaml network check
mos-checker --env-name $MY_CLIENTSHORTNAME-mcc --env-config /artifacts/envs/mcc-checker.env --kube-config /artifacts/envs/mcc-kubeconfig.yaml network report --html $MY_CLIENTSHORTNAME-mcc-networks-01.html


deactivate
