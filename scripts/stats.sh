#!/bin/bash
# ol1 is short for openstack list with 1 param. Also grep and cut
# "ol1 network public" will list all networks, grep by name public and return IDs
function olcID1() { echo $(openstack $1 list $2 -c ID -f value | wc -l); }
# same as ol1 but with 2 initial commands before list
function olcID2() { echo $(openstack $1 $2 list $3 -c ID -f value | wc -l); }
function olc2() { echo $(openstack $1 $2 list $4 -c $3 -f value | wc -l); }

echo "### Cloud totals"
printf "Projects:\t%s\n" $(olcID1 project)
printf "Users:\t\t%s\n" $(olcID1 user)
printf "Flavors:\t%s\n" $(olcID1 flavor)
printf "Zones:\t\t%s\n" $(openstack availability zone list -c "Zone Name" -f value | sort | uniq | wc -l)
printf "Servers:\t%s\n" $(olcID1 server --all)
printf "Networks:\t%s\n" $(olcID1 network)
printf "Subnets:\t%s\n" $(olcID1 subnet)
printf "Ports:\t\t%s\n" $(olcID1 port)
printf "Volumes:\t%s\n" $(olcID1 volume --all)
printf "Snapshots:\t%s\n" $(olcID2 volume snapshot --all)
printf "Images:\t\t%s\n" $(olcID1 image)

