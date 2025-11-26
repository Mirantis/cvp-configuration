#!/bin/bash

cd /artifacts
. env.sh

. "$(dirname "$0")/functions.sh"
cd $MY_PROJFOLDER/tmp
source $MY_PROJFOLDER/env.sh
source $MY_PROJFOLDER/envs/mgmtrc
source /opt/ksi/.venv/bin/activate

fname="$MY_PROJFOLDER/reports/$MY_CLIENTSHORTNAME-k0rdent-sanity-$(get_timestamp).html"

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

# Run the sanity tests
pytest -m sanity \
 -p pytest_subtests \
 -v \
 --tb=short \
 --color=yes \
 -p no:warnings \
 -p no:sugar \
 --junitxml=$sanity_reports_dir/sanity-checks-results.xml \
 --html=$sanity_reports_dir/sanity-checks-results.html \
 --self-contained-html \
 -r s \
 /opt/ksi/test_sanity_checks.py

if [ "$(ls -A "$MY_PROJFOLDER/tmp/artifacts" 2>/dev/null)" ]; then
    cp "$MY_PROJFOLDER/tmp/artifacts/"* "$sanity_reports_dir"
fi

cp $sanity_reports_dir/sanity-checks-results.html ${fname}
update_latest_report_to "${fname}"

echo "The test report can be found at ${fname}"

deactivate