#!/bin/bash
### initial folders
function ewriteln() {
	echo ${1} | tee -a $MY_PROJFOLDER/env.sh
}
function qkeystone() {
	keystone_pod=$(kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml get pod -n openstack -o=custom-columns=NAME:.metadata.name | grep keystone-client)
	# echo "# Running 'kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack exec {} -c keystone-client --stdin -- "${1}"'"
	kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack exec ${keystone_pod} -c keystone-client --stdin -- '${1}'
}
function get_conformance_image_tag() {
    kubeconfig_path=$1
    k8s_server_version=$(kubectl --kubeconfig="$kubeconfig_path" version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion')
    k8s_short_version=${k8s_server_version:1:4}
    image_tag=""
    case $k8s_short_version in
        "1.18")
            image_tag="1.18.9-16"
            ;;
        "1.19")
            image_tag="1.19.2-1"
            ;;
        "1.20")
            image_tag="1.20.6-4"
            ;;
        "1.21")
            image_tag="1.21.9-4"
            ;;
        "1.24")
            image_tag="1.24.4-2"
            ;;
        "1.27")
            image_tag="1.27.6-2"
            ;;
    esac
    echo "$image_tag"
}

export MY_PROJFOLDER=/artifacts
echo "# Using folder '$MY_PROJFOLDER'"
cd $MY_PROJFOLDER
[ ! -d envs ] && mkdir envs
[ ! -d yamls ] && mkdir yamls
[ ! -d reports ] && mkdir reports
[ ! -d tmp ] && mkdir tmp

# move mcc konfig to default place
if [ -f $MY_PROJFOLDER/mcc-kubeconfig.yaml ]; then
    mv $MY_PROJFOLDER/mcc-kubeconfig.yaml $MY_PROJFOLDER/envs/mcc-kubeconfig.yaml
fi
if [ -f $MY_PROJFOLDER/node.key ]; then
    mv $MY_PROJFOLDER/node.key $MY_PROJFOLDER/envs/node.key
fi
if [ ! -f $MY_PROJFOLDER/envs/mcc-kubeconfig.yaml ]; then
	echo "ERROR: MCC kubeconfig not found either at '$MY_PROJFOLDER/mcc-kubeconfig.yaml' or '$MY_PROJFOLDER/envs/mcc-kubeconfig.yaml'"
	exit 1
fi
echo " "

### prepare needed variables
echo "# Updating '$MY_PROJFOLDER/env.sh'"

export KUBECONFIG=$MY_PROJFOLDER/envs/mcc-kubeconfig.yaml
if [ ! -f $MY_PROJFOLDER/env.sh ]; then
	touch $MY_PROJFOLDER/env.sh
else
	truncate -s 0 $MY_PROJFOLDER/env.sh
	echo "$MY_PROJFOLDER/env.sh has been truncated"
fi
ewriteln "export MY_CLIENTNAME='ClientName'"
ewriteln "export MY_CLIENTSHORTNAME='clname'"
ewriteln "export MY_PROJNAME='MOS_DEPLOY'"
CUSTOM_PUBLIC_NET_NAME=""
ewriteln "export MY_PROJFOLDER=/artifacts"

# NS & CLUSTER
printf "\n\n# Getting namespace and cluster"
nn=( $(kubectl get cluster -A --no-headers -o=custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace | grep -v default) )
echo "# Extracted data: '${nn[@]}'"
vNS="${nn[1]}"
vCLUSTER="${nn[0]}"
ewriteln "export MOS_NS=${vNS}"
ewriteln "export MOS_CLUSTER=${vCLUSTER}"
echo "# Extracted NS: '${vNS}'"
echo "# Extracted CLUSTER: '${vCLUSTER}'"

printf "\n\n# Writing additional options"
ewriteln "export SI_BINARIES_DIR=$(which helm | rev | cut -d'/' -f2- | rev)"
ewriteln "export HELM_BINARY_PATH=$(which helm)"
ewriteln "export K8S_CONFORMANCE_CONCURRENCY=10"

