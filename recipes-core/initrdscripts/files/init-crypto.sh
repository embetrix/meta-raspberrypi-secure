#!/usr/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Crypto helpers: plain dm-crypt with kernel keyring, rootfs encryption, data partition setup

# To provision an OTP key (one-time irreversible to fuses):
#   $ rpi-fw-crypto genkey --key-id 1 --alg ec
# then lock raw key readout in config.txt:
#   lock_device_private_key=1
# Note: if OTP key is not provisioned will fall back to using a user master key which is not secure
setup_encrypted_keys() {

	klog "OTP key provisioned, using trusted master key"
	MASTER_KEY_TYPE="trusted"
	ENC_KEY_MASTER="trusted:kmk"

	if [ ! -f "${KMK_BLOB}" ] || [ ! -f "${ENC_KEY_BLOB}" ] || [ ! -f "${EVM_KEY_BLOB}" ]; then
		if [ "$MASTER_KEY_TYPE" = "trusted" ]; then
			keyctl add trusted kmk "new ${KEY_SZ}" @u \
				|| fatal "cannot create KMK"
			keyctl pipe $(keyctl search @u trusted kmk) > ${KMK_BLOB} \
				|| fatal "cannot export KMK to ${KMK_BLOB}"
		else
			keyctl add user kmk "`dd if=/dev/urandom bs=1 count=${KEY_SZ} 2>/dev/null`" @u \
				|| fatal "cannot create KMK"
			keyctl pipe `keyctl search @u user kmk` > ${KMK_BLOB} \
				|| fatal "cannot export KMK to ${KMK_BLOB}"
		fi
		keyctl add encrypted enc-key "new ${ENC_KEY_MASTER} ${KEY_SZ}" @u \
			|| fatal "cannot create enc-key"
		keyctl pipe $(keyctl search @u encrypted enc-key) > ${ENC_KEY_BLOB} \
			|| fatal "cannot export enc-key to ${ENC_KEY_BLOB}"
		keyctl add encrypted evm-key "new ${ENC_KEY_MASTER} ${KEY_SZ}" @u \
			|| fatal "cannot create EVM key"
		keyctl pipe $(keyctl search @u encrypted evm-key) > ${EVM_KEY_BLOB} \
			|| fatal "cannot export EVM key to ${EVM_KEY_BLOB}"
		sync
	else
		if [ "$MASTER_KEY_TYPE" = "trusted" ]; then
			keyctl add trusted kmk "load $(cat ${KMK_BLOB})" @u \
				|| fatal "cannot import KMK from ${KMK_BLOB}"
		else
			keyctl add user kmk "`cat ${KMK_BLOB}`" @u \
				|| fatal "cannot import KMK from ${KMK_BLOB}"
		fi
		keyctl add encrypted enc-key "load $(cat ${ENC_KEY_BLOB})" @u \
			|| fatal "cannot import enc-key from ${ENC_KEY_BLOB}"
		keyctl add encrypted evm-key "load $(cat ${EVM_KEY_BLOB})" @u \
			|| fatal "cannot import EVM key from ${EVM_KEY_BLOB}"
	fi
}

# Open a block device with plain dm-crypt using the encrypted key
# already loaded in the kernel keyring by setup_encrypted_keys().
# Usage: setup_dmcrypt <device> <dm_name>
setup_dmcrypt() {

	dev="$1"
	dm_name="$2"

	num_sectors=$(blockdev --getsz "$dev") \
		|| fatal "cannot get size of $dev"

	dmsetup create "$dm_name" --table \
		"0 $num_sectors crypt aes-xts-plain64 :${KEY_SZ}:encrypted:enc-key 0 $dev 0" \
		|| fatal "cannot open plain dm-crypt $dev as $dm_name"

	# No udev in initramfs so create the device node manually
	dmsetup mknodes "$dm_name"
}

#############################################################################
# Encrypt rootfs on first boot using the update partition.
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# WARNING: This operation is NOT power-safe
# Power loss mid-migration can leave both root partitions unrecoverable
# should ideally be performed during manufacturing or
# initial provisioning and not in the field
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Flow:
#   Open root as plain dm-crypt, copy rootfs from update into it,
#   then open update as plain dm-crypt.
#############################################################################
encrypt_rootfs() {

	root_dm="$1"
	update_dev="$2"
	update_dm="$3"

	klog "First-boot rootfs encryption: migrating plain rootfs to dm-crypt..."
	enc_start=$(date +%s)

	# Copy the entire AVB image (filesystem + hashtree + footer)
	# from the update partition into the dm-crypt container.
	klog "Copying image from $update_dev to encrypted root volume..."
	dd if="$update_dev" of="/dev/mapper/$root_dm" bs=1M 2>/dev/null
	sync
    
	# Note: blkdiscard is not supported on all block devices (e.g. SD cards)
	blkdiscard -sf "$update_dev" 2>/dev/null || true
	setup_dmcrypt "$update_dev" "$update_dm"
   
	enc_end=$(date +%s)
	klog "Rootfs encryption complete in $((enc_end - enc_start))s"
}

# Mount a data partition with plain dm-crypt encryption.
# First boot: open + mkfs.ext4 + mount
# Normal boot: open + mount
# Usage: mount_dmcrypt_data <device> <dm_name> <label> <mountpoint> [mount_opts]
mount_dmcrypt_data() {

	dev="$1"
	dm_name="$2"
	label="$3"
	mnt="$4"
	mnt_opts="${5:-$OPT_PART}"

	[ -n "$dev" ] || return 0

	setup_dmcrypt "$dev" "$dm_name"

	if ! blkid -s TYPE "/dev/mapper/$dm_name" >/dev/null 2>&1; then
		fmt_start=$(date +%s)
		klog "Creating ext4 filesystem on $dm_name..."
		mkfs.ext4 -L "$label" "/dev/mapper/$dm_name" > /dev/null 2>&1 \
			|| fatal "cannot create filesystem on $dm_name"
		fmt_end=$(date +%s)
		klog "dm-crypt+ext4 setup of $dm_name completed in $((fmt_end - fmt_start))s"
	fi

	mkdir -p "$mnt"
	mount -o $mnt_opts -t ext4 "/dev/mapper/$dm_name" "$mnt" \
		|| fatal "cannot mount /dev/mapper/$dm_name on $mnt"
}
