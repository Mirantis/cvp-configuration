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
  rally_version=$(rally version 2>&1)
  # will be removed when we switch to Rally 0.9.2+
  if [ "$rally_version" == "0.9.0" ] || [ "$rally_version" == "0.9.1" ]; then
    pip install ansible==2.3.2.0
    sed -i '270s/,/}#,/g' /usr/local/lib/python2.7/dist-packages/rally/plugins/openstack/wrappers/network.py
  fi
  sub_name=`date "+%H_%M_%S"`
  rally deployment create --fromenv --name=tempest_$sub_name
  rally deployment config
}

additional_tempest_plugins (){
if [ -n "${PROXY}" ]; then
  export https_proxy=$PROXY
fi
#rally verify add-verifier-ext --source https://github.com/openstack/telemetry-tempest-plugin
#rally verify add-verifier-ext --version 0.1.0 --source https://github.com/openstack/heat-tempest-plugin
unset https_proxy
}

tempest_configuration () {
  sub_name=`date "+%H_%M_%S"`
  # For 2018.4.0 we will use Tempest 15.0.0
  tempest_version='15.0.0'
  if [ -n "${OFFLINE}" ]; then
    rally verify create-verifier --name tempest_verifier_$sub_name --type tempest --source $TEMPEST_REPO --system-wide --version $tempest_version
    cd /var/lib/
  else
    if [ -n "${PROXY}" ]; then
      export https_proxy=$PROXY
    fi
    rally verify create-verifier --name tempest_verifier_$sub_name --type tempest --source $TEMPEST_REPO --version $tempest_version
    unset https_proxy
  fi
  # supress tempest.conf display in console
  #rally verify configure-verifier --show
  # Plugins will not be used for Tempest 15.0.0
  #additional_tempest_plugins
  pip install --force-reinstall python-cinderclient==3.2.0
}

quick_configuration () {
current_path=$(pwd)
#image
glance image-list | grep "\btestvm\b" 2>&1 >/dev/null || {
    if [ -n "${PROXY}" ]; then
      export http_proxy=$PROXY
    fi
    ls $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img || wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img -O $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img
    unset http_proxy
    echo "MD5 should be ee1eca47dc88f4879d8a229cc70a07c6"
    md5sum $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img
    glance image-create --name=testvm --visibility=public --container-format=bare --disk-format=qcow2 < $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img
}
IMAGE_REF2=$(glance image-list | grep 'testvm' | awk '{print $2}')
#flavor for rally
nova flavor-list | grep tiny 2>&1 >/dev/null || {
    echo "Let's create m1.tiny flavor"
    nova flavor-create --is-public true m1.tiny auto 128 1 1
}
#shared fixed network
shared_count=`neutron net-list -c name -c shared | grep True | wc -l`
if [ $shared_count -gt 1 ]; then
  echo "TOO MANY SHARED NETWORKS! Script will choose just 1 random"
fi
if [ $shared_count -eq 0 ]; then
  echo "Let's create shared fixed net"
  neutron net-create --shared tempest-net
  neutron subnet-create --name tempest-subnet --gateway 192.168.0.1 --allocation-pool start=192.168.0.2,end=192.168.0.254 --ip-version 4 tempest-net 192.168.0.0/24
fi
FIXED_NET=$(neutron net-list -c name -c shared | grep True | awk '{print $2}' | tail -n 1)
echo "Fixed net is: $FIXED_NET"
#Updating of tempest_full.conf file is skipped/deprecated
sed -i 's/${IMAGE_REF2}/'$IMAGE_REF2'/g' $current_path/cvp-configuration/tempest/tempest_ext.conf
sed -i 's/${FIXED_NET}/'$FIXED_NET'/g' $current_path/cvp-configuration/tempest/tempest_ext.conf
sed -i 's/publicURL/'$TEMPEST_ENDPOINT_TYPE'/g' $current_path/cvp-configuration/tempest/tempest_ext.conf
cat $current_path/cvp-configuration/tempest/tempest_ext.conf
}

if [ "$1" == "reconfigure" ]; then
  echo "This is reconfiguration"
  rally verify configure-verifier --reconfigure
  rally verify configure-verifier --extend $current_path/cvp-configuration/tempest/tempest_ext.conf
  rally verify configure-verifier --show
  exit 0
fi

check_variables
rally_configuration
if [ -n "${TEMPEST_REPO}" ]; then
    tempest_configuration
    quick_configuration
    rally verify configure-verifier --extend $current_path/cvp-configuration/tempest/tempest_ext.conf
    # Add 2 additional tempest tests (live migration to all nodes + ssh to all nodes)
    # TBD
    #cat tempest/test_extension.py >> repo/tempest/scenario/test_server_multinode.py
fi
set -e

echo "Configuration is done!"
