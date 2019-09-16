#!/usr/bin/env bash
docker run  --rm --device=/dev/cpu_dma_latency:/dev/cpu_dma_latency --cap-add=SYS_RAWIO --cap-add=SYS_NICE --cap-add=IPC_LOCK -v /tmp/results:/cyclictest_results -e DURATION=2m cscojianzhan/rt-cyclictest

docker run -it --rm --privileged  -v /sys:/sys -v /dev:/dev -v /lib/modules:/lib/modules --cpuset-cpus 2,4,6,8 docker.io/cscojianzhan/trafficgen bash

