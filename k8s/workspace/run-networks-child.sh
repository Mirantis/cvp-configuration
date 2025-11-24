#!/bin/bash

set -euo pipefail

. "$(dirname "$0")/functions.sh"
cd /artifacts
. env.sh
. envs/mgmtrc
. /opt/cfg-checker/.checkervenv/bin/activate

if [[ $# -lt 1 ]]; then
  echo -e "\nError: No cluster name provided."
  echo "Usage: $0 <cluster-name>"
  echo ""
  exit 1
fi

CLUSTER_NAME="$1"
if ! check_cluster_deployment_exists "$CLUSTER_NAME"; then
    exit 1
fi

KUBECONFIG_PATH="$MY_PROJFOLDER/envs/kubeconfigs/${CLUSTER_NAME}-kubeconfig.yaml"
CHECKER_ENV_PATH="$MY_PROJFOLDER/envs/checkers/${CLUSTER_NAME}-checker.env"

if [[ ! -f "$KUBECONFIG_PATH" ]]; then
  echo -e "Error: kubeconfig file not found at $KUBECONFIG_PATH"
  exit 1
fi

if [[ ! -f "$CHECKER_ENV_PATH" ]]; then
  echo -e "Error: checker.env file not found at $CHECKER_ENV_PATH"
  exit 1
fi

echo -e "Cluster configuration files found\n"

fname="/artifacts/reports/$MY_CLIENTSHORTNAME-${CLUSTER_NAME}-networks-$(get_timestamp).html"

mos-checker --env-name $MY_CLIENTSHORTNAME-child --env-config $CHECKER_ENV_PATH --kube-config $KUBECONFIG_PATH network check
mos-checker --env-name $MY_CLIENTSHORTNAME-child --env-config $CHECKER_ENV_PATH --kube-config $KUBECONFIG_PATH network report --html "${fname}"

update_latest_report_to "${fname}"
deactivate
