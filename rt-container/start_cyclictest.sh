#!/bin/bash

function sigfunc() {
        tmux kill-session -t stress 2>/dev/null
	rm -rf {RESULT_DIR}/cyclictest_running
	exit 0
}

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


if [[ -z "${DURATION}" ]]; then
	DURATION="24h"
fi

if [[ -z "${RESULT_DIR}" ]]; then
	RESULT_DIR="/tmp/cyclictest"
fi

if [[ -z "${stress_tool}" ]]; then
	stress="false"
elif [[ "${stress_tool}" != "stress-ng" && "${stress_tool}" != "rteval" ]]; then
	stress="false"
else
	stress=${stress_tool}
fi

if [[ -z "${rt_priority}" ]]; then
        rt_priority=99
elif [[ "${rt_priority}" =~ ^[0-9]+$ ]]; then
	if (( rt_priority > 99 )); then
		rt_priority=99
	fi
else
	rt_priority=99
fi


# make sure the dir exists
[ -d ${RESULT_DIR} ] || mkdir -p ${RESULT_DIR} 

for cmd in tmux cyclictest; do
    command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed.  Aborting"; exit 1; }
done

# first parse the cpu list that can be used for testpmd
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

cyccore=${cpus[0]}
cindex=1
ccount=1
while (( $cindex < ${#cpus[@]} )); do
	cyccore="${cyccore},${cpus[$cindex]}"
	cindex=$(($cindex + 1))
        ccount=$(($ccount + 1))
done

touch ${RESULT_DIR}/cyclictest_running
cyclictest -q -D ${DURATION} -p ${rt_priority} -t ${ccount} -a ${cyccore} -h 30 -m -n > ${RESULT_DIR}/cyclictest_${DURATION}.out
# kill stress before exit 
tmux kill-session -t stress 2>/dev/null
rm -rf ${RESULT_DIR}/cyclictest_running
