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
echo "# Input uri is ${1}"
echo "[$(date +'%H:%M:%S')] -> '${poke_uri}'"
curl -sH "X-Auth-Token: ${token}" ${poke_uri} | python -m json.tool
