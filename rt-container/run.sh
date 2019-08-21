#!/usr/bin/env bash
docker run  --rm --device=/dev/cpu_dma_latency:/dev/cpu_dma_latency --cap-add=SYS_RAWIO --cap-add=SYS_NICE --cap-add=IPC_LOCK -v /tmp/results:/cyclictest_results -e DURATION=2m cscojianzhan/rt-cyclictest
