#!/bin/bash
silent=false
cleaning=false
all_computes=false
fill_mode=false

tmp_out=$(mktemp)
trap "rm -f ${tmp_out}" EXIT

declare errors=()

function show_help {
    printf "Compute check/filling script\n\t-h, -?\tShow this help\n"
    printf "\t-d\tCleaning of earlier created VMs\n"
    printf "\t-q\tSilent mode\n"
    printf "\t-a\tEnumeratre all computes\n"
    printf "\t-f\tFill mode\n"
    printf "\nUsage: cmp_check.sh (-a | <compute_hostname>) (-f [<vm_count>|def:1])\n"
    printf "\t<compute_hostname> is a host shortname\n"
    printf "\t<vm_count> is optional. Defaults to 1\n"
    printf "Examples:\n"
    printf "\tFill all computes with 3 VMs:\n\t\t'bash cmp_check.sh -fa 3'\n\n"
    printf "\tFill specific compute with 5 VMs:\n\t\t'bash cmp_check.sh -f cmp001 5'\n\n"
    printf "\tCheck all computes:\n\t\t'bash cmp_check.sh -a'\n\n"
    printf "\tCheck specific compute:\n\t\t'bash cmp_check.sh cmp001'\n\n"
    printf "\tClean all computes:\n\t\t'bash cmp_check.sh -da'\n\n"
}

OPTIND=1 # Reset in case getopts has been used previously in the shell.
while getopts "h?:qdaf" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    q)  silent=true
        ;;
    d)  cleaning=true
        ;;
    a)  all_computes=true
        ;;
    f)  fill_mode=true
        ;;
    esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# Check and create cmp_name var
if [[ -z ${1+x} ]] && [[ ! ${all_computes} == "true" ]]; then
   show_help
   printf "\nERROR: No compute host specified\n"
   exit 1
fi
if [[ ${all_computes} == "true" ]]; then
   cmp_name=all
   # if enumerate mode is set, vmcount source is ${1}
   if [[ -z ${1+x} ]] || [[ ! ${fill_mode} == true ]]; then
      vmcount=1
   else
      vmcount=${1}
   fi
else
   cmp_name=${1}
   # in single compute mode, vmcount source is ${2}
   # in check mode count is always 1
   if [[ -z ${2+x} ]] || [[ ! ${fill_mode} == true ]]; then
      vmcount=1
   else
      vmcount=${2}
   fi
fi

function cmp_stats() {
   cmpid=$(openstack hypervisor list --matching ${1} -f value -c ID)
   vars=( $(openstack hypervisor show ${cmpid} -f shell -c running_vms -c vcpus -c vcpus_used -c memory_mb -c memory_mb_used) )
   declare ${vars[@]}
   printf "${1}: vms=%s vcpus=%s/%s ram=%s/%s\n" ${running_vms} ${vcpus_used} ${vcpus} ${memory_mb_used} ${memory_mb}
}

