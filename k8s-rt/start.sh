#!/usr/bin/env bash
if crictl ps -a | grep podsandbox1-cyclictest; then
    CONTAINER_ID=$(crictl ps -a | awk '/podsandbox1-cyclictest/ {print $1}')
    crictl stop ${CONTAINER_ID}
    crictl rm ${CONTAINER_ID}
fi

if crictl pods | grep podsandbox1; then
    POD_ID=$(crictl pods | awk '/podsandbox1/ {print $1}')
    crictl stopp ${POD_ID}
    crictl rmp ${POD_ID}
fi

POD_ID=$(crictl runp sandbox_config.json)
CONTAINER_ID=$(crictl create $POD_ID container_cyclictest.json sandbox_config.json)
crictl start $CONTAINER_ID
