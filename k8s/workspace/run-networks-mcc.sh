#!/bin/bash

. "$(dirname "$0")/functions.sh"
cd /artifacts
. env.sh
. /opt/cfg-checker/.checkervenv/bin/activate
fname="/artifacts/reports/$MY_CLIENTSHORTNAME-mcc-networks-$(get_timestamp).html"
mos-checker --env-name $MY_CLIENTSHORTNAME-mcc --env-config /artifacts/envs/mcc-checker.env --kube-config /artifacts/envs/mcc-kubeconfig.yaml network check
mos-checker --env-name $MY_CLIENTSHORTNAME-mcc --env-config /artifacts/envs/mcc-checker.env --kube-config /artifacts/envs/mcc-kubeconfig.yaml network report --html "${fname}"
update_latest_report_to "${fname}"

deactivate
