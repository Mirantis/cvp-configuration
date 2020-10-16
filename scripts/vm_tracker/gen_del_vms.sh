#!/bin/bash
cmp_mask="cmp"
echo "Using Compute nodes mask of ${cmp_mask}"
python analyze.py | tee vms.list
cat vms.list | cut -d' ' -f 3 >vms
cat vms | xargs -I{} grep "{}\|${cmp_mask}" ./virsh_vms >to_del_vms
rm vms