printf "\n\n# Writing additional options for K8S conformance tests for MCC cluster...\n"
mcc_kubeconfig_path="$MY_PROJFOLDER/envs/mcc-kubeconfig.yaml"
mcc_conformance_image_tag=$(get_conformance_image_tag "$mcc_kubeconfig_path")
if [ -z "$mcc_conformance_image_tag" ]; then
    echo "Could not identify K8S_CONFORMANCE_IMAGE_VERSION for MCC."
fi
mcc_conformance_image_url="mirantis.azurecr.io/lcm/kubernetes/k8s-conformance:v${mcc_conformance_image_tag}"
ewriteln "export MCC_K8S_CONFORMANCE_IMAGE_VERSION='${mcc_conformance_image_tag}'"
ewriteln "export MCC_K8S_CONFORMANCE_IMAGE_URL='${mcc_conformance_image_url}'"

# extract MOS kubeconfig
echo " "
printf "\n\nExtracting mos-kubeconfig.yaml"
if [[ ! -z ${vCLUSTER+x} ]]; then
	kubectl --kubeconfig $MY_PROJFOLDER/envs/mcc-kubeconfig.yaml -n ${vNS} get secrets ${vCLUSTER}-kubeconfig -o jsonpath='{.data.admin\.conf}'  | base64 -d | sed 's/:5443/:443/g' | tee $MY_PROJFOLDER/envs/mos-kubeconfig.yaml
else
	echo "MOS_CLUSTER variable empty/invalid: '${vCLUSTER}'"
fi

