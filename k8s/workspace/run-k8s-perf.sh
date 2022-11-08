#!/bin/bash
##
echo "### Checking rally environments"
status=$(kubectl -n qa-space get pod | grep rally | tr -s " " | cut -d' ' -f3)
if [ ${status} != "Running" ]; then
	echo "# 'rally' container is not Running"
	echo "# Consider creating resources and/or creating environments"
	exit 1
fi

###
if [ -z $(kubectl exec -n qa-space --stdin rally -- rally env list | grep kubernetes | cut -d' ' -f2) ]; then
        echo "# Kubernetes env not found. Please, run 'create-rally-deployments.sh'"
        kubectl exec -n qa-space --stdin rally -- rally env list
else
        echo "# Running k8s performance tests"
        kubectl exec -n qa-space --stdin rally -- rally task start /rally/rally-files/k8s-mos-scn-i100c5.yaml
	# generate report
	echo "# Generating report"
	fname=$MY_CLIENTSHORTNAME-mos-k8s-perf-latest.html
	kubectl exec -n qa-space --stdin rally -- rally task report $(kubectl exec -n qa-space --stdin rally -- rally task list | grep kubernetes | cut -d' ' -f2 | tail -1) --html-static --out ${fname}
	kubectl cp qa-space/rally:/rally/${fname} $MY_PROJFOLDER/reports/${fname}
fi
