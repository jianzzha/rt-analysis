#!/usr/bin/env bash
yum install -y bridge-utils
if ! ip link show br-em1 2>/dev/null; then
    # bridge not exists
    brctl addbr br-em1
    brctl addif br-em1 em1
    ip add add 2.2.2.1/24 dev br-em1
fi

if ! ip link show br-em1 | grep 'state UP'; then
    ip link set br-em1 up
    ip link set em1 up
fi

