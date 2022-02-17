#!/bin/bash
if [[ -z ${token+x} ]]; then
    export token=$(openstack token issue -c id -f value)
    echo "# Exported token: ${token}"
fi
if [[ -z ${project_id+x} ]]; then
    export project_id=$(openstack project list -c ID -c Name -f value | grep ${OS_PROJECT_NAME} | cut -d' ' -f1)
    echo "# Exported project_id: ${project_id}"
fi
poke_uri=$(echo ${1/project_id/$project_id})

function ppoke {
rr=$(curl --insecure -sH "X-Auth-Token: ${token}" $1)
if [[ $? != 0 ]]; then
	echo "[$(date +'%H:%M:%S')] Error: $rr"
else
	echo "[$(date +'%H:%M:%S')] -> '$1', $(echo $rr | wc -c) bytes"
fi
}

cc=50;
while [[ $cc -gt 0 ]]; do
	cat $1 | while read svc; do
		ppoke $svc | grep "Error";
	done
	(( cc -= 1 ));
	echo "$cc to go";
	sleep 0.1;
done
