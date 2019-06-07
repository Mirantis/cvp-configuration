#!/bin/bash

function help_and_exit {
    echo "simple_profile.sh <repeat_count>"
    exit 1
}

#if [ -z ${1+x} ]; then echo "First parameter should be total count of the requests"; help_and_exit; fi
count=1
declare all_req=()
declare errors=()
tmp_time=$(mktemp)
tmp_out=$(mktemp)

function profiled_run {
        if [ -z ${2+x} ]; then
                /usr/bin/time --quiet -f'%e %x' -o ${tmp_time} ${1} 1>/dev/null 2>${tmp_out}
                real=$(cat ${tmp_time} | awk '{print $1}')
                errlevel=$(cat ${tmp_time} | awk '{print $2}')
                if [ 0 -eq ${errlevel} ]; then
                        echo "#${count}(${real}s), '${1}'";
                        all_req+=("#${count}, ${real}, '${1}'");
                else
                        echo "#${count}, ERROR(${errlevel}): '${1}'"
                        errors+=("#${count}: $(cat ${tmp_out})")
                fi
                ((count++))
        else
                echo "### Running '${1}' ${2} times"
                for (( idx=1; idx<=${2}; idx++ ))
                do
                        /usr/bin/time --quiet -f'%e %x' -o ${tmp_time} ${1} 1>/dev/null 2>${tmp_out}
                        real=$(cat ${tmp_time} | awk '{print $1}')
                        errlevel=$(cat ${tmp_time} | awk '{print $2}')
                        if [ 0 -eq ${errlevel} ]; then
                                echo "#${count}/${idx}, ${real}s";
                                all_req+=("#${count}/${idx}, ${real}, '${1}'");
                        else
                                echo "#${count}/${idx}, ERROR(${errlevel}): '${1}'"
                                errors+=("#${count}: $(cat ${tmp_out})")
                        fi
                        ((count++))
                done
        fi
}

function errors {
        echo "==== Errors"
        for i in "${!errors[@]}"; do
                printf "#%s\n\n" "${errors[$i]}"
        done
}

function stats {
        echo "==== Stats"
        printf '%s\n' "${all_req[@]}" | awk 'BEGIN{min=999;avg=0}
        {if($2<min){min=$2;}if($2>max){max=$2;}avg+=$2;}
        END { print "Total requests: "NR", Timings: "min" <-- "avg/NR" --> "max;}'
}

function clean {
        rm ${tmp_time}
        rm ${tmp_out}
}

echo "===== Totals"
echo "Total projects = $(openstack project list -f value -c ID | wc -l)"
echo "Total networks = $(openstack network list -f value -c ID | wc -l)"
echo "Total subnets = $(openstack subnet list -f value -c ID | wc -l)"
echo "Total ports = $(openstack port list -f value -c ID | wc -l)"
echo "Total servers = $(openstack server list --all-projects --limit -1 -f value -c ID | wc -l)"
echo "Total images = $(openstack image list -f value -c ID | wc -l)"
echo "===== Timings"
openstack --timing project list
openstack --timing network list
openstack --timing subnet list
openstack --timing port list
openstack --timing server list
openstack --timing image list

echo "********"
profiled_run "openstack network list" 10
stats
declare all_req=()
echo "********"
profiled_run "openstack project list" 10
stats
declare all_req=()
echo "********"
profiled_run "openstack server list --limit -1" 10
stats
declare all_req=()
profiled_run "heat stack-list" 10
stats
declare all_req=()
echo "********"
profiled_run "heat resource-type-list" 10
stats
declare all_req=()
echo "********"
profiled_run "nova list --limit -1" 10
stats
declare all_req=()
echo "********"
profiled_run "glance image-list" 10
echo "===================================="
errors
clean