#!/bin/bash

. "$(dirname "$0")/functions.sh"
cd /artifacts
. env.sh
. /opt/cfg-checker/.checkervenv/bin/activate
fname="/artifacts/reports/$MY_CLIENTSHORTNAME-mos-packages-$(get_timestamp).html"
mos-checker --ssh-direct --kube-config /artifacts/envs/mos-kubeconfig.yaml --env-name $MY_CLIENTSHORTNAME-mos --env-config /artifacts/envs/mos-checker.env packages report --html "${fname}"
update_latest_report_to "${fname}"
deactivate
