#!/usr/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Integrity helpers: IMA/EVM signature restore, key import, AVB dm-verity setup

# Restore IMA/EVM xattrs from build-time manifest
# cpio newc format does not preserve xattrs so we re-apply them
# Usage: restore_ima_evm_signatures <manifest> <xattr> <target_root> [file]
#   If [file] is given, only restore that single file's signature
restore_ima_evm_signatures() {

	manifest="$1"
	xattr="$2"
	target="$3"
	single="$4"

	[ -f "$manifest" ] || return 0

	if [ -n "$single" ]; then
		sig=$(grep "^${single} " "$manifest" | cut -d' ' -f2)
		[ -n "$sig" ] && [ -e "${target}${single}" ] && \
			setfattr -n "$xattr" -v "${sig#*:}" "${target}${single}" 2>/dev/null
		return 0
	fi

	while read filepath sig; do
		[ -e "${target}${filepath}" ] || continue
		setfattr -n "$xattr" -v "${sig#*:}" "${target}${filepath}" 2>/dev/null
	done < "$manifest"
}

setup_integrity() {

	klog "Setting up IMA/EVM Integrity..."

	# Restore IMA/EVM signatures on initramfs file path so that :
	# switch_root binary does not break signature verification
	# for performance reasons only handful files are needed to be restored
	restore_ima_evm_signatures "$IMA_MANIFEST" security.ima "" "/usr/bin/busybox.nosuid"
	restore_ima_evm_signatures "$EVM_MANIFEST" security.evm "" "/usr/bin/busybox.nosuid"
	restore_ima_evm_signatures "$IMA_MANIFEST" security.ima "" "/usr/lib/ld-linux-aarch64.so.1"
	restore_ima_evm_signatures "$EVM_MANIFEST" security.evm "" "/usr/lib/ld-linux-aarch64.so.1"  
	restore_ima_evm_signatures "$IMA_MANIFEST" security.ima "" "/usr/lib/libm.so.6"
	restore_ima_evm_signatures "$EVM_MANIFEST" security.evm "" "/usr/lib/libm.so.6"
	restore_ima_evm_signatures "$IMA_MANIFEST" security.ima "" "/usr/lib/libc.so.6"
	restore_ima_evm_signatures "$EVM_MANIFEST" security.evm "" "/usr/lib/libc.so.6"

	# Import IMA/EVM X509
	if [ ! -f "$IMA_X509" ] || [ ! -f "$EVM_X509" ]; then
		fatal "IMA/EVM X509 certificates not found!"
	fi

	ima_id=$(keyctl newring _ima @u)
	evmctl import "$IMA_X509" $ima_id > /dev/null 2>&1

	evm_id=$(keyctl newring _evm @u)
	evmctl import "$EVM_X509" $evm_id > /dev/null 2>&1

	# Load IMA policy
	if [ ! -f "$IMA_POLICY" ]; then
		fatal "IMA policy not found!"
	fi

	cat "$IMA_POLICY" \
		 > /sys/kernel/security/integrity/ima/policy \
		|| fatal "cannot load IMA policy"

	# Enable EVM in signature verification mode only 
	# and lock the configuration to prevent changes at runtime
	echo "0x80000002" > /sys/kernel/security/integrity/evm/evm
}

# Verify AVB signature and set up dm-verity on the decrypted root device.
# The AVB footer (with hashtree) lives inside the LUKS2 container.
# Usage: setup_avb_verity <luks_dm_name> <verity_dm_name>
setup_avb_verity() {

	luks_dev="/dev/mapper/$1"
	verity_name="$2"

	if [ ! -f "$AVB_PUBKEY" ]; then
		fatal "AVB public key not found at $AVB_PUBKEY"
	fi

	klog "Verifying AVB signature on $luks_dev..."
	dm_table=$(avb_verify --dm-table -d "$luks_dev" -k "$AVB_PUBKEY") \
		|| fatal "AVB verification failed on $luks_dev"

	klog "Setting up dm-verity as $verity_name..."
	echo "$dm_table" | dmsetup create --readonly "$verity_name" \
		|| fatal "cannot create dm-verity device $verity_name"

	# No udev in initramfs so create the device node manually
	dmsetup mknodes "$verity_name"

	klog "dm-verity $verity_name active on $luks_dev"
}
