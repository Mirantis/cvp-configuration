#!/bin/bash

FLAVOR='cvp.high'
IMAGE='cvp.ubuntu.2004'
EXT_NET='public'
DNS_SERVERS='[]' # example of the custom value: DNS_SERVERS='["192.168.129.5", "192.168.129.254"]'
APP_DOCKER_IMAGE='mirantis.azurecr.io/openstack/openstack-refapp:0.1.2' # you can replace with some local copy for offline cloud

REFAPP_PATH=/opt/density/openstack-refapp/

# Check the private CVP key, convert to the public one
cvp_private_key=/opt/cmp-check/cvp_testkey
if [ -e ${cvp_private_key} ]; then
    ssh-keygen -y -f ${cvp_private_key} > ${REFAPP_PATH}/cvp_testkey.pub
else
    echo "The key file at ${cvp_private_key} does not exist. Please run \"cd /opt/cmp-check && bash /opt/cmp-check/prepare.sh -w $(pwd) && cd ${REFAPP_PATH}\" to create a key and other test resources."
    exit 1
fi

TOP_FILE=${REFAPP_PATH}/heat-templates/top.yaml

# Replace the default public key with the CVP one
cvp_key=$(cat ${REFAPP_PATH}/cvp_testkey.pub)
escaped_cvp_key=$(echo "$cvp_key" | sed -e 's/[\/&]/\\&/g')
sed -i "/^ *cluster_public_key:/,/default:/ s/default:.*/default: '$escaped_cvp_key'/" $TOP_FILE

# Replace the flavor
sed -i "/^ *database_flavor:/,/default:/ s/default:.*/default: '$FLAVOR'/" $TOP_FILE

# Replace the image
sed -i "/^ *database_image:/,/default:/ s/default:.*/default: '$IMAGE'/" $TOP_FILE

# Replace the external net
sed -i "/^ *public_network_id:/,/default:/ s/default:.*/default: '$EXT_NET'/" $TOP_FILE

# Replace the DNS servers list
sed -i "/^ *dns_nameservers:/,/default:/ s/default:.*/default: $DNS_SERVERS/" $TOP_FILE

# Replace the docker image for RefApp application if the cloud has no Internet access
ESC_APP_DOCKER_IMAGE=$(sed 's/[\/&]/\\&/g' <<< "$APP_DOCKER_IMAGE")
sed -i "/^\s*app_docker_image:/,/default:/ s/default:.*/default: '$ESC_APP_DOCKER_IMAGE'/" $TOP_FILE
