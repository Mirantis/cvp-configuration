#!/bin/bash

cd /artifacts
. env.sh

. "$(dirname "$0")/functions.sh"
cd $MY_PROJFOLDER/tmp
source $MY_PROJFOLDER/env.sh
source $MY_PROJFOLDER/envs/mgmtrc
source /opt/ksi/.ksivenv/bin/activate


if [[ $# -lt 1 ]]; then
  echo -e "\nError: No cluster name provided."
  echo "Usage: $0 <cluster-name>"
  echo ""
  exit 1
fi

if [[ $# -lt 2 ]]; then
  echo -e "\nError: No cluster namespace provided."
  echo "Usage: $0 <cluster-name> <cluster-namespace>"
  echo ""
  exit 1
fi

TARGET_CLD="$1"
TARGET_NAMESPACE="$2"

echo ""
echo "Checking if ClusterDeployment '$TARGET_CLD' exists..."
if ! kubectl get cld -n $TARGET_NAMESPACE -o name | grep -q "/$TARGET_CLD$"; then
  echo -e "Error: ClusterDeployment '$TARGET_CLD' not found in '$TARGET_NAMESPACE' namespace"
  exit 1
fi
echo -e "ClusterDeployment '$TARGET_CLD' found in $TARGET_NAMESPACE namespace"
echo ""

fname="$MY_PROJFOLDER/reports/$MY_CLIENTSHORTNAME-k0rdent-sanity-$TARGET_CLD-$(get_timestamp).html"

# Cleaning up
echo "# Cleaning up '$MY_PROJFOLDER/tmp/artifacts/'"
[ -d "$MY_PROJFOLDER/tmp/artifacts/" ] && rm -rf "$MY_PROJFOLDER/tmp/artifacts/"
[ -f "$MY_PROJFOLDER/tmp/nosetests.xml" ]  && rm "$MY_PROJFOLDER/tmp/nosetests.xml"
mkdir "$MY_PROJFOLDER/tmp/artifacts/"

# recreate the sanity reports dir to have fresh artifacts
sanity_reports_dir="$MY_PROJFOLDER/reports/sanity"
if [ -d $sanity_reports_dir ]; then
	yes | rm $sanity_reports_dir/*
else
	mkdir $sanity_reports_dir
fi

# exporting envs
export TARGET_NAMESPACE=$TARGET_NAMESPACE
export TARGET_CLD=$TARGET_CLD

# Run the sanity tests
pytest -m sanity_targeted \
  -p pytest_subtests \
  -v \
  --tb=short \
  --color=yes \
  -p no:warnings \
  -p no:sugar \
  --junitxml=$sanity_reports_dir/sanity-checks-results-$TARGET_CLD.xml \
  --html=$sanity_reports_dir/sanity-checks-results-$TARGET_CLD.html \
  --self-contained-html \
  -r s /opt/ksi/test_sanity_checks.py

if [ "$(ls -A "$MY_PROJFOLDER/tmp/artifacts" 2>/dev/null)" ]; then
    cp "$MY_PROJFOLDER/tmp/artifacts/"* "$sanity_reports_dir"
fi

cp $sanity_reports_dir/sanity-checks-results-$TARGET_CLD.html ${fname}
update_latest_report_to "${fname}"

echo "The test report can be found at ${fname}"

deactivate