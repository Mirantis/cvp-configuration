#!/bin/bash
function print_help {
   echo "Missing parameters: del_vm.sh <cmp_node> <instance-XXXXXX>"
   exit 1
}
if [[ -z ${1+x} ]]; then
   print_help
fi
if [[ -z ${2+x} ]]; then
   print_help
fi

echo "Destroy-n-undefine a VM..."
salt ${1}\* cmd.run "virsh destroy ${2}; virsh undefine ${2}"
