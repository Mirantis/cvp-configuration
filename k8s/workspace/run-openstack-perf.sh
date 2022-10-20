#!/bin/bash
function kexec() {
	kubectl exec -n qa-space --tty --stdin rally -- bash -c "${1}"
}

# consts
concurrency=10
run_times=200

tenv=mos
. /opt/si-tests/.sivenv/bin/activate
cd $MY_PROJFOLDER/tmp
. $MY_PROJFOLDER/env.sh
. $MY_PROJFOLDER/envs/${tenv}rc
# Just in case
unset TARGET_CLUSTER
unset TARGET_NAMESPACE
dryrun=0
#
if [ ! -z ${1+x} ]; then
	echo "# Using Dry-run mode"
	dryrun=1
fi

##
echo "### Checking rally environments"
status=$(kubectl -n qa-space get pod | grep rally | tr -s " " | cut -d' ' -f3)
if [ ${status} != "Running" ]; then
	echo "# 'rally' container is not Running"
	echo "# Consider creating resources and/or creating environments"
	exit 1
fi

###
uuid=$(kubectl exec -n qa-space --stdin rally -- rally env list | grep openstack | cut -d' ' -f2)
if [ -z ${uuid} ]; then
        echo "# Openstack env not found. Please, run 'create-rally-deployments.sh'"
        kubectl exec -n qa-space --stdin rally -- rally env list
else
        echo "# Running Openstack performance tests"
	if [ ${dryrun} == 1 ]; then
		scenario=/rally/rally-files/openstack-mos-scn-i1.json
	else
		scenario=/rally/rally-files/openstack-mos-scn.json.clean
	fi
	task_scn=/artifacts/openstack-scenario.json
        # prepare scenario
        kexec "cp -v ${scenario} ${task_scn}"
	declare $(kubectl exec toolset --stdin -n qa-space -- bash -c "cat /artifacts/cmp-check/cvp.manifest")
	echo "# Updating network UUID to ${fixed_net_left_id}"
	kexec "sed -i \"s/fixed-net-id/${fixed_net_left_id}/g\" ${task_scn}"
	echo "# Updating concurrency to ${concurrency}"
	kexec "sed -i \"s/concurrent-threads/${concurrency}/g\" ${task_scn}"
	echo "# Updating running times to ${run_times}"
	kexec "sed -i \"s/run-times-number/${run_times}/g\" ${task_scn}"
	# run
	kexec "rally env use ${uuid}; rally task start ${task_scn}"
	# generate report
	echo "# Generating report"
	fname=$MY_CLIENTSHORTNAME-mos-openstack-perf-latest.html
	kubectl exec -n qa-space --stdin rally -- rally task report $(kubectl exec -n qa-space --stdin rally -- rally task list | grep openstack | cut -d' ' -f2 | tail -1) --html-static --out ${fname}
	kubectl cp qa-space/rally:/rally/${fname} $MY_PROJFOLDER/reports/${fname}
fi
