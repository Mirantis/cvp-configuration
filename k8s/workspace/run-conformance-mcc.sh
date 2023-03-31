#!/bin/bash
tenv=mcc
. /opt/si-tests/.sivenv/bin/activate
cd $MY_PROJFOLDER/tmp
. $MY_PROJFOLDER/envs/mccrc
. $MY_PROJFOLDER/envs/target-${tenv}

# Setting concurrency
echo "Current conformance concurrency is ${K8S_CONFORMANCE_CONCURRENCY}"
export K8S_CONFORMANCE_CONCURRENCY=5
echo "Using concurrency of ${K8S_CONFORMANCE_CONCURRENCY} for MCC"
export K8S_CONFORMANCE_RUN_NETPOLICY_TESTS=False
echo "Run network policy tests is ${K8S_CONFORMANCE_CONCURRENCY} for MCC"

# Run tests
pytest /opt/si-tests/si_tests/tests/deployment/test_k8s_conformance.py
unset TARGET_CLUSTER
unset TARGET_NAMESPACE
deactivate
# report
if [ -d $MY_PROJFOLDER/reports/${tenv}-conformance ]; then
	echo "# Generating repors"
	yes | rm $MY_PROJFOLDER/reports/${tenv}-conformance/*
else
	mkdir $MY_PROJFOLDER/reports/${tenv}-conformance
fi
cp ./artifacts/*.xml $MY_PROJFOLDER/reports/${tenv}-conformance/
cd $MY_PROJFOLDER/reports/
tparser -f r_xml --omit-status SKIP --force-single -d -r $MY_CLIENTSHORTNAME-${tenv}-conformance-latest.html $MY_PROJFOLDER/reports/${tenv}-conformance/
cd $MY_PROJFOLDER
