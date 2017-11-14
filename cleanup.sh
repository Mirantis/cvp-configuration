#!/bin/bash
#mask='rally_'
#mask='tempest'
export OS_ENDPOINT_TYPE=internal
#export OS_ENDPOINT_TYPE='adminURL'
export OS_INTERFACE='admin'
#export OS_INSECURE=True
mask='rally_\|tempest_\|tempest-'
echo "Starting. Using mask '$mask'"
echo "Delete users"
for i in `openstack user list | grep $mask | awk '{print $2}'`; do openstack user delete $i; echo deleted $i; done
echo "Delete roles"
for i in `openstack role list | grep $mask | awk '{print $2}'`; do openstack role delete $i; echo deleted $i; done
echo "Delete servers"
for i in `openstack server list --all | grep $mask | awk '{print $2}'`; do openstack server delete $i; echo deleted $i; done
echo "Delete snapshot"
#[--force]
for i in `cinder snapshot-list --all | grep $mask | awk '{print $2}'`; do cinder snapshot-reset-state $i; echo snapshot reset state is done for $i; done
for i in `cinder snapshot-list --all | grep $mask | awk '{print $2}'`; do cinder snapshot-delete $i; echo deleted $i; done
echo "Delete volumes"
for i in `openstack volume list --all | grep $mask | awk '{print $2}'`; do cinder reset-state $i --state available; echo reset state is done for $i; done
for i in `openstack volume list --all | grep $mask | awk '{print $2}'`; do openstack volume delete $i; echo deleted $i; done
echo "Delete volume types"
for i in `cinder type-list | grep $mask | awk '{print $2}'`; do cinder type-delete $i; done
echo "Delete images"
for i in `openstack image list | grep $mask | awk '{print $2}'`; do openstack image delete $i; echo deleted $i; done
echo "Delete sec groups"
for i in `openstack security group list --all | grep $mask | awk '{print $2}'`; do openstack security group delete $i; echo deleted $i; done
echo "Delete keypairs"
for i in `openstack keypair list | grep $mask | awk '{print $2}'`; do openstack keypair delete $i; echo deleted $i; done
echo "Delete ports"
for i in `neutron port-list --all | grep $mask | awk '{print $2}'`; do neutron port-delete $i; done
echo "Delete Router ports (experimental)"
neutron router-list|grep $mask|awk '{print $2}'|while read line; do echo $line; neutron router-port-list $line|grep subnet_id|awk '{print $11}'|sed 's/^\"//;s/\",//'|while read interface; do neutron router-interface-delete $line $interface; done; done
echo "Delete subnets"
for i in `neutron subnet-list --all | grep $mask | awk '{print $2}'`; do neutron subnet-delete $i; done
echo "Delete nets"
for i in `neutron net-list --all | grep $mask | awk '{print $2}'`; do neutron net-delete $i; done
echo "Delete routers"
for i in `neutron router-list --all | grep $mask | awk '{print $2}'`; do neutron router-delete $i; done
echo "Delete regions"
for i in `openstack region list | grep $mask | awk '{print $2}'`; do openstack region delete $i; echo deleted $i; done
echo "Delete stacks"
for i in `openstack stack list | grep $mask | awk '{print $2}'`; do openstack stack check $i; done
for i in `openstack stack list | grep $mask | awk '{print $2}'`; do openstack stack delete -y $i; echo deleted $i; done
#echo "Delete containers"
#for i in `openstack container list --all | grep $mask | awk '{print $2}'`; do openstack container delete $i; echo deleted $i; done
echo "Done"
# It is not recommended to remove projects until you are sure that there are no other leftovers.
#echo "Delete projects"
#for i in `openstack project list | grep $mask | awk '{print $2}'`; do openstack project delete $i; echo deleted $i; done
