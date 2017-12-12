#!/bin/bash
 
# TODO
#personality option
#security_compliance option
#port_security option

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
}

rally_configuration () {
  sub_name=`date "+%H_%M_%S"`
  rally deployment create --fromenv --name=tempest_$sub_name
  rally deployment config
}

tempest_configuration () {
  sub_name=`date "+%H_%M_%S"`
  if [ -n "${PROXY}" ]; then
    export https_proxy=$PROXY
  fi
  rally verify create-verifier --name tempest_verifier_$sub_name --type tempest --source $TEMPEST_ENDPOINT --version $tempest_version
  unset https_proxy
  rally verify configure-verifier --show
}

collecting_openstack_data () {
current_path=$(pwd)
  
PUBLIC_NETWORK_ID=$(neutron net-list --router:external=True -f csv -c id --quote none | tail -1)
PUBLIC_NETWORK_NAME="`neutron --insecure net-list --router:external=True -f csv -c name --quote none | tail -1`"
NEUTRON_EXT_LIST=$(neutron ext-list | grep -v "+" | grep -v "alias" | awk '{print $2}' | tr '\n ' ', ' | head -c -1)
neutron net-list | grep fixed 2>&1 >/dev/null || {
    neutron net-create --shared fixed
    neutron subnet-create --name fixed-subnet --gateway 192.168.0.1 --allocation-pool start=192.168.0.2,end=192.168.0.254 --ip-version 4 fixed 192.168.0.0/24
}
SHARED_NETWORK_NAME=fixed
SHARED_NETWORK_ID=$(neutron net-list | grep "\b${SHARED_NETWORK_NAME}\b" | cut -c3-38)
neutron net-update ${SHARED_NETWORK_ID} --shared true

#flavor
nova flavor-list | grep tiny 2>&1 >/dev/null || {
    nova flavor-create --is-public true m1.tiny auto 128 1 1
}
FLAVOR_REF=$(nova flavor-list | grep '\bm1.tiny\b' | awk '{print $2}')
nova flavor-list | grep m1.micro 2>&1 >/dev/null || {
    nova flavor-create --is-public true m1.micro auto 1024 2 2
}
FLAVOR_REF2=$(nova flavor-list | grep '\bm1.micro\b' | awk '{print $2}')

#image 
glance image-list | grep "\bTestVM\b" 2>&1 >/dev/null || {
    if [ -n "${PROXY}" ]; then
      export http_proxy=$PROXY
    fi
    ls $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img || wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
    unset http_proxy
    echo "TODO: add md5check here"
    echo "should be ee1eca47dc88f4879d8a229cc70a07c6"
    md5sum $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img
    glance image-create --name=TestVM --visibility=public --container-format=bare --disk-format=qcow2 < $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img
    glance image-create --name=Test2VM --visibility=public --container-format=bare --disk-format=qcow2 < $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img
}
IMAGE_REF=$(glance image-list | grep 'TestVM' | awk '{print $2}')
IMAGE_REF2=$(glance image-list | grep 'Test2VM' | awk '{print $2}')
  
url_base=$(echo ${OS_AUTH_URL} | sed -e 's/[^/]*\/\/\([^@]*@\)\?\([^:/]*\).*/\2/')
 
#neutron net-create --shared fixed
#neutron subnet-create --name fixed-subnet --gateway 192.168.0.1 --allocation-pool start=192.168.0.2,end=192.168.0.254 --ip-version 4 fixed 192.168.0.0/24
  
check_service_availability() {
    SVC=$(openstack service list | grep $1 | wc -l)
    if [ "${SVC}" -eq "0" ]; then
        echo "false"
    else
        echo "true"
    fi
}
   
NEUTRON_AVAILABLE=$(check_service_availability "neutron")
NOVA_AVAILABLE=$(check_service_availability "nova")
CINDER_AVAILABLE=$(check_service_availability "cinder")
GLANCE_AVAILABLE=$(check_service_availability "glance")
SWIFT_AVAILABLE=$(check_service_availability "swift")
HEAT_AVAILABLE=$(check_service_availability "heat")
CEILOMETER_AVAILABLE=$(check_service_availability "ceilometer")
SAHARA_AVAILABLE=$(check_service_availability "sahara")
IRONIC_AVAILABLE=$(check_service_availability "ironic")
TROVE_AVAILABLE=$(check_service_availability "trove")
ZAQAR_AVAILABLE=$(check_service_availability "zaqar")
}

