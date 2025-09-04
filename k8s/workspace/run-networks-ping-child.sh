#!/bin/bash

set -euo pipefail
. "$(dirname "$0")/functions.sh"
cd /artifacts
. env.sh
. envs/mgmtrc
. /opt/cfg-checker/.checkervenv/bin/activate

if [[ $# -lt 1 ]]; then
  echo -e "\nError: No cluster name provided."
  echo "Usage: $0 <cluster-name>" && echo ""
  exit 1
fi

CLUSTER_NAME="$1"
if ! check_cluster_deployment_exists "$CLUSTER_NAME"; then
    exit 1
fi


KUBECONFIG_PATH="$MY_PROJFOLDER/envs/kubeconfigs/${CLUSTER_NAME}-kubeconfig.yaml"
CHECKER_ENV_PATH="$MY_PROJFOLDER/envs/checkers/${CLUSTER_NAME}-checker.env"
check_file_exists "$KUBECONFIG_PATH" "kubeconfig file" || exit 1
check_file_exists "$CHECKER_ENV_PATH" "checker.env file" || exit 1
echo -e "Cluster configuration files found\n"


fname="/artifacts/reports/$MY_CLIENTSHORTNAME-${CLUSTER_NAME}-networks-ping-$(get_timestamp)"
nets=$(mos-checker --env-name $MY_CLIENTSHORTNAME-child --env-config $CHECKER_ENV_PATH --kube-config $KUBECONFIG_PATH network list 2>&1 | grep -A20 "# Runtime networks list" | grep "\:" | grep -v 'o-hm0' | awk '{print $1}')
nets=$(echo "$nets" | tr ' ' '\n' | grep -v '/32' | grep -v '10.99.')

echo "The following CIRDs will be pinged:"
printf "%s\n\n" "$nets"

cidr_options=""
for net in $nets; do
    cidr_options+="--cidr $net "  # Append each network to the list
done

summary=$(mos-checker --env-name $MY_CLIENTSHORTNAME-child --env-config $CHECKER_ENV_PATH --kube-config $KUBECONFIG_PATH network ping --detailed $cidr_options 2>&1 | awk '/Summary/ {flag=1} flag')


printf "%s\n" "$summary"
printf "%s\n" "$summary" > $fname.txt

txt2html_net_ping_report $fname.txt $CLUSTER_NAME $fname.html

echo ""
echo "The raw txt output is saved to $fname.txt"
echo "The HTML report is saved to $fname.html"
deactivate