# generate additional files
printf "\n\nPreparing additional files"
# copy files
cp -v /opt/res-files/k8s/workspace/* $MY_PROJFOLDER/envs/
[ ! -d $MY_PROJFOLDER/scripts ] && mkdir $MY_PROJFOLDER/scripts
mv -v $MY_PROJFOLDER/envs/*.sh $MY_PROJFOLDER/scripts/

cp -v /opt/res-files/k8s/yamls/qa-rally.yaml $MY_PROJFOLDER/yamls
cp -v /opt/res-files/k8s/yamls/qa-res.yaml $MY_PROJFOLDER/yamls
cp -v /opt/res-files/k8s/yamls/qa-toolset-bare.yaml $MY_PROJFOLDER/yamls
cp -v /opt/res-files/k8s/yamls/qa-toolset.yaml $MY_PROJFOLDER/yamls

# remove duplicate init
rm -v $MY_PROJFOLDER/scripts/init-workspace.sh
# update IP Addresses
mccip=$(cat $MY_PROJFOLDER/envs/mcc-kubeconfig.yaml | grep server | cut -d':' -f3 | cut -d'/' -f3)
echo "-> MCC Server IP is: ${mccip}"
sed -i "s/ip_address/$mccip/g" $MY_PROJFOLDER/envs/mcc-checker.env

if [ -f $MY_PROJFOLDER/envs/mos-kubeconfig.yaml ]; then
    mosip=$(cat $MY_PROJFOLDER/envs/mos-kubeconfig.yaml | grep server | cut -d':' -f3 | cut -d'/' -f3)
    echo "-> MOS Server IP is: ${mosip}"
    sed -i "s/ip_address/$mosip/g" $MY_PROJFOLDER/envs/mos-checker.env

    vSC="$(kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml get sc | grep default | cut -d' ' -f1)"
    echo "-> Storage class is ${vSC}"
    echo "# Updating resources yaml "
    sed -i "s/storage_class/${vSC}/g" $MY_PROJFOLDER/yamls/qa-res.yaml
    echo " "
    ewriteln "export MOS_SC=${vSC}"

    ewriteln "export OSH_DEPLOYMENT_NAME=$(kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack get openstackdeployment --no-headers | cut -d' ' -f1)"
    ewriteln "export SI_BINARIES_DIR=$(which helm | rev | cut -d'/' -f2- | rev)"
    ewriteln "export HELM_BINARY_PATH=$(which helm)"

    printf "\n\n# Writing additional options for K8S conformance tests for MOS cluster...\n"
    mos_kubeconfig_path="$MY_PROJFOLDER/envs/mos-kubeconfig.yaml"
    mos_conformance_image_tag=$(get_conformance_image_tag "$mos_kubeconfig_path")
    if [ -z "$mos_conformance_image_tag" ]; then
        echo "Could not identify K8S_CONFORMANCE_IMAGE_VERSION for MOS."
    fi
    mos_conformance_image_url="mirantis.azurecr.io/lcm/kubernetes/k8s-conformance:v${mos_conformance_image_tag}"
    ewriteln "export MOS_K8S_CONFORMANCE_IMAGE_VERSION='${mos_conformance_image_tag}'"
    ewriteln "export MOS_K8S_CONFORMANCE_IMAGE_URL='${mos_conformance_image_url}'"

    echo " "
    keystone_pod=$(kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml get pod -n openstack -o=custom-columns=NAME:.metadata.name | grep keystone-client)
    if [ -n "${CUSTOM_PUBLIC_NET_NAME:-}" ]; then
      # if CUSTOM_PUBLIC_NET_NAME is set to some specific net, check it is present on the cloud
      echo "# Checking that the external network ${CUSTOM_PUBLIC_NET_NAME} is present on the cloud"
      cmd="openstack network show ${CUSTOM_PUBLIC_NET_NAME} -c id -f value 2>/dev/null"
      echo "# Running 'kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack exec ${keystone_pod} -c keystone-client --stdin -- sh -c '${cmd}'"
      network_exists=$(kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack exec "${keystone_pod}" -c keystone-client --stdin -- sh -c "${cmd}")
      if [ -n "$network_exists" ]; then
        echo "# Setting TEMPEST_CUSTOM_PUBLIC_NET to ${CUSTOM_PUBLIC_NET_NAME}"
        ewriteln "export TEMPEST_CUSTOM_PUBLIC_NET=${CUSTOM_PUBLIC_NET_NAME}"
      else
        echo "The custom external (floating) network ${CUSTOM_PUBLIC_NET_NAME} is not found on the cloud. Set CUSTOM_PUBLIC_NET_NAME=\"\" to automatically pick some public network."
        exit 1
      fi
    else
      # else if it is not set by the QA engineer, let's extract the first external network and use it
      echo "# Extracting network: taking the first found external network"
      cmd="openstack network list --external -c Name -f value | head -n1"
      echo "# Running 'kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack exec ${keystone_pod} -c keystone-client --stdin -- sh -c '${cmd}'"
      vPUBNET=$(kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack exec ${keystone_pod} -c keystone-client --stdin -- sh -c "${cmd}")
      echo "-> 'openstack network list --external -c Name -f value | head -n1': '${vPUBNET}'"
      ewriteln "export TEMPEST_CUSTOM_PUBLIC_NET=${vPUBNET}"
    fi

    echo "# Extracting volume types"
    cmd_all="openstack volume type list -f value -c Name"
    vVOLTYPES=( $(kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack exec ${keystone_pod} -c keystone-client --stdin -- ${cmd_all}) )
    echo "# Volume types available: ${vVOLTYPES[@]}"
    cmd_default="openstack volume type list -f value -c Name --default"
    vVOLTYPE=$(kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack exec ${keystone_pod} -c keystone-client --stdin -- ${cmd_default})
    echo "# Default volume type used: ${vVOLTYPE}"
    ewriteln "export TEMPEST_CUSTOM_VOLUME_TYPE=${vVOLTYPE}"
    # hardcoded values
    ewriteln "# export TEMPEST_CUSTOM_FLAVOR=cvp.tiny"
    ewriteln "# export TEMPEST_CUSTOM_IMAGE=cvp.cirros.51"
    ewriteln "# export TEMPEST_CUSTOM_IMAGE_ALT=cvp.cirros.52"
    #prepare tempest custom yaml
    cp /opt/res-files/k8s/yamls/tempest_custom.yaml.clean $MY_PROJFOLDER/yamls/tempest_custom.yaml
    ewriteln 'export TEMPEST_CUSTOM_PARAMETERS=$(cat $MY_PROJFOLDER/yamls/tempest_custom.yaml)'
fi

# Aliases
ewriteln 'alias k=kubectl'

# end
echo " "
echo "# Done!"
