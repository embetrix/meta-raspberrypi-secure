#!/usr/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 Embetrix Embedded Systems Solutions <ayoub.zaki@embetrix.com>
#
# Crypto helpers: LUKS2 key derivation, rootfs encryption, data partition setup

# Derive LUKS2 encryption key from secure storage:
# Uses rpi-fw-crypto HMAC-SHA256 with the OTP device key
# The HMAC input is the storage device CID (if available) which
# binds the key to the specific eMMC/SD/NVMe hardware preventing
# cloned disk images from being decrypted
# Falls back to HW_SERIAL if CID is not available on USB boot
# Falls back to sha256(serial) if OTP key is not provisioned.
#
# To provision an OTP key (one-time irreversible to fuses):
#   $ rpi-fw-crypto genkey --key-id 1 --alg ec
# then lock raw key readout in config.txt:
#   lock_device_private_key=1
#
# The derived key hex is cached in ENC_KEY_HEX so the expensive
# derivation (OTP HMAC / block-device-id) runs only once per boot.
derive_key() {

	[ -e "$HW_SERIAL" ] || fatal "Hardware serial not found at $HW_SERIAL"

	CID=$(block-device-id "/dev/$BASE_DEV" 2>/dev/null) \
		|| klog "cannot read CID from /dev/$BASE_DEV"

	# Try hardware-bound key via OTP HMAC
	if rpi-fw-crypto pubkey --key-id "$OTP_KEY_ID" --out /dev/null 2>/dev/null; then
		if [ -n "$CID" ]; then
			ENC_KEY_HEX=$(printf '%s' "$CID" | rpi-fw-crypto hmac --in /proc/self/fd/0 --key-id "$OTP_KEY_ID" --outform hex 2>/dev/null)
		else
			ENC_KEY_HEX=$(rpi-fw-crypto hmac --in "$HW_SERIAL" --key-id "$OTP_KEY_ID" --outform hex 2>/dev/null)
		fi
		if [ -n "$ENC_KEY_HEX" ]; then
			return 0
		fi
		klog "WARNING: OTP HMAC failed, falling back to serial-based key" >&2
	else
		klog "WARNING: OTP key not provisioned, falling back to serial-based key" >&2
	fi

	if [ -n "$CID" ]; then
		ENC_KEY_HEX=$(printf '%s' "$CID" | sha256sum | cut -d' ' -f1)
	else
		ENC_KEY_HEX=$(tr -d '\0' < "$HW_SERIAL" | sha256sum | cut -d' ' -f1)
	fi
}

inject_key() {

	hex2bin "$ENC_KEY_HEX"
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
#   Format root partition as LUKS2, copy from update (plain) into it
#   then format update partition as LUKS2
#############################################################################
encrypt_rootfs() {

	root_dev="$1"
	update_dev="$2"
	root_dm="$3"
	update_dm="$4"
	luks_opts="--type luks2 --key-size 256"

	klog "First-boot rootfs encryption: migrating plain rootfs to dm-crypt LUKS2..."
	enc_start=$(date +%s)

	# Detect filesystem type
	fstype=$(blkid -s TYPE -o value "$update_dev" 2>/dev/null) \
		|| fatal "cannot detect root filesystem type"
	klog "Update partition filesystem: $fstype"

	# Format root partition as LUKS2, copy from update
	inject_key | cryptsetup luksFormat $luks_opts -q --key-file=- "$root_dev" \
		|| fatal "cannot format root $root_dev as LUKS2"
	inject_key | cryptsetup luksOpen --key-file=- "$root_dev" "$root_dm" \
		|| fatal "cannot open root LUKS2 $root_dev"

	# Copy the entire AVB image (filesystem + hashtree + footer)
	# from the update partition into the LUKS2 container.
	# Do NOT shrink or expand the filesystem the AVB hashtree
	# must remain intact for dm-verity verification.
	klog "Copying image from $update_dev to encrypted root volume..."
	dd if="$update_dev" of="/dev/mapper/$root_dm" bs=4M 2>/dev/null
	sync

	# Format update partition as LUKS2
	inject_key | cryptsetup luksFormat $luks_opts -q --key-file=- "$update_dev" \
		|| fatal "cannot format update $update_dev as LUKS2"
	inject_key | cryptsetup luksOpen --key-file=- "$update_dev" "$update_dm" \
		|| fatal "cannot open update LUKS2 $update_dev"

	enc_end=$(date +%s)
	klog "Rootfs encryption complete in $((enc_end - enc_start))s"
}

# Mount a data partition with LUKS2 encryption.
# First boot: luksFormat + mkfs.ext4 + mount
# Normal boot: luksOpen + mount
# Usage: mount_data_luks <device> <dm_name> <label> <mountpoint> [mount_opts]
mount_data_luks() {

	dev="$1"
	dm_name="$2"
	label="$3"
	mnt="$4"
	mnt_opts="${5:-$OPT_PART}"
	luks_opts="--type luks2 --key-size 256"

	[ -n "$dev" ] || return 0
	[ -n "$DM_INTEGRITY" ] && luks_opts="$luks_opts --integrity $DM_INTEGRITY"

	if ! cryptsetup isLuks "$dev" 2>/dev/null; then
		fmt_start=$(date +%s)
		klog "Formatting $dev as LUKS2 for $dm_name..."
		inject_key | cryptsetup luksFormat $luks_opts -q --key-file=- "$dev" \
			|| fatal "cannot format $dev as LUKS2"
		inject_key | cryptsetup luksOpen --key-file=- "$dev" "$dm_name" \
			|| fatal "cannot open LUKS2 device $dev"
		mkfs.ext4 -L "$label" "/dev/mapper/$dm_name" > /dev/null 2>&1 \
			|| fatal "cannot create filesystem on $dm_name"
		fmt_end=$(date +%s)
		klog "LUKS2+ext4 setup of $dev completed in $((fmt_end - fmt_start))s"
	else
		inject_key | cryptsetup luksOpen --key-file=- "$dev" "$dm_name" \
			|| fatal "cannot open LUKS2 device $dev"
	fi

	mkdir -p "$mnt"
	mount -o $mnt_opts -t ext4 "/dev/mapper/$dm_name" "$mnt" \
		|| fatal "cannot mount /dev/mapper/$dm_name on $mnt"
}
