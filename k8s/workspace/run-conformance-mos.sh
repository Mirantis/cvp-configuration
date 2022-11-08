#!/bin/bash
tenv=mos
. /opt/si-tests/.sivenv/bin/activate
cd $MY_PROJFOLDER/tmp
. $MY_PROJFOLDER/envs/mccrc
. $MY_PROJFOLDER/envs/target-${tenv}
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
