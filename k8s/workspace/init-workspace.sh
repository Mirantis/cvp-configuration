#!/bin/bash
### initial folders
function ewriteln() {
	echo ${1} | tee -a $MY_PROJFOLDER/env.sh
}

exec 2> >(while read line; do echo -e "\033[0;31m$line\033[0m" >&2; done)
export MY_PROJFOLDER=/artifacts
echo "# Using folder '$MY_PROJFOLDER'"
cd $MY_PROJFOLDER
[ ! -d envs ] && mkdir envs
[ ! -d yamls ] && mkdir yamls
[ ! -d reports ] && mkdir reports
[ ! -d tmp ] && mkdir tmp

##
# re-creating the envs/kubeconfigs in case of update and rerunning the init script
if [ -f "$MY_PROJFOLDER/envs/kubeconfigs/mgmt-kubeconfig.yaml" ]; then
    cp "$MY_PROJFOLDER/envs/kubeconfigs/mgmt-kubeconfig.yaml" "$MY_PROJFOLDER/mgmt-kubeconfig.yaml"
fi
rm -rf envs/kubeconfigs && mkdir -p envs/kubeconfigs
# re-creating to collect from scratch and do not keep obsolete configs (clds might have the same names)
rm -rf envs/checkers && mkdir -p envs/checkers
# deleting all envs/*rc files to remove all obsolete data
rm -f envs/*rc
##

# move mgmt (k0rdent mothership) k8s konfig to default place
if [ -f $MY_PROJFOLDER/mgmt-kubeconfig.yaml ]; then
    mv $MY_PROJFOLDER/mgmt-kubeconfig.yaml $MY_PROJFOLDER/envs/kubeconfigs/mgmt-kubeconfig.yaml
fi
if [ -f $MY_PROJFOLDER/node.key ]; then
    mv $MY_PROJFOLDER/node.key $MY_PROJFOLDER/envs/node.key
fi
if [ ! -f $MY_PROJFOLDER/envs/kubeconfigs/mgmt-kubeconfig.yaml ]; then
	echo "ERROR: k0rdent mgmt cluster (mothership) kubeconfig was not found either at '$MY_PROJFOLDER/mgmt-kubeconfig.yaml' or '$MY_PROJFOLDER/envs/kubeconfigs/mgmt-kubeconfig.yaml'"
	exit 1
fi
echo " "

### prepare needed variables
echo "# Updating '$MY_PROJFOLDER/env.sh'"

export KUBECONFIG=$MY_PROJFOLDER/envs/kubeconfigs/mgmt-kubeconfig.yaml
if [ ! -f $MY_PROJFOLDER/env.sh ]; then
	touch $MY_PROJFOLDER/env.sh
else
	truncate -s 0 $MY_PROJFOLDER/env.sh
	echo "$MY_PROJFOLDER/env.sh has been truncated"
fi

### Edit the following lines to set the client name, floating network name, IAM writer password
ewriteln "export MY_CLIENTNAME='${MY_CLIENTNAME:-ClientName}'"
ewriteln "export MY_CLIENTSHORTNAME='${MY_CLIENTSHORTNAME:-clname}'"
ewriteln "export MY_PROJNAME='K0RDENT_DEPLOY'"

### Setting the project directory
ewriteln "export MY_PROJFOLDER=/artifacts"

printf "\n\n# Getting ready ClusterDeployments"
printf "\n# For each ready cld, getting namespace and cluster\n"
kubectl get cld -A --no-headers | awk '$3 == "True" {print $1, $2}' | while read -r namespace name; do
    echo "   -> Processing $name in namespace $namespace..."
    kubeconfig_secret="${name}-kubeconfig"
    kubeconfig_file="$MY_PROJFOLDER/envs/kubeconfigs/${name}-kubeconfig.yaml"

    echo "   -> Fetching kubeconfig to $kubeconfig_file"
    kubectl -n "$namespace" get secret "$kubeconfig_secret" \
      -o jsonpath='{.data.value}' | base64 -d > "$kubeconfig_file"

    rc_file="$MY_PROJFOLDER/envs/${name}rc"
    echo "   -> Generating RC file at $rc_file"
    cat <<EOF > "$rc_file"
#!/bin/bash
export KUBECONFIG=$MY_PROJFOLDER/envs/kubeconfigs/${name}-kubeconfig.yaml
export CHILD_CLUSTER_NAME=${name}
export CHILD_CLUSTER_NS=${namespace}
source envs/target-child
EOF

    chmod +x "$rc_file"
done

printf "\n\n# Writing additional options\n"
ewriteln "export SI_BINARIES_DIR=$(which helm | rev | cut -d'/' -f2- | rev)"
ewriteln "export HELM_BINARY_PATH=$(which helm)"
ewriteln "export SONOBUOY_IMAGE_VERSION=v0.57"
ewriteln "export SONOBUOY_LOGS_IMAGE_VERSION=v0.4"


# generate additional files
printf "\n\n# Preparing additional files\n"
# copy files
cp -v /opt/res-files/k8s/workspace/* $MY_PROJFOLDER/envs/
[ ! -d $MY_PROJFOLDER/scripts ] && mkdir $MY_PROJFOLDER/scripts
mv -v $MY_PROJFOLDER/envs/*.sh $MY_PROJFOLDER/scripts/
mv -v $MY_PROJFOLDER/envs/*.env $MY_PROJFOLDER/envs/checkers

cp -v /opt/res-files/k8s/yamls/qa-rally.yaml $MY_PROJFOLDER/yamls
cp -v /opt/res-files/k8s/yamls/qa-res.yaml $MY_PROJFOLDER/yamls
cp -v /opt/res-files/k8s/yamls/qa-toolset.yaml $MY_PROJFOLDER/yamls

# remove duplicate init
rm -v $MY_PROJFOLDER/scripts/init-workspace.sh
# update IP Addresses
mgmt_ip=$(cat $MY_PROJFOLDER/envs/kubeconfigs/mgmt-kubeconfig.yaml | grep server | cut -d':' -f3 | cut -d'/' -f3)
echo "   -> MGMT (Mothership) Server IP is: ${mgmt_ip}"
sed -i "s/ip_address/$mgmt_ip/g" $MY_PROJFOLDER/envs/checkers/mgmt-checker.env


printf "\n\n# Preparing checker.env files for each child cluster, getting default SC...\n"
ENV_DIR="$MY_PROJFOLDER/envs"
CHECKERS_DIR="$MY_PROJFOLDER/envs/checkers"
for kubeconfig_path in "$ENV_DIR"/kubeconfigs/*-kubeconfig.yaml; do
    [[ -e "$kubeconfig_path" ]] || continue
    name=$(basename "$kubeconfig_path" -kubeconfig.yaml)

    echo "# Processing cluster - getting K8S IP: $name"
    child_ip=$(grep server "$kubeconfig_path" | cut -d':' -f3 | cut -d'/' -f3)
    echo "   -> Cluster ${name} Server IP is: ${child_ip}"

    checker_env="$CHECKERS_DIR/${name}-checker.env"
    cp $CHECKERS_DIR/child-checker.env ${checker_env}
    echo "   -> Generating checker.env for $name"
    sed -i "s/ip_address/${child_ip}/g" "$checker_env"

    default_sc=$(kubectl --kubeconfig "$kubeconfig_path" get sc 2>/dev/null | grep 'default' || true)

    if [[ -n "$default_sc" ]]; then
        vSC=$(echo "$default_sc" | awk '{print $1}')
        echo "   -> Default storage class: $vSC"
    else
        vSC=""
        echo "   -> No default storage class found."
    fi

    rc_file="$ENV_DIR/${name}rc"

    if [[ -f "$rc_file" ]]; then
        echo "   -> Updating RC file: $rc_file"
        echo "export CHILD_SC=${vSC}" >> "$rc_file"
    else
        echo "# RC file not found for $name — skipping."
    fi

done

# Aliases
ewriteln 'alias k=kubectl'

# end
echo " "
echo "# ✅ Done!"
