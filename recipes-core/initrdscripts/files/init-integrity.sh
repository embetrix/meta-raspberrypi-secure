#!/usr/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Integrity helpers: EVM and AVB dm-verity setup

setup_evm_integrity() {

	klog "Setting up EVM Integrity..."
	# Enable EVM in signature + hmac verification mode
	# and lock the configuration to prevent changes at runtime
	echo "0x80000003" > /sys/kernel/security/integrity/evm/evm \
	    || fatal "Failed to enable EVM signature + HMAC verification"
}

# Verify AVB signature and set up dm-verity on the decrypted root device.
# The AVB footer (with hashtree) lives inside the dmcrypt container.
# Usage: setup_avb_verity <dmcrypt_name> <dmverity_name>
setup_avb_verity() {

	dev="/dev/mapper/$1"
	verity_name="$2"

	if [ ! -f "$AVB_PUBKEY" ]; then
		fatal "AVB public key not found at $AVB_PUBKEY"
	fi

	klog "Verifying AVB signature on $dev..."
	dm_table=$(avb_verify --dm-table -d "$dev" -k "$AVB_PUBKEY") \
		|| fatal "AVB verification failed on $dev"

	# Apply dm-verity corruption behavior from kernel cmdline
	# (prod=restart, dev=ignore)
	case " $(cat /proc/cmdline) " in
		*" verity_mode=ignore "*) dm_table="$dm_table 1 ignore_corruption" ;;
		*" verity_mode=panic "*)  dm_table="$dm_table 1 panic_on_corruption" ;;
		*)                        dm_table="$dm_table 1 restart_on_corruption" ;;
	esac

	klog "Setting up dm-verity as $verity_name..."
	echo "$dm_table" | dmsetup create --readonly "$verity_name" \
		|| fatal "cannot create dm-verity device $verity_name"

	# No udev in initramfs so create the device node manually
	dmsetup mknodes "$verity_name"

	klog "dm-verity $verity_name active on $dev"
}
