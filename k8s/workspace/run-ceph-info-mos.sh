#!/bin/bash
. /opt/cfg-checker/.checkervenv/bin/activate
mos-checker ceph info --client-name $MY_CLIENTNAME --project-name $MY_PROJNAME --html $MY_PROJFOLDER/reports/$MY_CLIENTSHORTNAME-mos-ceph-info-01.html
deactivate
