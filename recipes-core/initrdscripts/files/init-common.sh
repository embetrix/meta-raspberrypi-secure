#!/usr/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Common helpers: logging, early mounts, block device wait

fatal() {

	echo "FATAL: $1" >&2
	reboot -f
	#sh
}

klog() {

	echo $@
    echo "Initramfs: $@" > /dev/kmsg
}

mount_early_fs() {

	mount -t devtmpfs none /dev
	mount -t tmpfs tmp /tmp
	mount -t proc proc /proc
	mount -t sysfs sysfs /sys
	mount -t selinuxfs selinuxfs /sys/fs/selinux
	mount -t securityfs securityfs /sys/kernel/security
}

await_blockdev() {

	i=0
	while [ $i -lt $TIMEOUT ]; do
		if [ -b "$1" ] ; then
				break;
		fi
		i=$((i + 1))
		sleep 0.1
	done
	if [ $i -eq $TIMEOUT ]; then
		fatal "Timeout waiting for $1"
	fi
}
