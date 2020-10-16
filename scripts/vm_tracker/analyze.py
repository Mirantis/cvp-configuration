#!/usr/bin/python
import json
def lookup_near(ls, name):
    for vm in ls:
        if vm['id'] == name:
            return vm['id']
    return False
def lookup_far(dc, name):
    result_hvs = []
    for hv in dc:
        res = lookup_near(dc[hv], name)
        if res:
            result_hvs.append(hv)
    return result_hvs
lost_vms = {}
hypervisors = {}
hypervisor_pattern = "cmp" #Replace with your own pattern, ensure it's unique so it wouldn't mix up with VM names
print("\n# Using hypervisor pattern of '{}'\n\n".format(hypervisor_pattern))
print("# Replace it with your own pattern if needed.\n# Ensure it's unique so it wouldn't mix up with VM names.\n\n")
skip_pattern = "------------"
current_hv = ""
vm_pattern = "-"
with open("virsh_vms", "rt") as f:
    for line in f.readlines():
        line = line.replace("\n", "")
        if skip_pattern in line:
            continue
        elif hypervisor_pattern in line:
            current_hv = line.replace(":", "")
            if current_hv in hypervisors:
                print("Duplicate hypervisor {}, exiting".format(current_hv))
                break
            else:
                hypervisors[current_hv] = []
        elif vm_pattern in line:
            if not current_hv:
                print("Malformed virsh list, exiting")
                break
            vm_info_struct = [x for x in line.replace("\n", "").replace("\t"," ").replace("shut off", "shutoff").split(" ") if x]
            if len(vm_info_struct) == 4:
                iid, virsh_id, iname, state  = vm_info_struct
                hypervisors[current_hv].append({"id": iid, "state": state})
            elif len(vm_info_struct) == 3: #No UUID assigned
                virsh_id, iname, state = vm_info_struct
                if not lost_vms.has_key(current_hv):
                    lost_vms[current_hv] = [iname + ":" + state]
                else:
                    lost_vms[current_hv].append(iname + ":" + state)
nova_out = ""
nova_vms = {}
with open("nova_vms", "rt") as f:
     for line in f.readlines():
         if "servers" in line:
             if "RESP BODY" in line:
                 nova_out = line.replace("RESP BODY: ", "").replace("\n", "")
                 nova_vms_json = json.loads(nova_out)
                 for vm in nova_vms_json['servers']:
                     vm_id = vm['id']
                     vm_iname = vm['OS-EXT-SRV-ATTR:instance_name']
                     vm_hv = vm['OS-EXT-SRV-ATTR:hypervisor_hostname']
                     vm_state = vm['OS-EXT-STS:vm_state']
                     if vm_hv not in nova_vms:
                         nova_vms[vm_hv] = []
                     nova_vms[vm_hv].append({"id": vm_id, "name": vm_iname, "state": vm_state})
rev = {}
lsdup = []
for hv in hypervisors:
   for vm in hypervisors[hv]:
       if not vm['id'] in rev:
           rev[vm['id']] = [hv+"({})".format(vm['state'])]
       else:
           rev[vm['id']].append(hv+"({})".format(vm['state']))
for vm_id in rev:
   if len(rev[vm_id]) > 1:
       print("Duplicate VM: {} on {}".format(vm_id, rev[vm_id]))
       lsdup.append(vm_id)
for hv in hypervisors:
    if hv not in nova_vms and len(hypervisors[hv]) > 0:
        #print "WARN: hypervisor %s exists but nova doesn't know that it has following VMs:" % hv
        for vm in hypervisors[hv]:
            if not lookup_far(nova_vms, vm["id"]):
                print("Nova doesn't know that vm {} is running on {}".format((vm["id"], hv)))
        continue
    for vm in hypervisors[hv]:
        report = ""
        if not lookup_near(nova_vms[hv], vm['id']):
            if vm['id'] in lsdup:
                continue
            report += "WARN: VM {} is on hypervisor {}".format((vm['id'], hv))
            nova_hvs = lookup_far(nova_vms, vm["id"])
            if nova_hvs:
                report +=  ", but nova thinks it is running on {}.".format((str(nova_hvs)))
            else:
                report += ", but nova doesn't know about it."
            report += " VM state is %s " % vm['state']
        if report:
            print(report)
if lost_vms:
    print("Lost VMs report (existing in virsh without an UUID and completely untracked in Openstack)")
for hv in lost_vms:
     print(hv+":")
     for vm in lost_vms[hv]:
         print(vm)

