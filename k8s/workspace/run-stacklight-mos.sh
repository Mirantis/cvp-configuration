#!/bin/bash

. "$(dirname "$0")/functions.sh"
tenv=mos
. /opt/si-tests/.sivenv/bin/activate
cd $MY_PROJFOLDER/tmp
. $MY_PROJFOLDER/env.sh
. $MY_PROJFOLDER/envs/mccrc

if [ -z "$WRITER_PASSWORD" ]; then
    echo -e "\nWRITER_PASSWORD is not exported or is empty.\nPlease export WRITER_PASSWORD or edit the /artifacts/env.sh file to set the writer keycloak user password in WRITER_PASSWORD\nExiting...\n"
    exit 1
fi

# Configuring the env variables
echo "# Configuring env variables"
unset TARGET_CLUSTER
unset TARGET_NAMESPACE
unset ENV_NAME
export TARGET_NAMESPACE=${MOS_NS}
export TARGET_CLUSTER=${MOS_CLUSTER}
export COMPONENT_TEST_RUN_ON_TARGET_CLUSTER=True
export ENV_NAME=${MOS_CLUSTER}

public_domain_name=$(kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack get osdpl -o jsonpath='{.items[0].spec.public_domain_name}')
export OS_KEYSTONE_URL="https://keystone.${public_domain_name}/v3"
export SL_TESTS_OS_KEYSTONE_URL=$OS_KEYSTONE_URL
export OS_DOMAIN_NAME=$public_domain_name
export SL_TESTS_OS_DOMAIN_NAME=$public_domain_name

si_config_file="$MY_PROJFOLDER/envs/si-config.yaml"
if [ ! -f "$si_config_file" ]; then
    echo -e "\nFile '$si_config_file' does not exist, creating it..."
    touch "$si_config_file"
else
    echo "File '$si_config_file' already exists."
fi
cat <<EOF > "$si_config_file"
keycloak_users:
  writer: $WRITER_PASSWORD
EOF
export SI_CONFIG=$MY_PROJFOLDER/envs/si-config.yaml
export SI_CONFIG_PATH=$SI_CONFIG
cat $SI_CONFIG

if [ -z "$KEYCLOAK_URL" ]; then
    echo "KEYCLOAK_URL is not exported in the environment variables, getting it from:"
    echo "kubectl get cluster kaas-mgmt -o jsonpath='{.status.providerStatus.helm.releases.iam.keycloak.url}'"
    KEYCLOAK_URL=$(kubectl get cluster kaas-mgmt -o jsonpath='{.status.providerStatus.helm.releases.iam.keycloak.url}')
else
  echo "KEYCLOAK_URL is manually set to $KEYCLOAK_URL"
fi
export KEYCLOAK_URL=$KEYCLOAK_URL

# Cleaning up
echo "# Cleaning up '/artifacts/tmp/artifacts/'"
[ -d "/artifacts/tmp/artifacts/" ] && rm -rf "/artifacts/tmp/artifacts/"
[ -f "/artifacts/tmp/nosetests.xml" ]  && rm "/artifacts/tmp/nosetests.xml"
mkdir "/artifacts/tmp/artifacts/"

# Show the exported envs
echo "# Exported envs"
env | grep TARGET
env | grep BIN
env | grep KUBE
env | grep K8S | grep -v CONFORMANCE
env | grep SI_CONFIG
env | grep KEYCLOAK
env | grep OS_
env | grep SL_TESTS
env | grep COMPONENT_TEST_RUN_ON_TARGET_CLUSTER

# Run tests
echo "# Running the tests"
pytest -vv /opt/si-tests/si_tests/tests/deployment/test_sl_test.py
deactivate

# Report
if [ -d $MY_PROJFOLDER/reports/${tenv}-stacklight ]; then
	echo "# Generating repors"
	yes | rm $MY_PROJFOLDER/reports/${tenv}-stacklight/*
else
	mkdir $MY_PROJFOLDER/reports/${tenv}-stacklight
fi
cp ./artifacts/*.xml $MY_PROJFOLDER/reports/${tenv}-stacklight/
cd $MY_PROJFOLDER/reports/
fname="$MY_CLIENTSHORTNAME-${tenv}-stacklight-$(get_timestamp).html"
tparser -f r_xml -d -r "${fname}" $MY_PROJFOLDER/reports/${tenv}-stacklight/
update_latest_report_to "$MY_PROJFOLDER/reports/${fname}"
cd $MY_PROJFOLDER
