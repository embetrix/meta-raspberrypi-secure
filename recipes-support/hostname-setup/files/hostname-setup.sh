#!/bin/sh
# Copyright 2025  Embetrix Embedded Systems Solutions, ayoub.zaki@embetrix.com
#

# pick the first non-loopback interface as the hostname base
IF="$(ls /sys/class/net | grep -v lo | head -n1)"
if [ -z "$IF" ]; then
    echo "No network interface found!"
else
    echo "Using interface $IF"
    export MACADDR="$(cat /sys/class/net/$IF/address | tr : -)"
    echo $(hostname)-${MACADDR:9:12} > /proc/sys/kernel/hostname
    echo "done"
fi
