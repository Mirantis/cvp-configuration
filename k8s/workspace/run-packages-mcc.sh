#!/bin/bash

. "$(dirname "$0")/functions.sh"
cd /artifacts
. env.sh
. /opt/cfg-checker/.checkervenv/bin/activate
fname="/artifacts/reports/$MY_CLIENTSHORTNAME-mcc-packages-$(get_timestamp).html"
mos-checker --ssh-direct --kube-config /artifacts/envs/mcc-kubeconfig.yaml --env-name $MY_CLIENTSHORTNAME-mcc --env-config /artifacts/envs/mcc-checker.env packages report --html "${fname}"
update_latest_report_to "${fname}"
deactivate
