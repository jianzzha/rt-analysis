#!/bin/bash
function sigfunc() {
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
        # for mlnx card, don't do anything
        if [ "${driver}" == "mlx5_core" ]; then
            return 0
        fi
	dpdk-devbind -u ${pci_west} ${pci_east}
	dpdk-devbind -b ${driver} ${pci_west} ${pci_east}
}

# check env variables
pci_list=$(env | sed -n -r -e 's/PCIDEVICE.*=(.*)/\1/p' | tr ',\n' ' ')
if [ -n "${pci_list}" ]; then
    pci_count=$(echo "${pci_list}" | wc -w )
    if (( ${pci_count} != 2 )); then
        echo "this container only support two pci network devices!"
        exit 1
    else
        pci_west=$(echo "${pci_list}" | cut -f1 -d ' ')
        pci_east=$(echo "${pci_list}" | cut -f2 -d ' ')
    fi
fi
    
if [[ -z "${pci_west}" || -z "${pci_east}" ]]; then
	echo "need env vars: pci_west, pci_east"
        exit 1
fi

if [[ -z "${vf_driver}" ]]; then
	vf_driver="i40evf"
fi

if [[ -z "${ring_size}" ]]; then
        ring_size=2048
fi

echo "pci_west ${pci_west} pci_east ${pci_east} vf_driver ${vf_driver} ring_size ${ring_size}"

for cmd in testpmd dpdk-devbind; do
    command -v $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but not installed.  Aborting"; exit 1; }
done

# first parse the cpu list that can be used for testpmd
cpulist=`cat /proc/self/status | grep Cpus_allowed_list: | cut -f 2`
cpulist=`convert_number_range ${cpulist} | tr , '\n' | sort | uniq`

declare -a cpus
cpus=(${cpulist})

if (( ${#cpus[@]} < 3 )); then
	echo "need at least 3 cpu to run this test!"
	exit 1
fi

mem="1024,1024"

# bind driver to vfio-pci unless it is mlnx nic
if [ "${vf_driver}" != "mlx5_core" ]; then
    bind_driver "vfio-pci"
    sleep 1
fi

testpmd_cmd="testpmd -l ${cpus[0]},${cpus[1]},${cpus[2]} --socket-mem ${mem} -n 4 --proc-type auto \
                 --file-prefix pg -w ${pci_west} -w ${pci_east} \
                 -- --nb-cores=2 --nb-ports=2 --portmask=3  --auto-start \
                    --rxq=1 --txq=1 --rxd=${ring_size} --txd=${ring_size} >/tmp/testpmd"

tmux new-session -s testpmd -d "${testpmd_cmd}"

trap sigfunc TERM INT SIGUSR1

sleep infinity
tmux kill-session -t testpmd
sleep 1
bind_driver ${vf_driver}
