#!/bin/bash

. "$(dirname "$0")/functions.sh"
cd /artifacts
. env.sh
. /opt/cfg-checker/.checkervenv/bin/activate

fname="/artifacts/reports/$MY_CLIENTSHORTNAME-mgmt-networks-$(get_timestamp).html"

CHECKER_ENV="$MY_PROJFOLDER/envs/checkers/mgmt-checker.env"
KUBECONF="$MY_PROJFOLDER/envs/kubeconfigs/mgmt-kubeconfig.yaml"

mos-checker --env-name $MY_CLIENTSHORTNAME-mgmt --env-config $CHECKER_ENV --kube-config $KUBECONF network check
mos-checker --env-name $MY_CLIENTSHORTNAME-mgmt --env-config $CHECKER_ENV --kube-config $KUBECONF network report --html "${fname}"
update_latest_report_to "${fname}"

deactivate
