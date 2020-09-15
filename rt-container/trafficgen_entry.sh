#!/bin/bash

function sigfunc() {
    pid=`pgrep binary-search`
    [ -z ${pid} ] || kill ${pid}
    tmux kill-session -t trex
    exit 0
}

trap sigfunc SIGTERM SIGINT SIGUSR1

if [ -z "$1" ]; then
    # do nothing
    sleep infinity
    exit 0 

else
    if [ -z "${pci_list}" ]; then
        echo "need env var: pci_list"
        exit 1
    fi
    # how many devices?
    number_of_devices=$(echo ${pci_list} | sed -e 's/,/ /g' | wc -w)
    if [ ${number_of_devices} -lt 2 ]; then
        echo "need at least 2 pci devices"
        exit 1
    fi
    # device_pairs in form of "0:1,2:3"
    index=0
    while [ ${index} -lt ${number_of_devices} ]; do
        if [ -z ${device_pairs} ]; then
            device_pairs="$((index)):$((index+1))"
        else
            device_pairs="${device_pairs},$((index)):$((index+1))"
        fi
        ((index+=2))
    done

    output_dir='/root/tgen'
    mkdir -p ${output_dir} 2>/dev/null

    if [ "$1" == "start" ]; then
        if [ -z "${validation_seconds}" ]; then
            validation_seconds=300
        fi
        if [ -z "${search_seconds}" ]; then
            search_seconds=30
        fi
        if [ -z "${sniff_seconds}" ]; then
            sniff_seconds=10
        fi
        if [ -z "${loss_ratio}" ]; then
            loss_ratio=0.002
        fi
        if [ -z "${flows}" ]; then
            flows=1
        fi
        if [ -z "${frame_size}" ]; then
            frame_size=64
        fi
        cd /root/tgen
        ./launch-trex.sh --devices=${pci_list} --use-vlan=y
        sleep 1
        for size in $(echo ${frame_size} | sed -e 's/,/ /g'); do
            ./binary-search.py --traffic-generator=trex-txrx --rate-tolerance=10 --use-src-ip-flows=1 --use-dst-ip-flows=1 --use-src-mac-flows=1 --use-dst-mac-flows=1 \
                --use-src-port-flows=0 --use-dst-port-flows=0 --use-encap-src-ip-flows=0 --use-encap-dst-ip-flows=0 --use-encap-src-mac-flows=0 --use-encap-dst-mac-flows=0 \
                --use-protocol-flows=0 --device-pairs=${device_pairs} --active-device-pairs=${device_pairs} --sniff-runtime=${sniff_seconds} \
                --search-runtime=${search_seconds} --validation-runtime=${validation_seconds} --max-loss-pct=${loss_ratio} \
                --traffic-direction=bidirectional --frame-size=${size} --num-flows=${flows} --rate-tolerance-failure=fail \
                --rate-unit=% --rate=100
        done
        sleep infinity
    fi
    
    if [ "$1" == "api-server" ]; then
        cd /root/tgen
        ./launch-trex.sh --devices=${pci_list} --use-vlan=y
        ./api-server.py --output-dir="${output_dir}" --device-pairs="${device_pairs}"
    fi
fi
