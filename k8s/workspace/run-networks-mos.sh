#!/bin/bash

. "$(dirname "$0")/functions.sh"
cd /artifacts
. env.sh
. /opt/cfg-checker/.checkervenv/bin/activate

fname="/artifacts/reports/$MY_CLIENTSHORTNAME-mos-networks-$(get_timestamp).html"
mos-checker --env-name $MY_CLIENTSHORTNAME-mos --env-config /artifacts/envs/mos-checker.env --kube-config /artifacts/envs/mos-kubeconfig.yaml network check
mos-checker --env-name $MY_CLIENTSHORTNAME-mos --env-config /artifacts/envs/mos-checker.env --kube-config /artifacts/envs/mos-kubeconfig.yaml network report --html "${fname}"
update_latest_report_to "${fname}"
deactivate
