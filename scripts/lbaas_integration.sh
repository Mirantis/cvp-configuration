#!/bin/bash

#A simple integration test that will allow you to check whether the LBaaS 2.0 integration is working on your cloud.
#May require some minor tuning depending on the LB provider (i.e. specifying flavor, order of listener/pool creation etc)
#Requires a project, permissive security group, tenant network, floating network, keypair and image/flavor to start the VM.

#Testing of the load balancing is still manual. Start the test in screen, wait until the LB is up and then test it in another tab.
now=$(date +'%m-%d-%Y')
IMAGE=260d1328-5ed0-4e54-a79c-26c98a92ecc9
FLAVOR=033b82cb-b39f-466c-96c8-cf7c4e910932
NETWORK=bd76e0b4-e707-4456-905d-834035f8c8e5
FIP_NET=f424e52d-eefc-4a8c-b51f-490d79a4127b
KEY=qa-lb-kp
SGID=1b53d9e0-c62f-4e2a-b942-3dd2fb356337
PROTO=TCP
PORT=22
LBNAME=qa-testlb-${now}
echo "Spawning the pool VMs"
openstack server create lb-1-${LBNAME} --image ${IMAGE} --flavor ${FLAVOR} --key ${KEY} --nic net-id=${NETWORK} --security-group ${SGID}
openstack server create lb-2-${LBNAME} --image ${IMAGE} --flavor ${FLAVOR} --key ${KEY} --nic net-id=${NETWORK} --security-group ${SGID}
openstack server create lb-3-${LBNAME} --image ${IMAGE} --flavor ${FLAVOR} --key ${KEY} --nic net-id=${NETWORK} --security-group ${SGID}
echo "Obtaining the service subnet ID"
SUBNET=`openstack network show ${NETWORK}  | grep subnets | awk '{print $4}'`
echo "Creating the load balancer"
#neutron lbaas-loadbalancer-create --name ${LBNAME} ${SUBNET}
openstack loadbalancer create --name ${LBNAME} --vip-subnet-id  ${SUBNET}
#LB=`neutron lbaas-loadbalancer-list | grep ${LBNAME} | awk '{print $2}'`
LB=`openstack loadbalancer list | grep ${LBNAME} | awk '{print $2}'`
echo "Obtaining the LB VIP port and adding the permissive security group"
#LB_PORT=`neutron lbaas-loadbalancer-show ${LB} | grep 'port_id' | awk '{print $4}'`
LB_PORT=`openstack loadbalancer  show ${LB} | grep 'port_id' | awk '{print $4}'`
neutron port-update ${LB_PORT} --no-security-groups
neutron port-update ${LB_PORT} --security-group ${SGID}
echo "Creating the LB listener and pool"
#LISTENER=`neutron lbaas-listener-create --loadbalancer ${LB} --protocol ${PROTO} --protocol-port ${PORT} --name ${LBNAME}-listener | grep '\ id' | awk '{print $4}'`
LISTENER=`openstack loadbalancer listener create  --protocol ${PROTO} --protocol-port ${PORT} --name ${LBNAME}-listener  ${LB} | grep '\ id' | awk '{print $4}'`
#POOL=`neutron lbaas-pool-create --listener ${LISTENER} --protocol ${PROTO} --name ${LBNAME}-pool --lb-algorithm ROUND_ROBIN | grep '\ id' | awk '{print $4}'`
POOL=`openstack loadbalancer pool create --listener ${LISTENER} --protocol ${PROTO} --name ${LBNAME}-pool --lb-algorithm ROUND_ROBIN | grep '\ id' | awk '{print $4}'`
echo "Obtaining the fixed IP addresses for the pool VMs"
IP1=`openstack server show lb-1-${LBNAME} | grep addresses | awk '{print $4}' | cut -d '=' -f 2`
IP2=`openstack server show lb-2-${LBNAME} | grep addresses | awk '{print $4}' | cut -d '=' -f 2`
IP3=`openstack server show lb-3-${LBNAME} | grep addresses | awk '{print $4}' | cut -d '=' -f 2`
echo "Adding the VMs to the pool"
#neutron lbaas-member-create --protocol-port ${PORT} ${POOL} --subnet ${SUBNET} --address ${IP1}
#neutron lbaas-member-create --protocol-port ${PORT} ${POOL} --subnet ${SUBNET} --address ${IP2}
#neutron lbaas-member-create --protocol-port ${PORT} ${POOL} --subnet ${SUBNET} --address ${IP3}
openstack loadbalancer member create --protocol-port ${PORT}  --subnet-id ${SUBNET} --address ${IP1}  ${POOL}
openstack loadbalancer member create --protocol-port ${PORT}  --subnet-id ${SUBNET} --address ${IP2}  ${POOL}
openstack loadbalancer member create --protocol-port ${PORT}  --subnet-id ${SUBNET} --address ${IP3}  ${POOL}
echo "Associating the floating IP with the LB VIP"
#FIP_ID=(neutron floatingip-create ${FIP_NET} | grep '\ id' | awk '{print $4}')
FIP_ID=$(neutron floatingip-show ${FIP_ID} | grep floating_ip_address | awk '{print $4}')
neutron floatingip-associate ${FIP_ID} ${LB_PORT}
FIP_IP=`neutron floatingip-show ${FIP_ID} | grep address | awk '{print $4}'`
echo Load balancer is up with the floating IP ${FIP_IP}:${PORT}, protocol ${PROTO}. Press Enter for LB decommissioning.
read _
neutron lbaas-member-list ${POOL} | grep ${SUBNET} | awk -v pool=${POOL} '{system("neutron lbaas-member-delete " $2 " " pool)}'
neutron lbaas-pool-delete ${POOL}
neutron lbaas-listener-delete ${LISTENER}
neutron lbaas-loadbalancer-delete ${LB}
neutron floatingip-delete ${FIP_ID}
openstack server delete lb-1-${LBNAME}
openstack server delete lb-2-${LBNAME}
openstack server delete lb-3-${LBNAME}
