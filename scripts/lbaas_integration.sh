#!/bin/bash

#A simple integration test that will allow you to check whether the LBaaS 2.0 integration is working on your cloud.
#May require some minor tuning depending on the LB provider (i.e. specifying flavor, order of listener/pool creation etc)
#Requires a project, permissive security group, tenant network, floating network, keypair and image/flavor to start the VM.

#Testing of the load balancing is still manual. Start the test in screen, wait until the LB is up and then test it in another tab.
IMAGE=6d989e06-493f-4f2d-9d07-81650fd04581
FLAVOR=dfa1ecac-e8a9-408a-b93c-75077272e10e
NETWORK=5435a882-32f0-4abf-b1f6-3f942f85c3e7
FIP_NET=ee84f06b-be00-4295-a27a-4c6653e960ef
KEY=qa-lb-kp
SGID=008f8c20-133c-4ff8-9ae0-5d8de301b3e7
PROTO=TCP
PORT=22
LBNAME=qa-testlb
echo "Spawning the pool VMs"
openstack server create lb-1 --image ${IMAGE} --flavor ${FLAVOR} --key ${KEY} --nic net-id=${NETWORK} --security-group ${SGID}
openstack server create lb-2 --image ${IMAGE} --flavor ${FLAVOR} --key ${KEY} --nic net-id=${NETWORK} --security-group ${SGID}
openstack server create lb-3 --image ${IMAGE} --flavor ${FLAVOR} --key ${KEY} --nic net-id=${NETWORK} --security-group ${SGID}
echo "Obtaining the service subnet ID"
SUBNET=`openstack network show ${NETWORK}  | grep subnets | awk '{print $4}'`
echo "Creating the load balancer"
neutron lbaas-loadbalancer-create --name ${LBNAME} ${SUBNET}
LB=`neutron lbaas-loadbalancer-list | grep ${LBNAME} | awk '{print $2}'`
echo "Obtaining the LB VIP port and adding the permissive security group"
LB_PORT=`neutron lbaas-loadbalancer-show ${LB} | grep 'port_id' | awk '{print $4}'`
neutron port-update ${LB_PORT} --no-security-groups
neutron port-update ${LB_PORT} --security-group ${SGID}
echo "Creating the LB listener and pool"
LISTENER=`neutron lbaas-listener-create --loadbalancer ${LB} --protocol ${PROTO} --protocol-port ${PORT} --name ${LBNAME}-listener | grep '\ id' | awk '{print $4}'`
POOL=`neutron lbaas-pool-create --listener ${LISTENER} --protocol ${PROTO} --name ${LBNAME}-pool --lb-algorithm ROUND_ROBIN | grep '\ id' | awk '{print $4}'`
echo "Obtaining the fixed IP addresses for the pool VMs"
IP1=`openstack server show lb-1 | grep addresses | awk '{print $4}' | cut -d '=' -f 2`
IP2=`openstack server show lb-2 | grep addresses | awk '{print $4}' | cut -d '=' -f 2`
IP3=`openstack server show lb-3 | grep addresses | awk '{print $4}' | cut -d '=' -f 2`
echo "Adding the VMs to the pool"
neutron lbaas-member-create --protocol-port ${PORT} ${POOL} --subnet ${SUBNET} --address ${IP1}
neutron lbaas-member-create --protocol-port ${PORT} ${POOL} --subnet ${SUBNET} --address ${IP2}
neutron lbaas-member-create --protocol-port ${PORT} ${POOL} --subnet ${SUBNET} --address ${IP3}
echo "Associating the floating IP with the LB VIP"
FIP_ID=`neutron floatingip-create ${FIP_NET} | grep '\ id' | awk '{print $4}'`
neutron floatingip-associate ${FIP_ID} ${LB_PORT}
FIP_IP=`neutron floatingip-show ${FIP_ID} | grep address | awk '{print $4}'`
echo Load balancer is up with the floating IP ${FIP_IP}:${PORT}, protocol ${PROTO}. Press Enter for LB decommissioning.
read _
neutron lbaas-member-list ${POOL} | grep ${SUBNET} | awk -v pool=${POOL} '{system("neutron lbaas-member-delete " $2 " " pool)}'
neutron lbaas-pool-delete ${POOL}
neutron lbaas-listener-delete ${LISTENER}
neutron lbaas-loadbalancer-delete ${LB}
neutron floatingip-delete ${FIP_ID}
openstack server delete lb-1
openstack server delete lb-2
openstack server delete lb-3
