#!/bin/bash
export OS_INTERFACE='admin'
mask='rally_\|tempest_\|tempest-\|spt-'

echo "Starting. Using mask '$mask'"

echo "Delete users"
for i in `openstack user list | grep $mask | awk '{print $2}'`; do openstack user delete $i; echo deleted $i; done

echo "Delete roles"
for i in `openstack role list | grep $mask | awk '{print $2}'`; do openstack role delete $i; echo deleted $i; done

#echo "Delete projects"
#for i in `openstack project list | grep $mask | awk '{print $2}'`; do openstack project delete $i; echo deleted $i; done

echo "Delete servers"
for i in `openstack server list --all | grep $mask | awk '{print $2}'`; do openstack server delete $i; echo deleted $i; done

echo "Reset snapshot state and delete"
for i in `openstack volume snapshot list --all | grep $mask | awk '{print $2}'`; do openstack snapshot set --state available $i; echo snapshot reset state is done for $i; done
for i in `openstack volume snapshot list --all | grep $mask | awk '{print $2}'`; do openstack snapshot set --state available $i; echo deleted $i; done

echo "Reset volume state and delete"
for i in `openstack volume list --all | grep $mask | awk '{print $2}'`; do openstack volume set --state available $i; echo reset state is done for $i; done
for i in `openstack volume list --all | grep $mask | awk '{print $2}'`; do openstack volume delete $i; echo deleted $i; done

echo "Delete volume types"
for i in `openstack volume type list | grep $mask | awk '{print $2}'`; do openstack volume type delete $i; done

echo "Delete images"
for i in `openstack image list | grep $mask | awk '{print $2}'`; do openstack image delete $i; echo deleted $i; done

echo "Delete sec groups"
for i in `openstack security group list --all | grep $mask | awk '{print $2}'`; do openstack security group delete $i; echo deleted $i; done

echo "Delete keypairs"
for i in `openstack keypair list | grep $mask | awk '{print $2}'`; do openstack keypair delete $i; echo deleted $i; done

echo "Delete ports"
for i in `openstack port list | grep $mask | awk '{print $2}'`; do openstack port delete $i; done

echo "Delete Router ports (experimental)"
neutron router-list|grep $mask|awk '{print $2}'|while read line; do echo $line; neutron router-port-list $line|grep subnet_id|awk '{print $11}'|sed 's/^\"//;s/\",//'|while read interface; do neutron router-interface-delete $line $interface; done; done

echo "Delete subnets"
for i in `openstack subnet list | grep $mask | awk '{print $2}'`; do openstack subnet delete $i; done

echo "Delete nets"
for i in `openstack network list | grep $mask | awk '{print $2}'`; do openstack network delete $i; done

echo "Delete routers"
for i in `openstack router list | grep $mask | awk '{print $2}'`; do openstack router delete $i; done

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
