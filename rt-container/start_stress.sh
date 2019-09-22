#!/bin/bash

function convert_number_range() {
        # converts a range of cpus, like "1-3,5" to a list, like "1,2,3,5"
        local cpu_range=$1
        local cpus_list=""
        local cpus=""
        for cpus in `echo "$cpu_range" | sed -e 's/,/ /g'`; do
                if echo "$cpus" | grep -q -- "-"; then
                        cpus=`echo $cpus | sed -e 's/-/ /'`
                        cpus=`seq $cpus | sed -e 's/ /,/g'`
                fi
                for cpu in $cpus; do
                        cpus_list="$cpus_list,$cpu"
                done
        done
        cpus_list=`echo $cpus_list | sed -e 's/^,//'`
        echo "$cpus_list"
}

function sigfunc() {
        tmux kill-session -t stress 2>/dev/null
	exit 0
}

if [[ -z "${stress_tool}" ]]; then
	stress="stress-ng"
elif [[ "${stress_tool}" != "stress-ng" && "${stress_tool}" != "rteval" ]]; then
	stress="stress-ng"
else
	stress=${stress_tool}
fi


for cmd in tmux stress-ng rteval; do
    command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed.  Aborting"; exit 1; }
done

cpulist=`cat /proc/self/status | grep Cpus_allowed_list: | cut -f 2`
cpulist=`convert_number_range ${cpulist} | tr , '\n' | sort | uniq`

declare -a cpus
cpus=(${cpulist})

trap sigfunc TERM INT SIGUSR1

# stress run in each tmux window per cpu
if [[ "$stress" == "stress-ng" ]]; then
    tmux new-session -s stress -d
    for w in $(seq 1 ${#cpus[@]}); do
        tmux new-window -t stress -n $w "taskset -c ${cpus[$(($w-1))]} stress-ng --cpu 1 --cpu-load 100 --cpu-method loop"
    done
fi

if [[ "$stress" == "rteval" ]]; then
	tmux new-session -s stress -d "rteval -v --onlyload"
fi

sleep infinity
tmux kill-session -t stress 2>/dev/null