create_tempest_config () {
sed -i 's/${OS_USERNAME}/'$OS_USERNAME'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${OS_PASSWORD}/'$OS_PASSWORD'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${OS_TENANT_NAME}/'$OS_TENANT_NAME'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${OS_DEFAULT_DOMAIN}/'$OS_DEFAULT_DOMAIN'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${IMAGE_REF}/'$IMAGE_REF'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${IMAGE_REF2}/'$IMAGE_REF2'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${FLAVOR_REF}/'$FLAVOR_REF'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${FLAVOR_REF2}/'$FLAVOR_REF2'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${SHARED_NETWORK_NAME}/'$SHARED_NETWORK_NAME'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${OS_REGION_NAME}/'$OS_REGION_NAME'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${url_base}/'$url_base'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${PUBLIC_NETWORK_ID}/'$PUBLIC_NETWORK_ID'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${PUBLIC_NETWORK_NAME}/'$PUBLIC_NETWORK_NAME'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/${NEUTRON_EXT_LIST}/'$NEUTRON_EXT_LIST'/g' $current_path/cvp-configuration/tempest_full.conf
sed -i 's/publicURL/'$TEMPEST_ENDPOINT_TYPE'/g' $current_path/cvp-configuration/tempest_full.conf
cat $current_path/cvp-configuration/tempest_full.conf
}

quick_configuration () {
current_path=$(pwd)
#image
glance image-list | grep "\bTest2VM\b" 2>&1 >/dev/null || {
    if [ -n "${PROXY}" ]; then
      export http_proxy=$PROXY
    fi
    ls $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img || wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
    unset http_proxy
    echo "TODO: add md5check here"
    echo "should be ee1eca47dc88f4879d8a229cc70a07c6"
    md5sum $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img
    glance image-create --name=Test2VM --visibility=public --container-format=bare --disk-format=qcow2 < $current_path/cvp-configuration/cirros-0.3.4-x86_64-disk.img
}
IMAGE_REF2=$(glance image-list | grep 'Test2VM' | awk '{print $2}')
#IMAGE_NAME=$(glance image-list | grep 'Test2VM' | awk '{print $4}')

#nova flavor-list | grep tiny 2>&1 >/dev/null || {
#    nova flavor-create --is-public true m1.tiny auto 128 1 1
#}
#FLAVOR_REF=$(nova flavor-list | grep '\bm1.tiny\b' | awk '{print $2}')
#FLAVOR_NAME=$(nova flavor-list | grep '\bm1.tiny\b' | awk '{print $4}')

#sed -i 's/${IMAGE_REF2}/'$IMAGE_NAME'/g' $current_path/testing-stuff/rally/rally_scenarios.json
#sed -i 's/${FLAVOR_REF}/'$FLAVOR_NAME'/g' $current_path/testing-stuff/rally/rally_scenarios.json
#sed -i 's/${IMAGE_REF2}/'$IMAGE_NAME'/g' $current_path/testing-stuff/rally/rally_scenarios_full.json
#sed -i 's/${FLAVOR_REF}/'$FLAVOR_NAME'/g' $current_path/testing-stuff/rally/rally_scenarios_full.json
#sed -i 's/${IMAGE_REF2}/'$IMAGE_NAME'/g' $current_path/testing-stuff/rally/rally_scenarios_many_VM.json
#sed -i 's/${FLAVOR_REF}/'$FLAVOR_NAME'/g' $current_path/testing-stuff/rally/rally_scenarios_many_VM.json

sed -i 's/${IMAGE_REF2}/'$IMAGE_REF2'/g' $current_path/cvp-configuration/tempest/tempest_ext.conf
sed -i 's/publicURL/'$TEMPEST_ENDPOINT_TYPE'/g' $current_path/cvp-configuration/tempest/tempest_ext.conf
cat $current_path/cvp-configuration/tempest/tempest_ext.conf
}

check_variables
rally_configuration
if [ -n "${TEMPEST_ENDPOINT}" ]; then
    tempest_configuration
    #collecting_openstack_data
    #create_tempest_config
    #rally verify configure-verifier --override /home/rally/cvp-configuration/tempest_full.conf
    quick_configuration
    rally verify configure-verifier --extend /home/rally/cvp-configuration/tempest/tempest_ext.conf
fi
set -e

echo "Job is done!"
