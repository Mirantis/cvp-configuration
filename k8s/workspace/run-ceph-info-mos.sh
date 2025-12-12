#!/bin/bash

. "$(dirname "$0")/functions.sh"
. /opt/cfg-checker/.checkervenv/bin/activate

current_dir=$(pwd)
cd /artifacts/reports

fname="$MY_PROJFOLDER/reports/$MY_CLIENTSHORTNAME-mos-ceph-info-$(get_timestamp).html"
mos-checker ceph info --client-name $MY_CLIENTNAME --project-name $MY_PROJNAME --html "${fname}"
update_latest_report_to "${fname}"
deactivate

cd "${current_dir}"
echo ""
echo "The reports are saved to:"
ls -art /artifacts/reports/ | tail -n2 | sed 's|^|/artifacts/reports/|'
echo ""