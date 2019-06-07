#!/bin/bash

function help_and_exit {
    echo "profiled_run.sh <command>"
    exit 1
}

#if [ -z ${1+x} ]; then echo "First parameter should be command to run"; help_and_exit; fi
#if [ -z ${2+x} ]; then echo "Second parameter should be count of time to run"; help_and_exit; fi
total=${2}
count=1
cmd="${1}"

declare all_req=()
declare errors=()
tmp_time=$(mktemp)
tmp_out=$(mktemp)

function timed_run {
        if [ -z ${2+x} ]; then
                echo "--> '${1}'"
                /usr/bin/time --quiet -f'%e %x' -o ${tmp_time} /bin/bash -c "${1}" 1>/dev/null 2>${tmp_out}
                real=$(cat ${tmp_time} | awk '{print $1}')
                errlevel=$(cat ${tmp_time} | awk '{print $2}')
                if [ 0 -eq ${errlevel} ]; then
                        echo "#${count}(${real}s), '${1:0:12}...'";
                        all_req+=("#${count}, ${real}, '${1}'");
                else
                        echo "#${count}, ERROR(${errlevel}): '${1}'"
                        errors+=("#${count}: $(cat ${tmp_out})")
                fi
                ((count++))
        else
                echo "### Running '${1:0:12}...' ${2} times"
                for (( idx=1; idx<=${2}; idx++ ))
                do
                        /usr/bin/time --quiet -f'%e %x' -o ${tmp_time} /bin/bash -c "${1}" 1>/dev/null 2>${tmp_out}
                        real=$(cat ${tmp_time} | awk '{print $1}')
                        errlevel=$(cat ${tmp_time} | awk '{print $2}')
                        if [ 0 -eq ${errlevel} ]; then
                                echo "#${count}/${total}, ${real}s";
                                all_req+=("#${count}/${idx}, ${real}, '${1}'");
                        else
                                echo "#${count}/${total}, ERROR(${errlevel}): '${1}'"
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

timed_run "${cmd}" ${total}
stats
errors
clean