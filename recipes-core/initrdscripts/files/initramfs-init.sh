#!/usr/bin/sh
# SPDX-License-Identifier: MIT
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>

# Early initramfs init script:
# - Mounts pseudo filesystems
# - Parses kernel cmdline for root device
# - Sets up IMA/EVM keys and loads IMA policy
# - Mounts the real rootfs and switches to /sbin/init
#

set -x

export PATH=$PATH:/sbin:/usr/sbin

ROOT_MNT="/tmp/rootfs"
BOOT_MNT="/boot"

ROOT_DEV=""
OPT_ROOT="ro,noatime"

IMA_POLICY="/etc/ima/ima-policy"
IMA_X509="/etc/keys/x509_ima.der"
EVM_X509="/etc/keys/x509_evm.der"

TIMEOUT=40

# Init
INIT="/sbin/init"

mount_pseudo_fs() {

	mount -t devtmpfs none /dev
	mount -t tmpfs tmp /tmp
	mount -t proc proc /proc
	mount -t sysfs sysfs /sys
	mount -t securityfs securityfs /sys/kernel/security
}

parse_cmdline() {

	#Parse kernel cmdline to extract base device path
	CMDLINE="$(cat /proc/cmdline)"
	echo "Kernel cmdline: $CMDLINE"
	for c in ${CMDLINE}; do
		case "$c" in
			root=*)
				ROOT_DEV="${c#root=}"
				;;
		esac
	done
}

error_exit() {

	echo "$1!"
	reboot -f
}

wait_for_dev() {

	i=0
	while [ $i -lt $TIMEOUT ]; do
		if [ -b "$1" ] ; then
				break;
		fi
		i=$((i + 1))
		sleep 0.1
	done
	if [ $i -eq $TIMEOUT ]; then
		error_exit "Timeout waiting for $1"
	fi
}

setup_ima_evm() {

	# Import IMA/EVM X509
	if [ ! -f "$IMA_X509" ] && [ ! -f "$EVM_X509" ]; then
		error_exit "IMA/EVM X509 certificates not found!"
	fi

	ima_id=$(keyctl newring _ima @u)
	evmctl import "$IMA_X509" $ima_id

	evm_id=$(keyctl newring _evm @u)
	evmctl import "$EVM_X509" $evm_id

	# Load IMA policy
	if [ ! -f "$IMA_POLICY" ]; then
		error_exit "IMA policy not found!"
	fi

	# Get root filesystem UUID
	FSUUID=$(blkid $ROOT_DEV -s UUID -o value)
	if [ -z "$FSUUID" ]; then
		error_exit "cannot get filesystem UUID for $ROOT_DEV"
	fi

	# Replace placeholder in IMA policy before loading it
	sed "s|__FSUUID__|$FSUUID|g" "$IMA_POLICY" > /sys/kernel/security/integrity/ima/policy \
		|| error_exit "cannot load IMA policy"

	# Enable EVM in signature verification mode only 
	# and lock the configuration to prevent changes at runtime
	echo "0x80000002" > /sys/kernel/security/integrity/evm/evm
}

echo "Starting Initramfs..."
mount_pseudo_fs
parse_cmdline

# Check root device
echo "Root device: $ROOT_DEV"
if [ -z "$ROOT_DEV" ] || [ "$ROOT_DEV" = "/dev/nfs" ]; then
	error_exit "cannot get root device"
fi

wait_for_dev "$ROOT_DEV"

# Setup IMA/EVM
setup_ima_evm

# this is needed to make pipe work in shell
ln -s /proc/self/fd /dev/fd

# Mount root filesystem
mkdir -p $ROOT_MNT
mount -o "$OPT_ROOT" "$ROOT_DEV" "$ROOT_MNT" || error_exit "cannot mount root filesystem"

# Switch to real root
echo "Switch to real root..."
exec switch_root $ROOT_MNT $INIT || error_exit "cannot switch_root to real root"
