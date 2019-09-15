#!/bin/bash
function sigfunc() {
	pid=`pgrep cyclictest`
	[ -z ${pid} ] || kill ${pid}
        tmux kill-session -t stress 2>/dev/null
	pid=`pgrep ${stress}`
        [ -z ${pid} ] || kill ${pid}
	tmux kill-session -t testpmd
	sleep 1
	bind_driver ${vf_driver}
	exit 0
}

# convert_number_range is from https://github.com/atheurer/dpdk-rhel-perf-tools/blob/master/virt-pin.sh
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

function bind_driver() {
	local driver=$1
	dpdk-devbind -u ${pci_west} ${pci_east}
	dpdk-devbind -b ${driver} ${pci_west} ${pci_east}
}

# check env variables
if [[ -z "${pci_west}" || -z "${pci_east}" ]]; then
	echo "need env vars: pci_west, pci_east"
        exit 1
fi

if [[ -z "${DURATION}" ]]; then
	DURATION="24h"
fi

if [[ -z "${RESULT_DIR}" ]]; then
	RESULT_DIR="/tmp/cyclictest"
fi

if [[ -z "${vf_driver}" ]]; then
	vf_driver="i40evf"
fi

if [[ -z "${stress_tool}" ]]; then
	stress="false"
elif [[ "${stress_tool}" != "stress-ng" && "${stress_tool}" != "rteval" ]]; then
	stress="false"
else
	stress=${stress_tool}
fi

if [[ -z "${rt_priority}" ]]; then
	echo "rt_priority not set"
	rt_priority="false"
elif [[ "${rt_priority}" =~ ^[0-9]+$ ]]; then
	echo "rt_priority set as digits: ${rt_priority}"
	if (( rt_priority > 99 )); then
		echo "rt_priority value illegal, disabled"
		rt_priority="false"
	fi
else
	echo "rt_priority not set as digits"
	rt_priority="false"
fi

if [[ -z "${cross_numa}" ]]; then
	cross_numa="false"
elif [[ "${cross_numa}" != "pci_only" && "${cross_numa}" != "memory_pci" ]]; then
	cross_numa="false"
fi

# make sure the dir exists
[ -d ${RESULT_DIR} ] || mkdir -p ${RESULT_DIR} 

for cmd in tmux testpmd cyclictest; do
    command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed.  Aborting"; exit 1; }
done

# first parse the cpu list that can be used for testpmd
cpulist=`cat /proc/self/status | grep Cpus_allowed_list: | cut -f 2`
#cpulist="12,10,14,16"
cpulist=`convert_number_range ${cpulist} | tr , '\n' | sort | uniq`

declare -a cpus
cpus=(${cpulist})

if (( ${#cpus[@]} < 3 )); then
	echo "need at least 3 cpu to run this test!"
	exit 1
fi

mem="1024,1024"
if false; then
if [[ "${cross_numa}" == "false" || "${cross_numa}" == "pci_only" ]]; then
	if (( ${cpus[1]}%2 == 0 )); then
		mem="1024,0"
	else
		mem="0,1024"
	fi
else
	if (( ${cpus[1]}%2 == 0 )); then
		mem="0,1024"
	else
		mem="1024,0"
	fi
fi
fi

# bind driver to vfio-pci
bind_driver "vfio-pci"
sleep 1

testpmd_cmd="testpmd -l ${cpus[0]},${cpus[1]},${cpus[2]} --socket-mem ${mem} -n 4 --proc-type auto \
                 --file-prefix pg -w ${pci_west} -w ${pci_east} \
                 -- --nb-cores=2 --nb-ports=2 --portmask=3  --auto-start \
                    --rxq=1 --txq=1 --rxd=2048 --txd=2048 >/tmp/testpmd"

echo "running testpmd with RT priority: ${rt_priority}"
if [[ "${rt_priority}" == "false" ]]; then
	tmux new-session -s testpmd -d "${testpmd_cmd}"
else
	tmux new-session -s testpmd -d "chrt --fifo ${rt_priority} ${testpmd_cmd}"
fi

trap sigfunc TERM INT SIGUSR1

#cyclictest will be running on cpus[0,3,...]
cyccore=${cpus[0]}
cindex=3
ccount=1
while (( $cindex < ${#cpus[@]} )); do
	cyccore="${cyccore},${cpus[$cindex]}"
	cindex=$(($cindex + 1))
        ccount=$(($ccount + 1))
done

if false; then
if [[ "$stress" == "stress-ng" ]]; then
	taskset -c ${cyccore} stress-ng --cpu ${ccount} --cpu-load 100 --cpu-method loop &
elif [[ "$stress" == "rteval" ]]; then
	tmux new-session -s stress -d "rteval -v --onlyload"
fi
fi

cyclictest -q -D ${DURATION} -p 99 -t ${ccount} -a ${cyccore} -h 30 -m -n > ${RESULT_DIR}/cyclictest_${DURATION}.out
# kill testpmd before exit 
tmux kill-session -t testpmd
sleep 1
bind_driver ${vf_driver}
