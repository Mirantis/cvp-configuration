#!/bin/bash
cmp_name=${1}
vmname=vm_${1}_01

function waitfor () {
   counter=0
   while [ ${counter} -lt 6 ]; do
      ids=( $(openstack server list --name ${vmname} --status ${1} -f value -c ID) )
      if [ ${#ids[@]} -eq 0 ]; then
         sleep 5
         counter=$((counter + 1))
      else
         printf "# '${vmname}' reached status ${1}\n"
         break
      fi
   done
}

function getid() {
   openstack server list --name ${1} -f value -c ID
}

function vm_create() {
   set -x
   openstack server create --nic net-id=${fixed_net_left_id} --image ${cirros35_id} --flavor ${flavor_tiny_id} --key-name ${keypair_id} --security-group ${secgroup_all_id} --availability-zone nova:${1} ${2} 2>&1 >/dev/nul
   set +x
}

function vm_action() {
   openstack server ${1} ${2}
}

# temp file for commands
cmds=$(mktemp)
#trap "rm -f ${cmds}" EXIT
#echo "# Using tempfile: '${cmds}'"

# trap "source adminrc" EXIT

echo "### CMP check for booting VMs"
if [ ! -f cvp.manifest ]; then
   echo "ERROR: No cvp.manifest file detected. Consider running prepare.sh"
   exit 1
else
   source cvp.manifest
fi

if [ -z ${cmp_name} ]; then
   echo "CMP node name not specified"
   exit 1
fi

echo "# Sourcing cvprc"
source cvprc

echo "# Checking for previously created VMs"
vmid=( $(getid ${vmname}) )
if [ ${#vmid[@]} -ne 0 ]; then
   echo "# Found previously created VMs. Cleaning."
   vm_action delete ${vmid[@]}
else
   echo "# ...no VMs found"
fi

printf "### Checking '${cmp_name}': Create, Pause, Unpause, Delete a VM\n"
echo "# ... creating VM on ${cmp_name} using name of ${vmname}"
vm_create ${cmp_name} ${vmname}
waitfor ACTIVE
vmid=$(openstack server list --name ${vmname} -f value -c ID)

vm_action pause ${vmid}
waitfor PAUSED
vm_action unpause ${vmid}
waitfor ACTIVE

echo "# ... deleting create VM (${vmid})"
vm_action delete ${vmid}

printf "\n# Done checking ${cmp_name}\n"

