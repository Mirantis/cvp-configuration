#!/bin/bash
cd /artifacts
. env.sh
. /opt/cfg-checker/.checkervenv/bin/activate

mos-checker --env-name $MY_CLIENTSHORTNAME-mos --env-config /artifacts/envs/mos-checker.env --kube-config /artifacts/envs/mos-kubeconfig.yaml network check
mos-checker --env-name $MY_CLIENTSHORTNAME-mos --env-config /artifacts/envs/mos-checker.env --kube-config /artifacts/envs/mos-kubeconfig.yaml network report --html $MY_CLIENTSHORTNAME-mos-networks-01.html

deactivate
