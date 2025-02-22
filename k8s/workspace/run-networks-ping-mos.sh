#!/bin/bash

. "$(dirname "$0")/functions.sh"
cd /artifacts
. env.sh
. /opt/cfg-checker/.checkervenv/bin/activate
fname="/artifacts/reports/$MY_CLIENTSHORTNAME-mos-networks-ping-$(get_timestamp).txt"
nets=$(mos-checker --env-name $MY_CLIENTSHORTNAME-mos --env-config /artifacts/envs/mos-checker.env --kube-config /artifacts/envs/mos-kubeconfig.yaml network list 2>&1 | grep -A20 "# Runtime networks list" | grep "\:" | grep -v 'o-hm0' | awk '{print $1}')
nets=$(echo "$nets" | tr ' ' '\n' | grep -v '/32' | grep -v '10.99.')

echo "The following CIRDs will be pinged:"
printf "%s\n\n" "$nets"

cidr_options=""
for net in $nets; do
    cidr_options+="--cidr $net "  # Append each network to the list
done

summary=$(mos-checker --env-name $MY_CLIENTSHORTNAME-mos --env-config /artifacts/envs/mos-checker.env --kube-config /artifacts/envs/mos-kubeconfig.yaml network ping --detailed $cidr_options 2>&1 | awk '/Summary/ {flag=1} flag')

printf "%s\n" "$summary"
printf "%s\n" "$summary" > $fname

echo ""
echo "The report is saved to $fname"
deactivate
