#!/bin/bash
 
variables=(
OS_USERNAME
OS_PASSWORD
OS_TENANT_NAME
OS_AUTH_URL
)

check_variables () {
  for i in $(seq 0 $(( ${#variables[@]} - 1 )) ); do
    if [ -z "${!variables[$i]}" ]; then
      echo "Variable \"${variables[$i]}\" is not defined"
      exit 1
    fi
  done
  ip=$(echo ${OS_AUTH_URL} | sed -e 's/[^/]*\/\/\([^@]*@\)\?\([^:/]*\).*/\2/')
  export no_proxy=$ip
}

rally_configuration () {
  if [ "$PROXY" != "offline" ]; then
    if [ -n "${PROXY}" ]; then
      export http_proxy=$PROXY
      export https_proxy=$PROXY
    fi
    pip install --force-reinstall python-glanceclient==2.11
    apt-get update; apt-get install -y iputils-ping curl wget
    unset http_proxy
    unset https_proxy
  fi
  sub_name=`date "+%H_%M_%S"`
  # remove dashes from rally user passwords to fit into 32 char limit
  sed -i 's/uuid4())/uuid4()).replace("-","")/g' /usr/local/lib/python2.7/dist-packages/rally/plugins/openstack/scenarios/keystone/utils.py
  sed -i 's/uuid4())/uuid4()).replace("-","")/g' /usr/local/lib/python2.7/dist-packages/rally/plugins/openstack/context/keystone/users.py
  rally deployment create --fromenv --name=tempest_$sub_name
  rally deployment config
  echo "[openstack]" >> /etc/rally/rally.conf
  echo "pre_newton_neutron=True" >> /etc/rally/rally.conf
}

tempest_configuration () {
  sub_name=`date "+%H_%M_%S"`
  # default tempest version is 18.0.0 now, unless
  # it is explicitly defined in pipelines
  if [ "$tempest_version" == "" ]; then
      tempest_version='18.0.0'
  fi
  if [ "$PROXY" == "offline" ]; then
    rally verify create-verifier --name tempest_verifier_$sub_name --type tempest --source $TEMPEST_REPO --system-wide --version $tempest_version
    #rally verify add-verifier-ext --source /var/lib/telemetry-tempest-plugin
    rally verify add-verifier-ext --source /var/lib/heat-tempest-plugin
  else
    if [ -n "${PROXY}" ]; then
      export https_proxy=$PROXY
    fi
    rally verify create-verifier --name tempest_verifier_$sub_name --type tempest --source $TEMPEST_REPO --version $tempest_version
    #rally verify add-verifier-ext --version 7a4bff728fbd8629ec211669264ab645aa921e2b --source https://github.com/openstack/telemetry-tempest-plugin
    rally verify add-verifier-ext --version 0.2.0 --source https://github.com/openstack/heat-tempest-plugin
    pip install --force-reinstall python-cinderclient==3.2.0
    unset https_proxy
  fi
  # set password length to 32
  data_utils_path=`find /home/rally/.rally/verification/ -name data_utils.py`
  sed -i 's/length=15/length=32/g' $data_utils_path
  # supress tempest.conf display in console
  #rally verify configure-verifier --show
}

glance_image() {
current_path=$(pwd)
# fetch image with exact name: testvm
IMAGE_REF2=$(glance image-list | grep '\btestvm\b' | awk '{print $2}')
if [ "${IMAGE_REF2}" == "" ]; then
  if [ "$PROXY" != "offline" ]; then
    if [ -n "${PROXY}" ]; then
      export http_proxy=$PROXY
      export https_proxy=$PROXY
    fi
    ls $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img || wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img -O $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img
    unset http_proxy
    unset https_proxy
  fi
  if [ -e $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img ]; then
    echo "MD5 should be ee1eca47dc88f4879d8a229cc70a07c6"
    md5sum $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img
    glance image-create --name=testvm --visibility=public --container-format=bare --disk-format=qcow2 < $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img
    IMAGE_REF2=$(glance image-list | grep '\btestvm\b' | awk '{print $2}')
  else
    echo "Cirros image was not downloaded! Some tests may fail"
    IMAGE_REF2=""
  fi
fi
sed -i 's/${IMAGE_REF2}/'$IMAGE_REF2'/g' $current_path/cvp-configuration/tempest/tempest_ext.conf
}

quick_configuration () {
current_path=$(pwd)
#image
glance_image
#flavor for rally
nova flavor-list | grep tiny 2>&1 >/dev/null || {
    echo "Let's create m1.tiny flavor"
    nova flavor-create --is-public true m1.tiny auto 128 1 1
}
#shared fixed network
shared_count=`neutron net-list -c name -c shared | grep True | grep "fixed-net" | wc -l`
if [ $shared_count -eq 0 ]; then
  echo "Let's create shared fixed net"
  neutron net-create --shared fixed-net
  FIXED_NET_ID=$(neutron net-list -c id -c name -c shared | grep "fixed-net" | grep True | awk '{print $2}' | tail -n 1)
  neutron subnet-create --name fixed-subnet --gateway 192.168.0.1 --allocation-pool start=192.168.0.2,end=192.168.0.254 --ip-version 4 $FIXED_NET_ID 192.168.0.0/24
fi
fixed_count=`neutron net-list | grep "fixed-net" | wc -l`
if [ $fixed_count -gt 1 ]; then
  echo "TOO MANY NETWORKS WITH fixed-net NAME! This may affect tests. Please review your network list."
fi
# public/floating net
PUBLIC_NET=$(neutron net-list -c name -c router:external | grep True | awk '{print $2}' | tail -n 1)
FIXED_NET=$(neutron net-list -c name -c shared | grep "fixed-net" | grep True | awk '{print $2}' | tail -n 1)
FIXED_NET_ID=$(neutron net-list -c id -c name -c shared | grep "fixed-net" | grep True | awk '{print $2}' | tail -n 1)
FIXED_SUBNET_ID=$(neutron net-show $FIXED_NET_ID -c subnets | grep subnets | awk '{print $4}')
FIXED_SUBNET_NAME=$(neutron subnet-show -c name $FIXED_SUBNET_ID | grep name | awk '{print $4}')
echo "Public net name is $PUBLIC_NET"
echo "Fixed net name is $FIXED_NET, id is $FIXED_NET_ID"
echo "Fixed subnet is: $FIXED_SUBNET_ID, name: $FIXED_SUBNET_NAME"
sed -i 's/${FIXED_NET}/'$FIXED_NET_ID'/g' $current_path/cvp-configuration/rally/rally_scenarios.json
sed -i 's/${FIXED_NET}/'$FIXED_NET_ID'/g' $current_path/cvp-configuration/rally/rally_scenarios_100.json
sed -i 's/${FIXED_NET}/'$FIXED_NET_ID'/g' $current_path/cvp-configuration/rally/rally_scenarios_fip_and_ubuntu.json
sed -i 's/${FIXED_NET}/'$FIXED_NET_ID'/g' $current_path/cvp-configuration/rally/rally_scenarios_fip_and_ubuntu_100.json
sed -i 's/${FIXED_NET}/'$FIXED_NET'/g' $current_path/cvp-configuration/tempest/tempest_ext.conf
sed -i 's/${FIXED_SUBNET_NAME}/'$FIXED_SUBNET_NAME'/g' $current_path/cvp-configuration/tempest/tempest_ext.conf
sed -i 's/${OS_USERNAME}/'$OS_USERNAME'/g' $current_path/cvp-configuration/tempest/tempest_ext.conf
sed -i 's/${OS_TENANT_NAME}/'$OS_TENANT_NAME'/g' $current_path/cvp-configuration/tempest/tempest_ext.conf
sed -i 's/${OS_REGION_NAME}/'$OS_REGION_NAME'/g' $current_path/cvp-configuration/tempest/tempest_ext.conf
sed -i 's|${OS_AUTH_URL}|'"${OS_AUTH_URL}"'|g' $current_path/cvp-configuration/tempest/tempest_ext.conf
sed -i 's|${OS_PASSWORD}|'"${OS_PASSWORD}"'|g' $current_path/cvp-configuration/tempest/tempest_ext.conf
sed -i 's|${PUBLIC_NET}|'"${PUBLIC_NET}"'|g' $current_path/cvp-configuration/tempest/tempest_ext.conf
sed -i 's/publicURL/'$TEMPEST_ENDPOINT_TYPE'/g' $current_path/cvp-configuration/tempest/tempest_ext.conf
#supress tempest.conf display in console
#cat $current_path/cvp-configuration/tempest/tempest_ext.conf
cp $current_path/cvp-configuration/tempest/boot_config_none_env.yaml /home/rally/boot_config_none_env.yaml
cp $current_path/cvp-configuration/rally/default.yaml.template /home/rally/default.yaml.template
cp $current_path/cvp-configuration/rally/instance_test.sh /home/rally/instance_test.sh
cp $current_path/cvp-configuration/cleanup.sh /home/rally/cleanup.sh
chmod 755 /home/rally/cleanup.sh
}

if [ "$1" == "reconfigure" ]; then
  echo "This is reconfiguration"
  rally verify configure-verifier --reconfigure
  rally verify configure-verifier --extend $current_path/cvp-configuration/tempest/tempest_ext.conf
  rally verify configure-verifier --show
  exit 0
fi

echo "========================================================================="
echo "You are using 2019.2.0 branch of cvp-configuration repo"
echo "This branch is deprecated and works for 2019.2.0 - 2019.2.4 only."
echo "This branch will be deleted soon."
ecgo "Please switch to release/2019.2.0 branch instead."
echo "========================================================================="
check_variables
rally_configuration
quick_configuration
if [ -n "${TEMPEST_REPO}" ]; then
    tempest_configuration
    # If you do not have fip network, use this command
    #cat $current_path/cvp-configuration/tempest/skip-list-fip-only.yaml >> $current_path/cvp-configuration/tempest/skip-list-queens.yaml
    # If Opencontrail is deployed, use this command
    #cat $current_path/cvp-configuration/tempest/skip-list-oc4.yaml >> $current_path/cvp-configuration/tempest/skip-list-queens.yaml
    #cat $current_path/cvp-configuration/tempest/skip-list-heat.yaml >> $current_path/cvp-configuration/tempest/skip-list-queens.yaml
    rally verify configure-verifier --extend $current_path/cvp-configuration/tempest/tempest_ext.conf
    rally verify configure-verifier --show
    # If Barbican tempest plugin is installed, use this
    #mkdir /etc/tempest
    #rally verify configure-verifier --show | grep -v "rally.api" > /etc/tempest/tempest.conf
    # Add 2 additional tempest tests (live migration to all nodes + ssh to all nodes)
    # TBD
    #cat tempest/test_extension.py >> repo/tempest/scenario/test_server_multinode.py
fi
set -e

echo "Configuration is done!"
echo "========================================================================="
echo "You are using 2019.2.0 branch of cvp-configuration repo"
echo "This branch is deprecated and works for 2019.2.0 - 2019.2.4 only."
echo "This branch will be deleted soon."
ecgo "Please switch to release/2019.2.0 branch instead."
echo "========================================================================="