function waitfor () {
   counter=0
   while [ ${counter} -lt 6 ]; do
      ids=( $(openstack server list --name ${1} --status ${2} -f value -c ID) )
      if [ ${#ids[@]} -eq 0 ]; then
         sleep 5
         counter=$((counter + 1))
      else
         [ ! "$silent" = true ] && printf "# '${1}' reached status ${2}\n"
         break
      fi
   done
}

function getid() {
   openstack server list -c ID -c Name -f value | grep "${1}" | cut -d' ' -f1
}

function get_all_cmp() {
   openstack hypervisor list -f value -c "Hypervisor Hostname" | cut -d'.' -f1
}

function vm_create() {
   [ ! "$silent" = true ] && set -x
   openstack server create --nic net-id=${fixed_net_left_id} --image ${cirros35_id} --flavor ${flavor_tiny_id} --key-name ${keypair_id} --security-group ${secgroup_all_id} --availability-zone nova:${1} ${2} 2>${tmp_out} >/dev/nul
   [ ! 0 -eq $? ] && errors+=("${1}/${2}: $(cat ${tmp_out})")
   set +x
   [ ! "$silent" = true ] && cat ${tmp_out}
}

function vm_action() {
   openstack server ${1} ${2} 2>${tmp_out} >/dev/nul
   if [ ! 0 -eq $? ]; then
      errors+=("${cmp_name}: $(cat ${tmp_out})")
   fi
}

function errors {
   echo "==== Errors"
   for i in "${!errors[@]}"; do
       printf "#%s\n" "${errors[$i]}"
   done
}

function join_by { local IFS="$1"; shift; echo "$*"; }


function clean_cmp() {
   # #### Cleaning mode
   if [ $cleaning = true ]; then
      vmname=vm_${1}
      vmid=( $(getid ${vmname}) )
      if [ ${#vmid[@]} -ne 0 ]; then
         [ ! "$silent" = true ] && echo "# ${1}: cleaning ${#vmid[@]} VMs"
         vm_action delete "$(join_by ' ' "${vmid[@]}")"
      else
         [ ! "$silent" = true ] && echo "# ${1}: ...no VMs found"
      fi
   fi
}

function check_cmp_node() {
   cmp_stats ${1}
   vm_create ${1} ${2}
   waitfor ${2} ACTIVE
   vmid=$(getid ${2})

   cmp_stats ${1}

   vm_action pause ${vmid}
   waitfor ${2} PAUSED
   vm_action unpause ${vmid}
   waitfor ${2} ACTIVE

   [ ! "$silent" = true ] && echo "# ... deleting created VM (${vmid})"
   vm_action delete ${vmid}

   cmp_stats ${1}
}

if [ ! -f cvp.manifest ]; then
   echo "ERROR: No cvp.manifest file detected. Consider running prepare.sh"
   exit 1
else
   source cvp.manifest
fi

[ ! "$silent" = true ] && echo "# Sourcing cvprc"
source cvprc

# #### Checking for CMP existence
if [[ ! ${cmp_name} == "all" ]]; then
   echo "# Inspecting '${cmp_name}'"
   # check that such node exists
   cmpid=$(openstack hypervisor list --matching ${cmp_name} -f value -c ID 2>${tmp_out})
   [ ! 0 -eq $? ] && errors+=("${cmp_name}: $(cat ${tmp_out})")
   if [[ -z ${cmpid} ]]; then
      echo "ERROR: ${cmp_name} not found among hypervisors"
      errors
      exit 1
   fi
fi

if [[ ${cmp_name} == all ]]; then
   echo "# Gathering compute count"
   cmp_nodes=( $(get_all_cmp) )
else
   cmp_nodes=( ${cmp_name} )
fi


# #### Cleaning mode
if [ $cleaning = true ]; then
   # get all computes
   if [[ ${cmp_name} == all ]]; then
      echo "# Cleaning ${#cmp_nodes[@]} computes"
   else
      echo "# Cleaning ${cmp_name}"
   fi

   # clean them
   for node in ${cmp_nodes[@]}; do
      clean_cmp ${node}
   done
   echo "# Done cleaning"
   errors
   exit 0
fi

# ###
if [[ ! ${fill_mode} = true ]]; then
   # ### CMP Checking mode
   if [[ ${cmp_name} == all ]]; then
      echo "# Checking ${#cmp_nodes[@]} computes"
   fi
   # check node
   for node in ${cmp_nodes[@]}; do
      echo "# ${node}: checking"
      check_cmp_node ${node} vm_${node}
      echo "# ${node}: done"
   done
   errors
   exit 0
else
   # ### CMP fillling mode
   if [[ ${cmp_name} == all ]]; then
      echo "# Filling ${#cmp_nodes[@]} computes"
   fi

   for node in ${cmp_nodes[@]}; do
      echo "# ${node}: filling"
      counter=1
      while [[ $counter -lt ${vmcount}+1 ]]; do
         vmname_c=vm_${node}_$(printf "%02d" ${counter})
         [ ! "$silent" = true ] && echo "# ${node}: creating ${vmname_c}"
         vm_create ${node} ${vmname_c}
         cmp_stats ${node}
         ((counter++))
      done
      printf "# ${node}: done\n"
   done
fi

errors

