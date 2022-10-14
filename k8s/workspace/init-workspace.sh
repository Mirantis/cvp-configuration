### initial folders
function ewriteln() {
	echo ${1} | tee -a $MY_PROJFOLDER/env.sh
}
function qkeystone() {
	keystone_pod=$(kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml get pod -n openstack -o=custom-columns=NAME:.metadata.name | grep keystone-client)
	# echo "# Running 'kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack exec {} -c keystone-client --stdin -- "${1}"'"
	kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack exec ${keystone_pod} -c keystone-client --stdin -- '${1}'
}

export MY_PROJFOLDER=/artifacts
echo "# Using folder '$MY_PROJFOLDER'"
cd $MY_PROJFOLDER
[ -f envs ] && mkdir envs
[ -f yamls ] && mkdir yamls
[ -f reports ] && mkdir reports
[ -f tmp ] && mkdir tmp

# move mcc konfig to default place
if [ -f $MY_PROJFOLDER/mcc-kubeconfig.yaml ]; then
    mv $MY_PROJFOLDER/mcc-kubeconfig.yaml $MY_PROJFOLDER/envs/mcc-kubeconfig.yaml
fi
if [ ! -f $MY_PROJFOLDER/envs/mcc-kubeconfig.yaml ]; then
	echo "ERROR: MCC kubeconfig not found either at '$MY_PROJFOLDER/mcc-kubeconfig.yaml' or '$MY_PROJFOLDER/envs/mcc-kubeconfig.yaml'"
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
ewriteln "export MY_PROJFOLDER=/artifacts"

# NS & CLUSTER
printf "\n\n# Getting namespace and cluster"
nn=( $(kubectl get cluster -A --no-headers -o=custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace | grep -v default) )
echo "# Extracted data: '${nn[@]}'"
vNS="${nn[0]}"
vCLUSTER="${nn[1]}"
ewriteln "export MOS_NS=${vNS}"
ewriteln "export MOS_CLUSTER=${vCLUSTER}"
echo "# Extracted NS: '${vNS}'"
echo "# Extracted CLUSTER: '${vCLUSTER}'"

printf "\n\n# Writing additional options"
ewriteln "export SI_BINARIES_DIR=$(which helm | rev | cut -d'/' -f2- | rev)"
ewriteln "export HELM_BINARY_PATH=$(which helm)"

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

    echo " "
    echo "# Extracting network"
    keystone_pod=$(kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml get pod -n openstack -o=custom-columns=NAME:.metadata.name | grep keystone-client)
    cmd="openstack network list --external -c Name -f value"
    echo "# Running 'kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack exec ${keystone_pod} -c keystone-client --stdin -- "${cmd}"'"
    vPUBNET=$(kubectl --kubeconfig $MY_PROJFOLDER/envs/mos-kubeconfig.yaml -n openstack exec ${keystone_pod} -c keystone-client --stdin -- ${cmd})
    echo "-> 'openstack network list --external -c Name -f value': '${vPUBNET}'"
    ewriteln "export TEMPEST_CUSTOM_PUBLIC_NET=${vPUBNET}"

    ewriteln "export TEMPEST_CUSTOM_IMAGE=cvp.cirros.51"
    ewriteln "export TEMPEST_CUSTOM_IMAGE_ALT=cvp.cirros.52"
    #prepare tempest custom yaml
    cp /opt/res-files/k8s/yamls/tempest_custom.yaml.clean $MY_PROJFOLDER/yamls/tempest_custom.yaml
    ewriteln 'export TEMPEST_CUSTOM_PARAMETERS=$(cat $MY_PROJFOLDER/yamls/tempest_custom.yaml)'
fi

# Aliases
ewriteln 'alias k=kubectl'

# end
echo " "
echo "# Done!"
