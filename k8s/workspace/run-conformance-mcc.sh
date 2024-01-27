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

if [ -z "$MCC_K8S_CONFORMANCE_IMAGE_VERSION" ]; then
  echo "Error: Failed to determine Kubernetes Conformance image version. Please export K8S_CONFORMANCE_IMAGE_VERSION, for example, export K8S_CONFORMANCE_IMAGE_VERSION=1.xx.x-x"
  exit 1
else
  echo "Using K8S Conformance image version ${MCC_K8S_CONFORMANCE_IMAGE_VERSION}"
  export K8S_CONFORMANCE_IMAGE_VERSION=${MCC_K8S_CONFORMANCE_IMAGE_VERSION}
fi

if [ -z "$MCC_K8S_CONFORMANCE_IMAGE_URL" ]; then
  echo "Error: Failed to determine Kubernetes Conformance image path. Please export K8S_CONFORMANCE_IMAGE_URL, for example, export K8S_CONFORMANCE_IMAGE_URL=mirantis.azurecr.io/lcm/kubernetes/k8s-conformance:v1.xx.x-x"
  exit 1
else
  echo "Using K8S Conformance image path ${MCC_K8S_CONFORMANCE_IMAGE_URL}"
  export K8S_CONFORMANCE_IMAGE_URL=${MCC_K8S_CONFORMANCE_IMAGE_URL}
fi

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
