#!/bin/bash
tenv=mos
. /opt/si-tests/.sivenv/bin/activate
cd $MY_PROJFOLDER/tmp
. $MY_PROJFOLDER/env.sh
. $MY_PROJFOLDER/envs/${tenv}rc
# Just in case
unset TARGET_CLUSTER
unset TARGET_NAMESPACE
# Cleaning up
echo "# Cleaning up '/artifacts/tmp/artifacts/'"
[ -d "/artifacts/tmp/artifacts/" ] && rm -rf "/artifacts/tmp/artifacts/"
[ -f "/artifacts/tmp/nosetests.xml" ]  && rm "/artifacts/tmp/nosetests.xml"
mkdir "/artifacts/tmp/artifacts/"

# 
echo "# Creating schema"
[ -f "/artifacts/tmp/artifacts/test_scheme.yaml" ] && rm -v $MY_PROJFOLDER/tmp/artifacts/test_scheme.yaml
cat <<'EOF' >artifacts/test_scheme.yaml
---
smoke: true
concurrency: 4
blacklist-file: /etc/tempest/test-blacklist
enabled: true
fail_on_test: true
type: tempest
# regex: test
EOF
cat artifacts/test_scheme.yaml
echo " "
env | grep TEMPEST_
echo " "
#
echo "# Checking auto-allocation"
cmd="openstack network auto allocated topology create --check-resources"
kubectl -n qa-space exec toolset --stdin -- $cmd
if [ $? -ne 0 ]; then
	cmd="openstack network set --default --external ${TEMPEST_CUSTOM_PUBLIC_NET}"
	echo "# Trying to set network: '${cmd}'"
        kubectl -n qa-space exec toolset --stdin -- $cmd
	echo "# Checking again"
	cmd="openstack network auto allocated topology create --check-resources"
        kubectl -n qa-space exec toolset --stdin -- $cmd
	[ $? -ne 0 ] && printf "\n\n# WARNING: Check functional tests pod for errors on test init\n\n"
fi

# run tests
pytest -vv /opt/si-tests/si_tests/tests/lcm/test_run_tempest.py
deactivate

# report
if [ -d $MY_PROJFOLDER/reports/${tenv}-func ]; then
	echo "# Generating repors"
	yes | rm $MY_PROJFOLDER/reports/${tenv}-func/*
else
	mkdir $MY_PROJFOLDER/reports/${tenv}-func
fi
cp ./artifacts/*.xml $MY_PROJFOLDER/reports/${tenv}-func/
cd $MY_PROJFOLDER/reports/
tparser -f r_xml -d -r $MY_CLIENTSHORTNAME-${tenv}-openstack-func-smoke-latest.html $MY_PROJFOLDER/reports/${tenv}-func/
cd $MY_PROJFOLDER
