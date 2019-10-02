#!/bin/bash
silent=false
cleaning=false

tmp_out=$(mktemp)
trap "rm -f ${tmp_out}" EXIT

declare errors=()

function show_help {
    printf "Compute check/filling script\n\t-h, -?\tShow this help\n"
    printf "\t-d\tCleaning of earlier created VMs\n"
    printf "\t-q\tSilent mode\n"
    printf "\nUsage: cmp_check.sh <compute_hostname> [<vm_count>|def:1]\n"
    printf "\t<compute_hostname> is a host shortname\n"
    printf "\t<vm_count> is optional.\n"
    printf "\t\tIf not set, script will check CMP: create, do actions and delete a VM\n"
    printf "\t\tIf set, script will create a <vm_count> of VMs and exit\n\n"
}

OPTIND=1 # Reset in case getopts has been used previously in the shell.
while getopts "h?:qd" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    q)  silent=true
        ;;
    d)  cleaning=true
        ;;
    esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# Check and create cmp_name var
if [[ -z ${1+x} ]]; then
   show_help
   printf "\nERROR: No compute host specified"
   exit 1
fi
cmp_name=${1}

# Check and create vmname var
if [[ -z ${2+x} ]]; then
   vmcount=1
else
   vmcount=${2}
fi
vmname=vm_${1}


function cmp_stats() {
   cmpid=$(openstack hypervisor list --matching ${1} -f value -c ID)
   vars=( $(openstack hypervisor show ${cmpid} -f shell -c running_vms -c vcpus -c vcpus_used -c memory_mb -c memory_mb_used) )
   declare ${vars[@]}
   printf "${1}: vms=%s vcpus=%s/%s ram=%s/%s\n" ${running_vms} ${vcpus_used} ${vcpus} ${memory_mb_used} ${memory_mb}
}

function waitfor () {
   counter=0
   while [ ${counter} -lt 6 ]; do
      ids=( $(openstack server list --name ${vmname} --status ${1} -f value -c ID) )
      if [ ${#ids[@]} -eq 0 ]; then
         sleep 5
         counter=$((counter + 1))
      else
         [ ! "$silent" = true ] && printf "# '${vmname}' reached status ${1}\n"
         break
      fi
   done
}

function getid() {
   openstack server list -c ID -c Name -f value | grep "${1}" | cut -d' ' -f1
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

# temp file for commands
cmds=$(mktemp)
#trap "rm -f ${cmds}" EXIT
#echo "# Using tempfile: '${cmds}'"

# trap "source adminrc" EXIT

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

[ ! "$silent" = true ] && echo "# Sourcing cvprc"
source cvprc

# #### Cleaning mode
if [ $cleaning = true ]; then
   echo "# Cleaning mode (${cmp_name})"
   vmid=( $(getid ${vmname}) )
   if [ ${#vmid[@]} -ne 0 ]; then
      [ ! "$silent" = true ] && echo "# Found ${#vmid[@]} previously created VMs. Cleaning."
      vm_action delete "$(join_by ' ' "${vmid[@]}")"
   else
      [ ! "$silent" = true ] && echo "# ...no VMs found"
   fi
   echo "# Done cleaning"
   errors
   exit 0
fi

if [ ${vmcount} = 1 ]; then
   echo "# Checking mode (${cmp_name})"
   # ### CMP Checking mode
   # if there are only 1 to boot, check actions with it too
   cmp_stats ${cmp_name}
   vm_create ${cmp_name} ${vmname}
   waitfor ACTIVE
   vmid=$(getid ${vmname})

   cmp_stats ${cmp_name}

   vm_action pause ${vmid}
   waitfor PAUSED
   vm_action unpause ${vmid}
   waitfor ACTIVE

   [ ! "$silent" = true ] && echo "# ... deleting created VM (${vmid})"
   vm_action delete ${vmid}

   cmp_stats ${cmp_name}
   printf "# Done checking ${cmp_name}\n"
else
   echo "# Filling mode (${cmp_name})"
   # ### CMP fillling mode
   # if vmcount>1, just create them and exit
   counter=1
   while [[ $counter -lt ${vmcount}+1 ]]; do
      vmname_c=${vmname}_$(printf "%02d" ${counter})
      [ ! "$silent" = true ] && echo "# ... creating VM on ${cmp_name} using name of ${vmname_c}"
      vm_create ${cmp_name} ${vmname_c}
      cmp_stats ${cmp_name}
      ((counter++))
   done
   printf "# Done filling ${cmp_name}\n"
fi

errors

