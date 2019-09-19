#!/usr/bin/env bash
docker run  --rm --device=/dev/cpu_dma_latency:/dev/cpu_dma_latency --cap-add=SYS_RAWIO --cap-add=SYS_NICE --cap-add=IPC_LOCK -v /tmp/results:/cyclictest_results -e DURATION=2m cscojianzhan/rt-cyclictest

docker run -it --rm --privileged  -v /sys:/sys -v /dev:/dev -v /lib/modules:/lib/modules --cpuset-cpus 2,4,6,8 docker.io/cscojianzhan/trafficgen bash

# this is a series command to run inside tgen container for test
./launch-trex.sh --devices=0000:03:00.0,0000:03:00.1 --use-vlan=y 

./binary-search.py --traffic-generator=trex-txrx --rate-tolerance=3 --use-src-ip-flows=1 --use-dst-ip-flows=1 --use-src-mac-flows=1 --use-dst-mac-flows=1 --use-src-port-flows=0 --use-dst-port-flows=0 --use-encap-src-ip-flows=0 --use-encap-dst-ip-flows=0 --use-encap-src-mac-flows=0 --use-encap-dst-mac-flows=0 --use-protocol-flows=0 --device-pairs=0:1 --active-device-pairs=0:1 --sniff-runtime=5 --search-runtime=5 --validation-runtime=5 --rate-unit=% --rate=100 --max-loss-pct=0.002 --traffic-direction=bidirectional --frame-size=64 --num-flows=1

