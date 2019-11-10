#!/usr/bin/bash
echo "clear iptables"
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

echo "find default route interface"
intf=$(ip route | awk '/default\svia/{print $NF}')

echo "set MASQUERADE to $intf"
iptables -t nat -A POSTROUTING -o $intf -j MASQUERADE 

