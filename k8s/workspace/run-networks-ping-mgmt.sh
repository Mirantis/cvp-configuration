#!/bin/bash

. "$(dirname "$0")/functions.sh"
cd /artifacts
. env.sh
. /opt/cfg-checker/.checkervenv/bin/activate

fname="/artifacts/reports/$MY_CLIENTSHORTNAME-mgmt-networks-ping-$(get_timestamp)"

CHECKER_ENV="$MY_PROJFOLDER/envs/checkers/mgmt-checker.env"
KUBECONF="$MY_PROJFOLDER/envs/kubeconfigs/mgmt-kubeconfig.yaml"

nets=$(mos-checker --env-name $MY_CLIENTSHORTNAME-mgmt --env-config $CHECKER_ENV --kube-config $KUBECONF network list 2>&1 | grep -A20 "# Runtime networks list" | grep "\:" | awk '{print $1}')
nets=$(echo "$nets" | tr ' ' '\n' | grep -v '/32' | grep -v '10.99.')

echo "The following CIRDs will be pinged:"
printf "%s\n\n" "$nets"

cidr_options=""
for net in $nets; do
    cidr_options+="--cidr $net "  # Append each network to the list
done

summary=$(mos-checker --env-name $MY_CLIENTSHORTNAME-mgmt --env-config $CHECKER_ENV --kube-config $KUBECONF network ping --detailed $cidr_options 2>&1 | awk '/Summary/ {flag=1} flag')

printf "%s\n" "$summary"
printf "%s\n" "$summary" > $fname.txt

CLUSTER_NAME=mgmt
txt2html_net_ping_report $fname.txt $CLUSTER_NAME $fname.html

echo ""
echo "The raw txt output is saved to $fname.txt"
echo "The HTML report is saved to $fname.html"

deactivate
