### initial folders
function ewriteln() {
	echo ${1} | tee -a $MY_PROJFOLDER/env.sh
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
cls=$(kubectl get cluster -A --no-headers | grep -v default)
declare nn=()
tifs=$IFS
IFS=" "
echo $cls | cut -d" " -f1-2 | while read -r -a nn; 
do 
    ewriteln "export MOS_NS=$(echo ${nn[0]})"
    ewriteln "export MOS_CLUSTER=$(echo ${nn[1]})"
done
IFS=$tifs
ewriteln "export MOS_SC=kubernetes-nvme"
ewriteln "export OSH_DEPLOYMENT_NAME='avt-openstack'"
ewriteln "export SI_BINARIES_DIR=$(which helm | rev | cut -d'/' -f2- | rev)"
ewriteln "export HELM_BINARY_PATH=$(which helm)"
ewriteln "export TEMPEST_CUSTOM_PUBLIC_NET=public"
ewriteln "export TEMPEST_CUSTOM_IMAGE=cvp.cirros.51"
ewriteln "export TEMPEST_CUSTOM_IMAGE_ALT=cvp.cirros.52"

# extract MOS kubeconfig
echo " "
echo "Extracting mos-kubeconfig.yaml"
if [[ ! -z ${MOS_CLUSTER+x} ]]; then
	kubectl --kubeconfig $MY_PROJFOLDER/envs/mcc-kubeconfig.yaml -n ${MOS_NS} get secrets ${MOS_CLUSTER}-kubeconfig -o jsonpath='{.data.admin\.conf}'  | base64 -d | sed 's/:5443/:443/g' | tee $MY_PROJFOLDER/envs/mos-kubeconfig.yaml
else
	echo "MOS_CLUSTER variable empty/invalid: '$MOS_CLUSTER'"
fi

# generate additional files
echo "Preparing additional files"
# copy files
cp -v /opt/res-files/k8s/workspace/* $MY_PROJFOLDER/envs/
mkdir $MY_PROJFOLDER/scripts
mv $MY_PROJFOLDER/envs/*.sh $MY_PROJFOLDER/scripts/
# update IP Addresses
mccip=$(cat $MY_PROJFOLDER/envs/mcc-kubeconfig.yaml | grep server | cut -d':' -f3 | cut -d'/' -f3)
echo "-> MCC Server IP is: ${mccip}"
sed -i "s/ip_address/$mccip/g" $MY_PROJFOLDER/envs/mcc-checker.env

if [ -f $MY_PROJFOLDER/envs/mos-kubeconfig.yaml ]; then
    mosip=$(cat $MY_PROJFOLDER/envs/mos-kubeconfig.yaml | grep server | cut -d':' -f3 | cut -d'/' -f3)
    echo "-> MOS Server IP is: ${mosip}"
    sed -i "s/ip_address/$mosip/g" $MY_PROJFOLDER/envs/mos-checker.env
    #prepare tempest custom yaml
    cp /opt/res-files/k8s/yamls/tempest_custom.yaml.clean $MY_PROJFOLDER/yamls/tempest_custom.yaml
    ewriteln 'export TEMPEST_CUSTOM_PARAMETERS=$(cat $MY_PROJFOLDER/yamls/tempest_custom.yaml)'
fi

# end
echo " "
echo "# Done!"
